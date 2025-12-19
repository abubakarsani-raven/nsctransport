import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../providers/trips_provider.dart';
import '../../../theme/app_theme.dart';
import '../../../widgets/navigation/drawer_menu_button.dart';
import 'active_trip_screen.dart';

class TripDetailsScreen extends StatefulWidget {
  const TripDetailsScreen({super.key, required this.tripId});

  final String tripId;

  @override
  State<TripDetailsScreen> createState() => _TripDetailsScreenState();
}

class _TripDetailsScreenState extends State<TripDetailsScreen> {
  Map<String, dynamic>? _tripData;

  @override
  void initState() {
    super.initState();
    _loadTripDetails();
  }

  Future<void> _loadTripDetails() async {
    try {
      final tripsProvider = Provider.of<TripsProvider>(context, listen: false);
      await tripsProvider.loadTrip(widget.tripId);
      if (mounted) {
        setState(() {
          _tripData = tripsProvider.activeTrip;
        });
      }
    } catch (e) {
      debugPrint('Error loading trip details: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Failed to load trip details: ${e.toString()}')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_tripData == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Trip Details')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    final trip = _tripData!;
    final request = trip['requestId'];
    final vehicle = trip['vehicleId'] ?? request?['assignedVehicleId'];
    final requester = request?['requesterId'];
    final participants = request?['participantIds'] ?? [];
    final actionHistory = request?['actionHistory'] ?? [];
    
    // Check if trip is completed
    final tripStatus = trip['status']?.toString().toLowerCase() ?? '';
    final isCompleted = tripStatus == 'completed' || tripStatus == 'COMPLETED';
    
    // Safely extract vehicle and requester data
    // They might be Maps (populated objects) or Strings (just IDs)
    final vehicleData = vehicle is Map<String, dynamic> ? vehicle : null;
    final requesterData = requester is Map<String, dynamic> ? requester : null;

    return Scaffold(
      appBar: AppBar(
        leading: const DrawerMenuButton(),
        title: const Text('Trip Details'),
        actions: [
          // Map button - only show for non-completed trips, or show read-only map for completed
          IconButton(
            icon: const Icon(Icons.map),
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ActiveTripScreen(
                    tripId: widget.tripId,
                    isReadOnly: isCompleted,
                  ),
                ),
              );
            },
            tooltip: isCompleted ? 'View Route (Read Only)' : 'View on Map',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadTripDetails,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          children: [
            // Trip Info Section
            _buildSectionCard(
              context,
              'Trip Information',
              Icons.info,
              [
                _buildInfoRow('Status', _formatStatus(trip['status'] ?? 'unknown'), Icons.info),
                if (trip['startTime'] != null)
                  _buildInfoRow(
                    'Start Time',
                    DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(trip['startTime'])),
                    Icons.play_arrow,
                  ),
                if (trip['endTime'] != null)
                  _buildInfoRow(
                    'End Time',
                    DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(trip['endTime'])),
                    Icons.stop,
                  ),
                if (trip['distance'] != null)
                  _buildInfoRow(
                    'Distance',
                    '${trip['distance'].toStringAsFixed(2)} km',
                    Icons.straighten,
                  ),
                if (trip['duration'] != null)
                  _buildInfoRow(
                    'Duration',
                    _formatDuration(trip['duration']),
                    Icons.timer,
                  ),
                if (trip['averageSpeed'] != null)
                  _buildInfoRow(
                    'Average Speed',
                    '${trip['averageSpeed'].toStringAsFixed(1)} km/h',
                    Icons.speed,
                  ),
              ],
            ),

            // Vehicle Section
            if (vehicleData != null)
              _buildSectionCard(
                context,
                'Vehicle Information',
                Icons.directions_car,
                [
                  if (vehicleData['make'] != null)
                    _buildInfoRow('Make', vehicleData['make'], Icons.branding_watermark),
                  if (vehicleData['model'] != null)
                    _buildInfoRow('Model', vehicleData['model'], Icons.category),
                  if (vehicleData['plateNumber'] != null)
                    _buildInfoRow('Plate Number', vehicleData['plateNumber'], Icons.confirmation_number),
                  if (vehicleData['capacity'] != null)
                    _buildInfoRow('Capacity', '${vehicleData['capacity']} passengers', Icons.people),
                  if (vehicleData['year'] != null)
                    _buildInfoRow('Year', vehicleData['year'].toString(), Icons.calendar_today),
                ],
              ),

            // Requester Section
            if (requesterData != null)
              _buildSectionCard(
                context,
                'Requester Information',
                Icons.person,
                [
                  if (requesterData['name'] != null)
                    _buildInfoRow('Name', requesterData['name'], Icons.person),
                  if (requesterData['email'] != null)
                    _buildContactRow(
                      'Email',
                      requesterData['email'],
                      Icons.email,
                      () => _launchEmail(requesterData['email']),
                    ),
                  if (requesterData['phone'] != null)
                    _buildContactRow(
                      'Phone',
                      requesterData['phone'],
                      Icons.phone,
                      () => _launchPhone(requesterData['phone']),
                    ),
                  if (requesterData['department'] != null)
                    _buildInfoRow('Department', requesterData['department'], Icons.business),
                ],
              ),

            // Participants Section
            if (participants.isNotEmpty)
              _buildSectionCard(
                context,
                'Participants (${participants.length})',
                Icons.people,
                participants.map<Widget>((participant) {
                  if (participant is Map<String, dynamic>) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (participant['name'] != null)
                            _buildInfoRow('Name', participant['name'], Icons.person),
                          if (participant['email'] != null)
                            _buildContactRow(
                              'Email',
                              participant['email'],
                              Icons.email,
                              () => _launchEmail(participant['email']),
                            ),
                          if (participant['phone'] != null)
                            _buildContactRow(
                              'Phone',
                              participant['phone'],
                              Icons.phone,
                              () => _launchPhone(participant['phone']),
                            ),
                          if (participant['department'] != null)
                            _buildInfoRow('Department', participant['department'], Icons.business),
                          if (participants.indexOf(participant) < participants.length - 1)
                            const Divider(),
                        ],
                      ),
                    );
                  }
                  return const SizedBox.shrink();
                }).toList(),
              ),

            // Trip History Section
            if (actionHistory.isNotEmpty)
              _buildSectionCard(
                context,
                'Trip History',
                Icons.history,
                actionHistory.map<Widget>((action) {
                  final performedBy = action['performedBy'];
                  final performedAt = action['performedAt'];
                  final notes = action['notes'];
                  final stage = action['stage'];
                  
                  return Padding(
                    padding: const EdgeInsets.only(bottom: AppTheme.spacingM),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        if (performedAt != null)
                          Text(
                            DateFormat('MMM dd, yyyy HH:mm').format(DateTime.parse(performedAt)),
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.neutral60,
                                  fontWeight: FontWeight.bold,
                                ),
                          ),
                        const SizedBox(height: 4),
                        if (stage != null)
                          Text(
                            'Stage: $stage',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.primaryColor,
                                ),
                          ),
                        if (notes != null)
                          Text(
                            notes,
                            style: Theme.of(context).textTheme.bodyMedium,
                          ),
                        if (performedBy is Map && performedBy['name'] != null)
                          Text(
                            'By: ${performedBy['name']}',
                            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                                  color: AppTheme.neutral60,
                                ),
                          ),
                        if (actionHistory.indexOf(action) < actionHistory.length - 1)
                          const Divider(),
                      ],
                    ),
                  );
                }).toList(),
              ),
          ],
        ),
      ),
    );
  }

  Widget _buildSectionCard(
    BuildContext context,
    String title,
    IconData icon,
    List<Widget> children,
  ) {
    return Card(
      margin: const EdgeInsets.only(bottom: AppTheme.spacingM),
      child: Padding(
        padding: const EdgeInsets.all(AppTheme.spacingL),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, color: AppTheme.primaryColor),
                const SizedBox(width: AppTheme.spacingS),
                Text(
                  title,
                  style: Theme.of(context).textTheme.titleLarge?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                ),
              ],
            ),
            const SizedBox(height: AppTheme.spacingM),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: Row(
        children: [
          Icon(icon, size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: AppTheme.spacingS),
          Text(
            '$label: ',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
          ),
          Expanded(
            child: Text(
              value,
              style: Theme.of(context).textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactRow(String label, String value, IconData icon, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppTheme.spacingS),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            Icon(icon, size: 20, color: AppTheme.primaryColor),
            const SizedBox(width: AppTheme.spacingS),
            Text(
              '$label: ',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            Expanded(
              child: Text(
                value,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppTheme.primaryColor,
                      decoration: TextDecoration.underline,
                    ),
              ),
            ),
            const Icon(Icons.open_in_new, size: 16, color: AppTheme.primaryColor),
          ],
        ),
      ),
    );
  }

  String _formatStatus(String status) {
    return status.split('_').map((word) {
      return word[0].toUpperCase() + word.substring(1).toLowerCase();
    }).join(' ');
  }

  String _formatDuration(double minutes) {
    if (minutes < 60) {
      return '${minutes.toInt()} minutes';
    }
    final hours = (minutes / 60).floor();
    final mins = (minutes % 60).toInt();
    if (mins == 0) {
      return '$hours hour${hours > 1 ? 's' : ''}';
    }
    return '$hours hour${hours > 1 ? 's' : ''} $mins minute${mins > 1 ? 's' : ''}';
  }

  Future<void> _launchEmail(String email) async {
    final uri = Uri.parse('mailto:$email');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot open email: $email')),
        );
      }
    }
  }

  Future<void> _launchPhone(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Cannot make call: $phone')),
        );
      }
    }
  }
}
