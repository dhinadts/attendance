import 'package:flutter/material.dart';
import '../theme/industrial_theme.dart';

enum ActionButtonStyle { primary, secondary, tertiary, outline }

class PrimaryActionButton extends StatefulWidget {
  final String label;
  final VoidCallback? onPressed;
  final ActionButtonStyle style;
  final IconData? icon;
  final bool isFullWidth;
  final bool isLoading;
  final double height;

  const PrimaryActionButton({
    super.key,
    required this.label,
    this.onPressed,
    this.style = ActionButtonStyle.primary,
    this.icon,
    this.isFullWidth = true,
    this.isLoading = false,
    this.height = 48,
  });

  @override
  State<PrimaryActionButton> createState() => _PrimaryActionButtonState();
}

class _PrimaryActionButtonState extends State<PrimaryActionButton> {
  bool _isPressed = false;

  Color _getBackgroundColor() {
    switch (widget.style) {
      case ActionButtonStyle.primary:
        return IndustrialColors.primary;
      case ActionButtonStyle.secondary:
        return IndustrialColors.secondary;
      case ActionButtonStyle.tertiary:
        return IndustrialColors.tertiary;
      case ActionButtonStyle.outline:
        return Colors.transparent;
    }
  }

  Color _getTextColor() {
    switch (widget.style) {
      case ActionButtonStyle.primary:
      case ActionButtonStyle.secondary:
      case ActionButtonStyle.tertiary:
        return IndustrialColors.onPrimary;
      case ActionButtonStyle.outline:
        return IndustrialColors.onSurface;
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTapDown: (_) => setState(() => _isPressed = true),
      onTapUp: (_) => setState(() => _isPressed = false),
      onTapCancel: () => setState(() => _isPressed = false),
      onTap: widget.isLoading ? null : widget.onPressed,
      child: AnimatedScale(
        scale: _isPressed ? 0.98 : 1.0,
        duration: const Duration(milliseconds: 100),
        child: Container(
          height: widget.height,
          width: widget.isFullWidth ? double.infinity : null,
          padding: const EdgeInsets.symmetric(horizontal: 24),
          decoration: BoxDecoration(
            color: _getBackgroundColor(),
            borderRadius: BorderRadius.circular(12),
            border: widget.style == ActionButtonStyle.outline
                ? Border.all(color: IndustrialColors.outline, width: 2)
                : null,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              if (widget.isLoading)
                SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation<Color>(_getTextColor()),
                  ),
                )
              else ...[
                if (widget.icon != null) ...[
                  Icon(widget.icon, color: _getTextColor(), size: 20),
                  const SizedBox(width: 8),
                ],
                Text(
                  widget.label,
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: _getTextColor(),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
