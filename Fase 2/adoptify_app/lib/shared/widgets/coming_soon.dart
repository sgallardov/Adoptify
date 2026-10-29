import 'package:flutter/material.dart';

import '../../app/theme.dart';

// Vista centrada con ícono, título y mensaje (estados vacíos o pantallas que piden sesión)
class ComingSoon extends StatelessWidget {
  const ComingSoon({
    super.key,
    required this.icon,
    required this.title,
    required this.message,
  });

  final IconData icon;
  final String title;
  final String message;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AdoptifySpacing.xxl),
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 420),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 72,
                height: 72,
                decoration: const BoxDecoration(color: AdoptifyColors.primarySoft, shape: BoxShape.circle),
                child: Icon(icon, size: 32, color: AdoptifyColors.primaryDark),
              ),
              const SizedBox(height: AdoptifySpacing.xl),
              Text(title, style: textTheme.titleLarge, textAlign: TextAlign.center),
              const SizedBox(height: AdoptifySpacing.sm),
              Text(
                message,
                style: textTheme.bodyMedium?.copyWith(color: AdoptifyColors.textMuted),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
