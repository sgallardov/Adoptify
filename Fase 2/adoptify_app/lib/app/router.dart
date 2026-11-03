import 'package:go_router/go_router.dart';

import '../features/account/account_screen.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/session_loading_screen.dart';
import '../features/foundation_home/foundation_home_screen.dart';
import '../features/foundations/foundations_screen.dart';
import '../features/map/detail_screen.dart';
import '../features/map/map_screen.dart';
import '../features/map/map_service.dart';
import '../features/match/favorites_screen.dart';
import '../features/match/match_screen.dart';
import '../features/report/report_screen.dart';
import '../shared/widgets/app_shell.dart';

const _loading = '/cargando';
const _login = '/login';
const _foundation = '/fundacion';

// Login obligatorio y único: sin sesión, cualquier ruta lleva al login. Con sesión, la vista depende del
// rol: los adoptantes usan la app normal (mapa y pestañas) y las fundaciones solo su vista /fundacion.
// Mientras se revisa la sesión guardada se muestra la pantalla de carga. Se vuelve a evaluar cada vez
// que cambia la sesión (iniciar, cerrar o token vencido), gracias a refreshListenable.
String? sessionRedirect(AuthController auth, String location) {
  if (auth.loading) return location == _loading ? null : _loading;
  final user = auth.user;
  if (user == null) return location == _login ? null : _login;
  if (user.isFoundation) return location == _foundation ? null : _foundation;
  if (location == _login || location == _loading || location == _foundation) return '/mapa';
  return null;
}

// Rutas de la app. Las pestañas comparten la barra inferior (AppShell) y
// cada una conserva su propio historial al cambiar de pestaña.
// El orden de las ramas es el de la barra: Fundaciones, Mapa, Match, Perfil.
GoRouter createAppRouter(AuthController auth) => GoRouter(
  initialLocation: _loading,
  refreshListenable: auth,
  redirect: (context, state) => sessionRedirect(auth, state.matchedLocation),
  routes: [
    GoRoute(path: _loading, builder: (context, state) => const SessionLoadingScreen()),
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
          GoRoute(path: '/match', builder: (context, state) => const MatchScreen()),
        ]),
        StatefulShellBranch(routes: [
          GoRoute(path: '/cuenta', builder: (context, state) => const AccountScreen()),
        ]),
      ],
    ),
    // Primera pantalla sin sesión (login obligatorio)
    GoRoute(path: _login, builder: (context, state) => const LoginScreen()),
    // Única vista de las cuentas de fundación (y admin) en la app
    GoRoute(path: _foundation, builder: (context, state) => const FoundationHomeScreen()),
    // Fuera de la barra inferior: pantallas completas con botón para volver
    // Se abre con el botón "Reportar mascota" del mapa
    GoRoute(path: '/reportar', builder: (context, state) => const ReportScreen()),
    // Se abre con el corazón de la pestaña Match
    GoRoute(path: '/favoritos', builder: (context, state) => const FavoritesScreen()),
    // Se abren al tocar la ficha de una mascota o un reporte en el mapa; el objeto viaja en `extra`
    // (ya está cargado ahí) para no volver a pedirlo a la API.
    GoRoute(path: '/animales/:id', builder: (context, state) => AnimalDetailScreen(animal: state.extra as Animal)),
    GoRoute(path: '/reportes/:id', builder: (context, state) => ReportDetailScreen(report: state.extra as DogReport)),
  ],
);
