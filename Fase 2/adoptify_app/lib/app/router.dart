import 'package:go_router/go_router.dart';

import '../features/account/account_screen.dart';
import '../features/auth/login_screen.dart';
import '../features/foundations/foundations_screen.dart';
import '../features/map/detail_screen.dart';
import '../features/map/map_screen.dart';
import '../features/map/map_service.dart';
import '../features/report/report_screen.dart';
import '../shared/widgets/app_shell.dart';

// Rutas de la app. Las pestañas comparten la barra inferior (AppShell) y
// cada una conserva su propio historial al cambiar de pestaña.
// El orden de las ramas es el de la barra: Fundaciones, Mapa, Perfil.
GoRouter createAppRouter() => GoRouter(
  initialLocation: '/mapa',
  routes: [
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(routes: [
          GoRoute(path: '/fundaciones', builder: (context, state) => const FoundationsScreen()),
        ]),
        StatefulShellBranch(routes: [
          // extra: id del reporte recién creado, para que el mapa recargue los datos
          GoRoute(path: '/mapa', builder: (context, state) => MapScreen(refreshKey: state.extra)),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/cuenta', builder: (context, state) => const AccountScreen()),
        ]),
      ],
    ),
    // Fuera de la barra inferior: pantallas completas con botón para volver
    GoRoute(path: '/login', builder: (context, state) => const LoginScreen()),
    // Se abre con el botón "Reportar mascota" del mapa
    GoRoute(path: '/reportar', builder: (context, state) => const ReportScreen()),
    // Se abren al tocar la ficha de una mascota o un reporte en el mapa; el objeto viaja en `extra`
    // (ya está cargado ahí) para no volver a pedirlo a la API.
    GoRoute(path: '/animales/:id', builder: (context, state) => AnimalDetailScreen(animal: state.extra as Animal)),
    GoRoute(path: '/reportes/:id', builder: (context, state) => ReportDetailScreen(report: state.extra as DogReport)),
  ],
);
