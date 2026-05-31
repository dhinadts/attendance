import 'package:flutter/material.dart';
import '../theme/industrial_theme.dart';

class SectionHeader extends StatelessWidget {
  final String title;
  final String? subtitle;
  final String? actionText;
  final VoidCallback? onAction;
  final IconData? icon;

  const SectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.actionText,
    this.onAction,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (icon != null) ...[
                Icon(icon, color: IndustrialColors.primary, size: 24),
                const SizedBox(width: 8),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: Theme.of(context).textTheme.headlineMedium
                          ?.copyWith(
                            fontSize: 20,
                            fontWeight: FontWeight.w600,
                            color: IndustrialColors.onSurface,
                          ),
                    ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          fontSize: 12,
                          color: IndustrialColors.onSurfaceVariant,
                        ),
                      ),
                  ],
                ),
              ),
              if (actionText != null)
                GestureDetector(
                  onTap: onAction,
                  child: Text(
                    actionText!,
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      fontSize: 12,
                      color: IndustrialColors.primary,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
