import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../app/theme_controller.dart';
import '../../core/api_client.dart';
import '../../core/photo_service.dart';
import '../../shared/widgets/content_width.dart';
import '../../shared/widgets/foundation_avatar.dart';
import '../../shared/widgets/message_box.dart';
import '../auth/auth_controller.dart';
import '../auth/two_factor_card.dart';
import '../foundations/foundation_service.dart';
import 'members_section.dart';
import '../map/map_service.dart';

// Mismo mínimo que el backend (schemas/foundation.py): la descripción se muestra en el mapa y en el perfil público
const descriptionMin = 20;
const descriptionMax = 1000;

// Pestaña derecha de la vista de fundación: foto de perfil y descripción (obligatoria), que los adoptantes
// ven al tocar su pin en el mapa y en la pestaña Fundaciones. Arriba a la derecha cambia entre modo claro y
// oscuro (luna / sol) y abajo se cierra sesión.
class FoundationProfileScreen extends StatefulWidget {
  const FoundationProfileScreen({super.key});

  @override
  State<FoundationProfileScreen> createState() => _FoundationProfileScreenState();
}

class _FoundationProfileScreenState extends State<FoundationProfileScreen> {
  late final _api = AuthScope.of(context).api;
  late final FoundationService _service = FoundationService(_api);
  final _description = TextEditingController();

  Foundation? _foundation;
  bool _loading = true;
  String? _loadError;
  bool _started = false;

  String? _photoUrl;
  bool _uploading = false;
  bool _saving = false;
  String? _descriptionError;
  String? _error;
  String? _saved;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  @override
  void dispose() {
    _description.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final foundation = await _service.fetchMine();
      if (!mounted) return;
      setState(() {
        _foundation = foundation;
        _photoUrl = foundation.photoUrl;
        _description.text = foundation.description ?? '';
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = errorMessage(error, 'No pudimos cargar el perfil de tu fundación.');
        _loading = false;
      });
    }
  }

  Future<void> _pickPhoto(PhotoSource source) async {
    final PickedPhoto? photo;
    try {
      photo = await PhotoService.instance.pick(source);
    } on PlatformException {
      if (!mounted) return;
      setState(() => _error = source == PhotoSource.camera
          ? 'No pudimos abrir la cámara. Revisa el permiso o elige una foto de la galería.'
          : 'No pudimos abrir la galería. Inténtalo nuevamente.');
      return;
    }
    if (photo == null || !mounted) return;
    setState(() {
      _uploading = true;
      _error = null;
      _saved = null;
    });
    try {
      final url = await MapService(_api).uploadPhoto(photo);
      if (!mounted) return;
      setState(() {
        _photoUrl = url;
        _uploading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _uploading = false;
        _error = errorMessage(error, 'No se pudo subir la foto. Inténtalo nuevamente.');
      });
    }
  }

  String? _validateDescription(String text) {
    final clean = text.trim();
    if (clean.isEmpty) return 'Escribe una descripción de tu fundación.';
    if (clean.length < descriptionMin) return 'La descripción debe tener al menos $descriptionMin caracteres.';
    return null;
  }

  Future<void> _save() async {
    final invalid = _validateDescription(_description.text);
    setState(() {
      _descriptionError = invalid;
      _error = null;
      _saved = null;
    });
    if (invalid != null) return;

    setState(() => _saving = true);
    try {
      final foundation = await _service.updateMine(description: _description.text.trim(), photoUrl: _photoUrl);
      if (!mounted) return;
      setState(() {
        _foundation = foundation;
        _photoUrl = foundation.photoUrl;
        _description.text = foundation.description ?? '';
        _saving = false;
        _saved = 'Perfil guardado. Así te verán los adoptantes en el mapa.';
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = errorMessage(error, 'No se pudo guardar el perfil. Inténtalo nuevamente.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil'), actions: const [_ThemeToggle(), SizedBox(width: AdoptifySpacing.xs)]),
      body: ContentWidth(child: _body()),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final foundation = _foundation;
    if (foundation == null) {
      return ListView(
        padding: const EdgeInsets.all(AdoptifySpacing.xl),
        children: [
          MessageBox.error(message: _loadError ?? 'No pudimos cargar el perfil de tu fundación.'),
          const SizedBox(height: AdoptifySpacing.lg),
          FilledButton(onPressed: _load, child: const Text('Reintentar')),
          const SizedBox(height: AdoptifySpacing.md),
          const _SignOutButton(),
        ],
      );
    }

    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final busy = _saving || _uploading;
    return ListView(
      padding: const EdgeInsets.fromLTRB(AdoptifySpacing.xl, AdoptifySpacing.sm, AdoptifySpacing.xl, AdoptifySpacing.xl),
      children: [
        Center(
          child: Stack(
            alignment: Alignment.center,
            children: [
              FoundationAvatar(name: foundation.name, photoUrl: _photoUrl, size: 112, color: colors.foundation),
              if (_uploading)
                const SizedBox.square(dimension: 32, child: CircularProgressIndicator()),
            ],
          ),
        ),
        const SizedBox(height: AdoptifySpacing.md),
        Text(foundation.name, style: textTheme.titleLarge, textAlign: TextAlign.center),
        Text(foundation.place, style: textTheme.bodySmall, textAlign: TextAlign.center),
        const SizedBox(height: AdoptifySpacing.lg),
        Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : () => _pickPhoto(PhotoSource.camera),
                icon: const Icon(Icons.photo_camera_outlined, size: 20),
                label: const Text('Tomar foto'),
              ),
            ),
            const SizedBox(width: AdoptifySpacing.md),
            Expanded(
              child: OutlinedButton.icon(
                onPressed: busy ? null : () => _pickPhoto(PhotoSource.gallery),
                icon: const Icon(Icons.photo_library_outlined, size: 20),
                label: const Text('Galería'),
              ),
            ),
          ],
        ),
        if (_photoUrl != null)
          Center(
            child: TextButton.icon(
              onPressed: busy ? null : () => setState(() => _photoUrl = null),
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Quitar foto'),
            ),
          ),
        Text('Foto de perfil (opcional). JPG o PNG, hasta 5 MB.', style: textTheme.bodySmall, textAlign: TextAlign.center),
        const SizedBox(height: AdoptifySpacing.xl),
        TextField(
          controller: _description,
          minLines: 4,
          maxLines: 8,
          maxLength: descriptionMax,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) {
            if (_descriptionError != null) setState(() => _descriptionError = null);
          },
          decoration: InputDecoration(
            labelText: 'Descripción de la fundación *',
            hintText: 'Cuéntales a los adoptantes qué hacen, a qué animales rescatan y cómo adoptar.',
            alignLabelWithHint: true,
            errorText: _descriptionError,
            helperText: 'Obligatoria. Se muestra al tocar tu fundación en el mapa.',
          ),
        ),
        if (_error != null) ...[const SizedBox(height: AdoptifySpacing.md), MessageBox.error(message: _error!)],
        if (_saved != null) ...[const SizedBox(height: AdoptifySpacing.md), MessageBox.success(message: _saved!)],
        const SizedBox(height: AdoptifySpacing.lg),
        FilledButton.icon(
          onPressed: busy ? null : _save,
          icon: _saving
              ? SizedBox.square(
                  dimension: 17,
                  child: CircularProgressIndicator(strokeWidth: 2, color: colors.onAccent),
                )
              : const Icon(Icons.save_outlined, size: 20),
          label: Text(_saving ? 'Guardando…' : 'Guardar perfil'),
        ),
        const SizedBox(height: AdoptifySpacing.xxl),
        MembersSection(service: _service),
        const SizedBox(height: AdoptifySpacing.xl),
        const TwoFactorCard(),
        const SizedBox(height: AdoptifySpacing.xl),
        const _SignOutButton(),
      ],
    );
  }
}

// Sin esto, una cuenta de fundación no podría salir de la app
class _SignOutButton extends StatelessWidget {
  const _SignOutButton();

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        onPressed: AuthScope.of(context).signOut,
        icon: const Icon(Icons.logout, size: 20),
        label: const Text('Cerrar sesión'),
        style: OutlinedButton.styleFrom(
          foregroundColor: context.colors.primaryDark,
          minimumSize: const Size.fromHeight(48),
        ),
      );
}

// Luna en modo claro (pasa a oscuro) y sol en modo oscuro (pasa a claro). Usa el mismo ThemeController que
// la tarjeta Apariencia del Perfil de adoptante, así que la elección se guarda en el dispositivo.
class _ThemeToggle extends StatelessWidget {
  const _ThemeToggle();

  @override
  Widget build(BuildContext context) {
    // brightness ya refleja el modo del sistema cuando no se ha elegido uno
    final dark = Theme.of(context).brightness == Brightness.dark;
    return IconButton(
      onPressed: () => ThemeScope.of(context).setMode(dark ? ThemeMode.light : ThemeMode.dark),
      icon: Icon(dark ? Icons.light_mode_outlined : Icons.dark_mode_outlined),
      tooltip: dark ? 'Cambiar a modo claro' : 'Cambiar a modo oscuro',
    );
  }
}
