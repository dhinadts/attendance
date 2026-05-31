import 'package:flutter/material.dart';
import '../theme/industrial_theme.dart';

class StatCard extends StatelessWidget {
  final String label;
  final String value;
  final IconData? icon;
  final Color? valueColor;
  final String? subtitle;
  final bool isLarge;

  const StatCard({
    super.key,
    required this.label,
    required this.value,
    this.icon,
    this.valueColor,
    this.subtitle,
    this.isLarge = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: IndustrialColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: IndustrialColors.outlineVariant, width: 1),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, size: 18, color: IndustrialColors.onSurfaceVariant),
                const SizedBox(width: 8),
              ],
              Text(
                label,
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  fontSize: 12,
                  color: IndustrialColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
              fontSize: isLarge ? 24 : 20,
              fontWeight: FontWeight.w600,
              color: valueColor ?? IndustrialColors.onSurface,
            ),
          ),
          if (subtitle != null) ...[
            const SizedBox(height: 4),
            Text(
              subtitle!,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                fontSize: 12,
                color: IndustrialColors.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
    );
  }
}
