import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

class ToastHelper {
  static const Duration _defaultDuration = Duration(seconds: 4);

  static BuildContext? _getContext(BuildContext? context) {
    if (context != null) return context;
    
    // Try to get context from navigator key
    final navigatorState = CustomToast.navigatorKey.currentState;
    if (navigatorState != null) {
      return navigatorState.context;
    }
    
    return null;
  }

  static void showSuccessToast(String message, {BuildContext? context}) {
    final ctx = _getContext(context);
    if (ctx == null) return;

    final screenWidth = MediaQuery.of(ctx).size.width;
    final minWidth = screenWidth * 0.5;

    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: minWidth,
            maxWidth: screenWidth * 0.9,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.check_circle_rounded,
                color: Theme.of(ctx).colorScheme.onInverseSurface,
                size: 20,
              ),
              SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(ctx).colorScheme.onInverseSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: AppTheme.successColor,
        duration: _defaultDuration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.bradiusM),
      ),
    );
  }

  static void showErrorToast(String message, {BuildContext? context}) {
    final ctx = _getContext(context);
    if (ctx == null) return;

    final screenWidth = MediaQuery.of(ctx).size.width;
    final minWidth = screenWidth * 0.5;

    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: minWidth,
            maxWidth: screenWidth * 0.9,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.error_rounded,
                color: Theme.of(ctx).colorScheme.onInverseSurface,
                size: 20,
              ),
              SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(ctx).colorScheme.onInverseSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: AppTheme.errorColor,
        duration: _defaultDuration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.bradiusM),
      ),
    );
  }

  static void showInfoToast(String message, {BuildContext? context}) {
    final ctx = _getContext(context);
    if (ctx == null) return;

    final screenWidth = MediaQuery.of(ctx).size.width;
    final minWidth = screenWidth * 0.5;

    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: minWidth,
            maxWidth: screenWidth * 0.9,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.info_rounded,
                color: Theme.of(ctx).colorScheme.onInverseSurface,
                size: 20,
              ),
              SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(ctx).colorScheme.onInverseSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: AppTheme.infoColor,
        duration: _defaultDuration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.bradiusM),
      ),
    );
  }

  static void showWarningToast(String message, {BuildContext? context}) {
    final ctx = _getContext(context);
    if (ctx == null) return;

    final screenWidth = MediaQuery.of(ctx).size.width;
    final minWidth = screenWidth * 0.5;

    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: minWidth,
            maxWidth: screenWidth * 0.9,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.warning_rounded,
                color: Theme.of(ctx).colorScheme.onInverseSurface,
                size: 20,
              ),
              SizedBox(width: AppTheme.spacingS),
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(ctx).colorScheme.onInverseSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: AppTheme.warningColor,
        duration: _defaultDuration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.bradiusM),
      ),
    );
  }

  static void showCustomToast(
    String message, {
    Color? backgroundColor,
    IconData? icon,
    Duration? duration,
    BuildContext? context,
  }) {
    final ctx = _getContext(context);
    if (ctx == null) return;

    final screenWidth = MediaQuery.of(ctx).size.width;
    final minWidth = screenWidth * 0.5;

    ScaffoldMessenger.of(ctx).showSnackBar(
      SnackBar(
        content: ConstrainedBox(
          constraints: BoxConstraints(
            minWidth: minWidth,
            maxWidth: screenWidth * 0.9,
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (icon != null) ...[
                Icon(
                  icon,
                  color: Theme.of(ctx).colorScheme.onInverseSurface,
                  size: 20,
                ),
                SizedBox(width: AppTheme.spacingS),
              ],
              Expanded(
                child: Text(
                  message,
                  style: Theme.of(ctx).textTheme.bodyMedium?.copyWith(
                    color: Theme.of(ctx).colorScheme.onInverseSurface,
                  ),
                ),
              ),
            ],
          ),
        ),
        backgroundColor: backgroundColor ?? AppTheme.primaryColor,
        duration: duration ?? _defaultDuration,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: AppTheme.bradiusM),
      ),
    );
  }
}

// Keep CustomToast for backward compatibility but use navigator key
class CustomToast {
  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}

