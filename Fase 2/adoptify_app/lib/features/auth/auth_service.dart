import '../../core/api_client.dart';

// Cuenta con sesión iniciada; role: 'adopter', 'foundation' o 'admin'
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.rut,
    required this.fullName,
    required this.role,
    this.twoFactorEnabled = false,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as int,
        email: json['email'] as String,
        rut: json['rut'] as String,
        fullName: json['full_name'] as String,
        role: json['role'] as String,
        twoFactorEnabled: json['two_factor_enabled'] as bool? ?? false,
      );

  final int id;
  final String email;
  final String rut;
  final String fullName;
  final String role;
  // Verificación en dos pasos por correo (HU-I)
  final bool twoFactorEnabled;

  String get roleLabel => switch (role) {
        'adopter' => 'Adoptante',
        'foundation' => 'Fundación',
        'admin' => 'Administrador',
        _ => role,
      };

  // Las fundaciones (y el admin) entran por el mismo login y ven su propia vista, no la de adoptante
  bool get isFoundation => role == 'foundation' || role == 'admin';
}

// Código enviado al correo (HU-I): para iniciar sesión con la verificación en dos pasos o para activarla.
// El cliente solo conoce el id del desafío y a dónde se envió, nunca el código.
class CodeChallenge {
  const CodeChallenge({
    required this.id,
    required this.emailHint,
    required this.expiresInMinutes,
    required this.resendInSeconds,
  });

  factory CodeChallenge.fromJson(Map<String, dynamic> json) => CodeChallenge(
        id: json['challenge_id'] as String,
        emailHint: json['email_hint'] as String,
        expiresInMinutes: json['expires_in_minutes'] as int,
        resendInSeconds: json['resend_in_seconds'] as int,
      );

  final String id;
  final String emailHint;
  final int expiresInMinutes;
  final int resendInSeconds;
}

// Llamadas a /auth, igual que services/auth.ts del portal
class AuthService {
  AuthService(this._api);

  final ApiClient _api;

  // Login único: sin account_type entra cualquier cuenta y la app muestra la vista según el rol.
  // Con la verificación en dos pasos activa no llega token (202): se devuelve el desafío del código.
  Future<CodeChallenge?> login(String email, String password) async {
    final data = await _api.post('/auth/login', {'email': email, 'password': password}) as Map<String, dynamic>;
    if (data.containsKey('challenge_id')) return CodeChallenge.fromJson(data);
    await _api.setToken(data['access_token'] as String);
    return null;
  }

  Future<void> verifyCode(String challengeId, String code) async {
    final data = await _api.post('/auth/verify-code', {'challenge_id': challengeId, 'code': code});
    await _api.setToken((data as Map<String, dynamic>)['access_token'] as String);
  }

  Future<CodeChallenge> resendCode(String challengeId) async => CodeChallenge.fromJson(
        await _api.post('/auth/resend-code', {'challenge_id': challengeId}) as Map<String, dynamic>,
      );

  // Activar: primero llega un código al correo y solo queda activa al confirmarlo
  Future<CodeChallenge> startTwoFactor() async =>
      CodeChallenge.fromJson(await _api.post('/auth/two-factor/enable', const {}) as Map<String, dynamic>);

  Future<AppUser> confirmTwoFactor(String challengeId, String code) async => AppUser.fromJson(
        await _api.post('/auth/two-factor/confirm', {'challenge_id': challengeId, 'code': code})
            as Map<String, dynamic>,
      );

  Future<AppUser> disableTwoFactor(String password) async => AppUser.fromJson(
        await _api.post('/auth/two-factor/disable', {'password': password}) as Map<String, dynamic>,
      );

  Future<void> register(String email, String rut, String password, String fullName) async {
    await _api.post('/auth/register', {
      'email': email,
      'rut': rut,
      'password': password,
      'full_name': fullName,
    });
  }

  Future<AppUser> fetchMe() async => AppUser.fromJson(await _api.get('/auth/me') as Map<String, dynamic>);
}
