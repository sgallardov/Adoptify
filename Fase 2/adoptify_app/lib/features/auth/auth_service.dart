import '../../core/api_client.dart';

// Cuenta con sesión iniciada; role: 'adopter', 'foundation' o 'admin'
class AppUser {
  const AppUser({
    required this.id,
    required this.email,
    required this.rut,
    required this.fullName,
    required this.role,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as int,
        email: json['email'] as String,
        rut: json['rut'] as String,
        fullName: json['full_name'] as String,
        role: json['role'] as String,
      );

  final int id;
  final String email;
  final String rut;
  final String fullName;
  final String role;

  String get roleLabel => switch (role) {
        'adopter' => 'Adoptante',
        'foundation' => 'Fundación',
        'admin' => 'Administrador',
        _ => role,
      };

  // Las fundaciones (y el admin) entran por el mismo login y ven su propia vista, no la de adoptante
  bool get isFoundation => role == 'foundation' || role == 'admin';
}

// Llamadas a /auth, igual que services/auth.ts del portal
class AuthService {
  AuthService(this._api);

  final ApiClient _api;

  // Login único: sin account_type entra cualquier cuenta y la app muestra la vista según el rol
  Future<void> login(String email, String password) async {
    final data = await _api.post('/auth/login', {'email': email, 'password': password});
    await _api.setToken((data as Map<String, dynamic>)['access_token'] as String);
  }

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
