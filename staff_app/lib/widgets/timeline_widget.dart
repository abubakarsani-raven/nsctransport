import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../theme/app_theme.dart';

enum TimelineItemStatus {
  pending,
  completed,
  failed,
  inProgress,
  notReached,
}

class TimelineItem {
  final String id;
  final String title;
  final String? subtitle;
  final String? description;
  final DateTime? timestamp;
  final TimelineItemStatus status;
  final IconData? icon;
  final Color? color;
  final Map<String, dynamic>? metadata;

  TimelineItem({
    required this.id,
    required this.title,
    this.subtitle,
    this.description,
    this.timestamp,
    required this.status,
    this.icon,
    this.color,
    this.metadata,
  });
}

class TimelineWidget extends StatefulWidget {
  final List<TimelineItem> items;
  final bool showConnectingLines;
  final bool expandable;
  final EdgeInsets? padding;
  final Color? lineColor;
  final double lineWidth;

  const TimelineWidget({
    super.key,
    required this.items,
    this.showConnectingLines = true,
    this.expandable = false,
    this.padding,
    this.lineColor,
    this.lineWidth = 2.0,
  });

  @override
  State<TimelineWidget> createState() => _TimelineWidgetState();
}

class _TimelineWidgetState extends State<TimelineWidget>
    with SingleTickerProviderStateMixin {
  final Map<String, bool> _expandedItems = {};
  late AnimationController _animationController;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: AppTheme.mediumDuration,
    );
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Color _getStatusColor(TimelineItemStatus status, Color? customColor) {
    if (customColor != null) return customColor;
    
    switch (status) {
      case TimelineItemStatus.completed:
        return AppTheme.successColor;
      case TimelineItemStatus.failed:
        return AppTheme.errorColor;
      case TimelineItemStatus.inProgress:
        return AppTheme.primaryColor;
      case TimelineItemStatus.pending:
        return AppTheme.warningColor;
      case TimelineItemStatus.notReached:
        return Colors.grey.withOpacity(0.4);
    }
  }

  IconData _getStatusIcon(TimelineItemStatus status, IconData? customIcon) {
    if (customIcon != null) return customIcon;
    
    switch (status) {
      case TimelineItemStatus.completed:
        return Icons.check_circle;
      case TimelineItemStatus.failed:
        return Icons.cancel;
      case TimelineItemStatus.inProgress:
        return Icons.radio_button_checked;
      case TimelineItemStatus.pending:
        return Icons.radio_button_unchecked;
      case TimelineItemStatus.notReached:
        return Icons.radio_button_unchecked;
    }
  }

  void _toggleExpand(String id) {
    if (!widget.expandable) return;
    setState(() {
      _expandedItems[id] = !(_expandedItems[id] ?? false);
    });
  }

  @override
  Widget build(BuildContext context) {
    if (widget.items.isEmpty) {
      return const SizedBox.shrink();
    }

    final colorScheme = Theme.of(context).colorScheme;
    final lineColor = widget.lineColor ?? colorScheme.outline.withOpacity(0.3);

    return Padding(
      padding: widget.padding ?? EdgeInsets.zero,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: List.generate(widget.items.length, (index) {
          final item = widget.items[index];
          final isLast = index == widget.items.length - 1;
          final isExpanded = _expandedItems[item.id] ?? false;
          final statusColor = _getStatusColor(item.status, item.color);
          final icon = _getStatusIcon(item.status, item.icon);

          return _TimelineItemWidget(
            item: item,
            isLast: isLast,
            isExpanded: isExpanded,
            statusColor: statusColor,
            icon: icon,
            showConnectingLine: widget.showConnectingLines && !isLast,
            lineColor: lineColor,
            lineWidth: widget.lineWidth,
            expandable: widget.expandable,
            onTap: () => _toggleExpand(item.id),
            animationValue: _animationController.value,
            index: index,
          );
        }),
      ),
    );
  }
}

class _TimelineItemWidget extends StatelessWidget {
  final TimelineItem item;
  final bool isLast;
  final bool isExpanded;
  final Color statusColor;
  final IconData icon;
  final bool showConnectingLine;
  final Color lineColor;
  final double lineWidth;
  final bool expandable;
  final VoidCallback onTap;
  final double animationValue;
  final int index;

  const _TimelineItemWidget({
    required this.item,
    required this.isLast,
    required this.isExpanded,
    required this.statusColor,
    required this.icon,
    required this.showConnectingLine,
    required this.lineColor,
    required this.lineWidth,
    required this.expandable,
    required this.onTap,
    required this.animationValue,
    required this.index,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return TweenAnimationBuilder<double>(
      tween: Tween(begin: 0.0, end: 1.0),
      duration: Duration(milliseconds: 300 + (index * 50)),
      curve: AppTheme.emphasizedCurve,
      builder: (context, value, child) {
        return Opacity(
          opacity: value,
          child: Transform.translate(
            offset: Offset(0, 20 * (1 - value)),
            child: child,
          ),
        );
      },
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Timeline indicator column
            Column(
              children: [
                // Icon container
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: item.status == TimelineItemStatus.notReached
                        ? Colors.transparent
                        : statusColor.withOpacity(0.1),
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: statusColor,
                      width: item.status == TimelineItemStatus.notReached ? 1.5 : 2.5,
                    ),
                  ),
                  child: Icon(
                    icon,
                    color: statusColor,
                    size: 24,
                  ),
                ),
                // Connecting line
                if (showConnectingLine)
                  Expanded(
                    child: Container(
                      width: lineWidth,
                      margin: EdgeInsets.symmetric(vertical: AppTheme.spacingXS),
                      decoration: BoxDecoration(
                        color: item.status == TimelineItemStatus.notReached
                            ? lineColor.withOpacity(0.3)
                            : lineColor,
                        borderRadius: BorderRadius.zero,
                      ),
                    ),
                  ),
              ],
            ),
            SizedBox(width: AppTheme.spacingM),
            // Content column
            Expanded(
              child: GestureDetector(
                onTap: expandable ? onTap : null,
                child: Container(
                  decoration: BoxDecoration(
                    color: item.status == TimelineItemStatus.notReached
                        ? colorScheme.surfaceContainerHighest.withOpacity(0.5)
                        : colorScheme.surfaceContainerHighest,
                    borderRadius: BorderRadius.zero,
                    border: item.status == TimelineItemStatus.notReached
                        ? Border.all(
                            color: colorScheme.outline.withOpacity(0.2),
                            width: 1,
                          )
                        : null,
                  ),
                  margin: EdgeInsets.only(
                    bottom: isLast ? 0 : AppTheme.spacingM,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(AppTheme.spacingM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.title,
                                    style: Theme.of(context).textTheme.titleMedium?.copyWith(
                                      fontWeight: FontWeight.w600,
                                      color: item.status == TimelineItemStatus.notReached
                                          ? colorScheme.onSurfaceVariant
                                          : null,
                                    ),
                                  ),
                                  if (item.subtitle != null) ...[
                                    SizedBox(height: AppTheme.spacingXS),
                                    Text(
                                      item.subtitle!,
                                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                        color: item.status == TimelineItemStatus.notReached
                                            ? colorScheme.onSurfaceVariant.withOpacity(0.7)
                                            : colorScheme.onSurfaceVariant,
                                      ),
                                    ),
                                  ],
                                ],
                              ),
                            ),
                            if (expandable)
                              Icon(
                                isExpanded
                                    ? Icons.expand_less
                                    : Icons.expand_more,
                                color: colorScheme.onSurfaceVariant,
                                size: 20,
                              ),
                          ],
                        ),
                        if (item.timestamp != null) ...[
                          SizedBox(height: AppTheme.spacingS),
                          Row(
                            children: [
                              Icon(
                                Icons.access_time,
                                size: 14,
                                color: colorScheme.onSurfaceVariant,
                              ),
                              SizedBox(width: AppTheme.spacingXS),
                              Text(
                                DateFormat('MMM dd, yyyy HH:mm').format(item.timestamp!),
                                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: colorScheme.onSurfaceVariant,
                                ),
                              ),
                            ],
                          ),
                        ],
                        if (item.description != null && (isExpanded || !expandable)) ...[
                          SizedBox(height: AppTheme.spacingM),
                          Text(
                            item.description!,
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              color: item.status == TimelineItemStatus.notReached
                                  ? colorScheme.onSurfaceVariant.withOpacity(0.7)
                                  : null,
                            ),
                          ),
                        ],
                        if (item.metadata != null && (isExpanded || !expandable)) ...[
                          SizedBox(height: AppTheme.spacingM),
                          ...item.metadata!.entries.map((entry) {
                            return Padding(
                              padding: EdgeInsets.only(bottom: AppTheme.spacingXS),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    '${entry.key}: ',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                      fontWeight: FontWeight.w500,
                                      color: colorScheme.onSurfaceVariant,
                                    ),
                                  ),
                                  Expanded(
                                    child: Text(
                                      entry.value.toString(),
                                      style: Theme.of(context).textTheme.bodySmall,
                                    ),
                                  ),
                                ],
                              ),
                            );
                          }),
                        ],
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

