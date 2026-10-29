import 'package:go_router/go_router.dart';

import '../features/account/account_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/home/home_screen.dart';
import '../features/map/map_screen.dart';
import '../features/report/report_screen.dart';
import '../shared/widgets/app_shell.dart';

// Rutas de la app. Las pestañas comparten la barra inferior (AppShell) y
// cada una conserva su propio historial al cambiar de pestaña.
GoRouter createAppRouter() => GoRouter(
  initialLocation: '/inicio',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/inicio', builder: (context, state) => const HomeScreen()),
        ]),
        StatefulShellBranch(routes: [
          // extra: id del reporte recién creado, para que el mapa recargue los datos
          GoRoute(path: '/mapa', builder: (context, state) => MapScreen(refreshKey: state.extra)),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/reportar', builder: (context, state) => const ReportScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/cuenta', builder: (context, state) => const AccountScreen()),
        ]),
      ],
    ),
    // Fuera de la barra inferior: pantalla completa (HU-14)
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
  ],
);
