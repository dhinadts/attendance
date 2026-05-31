import 'package:flutter/material.dart';
import '../theme/industrial_theme.dart';

class IndustrialCard extends StatelessWidget {
  final Widget child;
  final EdgeInsets padding;
  final VoidCallback? onTap;
  final bool highlighted;
  final Color? backgroundColor;
  final double borderRadius;

  const IndustrialCard({
    super.key,
    required this.child,
    this.padding = const EdgeInsets.all(16),
    this.onTap,
    this.highlighted = false,
    this.backgroundColor,
    this.borderRadius = 12,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: padding,
        decoration: BoxDecoration(
          color:
              backgroundColor ??
              (highlighted
                  ? IndustrialColors.surfaceContainerLow
                  : IndustrialColors.surface),
          borderRadius: BorderRadius.circular(borderRadius),
          border: Border.all(color: IndustrialColors.outlineVariant, width: 1),
        ),
        child: child,
      ),
    );
  }
}
