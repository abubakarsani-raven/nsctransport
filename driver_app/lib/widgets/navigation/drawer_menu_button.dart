import 'package:flutter/material.dart';
import 'package:flutter_advanced_drawer/flutter_advanced_drawer.dart';
import 'package:provider/provider.dart';

/// A reusable drawer menu button widget that handles drawer menu functionality
/// across different screens. It attempts to use the drawer controller from context,
/// falls back to the provided callback, or uses Navigator.pop() as a last resort.
class DrawerMenuButton extends StatelessWidget {
  const DrawerMenuButton({
    super.key,
    this.onMenuPressed,
    this.tooltip = 'Menu',
  });

  /// Optional callback to handle menu button press
  /// If provided, this will be called before attempting to use the drawer controller
  final VoidCallback? onMenuPressed;

  /// Tooltip text for the button
  final String tooltip;

  @override
  Widget build(BuildContext context) {
    // Try to get drawer controller from context
    // The DriverDrawerShell uses ListenableProvider.value to provide the controller
    AdvancedDrawerController? drawerController;
    
    // Try multiple methods to get the drawer controller
    // Method 1: Try to get from ListenableProvider (how DriverDrawerShell provides it)
    try {
      drawerController = Provider.of<AdvancedDrawerController>(context, listen: false);
    } catch (e) {
      // Method 2: Try nullable provider
      try {
        drawerController = Provider.of<AdvancedDrawerController?>(context, listen: false);
      } catch (e) {
        // Method 3: Try to find AdvancedDrawer widget in the widget tree
        try {
          final drawer = context.findAncestorWidgetOfExactType<AdvancedDrawer>();
          if (drawer != null) {
            drawerController = drawer.controller;
          }
        } catch (e) {
          // No drawer controller available
          drawerController = null;
        }
      }
    }

    // If we have a controller, use it with ValueListenableBuilder
    // Don't call onMenuPressed when we have a controller, as the controller
    // handles the drawer state directly
    if (drawerController != null) {
      return ValueListenableBuilder<AdvancedDrawerValue>(
        valueListenable: drawerController,
        builder: (context, value, _) {
          return IconButton(
            icon: Icon(value.visible ? Icons.close : Icons.menu),
            onPressed: () {
              if (value.visible) {
                drawerController!.hideDrawer();
              } else {
                drawerController!.showDrawer();
              }
            },
            tooltip: tooltip,
          );
        },
      );
    }

    // If we have a callback, use it
    if (onMenuPressed != null) {
      return IconButton(
        icon: const Icon(Icons.menu),
        onPressed: onMenuPressed,
        tooltip: tooltip,
      );
    }

    // Fallback: Use Navigator.pop() to go back
    // This is useful for screens that are pushed on top of drawer-enabled screens
    if (Navigator.canPop(context)) {
      return IconButton(
        icon: const Icon(Icons.arrow_back),
        onPressed: () => Navigator.pop(context),
        tooltip: 'Back',
      );
    }

    // Last resort: Show menu icon but it won't do anything
    // This should rarely happen, but prevents crashes
    return IconButton(
      icon: const Icon(Icons.menu),
      onPressed: () {
        debugPrint('DrawerMenuButton: No drawer controller, callback, or navigation available');
      },
      tooltip: tooltip,
    );
  }
}

