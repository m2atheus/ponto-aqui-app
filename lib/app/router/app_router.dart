import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/auth/presentation/auth_view_model.dart';
import '../../features/auth/presentation/login_view.dart';
import '../../features/marcacoes/presentation/work_views.dart';
import '../../features/marcacoes/domain/punch_event.dart';

final routerProvider = Provider<GoRouter>((ref) {
  final router = GoRouter(
    initialLocation: '/iniciando',
    redirect: (context, route) {
      final session = ref.read(authProvider);
      if (session.isLoading) {
        return route.matchedLocation == '/iniciando' ? null : '/iniciando';
      }
      final signedIn = session.asData?.value != null;
      if (!signedIn) return route.matchedLocation == '/login' ? null : '/login';
      if (route.matchedLocation == '/login' ||
          route.matchedLocation == '/iniciando') {
        return '/inicio';
      }
      return null;
    },
    routes: [
      GoRoute(
        path: '/iniciando',
        builder: (_, _) =>
            const Scaffold(body: Center(child: CircularProgressIndicator())),
      ),
      GoRoute(path: '/login', builder: (_, _) => const LoginView()),
      ShellRoute(
        builder: (_, state, child) =>
            WorkShell(path: state.uri.path, child: child),
        routes: [
          GoRoute(path: '/inicio', builder: (_, _) => const HomeView()),
          GoRoute(
            path: '/registrar',
            builder: (_, state) => CaptureView(
              initialType:
                  PunchType.values
                      .where(
                        (type) =>
                            type.wire == state.uri.queryParameters['tipo'],
                      )
                      .firstOrNull ??
                  PunchType.entrada,
            ),
          ),
          GoRoute(path: '/historico', builder: (_, _) => const HistoryView()),
          GoRoute(path: '/fila', builder: (_, _) => const QueueView()),
          GoRoute(path: '/escala', builder: (_, _) => const ScheduleView()),
        ],
      ),
    ],
  );
  ref.listen(authProvider, (_, _) => router.refresh());
  ref.onDispose(router.dispose);
  return router;
});
