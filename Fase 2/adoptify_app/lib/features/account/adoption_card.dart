import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/api_client.dart';
import '../../shared/widgets/message_box.dart';
import '../auth/auth_controller.dart';
import 'adoption_service.dart';

// Opciones del formulario: [valor que guardará la API, texto que ve el usuario]
typedef _Option = (String, String);

const _housing = <_Option>[('casa_patio', 'Casa con patio'), ('casa_sin_patio', 'Casa sin patio'), ('departamento', 'Departamento')];
const _yesNo = <_Option>[('si', 'Sí'), ('no', 'No')];
const _hoursAlone = <_Option>[('0_2', 'Menos de 2 h'), ('2_5', '2 a 5 h'), ('5_8', '5 a 8 h'), ('8_mas', 'Más de 8 h')];
const _activity = <_Option>[('bajo', 'Tranquilo'), ('medio', 'Moderado'), ('alto', 'Muy activo')];
const _experience = <_Option>[('ninguna', 'Ninguna'), ('algo', 'Algo'), ('mucha', 'Mucha')];
const _species = <_Option>[('perro', 'Perro'), ('gato', 'Gato')];
const _sizes = <_Option>[('pequeño', 'Pequeño'), ('mediano', 'Mediano'), ('grande', 'Grande')];
const _ages = <_Option>[('cachorro', 'Cachorro'), ('adulto', 'Adulto'), ('senior', 'Senior')];

// "Quiero adoptar" en el perfil: es opcional y se despliega al tocarlo. Quien solo reporta no lo completa.
// Se carga y se guarda con GET/PUT /users/me/adoption-profile.
class AdoptionCard extends StatefulWidget {
  const AdoptionCard({super.key});

  @override
  State<AdoptionCard> createState() => _AdoptionCardState();
}

class _AdoptionCardState extends State<AdoptionCard> {
  bool _open = false;
  bool _saved = false;
  bool _saving = false;
  bool _loaded = false;
  String? _error;
  List<String> _missing = const [];

  String? _housingType;
  String? _hasKids;
  String? _hasPets;
  String? _hoursAloneValue;
  String? _activityLevel;
  String? _experienceLevel;
  final Set<String> _wantedSpecies = {};
  final Set<String> _wantedSizes = {};
  final Set<String> _wantedAges = {};
  bool _acceptsFollowUp = true;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loaded) return;
    _loaded = true;
    _load();
  }

  AdoptionService get _service => AdoptionService(AuthScope.of(context).api);

  // Si ya completó el formulario antes, lo muestra para poder editarlo
  Future<void> _load() async {
    try {
      final profile = await _service.fetch();
      if (!mounted || profile == null) return;
      setState(() {
        _saved = true;
        _housingType = profile.housingType;
        _hasKids = profile.hasKids;
        _hasPets = profile.hasPets;
        _hoursAloneValue = profile.hoursAlone;
        _activityLevel = profile.activityLevel;
        _experienceLevel = profile.experience;
        _wantedSpecies..clear()..addAll(profile.wantedSpecies);
        _wantedSizes..clear()..addAll(profile.wantedSizes);
        _wantedAges..clear()..addAll(profile.wantedAges);
        _acceptsFollowUp = profile.acceptsFollowUp;
      });
    } on ApiException {
      // Sin conexión no se bloquea el perfil: el formulario se muestra vacío
    }
  }

  Future<void> _save() async {
    final missing = <String>[
      if (_housingType == null) 'Tipo de vivienda',
      if (_hasKids == null) 'Niños en casa',
      if (_hasPets == null) 'Otras mascotas',
      if (_hoursAloneValue == null) 'Horas solo',
      if (_wantedSpecies.isEmpty) 'Especie',
      if (_wantedSizes.isEmpty) 'Tamaño',
    ];
    setState(() {
      _missing = missing;
      _error = null;
    });
    if (missing.isNotEmpty) return;

    setState(() => _saving = true);
    try {
      await _service.save(AdoptionProfile(
        housingType: _housingType!,
        hasKids: _hasKids!,
        hasPets: _hasPets!,
        hoursAlone: _hoursAloneValue!,
        activityLevel: _activityLevel,
        experience: _experienceLevel,
        wantedSpecies: _wantedSpecies,
        wantedSizes: _wantedSizes,
        wantedAges: _wantedAges,
        acceptsFollowUp: _acceptsFollowUp,
      ));
      if (!mounted) return;
      setState(() {
        _saved = true;
        _open = false;
        _saving = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(error, 'No pudimos guardar tus preferencias. Inténtalo nuevamente.');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
        border: Border.all(color: colors.border),
        boxShadow: AdoptifyShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
            onTap: () => setState(() => _open = !_open),
            child: Padding(
              padding: const EdgeInsets.all(AdoptifySpacing.lg),
              child: Row(
                children: [
                  CircleAvatar(
                    backgroundColor: colors.primarySoft,
                    child: Icon(Icons.favorite_border, color: colors.primaryDark),
                  ),
                  const SizedBox(width: AdoptifySpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Quiero adoptar', style: textTheme.titleMedium),
                        const SizedBox(height: 2),
                        Text(
                          _saved ? 'Preferencias guardadas · toca para editar' : 'Opcional · cuéntanos de tu hogar para encontrar tu match',
                          style: textTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  Icon(_open ? Icons.expand_less : Icons.expand_more, color: colors.textMuted),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(AdoptifySpacing.lg, 0, AdoptifySpacing.lg, AdoptifySpacing.lg),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Divider(),
                  _Section('Tu hogar'),
                  _Single('Tipo de vivienda', _housing, _housingType, (v) => setState(() => _housingType = v)),
                  _Single('¿Hay niños en casa?', _yesNo, _hasKids, (v) => setState(() => _hasKids = v)),
                  _Single('¿Tienes otras mascotas?', _yesNo, _hasPets, (v) => setState(() => _hasPets = v)),
                  _Section('Tu estilo de vida'),
                  _Single('Horas al día que estaría solo', _hoursAlone, _hoursAloneValue, (v) => setState(() => _hoursAloneValue = v)),
                  _Single('Tu nivel de actividad', _activity, _activityLevel, (v) => setState(() => _activityLevel = v)),
                  _Single('Experiencia con mascotas', _experience, _experienceLevel, (v) => setState(() => _experienceLevel = v)),
                  _Section('Qué buscas'),
                  _Multi('Especie', _species, _wantedSpecies, () => setState(() {})),
                  _Multi('Tamaño', _sizes, _wantedSizes, () => setState(() {})),
                  _Multi('Edad (opcional)', _ages, _wantedAges, () => setState(() {})),
                  // Row y no SwitchListTile: un ListTile sobre el fondo de la tarjeta oculta su efecto al tocar
                  const SizedBox(height: AdoptifySpacing.sm),
                  Row(
                    children: [
                      const Expanded(child: Text('Acepto una visita de seguimiento')),
                      Switch(value: _acceptsFollowUp, onChanged: (v) => setState(() => _acceptsFollowUp = v)),
                    ],
                  ),
                  const SizedBox(height: AdoptifySpacing.sm),
                  if (_missing.isNotEmpty) ...[
                    MessageBox.error(message: 'Revisa: ${_missing.join(', ')}.'),
                    const SizedBox(height: AdoptifySpacing.md),
                  ],
                  if (_error != null) ...[
                    MessageBox.error(message: _error!),
                    const SizedBox(height: AdoptifySpacing.md),
                  ],
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Text(_saving ? 'Guardando…' : 'Guardar preferencias'),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  const _Section(this.title);

  final String title;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AdoptifySpacing.md, bottom: AdoptifySpacing.xs),
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

// Una sola opción
class _Single extends StatelessWidget {
  const _Single(this.label, this.options, this.value, this.onChanged);

  final String label;
  final List<_Option> options;
  final String? value;
  final ValueChanged<String> onChanged;

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
                ChoiceChip(label: Text(text), selected: value == id, onSelected: (_) => onChanged(id)),
            ],
          ),
        ],
      );
}

// Varias opciones; vacío equivale a "me da igual" para el motor de match
class _Multi extends StatelessWidget {
  const _Multi(this.label, this.options, this.selected, this.onChanged);

  final String label;
  final List<_Option> options;
  final Set<String> selected;
  final VoidCallback onChanged;

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
                FilterChip(
                  label: Text(text),
                  selected: selected.contains(id),
                  onSelected: (on) {
                    on ? selected.add(id) : selected.remove(id);
                    onChanged();
                  },
                ),
            ],
          ),
        ],
      );
}
