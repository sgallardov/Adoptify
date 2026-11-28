import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api_client.dart';
import '../../shared/widgets/content_width.dart';
import '../../shared/widgets/message_box.dart';
import '../../shared/widgets/network_photo.dart';
import '../auth/auth_controller.dart';
import '../map/map_service.dart' show formatDate;
import 'adoption_applications_service.dart';

// "Mis postulaciones" (HU-AC), a pantalla completa desde el Perfil del adoptante.
// Lista las postulaciones de la más reciente a la más antigua y permite retirar las que no están aprobadas.
class MyApplicationsScreen extends StatefulWidget {
  const MyApplicationsScreen({super.key});

  @override
  State<MyApplicationsScreen> createState() => _MyApplicationsScreenState();
}

class _MyApplicationsScreenState extends State<MyApplicationsScreen> {
  late final AdoptionApplicationsService _service = AdoptionApplicationsService(AuthScope.of(context).api);
  List<MyApplication> _applications = const [];
  bool _loading = true;
  bool _started = false;
  String? _loadError;
  // Postulación que se está retirando: bloquea su botón mientras tanto
  int? _withdrawing;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _loadError = null;
    });
    try {
      final applications = await _service.listMine();
      if (!mounted) return;
      setState(() {
        _applications = applications;
        _loading = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _loadError = errorMessage(error, 'No pudimos cargar tus postulaciones.');
        _loading = false;
      });
    }
  }

  Future<void> _withdraw(MyApplication application) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('¿Retirar tu postulación?', textAlign: TextAlign.center),
        content: Text('La fundación dejará de ver tu postulación por ${application.animalName}. '
            'Podrás volver a postular cuando quieras.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
          FilledButton(onPressed: () => Navigator.of(context).pop(true), child: const Text('Retirar')),
        ],
      ),
    );
    if (confirmed == true && mounted) await _doWithdraw(application);
  }

  Future<void> _doWithdraw(MyApplication application) async {
    setState(() => _withdrawing = application.id);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await _service.withdraw(application.id);
      if (!mounted) return;
      setState(() {
        _applications = [for (final a in _applications) if (a.id != application.id) a];
        _withdrawing = null;
      });
      messenger.showSnackBar(const SnackBar(content: Text('Retiraste tu postulación.')));
    } catch (error) {
      if (!mounted) return;
      // La postulación se mantiene en la lista y se ofrece reintentar
      setState(() => _withdrawing = null);
      messenger.showSnackBar(SnackBar(
        content: Text(errorMessage(error, 'No pudimos retirar tu postulación. Inténtalo nuevamente.')),
        action: SnackBarAction(label: 'Reintentar', onPressed: () => _doWithdraw(application)),
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis postulaciones')),
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
    if (_applications.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(AdoptifySpacing.xl),
        children: [
          const SizedBox(height: AdoptifySpacing.xl),
          Icon(Icons.assignment_outlined, size: 48, color: context.colors.textMuted),
          const SizedBox(height: AdoptifySpacing.md),
          Text(
            'Todavía no postulaste a ningún animal.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: AdoptifySpacing.lg),
          FilledButton(onPressed: () => context.go('/mapa'), child: const Text('Explorar animales')),
        ],
      );
    }
    return ListView.separated(
      padding: const EdgeInsets.all(AdoptifySpacing.lg),
      itemCount: _applications.length,
      separatorBuilder: (_, _) => const SizedBox(height: AdoptifySpacing.md),
      itemBuilder: (context, index) {
        final application = _applications[index];
        return _ApplicationCard(
          application: application,
          withdrawing: _withdrawing == application.id,
          onWithdraw: () => _withdraw(application),
        );
      },
    );
  }
}

class _ApplicationCard extends StatelessWidget {
  const _ApplicationCard({required this.application, required this.withdrawing, required this.onWithdraw});

  final MyApplication application;
  final bool withdrawing;
  final VoidCallback onWithdraw;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final photo = application.photoUrl;
    final placeholder = Container(
      color: colors.muted,
      child: Icon(Icons.pets, color: colors.textMuted),
    );
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
        border: Border.all(color: colors.border),
        boxShadow: AdoptifyShadows.soft,
      ),
      clipBehavior: Clip.antiAlias,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            onTap: () => context.push('/animales/${application.animalId}'),
            child: Padding(
              padding: const EdgeInsets.all(AdoptifySpacing.md),
              child: Row(
                children: [
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AdoptifyRadius.md),
                    child: SizedBox(
                      width: 72,
                      height: 72,
                      child: photo == null
                          ? placeholder
                          : NetworkPhoto(url: photo, pixelsWide: 72, fallback: placeholder),
                    ),
                  ),
                  const SizedBox(width: AdoptifySpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(application.animalName, style: textTheme.titleMedium),
                        Text(application.foundationName, style: textTheme.bodyMedium),
                        Text('Enviada el ${formatDate(application.createdAt)}', style: textTheme.bodySmall),
                        const SizedBox(height: AdoptifySpacing.xs),
                        _StatusChip(application: application),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: colors.textMuted),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(AdoptifySpacing.md, 0, AdoptifySpacing.md, AdoptifySpacing.sm),
            child: application.canWithdraw
                ? Align(
                    alignment: Alignment.centerLeft,
                    child: TextButton.icon(
                      onPressed: withdrawing ? null : onWithdraw,
                      icon: const Icon(Icons.close, size: 18),
                      label: Text(withdrawing ? 'Retirando…' : 'Retirar postulación'),
                    ),
                  )
                : Text(
                    'Fue aprobada: para retirarla, contacta a la fundación.',
                    style: textTheme.bodySmall,
                  ),
          ),
        ],
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.application});

  final MyApplication application;

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final (background, foreground) = switch (application.status) {
      'approved' => (colors.successStrong, colors.onAccent),
      'rejected' => (colors.muted, colors.textMuted),
      _ => (colors.primarySoft, colors.primaryText),
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AdoptifySpacing.sm, vertical: 2),
      decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(99)),
      child: Text(application.statusLabel, style: Theme.of(context).textTheme.labelSmall?.copyWith(color: foreground)),
    );
  }
}
