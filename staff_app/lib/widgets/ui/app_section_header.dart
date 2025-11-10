import 'package:flutter/material.dart';
import 'package:flutter_advanced_drawer/flutter_advanced_drawer.dart';
import 'package:provider/provider.dart';
import '../../theme/app_theme.dart';
import '../navigation/drawer_controller_scope.dart';

class AppSectionHeader extends StatelessWidget {
  const AppSectionHeader({
    super.key,
    required this.title,
    this.subtitle,
    this.subtitleWidget,
    this.action,
    this.icon,
    this.margin = const EdgeInsets.only(bottom: AppTheme.spacingM),
    this.showMenuButton = false,
    this.leading,
    this.onMenuPressed,
  });

  final String title;
  final String? subtitle;
  final Widget? subtitleWidget;
  final Widget? action;
  final IconData? icon;
  final EdgeInsetsGeometry margin;
  final bool showMenuButton;
  final Widget? leading;
  final VoidCallback? onMenuPressed;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Container(
      margin: margin,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showMenuButton)
            _MenuToggleButton(onPressed: onMenuPressed),
          if (!showMenuButton && leading != null) leading!,
          if (icon != null)
            Container(
              height: 40,
              width: 40,
              margin: const EdgeInsets.only(right: AppTheme.spacingM),
              decoration: BoxDecoration(
                color: AppTheme.neutral20,
                borderRadius: AppTheme.bradiusS,
              ),
              child: Icon(icon, color: AppTheme.primaryColor),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: theme.textTheme.headlineSmall),
                if (subtitleWidget != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppTheme.spacingXS),
                    child: subtitleWidget!,
                  )
                else if (subtitle != null)
                  Padding(
                    padding: const EdgeInsets.only(top: AppTheme.spacingXS),
                    child: Text(
                      subtitle!,
                      style: theme.textTheme.bodyMedium,
                    ),
                  ),
              ],
            ),
          ),
          if (action != null) action!,
        ],
      ),
    );
  }
}

class _MenuToggleButton extends StatelessWidget {
  const _MenuToggleButton({this.onPressed});

  final VoidCallback? onPressed;

  @override
  Widget build(BuildContext context) {
    debugPrint('[AppSectionHeader] Building menu toggle button');

    final controllerFromScope = DrawerControllerScope.maybeOf(context);
    debugPrint('[AppSectionHeader] Controller from scope: ${controllerFromScope != null}');

    AdvancedDrawerController? controllerFromWatch;
    try {
      controllerFromWatch = context.watch<AdvancedDrawerController?>();
      debugPrint('[AppSectionHeader] Controller from watch: ${controllerFromWatch != null}');
    } catch (e) {
      debugPrint('[AppSectionHeader] Error watching AdvancedDrawerController: $e');
    }

    final controller = controllerFromScope ?? controllerFromWatch;
    debugPrint('[AppSectionHeader] Final controller: ${controller != null}');

    if (controller == null) {
      debugPrint('[AppSectionHeader] No controller found, using fallback IconButton');
      // Try to find controller from parent context as last resort
      AdvancedDrawerController? parentController;
      try {
        // Try to find AdvancedDrawer in the widget tree
        final drawer = context.findAncestorWidgetOfExactType<AdvancedDrawer>();
        if (drawer != null) {
          parentController = drawer.controller;
          debugPrint('[AppSectionHeader] Found controller from AdvancedDrawer widget: ${parentController != null}');
        }
      } catch (e) {
        debugPrint('[AppSectionHeader] Error finding AdvancedDrawer: $e');
      }
      
      final finalController = controller ?? parentController;
      
      if (finalController != null) {
        debugPrint('[AppSectionHeader] Using controller found from widget tree');
        return ValueListenableBuilder<AdvancedDrawerValue>(
          valueListenable: finalController,
          builder: (context, value, _) {
            return IconButton(
              onPressed: () {
                if (value.visible) {
                  finalController.hideDrawer();
                } else {
                  finalController.showDrawer();
                }
              },
              icon: AnimatedSwitcher(
                duration: const Duration(milliseconds: 250),
                child: Icon(
                  value.visible ? Icons.clear : Icons.menu_rounded,
                  key: ValueKey<bool>(value.visible),
                ),
              ),
            );
          },
        );
      }
      
      // Last resort: use callback if available
      return IconButton(
        icon: const Icon(Icons.menu_rounded),
        onPressed: () {
          debugPrint('[AppSectionHeader] Fallback menu button pressed');
          if (onPressed != null) {
            debugPrint('[AppSectionHeader] Calling onPressed callback');
            onPressed!();
          } else {
            debugPrint('[AppSectionHeader] ERROR: Both controller and onPressed are null; drawer cannot be opened');
            debugPrint('[AppSectionHeader] This usually means the widget is not inside a StaffDrawerShell');
          }
        },
      );
    }

    debugPrint('[AppSectionHeader] Using ValueListenableBuilder with controller');
    return ValueListenableBuilder<AdvancedDrawerValue>(
      valueListenable: controller,
      builder: (context, value, _) {
        debugPrint('[AppSectionHeader] Drawer visible: ${value.visible}');
        return IconButton(
          onPressed: () {
            debugPrint('[AppSectionHeader] Menu button pressed, drawer visible: ${value.visible}');
            if (value.visible) {
              debugPrint('[AppSectionHeader] Hiding drawer');
              controller.hideDrawer();
              return;
            }
            if (onPressed != null) {
              debugPrint('[AppSectionHeader] Calling onPressed before showing drawer');
              onPressed!();
              return;
            }
            debugPrint('[AppSectionHeader] Showing drawer directly');
            controller.showDrawer();
          },
          icon: AnimatedSwitcher(
            duration: const Duration(milliseconds: 250),
            child: Icon(
              value.visible ? Icons.clear : Icons.menu_rounded,
              key: ValueKey<bool>(value.visible),
            ),
          ),
        );
      },
    );
  }
}

