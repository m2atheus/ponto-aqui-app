import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../app/app_runtime.dart';
import '../domain/mobile_session.dart';

final authProvider = AsyncNotifierProvider<AuthViewModel, MobileSession?>(
  AuthViewModel.new,
);

class AuthViewModel extends AsyncNotifier<MobileSession?> {
  @override
  Future<MobileSession?> build() => ref.read(runtimeProvider).auth.restore();

  Future<void> login(String email, String password, String deviceId) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(runtimeProvider).auth.login(email, password, deviceId),
    );
  }

  Future<void> logout() async {
    state = const AsyncData(null);
    await ref.read(runtimeProvider).storage.logout();
  }

  Future<void> block(MobileSession session, String message) async {
    final current = state.asData?.value;
    if (current?.scope != session.scope || current?.token != session.token) {
      return;
    }
    final blocked = session.blocked(message);
    // Suspend in memory immediately; secure-storage failure cannot leave a
    // worker authorized to keep sending while persistence is attempted.
    state = AsyncData(blocked);
    await ref.read(runtimeProvider).storage.save(blocked);
  }
}
