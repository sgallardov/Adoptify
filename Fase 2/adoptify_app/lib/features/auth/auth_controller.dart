import 'package:flutter/widgets.dart';

import '../../core/api_client.dart';
import 'auth_service.dart';

// Estado de la sesión: equivalente a AuthProvider del portal
class AuthController extends ChangeNotifier {
  AuthController(this._api) : _service = AuthService(_api) {
    _api.onUnauthorized = _clearSession;
  }

  final ApiClient _api;
  final AuthService _service;

  AppUser? _user;
  bool _loading = true;

  AppUser? get user => _user;
  bool get loading => _loading;
  ApiClient get api => _api;
  AuthService get service => _service;

  // Al abrir la app: si hay un token guardado, recupera la sesión con /auth/me.
  // Solo se descarta el token si la API lo rechaza; sin conexión se conserva para el próximo intento.
  Future<void> restore() async {
    final token = await _api.loadToken();
    if (token != null) {
      try {
        _user = await _service.fetchMe();
      } on ApiException catch (error) {
        if (error.statusCode == 401) await _api.setToken(null);
      }
    }
    _loading = false;
    notifyListeners();
  }

  // Sin verificación en dos pasos, la sesión queda iniciada y retorna null. Con ella, retorna el desafío
  // del código enviado al correo y la sesión empieza recién con verifyCode.
  Future<CodeChallenge?> signIn(String email, String password) async {
    final challenge = await _service.login(email, password);
    if (challenge != null) return challenge;
    await _loadUser();
    return null;
  }

  Future<void> verifyCode(String challengeId, String code) async {
    await _service.verifyCode(challengeId, code);
    await _loadUser();
  }

  // Una cuenta nueva no tiene la verificación en dos pasos: entra directo
  Future<void> signUp(String email, String rut, String password, String fullName) async {
    await _service.register(email, rut, password, fullName);
    await signIn(email, password);
  }

  // Tras activar o desactivar la verificación en dos pasos, el Perfil muestra el estado nuevo
  void updateUser(AppUser user) {
    _user = user;
    notifyListeners();
  }

  Future<void> _loadUser() async {
    _user = await _service.fetchMe();
    notifyListeners();
  }

  Future<void> signOut() async {
    await _api.setToken(null);
    _user = null;
    notifyListeners();
  }

  void _clearSession() {
    if (_user == null && !_api.hasToken) return;
    signOut();
  }
}

// Expone el AuthController a las pantallas y las redibuja cuando cambia la sesión
class AuthScope extends InheritedNotifier<AuthController> {
  const AuthScope({super.key, required AuthController controller, required super.child})
      : super(notifier: controller);

  static AuthController of(BuildContext context) {
    final scope = context.dependOnInheritedWidgetOfExactType<AuthScope>();
    assert(scope != null, 'AuthScope.of debe usarse dentro de AuthScope');
    return scope!.notifier!;
  }
}
