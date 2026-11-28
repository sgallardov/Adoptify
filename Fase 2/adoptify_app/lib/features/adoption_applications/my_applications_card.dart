import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';

// "Mis postulaciones" en el Perfil del adoptante (HU-AC): abre la lista a pantalla completa.
class MyApplicationsCard extends StatelessWidget {
  const MyApplicationsCard({super.key});

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
      child: InkWell(
        borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
        onTap: () => context.push('/mis-postulaciones'),
        child: Padding(
          padding: const EdgeInsets.all(AdoptifySpacing.lg),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colors.primarySoft,
                child: Icon(Icons.assignment_outlined, color: colors.primaryDark),
              ),
              const SizedBox(width: AdoptifySpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Mis postulaciones', style: textTheme.titleMedium),
                    const SizedBox(height: 2),
                    Text('Mira el estado de cada una o retira las que ya no te interesan', style: textTheme.bodySmall),
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
