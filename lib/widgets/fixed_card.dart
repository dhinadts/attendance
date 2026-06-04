import 'package:flutter/material.dart';

class FixedCard extends StatelessWidget {
  final double? width;
  final double? height;
  final EdgeInsetsGeometry padding;
  final Widget child;

  const FixedCard({
    super.key,
    this.width,
    this.height,
    this.padding = const EdgeInsets.all(0),
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: width,
      height: height,
      child: Padding(
        padding: padding,
        child: child,
      ),
    );
  }
}
