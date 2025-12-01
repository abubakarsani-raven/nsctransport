import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/trips_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/navigation/drawer_menu_button.dart';
import 'trip_details_screen.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key, this.onMenuPressed});

  final VoidCallback? onMenuPressed;

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  @override
  void initState() {
    super.initState();
    // Load completed trips when screen is opened
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TripsProvider>(context, listen: false).loadCompletedTrips();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: DrawerMenuButton(onMenuPressed: widget.onMenuPressed),
        title: const Text('Trip History'),
      ),
      body: Consumer<TripsProvider>(
        builder: (context, tripsProvider, _) {
          if (tripsProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          final completedTrips = tripsProvider.completedTrips;

          if (completedTrips.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.history, size: 64, color: AppTheme.neutral40),
                  const SizedBox(height: AppTheme.spacingM),
                  Text(
                    'No trip history',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: AppTheme.spacingS),
                  Text(
                    'Completed trips will appear here',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: AppTheme.neutral60,
                        ),
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => tripsProvider.loadCompletedTrips(),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              itemCount: completedTrips.length,
              itemBuilder: (context, index) {
                final trip = completedTrips[index];
                final request = trip['requestId'];
                final status = trip['status'] ?? 'completed';
                final endTime = trip['endTime'];
                final distance = trip['distance'];
                final duration = trip['duration'];
                final averageSpeed = trip['averageSpeed'];

                return Card(
                  margin: const EdgeInsets.only(bottom: AppTheme.spacingS),
                  child: InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => TripDetailsScreen(tripId: trip['_id']),
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.all(AppTheme.spacingM),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: AppTheme.spacingS,
                                  vertical: 4,
                                ),
                                decoration: BoxDecoration(
                                  color: status == 'completed'
                                      ? AppTheme.successColor.withOpacity(0.1)
                                      : AppTheme.primaryColor.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  status.toUpperCase(),
                                  style: TextStyle(
                                    color: status == 'completed'
                                        ? AppTheme.successColor
                                        : AppTheme.primaryColor,
                                    fontSize: 12,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              ),
                              const Spacer(),
                              if (endTime != null)
                                Text(
                                  DateFormat('MMM dd, yyyy').format(
                                    DateTime.parse(endTime),
                                  ),
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(color: AppTheme.neutral60),
                                ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          Row(
                            children: [
                              const Icon(
                                Icons.location_on,
                                color: AppTheme.primaryColor,
                                size: 20,
                              ),
                              const SizedBox(width: AppTheme.spacingS),
                              Expanded(
                                child: Text(
                                  request?['destination'] ?? 'Unknown destination',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          Row(
                            children: [
                              if (distance != null)
                                Expanded(
                                  child: _buildInfoChip(
                                    Icons.straighten,
                                    '${distance.toStringAsFixed(1)} km',
                                  ),
                                ),
                              if (duration != null)
                                Expanded(
                                  child: _buildInfoChip(
                                    Icons.timer,
                                    _formatDuration(duration),
                                  ),
                                ),
                              if (averageSpeed != null)
                                Expanded(
                                  child: _buildInfoChip(
                                    Icons.speed,
                                    '${averageSpeed.toStringAsFixed(1)} km/h',
                                  ),
                                ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 16, color: AppTheme.neutral60),
        const SizedBox(width: 4),
        Flexible(
          child: Text(
            text,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(color: AppTheme.neutral60),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }

  String _formatDuration(double minutes) {
    if (minutes < 60) {
      return '${minutes.toInt()}m';
    }
    final hours = (minutes / 60).floor();
    final mins = (minutes % 60).toInt();
    return '${hours}h ${mins}m';
  }
}

