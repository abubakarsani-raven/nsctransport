import 'package:flutter/material.dart';
import 'package:flutter_advanced_drawer/flutter_advanced_drawer.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/request_history_provider.dart';
import '../theme/app_theme.dart';
import '../widgets/ui/app_card.dart';
import '../widgets/navigation/drawer_controller_scope.dart';

class _FilterChipData {
  const _FilterChipData({
    required this.label,
    required this.value,
    required this.icon,
    required this.tint,
    required this.count,
  });

  final String label;
  final String? value;
  final IconData icon;
  final Color tint;
  final int count;
}

class RecentActivityScreen extends StatefulWidget {
  const RecentActivityScreen({super.key, this.onMenuPressed});

  final VoidCallback? onMenuPressed;

  @override
  State<RecentActivityScreen> createState() => _RecentActivityScreenState();
}

class _RecentActivityScreenState extends State<RecentActivityScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _query = '';
  String _actionFilter = 'all';
  String? _requestTypeFilter; // null = all, 'vehicle', 'ict', 'store'

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RequestHistoryProvider>().loadHistory();
    });
    _searchController.addListener(() {
      if (_query != _searchController.text.trim()) {
        setState(() {
          _query = _searchController.text.trim();
        });
      }
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  String _formatLabelValue(String value) {
    if (value.isEmpty) return '';
    return value
        .replaceAll('_', ' ')
        .split(' ')
        .where((p) => p.trim().isNotEmpty)
        .map((p) => p[0].toUpperCase() + p.substring(1).toLowerCase())
        .join(' ');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: _DrawerLeadingButton(onMenuPressed: widget.onMenuPressed),
        title: const Text('Recent Activity'),
        actions: [
          IconButton(
            tooltip: 'Refresh activity',
            onPressed: () => context.read<RequestHistoryProvider>().loadHistory(force: true),
            icon: const Icon(Icons.refresh_rounded),
          ),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(120),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(AppTheme.spacingM, 0, AppTheme.spacingM, AppTheme.spacingS),
            child: Column(
              children: [
                TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Search activity...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    border: OutlineInputBorder(borderRadius: AppTheme.bradiusS),
                  ),
                ),
                const SizedBox(height: AppTheme.spacingS),
                Consumer<RequestHistoryProvider>(
                  builder: (context, historyProvider, _) {
                    return _buildFilterChips(context, historyProvider.history);
                  },
                ),
              ],
            ),
          ),
        ),
      ),
      body: SafeArea(
        child: Consumer<RequestHistoryProvider>(
          builder: (context, historyProvider, _) {
            if (historyProvider.isLoading && historyProvider.history.isEmpty) {
              return _buildLoading(context);
            }
            if (historyProvider.history.isEmpty) {
              return _buildEmpty(context);
            }
            final rawEntries = historyProvider.history.cast<Map<String, dynamic>>();
            final filtered = _applySearchAndFilter(rawEntries);
            final grouped = _groupByRequestNumber(filtered);
            if (grouped.isEmpty) {
              return _buildEmpty(context);
            }
            final groupKeys = grouped.keys.toList()..sort((a, b) => b.compareTo(a));
            return RefreshIndicator(
              onRefresh: () => historyProvider.loadHistory(force: true),
              color: AppTheme.primaryColor,
              child: ListView.builder(
                padding: const EdgeInsets.all(AppTheme.spacingM),
                itemCount: groupKeys.length,
                itemBuilder: (context, index) {
                  final key = groupKeys[index];
                  final items = grouped[key]!;
                  return _buildGroupTile(context, key, items);
                },
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildLoading(BuildContext context) {
    return Center(
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Theme.of(context).colorScheme.primary,
            ),
          ),
          const SizedBox(width: AppTheme.spacingM),
          Text('Loading recent activity…', style: Theme.of(context).textTheme.bodyMedium),
        ],
      ),
    );
  }

  Widget _buildEmpty(BuildContext context) {
    return Center(
      child: Text(
        'No recent activity',
        style: Theme.of(context).textTheme.bodyMedium,
      ),
    );
  }

  Widget _buildFilterChips(BuildContext context, List<dynamic> history) {
    final theme = Theme.of(context);
    
    // Count by request type
    final vehicleCount = history.where((e) {
      final requestType = e['requestType'] ?? e['request']?['requestType'];
      return requestType == 'vehicle' || requestType == null;
    }).length;
    final ictCount = history.where((e) {
      final requestType = e['requestType'] ?? e['request']?['requestType'];
      return requestType == 'ict';
    }).length;
    final storeCount = history.where((e) {
      final requestType = e['requestType'] ?? e['request']?['requestType'];
      return requestType == 'store';
    }).length;

    final filterItems = [
      _FilterChipData(
        label: 'All',
        value: null,
        icon: Icons.filter_list_rounded,
        tint: AppTheme.primaryColor,
        count: history.length,
      ),
      _FilterChipData(
        label: 'Vehicle',
        value: 'vehicle',
        icon: Icons.directions_car_rounded,
        tint: AppTheme.primaryColor,
        count: vehicleCount,
      ),
      _FilterChipData(
        label: 'ICT',
        value: 'ict',
        icon: Icons.computer_rounded,
        tint: Colors.blue,
        count: ictCount,
      ),
      _FilterChipData(
        label: 'Store',
        value: 'store',
        icon: Icons.inventory_2_rounded,
        tint: Colors.green,
        count: storeCount,
      ),
    ];

    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingXS),
      child: Row(
        children: filterItems
            .map(
              (item) {
                final isActive = _requestTypeFilter == item.value;
                return Padding(
                  padding: const EdgeInsets.only(right: AppTheme.spacingS),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      onTap: () {
                        setState(() {
                          if (_requestTypeFilter == item.value) {
                            _requestTypeFilter = null; // Toggle off if already active
                          } else {
                            _requestTypeFilter = item.value; // Set new filter
                          }
                        });
                      },
                      borderRadius: BorderRadius.circular(20),
                      child: AnimatedContainer(
                        duration: const Duration(milliseconds: 200),
                        curve: Curves.easeInOut,
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppTheme.spacingM,
                          vertical: AppTheme.spacingS,
                        ),
                        decoration: BoxDecoration(
                          color: isActive
                              ? item.tint.withOpacity(0.15)
                              : Theme.of(context).colorScheme.surfaceVariant.withOpacity(0.6),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: isActive
                                ? item.tint.withOpacity(0.5)
                                : Theme.of(context).colorScheme.outline.withOpacity(0.15),
                            width: isActive ? 2 : 1,
                          ),
                          boxShadow: isActive
                              ? [
                                  BoxShadow(
                                    color: item.tint.withOpacity(0.15),
                                    blurRadius: 6,
                                    offset: const Offset(0, 2),
                                  ),
                                ]
                              : null,
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              item.icon,
                              color: isActive
                                  ? item.tint
                                  : item.tint,
                              size: 16,
                            ),
                            const SizedBox(width: AppTheme.spacingXS),
                            Text(
                              item.label,
                              style: theme.textTheme.labelMedium?.copyWith(
                                fontSize: 12,
                                color: isActive
                                    ? item.tint
                                    : Theme.of(context).colorScheme.onSurfaceVariant,
                                fontWeight: isActive ? FontWeight.w700 : FontWeight.w500,
                              ),
                            ),
                            const SizedBox(width: AppTheme.spacingXS),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 6,
                                vertical: 2,
                              ),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? item.tint.withOpacity(0.2)
                                    : Theme.of(context).colorScheme.outline.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                item.count.toString(),
                                style: theme.textTheme.labelSmall?.copyWith(
                                  fontWeight: FontWeight.w700,
                                  fontSize: 11,
                                  color: isActive
                                      ? item.tint
                                      : theme.colorScheme.onSurface,
                                ),
                              ),
                            ),
                            if (isActive) ...[
                              const SizedBox(width: AppTheme.spacingXS),
                              Icon(
                                Icons.check_circle_rounded,
                                size: 14,
                                color: item.tint,
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                );
              },
            )
            .toList(),
      ),
    );
  }

  List<Map<String, dynamic>> _applySearchAndFilter(List<Map<String, dynamic>> entries) {
    final query = _query.toLowerCase();
    return entries.where((e) {
      // Request type filter
      if (_requestTypeFilter != null) {
        final requestType = e['requestType'] ?? e['request']?['requestType'];
        if (_requestTypeFilter == 'vehicle') {
          if (requestType != 'vehicle' && requestType != null) return false;
        } else {
          if (requestType != _requestTypeFilter) return false;
        }
      }
      
      // action filter
      if (_actionFilter != 'all') {
        final action = (e['action'] ?? '').toString().toLowerCase();
        if (action != _actionFilter) return false;
      }
      // search text across multiple fields
      if (query.isEmpty) return true;
      final fields = <String>[
        (e['summary'] ?? '').toString(),
        (e['notes'] ?? '').toString(),
        (e['status'] ?? '').toString(),
        (e['stage'] ?? '').toString(),
        (e['currentStage'] ?? '').toString(),
        (e['action'] ?? '').toString(),
        if (e['performedBy'] is Map) ...[
          ((e['performedBy'] as Map)['name'] ?? '').toString(),
          ((e['performedBy'] as Map)['email'] ?? '').toString(),
        ],
      ].join(' ').toLowerCase();
      return fields.contains(query);
    }).toList();
  }

  Map<String, List<Map<String, dynamic>>> _groupByRequestNumber(
    List<Map<String, dynamic>> entries,
  ) {
    final Map<String, List<Map<String, dynamic>>> grouped = {};
    for (final e in entries) {
      final id = (e['requestId'] ?? '').toString();
      if (id.isEmpty) continue;
      final numKey = '#${id.substring(id.length >= 6 ? id.length - 6 : 0).toUpperCase()}';
      grouped.putIfAbsent(numKey, () => []);
      grouped[numKey]!.add(e);
    }
    // sort each group by performedAt desc
    for (final list in grouped.values) {
      list.sort((a, b) {
        final atA = a['performedAt'] != null ? DateTime.tryParse(a['performedAt'].toString())?.millisecondsSinceEpoch ?? 0 : 0;
        final atB = b['performedAt'] != null ? DateTime.tryParse(b['performedAt'].toString())?.millisecondsSinceEpoch ?? 0 : 0;
        return atB.compareTo(atA);
      });
    }
    return grouped;
  }

  Widget _buildGroupTile(BuildContext context, String groupTitle, List<Map<String, dynamic>> items) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    return Container(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
      decoration: BoxDecoration(
        borderRadius: AppTheme.bradiusM,
        border: Border.all(color: colorScheme.outline.withOpacity(0.12)),
        color: colorScheme.surface,
      ),
      child: ExpansionTile(
        tilePadding: const EdgeInsets.symmetric(horizontal: AppTheme.spacingM),
        childrenPadding: const EdgeInsets.fromLTRB(AppTheme.spacingM, 0, AppTheme.spacingM, AppTheme.spacingM),
        title: Row(
          children: [
            Text(groupTitle, style: theme.textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
            const SizedBox(width: AppTheme.spacingS),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
              decoration: BoxDecoration(
                color: colorScheme.secondary.withOpacity(0.12),
                borderRadius: AppTheme.bradiusS,
              ),
              child: Text('${items.length}', style: theme.textTheme.labelSmall?.copyWith(color: colorScheme.secondary)),
            ),
          ],
        ),
        children: [
          ...List.generate(items.length, (index) {
            final entry = items[index];
            return Column(
              children: [
                _buildHistoryItem(context, entry),
                if (index != items.length - 1)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: AppTheme.spacingS),
                    child: Divider(
                      height: 1,
                      thickness: 1,
                      color: colorScheme.outlineVariant.withOpacity(0.12),
                    ),
                  ),
              ],
            );
          }),
        ],
      ),
    );
  }

  Widget _buildHistoryItem(BuildContext context, Map<String, dynamic> entry) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    String _formatLabel(String? value) {
      if (value == null || value.isEmpty) return '';
      return _formatLabelValue(value);
    }

    String? _formatTime(String? value) {
      if (value == null || value.isEmpty) return null;
      try {
        final parsed = DateTime.parse(value).toLocal();
        return DateFormat('MMM d, yyyy • HH:mm').format(parsed);
      } catch (_) {
        return null;
      }
    }

    final actionLabel = _formatLabel(entry['action']?.toString());
    final stageLabel = _formatLabel(
      entry['stage']?.toString().isNotEmpty == true
          ? entry['stage'].toString()
          : entry['currentStage']?.toString(),
    );
    final statusLabel = _formatLabel(entry['status']?.toString());
    final performer = entry['performedBy'];
    final performerName = performer is Map<String, dynamic>
        ? (performer['name'] ?? performer['email'] ?? 'Someone')
        : 'Someone';
    final timestamp = _formatTime(entry['performedAt']?.toString());
    final notes = entry['notes']?.toString().trim();
    final summary = entry['summary']?.toString().trim();
    final requestId = entry['requestId']?.toString();

    return AppCard(
      backgroundColor: theme.colorScheme.surface,
      borderColor: theme.colorScheme.outline.withOpacity(0.12),
      padding: const EdgeInsets.all(AppTheme.spacingM),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (requestId != null && requestId.isNotEmpty)
            Text(
              '#${requestId.substring(requestId.length >= 6 ? requestId.length - 6 : 0).toUpperCase()}',
              style: theme.textTheme.labelSmall?.copyWith(
                color: colorScheme.onSurfaceVariant,
                letterSpacing: 0.6,
              ),
            ),
          if (requestId != null && requestId.isNotEmpty) const SizedBox(height: AppTheme.spacingXS),
          Wrap(
            spacing: AppTheme.spacingXS,
            runSpacing: AppTheme.spacingXS,
            children: [
              if (actionLabel.isNotEmpty) _badge(context, actionLabel, colorScheme.primary, colorScheme.onPrimary),
              if (stageLabel.isNotEmpty) _badge(context, stageLabel, colorScheme.secondary, colorScheme.onSecondary),
              if (statusLabel.isNotEmpty) _badge(context, statusLabel, colorScheme.tertiary, colorScheme.onTertiary),
            ],
          ),
          const SizedBox(height: AppTheme.spacingXS),
          Row(
            children: [
              Icon(Icons.person_outline_rounded, size: 16, color: colorScheme.onSurfaceVariant),
              const SizedBox(width: AppTheme.spacingXS),
              Expanded(
                child: Text(
                  performerName,
                  style: theme.textTheme.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              if (timestamp != null) ...[
                const SizedBox(width: AppTheme.spacingS),
                Icon(Icons.access_time_rounded, size: 14, color: colorScheme.onSurfaceVariant),
                const SizedBox(width: AppTheme.spacingXS),
                Text(
                  timestamp,
                  style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
                ),
              ],
            ],
          ),
          if (summary != null && summary.isNotEmpty) ...[
            const SizedBox(height: AppTheme.spacingXS),
            Text(summary, style: theme.textTheme.bodyMedium),
          ],
          if ((notes ?? '').isNotEmpty && summary != notes) ...[
            const SizedBox(height: AppTheme.spacingXS),
            Text(
              notes!,
              style: theme.textTheme.bodySmall?.copyWith(color: colorScheme.onSurfaceVariant),
            ),
          ],
        ],
      ),
    );
  }

  Widget _badge(BuildContext context, String label, Color bg, Color? fg) {
    final theme = Theme.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppTheme.spacingS,
        vertical: AppTheme.spacingXS,
      ),
      decoration: BoxDecoration(
        color: bg.withOpacity(0.16),
        borderRadius: AppTheme.bradiusS,
        border: Border.all(color: bg.withOpacity(0.24)),
      ),
      child: Text(
        label,
        style: theme.textTheme.labelSmall?.copyWith(
          fontWeight: FontWeight.w600,
          color: fg ?? bg,
        ),
      ),
    );
  }
}

class _DrawerLeadingButton extends StatelessWidget {
  const _DrawerLeadingButton({this.onMenuPressed});
  final VoidCallback? onMenuPressed;
  @override
  Widget build(BuildContext context) {
    final controller =
        DrawerControllerScope.maybeOf(context) ?? context.watch<AdvancedDrawerController?>();
    if (controller == null) {
      return IconButton(
        icon: const Icon(Icons.menu_rounded),
        onPressed: onMenuPressed,
        tooltip: 'Menu',
      );
    }
    return ValueListenableBuilder<AdvancedDrawerValue>(
      valueListenable: controller,
      builder: (context, value, child) {
        return IconButton(
          icon: Icon(value.visible ? Icons.close_rounded : Icons.menu_rounded),
          onPressed: () {
            if (value.visible) {
              controller.hideDrawer();
            } else {
              controller.showDrawer();
            }
          },
          tooltip: 'Menu',
        );
      },
    );
  }
}


