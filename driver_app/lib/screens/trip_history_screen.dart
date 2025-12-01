import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/trips_provider.dart';
import '../theme/app_theme.dart';
import '../modules/trips/screens/trip_details_screen.dart';

class TripHistoryScreen extends StatefulWidget {
  const TripHistoryScreen({super.key, this.onMenuPressed});

  final VoidCallback? onMenuPressed;

  @override
  State<TripHistoryScreen> createState() => _TripHistoryScreenState();
}

class _TripHistoryScreenState extends State<TripHistoryScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: widget.onMenuPressed != null
            ? IconButton(
                icon: const Icon(Icons.menu),
                onPressed: widget.onMenuPressed,
              )
            : null,
        title: const Text('Trip History'),
      ),
      body: Consumer<TripsProvider>(
        builder: (context, tripsProvider, _) {
          // Note: This would need a new endpoint to get completed trips
          // For now, showing empty state
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
        },
      ),
    );
  }
}

