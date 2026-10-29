# Adoptify

Plataforma de rescate y adopción animal (proyecto de título Capstone, Duoc UC). Equipo: Tiare Alarcón, Santiago Gallardo, Vittorio Dotte.
Arquitectura: API FastAPI + PostGIS, portal web React (fundaciones y adoptantes) y app móvil Flutter (`Fase 2/adoptify_app`, en desarrollo).

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

## Estructura
```
Fase 2/backend/app/
  main.py                  # FastAPI, CORS, /health en raíz, api_router en /api/v1
  core/                    # config.py (Settings), security.py (bcrypt + JWT HS256), rut.py (normalize_rut)
  db/                      # database.py (engine async, get_db), seed.py, create_user.py
  models/                  # user, foundation, animal, report (AbandonedDogReport)
  schemas/                 # Pydantic v2 por recurso
  services/match.py        # calculate_match_score (HU-05, sin endpoint aún)
  api/v1/endpoints/        # health, auth, animals, reports
  alembic/versions/        # 0001..0003, nombrados NNNN_descripcion.py
  tests/                   # pytest-asyncio (asyncio_mode=auto), fixtures en conftest.py
Fase 2/portal-fundaciones/src/
  App.tsx                  # rutas; RequireAuth por rol
  services/                # api.ts (axios + Bearer desde localStorage), auth, animals, reports
  hooks/                   # useAnimals, useMapAnimals, useNearbyReports, useAuth
  components/              # Layout (sidebar), AnimalsMap, ReportLocationPicker, mapTiles.ts (OSM, SANTIAGO, dotIcon)
  pages/                   # Login, UserHome, ReportDog, Dashboard, Animals, AnimalDetail, Foundation, NotFound
  data/demo.ts             # tipos (Animal) y datos de maqueta
Fase 2/adoptify_app/lib/   # app Flutter (HU-08)
  app/                     # app.dart, router.dart (go_router, StatefulShellRoute con 4 pestañas), theme.dart (paleta del portal)
  core/                    # config.dart (apiUrl: 10.0.2.2 en emulador, localhost en web, --dart-define=API_URL), api_client.dart, token_storage.dart
  features/<pantalla>/     # home, map (map_service = modelos + /animals y /reports), report, account, auth (AuthController + AuthScope = sesión)
  shared/map/map_style.dart # mosaicos OSM, atribución y pines (MapPins), equivalente a mapTiles.ts
  shared/widgets/          # app_shell.dart (barra inferior), coming_soon.dart
```

## Dominio
- **Roles:** `adopter` (pestaña Usuario del login), `foundation` y `admin` (pestaña Fundación). Fundaciones no tienen registro público: `python -m app.db.create_user ... --role foundation`.
- **Rutas portal:** adopter → `/usuario` (mapa + lista), `/reportar`; foundation/admin → `/`, `/animales`, `/animales/:id`, `/fundacion` (maqueta).
- **Animal.status:** `available` | `adopted` | `in_process`. **Report.status:** `reported` | `in_rescue` | `resolved`. El portal traduce estados al español.
- **RUT:** obligatorio y único, no autentica. Solo se valida formato; se guarda sin puntos y con K mayúscula (`normalize_rut`).
- **Contraseñas:** 8 caracteres mínimo, 72 bytes máximo (bcrypt). Correos en minúsculas.
- **Match:** pesos especie 30, tamaño 25, rango edad 25, energía 20; normaliza sobre criterios comparables.

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
- Estilos con clases Tailwind, íconos de `lucide-react`. Mapas con Leaflet/react-leaflet usando lo de `mapTiles.ts` (mantener la atribución de OSM).
- Accesibilidad: etiquetas en formularios, navegación por teclado, estados vacíos y de error visibles.

**App móvil**
- Una carpeta por pantalla en `features/`; colores solo desde `AdoptifyColors` (`app/theme.dart`), no hardcodeados.
- Rutas nuevas en `app/router.dart`; pantallas con barra inferior dentro del `StatefulShellRoute`, pantallas completas fuera.
- Mapas con `flutter_map` + OSM (mismo proveedor que la web). La API ya entrega `latitude`/`longitude`: no parsear WKB.
- HTTP solo a través de `ApiClient` (`AuthScope.of(context).api`); errores al usuario con `errorMessage(err, fallback)`, igual que el portal.
- Cada pantalla nueva con su widget test en `test/`; la API se simula con `test/fake_api.dart` (MockClient + MemoryTokenStorage).

## Estado y pendientes
Hecho: HU-01 a HU-07, búsqueda por cercanía, mapa Leaflet/OSM y reportes de perros abandonados (rama `feat/mapa-leaflet-reportes`).
Pendiente (en orden aproximado de prioridad):
1. CRUD de animales para fundaciones (`POST/PUT/DELETE /animals` + formulario en el portal).
2. Vincular cuenta `foundation` con su `Foundation` y filtrar "Mis casos" por la fundación autenticada.
3. TTL / expiración de reportes-alertas (objetivo 3 del proyecto).
4. Endpoint del match (animales ordenados por compatibilidad para el adoptante) y edición de `preferences`.
5. Subida de fotos (hoy solo `photo_url`).
6. App móvil Flutter: HU-08, HU-14 y HU-15 hechas; la foto en reportes queda para HU-16.
7. Fase 3: QA, pruebas de integración, evidencias (capturas de Swagger, `docker compose ps`, `pytest`), despliegue.
