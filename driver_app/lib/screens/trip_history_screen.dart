import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

class TripHistoryScreen extends StatelessWidget {
  const TripHistoryScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Trip History')),
      body: const Center(
        child: Text('Trip history will be displayed here'),
      ),
    );
  }
}

