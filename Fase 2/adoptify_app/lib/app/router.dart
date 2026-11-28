import 'package:flutter/widgets.dart';
import 'package:go_router/go_router.dart';

import '../features/account/account_screen.dart';
import '../features/adoption_applications/application_form_screen.dart';
import '../features/adoption_applications/my_applications_screen.dart';
import '../features/auth/auth_controller.dart';
import '../features/auth/login_screen.dart';
import '../features/auth/session_loading_screen.dart';
import '../features/foundation_add/add_animal_screen.dart';
import '../features/foundation_chat/foundation_chat_screen.dart';
import '../features/foundation_animals/foundation_animals_screen.dart';
import '../features/foundation_animals/foundation_animals_service.dart';
import '../features/foundation_animals/application_candidates_screen.dart';
import '../features/foundation_animals/interested_animals_screen.dart';
import '../features/foundation_home/foundation_home_screen.dart';
import '../features/foundation_profile/foundation_profile_screen.dart';
import '../features/foundations/foundation_detail_screen.dart';
import '../features/foundations/foundation_service.dart';
import '../features/foundations/foundations_screen.dart';
import '../features/foster/foster_screen.dart';
import '../features/map/detail_screen.dart';
import '../features/map/map_screen.dart';
import '../features/map/map_service.dart';
import '../features/match/favorites_screen.dart';
import '../features/match/match_screen.dart';
import '../features/messages/chat_screen.dart';
import '../features/messages/messages_screen.dart';
import '../features/messages/messages_service.dart';
import '../features/report/report_screen.dart';
import '../shared/widgets/app_shell.dart';
import '../core/api_client.dart';
import '../shared/widgets/detail_loader.dart';

const _loading = '/cargando';
const _login = '/login';
const _foundation = '/fundacion';
// Inicio de la fundación: no se fuerza el formulario de alta al entrar.
const _foundationHome = '/fundacion';
const _foundationAddAnimal = '/fundacion/agregar';

// Login obligatorio y único: sin sesión, cualquier ruta lleva al login. Con sesión, la vista depende del
// rol: los adoptantes usan la app normal (mapa y pestañas) y las fundaciones solo su vista /fundacion/...
// Mientras se revisa la sesión guardada se muestra la pantalla de carga. Se vuelve a evaluar cada vez
// que cambia la sesión (iniciar, cerrar o token vencido), gracias a refreshListenable.
String? sessionRedirect(AuthController auth, String location) {
  if (auth.loading) return location == _loading ? null : _loading;
  final user = auth.user;
  if (user == null) return location == _login ? null : _login;
  final inFoundationArea =
      location == _foundation || location.startsWith('$_foundation/');
  if (user.isFoundation) return inFoundationArea ? null : _foundationHome;
  // /fundaciones (pestaña de adoptante) no es parte del área de fundación: por eso se compara con la barra
  if (location == _login || location == _loading || inFoundationArea) {
    return '/mapa';
  }
  return null;
}

// Los detalles reciben el objeto por `extra` al abrirse desde una lista; al recargar la página o abrir el
// enlace directo no hay `extra` y se pide por id (GET /reports|animals|foundations/{id}).
int _id(GoRouterState state) => int.tryParse(state.pathParameters['id'] ?? '') ?? 0;

// Las pantallas que antes exigían el objeto por `extra` (editar mascota, chat, postular) tampoco fallan al
// recargar: sin `extra` lo buscan en la API, y si ya no existe muestran el aviso de DetailLoader.
Future<T> _find<T>(Future<List<T>> Function() list, bool Function(T) match) async {
  for (final item in await list()) {
    if (match(item)) return item;
  }
  throw ApiException(statusCode: 404);
}

Widget _editAnimal(GoRouterState state) => DetailLoader<ManagedAnimal>(
  key: ValueKey('editar-${_id(state)}'),
  initial: state.extra as ManagedAnimal?,
  load: (api) => _find(FoundationAnimalsService(api).list, (a) => a.id == _id(state)),
  builder: (context, animal) => AddAnimalScreen(animal: animal),
);

Widget _chat(GoRouterState state) => DetailLoader<Conversation>(
  key: ValueKey('chat-${_id(state)}'),
  initial: state.extra as Conversation?,
  load: (api) => _find(MessagesService(api).fetchConversations, (c) => c.id == _id(state)),
  builder: (context, conversation) => ChatScreen(conversation: conversation),
);

Widget _apply(GoRouterState state) => DetailLoader<Animal>(
  key: ValueKey('postular-${_id(state)}'),
  initial: state.extra as Animal?,
  load: (api) => MapService(api).fetchAnimal(_id(state)),
  builder: (context, animal) => ApplicationFormScreen(animal: animal),
);

Widget _reportDetail(GoRouterState state) => DetailLoader<DogReport>(
  key: ValueKey('reporte-${_id(state)}'),
  initial: state.extra as DogReport?,
  load: (api) => MapService(api).fetchReport(_id(state)),
  builder: (context, report) => ReportDetailScreen(report: report),
);

Widget _animalDetail(GoRouterState state) => DetailLoader<Animal>(
  key: ValueKey('animal-${_id(state)}'),
  initial: state.extra as Animal?,
  load: (api) => MapService(api).fetchAnimal(_id(state)),
  builder: (context, animal) => AnimalDetailScreen(animal: animal),
);

Widget _foundationDetail(GoRouterState state) => DetailLoader<Foundation>(
  key: ValueKey('fundacion-${_id(state)}'),
  initial: state.extra as Foundation?,
  load: (api) => FoundationService(api).fetchFoundation(_id(state)),
  builder: (context, foundation) => FoundationDetailScreen(foundation: foundation),
);

// Rutas de la app. Las pestañas comparten la barra inferior (AppShell) y
// cada una conserva su propio historial al cambiar de pestaña.
// El orden de las ramas es el de la barra: Fundaciones, Mensajes, Mapa, Match, Perfil.
GoRouter createAppRouter(AuthController auth) {
  // Que la barra de direcciones refleje las pantallas abiertas con push (/reportes/3, /animales/7...)
  GoRouter.optionURLReflectsImperativeAPIs = true;
  return _buildRouter(auth);
}

GoRouter _buildRouter(AuthController auth) => GoRouter(
  initialLocation: _loading,
  refreshListenable: auth,
  redirect: (context, state) => sessionRedirect(auth, state.matchedLocation),
  routes: [
    GoRoute(
      path: _loading,
      builder: (context, state) => const SessionLoadingScreen(),
    ),
    // Vista de las cuentas de fundación (y admin): inicia en un panel propio, sin forzar el alta de una mascota.
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => FoundationShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: _foundationHome,
              builder: (context, state) => const FoundationHomeScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            // Mismo mapa que ve el adoptante; la fundación además gestiona los reportes (HU-L)
            GoRoute(
              path: '/fundacion/mapa',
              builder: (context, state) => MapScreen(refreshKey: state.extra),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/fundacion/chat',
              // "Conversar" desde los interesados de una mascota: con animal_id empieza el cuestionario (HU-G3)
              builder: (context, state) => FoundationChatScreen(
                interestedUserId: int.tryParse(state.uri.queryParameters['user_id'] ?? ''),
                animalId: int.tryParse(state.uri.queryParameters['animal_id'] ?? ''),
              ),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/fundacion/perfil',
              builder: (context, state) => const FoundationProfileScreen(),
            ),
          ],
        ),
      ],
    ),
    // Flujo de publicación fuera de la barra: se abre desde el botón principal del Inicio de fundación.
    GoRoute(
      path: _foundationAddAnimal,
      builder: (context, state) => const AddAnimalScreen(),
    ),
    // Detalles abiertos desde el mapa de la fundación: dentro de /fundacion para que el redirect no la expulse
    GoRoute(
      path: '/fundacion/reportes/:id',
      builder: (context, state) => _reportDetail(state),
    ),
    GoRoute(
      path: '/fundacion/animales/:id',
      builder: (context, state) => _animalDetail(state),
    ),
    GoRoute(
      path: '/fundacion/directorio/:id',
      builder: (context, state) => _foundationDetail(state),
    ),
    GoRoute(
      path: '/fundacion/mis-animales',
      builder: (context, state) => const FoundationAnimalsScreen(),
    ),
    // Personas que marcaron con el corazón a un animal (o a todos, sin animal_id)
    GoRoute(
      path: '/fundacion/interesados',
      builder: (context, state) => InterestedAnimalsScreen(animalId: int.tryParse(state.uri.queryParameters['animal_id'] ?? '')),
    ),
    GoRoute(
      path: '/fundacion/postulaciones',
      builder: (context, state) => ApplicationCandidatesScreen(animalId: int.tryParse(state.uri.queryParameters['animal_id'] ?? '')),
    ),
    GoRoute(
      path: '/fundacion/mis-animales/:id/editar',
      builder: (context, state) => _editAnimal(state),
    ),
    StatefulShellRoute.indexedStack(
      builder: (context, state, shell) => AppShell(shell: shell),
      branches: [
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/fundaciones',
              builder: (context, state) => const FoundationsScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/mensajes',
              builder: (context, state) => const MessagesScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            // extra: id del reporte recién creado, para que el mapa recargue los datos
            GoRoute(
              path: '/mapa',
              builder: (context, state) => MapScreen(refreshKey: state.extra),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/conecta',
              builder: (context, state) => const MatchScreen(),
            ),
          ],
        ),
        StatefulShellBranch(
          routes: [
            GoRoute(
              path: '/cuenta',
              builder: (context, state) => const AccountScreen(),
            ),
          ],
        ),
      ],
    ),
    // Primera pantalla sin sesión (login obligatorio)
    GoRoute(path: _login, builder: (context, state) => const LoginScreen()),
    // Fuera de la barra inferior: pantallas completas con botón para volver
    // Se abre con el botón "Reportar mascota" del mapa
    GoRoute(
      path: '/reportar',
      builder: (context, state) => const ReportScreen(),
    ),
    // Chat con una fundación (HU-G2), desde la pestaña Mensajes; la conversación viaja en `extra`
    GoRoute(
      path: '/mensajes/:id',
      builder: (context, state) => _chat(state),
    ),
    // Antes la pestaña Conecta se llamaba Match: los enlaces viejos siguen funcionando
    GoRoute(path: '/match', redirect: (context, state) => '/conecta'),
    // Chat de la fundación con un adoptante, desde su pestaña Chat
    GoRoute(
      path: '/fundacion/mensajes/:id',
      builder: (context, state) => _chat(state),
    ),
    // Se abre con el corazón de la pestaña Conecta
    GoRoute(
      path: '/favoritos',
      builder: (context, state) => const FavoritesScreen(),
    ),
    // Postulaciones de adopción del adoptante (HU-AC), desde su Perfil
    GoRoute(
      path: '/mis-postulaciones',
      builder: (context, state) => const MyApplicationsScreen(),
    ),
    // Postulación a hogar temporal (HU-B), desde la tarjeta del Perfil del adoptante
    GoRoute(
      path: '/hogar-temporal',
      builder: (context, state) => const FosterScreen(),
    ),
    // Perfil público de una organización. El objeto llega desde el directorio y evita otra petición.
    GoRoute(
      path: '/fundaciones/:id',
      builder: (context, state) =>
          _foundationDetail(state),
    ),
    // Se abren al tocar la ficha de una mascota o un reporte en el mapa; el objeto viaja en `extra`
    // (ya está cargado ahí) para no volver a pedirlo a la API.
    GoRoute(
      path: '/animales/:id',
      builder: (context, state) =>
          _animalDetail(state),
    ),
    GoRoute(
      path: '/animales/:id/postular',
      builder: (context, state) => _apply(state),
    ),
    GoRoute(
      path: '/reportes/:id',
      builder: (context, state) =>
          _reportDetail(state),
    ),
  ],
);
