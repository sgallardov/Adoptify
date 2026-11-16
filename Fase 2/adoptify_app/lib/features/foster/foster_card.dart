import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../auth/auth_controller.dart';
import 'foster_service.dart';

// "Hogar temporal" en el Perfil del adoptante (HU-B): invita a postular o muestra el estado de su postulación.
// El formulario se abre a pantalla completa (/hogar-temporal); al volver, la tarjeta se actualiza.
class FosterCard extends StatefulWidget {
  const FosterCard({super.key});

  @override
  State<FosterCard> createState() => _FosterCardState();
}

class _FosterCardState extends State<FosterCard> {
  FosterApplication? _application;
  bool _loading = true;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started) return;
    _started = true;
    _load();
  }

  Future<void> _load() async {
    try {
      final application = await FosterService(AuthScope.of(context).api).fetchMine();
      if (mounted) setState(() => _application = application);
    } catch (_) {
      // Sin conexión no se bloquea el perfil: la tarjeta invita a postular
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _open() async {
    final changed = await context.push<bool>('/hogar-temporal');
    if (changed == true && mounted) _load();
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final application = _application;
    return Container(
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
        border: Border.all(color: colors.border),
        boxShadow: AdoptifyShadows.soft,
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
        onTap: _loading ? null : _open,
        child: Padding(
          padding: const EdgeInsets.all(AdoptifySpacing.lg),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colors.primarySoft,
                child: Icon(Icons.house_outlined, color: colors.primaryDark),
              ),
              const SizedBox(width: AdoptifySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Flexible(child: Text('Hogar temporal', style: textTheme.titleMedium)),
                        if (application != null) ...[
                          const SizedBox(width: AdoptifySpacing.sm),
                          _StatusChip(application: application),
                        ],
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      application == null
                          ? 'Recibe a un animal rescatado mientras encuentra familia · toca para postular'
                          : 'Hasta ${application.maxAnimals} a la vez · máx. ${application.maxDays} días · '
                              'toca para ${application.isPending ? 'ver o editar' : 'ver'}',
                      style: textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Icon(Icons.chevron_right, color: colors.textMuted),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusChip extends StatelessWidget {
  const _StatusChip({required this.application});

  final FosterApplication application;

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
