import 'package:flutter_test/flutter_test.dart';

import 'package:adoptify_app/core/config.dart';

void main() {
  test('las fotos subidas se piden al servidor de la API, sin importar desde dónde se subieron', () {
    final api = Uri.parse(apiUrl);
    final url = Uri.parse(mediaUrl('http://localhost:8000/uploads/abc.jpg')!);
    expect(url.host, api.host);
    expect(url.port, api.port);
    expect(url.path, '/uploads/abc.jpg');
  });

  test('las fotos externas y los valores vacíos no cambian', () {
    const external = 'https://images.unsplash.com/photo-1543466835?w=900';
    expect(mediaUrl(external), external);
    expect(mediaUrl(null), isNull);
  });
}
