import 'package:flutter/material.dart';
import '../../theme/app_breakpoints.dart';
import '../../theme/app_theme.dart';

class AppPageContainer extends StatelessWidget {
  const AppPageContainer({
    super.key,
    required this.child,
    this.padding,
    this.maxWidth = AppBreakpoints.maxContentWidth,
  });

  final Widget child;
  final EdgeInsetsGeometry? padding;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.topCenter,
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: Padding(
          padding: padding ??
              const EdgeInsets.symmetric(
                horizontal: AppTheme.spacingL,
                vertical: AppTheme.spacingL,
              ),
          child: child,
        ),
      ),
    );
  }
}

