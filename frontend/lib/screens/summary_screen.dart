import 'package:flutter/material.dart';

import '../models/session_close_result.dart';
import '../models/session_summary.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({
    super.key,
    required this.apiService,
    required this.sessionId,
    this.closeResult,
  });

  final ApiService apiService;
  final String sessionId;
  final SessionCloseResult? closeResult;

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
                padding: const EdgeInsets.all(24),
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
            return const Center(child: Text('No summary available.'));
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
                      Text(summary.vendorName, style: Theme.of(context).textTheme.headlineSmall),
                      const SizedBox(height: 8),
                      Text('Status: ${summary.status}'),
                      if (widget.closeResult != null) ...[
                        const SizedBox(height: 8),
                        Text('Updated balance: ${formatCurrency(widget.closeResult!.vendorBalance)}'),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                crossAxisSpacing: 12,
                mainAxisSpacing: 12,
                childAspectRatio: 1.7,
                children: [
                  _SummaryCard(label: 'Total issued', value: '${summary.totalIssued}'),
                  _SummaryCard(label: 'Total returned', value: '${summary.totalReturned}'),
                  _SummaryCard(label: 'Total sold', value: '${summary.totalSold}'),
                  _SummaryCard(label: 'Total bill', value: formatCurrency(summary.totalBill)),
                ],
              ),
              const SizedBox(height: 16),
              Text('Plant Summary', style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 8),
              if (summary.plants.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No plant activity recorded yet.'),
                  ),
                )
              else
                ...summary.plants.map(
                  (plant) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(plant.name, style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: _PlantMetric(label: 'Issued', value: '${plant.issued}')),
                                Expanded(child: _PlantMetric(label: 'Returned', value: '${plant.returned}')),
                                Expanded(child: _PlantMetric(label: 'Sold', value: '${plant.sold}')),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Bill: ${formatCurrency(plant.total)}'),
                          ],
                        ),
                      ),
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

class _SummaryCard extends StatelessWidget {
  const _SummaryCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(label),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}

class _PlantMetric extends StatelessWidget {
  const _PlantMetric({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label),
        const SizedBox(height: 4),
        Text(value, style: Theme.of(context).textTheme.titleMedium),
      ],
    );
  }
}
