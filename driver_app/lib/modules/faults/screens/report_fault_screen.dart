import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../../modules/faults/providers/faults_provider.dart';
import '../../../theme/app_theme.dart';

class ReportFaultScreen extends StatefulWidget {
  const ReportFaultScreen({super.key, required this.vehicleId});

  final String vehicleId;

  @override
  State<ReportFaultScreen> createState() => _ReportFaultScreenState();
}

class _ReportFaultScreenState extends State<ReportFaultScreen> {
  final _formKey = GlobalKey<FormState>();
  final _descriptionController = TextEditingController();
  String _selectedCategory = 'engine';
  String _selectedPriority = 'medium';
  bool _isSubmitting = false;

  final List<String> _categories = [
    'engine',
    'brakes',
    'tires',
    'electrical',
    'body',
    'other',
  ];

  final List<String> _priorities = ['low', 'medium', 'high', 'critical'];

  @override
  void dispose() {
    _descriptionController.dispose();
    super.dispose();
  }

  Future<void> _submitFault() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isSubmitting = true;
    });

    final faultsProvider = Provider.of<FaultsProvider>(context, listen: false);
    final success = await faultsProvider.reportFault(
      vehicleId: widget.vehicleId,
      category: _selectedCategory,
      description: _descriptionController.text,
      priority: _selectedPriority,
    );

    setState(() {
      _isSubmitting = false;
    });

    if (success && mounted) {
      Navigator.pop(context);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Fault reported successfully')),
      );
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Failed to report fault')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Report Fault'),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.all(AppTheme.spacingL),
          children: [
            DropdownButtonFormField<String>(
              value: _selectedCategory,
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
              items: _categories.map((category) {
                return DropdownMenuItem(
                  value: category,
                  child: Text(category.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedCategory = value;
                  });
                }
              },
            ),
            const SizedBox(height: AppTheme.spacingL),
            DropdownButtonFormField<String>(
              value: _selectedPriority,
              decoration: const InputDecoration(
                labelText: 'Priority',
                border: OutlineInputBorder(),
              ),
              items: _priorities.map((priority) {
                return DropdownMenuItem(
                  value: priority,
                  child: Text(priority.toUpperCase()),
                );
              }).toList(),
              onChanged: (value) {
                if (value != null) {
                  setState(() {
                    _selectedPriority = value;
                  });
                }
              },
            ),
            const SizedBox(height: AppTheme.spacingL),
            TextFormField(
              controller: _descriptionController,
              decoration: const InputDecoration(
                labelText: 'Description',
                border: OutlineInputBorder(),
                hintText: 'Describe the fault in detail...',
              ),
              maxLines: 5,
              validator: (value) {
                if (value == null || value.isEmpty) {
                  return 'Please enter a description';
                }
                return null;
              },
            ),
            const SizedBox(height: AppTheme.spacingXL),
            ElevatedButton(
              onPressed: _isSubmitting ? null : _submitFault,
              child: _isSubmitting
                  ? const SizedBox(
                      height: 20,
                      width: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Submit Report'),
            ),
          ],
        ),
      ),
    );
  }
}

