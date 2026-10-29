import 'package:flutter/material.dart';

import '../../app/theme.dart';

// Logo "adoptify." como en el portal. compact: versión para el header.
class AdoptifyLogo extends StatelessWidget {
  const AdoptifyLogo({super.key, this.compact = false});

  final bool compact;

  @override
  Widget build(BuildContext context) {
    final iconSize = compact ? 18.0 : 24.0;
    final textStyle = (compact ? Theme.of(context).textTheme.titleLarge : Theme.of(context).textTheme.headlineSmall)
        ?.copyWith(fontWeight: FontWeight.w800, letterSpacing: -0.5);

    return Semantics(
      label: 'Adoptify',
      child: ExcludeSemantics(
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: EdgeInsets.all(compact ? 6 : AdoptifySpacing.sm),
              decoration: BoxDecoration(
                color: AdoptifyColors.primary,
                borderRadius: BorderRadius.circular(compact ? AdoptifyRadius.sm + 2 : AdoptifyRadius.md),
              ),
              child: Icon(Icons.pets, color: Colors.white, size: iconSize),
            ),
            SizedBox(width: compact ? AdoptifySpacing.sm : 10),
            Text.rich(
              const TextSpan(
                text: 'adoptify',
                children: [TextSpan(text: '.', style: TextStyle(color: AdoptifyColors.primary))],
              ),
              style: textStyle,
            ),
          ],
        ),
      ),
    );
  }
}
