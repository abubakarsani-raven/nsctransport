import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AppScaffold extends StatelessWidget {
  const AppScaffold({
    super.key,
    required this.body,
    this.header,
    this.floatingActionButton,
    this.bottomNavigationBar,
    this.drawer,
    this.extendBodyBehindAppBar = false,
    this.backgroundGradient,
    this.safeAreaBottom = true,
  });

  final Widget body;
  final Widget? header;
  final Widget? floatingActionButton;
  final Widget? bottomNavigationBar;
  final Widget? drawer;
  final bool extendBodyBehindAppBar;
  final bool safeAreaBottom;
  final Gradient? backgroundGradient;

  @override
  Widget build(BuildContext context) {
    final gradient = backgroundGradient ??
        LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            AppTheme.primaryColor.withOpacity(.08),
            Colors.transparent,
          ],
        );

    return Scaffold(
      extendBody: true,
      extendBodyBehindAppBar: extendBodyBehindAppBar,
      floatingActionButton: floatingActionButton,
      bottomNavigationBar: bottomNavigationBar,
      drawer: drawer,
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: BoxDecoration(
          color: Theme.of(context).scaffoldBackgroundColor,
          gradient: gradient,
        ),
        child: SafeArea(
          top: true,
          bottom: safeAreaBottom,
          child: Column(
            children: [
              if (header != null)
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppTheme.spacingL,
                    vertical: AppTheme.spacingM,
                  ),
                  child: header!,
                ),
              Expanded(child: body),
            ],
          ),
        ),
      ),
    );
  }
}

