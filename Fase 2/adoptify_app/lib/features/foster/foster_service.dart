import '../../core/api_client.dart';

// Opciones de la postulación: [valor que guarda la API, texto que ve el usuario].
// Mismos valores que schemas/foster_application.py del backend.
typedef FosterOption = (String, String);

const fosterSpecies = <FosterOption>[('perro', 'Perros'), ('gato', 'Gatos'), ('ambos', 'Ambos')];
const fosterSizes = <FosterOption>[('pequeño', 'Pequeño'), ('mediano', 'Mediano'), ('grande', 'Grande')];
const fosterSpaces = <FosterOption>[
  ('casa_patio', 'Casa con patio'),
  ('casa_sin_patio', 'Casa sin patio'),
  ('departamento', 'Departamento'),
];

String fosterLabel(List<FosterOption> options, String value) =>
    options.firstWhere((option) => option.$1 == value, orElse: () => (value, value)).$2;

// Postulación a hogar temporal (HU-B). Es general (no va a una fundación) y hay una por cuenta.
// Nombre y correo no viajan aquí: el backend los toma de la cuenta.
class FosterApplication {
  const FosterApplication({
    required this.species,
    required this.sizes,
    required this.space,
    required this.maxAnimals,
    required this.maxDays,
    required this.availability,
    required this.phone,
    required this.address,
    this.status = 'pending',
  });

  factory FosterApplication.fromJson(Map<String, dynamic> json) => FosterApplication(
        species: json['species'] as String,
        sizes: Set<String>.from(json['sizes'] as List),
        space: json['space'] as String,
        maxAnimals: json['max_animals'] as int,
        maxDays: json['max_days'] as int,
        availability: json['availability'] as String,
        phone: json['phone'] as String,
        address: json['address'] as String,
        status: json['status'] as String,
      );

  final String species;
  final Set<String> sizes;
  final String space;
  final int maxAnimals;
  final int maxDays;
  final String availability;
  final String phone;
  final String address;
  // 'pending' | 'approved' | 'rejected': un solo estado para todas las fundaciones
  final String status;

  bool get isPending => status == 'pending';

  String get statusLabel => switch (status) {
        'approved' => 'Aprobada',
        'rejected' => 'No aprobada',
        _ => 'En revisión',
      };

  Map<String, dynamic> toJson() => {
        'species': species,
        // Siempre en el mismo orden (pequeño, mediano, grande)
        'sizes': [for (final (id, _) in fosterSizes) if (sizes.contains(id)) id],
        'space': space,
        'max_animals': maxAnimals,
        'max_days': maxDays,
        'availability': availability,
        'phone': phone,
        'address': address,
      };
}

// Llamadas a /foster-applications
class FosterService {
  FosterService(this._api);

  final ApiClient _api;

  // null si la persona todavía no postula
  Future<FosterApplication?> fetchMine() async {
    final data = await _api.get('/foster-applications/me');
    return data == null ? null : FosterApplication.fromJson(data as Map<String, dynamic>);
  }

  // Crea la postulación o, si ya existe, la actualiza (solo mientras está en revisión)
  Future<FosterApplication> save(FosterApplication application, {required bool exists}) async {
    final data = exists
        ? await _api.put('/foster-applications/me', application.toJson())
        : await _api.post('/foster-applications', application.toJson());
    return FosterApplication.fromJson(data as Map<String, dynamic>);
  }

  Future<void> withdraw() => _api.delete('/foster-applications/me');
}
