import 'package:flutter/material.dart';

class StatusChip extends StatelessWidget {
  final String status;
  const StatusChip(this.status, {super.key});

  @override
  Widget build(BuildContext context) {
    final s = status.toUpperCase();
    final cs = Theme.of(context).colorScheme;
    Color bg, fg;
    switch (s) {
      case 'APPROVED':
        bg = cs.primaryContainer;
        fg = cs.onPrimaryContainer;
        break;
      case 'REJECTED':
        bg = cs.errorContainer;
        fg = cs.onErrorContainer;
        break;
      default:
        bg = cs.surfaceVariant;
        fg = cs.onSurface;
    }
    return Chip(
      label: Text(s, style: TextStyle(color: fg, fontWeight: FontWeight.w600)),
      backgroundColor: bg,
    );
  }
}
