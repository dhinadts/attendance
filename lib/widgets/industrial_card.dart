import 'package:flutter/material.dart';
import '../theme/industrial_theme.dart';

class IndustrialCard extends StatefulWidget {
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
    this.borderRadius = 16,
  });

  @override
  State<IndustrialCard> createState() => _IndustrialCardState();
}

class _IndustrialCardState extends State<IndustrialCard> {
  bool _isHovered = false;
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final hasTap = widget.onTap != null;
    return MouseRegion(
      onEnter: (_) {
        if (hasTap) setState(() => _isHovered = true);
      },
      onExit: (_) {
        if (hasTap) setState(() => _isHovered = false);
      },
      child: GestureDetector(
        onTapDown: (_) {
          if (hasTap) setState(() => _isPressed = true);
        },
        onTapUp: (_) {
          if (hasTap) setState(() => _isPressed = false);
        },
        onTapCancel: () {
          if (hasTap) setState(() => _isPressed = false);
        },
        onTap: widget.onTap,
        child: AnimatedScale(
          scale: _isPressed ? 0.98 : (_isHovered ? 1.015 : 1.0),
          duration: const Duration(milliseconds: 150),
          curve: Curves.easeOutCubic,
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 250),
            curve: Curves.easeOutCubic,
            padding: widget.padding,
            decoration: BoxDecoration(
              color: widget.backgroundColor ??
                  (widget.highlighted
                      ? (_isHovered
                          ? IndustrialColors.surfaceContainerLow
                          : IndustrialColors.surfaceContainerLow)
                      : (_isHovered
                          ? IndustrialColors.surfaceContainerLow
                          : IndustrialColors.surface)),
              borderRadius: BorderRadius.circular(widget.borderRadius),
              border: Border.all(
                color: _isHovered
                    ? IndustrialColors.primary.withValues(alpha: 0.3)
                    : (widget.highlighted
                        ? IndustrialColors.primary.withValues(alpha: 0.15)
                        : IndustrialColors.outlineVariant),
                width: widget.highlighted ? 1.5 : 1,
              ),
              boxShadow: [
                BoxShadow(
                  color: _isHovered
                      ? IndustrialColors.primary.withValues(alpha: 0.05)
                      : Colors.black.withValues(alpha: 0.015),
                  blurRadius: _isHovered ? 14 : 6,
                  offset: Offset(0, _isHovered ? 4 : 1),
                ),
              ],
            ),
            child: widget.child,
          ),
        ),
      ),
    );
  }
}
