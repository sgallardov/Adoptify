import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/api_client.dart';
import '../../shared/widgets/content_width.dart';
import '../../shared/widgets/message_box.dart';
import '../auth/auth_controller.dart';
import 'foster_service.dart';

const _maxAnimalsLimit = 10;

// Postular como hogar temporal (HU-B), a pantalla completa desde el Perfil del adoptante.
// Es general: no se elige fundación. Mientras está en revisión se puede editar; después, solo retirar.
// Al cerrar devuelve true si algo cambió, para que la tarjeta del Perfil se actualice.
class FosterScreen extends StatefulWidget {
  const FosterScreen({super.key});

  @override
  State<FosterScreen> createState() => _FosterScreenState();
}

class _FosterScreenState extends State<FosterScreen> {
  late final FosterService _service = FosterService(AuthScope.of(context).api);
  final _formKey = GlobalKey<FormState>();
  final _phone = TextEditingController();
  final _address = TextEditingController();
  final _maxDays = TextEditingController();
  final _availability = TextEditingController();

  FosterApplication? _application;
  bool _loading = true;
  String? _loadError;
  bool _started = false;

  String? _species;
  final Set<String> _sizes = {};
  String? _space;
  int _maxAnimals = 1;

  bool _saving = false;
  String? _error;
  List<String> _missing = const [];

  bool get _editable => _application == null || _application!.isPending;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  @override
  void dispose() {
    _phone.dispose();
    _address.dispose();
    _maxDays.dispose();
    _availability.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final application = await _service.fetchMine();
      if (!mounted) return;
      setState(() {
        _application = application;
        _loading = false;
        if (application != null) {
          _species = application.species;
          _sizes..clear()..addAll(application.sizes);
          _space = application.space;
          _maxAnimals = application.maxAnimals;
          _maxDays.text = '${application.maxDays}';
          _availability.text = application.availability;
          _phone.text = application.phone;
          _address.text = application.address;
        }
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = errorMessage(error, 'No pudimos cargar tu postulación.');
        _loading = false;
      });
    }
  }

  Future<void> _save() async {
    FocusScope.of(context).unfocus();
    _formKey.currentState!.validate();
    // Junto al botón se listan todos los pendientes: los errores de arriba pueden quedar fuera de la pantalla
    final missing = <String>[
      if (_validatePhone(_phone.text) != null) 'Teléfono',
      if (_validateAddress(_address.text) != null) 'Dirección',
      if (_species == null) 'Tipo de mascota',
      if (_sizes.isEmpty) 'Tamaño',
      if (_validateMaxDays(_maxDays.text) != null) 'Días máximos',
      if (_space == null) 'Espacio',
      if (_availability.text.trim().isEmpty) 'Disponibilidad',
    ];
    setState(() {
      _missing = missing;
      _error = null;
    });
    if (missing.isNotEmpty) return;

    setState(() => _saving = true);
    try {
      await _service.save(
        FosterApplication(
          species: _species!,
          sizes: _sizes,
          space: _space!,
          maxAnimals: _maxAnimals,
          maxDays: int.parse(_maxDays.text),
          availability: _availability.text.trim(),
          phone: _phone.text.trim(),
          address: _address.text.trim(),
        ),
        exists: _application != null,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            _application == null
                ? 'Postulación enviada. Las fundaciones la revisarán.'
                : 'Guardamos los cambios de tu postulación.',
          ),
        ),
      );
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = errorMessage(error, 'No pudimos guardar tu postulación. Inténtalo nuevamente.');
      });
    }
  }

  String? _validatePhone(String? value) {
    final digits = (value ?? '').replaceAll(RegExp(r'\D'), '');
    if (digits.isEmpty) return 'Escribe tu teléfono.';
    if (digits.length < 8 || digits.length > 15) return 'Escribe un teléfono válido, por ejemplo +56 9 1234 5678.';
    return null;
  }

  String? _validateAddress(String? value) {
    final text = (value ?? '').trim();
    if (text.isEmpty) return 'Escribe tu dirección.';
    if (text.length < 5) return 'Escribe la dirección completa (calle, número y comuna).';
    return null;
  }

  String? _validateMaxDays(String? value) {
    final days = int.tryParse(value ?? '');
    if (days == null) return 'Escribe cuántos días como máximo.';
    if (days < 1 || days > 365) return 'Debe ser entre 1 y 365 días.';
    return null;
  }

  Future<void> _withdraw() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Retirar tu postulación?', textAlign: TextAlign.center),
        content: const Text('Las fundaciones dejarán de verla. Podrás volver a postular cuando quieras.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Retirar')),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await _service.withdraw();
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Retiraste tu postulación.')));
      Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = errorMessage(error, 'No pudimos retirar tu postulación. Inténtalo nuevamente.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Hogar temporal')),
      body: SafeArea(top: false, child: ContentWidth(child: _body())),
    );
  }

  Widget _body() {
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_loadError != null) {
      return ListView(
        padding: const EdgeInsets.all(AdoptifySpacing.xl),
        children: [
          MessageBox.error(message: _loadError!),
          const SizedBox(height: AdoptifySpacing.lg),
          FilledButton(onPressed: _load, child: const Text('Reintentar')),
        ],
      );
    }

    final user = AuthScope.of(context).user;
    final textTheme = Theme.of(context).textTheme;
    final application = _application;
    return Form(
      key: _formKey,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(AdoptifySpacing.lg, AdoptifySpacing.sm, AdoptifySpacing.lg, AdoptifySpacing.xl),
        children: [
          Text(
            'Recibe en tu casa a un animal rescatado mientras encuentra una familia. Tu postulación la verán '
            'todas las fundaciones, y la que te necesite te contactará.',
            style: textTheme.bodyMedium,
          ),
          if (application != null) ...[
            const SizedBox(height: AdoptifySpacing.lg),
            _StatusBanner(application: application),
          ],
          const _Section('Tus datos de contacto'),
          _AccountRow(icon: Icons.person_outline, label: 'Nombre', value: user?.fullName ?? ''),
          _AccountRow(icon: Icons.mail_outline, label: 'Correo', value: user?.email ?? ''),
          Text('Se toman de tu cuenta.', style: textTheme.bodySmall),
          const SizedBox(height: AdoptifySpacing.md),
          TextFormField(
            controller: _phone,
            enabled: _editable,
            keyboardType: TextInputType.phone,
            autofillHints: const [AutofillHints.telephoneNumber],
            maxLength: 30,
            decoration: const InputDecoration(labelText: 'Teléfono *', hintText: '+56 9 1234 5678', counterText: ''),
            validator: _validatePhone,
          ),
          const SizedBox(height: AdoptifySpacing.md),
          TextFormField(
            controller: _address,
            enabled: _editable,
            maxLength: 255,
            textCapitalization: TextCapitalization.sentences,
            autofillHints: const [AutofillHints.fullStreetAddress],
            decoration: const InputDecoration(
              labelText: 'Dirección *',
              hintText: 'Calle, número y comuna',
              helperText: 'Privada: solo la verán las fundaciones.',
              prefixIcon: Icon(Icons.lock_outline, size: 20),
            ),
            validator: _validateAddress,
          ),
          const _Section('Qué puedes recibir'),
          _Choices(
            label: 'Tipo de mascota *',
            options: fosterSpecies,
            isSelected: (id) => _species == id,
            onTap: _editable ? (id) => setState(() => _species = id) : null,
          ),
          _Choices(
            label: 'Tamaño * (puedes elegir varios)',
            options: fosterSizes,
            multiple: true,
            isSelected: _sizes.contains,
            onTap: _editable ? (id) => setState(() => _sizes.contains(id) ? _sizes.remove(id) : _sizes.add(id)) : null,
          ),
          const _Label('¿Cuántos a la vez? *'),
          Row(
            children: [
              IconButton.outlined(
                onPressed: _editable && _maxAnimals > 1 ? () => setState(() => _maxAnimals--) : null,
                icon: const Icon(Icons.remove),
                tooltip: 'Menos',
              ),
              SizedBox(
                width: 64,
                child: Text(
                  '$_maxAnimals',
                  textAlign: TextAlign.center,
                  style: textTheme.titleLarge,
                  semanticsLabel: '$_maxAnimals ${_maxAnimals == 1 ? 'animal' : 'animales'} a la vez',
                ),
              ),
              IconButton.outlined(
                onPressed: _editable && _maxAnimals < _maxAnimalsLimit ? () => setState(() => _maxAnimals++) : null,
                icon: const Icon(Icons.add),
                tooltip: 'Más',
              ),
            ],
          ),
          const SizedBox(height: AdoptifySpacing.md),
          TextFormField(
            controller: _maxDays,
            enabled: _editable,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(3)],
            decoration: const InputDecoration(
              labelText: 'Días máximos que puedes tenerlo *',
              hintText: 'Por ejemplo 30',
              suffixText: 'días',
            ),
            validator: _validateMaxDays,
          ),
          const _Section('Tu hogar'),
          _Choices(
            label: 'Espacio *',
            options: fosterSpaces,
            isSelected: (id) => _space == id,
            onTap: _editable ? (id) => setState(() => _space = id) : null,
          ),
          const SizedBox(height: AdoptifySpacing.md),
          TextFormField(
            controller: _availability,
            enabled: _editable,
            maxLength: 120,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              labelText: 'Disponibilidad *',
              hintText: 'Por ejemplo: desde ya, todos los días',
            ),
            validator: (value) => (value ?? '').trim().isEmpty ? 'Cuéntanos tu disponibilidad.' : null,
          ),
          if (_missing.isNotEmpty) ...[
            const SizedBox(height: AdoptifySpacing.md),
            MessageBox.error(message: 'Revisa: ${_missing.join(', ')}.'),
          ],
          if (_error != null) ...[
            const SizedBox(height: AdoptifySpacing.md),
            MessageBox.error(message: _error!),
          ],
          const SizedBox(height: AdoptifySpacing.lg),
          if (_editable)
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(
                _saving
                    ? 'Guardando…'
                    : application == null
                        ? 'Enviar postulación'
                        : 'Guardar cambios',
              ),
            ),
          if (application != null) ...[
            const SizedBox(height: AdoptifySpacing.sm),
            TextButton.icon(
              onPressed: _saving ? null : _withdraw,
              icon: const Icon(Icons.close, size: 18),
              label: const Text('Retirar postulación'),
            ),
          ],
        ],
      ),
    );
  }
}

// Estado de la postulación. Ya revisada, el formulario queda solo para leer.
class _StatusBanner extends StatelessWidget {
  const _StatusBanner({required this.application});

  final FosterApplication application;

  @override
  Widget build(BuildContext context) {
    final message = switch (application.status) {
      'approved' => 'Una fundación aprobó tu postulación y te contactará para coordinar.',
      'rejected' => 'Por ahora no fue aprobada. Puedes retirarla y volver a postular más adelante.',
      _ => 'Las fundaciones están revisando tu postulación. Puedes editarla mientras tanto.',
    };
    return application.status == 'rejected'
        ? MessageBox.error(message: '${application.statusLabel}: $message')
        : MessageBox.success(message: '${application.statusLabel}: $message');
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AdoptifySpacing.xl, bottom: AdoptifySpacing.sm),
        child: Text(title, style: Theme.of(context).textTheme.titleSmall?.copyWith(color: context.colors.primaryText)),
      );
}

class _Label extends StatelessWidget {
  const _Label(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AdoptifySpacing.md, bottom: AdoptifySpacing.sm),
        child: Text(text, style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w500)),
      );
}

// Dato de la cuenta que no se edita aquí
class _AccountRow extends StatelessWidget {
  const _AccountRow({required this.icon, required this.label, required this.value});

  final IconData icon;
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AdoptifySpacing.xs),
      child: Row(
        children: [
          Icon(icon, size: 20, color: context.colors.textMuted),
          const SizedBox(width: AdoptifySpacing.sm),
          Text('$label: ', style: textTheme.bodyMedium?.copyWith(color: context.colors.textMuted)),
          Expanded(child: Text(value, style: textTheme.bodyMedium, overflow: TextOverflow.ellipsis)),
        ],
      ),
    );
  }
}

// Chips de una opción (ChoiceChip) o de varias (FilterChip). Sin onTap quedan solo para leer.
class _Choices extends StatelessWidget {
  const _Choices({
    required this.label,
    required this.options,
    required this.isSelected,
    required this.onTap,
    this.multiple = false,
  });

  final String label;
  final List<FosterOption> options;
  final bool Function(String id) isSelected;
  final ValueChanged<String>? onTap;
  final bool multiple;

  @override
  Widget build(BuildContext context) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Label(label),
          Wrap(
            spacing: AdoptifySpacing.sm,
            runSpacing: AdoptifySpacing.sm,
            children: [
              for (final (id, text) in options)
                multiple
                    ? FilterChip(
                        label: Text(text),
                        selected: isSelected(id),
                        onSelected: onTap == null ? null : (_) => onTap!(id),
                      )
                    : ChoiceChip(
                        label: Text(text),
                        selected: isSelected(id),
                        onSelected: onTap == null ? null : (_) => onTap!(id),
                      ),
            ],
          ),
        ],
      );
}
