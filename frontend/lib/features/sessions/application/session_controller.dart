import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../models/category.dart';
import '../../../models/item.dart';
import '../../../models/session_close_result.dart';
import '../../../models/session_info.dart';
import '../../../models/session_summary.dart';
import '../../auth/presentation/auth_provider.dart';
import '../data/session_api.dart';

enum SessionMode {
  issue,
  returnItems,
}

class SessionState {
  const SessionState({
    required this.session,
    this.items = const <Item>[],
    this.categories = const <Category>[],
    this.quantities = const <String, int>{},
    this.selectedCategoryId = 'all',
    this.mode = SessionMode.issue,
    this.isLoading = false,
    this.isSubmitting = false,
    this.isClosing = false,
    this.errorMessage,
    this.summary,
  });

  final SessionInfo session;
  final List<Item> items;
  final List<Category> categories;
  final Map<String, int> quantities;
  final String selectedCategoryId;
  final SessionMode mode;
  final bool isLoading;
  final bool isSubmitting;
  final bool isClosing;
  final String? errorMessage;
  final SessionSummary? summary;

  int get totalQuantity {
    return quantities.values.fold<int>(0, (sum, quantity) => sum + quantity);
  }

  double get estimatedBill {
    return items.fold<double>(0, (sum, item) {
      return sum + ((quantities[item.id] ?? 0) * item.vendorPrice);
    });
  }

  SessionState copyWith({
    SessionInfo? session,
    List<Item>? items,
    List<Category>? categories,
    Map<String, int>? quantities,
    String? selectedCategoryId,
    SessionMode? mode,
    bool? isLoading,
    bool? isSubmitting,
    bool? isClosing,
    String? errorMessage,
    bool clearError = false,
    SessionSummary? summary,
  }) {
    return SessionState(
      session: session ?? this.session,
      items: items ?? this.items,
      categories: categories ?? this.categories,
      quantities: quantities ?? this.quantities,
      selectedCategoryId: selectedCategoryId ?? this.selectedCategoryId,
      mode: mode ?? this.mode,
      isLoading: isLoading ?? this.isLoading,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isClosing: isClosing ?? this.isClosing,
      errorMessage: clearError ? null : errorMessage ?? this.errorMessage,
      summary: summary ?? this.summary,
    );
  }
}

final sessionApiProvider = Provider<SessionApi>((ref) {
  return SessionApi(ref.watch(apiClientProvider));
});

final sessionControllerProvider = StateNotifierProvider.autoDispose
    .family<SessionController, SessionState, SessionInfo>((ref, session) {
  return SessionController(
    sessionApi: ref.watch(sessionApiProvider),
    initialSession: session,
  );
});

class SessionController extends StateNotifier<SessionState> {
  SessionController({
    required SessionApi sessionApi,
    required SessionInfo initialSession,
  })  : _sessionApi = sessionApi,
        super(SessionState(session: initialSession));

  final SessionApi _sessionApi;

  Future<void> loadData() async {
    state = state.copyWith(isLoading: true, clearError: true);

    try {
      final results = await Future.wait([
        _sessionApi.getItems(),
        _sessionApi.getCategories(),
      ]);
      state = state.copyWith(
        items: results[0] as List<Item>,
        categories: results[1] as List<Category>,
        isLoading: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isLoading: false,
        errorMessage: error.toString(),
      );
    }
  }

  Future<SessionInfo> startSession(String vendorId) async {
    final session = await _sessionApi.startSession(vendorId);
    state = state.copyWith(session: session, clearError: true);
    return session;
  }

  void changeQuantity(Item item, int delta) {
    final updated = Map<String, int>.from(state.quantities);
    final current = updated[item.id] ?? 0;
    final next = current + delta;

    if (next <= 0) {
      updated.remove(item.id);
    } else {
      updated[item.id] = next;
    }

    state = state.copyWith(quantities: updated);
  }

  void setMode(SessionMode mode) {
    state = state.copyWith(mode: mode);
  }

  void setSelectedCategory(String categoryId) {
    state = state.copyWith(selectedCategoryId: categoryId);
  }

  Future<void> issueItems() async {
    await _submitItems(SessionMode.issue);
  }

  Future<void> returnItems() async {
    await _submitItems(SessionMode.returnItems);
  }

  Future<SessionSummary> fetchSummary() async {
    final summary = await _sessionApi.getSessionSummary(state.session.id);
    state = state.copyWith(summary: summary, clearError: true);
    return summary;
  }

  Future<SessionCloseResult> closeSession() async {
    state = state.copyWith(isClosing: true, clearError: true);

    try {
      final result = await _sessionApi.closeSession(state.session.id);
      state = state.copyWith(isClosing: false, clearError: true);
      return result;
    } catch (error) {
      state = state.copyWith(
        isClosing: false,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }

  Future<void> _submitItems(SessionMode mode) async {
    final selected = Map<String, int>.fromEntries(
      state.quantities.entries.where((entry) => entry.value > 0),
    );

    if (selected.isEmpty) {
      throw StateError('Select items first.');
    }

    state = state.copyWith(isSubmitting: true, clearError: true);

    try {
      if (mode == SessionMode.issue) {
        await _sessionApi.submitIssueItems(
          sessionId: state.session.id,
          quantities: selected,
        );
      } else {
        await _sessionApi.submitReturnItems(
          sessionId: state.session.id,
          quantities: selected,
        );
      }

      state = state.copyWith(
        quantities: const <String, int>{},
        isSubmitting: false,
        clearError: true,
      );
    } catch (error) {
      state = state.copyWith(
        isSubmitting: false,
        errorMessage: error.toString(),
      );
      rethrow;
    }
  }
}
