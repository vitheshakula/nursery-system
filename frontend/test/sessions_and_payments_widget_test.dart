import 'package:flutter/material.dart';
import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nursery_frontend/core/network/api_client.dart';
import 'package:nursery_frontend/features/sessions/application/session_controller.dart';
import 'package:nursery_frontend/features/vendors/data/vendor_api.dart';
import 'package:nursery_frontend/features/vendors/presentation/vendor_provider.dart';
import 'package:nursery_frontend/models/active_session.dart';
import 'package:nursery_frontend/models/payment.dart';
import 'package:nursery_frontend/models/vendor.dart';
import 'package:nursery_frontend/models/vendor_session.dart';
import 'package:nursery_frontend/screens/sessions_tab_screen.dart';
import 'package:nursery_frontend/screens/vendor_detail_screen.dart';

void main() {
  test('ActiveSession parses API response and maps to session/vendor models',
      () {
    final activeSession = ActiveSession.fromJson({
      'id': 'session-1',
      'vendorId': 'vendor-1',
      'status': 'ACTIVE',
      'totalIssued': 10,
      'totalReturned': 3,
      'totalBill': 210.5,
      'vendor': {
        'id': 'vendor-1',
        'name': 'Patil Plants',
        'phone': '9999999999',
        'balance': 450.0,
      },
    });

    expect(activeSession.vendorName, 'Patil Plants');
    expect(activeSession.totalBill, 210.5);
    expect(activeSession.toSessionInfo().id, 'session-1');
    expect(activeSession.toVendor().balance, 450);
  });

  testWidgets('Sessions tab renders empty state and start action',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeSessionsProvider.overrideWith((ref) async => []),
        ],
        child: const MaterialApp(home: SessionsTabScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('No active sessions'), findsOneWidget);
    expect(
      find.text("Start a session to track today's activity"),
      findsOneWidget,
    );
    expect(find.text('Start Session'), findsOneWidget);
  });

  testWidgets('Sessions tab never renders blank while loading', (tester) async {
    final completer = Completer<List<ActiveSession>>();

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeSessionsProvider.overrideWith((ref) => completer.future),
        ],
        child: const MaterialApp(home: SessionsTabScreen()),
      ),
    );

    await tester.pump();

    expect(find.text('Sessions'), findsOneWidget);
    expect(find.byType(CircularProgressIndicator), findsOneWidget);

    completer.complete([]);
  });

  testWidgets('Sessions tab renders active sessions lazily', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          activeSessionsProvider.overrideWith(
            (ref) async => [
              const ActiveSession(
                id: 'session-1',
                vendorId: 'vendor-1',
                vendorName: 'Patil Plants',
                vendorPhone: '9999999999',
                vendorBalance: 300,
                status: 'ACTIVE',
                totalIssued: 12,
                totalReturned: 2,
                totalBill: 250,
              ),
            ],
          ),
        ],
        child: const MaterialApp(home: SessionsTabScreen()),
      ),
    );

    await tester.pumpAndSettle();

    expect(find.text('Active Sessions'), findsOneWidget);
    expect(find.text('Patil Plants'), findsOneWidget);
    expect(find.text('In Progress'), findsOneWidget);
    expect(find.text('Current balance Rs 250.00'), findsOneWidget);
  });

  testWidgets('Collect payment screen pre-fills full pending balance',
      (tester) async {
    await tester.pumpWidget(
      const ProviderScope(
        child: MaterialApp(
          home: CollectPaymentScreen(
            vendor: Vendor(
              id: 'vendor-1',
              name: 'Patil Plants',
              phone: '9999999999',
              balance: 700,
            ),
            initialAmount: 700,
          ),
        ),
      ),
    );

    expect(find.text('Collect Payment'), findsOneWidget);
    expect(find.text('Patil Plants'), findsOneWidget);
    expect(find.text('Rs 700.00'), findsOneWidget);
    expect(find.widgetWithText(TextField, 'Amount'), findsOneWidget);
    expect(find.text('Cash'), findsOneWidget);
    expect(find.text('UPI'), findsOneWidget);
    expect(find.text('Confirm Payment'), findsOneWidget);
  });

  testWidgets('Vendor detail renders header, today, actions, and history tabs',
      (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vendorApiProvider.overrideWithValue(_FakeVendorApi()),
          sessionsProvider.overrideWith(
            (ref, vendorId) async => <VendorSession>[
              VendorSession(
                id: 'session-1',
                status: 'ACTIVE',
                totalIssued: 5,
                totalReturned: 1,
                totalSold: 4,
                totalBill: 100,
                createdAt: DateTime(2026, 5, 1),
              ),
            ],
          ),
          paymentsProvider.overrideWith(
            (ref, vendorId) async => <PaymentRecord>[
              PaymentRecord(
                id: 'payment-1',
                vendorId: vendorId,
                amount: 50,
                mode: 'CASH',
                createdAt: DateTime(2026, 5, 2),
              ),
            ],
          ),
        ],
        child: const MaterialApp(
          home: VendorDetailScreen(
            vendor: Vendor(
              id: 'vendor-1',
              name: 'Patil Plants',
              phone: '9999999999',
              balance: 350,
            ),
          ),
        ),
      ),
    );

    await tester.pump();

    expect(find.text('Vendor Details'), findsOneWidget);
    expect(find.text('Patil Plants'), findsOneWidget);
    expect(find.text('Total Pending'), findsOneWidget);
    expect(find.text('Today'), findsOneWidget);
    expect(find.text('Collect Payment'), findsOneWidget);
    expect(find.text('Settle Full Amount'), findsOneWidget);
    expect(find.text('Sessions'), findsOneWidget);
    expect(find.text('Payments'), findsOneWidget);
  });
}

class _FakeVendorApi extends VendorApi {
  _FakeVendorApi() : super(ApiClient(baseUrl: 'http://localhost'));

  @override
  Future<Vendor> getVendor(String id) async {
    return const Vendor(
      id: 'vendor-1',
      name: 'Patil Plants',
      phone: '9999999999',
      balance: 350,
    );
  }
}
