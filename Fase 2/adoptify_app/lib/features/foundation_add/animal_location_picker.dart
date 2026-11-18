import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';
import '../../core/api_client.dart';
import '../../core/location_service.dart';
import '../../shared/map/map_style.dart';
import '../../shared/widgets/message_box.dart';
import '../auth/auth_controller.dart';
import 'geocode_service.dart';

const _pickedZoom = 16.0;

// Ubicación privada del animal sin escribir coordenadas: se busca la dirección (o se usa el GPS)
// y el punto se ajusta tocando el mapa.
class AnimalLocationPicker extends StatefulWidget {
  const AnimalLocationPicker({
    super.key,
    required this.value,
    required this.onChanged,
    required this.suggestion,
    this.onCommune,
    this.enabled = true,
  });

  final LatLng? value;
  final ValueChanged<LatLng> onChanged;
  // Texto con el que parte la búsqueda: la dirección del lugar de resguardo
  final TextEditingController suggestion;
  // Comuna reconocida en la dirección elegida
  final ValueChanged<String>? onCommune;
  final bool enabled;

  @override
  State<AnimalLocationPicker> createState() => _AnimalLocationPickerState();
}

class _AnimalLocationPickerState extends State<AnimalLocationPicker> {
  final _query = TextEditingController();
  final _map = MapController();
  bool _edited = false;
  bool _searching = false;
  bool _locating = false;
  List<GeocodeResult>? _results;
  String? _error;
  String? _picked;

  @override
  void initState() {
    super.initState();
    _query.text = widget.suggestion.text;
    widget.suggestion.addListener(_followSuggestion);
  }

  @override
  void dispose() {
    widget.suggestion.removeListener(_followSuggestion);
    _query.dispose();
    _map.dispose();
    super.dispose();
  }

  // Mientras no se escriba aquí, el buscador repite la dirección del lugar de resguardo
  void _followSuggestion() {
    if (!_edited) _query.text = widget.suggestion.text;
  }

  void _move(LatLng position) {
    widget.onChanged(position);
    _map.move(position, _pickedZoom);
  }

  Future<void> _search() async {
    FocusScope.of(context).unfocus();
    final query = _query.text.trim();
    if (query.length < 3) {
      setState(() {
        _error = 'Escribe al menos 3 caracteres de la dirección.';
        _results = null;
      });
      return;
    }
    setState(() {
      _searching = true;
      _error = null;
      _results = null;
    });
    try {
      final results = await GeocodeService(AuthScope.of(context).api).search(query);
      if (!mounted) return;
      setState(() => _results = results);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorMessage(error, 'No pudimos buscar la dirección. Inténtalo nuevamente.'));
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  void _pick(GeocodeResult result) {
    setState(() {
      _picked = result.label;
      _results = null;
    });
    _move(result.position);
    if (result.commune != null) widget.onCommune?.call(result.commune!);
  }

  Future<void> _useMyLocation() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final position = await LocationService.instance.current();
      if (!mounted) return;
      setState(() {
        _picked = 'Tu ubicación actual';
        _results = null;
      });
      _move(position);
    } on LocationException catch (error) {
      if (mounted) setState(() => _error = error.message);
    } finally {
      if (mounted) setState(() => _locating = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final busy = !widget.enabled || _searching || _locating;
    final value = widget.value;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          key: const ValueKey('address-search'),
          controller: _query,
          enabled: !busy,
          maxLength: 200,
          textInputAction: TextInputAction.search,
          onChanged: (_) => _edited = true,
          onSubmitted: (_) => _search(),
          decoration: InputDecoration(
            labelText: 'Buscar dirección',
            hintText: 'Ej.: Av. Grecia 100, Ñuñoa',
            suffixIcon: IconButton(
              tooltip: 'Buscar dirección',
              icon: _searching
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.search),
              onPressed: busy ? null : _search,
            ),
          ),
        ),
        Align(
          alignment: Alignment.centerLeft,
          child: TextButton.icon(
            onPressed: busy ? null : _useMyLocation,
            icon: _locating
                ? const SizedBox.square(dimension: 16, child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.my_location, size: 18),
            label: const Text('Usar mi ubicación actual'),
          ),
        ),
        if (_error != null) ...[MessageBox.error(message: _error!), const SizedBox(height: AdoptifySpacing.sm)],
        if (_results != null && _results!.isEmpty) ...[
          const MessageBox.error(message: 'No encontramos esa dirección. Prueba agregando la comuna o una calle cercana.'),
          const SizedBox(height: AdoptifySpacing.sm),
        ],
        if (_results != null && _results!.isNotEmpty)
          Card(
            margin: const EdgeInsets.only(bottom: AdoptifySpacing.sm),
            child: Column(
              children: [
                for (final result in _results!)
                  ListTile(
                    leading: Icon(Icons.place_outlined, color: context.colors.primaryDark),
                    title: Text(result.label, style: textTheme.bodyMedium, maxLines: 2, overflow: TextOverflow.ellipsis),
                    subtitle: result.commune == null ? null : Text('Comuna: ${result.commune}'),
                    onTap: () => _pick(result),
                  ),
              ],
            ),
          ),
        ClipRRect(
          borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
          child: Container(
            height: 220,
            decoration: BoxDecoration(border: Border.all(color: context.colors.border)),
            child: FlutterMap(
              mapController: _map,
              options: MapOptions(
                initialCenter: value ?? santiago,
                initialZoom: value == null ? 11 : _pickedZoom,
                interactionOptions: const InteractionOptions(flags: InteractiveFlag.all & ~InteractiveFlag.rotate),
                // Tocar el mapa ajusta el punto
                onTap: (_, point) {
                  if (!widget.enabled) return;
                  setState(() => _picked = null);
                  widget.onChanged(point);
                },
              ),
              children: [
                const OsmTileLayer(),
                if (value != null) MarkerLayer(markers: [mapMarker(value, MapPins.animal, key: const ValueKey('animal-location'))]),
                osmAttribution(context),
              ],
            ),
          ),
        ),
        const SizedBox(height: AdoptifySpacing.xs),
        Text(
          value == null
              ? 'Busca la dirección o toca el mapa para marcar dónde está. Sin ubicación, no aparecerá en las búsquedas por cercanía.'
              : _picked == null
                  ? 'Punto marcado. Toca el mapa para ajustarlo.'
                  : 'Ubicado en: $_picked. Toca el mapa para ajustarlo.',
          style: textTheme.bodySmall,
        ),
      ],
    );
  }
}
