import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api_client.dart';
import '../../shared/widgets/animal_photo.dart';
import '../../shared/widgets/content_width.dart';
import '../../shared/widgets/foundation_avatar.dart';
import '../auth/auth_controller.dart';
import '../map/map_service.dart';
import 'foundation_service.dart';

// Perfil público. Muestra solo zonas generales de adopción, no ubicaciones privadas.
class FoundationDetailScreen extends StatelessWidget {
  const FoundationDetailScreen({super.key, required this.foundation});
  final Foundation foundation;

  @override
  Widget build(BuildContext context) {
    final animals = foundation.animals;
    final textTheme = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: const Text('Perfil de fundación')),
      body: SafeArea(
        top: false,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AdoptifySpacing.lg,
            AdoptifySpacing.md,
            AdoptifySpacing.lg,
            AdoptifySpacing.xxl,
          ),
          children: [
            ContentWidth(child: _ProfileHeader(foundation: foundation)),
            const SizedBox(height: AdoptifySpacing.xl),
            ContentWidth(
              child: Text(
                'Animales que buscan hogar',
                style: textTheme.titleLarge,
              ),
            ),
            const SizedBox(height: AdoptifySpacing.xs),
            ContentWidth(
              child: Text(
                animals.isEmpty
                    ? 'Esta fundación no tiene casos publicados por ahora.'
                    : 'Conoce a los animales disponibles y revisa su zona aproximada.',
                style: textTheme.bodyMedium?.copyWith(
                  color: context.colors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: AdoptifySpacing.lg),
            if (animals.isEmpty)
              ContentWidth(child: const _NoCases())
            else
              for (final animal in animals) ...[
                ContentWidth(child: _AdoptionAnimalCard(animal: animal)),
                const SizedBox(height: AdoptifySpacing.lg),
              ],
            const SizedBox(height: AdoptifySpacing.sm),
            ContentWidth(child: _PublicMembers(foundationId: foundation.id)),
            const SizedBox(height: AdoptifySpacing.lg),
            const ContentWidth(child: _TrustNote()),
            const SizedBox(height: AdoptifySpacing.lg),
            const ContentWidth(child: _AdoptionProcess()),
          ],
        ),
      ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  const _ProfileHeader({required this.foundation});
  final Foundation foundation;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Container(
      padding: const EdgeInsets.all(AdoptifySpacing.xl),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AdoptifyRadius.xl),
        border: Border.all(color: colors.border),
        boxShadow: AdoptifyShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              foundation.photoUrl != null
                  ? FoundationAvatar(
                      name: foundation.name,
                      photoUrl: foundation.photoUrl,
                      size: 64,
                      color: colors.primaryStrong,
                    )
                  : Container(
                      width: 64,
                      height: 64,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: colors.primarySoft,
                        borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
                      ),
                      child: Icon(
                        Icons.volunteer_activism_outlined,
                        size: 32,
                        color: colors.primaryDark,
                      ),
                    ),
              const SizedBox(width: AdoptifySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(foundation.name, style: textTheme.titleLarge),
                    const SizedBox(height: AdoptifySpacing.xs),
                    foundation.isVerified
                        ? const _VerifiedLabel()
                        : Text(
                            'Fundación registrada',
                            style: textTheme.bodySmall,
                          ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AdoptifySpacing.xl),
          Text(
            foundation.description ?? 'Esta fundación aún no ha compartido una descripción de su labor.',
            style: textTheme.bodyLarge,
          ),
          const SizedBox(height: AdoptifySpacing.xl),
          _InfoLine(icon: Icons.location_on_outlined, text: foundation.place),
          const SizedBox(height: AdoptifySpacing.md),
          _InfoLine(
            icon: Icons.pets_outlined,
            text:
                '${foundation.animals.length} ${foundation.animals.length == 1 ? 'animal disponible' : 'animales disponibles'} para adopción',
          ),
          if (foundation.phone != null || foundation.email.isNotEmpty) ...[
            const SizedBox(height: AdoptifySpacing.xl),
            const Divider(),
            const SizedBox(height: AdoptifySpacing.md),
            Text('Contacto de la fundación', style: textTheme.titleSmall),
            if (foundation.phone != null) ...[
              const SizedBox(height: AdoptifySpacing.sm),
              _InfoLine(icon: Icons.phone_outlined, text: foundation.phone!),
            ],
            const SizedBox(height: AdoptifySpacing.sm),
            _InfoLine(icon: Icons.mail_outline, text: foundation.email),
          ],
        ],
      ),
    );
  }
}

class _VerifiedLabel extends StatelessWidget {
  const _VerifiedLabel();
  @override
  Widget build(BuildContext context) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Icon(Icons.verified, size: 17, color: context.colors.primary),
      const SizedBox(width: AdoptifySpacing.xs),
      Text(
        'Fundación verificada',
        style: Theme.of(context).textTheme.labelMedium
            ?.copyWith(color: context.colors.primaryDark),
      ),
    ],
  );
}

class _InfoLine extends StatelessWidget {
  const _InfoLine({required this.icon, required this.text});
  final IconData icon;
  final String text;
  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Icon(icon, size: 18, color: context.colors.textMuted),
      const SizedBox(width: AdoptifySpacing.sm),
      Expanded(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyMedium
              ?.copyWith(color: context.colors.textMuted),
        ),
      ),
    ],
  );
}

class _AdoptionAnimalCard extends StatelessWidget {
  const _AdoptionAnimalCard({required this.animal});
  final Animal animal;
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    return Material(
      color: colors.surface,
      borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
      child: InkWell(
        onTap: () => context.push('/animales/${animal.id}', extra: animal),
        borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
        child: Container(
          padding: const EdgeInsets.all(AdoptifySpacing.md),
          decoration: BoxDecoration(
            border: Border.all(color: colors.border),
            borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
          ),
          child: Row(
            children: [
              AnimalPhoto(url: animal.photoUrl, size: 96),
              const SizedBox(width: AdoptifySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(animal.name, style: textTheme.titleMedium),
                    const SizedBox(height: AdoptifySpacing.xs),
                    Text(animal.summary, style: textTheme.bodySmall),
                    const SizedBox(height: AdoptifySpacing.sm),
                    Row(
                      children: [
                        Icon(
                          Icons.location_on_outlined,
                          size: 15,
                          color: colors.primaryDark,
                        ),
                        const SizedBox(width: AdoptifySpacing.xs),
                        Expanded(
                          child: Text(
                            animal.publicZone,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: textTheme.bodySmall?.copyWith(
                              color: colors.primaryText,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: AdoptifySpacing.md),
                    Text(
                      'Ver ficha',
                      style: textTheme.labelLarge?.copyWith(
                        color: colors.primaryDark,
                      ),
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

class _NoCases extends StatelessWidget {
  const _NoCases();
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(AdoptifySpacing.xl),
    decoration: BoxDecoration(
      color: context.colors.muted,
      borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
    ),
    child: Column(
      children: [
        Icon(Icons.pets_outlined, size: 32, color: context.colors.placeholder),
        const SizedBox(height: AdoptifySpacing.sm),
        Text(
          'No hay casos publicados',
          style: Theme.of(context).textTheme.titleSmall,
        ),
        const SizedBox(height: AdoptifySpacing.xs),
        Text(
          'Vuelve pronto para conocer sus próximas mascotas disponibles.',
          textAlign: TextAlign.center,
          style: Theme.of(context).textTheme.bodySmall,
        ),
      ],
    ),
  );
}

// "Nuestros socios": solo nombre y fecha de ingreso de los socios que la fundación marcó como públicos.
// Sin socios públicos se muestra un estado vacío en vez de ocultar la sección, para que se entienda que existe.
class _PublicMembers extends StatefulWidget {
  const _PublicMembers({required this.foundationId});
  final int foundationId;

  @override
  State<_PublicMembers> createState() => _PublicMembersState();
}

class _PublicMembersState extends State<_PublicMembers> {
  List<PublicMember>? _members;
  String? _error;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _load();
    }
  }

  Future<void> _load() async {
    setState(() => _error = null);
    try {
      final members = await FoundationService(AuthScope.of(context).api).fetchPublicMembers(widget.foundationId);
      if (!mounted) return;
      setState(() => _members = members);
    } catch (error) {
      if (!mounted) return;
      setState(() => _error = errorMessage(error, 'No pudimos cargar los socios de esta fundación.'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final members = _members;
    return Container(
      padding: const EdgeInsets.all(AdoptifySpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Nuestros socios', style: textTheme.titleLarge),
          const SizedBox(height: AdoptifySpacing.xs),
          Text('Personas que apoyan a esta fundación.', style: textTheme.bodySmall),
          const SizedBox(height: AdoptifySpacing.md),
          if (_error != null) ...[
            Text(_error!, style: textTheme.bodyMedium),
            TextButton(onPressed: _load, child: const Text('Reintentar')),
          ] else if (members == null)
            const Center(child: CircularProgressIndicator())
          else if (members.isEmpty)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(AdoptifySpacing.xl),
              decoration: BoxDecoration(color: colors.muted, borderRadius: BorderRadius.circular(AdoptifyRadius.lg)),
              child: Column(
                children: [
                  Icon(Icons.groups_outlined, size: 32, color: colors.placeholder),
                  const SizedBox(height: AdoptifySpacing.sm),
                  Text('Aún no hay socios públicos', style: textTheme.titleSmall),
                  const SizedBox(height: AdoptifySpacing.xs),
                  Text(
                    'Esta fundación todavía no muestra a sus socios.',
                    textAlign: TextAlign.center,
                    style: textTheme.bodySmall,
                  ),
                ],
              ),
            )
          else
            for (final member in members)
              Padding(
                padding: const EdgeInsets.only(bottom: AdoptifySpacing.sm),
                child: Row(
                  children: [
                    Icon(Icons.favorite_outline, size: 18, color: colors.primaryDark),
                    const SizedBox(width: AdoptifySpacing.sm),
                    Expanded(child: Text(member.name, style: textTheme.bodyMedium)),
                    Text('Desde ${dateToDisplay(member.joinedAt)}', style: textTheme.bodySmall),
                  ],
                ),
              ),
        ],
      ),
    );
  }
}

class _TrustNote extends StatelessWidget {
  const _TrustNote();
  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AdoptifySpacing.lg),
      decoration: BoxDecoration(
        color: colors.primarySoft,
        borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.shield_outlined, color: colors.primaryDark),
          const SizedBox(width: AdoptifySpacing.md),
          Expanded(
            child: Text(
              'La ubicación de cada caso se muestra por zona para cuidar a los animales. La fundación guía el proceso de adopción.',
              style: Theme.of(context).textTheme.bodySmall
                  ?.copyWith(color: colors.primaryText),
            ),
          ),
        ],
      ),
    );
  }
}

// Explica el recorrido sin prometer una adopción automática. La fundación mantiene
// el control de la entrevista y selección de la familia.
class _AdoptionProcess extends StatelessWidget {
  const _AdoptionProcess();

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    return Container(
      padding: const EdgeInsets.all(AdoptifySpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        border: Border.all(color: colors.border),
        borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Así funciona la adopción',
            style: Theme.of(context).textTheme.titleSmall,
          ),
          const SizedBox(height: AdoptifySpacing.md),
          const _ProcessStep(
            number: '1',
            text: 'Conoce la ficha y guarda tus animales favoritos.',
          ),
          const SizedBox(height: AdoptifySpacing.sm),
          const _ProcessStep(
            number: '2',
            text:
                'Completa tu perfil de adopción para mostrar tus preferencias.',
          ),
          const SizedBox(height: AdoptifySpacing.sm),
          const _ProcessStep(
            number: '3',
            text: 'La fundación revisa cada caso y coordina el siguiente paso.',
          ),
        ],
      ),
    );
  }
}

class _ProcessStep extends StatelessWidget {
  const _ProcessStep({required this.number, required this.text});
  final String number;
  final String text;

  @override
  Widget build(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Container(
        width: 22,
        height: 22,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: context.colors.primarySoft,
          shape: BoxShape.circle,
        ),
        child: Text(
          number,
          style: Theme.of(context).textTheme.labelMedium
              ?.copyWith(color: context.colors.primaryDark),
        ),
      ),
      const SizedBox(width: AdoptifySpacing.sm),
      Expanded(
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodySmall
              ?.copyWith(color: context.colors.textMuted),
        ),
      ),
    ],
  );
}
