import 'package:flutter/material.dart';

import '../theme/app_theme.dart';

enum NotificationPosition {
  top,
  bottom,
}

class OverlaySupportEntry {
  final VoidCallback dismiss;

  OverlaySupportEntry({required this.dismiss});
}

class CustomToast {
  static OverlaySupportEntry? _currentToast;
  static bool _isRetrying = false;

  static OverlaySupportEntry showSimpleNotification(
    Widget content, {
    Widget? leading,
    Widget? subtitle,
    Widget? trailing,
    EdgeInsetsGeometry? contentPadding,
    Color? background,
    Color? foreground,
    double elevation = 16,
    Duration? duration,
    Key? key,
    bool autoDismiss = true,
    NotificationPosition position = NotificationPosition.top,
    BuildContext? context,
    DismissDirection? slideDismissDirection,
  }) {
    // Dismiss previous toast if exists
    _currentToast?.dismiss();

    // Always use navigator's overlay - it's more reliable than Overlay.of()
    OverlayState? overlayState;
    BuildContext? targetContext = context;
    
    // First, try to get overlay from navigator key (most reliable)
    final navigatorState = navigatorKey.currentState;
    if (navigatorState != null) {
      overlayState = navigatorState.overlay;
      // Use navigator's context for theme access
      targetContext ??= navigatorState.context;
      // If overlay is null but navigator exists, overlay might not be ready yet
      if (overlayState == null) {
        debugPrint('CustomToast: Navigator exists but overlay is null, will retry');
      }
    }
    
    // If still no overlay and we have a context, try Overlay.of() as fallback
    if (overlayState == null && targetContext != null) {
      try {
        overlayState = Overlay.of(targetContext, rootOverlay: true);
      } catch (e) {
        // Overlay not available from context either
        overlayState = null;
      }
    }
    
    if (overlayState == null) {
      // If we're already retrying, don't retry again to prevent infinite recursion
      if (_isRetrying) {
        debugPrint('CustomToast: Overlay not available, skipping toast');
        return OverlaySupportEntry(dismiss: () {});
      }
      
      // Schedule to show after frame to ensure overlay is ready
      _isRetrying = true;
      // Use both post-frame callback and a small delay to ensure overlay is ready
      WidgetsBinding.instance.addPostFrameCallback((_) {
        // Add a small delay to ensure overlay is fully initialized
        Future.delayed(const Duration(milliseconds: 50), () {
          _isRetrying = false;
          // Try again - overlay should be available now
          final navigatorState = navigatorKey.currentState;
          if (navigatorState != null) {
            final overlay = navigatorState.overlay;
            if (overlay != null) {
              // Don't pass context through async gap, navigator will provide it
              showSimpleNotification(
                content,
                leading: leading,
                subtitle: subtitle,
                trailing: trailing,
                contentPadding: contentPadding,
                background: background,
                foreground: foreground,
                elevation: elevation,
                duration: duration,
                key: key,
                autoDismiss: autoDismiss,
                position: position,
                context: null, // Will use navigator's context
                slideDismissDirection: slideDismissDirection,
              );
            } else {
              debugPrint('CustomToast: Overlay still not available after retry');
            }
          }
        });
      });
      // Return a dummy entry for now
      return OverlaySupportEntry(dismiss: () {});
    }
    
    _isRetrying = false; // Reset retry flag when overlay is found

    // Get theme colors from context if available, otherwise use defaults
    final palette = targetContext != null ? AppPalette.of(targetContext) : AppPalette.light;

    final backgroundColor = background ?? palette.toastBackground;
    final foregroundColor = foreground ?? palette.toastForeground;

    // Create overlay entry
    late OverlayEntry overlayEntry;
    AnimationController? animationController;

    // Define dismiss function after overlay entry is created
    void dismissEntry() {
      if (animationController != null) {
        animationController!.reverse().then((_) {
          overlayEntry.remove();
          _currentToast = null;
        });
      } else {
        overlayEntry.remove();
        _currentToast = null;
      }
    }

    overlayEntry = OverlayEntry(
      builder: (overlayContext) {
        return _ToastWidget(
          content: content,
          leading: leading,
          subtitle: subtitle,
          trailing: trailing,
          contentPadding: contentPadding,
          background: backgroundColor,
          foreground: foregroundColor,
          elevation: elevation,
          position: position,
          slideDismissDirection: slideDismissDirection ?? DismissDirection.none,
          onDismiss: dismissEntry,
          onAnimationControllerCreated: (controller) {
            animationController = controller;
          },
        );
      },
    );

    overlayState.insert(overlayEntry);

    if (autoDismiss && duration != null && duration != Duration.zero) {
      Future.delayed(duration, dismissEntry);
    }

    _currentToast = OverlaySupportEntry(dismiss: dismissEntry);
    return _currentToast!;
  }

  static final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();
}

class _ToastWidget extends StatefulWidget {
  final Widget content;
  final Widget? leading;
  final Widget? subtitle;
  final Widget? trailing;
  final EdgeInsetsGeometry? contentPadding;
  final Color background;
  final Color foreground;
  final double elevation;
  final NotificationPosition position;
  final DismissDirection slideDismissDirection;
  final VoidCallback onDismiss;
  final ValueChanged<AnimationController> onAnimationControllerCreated;

  const _ToastWidget({
    required this.content,
    this.leading,
    this.subtitle,
    this.trailing,
    this.contentPadding,
    required this.background,
    required this.foreground,
    required this.elevation,
    required this.position,
    required this.slideDismissDirection,
    required this.onDismiss,
    required this.onAnimationControllerCreated,
  });

  @override
  State<_ToastWidget> createState() => _ToastWidgetState();
}

class _ToastWidgetState extends State<_ToastWidget>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<Offset> _slideAnimation;
  late Animation<double> _fadeAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
    widget.onAnimationControllerCreated(_controller);

    final beginOffset = widget.position == NotificationPosition.top
        ? const Offset(0.0, -1.0)
        : const Offset(0.0, 1.0);
    _slideAnimation = Tween<Offset>(
      begin: beginOffset,
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _controller,
      curve: Curves.easeOut,
    ));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final materialWidget = Material(
      color: widget.background,
      elevation: widget.elevation,
      child: ListTileTheme(
        textColor: widget.foreground,
        iconColor: widget.foreground,
        child: ListTile(
          leading: widget.leading,
          title: widget.content,
          subtitle: widget.subtitle,
          trailing: widget.trailing,
          contentPadding: widget.contentPadding,
        ),
      ),
    );

    final dismissibleWidget = widget.slideDismissDirection != DismissDirection.none
        ? Dismissible(
            key: ValueKey(widget.content),
            direction: widget.slideDismissDirection,
            onDismissed: (_) => widget.onDismiss(),
            child: materialWidget,
          )
        : materialWidget;

    return Positioned(
      top: widget.position == NotificationPosition.top ? 0 : null,
      bottom: widget.position == NotificationPosition.bottom ? 0 : null,
      left: 0,
      right: 0,
      child: SafeArea(
        bottom: widget.position == NotificationPosition.bottom,
        top: widget.position == NotificationPosition.top,
        child: SlideTransition(
          position: _slideAnimation,
          child: FadeTransition(
            opacity: _fadeAnimation,
            child: dismissibleWidget,
          ),
        ),
      ),
    );
  }
}

