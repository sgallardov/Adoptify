import 'dart:typed_data';

import 'package:image_picker/image_picker.dart';

enum PhotoSource { camera, gallery }

class PickedPhoto {
  const PickedPhoto({required this.bytes, required this.filename});

  final Uint8List bytes;
  final String filename;
}

// Toma una foto con la cámara o la elige de la galería.
// Reemplazable en las pruebas igual que LocationService.instance.
class PhotoService {
  static PhotoService instance = PhotoService();

  final _picker = ImagePicker();

  // null si la persona cancela. La imagen se achica para no superar el máximo de 5 MB del backend.
  Future<PickedPhoto?> pick(PhotoSource source) async {
    final file = await _picker.pickImage(
      source: source == PhotoSource.camera ? ImageSource.camera : ImageSource.gallery,
      maxWidth: 1600,
      maxHeight: 1600,
      imageQuality: 85,
    );
    if (file == null) return null;
    return PickedPhoto(bytes: await file.readAsBytes(), filename: file.name);
  }
}
