import 'package:flutter_advanced_drawer/flutter_advanced_drawer.dart';
import 'package:flutter/material.dart';

class DrawerControllerScope extends InheritedWidget {
  const DrawerControllerScope({
    required this.controller,
    required super.child,
    super.key,
  });

  final AdvancedDrawerController controller;

  static AdvancedDrawerController? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<DrawerControllerScope>()?.controller;

  static AdvancedDrawerController of(BuildContext context) {
    final controller = maybeOf(context);
    assert(controller != null, 'No AdvancedDrawerController found in context');
    return controller!;
  }

  @override
  bool updateShouldNotify(DrawerControllerScope oldWidget) => controller != oldWidget.controller;
}


