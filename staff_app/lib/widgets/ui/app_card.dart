import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AppCard extends StatelessWidget {
  const AppCard({
    super.key,
    required this.child,
    this.onTap,
    this.padding = const EdgeInsets.all(AppTheme.spacingL),
    this.backgroundColor,
    this.borderColor,
    this.showShadow = false,
  });

  final Widget child;
  final GestureTapCallback? onTap;
  final EdgeInsetsGeometry padding;
  final Color? backgroundColor;
  final Color? borderColor;
  final bool showShadow;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final palette = AppPalette.of(context);
    final content = AnimatedContainer(
      duration: AppTheme.shortDuration,
      curve: AppTheme.standardCurve,
      decoration: BoxDecoration(
        color: backgroundColor ?? theme.cardColor,
        borderRadius: AppTheme.bradiusL,
        border: Border.all(
          color: borderColor ?? palette.surfaceBorder,
          width: 1,
        ),
        boxShadow: showShadow ? AppTheme.softShadow : null,
      ),
      child: Padding(padding: padding, child: child),
    );

    if (onTap != null) {
      return InkWell(
        borderRadius: AppTheme.bradiusL,
        onTap: onTap,
        child: content,
      );
    }
    return content;
  }
}

