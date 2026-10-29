import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:go_router/go_router.dart';
import 'package:latlong2/latlong.dart';

import '../../app/theme.dart';
import '../../core/api_client.dart';
import '../../core/location_service.dart';
import '../../shared/map/map_style.dart';
import '../../shared/widgets/coming_soon.dart';
import '../../shared/widgets/message_box.dart';
import '../auth/auth_controller.dart';
import '../map/map_service.dart';

const _minDescription = 10;
const _maxDescription = 1000;

// Formulario para reportar un perro abandonado: equivalente a /reportar del portal
class ReportScreen extends StatelessWidget {
  const ReportScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final auth = AuthScope.of(context);
    return Scaffold(
      appBar: AppBar(title: const Text('Reportar')),
      body: auth.loading
          ? const Center(child: CircularProgressIndicator())
          : auth.user == null
          ? const _LoginRequired()
          : const _ReportForm(),
    );
  }
}

// Igual que en la web, reportar requiere una cuenta (POST /reports pide token)
class _LoginRequired extends StatelessWidget {
  const _LoginRequired();

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Expanded(
          child: ComingSoon(
            icon: Icons.add_location_alt,
            title: 'Reportar un perro abandonado',
            message: 'Inicia sesión para reportar. Tu nombre y tus datos no se publican.',
          ),
        ),
        Padding(
          padding: const EdgeInsets.all(20),
          child: FilledButton(
            onPressed: () => context.push('/login'),
            child: const Text('Iniciar sesión'),
          ),
        ),
      ],
    );
  }
}

class _ReportForm extends StatefulWidget {
  const _ReportForm();

  @override
  State<_ReportForm> createState() => _ReportFormState();
}

class _ReportFormState extends State<_ReportForm> {
  final _description = TextEditingController();
  final _mapController = MapController();

  LatLng? _position;
  bool _locating = false;
  bool _sending = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _description.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _description.dispose();
    _mapController.dispose();
    super.dispose();
  }

  void _place(LatLng position, {bool follow = false}) {
    setState(() => _position = position);
    // Al usar el GPS, el mapa se centra en el punto (igual que FollowValue en la web)
    if (follow) {
      _mapController.move(position, math.max(_mapController.camera.zoom, 16));
    }
  }

  Future<void> _locate() async {
    setState(() {
      _locating = true;
      _error = null;
    });
    try {
      final position = await LocationService.instance.current();
      if (!mounted) return;
      setState(() => _locating = false);
      _place(position, follow: true);
    } on LocationException catch (error) {
      if (!mounted) return;
      setState(() {
        _error = '${error.message} Marca el punto en el mapa.';
        _locating = false;
      });
    }
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    final position = _position;
    final description = _description.text.trim();
    if (position == null) {
      setState(() => _error = 'Marca en el mapa dónde está el perro.');
      return;
    }
    if (description.length < _minDescription) {
      setState(
        () => _error =
            'Describe al perro con al menos $_minDescription caracteres.',
      );
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final report = await MapService(AuthScope.of(context).api)
          .createReport(position, description);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Gracias! Tu reporte quedó publicado en el mapa.'),
        ),
      );
      setState(() {
        _sending = false;
        _position = null;
        _description.clear();
      });
      // El id del reporte hace que el mapa vuelva a cargar los datos
      context.go('/mapa', extra: report.id);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(
          error,
          'No se pudo enviar el reporte. Inténtalo nuevamente.',
        );
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'AYUDA A UN PERRO',
            style: textTheme.labelMedium?.copyWith(
              color: AdoptifyColors.primaryDark,
              letterSpacing: 1,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Reportar perro abandonado',
            style: textTheme.headlineSmall?.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Marca en el mapa dónde viste al perro y cuéntanos cómo está. Las fundaciones cercanas podrán verlo.',
            style: textTheme.bodyMedium?.copyWith(
              color: AdoptifyColors.textMuted,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            '1. ¿Dónde está el perro?',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          Row(
            children: [
              OutlinedButton.icon(
                onPressed: _locating ? null : _locate,
                icon: _locating
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.my_location, size: 18),
                label: const Text('Usar mi ubicación'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AdoptifyColors.text,
                  backgroundColor: AdoptifyColors.surface,
                  minimumSize: const Size(0, 44),
                  side: const BorderSide(color: AdoptifyColors.border),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  _position != null
                      ? 'Punto marcado. Toca otro lugar del mapa para moverlo.'
                      : 'O toca el mapa para marcar el lugar.',
                  style: const TextStyle(
                    fontSize: 13,
                    color: AdoptifyColors.textMuted,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Container(
              height: 320,
              decoration: BoxDecoration(
                border: Border.all(color: AdoptifyColors.border),
                borderRadius: BorderRadius.circular(16),
              ),
              child: FlutterMap(
                mapController: _mapController,
                options: MapOptions(
                  initialCenter: santiago,
                  initialZoom: 12,
                  onTap: (_, point) => _place(point),
                ),
                children: [
                  osmTileLayer(),
                  if (_position != null)
                    MarkerLayer(
                      markers: [
                        mapMarker(
                          _position!,
                          MapPins.reportPicker,
                          key: const ValueKey('picker'),
                        ),
                      ],
                    ),
                  osmAttribution,
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          const Text(
            '2. Describe al perro y su estado',
            style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 8),
          TextField(
            controller: _description,
            maxLines: 4,
            maxLength: _maxDescription,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(
              hintText: 'Ej.: perro mediano café, con collar rojo, parece herido de una pata. Está cerca del paradero.',
              hintMaxLines: 3,
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AdoptifyColors.muted,
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Text(
              'El reporte muestra solo la ubicación del perro y la descripción. Tu nombre y tus datos no se publican.',
              style: TextStyle(
                fontSize: 12,
                height: 1.5,
                color: AdoptifyColors.textMuted,
              ),
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: 16),
            MessageBox.error(message: _error!),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _sending ? null : _submit,
            icon: _sending
                ? const SizedBox.square(
                    dimension: 17,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.send, size: 18),
            label: Text(
              _sending ? 'Enviando…' : 'Enviar reporte',
              style: const TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
