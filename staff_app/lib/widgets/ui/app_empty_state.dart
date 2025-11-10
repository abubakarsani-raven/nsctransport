import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';

class AppEmptyState extends StatelessWidget {
  const AppEmptyState({
    super.key,
    required this.title,
    this.message,
    this.icon = Icons.inbox_rounded,
    this.action,
    this.compact = false,
  });

  final String title;
  final String? message;
  final IconData icon;
  final Widget? action;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final spacing = compact ? AppTheme.spacingS : AppTheme.spacingM;

    Widget buildContent() {
      return Padding(
        padding: EdgeInsets.all(compact ? AppTheme.spacingL : AppTheme.spacingXL),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircleAvatar(
              radius: compact ? 32 : 42,
              backgroundColor: AppTheme.primaryColor.withOpacity(.08),
              child: Icon(
                icon,
                size: compact ? 28 : 36,
                color: AppTheme.primaryColor,
              ),
            ),
            SizedBox(height: spacing),
            Text(
              title,
              style: theme.textTheme.titleLarge,
              textAlign: TextAlign.center,
            ),
            if (message != null) ...[
              SizedBox(height: spacing / 1.5),
              Text(
                message!,
                style: theme.textTheme.bodyMedium,
                textAlign: TextAlign.center,
              ),
            ],
            if (action != null) ...[
              SizedBox(height: spacing),
              action!,
            ],
          ],
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final content = Center(child: buildContent());
        if (constraints.maxHeight.isFinite) {
          return SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingM),
            child: ConstrainedBox(
              constraints: BoxConstraints(minHeight: constraints.maxHeight),
              child: Align(alignment: Alignment.center, child: content),
            ),
          );
        }
        return content;
      },
    );
  }
}

