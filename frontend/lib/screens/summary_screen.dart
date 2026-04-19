import 'package:flutter/material.dart';

import '../models/session_summary.dart';
import '../services/api_service.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({
    super.key,
    required this.apiService,
    required this.sessionId,
    required this.onBack,
  });

  final ApiService apiService;
  final String sessionId;
  final VoidCallback onBack;

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  late Future<SessionSummary> _summaryFuture;

  @override
  void initState() {
    super.initState();
    _summaryFuture = widget.apiService.getSessionSummary(widget.sessionId);
  }

  void _reload() {
    setState(() {
      _summaryFuture = widget.apiService.getSessionSummary(widget.sessionId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Summary'),
        leading: IconButton(
          onPressed: widget.onBack,
          icon: const Icon(Icons.arrow_back),
        ),
        actions: [
          IconButton(
            tooltip: 'Refresh',
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<SessionSummary>(
        future: _summaryFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(snapshot.error.toString(), textAlign: TextAlign.center),
                    const SizedBox(height: 12),
                    FilledButton(
                      onPressed: _reload,
                      child: const Text('Retry'),
                    ),
                  ],
                ),
              ),
            );
          }

          final summary = snapshot.data;
          if (summary == null) {
            return const Center(child: Text('No summary available'));
          }

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(summary.vendorName, style: Theme.of(context).textTheme.titleLarge),
                      const SizedBox(height: 8),
                      Text('Session: ${summary.sessionId}'),
                      Text('Status: ${summary.status}'),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              _MetricTile(label: 'Total issued', value: summary.totalIssued.toString()),
              _MetricTile(label: 'Total returned', value: summary.totalReturned.toString()),
              _MetricTile(label: 'Sold', value: summary.totalSold.toString()),
              _MetricTile(label: 'Bill', value: summary.totalBill.toStringAsFixed(2)),
              const SizedBox(height: 16),
              Text('Plant breakdown', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              ...summary.plants.map(
                (plant) => Card(
                  child: ListTile(
                    title: Text(plant.name),
                    subtitle: Text(
                      'Issued: ${plant.issued}  Returned: ${plant.returned}  Sold: ${plant.sold}',
                    ),
                    trailing: Text(plant.total.toStringAsFixed(2)),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _MetricTile extends StatelessWidget {
  const _MetricTile({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: ListTile(
        title: Text(label),
        trailing: Text(
          value,
          style: Theme.of(context).textTheme.titleMedium,
        ),
      ),
    );
  }
}
