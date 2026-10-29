import 'package:flutter/material.dart';

import '../../app/theme.dart';

// Aviso en caja de color, como los role="alert" / role="status" del portal
class MessageBox extends StatelessWidget {
  const MessageBox.error({super.key, required this.message})
      : icon = Icons.warning_amber_rounded,
        background = AdoptifyColors.primarySoft,
        foreground = AdoptifyColors.primaryTextDark;

  const MessageBox.success({super.key, required this.message})
      : icon = Icons.check_circle_outline,
        background = AdoptifyColors.successSoft,
        foreground = AdoptifyColors.success;

  final String message;
  final IconData icon;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(color: background, borderRadius: BorderRadius.circular(12)),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 1),
              child: Icon(icon, size: 16, color: foreground),
            ),
            const SizedBox(width: 8),
            Expanded(child: Text(message, style: TextStyle(fontSize: 14, color: foreground))),
          ],
        ),
      ),
    );
  }
}
