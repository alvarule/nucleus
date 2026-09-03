/// MFA tab list state.
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nucleus/core/di/providers.dart';
import 'package:nucleus/core/errors/user_facing_error.dart';
import 'package:nucleus/features/mfa/domain/entities/mfa_entry.dart';
import 'package:nucleus/features/unlock/presentation/providers/vault_session_provider.dart';

class MfaListNotifier extends StateNotifier<AsyncValue<List<MfaEntry>>> {
  MfaListNotifier(this._ref) : super(const AsyncValue.loading()) {
    refresh();
  }

  final Ref _ref;

  Future<void> refresh() async {
    final session = _ref.read(vaultSessionProvider);
    final userId = _ref.read(authRepositoryProvider).currentUserId;
    if (!session.isUnlocked || session.dek == null || userId == null) {
      state = const AsyncValue.data([]);
      return;
    }
    state = const AsyncValue.loading();
    try {
      final list = await _ref.read(mfaRepositoryProvider).listEntries(
            userId: userId,
            dek: session.dek!,
          );
      state = AsyncValue.data(list);
    } catch (e, st) {
      state = AsyncValue.error(
        await userFacingErrorMessage(
          _ref.read(connectivityServiceProvider),
          e,
        ),
        st,
      );
    }
  }

  Future<void> delete(String id) async {
    final previous = state;
    final current = state.valueOrNull;
    if (current != null) {
      state = AsyncValue.data(
        current.where((e) => e.id != id).toList(),
      );
    }
    try {
      await _ref.read(mfaRepositoryProvider).deleteEntry(id);
    } catch (e) {
      state = previous;
      rethrow;
    }
  }

  /// Replaces one entry in the cached list (e.g. after editing account on detail).
  void replaceEntry(MfaEntry entry) {
    final current = state.valueOrNull;
    if (current == null) return;
    state = AsyncValue.data(
      current.map((e) => e.id == entry.id ? entry : e).toList(),
    );
  }
}

final mfaListProvider =
    StateNotifierProvider<MfaListNotifier, AsyncValue<List<MfaEntry>>>((ref) {
  return MfaListNotifier(ref);
});
