import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:adoptify_app/shared/widgets/network_photo.dart';

const signed = 'https://abc.supabase.co/storage/v1/object/sign/fotos/a1.jpg?token=eyJ.firmado';

void main() {
  group('photoCacheKey', () {
    test('quita el token del enlace firmado: la misma foto tiene la misma clave aunque cambie el enlace', () {
      expect(photoCacheKey(signed), 'https://abc.supabase.co/storage/v1/object/sign/fotos/a1.jpg');
      expect(photoCacheKey(signed.replaceFirst('firmado', 'otro')), photoCacheKey(signed));
    });

    test('deja intactos los demás parámetros y los enlaces sin token', () {
      expect(photoCacheKey('https://x.cl/a.jpg?w=400&token=t'), 'https://x.cl/a.jpg?w=400');
      expect(photoCacheKey('https://images.unsplash.com/photo-1?w=400'), 'https://images.unsplash.com/photo-1?w=400');
    });
  });

  group('sizedPhotoUrl', () {
    test('pide las fotos de Unsplash al ancho en que se muestran, en múltiplos de 200', () {
      final uri = Uri.parse(sizedPhotoUrl('https://images.unsplash.com/photo-1?ixid=abc', 375));
      expect(uri.queryParameters['w'], '400');
      expect(uri.queryParameters['q'], '75');
      expect(uri.queryParameters['ixid'], 'abc');
      expect(Uri.parse(sizedPhotoUrl('https://images.unsplash.com/photo-1', 5000)).queryParameters['w'], '1600');
    });

    test('no toca las fotos del bucket ni el tamaño original', () {
      expect(sizedPhotoUrl(signed, 400), signed);
      expect(sizedPhotoUrl('https://images.unsplash.com/photo-1', null), 'https://images.unsplash.com/photo-1');
    });
  });

  testWidgets('decodifica la foto al tamaño en que se muestra y usa la huella si no carga', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: MediaQuery(
        data: MediaQueryData(devicePixelRatio: 2),
        child: NetworkPhoto(url: 'https://x.cl/a.jpg', pixelsWide: 72, fallback: Icon(Icons.pets)),
      ),
    ));
    final image = tester.widget<Image>(find.byType(Image));
    expect(image.image, isA<ResizeImage>());
    expect((image.image as ResizeImage).width, 144);

    // En las pruebas la red responde 400: se muestra la huella en vez de un error
    await tester.pumpAndSettle();
    expect(find.byIcon(Icons.pets), findsOneWidget);
  });
}
