import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api_client.dart';
import '../../core/photo_service.dart';
import '../../shared/widgets/content_width.dart';
import '../../shared/widgets/message_box.dart';
import '../auth/auth_controller.dart';
import '../foundation_animals/foundation_animals_service.dart';
import '../map/map_service.dart';

const _placeTypes = <String, String>{
  'refugio': 'Refugio',
  'hogar_temporal': 'Hogar temporal',
};

// location conserva su función de punto privado de HU-04. El lugar de resguardo
// se guarda como texto interno y no se geocodifica automáticamente.
class AddAnimalScreen extends StatefulWidget {
  const AddAnimalScreen({super.key, this.animal});

  final ManagedAnimal? animal;

  @override
  State<AddAnimalScreen> createState() => _AddAnimalScreenState();
}

class _AddAnimalScreenState extends State<AddAnimalScreen> {
  final _formKey = GlobalKey<FormState>();
  late final TextEditingController _name;
  late final TextEditingController _placeAddress;
  String? _species;
  String? _size;
  String? _gender;
  String? _placeType;
  int _energyLevel = 3;
  String? _photoUrl;
  bool _uploading = false;
  String? _photoError;
  bool _saving = false;
  String? _error;

  bool get _editing => widget.animal != null;

  @override
  void initState() {
    super.initState();
    final animal = widget.animal;
    _name = TextEditingController(text: animal?.name ?? '');
    _placeAddress = TextEditingController(text: animal?.keepingPlaceAddress ?? '');
    _species = animal?.species;
    _size = animal?.size;
    _gender = animal?.gender;
    _placeType = animal?.keepingPlaceType;
    _energyLevel = animal?.energyLevel ?? 3;
    _photoUrl = animal?.photoUrl;
  }

  @override
  void dispose() {
    _name.dispose();
    _placeAddress.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    setState(() {
      _error = null;
    });
    if (!(_formKey.currentState?.validate() ?? false)) return;
    if (!_editing && (_photoUrl == null || _photoUrl!.isEmpty)) {
      setState(() => _photoError = 'Debes subir una foto del animal antes de publicar.');
      return;
    }
    setState(() => _saving = true);
    try {
      final payload = <String, dynamic>{
        'name': _name.text.trim(),
        'species': _species,
        'size': _size,
        'gender': _gender,
        'energy_level': _energyLevel,
        'keeping_place_type': _placeType,
        'keeping_place_address': _placeAddress.text.trim(),
        // Al editar, omitir la foto conserva la que ya tenía el registro (incluidos casos históricos sin foto).
        if (!_editing || _photoUrl != null) 'photo_url': _photoUrl,
      };
      if (_editing) {
        await AuthScope.of(context).api.patch('/animals/${widget.animal!.id}', payload);
      } else {
        await AuthScope.of(context).api.post('/animals', payload);
      }
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(_editing ? 'Animal actualizado correctamente.' : 'Animal publicado correctamente.')),
      );
      // Tras publicar o editar, la fundación ve de inmediato el resultado en su listado privado.
      context.go('/fundacion/mis-animales');
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorMessage(error, 'No pudimos publicar el animal. Inténtalo nuevamente.'));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String? _required(String? value, String label) =>
      value == null || value.isEmpty ? 'Selecciona $label.' : null;

  Future<void> _pickPhoto(PhotoSource source) async {
    final PickedPhoto? photo;
    try {
      photo = await PhotoService.instance.pick(source);
    } on PlatformException {
      if (!mounted) return;
      setState(() => _photoError = source == PhotoSource.camera
          ? 'No pudimos abrir la cámara. Revisa el permiso o elige una foto de la galería.'
          : 'No pudimos abrir la galería. Inténtalo nuevamente.');
      return;
    }
    if (photo == null || !mounted) return;
    setState(() {
      _uploading = true;
      _photoError = null;
      _error = null;
    });
    try {
      final url = await MapService(AuthScope.of(context).api).uploadPhoto(photo);
      if (!mounted) return;
      setState(() {
        _photoUrl = url;
        _uploading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _photoError = errorMessage(error, 'No se pudo subir la foto. Inténtalo nuevamente.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final busy = _saving || _uploading;
    return Scaffold(
      appBar: AppBar(title: Text(_editing ? 'Editar mascota' : 'Agregar mascota')),
      body: ContentWidth(
        child: Form(
          key: _formKey,
          child: ListView(
            padding: const EdgeInsets.all(AdoptifySpacing.xl),
            children: [
              Text(_editing ? 'Actualiza su historia' : 'Publica una historia', style: Theme.of(context).textTheme.headlineSmall),
              const SizedBox(height: AdoptifySpacing.sm),
              Text(
                'Los datos de resguardo solo se comparten con tu fundación y el administrador.',
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: AdoptifySpacing.xl),
              TextFormField(
                controller: _name,
                enabled: !busy,
                maxLength: 100,
                textCapitalization: TextCapitalization.words,
                decoration: const InputDecoration(labelText: 'Nombre *'),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Escribe el nombre del animal.'
                    : null,
              ),
              const SizedBox(height: AdoptifySpacing.md),
              _SelectField(
                label: 'Especie *',
                value: _species,
                enabled: !busy,
                items: const {'perro': 'Perro', 'gato': 'Gato'},
                onChanged: (value) => setState(() => _species = value),
                validator: (value) => _required(value, 'una especie'),
              ),
              const SizedBox(height: AdoptifySpacing.md),
              _SelectField(
                label: 'Tamaño *',
                value: _size,
                enabled: !busy,
                items: const {'pequeño': 'Pequeño', 'mediano': 'Mediano', 'grande': 'Grande'},
                onChanged: (value) => setState(() => _size = value),
                validator: (value) => _required(value, 'un tamaño'),
              ),
              const SizedBox(height: AdoptifySpacing.md),
              _SelectField(
                label: 'Sexo *',
                value: _gender,
                enabled: !busy,
                items: const {'macho': 'Macho', 'hembra': 'Hembra'},
                onChanged: (value) => setState(() => _gender = value),
                validator: (value) => _required(value, 'el sexo'),
              ),
              const SizedBox(height: AdoptifySpacing.md),
              _SelectField(
                label: 'Nivel de energía *',
                value: '$_energyLevel',
                enabled: !busy,
                items: const {
                  '1': '1 · Muy tranquilo',
                  '2': '2 · Tranquilo',
                  '3': '3 · Moderado',
                  '4': '4 · Activo',
                  '5': '5 · Muy activo',
                },
                onChanged: (value) => setState(() => _energyLevel = int.parse(value!)),
                validator: (_) => null,
              ),
              const SizedBox(height: AdoptifySpacing.xl),
              Text('Foto del animal *', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AdoptifySpacing.xs),
              Text(
                _photoUrl == null
                    ? (_editing ? 'Puedes cargar una foto si deseas actualizarla.' : 'Sube una foto para poder publicar esta mascota.')
                    : 'Foto cargada correctamente.',
                style: Theme.of(context).textTheme.bodySmall,
              ),
              const SizedBox(height: AdoptifySpacing.md),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : () => _pickPhoto(PhotoSource.camera),
                      icon: const Icon(Icons.photo_camera_outlined),
                      label: const Text('Cámara'),
                    ),
                  ),
                  const SizedBox(width: AdoptifySpacing.md),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: busy ? null : () => _pickPhoto(PhotoSource.gallery),
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('Galería'),
                    ),
                  ),
                ],
              ),
              if (_uploading) ...[
                const SizedBox(height: AdoptifySpacing.sm),
                const Center(child: CircularProgressIndicator()),
              ],
              if (_photoUrl != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: TextButton.icon(
                    onPressed: busy ? null : () => setState(() => _photoUrl = null),
                    icon: const Icon(Icons.delete_outline),
                    label: const Text('Quitar foto'),
                  ),
                ),
              if (_photoError != null) ...[
                const SizedBox(height: AdoptifySpacing.sm),
                MessageBox.error(message: _photoError!),
              ],
              const SizedBox(height: AdoptifySpacing.xl),
              Text('Lugar de resguardo', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: AdoptifySpacing.xs),
              Text('Nunca se muestra en el mapa ni en las fichas públicas.', style: Theme.of(context).textTheme.bodySmall),
              const SizedBox(height: AdoptifySpacing.md),
              _SelectField(
                label: 'Tipo de lugar *',
                value: _placeType,
                enabled: !busy,
                items: _placeTypes,
                onChanged: (value) => setState(() => _placeType = value),
                validator: (value) => _required(value, 'el tipo de lugar'),
              ),
              const SizedBox(height: AdoptifySpacing.md),
              TextFormField(
                controller: _placeAddress,
                enabled: !busy,
                maxLength: 255,
                textCapitalization: TextCapitalization.sentences,
                decoration: const InputDecoration(
                  labelText: 'Lugar donde se encuentra *',
                  hintText: 'Sede, comuna y referencia interna',
                ),
                validator: (value) => value == null || value.trim().isEmpty
                    ? 'Indica el lugar donde se encuentra el animal.'
                    : null,
              ),
              if (_error != null) ...[const SizedBox(height: AdoptifySpacing.md), MessageBox.error(message: _error!)],
              const SizedBox(height: AdoptifySpacing.lg),
              FilledButton.icon(
                onPressed: busy ? null : _submit,
                icon: busy
                    ? SizedBox.square(
                        dimension: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: context.colors.onAccent,
                        ),
                      )
                    : const Icon(Icons.publish_outlined),
                label: Text(busy ? (_editing ? 'Guardando…' : 'Publicando…') : (_editing ? 'Guardar cambios' : 'Publicar animal')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SelectField extends StatelessWidget {
  const _SelectField({
    required this.label,
    required this.value,
    required this.enabled,
    required this.items,
    required this.onChanged,
    required this.validator,
  });

  final String label;
  final String? value;
  final bool enabled;
  final Map<String, String> items;
  final ValueChanged<String?> onChanged;
  final String? Function(String?) validator;

  @override
  Widget build(BuildContext context) => DropdownButtonFormField<String>(
        value: value,
        isExpanded: true,
        decoration: InputDecoration(labelText: label),
        items: [
          for (final item in items.entries)
            DropdownMenuItem(value: item.key, child: Text(item.value)),
        ],
        onChanged: enabled ? onChanged : null,
        validator: validator,
      );
}
