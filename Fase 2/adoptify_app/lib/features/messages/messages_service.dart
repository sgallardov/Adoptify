import '../../core/api_client.dart';

// Sondeo del chat (HU-G2), igual que el portal: sin WebSockets
const conversationsPollInterval = Duration(seconds: 15);
const messagesPollInterval = Duration(seconds: 10);
const maxMessageLength = 1000;

class LastMessage {
  const LastMessage({required this.body, required this.createdAt, required this.fromFoundation});

  final String body;
  final DateTime createdAt;
  final bool fromFoundation;

  factory LastMessage.fromJson(Map<String, dynamic> json) => LastMessage(
    body: json['body'] as String,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    fromFoundation: json['from_foundation'] as bool,
  );
}

// Conversación entre una fundación y un adoptante. Nunca trae correo, teléfono ni RUT.
class Conversation {
  const Conversation({
    required this.id,
    required this.foundationName,
    required this.userName,
    required this.createdAt,
    this.lastMessage,
  });

  final int id;
  final String foundationName;
  final String userName;
  final DateTime createdAt;
  final LastMessage? lastMessage;

  DateTime get lastActivity => lastMessage?.createdAt ?? createdAt;

  factory Conversation.fromJson(Map<String, dynamic> json) => Conversation(
    id: json['id'] as int,
    foundationName: json['foundation_name'] as String,
    userName: json['user_name'] as String,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    lastMessage: json['last_message'] == null
        ? null
        : LastMessage.fromJson(json['last_message'] as Map<String, dynamic>),
  );
}

// Pregunta automática del cuestionario de adopción (HU-G3). Al apretar "Conversar" junto a un
// interesado, el chat le hace las preguntas de la fundación una a una; el adoptante responde aquí.
class QuestionInfo {
  const QuestionInfo({
    required this.formId,
    required this.index,
    required this.total,
    required this.kind,
    required this.options,
    required this.required,
  });

  final int formId;
  // 0 = primera pregunta
  final int index;
  final int total;
  // text | yes_no | choice
  final String kind;
  final List<String> options;
  final bool required;

  factory QuestionInfo.fromJson(Map<String, dynamic> json) => QuestionInfo(
    formId: json['form_id'] as int,
    index: json['index'] as int,
    total: json['total'] as int,
    kind: json['kind'] as String,
    options: [for (final option in json['options'] as List<dynamic>? ?? const []) option as String],
    required: json['required'] as bool? ?? true,
  );
}

class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.body,
    required this.createdAt,
    required this.fromFoundation,
    required this.mine,
    this.kind = 'text',
    this.question,
  });

  final int id;
  final String body;
  final DateTime createdAt;
  final bool fromFoundation;
  final bool mine;
  // text | question (pregunta automática del cuestionario) | answer (respuesta del adoptante)
  final String kind;
  final QuestionInfo? question;

  factory ChatMessage.fromJson(Map<String, dynamic> json) => ChatMessage(
    id: json['id'] as int,
    body: json['body'] as String,
    createdAt: DateTime.parse(json['created_at'] as String).toLocal(),
    fromFoundation: json['from_foundation'] as bool,
    mine: json['mine'] as bool,
    kind: json['kind'] as String? ?? 'text',
    question: json['question'] == null ? null : QuestionInfo.fromJson(json['question'] as Map<String, dynamic>),
  );
}

// La pregunta que espera respuesta: la última pregunta automática, si después no llegó su respuesta
ChatMessage? pendingQuestion(List<ChatMessage> messages) {
  for (final message in messages.reversed) {
    if (message.kind == 'answer') return null;
    if (message.kind == 'question' && message.question != null) return message;
  }
  return null;
}

// Llamadas de /conversations. Las conversaciones las abre una fundación; el adoptante lee y responde.
class MessagesService {
  MessagesService(this._api);

  final ApiClient _api;

  Future<List<Conversation>> fetchConversations() async {
    final data = await _api.get('/conversations') as List<dynamic>;
    return [for (final item in data) Conversation.fromJson(item as Map<String, dynamic>)];
  }

  // Con afterId solo llegan los mensajes nuevos (para el sondeo)
  Future<List<ChatMessage>> fetchMessages(int conversationId, {int? afterId}) async {
    final data = await _api.get(
      '/conversations/$conversationId/messages',
      query: afterId == null ? null : {'after_id': afterId},
    ) as List<dynamic>;
    return [for (final item in data) ChatMessage.fromJson(item as Map<String, dynamic>)];
  }

  Future<ChatMessage> send(int conversationId, String body) async {
    final data = await _api.post('/conversations/$conversationId/messages', {'body': body});
    return ChatMessage.fromJson(data as Map<String, dynamic>);
  }

  // Fundación: abre (o recupera) el chat con una persona interesada o postulada. Con animalId
  // ("Conversar" desde los interesados de una mascota) empieza el cuestionario de adopción, una sola vez.
  Future<Conversation> open(int userId, {int? animalId}) async {
    final data = await _api.post('/conversations', {'user_id': userId, 'animal_id': ?animalId});
    return Conversation.fromJson(data as Map<String, dynamic>);
  }

  // Adoptante: responde la pregunta pendiente (true/false, una alternativa o texto; null salta una
  // opcional). Devuelve su respuesta y la siguiente pregunta, o el cierre si era la última.
  Future<List<ChatMessage>> answer(int conversationId, int formId, Object? answer) async {
    final data = await _api.post('/conversations/$conversationId/forms/$formId/answer', {'answer': answer}) as List<dynamic>;
    return [for (final item in data) ChatMessage.fromJson(item as Map<String, dynamic>)];
  }
}

// Suma mensajes nuevos sin duplicar los que ya llegaron (el sondeo y el envío pueden traer el mismo)
List<ChatMessage> mergeMessages(List<ChatMessage> current, List<ChatMessage> incoming) {
  final known = {for (final message in current) message.id};
  return [...current, ...incoming.where((message) => !known.contains(message.id))]
    ..sort((a, b) => a.id.compareTo(b.id));
}

// "14:05" si es de hoy; si no, "12 nov"
String shortTime(DateTime date) {
  final now = DateTime.now();
  final hh = date.hour.toString().padLeft(2, '0');
  final mm = date.minute.toString().padLeft(2, '0');
  if (date.year == now.year && date.month == now.month && date.day == now.day) return '$hh:$mm';
  const months = ['ene', 'feb', 'mar', 'abr', 'may', 'jun', 'jul', 'ago', 'sept', 'oct', 'nov', 'dic'];
  return '${date.day} ${months[date.month - 1]}';
}
