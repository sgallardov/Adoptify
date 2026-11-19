# Adoptify

Plataforma de rescate y adopción animal (proyecto de título Capstone, Duoc UC). Equipo: Tiare Alarcón, Santiago Gallardo, Vittorio Dotte.
Arquitectura: API FastAPI + PostGIS, portal web React (solo fundaciones) y app móvil Flutter (`Fase 2/adoptify_app`, en desarrollo).

## Cómo trabajar en este repo
- Responde y escribe código, comentarios, mensajes de error y docs **en español**. Identificadores en inglés (como el código actual).
- Antes de cambiar algo, lee el archivo vecino más parecido y copia su patrón (ver "Patrones").
- Todo cambio de endpoint, modelo o ruta del portal se documenta en `Fase 2/README.md` o `Fase 2/portal-fundaciones/README.md`.
- Commits estilo Conventional Commits en español, referenciando la HU si aplica: `feat(animals): ... (HU-0X)`, `feat(portal): ...`, `docs: ...`. Un commit/PR por funcionalidad. No commitear en `main`.
- Entorno: Windows 10, PowerShell, Docker Desktop. Rutas con espacios (`"Fase 2"`) siempre entre comillas.
- Las carpetas `Fase 1/`, `Fase 2/Evidencias*` y `Fase 3/` son documentos académicos (docx/pdf), no código.

## Comandos (desde `Fase 2/`)
```bash
docker compose up --build -d                          # db (adoptify_db) + backend (adoptify_backend, --reload)
docker compose exec backend alembic upgrade head
docker compose exec backend python -m app.db.seed
docker compose exec backend pytest -v                 # o un archivo: pytest tests/test_reports.py -v
docker compose exec backend alembic revision --autogenerate --rev-id 0004 -m "descripcion"
```
Portal (desde `Fase 2/portal-fundaciones/`): `npm run dev` (http://localhost:5173), `npm run build` (incluye `tsc -b`), `npm run lint` (oxlint).
App móvil (desde `Fase 2/adoptify_app/`): `flutter run` (emulador) o `flutter run -d chrome`, `flutter analyze`, `flutter test`. En el equipo de Santiago, Flutter está en `C:\src\flutter\bin`.
Swagger: http://localhost:8000/docs.

**Verificación antes de dar algo por terminado:** backend → `pytest` dentro del contenedor; portal → `npm run build` y `npm run lint`; app → `flutter analyze` y `flutter test`.
Las pruebas del backend usan la **BD real del contenedor** (no hay BD de test aislada): requieren `docker compose up` y escriben datos; usar correos/RUT únicos por prueba.
**BD compartida (Supabase):** el backend usa `DATABASE_URL` + `DB_SSL=true` del `.env` (Session pooler; ver README "Base de datos compartida"). `pytest` siempre usa el Postgres local (`settings.test_database_url`), nunca la compartida. Las migraciones en la compartida las aplica una sola persona; `DB_PASS` es la clave local, no la de Supabase. Toda tabla nueva activa RLS en su migración (`ALTER TABLE ... ENABLE ROW LEVEL SECURITY`, ver `0009`): sin eso, la API pública de Supabase la expone. Fotos: bucket **privado** `fotos` de Supabase Storage si hay `SUPABASE_SERVICE_KEY` (si no, disco local); la BD guarda `storage:<archivo>` y el middleware `services/photo_access.py` lo cambia por un enlace firmado (`PHOTO_LINK_HOURS`, 6 h) solo con token válido, si no `null`. Con la BD compartida el pool no usa `pool_pre_ping` y una tarea mantiene viva la conexión (`db_pool_options`, `keep_connections_warm`): cada ida y vuelta a Supabase cuesta ~55 ms (proyecto en São Paulo, `aws-1-sa-east-1`). El bucket `fotos` no se crea solo: en un proyecto nuevo se corre `storage.ensure_bucket()` una vez (README). En la app, toda foto de la red va por `shared/widgets/network_photo.dart` (`NetworkPhoto`: caché en disco con clave sin el token, tamaño justo e indicador de carga). Nuevos campos de foto: llamarlos `photo_url` y normalizar la entrada con `storage.to_reference`.

## Estructura
```
Fase 2/backend/app/
  main.py                  # FastAPI, CORS, /health en raíz, api_router en /api/v1
  core/                    # config.py (Settings), security.py (bcrypt + JWT HS256), rut.py (normalize_rut), rut_crypto.py (RUT cifrado y hash)
  db/                      # database.py (engine async, get_db), seed.py, create_user.py
  models/                  # user, foundation, animal, report (AbandonedDogReport: cualquier mascota, con ficha)
  schemas/                 # Pydantic v2 por recurso
  services/match.py        # calculate_match_score (HU-05, sin endpoint aún)
  api/v1/endpoints/        # health, auth, animals, foundations (GET público), reports, uploads
  alembic/versions/        # 0001..0005, nombrados NNNN_descripcion.py
  tests/                   # pytest-asyncio (asyncio_mode=auto), fixtures en conftest.py
Fase 2/portal-fundaciones/src/
  App.tsx                  # rutas; RequireAuth por rol
  services/                # api.ts (axios + Bearer desde localStorage), auth, animals, reports, uploads (multipart), photo (validación y mediaUrl)
  hooks/                   # useAnimals, useMapAnimals, useNearbyReports, useAuth
  components/              # Layout (sidebar), ReportLocationPicker, PhotoPicker, mapTiles.ts (OSM, SANTIAGO, dotIcon)
  pages/                   # Login, Dashboard, Animals, AnimalDetail, Foundation, NotFound
  data/demo.ts             # tipos (Animal) y datos de maqueta
Fase 2/adoptify_app/lib/   # app Flutter (HU-08)
  app/                     # app.dart, router.dart (go_router; **login obligatorio**: abre en /cargando y el redirect lleva a /login sin sesión, a /mapa si es adoptante o a /fundacion (Inicio) si es fundación/admin (barra propia: Inicio, Mapa, Chat, Perfil), también al cerrar sesión o vencer el token; barra de adoptante: Fundaciones, Mensajes, Mapa, Conecta (`/conecta`, el match; `/match` redirige), Perfil; /reportar, /favoritos y los detalles a pantalla completa), theme.dart (paleta clara y oscura, espaciado, radios, sombra y escala tipográfica), theme_controller.dart (modo oscuro)
  core/                    # config.dart (apiUrl: 10.0.2.2 en emulador, localhost en web, --dart-define=API_URL; mediaUrl), api_client.dart (incluye upload multipart), token_storage.dart, photo_service.dart
  features/<pantalla>/     # map (map_service = modelos + /animals y /reports; mapa a pantalla completa con buscador), foundations (/foundations), report, account, auth (AuthController + AuthScope = sesión), messages (chat del adoptante), foundation_home / foundation_animals / foundation_add / foundation_profile (vista de fundación), foundation_chat (todavía "Próximamente": las fundaciones chatean desde el portal)
  shared/map/              # map_style.dart (mosaicos OSM, atribución, MapPins; equivale a mapTiles.ts) y map_controls.dart (MapButton, mapSurface)
  shared/widgets/          # app_shell.dart (barra inferior: AppShell de adoptante y FoundationShell, mismo diseño), coming_soon.dart
```

## Dominio
- **Roles:** `adopter` (app móvil), `foundation` y `admin` (portal web y, en la app, su propia vista `/fundacion`). **La app tiene un solo login sin pestañas** (no manda `account_type`): el router lleva a cada rol a su vista y el adoptante nunca ve que existen cuentas de fundación. El portal sigue mandando `account_type: "foundation"`. Fundaciones no tienen registro público: `python -m app.db.create_user ... --role foundation`.
- **Rutas portal:** foundation/admin → `/`, `/animales`, `/animales/:id`, `/fundacion` (maqueta).
- **Animal.status:** `available` | `adopted` | `in_process`. **Report.status:** `reported` | `in_rescue` | `resolved`. El portal traduce estados al español.
- **Reporte de mascota:** obligatorios `species` (`perro`|`gato`|`otro`), `size`, `color`, `conditions` (lista, al menos una de 15 opciones: `bien`, `herido`, `desnutrido`, `cojea`, `prenada`…) y `description` (= "Comentarios"); opcionales `weight_kg`, `features`, `behaviors` (lista de 13 opciones: `tranquilo`, `amistoso`, `asustado`, `agresivo`…). Opciones en `schemas/report.py` (backend), y `map_service.dart` (app): mantener las dos iguales. En la interfaz se dice "mascota", no "perro".
- **RUT:** obligatorio y único, no autentica. Solo se valida formato; se normaliza sin puntos y con K mayúscula (`normalize_rut`). En `users` va cifrado (HU-E): `rut_encrypted` (Fernet) + `rut_hash` (HMAC, único); `user.rut` es una propiedad que cifra/descifra y para buscar se usa `User.rut_hash == hash_rut(rut)`. Claves `RUT_ENCRYPTION_KEY`/`RUT_HASH_KEY` en `.env`; con la BD compartida no se aceptan las de desarrollo. El RUT de `foundations` sigue en texto.
- **Contraseñas:** 8 caracteres mínimo, 72 bytes máximo (bcrypt). Correos en minúsculas.
- **Cuenta:** `PATCH /auth/me` edita el nombre y `POST /auth/change-password` cambia la contraseña pidiendo la actual (`400` si no coincide). El correo y el RUT no se editan.
- **Errores en español** (`core/errors.py`): `401` sin token ("Inicia sesión para continuar.") y `422` con `msg` en español y sin `input`. Un permiso que debe ganar a la validación va como dependencia (ver `require_admin` en veterinarias).
- **Verificación en dos pasos (HU-I):** opcional, por correo (Gmail SMTP, `services/email.py`; sin SMTP en development el código sale en los logs). Con ella activa, `/auth/login` responde 202 con `challenge_id` y el token llega con `/auth/verify-code`. Los endpoints con sesión iniciada nunca responden 401 por un dato mal ingresado (usar 400): la app y el portal cierran sesión ante cualquier 401.
- **Match** (en la interfaz se llama **Conecta**, nunca "match"; porcentaje "83 % compatible"; en la API y el código sigue `match`): pesos especie 30, tamaño 25, rango edad 25, energía 20; normaliza sobre criterios comparables.

## Patrones
**Backend**
- Endpoints `async` con `db: AsyncSession = Depends(get_db)`; auth con `Depends(get_current_user)` (de `endpoints/auth.py`).
- Errores SQL: `except SQLAlchemyError` → `rollback` si hubo escritura → `HTTPException(503, detail="mensaje público en español")`.
- Geometría: siempre `Geometry('POINT', srid=4326)` + índice GiST. Crear con `WKTElement(f"POINT({lng} {lat})", srid=4326)` — **orden longitud, latitud**.
- Cercanía: castear a `Geography`, filtrar con `ST_DWithin(…, radius_km*1000)` y ordenar por `ST_Distance`; parámetros `lat`, `lng`, `radius_km` (`gt=0, le=100`, default 10).
- La API nunca expone la geometría cruda ni datos de quien reporta; los modelos exponen `latitude`/`longitude` como propiedades (`to_shape`). `foundation_name` requiere `selectinload(Animal.foundation)`.
- Cada modelo/tabla nueva: modelo en `models/`, export en `models/__init__.py`, migración Alembic con el siguiente `--rev-id`, schemas en `schemas/`, router registrado en `api/api_router.py`, tests en `tests/`.

**Portal**
- Llamadas HTTP solo en `services/*.ts` usando `api` de `services/api.ts`; mensajes de error con `errorMessage(err, fallback)`.
- Hooks de datos con `AbortController`, estados `loading` / `error` / `retry` (ver `hooks/useAnimals.ts`).
- Estilos con clases Tailwind (colores del tema en `index.css`, con modo oscuro en `:root[data-theme="dark"]`; texto sobre fondos de color con `text-on-accent`), íconos de `lucide-react`. Mapas con Leaflet/react-leaflet usando lo de `mapTiles.ts` (mantener la atribución de OSM).
- Accesibilidad: etiquetas en formularios, navegación por teclado, estados vacíos y de error visibles.

**App móvil**
- Una carpeta por pantalla en `features/`. Colores, espaciado, radios, sombras y textos solo desde `app/theme.dart` (`context.colors`, `AdoptifySpacing`, `AdoptifyRadius`, `AdoptifyShadows`, `Theme.of(context).textTheme`); nada de tamaños o colores sueltos. `context.colors` cambia con el modo oscuro (Perfil → Apariencia). Texto sobre fondos de color: `onAccent` sobre `primaryStrong`/`successStrong` (iguales en los dos modos); `primaryDark` y `success` son para texto y se aclaran en modo oscuro, nunca de fondo. Títulos centrados.
- Rutas nuevas en `app/router.dart`; pantallas con barra inferior dentro del `StatefulShellRoute`, pantallas completas fuera.
- Mapas con `flutter_map` + OSM (mismo proveedor que la web). La API ya entrega `latitude`/`longitude`: no parsear WKB.
- HTTP solo a través de `ApiClient` (`AuthScope.of(context).api`); errores al usuario con `errorMessage(err, fallback)`, igual que el portal.
- Cada pantalla nueva con su widget test en `test/`; la API se simula con `test/fake_api.dart` (MockClient + MemoryTokenStorage). `FakeApi()` parte con la sesión de Matías iniciada; `FakeApi(loggedIn: false)` parte en el login.

## Estado y pendientes
Hecho: HU-01 a HU-16 (backend, portal y app), match con `/animals/match` y "Quiero adoptar", fotos privadas en Supabase Storage, HU-A a HU-L (resguardo privado, hogares temporales, gestión de reportes, veterinarias, RUT cifrado, socios, interesados, avisos cercanos, verificación en dos pasos, mapa de la fundación), postulaciones de adopción, chat HU-G2 (backend, portal y pestaña Mensajes del adoptante), edición de nombre y contraseña, y errores en español.
Pendiente (en orden aproximado de prioridad):
1. TTL / expiración de reportes-alertas (objetivo 3 del proyecto).
2. Chat en la pestaña Chat de la fundación en la app (hoy "Próximamente"; el portal ya lo tiene).
3. Fotos: borrar archivos huérfanos del bucket.
4. Fase 3: QA, pruebas de integración, evidencias (capturas de Swagger, `docker compose ps`, `pytest`), despliegue.
