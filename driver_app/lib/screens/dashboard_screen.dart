import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import '../providers/trips_provider.dart';
import '../providers/auth_provider.dart';
import 'active_trip_screen.dart';
import 'trip_history_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Provider.of<TripsProvider>(context, listen: false).loadTrips();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('My Trips'),
        actions: [
          IconButton(
            icon: const Icon(Icons.history),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const TripHistoryScreen()),
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await Provider.of<AuthProvider>(context, listen: false).logout();
              if (mounted) {
                Navigator.of(context).pushReplacementNamed('/login');
              }
            },
          ),
        ],
      ),
      body: Consumer<TripsProvider>(
        builder: (context, tripsProvider, _) {
          if (tripsProvider.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (tripsProvider.activeTrip != null) {
            return Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.directions_car, size: 64, color: Colors.green),
                  const SizedBox(height: 16),
                  const Text(
                    'Active Trip',
                    style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 32),
                  ElevatedButton(
                    onPressed: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ActiveTripScreen(
                            tripId: tripsProvider.activeTrip!['_id'],
                          ),
                        ),
                      );
                    },
                    child: const Text('View Active Trip'),
                  ),
                ],
              ),
            );
          }

          if (tripsProvider.trips.isEmpty) {
            return const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.inbox, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('No active trips'),
                ],
              ),
            );
          }

          return RefreshIndicator(
            onRefresh: () => tripsProvider.loadTrips(),
            child: ListView.builder(
              padding: const EdgeInsets.all(8),
              itemCount: tripsProvider.trips.length,
              itemBuilder: (context, index) {
                final trip = tripsProvider.trips[index];
                return Card(
                  margin: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
                  child: ListTile(
                    leading: const Icon(Icons.directions_car, color: Colors.blue),
                    title: Text(trip['endLocation']?['address'] ?? 'Unknown destination'),
                    subtitle: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (trip['startTime'] != null)
                          Text('Started: ${DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(trip['startTime']))}'),
                        Text('Status: ${trip['status'] ?? ''}'),
                      ],
                    ),
                    trailing: const Icon(Icons.arrow_forward_ios),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) => ActiveTripScreen(tripId: trip['_id']),
                        ),
                      );
                    },
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

