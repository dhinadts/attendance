import 'package:flutter/material.dart';
import '../theme/industrial_theme.dart';

enum StatusChipType { success, pending, alert, neutral }

class StatusChip extends StatelessWidget {
  final String label;
  final StatusChipType type;
  final IconData? icon;

  const StatusChip({
    super.key,
    required this.label,
    this.type = StatusChipType.success,
    this.icon,
  });

  Color _getBackgroundColor() {
    switch (type) {
      case StatusChipType.success:
        return IndustrialColors.secondaryContainer;
      case StatusChipType.pending:
        return IndustrialColors.tertiaryContainer;
      case StatusChipType.alert:
        return IndustrialColors.error.withValues(alpha: 0.1);
      case StatusChipType.neutral:
        return IndustrialColors.surfaceContainerHigh;
    }
  }

  Color _getTextColor() {
    switch (type) {
      case StatusChipType.success:
        return IndustrialColors.onSecondaryContainer;
      case StatusChipType.pending:
        return IndustrialColors.onTertiaryContainer;
      case StatusChipType.alert:
        return IndustrialColors.error;
      case StatusChipType.neutral:
        return IndustrialColors.onSurface;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: _getBackgroundColor(),
        borderRadius: BorderRadius.circular(20),
        border: type == StatusChipType.alert
            ? Border.all(color: IndustrialColors.error, width: 0.5)
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 14, color: _getTextColor()),
            const SizedBox(width: 4),
          ],
          Text(
            label.toUpperCase(),
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              fontSize: 11,
              color: _getTextColor(),
            ),
          ),
        ],
      ),
    );
  }
}
