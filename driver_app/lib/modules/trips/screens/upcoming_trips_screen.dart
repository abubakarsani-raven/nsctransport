import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../../../providers/trips_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/navigation/drawer_menu_button.dart';
import 'active_trip_screen.dart';
import 'trip_details_screen.dart';

class UpcomingTripsScreen extends StatefulWidget {
  const UpcomingTripsScreen({super.key, this.onMenuPressed});

  final VoidCallback? onMenuPressed;

  @override
  State<UpcomingTripsScreen> createState() => _UpcomingTripsScreenState();
}

class _UpcomingTripsScreenState extends State<UpcomingTripsScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TripsProvider>(context, listen: false).loadUpcomingTrips();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: DrawerMenuButton(onMenuPressed: widget.onMenuPressed),
        title: const Text('Upcoming Trips'),
      ),
      body: Consumer<TripsProvider>(
        builder: (context, tripsProvider, _) {
          if (tripsProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (tripsProvider.upcomingTrips.isEmpty) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.schedule, size: 64, color: AppTheme.neutral40),
                  const SizedBox(height: AppTheme.spacingM),
                  Text(
                    'No upcoming trips',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => tripsProvider.loadUpcomingTrips(),
            child: ListView.builder(
              padding: const EdgeInsets.all(AppTheme.spacingM),
              itemCount: tripsProvider.upcomingTrips.length,
              itemBuilder: (context, index) {
                final trip = tripsProvider.upcomingTrips[index];
                final request = trip['requestId'];
                final vehicle = request?['assignedVehicleId'];
                final requester = request?['requesterId'];
                final passengerCount = request?['passengerCount'] ?? 0;
                
                // Safely extract vehicle and requester data
                // They might be Maps (populated objects) or Strings (just IDs)
                final vehicleData = vehicle is Map<String, dynamic> ? vehicle : null;
                final requesterData = requester is Map<String, dynamic> ? requester : null;
                
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
                              const Icon(Icons.directions_car, color: AppTheme.primaryColor),
                              const SizedBox(width: AppTheme.spacingS),
                              Expanded(
                                child: Text(
                                  request?['destination'] ?? 'Unknown destination',
                                  style: Theme.of(context).textTheme.titleMedium,
                                ),
                              ),
                              const Icon(Icons.chevron_right, color: AppTheme.neutral60),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          if (request?['startDate'] != null)
                            Row(
                              children: [
                                const Icon(Icons.schedule, size: 16, color: AppTheme.neutral60),
                                const SizedBox(width: 4),
                                Text(
                                  DateFormat('MMM dd, yyyy HH:mm').format(
                                    DateTime.parse(request['startDate']),
                                  ),
                                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                        color: AppTheme.neutral60,
                                      ),
                                ),
                              ],
                            ),
                          const SizedBox(height: AppTheme.spacingS),
                          Row(
                            children: [
                              if (vehicleData != null && vehicleData['plateNumber'] != null)
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.confirmation_number, size: 16, color: AppTheme.neutral60),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          vehicleData['plateNumber'],
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: AppTheme.neutral60,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              if (requesterData != null && requesterData['name'] != null)
                                Expanded(
                                  child: Row(
                                    children: [
                                      const Icon(Icons.person, size: 16, color: AppTheme.neutral60),
                                      const SizedBox(width: 4),
                                      Flexible(
                                        child: Text(
                                          requesterData['name'],
                                          style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                                color: AppTheme.neutral60,
                                              ),
                                          overflow: TextOverflow.ellipsis,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              Row(
                                children: [
                                  const Icon(Icons.people, size: 16, color: AppTheme.neutral60),
                                  const SizedBox(width: 4),
                                  Text(
                                    '$passengerCount',
                                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                          color: AppTheme.neutral60,
                                        ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                          const SizedBox(height: AppTheme.spacingS),
                          SizedBox(
                            width: double.infinity,
                            child: ElevatedButton(
                              onPressed: () {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => ActiveTripScreen(tripId: trip['_id']),
                                  ),
                                );
                              },
                              child: const Text('Start Trip'),
                            ),
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
}

