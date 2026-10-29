import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// Dónde se guarda el token de sesión. Interfaz para poder usar memoria en los tests.
abstract class TokenStorage {
  Future<String?> read();
  Future<void> write(String? token);
}

// Almacenamiento cifrado del sistema (Keystore en Android, Keychain en iOS)
class SecureTokenStorage implements TokenStorage {
  static const _key = 'adoptify_token';
  final _storage = const FlutterSecureStorage();

  @override
  Future<String?> read() async {
    try {
      return await _storage.read(key: _key);
    } catch (_) {
      return null; // Sin almacenamiento disponible: la sesión dura hasta cerrar la app
    }
  }

  @override
  Future<void> write(String? token) async {
    try {
      if (token == null) {
        await _storage.delete(key: _key);
      } else {
        await _storage.write(key: _key, value: token);
      }
    } catch (_) {
      // Igual que en la web: si no se puede guardar, la sesión sigue en memoria
    }
  }
}

class MemoryTokenStorage implements TokenStorage {
  MemoryTokenStorage([this.token]);

  String? token;

  @override
  Future<String?> read() async => token;

  @override
  Future<void> write(String? value) async => token = value;
}
