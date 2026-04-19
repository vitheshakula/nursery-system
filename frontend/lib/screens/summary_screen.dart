import 'package:flutter/material.dart';

import '../models/session_summary.dart';
import '../services/api_service.dart';
import '../utils/formatters.dart';

class SummaryScreen extends StatefulWidget {
  const SummaryScreen({
    super.key,
    required this.apiService,
    required this.sessionId,
  });

  final ApiService apiService;
  final String sessionId;

  @override
  State<SummaryScreen> createState() => _SummaryScreenState();
}

class _SummaryScreenState extends State<SummaryScreen> {
  late Future<SessionSummary> _future;

  @override
  void initState() {
    super.initState();
    _future = widget.apiService.getSessionSummary(widget.sessionId);
  }

  void _reload() {
    setState(() {
      _future = widget.apiService.getSessionSummary(widget.sessionId);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Session Summary'),
        actions: [
          IconButton(
            onPressed: _reload,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: FutureBuilder<SessionSummary>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
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
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),
              GridView.count(
                crossAxisCount: 2,
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                childAspectRatio: 1.8,
                children: [
                  _MetricCard(label: 'Total issued', value: '${summary.totalIssued}'),
                  _MetricCard(label: 'Total returned', value: '${summary.totalReturned}'),
                  _MetricCard(label: 'Total sold', value: '${summary.totalSold}'),
                  _MetricCard(label: 'Total bill', value: formatCurrency(summary.totalBill)),
                ],
              ),
              const SizedBox(height: 20),
              Text('Item details', style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 12),
              if (summary.items.isEmpty)
                const Card(
                  child: Padding(
                    padding: EdgeInsets.all(16),
                    child: Text('No items in this session yet.'),
                  ),
                )
              else
                ...summary.items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(item.name, style: Theme.of(context).textTheme.titleMedium),
                            const SizedBox(height: 12),
                            Row(
                              children: [
                                Expanded(child: _MiniStat(label: 'Issued', value: '${item.issued}')),
                                Expanded(child: _MiniStat(label: 'Returned', value: '${item.returned}')),
                                Expanded(child: _MiniStat(label: 'Sold', value: '${item.sold}')),
                              ],
                            ),
                            const SizedBox(height: 10),
                            Text('Bill: ${formatCurrency(item.total)}'),
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

class _MetricCard extends StatelessWidget {
  const _MetricCard({
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
            const SizedBox(height: 6),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
          ],
        ),
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  const _MiniStat({
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
