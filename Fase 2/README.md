# Adoptify - Fase 2: Backend Core e Infraestructura (HU-01 & HU-02)

Este directorio contiene la arquitectura contenerizada y el backend base para el proyecto **Adoptify**.

---

## 📁 Estructura del Proyecto

```text
Fase 2/
├── .env                  # Variables de entorno locales (credenciales, puertos, URLs)
├── .env.example          # Plantilla de variables de entorno
├── .gitignore            # Archivos ignorados por git
├── docker-compose.yml    # Orquestación de servicios (db PostGIS y backend FastAPI)
├── README.md             # Documentación técnica
└── backend/
    ├── Dockerfile        # Imagen Docker basada en python:3.11-slim
    ├── requirements.txt  # FastAPI, SQLAlchemy 2.0, GeoAlchemy2, asyncpg, Pydantic v2
    └── app/
        ├── __init__.py
        ├── main.py       # Aplicación FastAPI, lifespan, CORS y registro de routers
        ├── core/
        │   ├── __init__.py
        │   └── config.py # Configuración centralizada (Pydantic BaseSettings)
        ├── db/
        │   ├── __init__.py
        │   ├── base.py   # DeclarativeBase de SQLAlchemy 2.0 con AsyncAttrs
        │   └── database.py # Motor asíncrono (asyncpg), sesión y verificación de PostGIS
        ├── schemas/
        │   ├── __init__.py
        │   └── health.py # Schemas Pydantic v2 para validación de respuestas
        └── api/
            ├── __init__.py
            ├── api_router.py # Enrutador principal de la API (/api/v1)
            └── v1/
                └── endpoints/
                    ├── __init__.py
                    └── health.py # Endpoint GET /health con consulta activa a BD
```

---

## 🚀 Requisitos Previos

### Frontend web — HU-06

El portal local está en `portal-fundaciones/`, con Vite, React, TypeScript,
TailwindCSS y React Router. Incluye Inicio, Mis animales, detalle y Mi fundación,
con sidebar responsivo y datos de ejemplo.

```powershell
cd portal-fundaciones
npm ci
npm run dev
```

Para compilar: `npm run build`. Ver `portal-fundaciones/README.md` para el alcance
y las instrucciones completas. HU-07 conecta listado, detalle y contadores a
`GET /api/v1/animals`; ahora esas vistas requieren el backend y la base de datos.

### Backend

1. Tener instalado **Docker Desktop** con soporte para Docker Compose v2.
2. Asegurarse de que Docker Desktop esté iniciado y en ejecución.

---

## ⚙️ Puesta en Marcha

1. **Abrir la terminal** en este directorio (`Adoptify-main/Fase 2`).
2. **Construir e iniciar los contenedores en segundo plano:**
   ```bash
   docker compose up --build -d
   ```
3. **Verificar el estado de los servicios:**
   ```bash
   docker compose ps
   ```
   Ambos contenedores (`adoptify_db` y `adoptify_backend`) deben figurar en estado `Up` (o `healthy`).

### 🌐 Base de datos compartida (Supabase)
Para que todo el equipo vea los mismos usuarios, animales, reportes y comentarios, cada uno corre su backend local apuntando a una sola BD en Supabase (PostgreSQL + PostGIS administrado, plan gratis de 500 MB). El proyecto está en la región **São Paulo (`sa-east-1`)**, la más cercana a Chile.

1. En el panel de Supabase del proyecto: **Database → Extensions → `postgis` → Enable** (una sola vez).
2. Botón **Connect** → pestaña **Session pooler** (no "Direct connection": esa es solo IPv6 y Docker en Windows no la alcanza). Copiar la URI tal cual: el host puede ser `aws-0-…` o `aws-1-…` según el proyecto.
3. En `Fase 2/.env` (nunca en git), reemplazar `DATABASE_URL`, activar SSL y apuntar las fotos al mismo proyecto:
   ```env
   DATABASE_URL=postgresql+asyncpg://postgres.<ref>:<contraseña>@aws-1-sa-east-1.pooler.supabase.com:5432/postgres
   DB_SSL=true
   SUPABASE_URL=https://<ref>.supabase.co
   SUPABASE_SERVICE_KEY=<llave secreta>
   ```
   La contraseña es la de la base de datos (Project Settings → Database), no la de la cuenta de Supabase; va sin corchetes. Si tiene caracteres como `@`, `#`, `/` o `%`, va codificada (`@` → `%40`, `#` → `%23`).
4. `docker compose up -d --force-recreate backend` para que tome el `.env`.
5. **Solo la primera vez y una sola persona:**
   ```bash
   docker compose exec backend alembic upgrade head
   docker compose exec backend python -m app.db.seed
   docker compose exec backend python -c "import asyncio; from app.services import storage; print(asyncio.run(storage.ensure_bucket()))"
   ```
   El último comando crea el bucket privado `fotos`: sin él, `POST /uploads` responde 503. Después, cada migración nueva la aplica una sola persona; los demás solo hacen `git pull`.

Notas:
* `pytest` **siempre usa el Postgres local** de Docker (o `TEST_DATABASE_URL`), así las pruebas no ensucian la BD compartida. Por eso el servicio `db` sigue en el compose.
* **Fotos compartidas y privadas:** con `SUPABASE_URL` y `SUPABASE_SERVICE_KEY` (llave secreta, Project Settings → API Keys) en el `.env`, `POST /uploads` sube cada foto al bucket **privado** `fotos` de Supabase Storage. En la BD se guarda una referencia (`storage:<archivo>`), no un enlace.
  * Al responder, la API cambia cada referencia por un **enlace firmado que caduca en `PHOTO_LINK_HOURS` horas (6 por defecto)**, solo si la petición trae un token válido; sin sesión, `photo_url` llega `null` (middleware `services/photo_access.py`, cubre todos los endpoints). El mismo enlace se reutiliza mientras le quede más de 10 minutos, para que el teléfono use su caché.
  * Al crear o editar un reporte o animal, el `photo_url` firmado que manda la app o el portal se vuelve a guardar como referencia. Los enlaces externos (Unsplash) pasan tal cual.
  * Sin la llave, las fotos se guardan en `backend/uploads` como antes (públicas y solo en ese computador). La app y el portal no cambian: muestran el enlace que reciben.
* **Rendimiento con la BD compartida:** cada ida y vuelta a Supabase cuesta ~55 ms desde Chile con el proyecto en São Paulo (~125 ms cuando estaba en us-east-1) y abrir una conexión, ~3 s. Por eso, con `DATABASE_URL`, el pool no verifica la conexión antes de cada petición (`pool_pre_ping=False`), reutiliza siempre la última (`pool_use_lifo`) y una tarea de fondo la usa cada 3 minutos (`keep_connections_warm`), así ninguna petición paga la conexión nueva. Las fotos se suben con `cache-control: max-age=31536000` (nombres aleatorios que no cambian) para que la CDN de Supabase las guarde. Medido: `/reports/nearby` bajó de 0,61 s a 0,26 s, y a 0,12 s al pasar a São Paulo.

  | Proceso (ms, p50) | us-east-1 | São Paulo |
  | --- | --- | --- |
  | Login | 445 | 313 |
  | `GET /animals` | 495 | 238 |
  | `GET /reports/nearby` | 249 | 119 |
  | `GET /animals/favorites` | 617 | 178 |
  | `POST /uploads` (773 KB) | 2195 | ~800 |
  | `POST /reports` | 1522 | 491 |
  | `POST /reports/{id}/comments` | 1118 | 561 |
* **RLS:** Supabase publica las tablas de `public` en su API REST con la llave publishable (pública). La migración `0009` activa RLS sin políticas en todas las tablas: esa API no ve nada y el backend (dueño de las tablas) funciona igual. **Toda tabla nueva debe hacer `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` en su migración.**
* El plan gratis pausa el proyecto tras ~1 semana sin uso; se reactiva desde el panel sin perder datos.
* Para volver a la BD local basta con dejar `DATABASE_URL` como en `.env.example` y `DB_SSL=false`.

---

## ✅ Verificación de Criterios de Aceptación

### HU-01: Infraestructura
* **`docker-compose up -d` ejecuta sin errores:** Imágenes descargadas, dependencias compiladas y contenedores en ejecución.
* **Contenedor de BD acepta conexiones locales:** Puerto `5432` disponible en `localhost:5432`.
  ```bash
  docker exec -it adoptify_db psql -U adoptify_user -d adoptify_db -c "SELECT PostGIS_Version();"
  ```
* **Persistencia probada al reiniciar contenedores:** Volumen local `postgres_data` montado en `/var/lib/postgresql/data`.

### HU-02: Backend Core
* **Swagger UI autogenerado accesible en `/docs`:**
  Ingresar a [http://localhost:8000/docs](http://localhost:8000/docs) para interactuar con la documentación OpenAPI interactiva.
* **Endpoint `/health` retorna HTTP 200 y status de BD:**
  Petición `GET http://localhost:8000/health` o `GET http://localhost:8000/api/v1/health`:
  ```json
  {
    "status": "ok",
    "service": "Adoptify API",
    "environment": "development",
    "database": {
      "connected": true,
      "postgis_version": "3.3 USE_GEOS=1 USE_PROJ=1 USE_STATS=1"
    }
  }
  ```

### Login con correo y contraseña
Un solo login para todas las cuentas. La **app** no envía `account_type`: entra cualquier cuenta y la app muestra la vista
de su rol (adoptante o fundación). El **portal** envía `account_type: "foundation"`, así una cuenta de adoptante no
entra al portal (`403` con "Esta cuenta es de adoptante. Inicia sesión desde la app de Adoptify.").

| Endpoint | Descripción |
| --- | --- |
| `POST /api/v1/auth/register` | Registra un **adoptante** (`email`, `rut`, `password`, `full_name`). `201`, o `409` si el correo o el RUT ya existen. |
| `POST /api/v1/auth/login` | Recibe `email`, `password` y, opcional, `account_type` (`"user"` o `"foundation"`). Sin `account_type` entra cualquier cuenta (login único de la app, que muestra la vista según el `role`); con él, solo ese tipo (el portal manda `"foundation"`). Devuelve `access_token` (JWT) y `role`. `401` si las credenciales son incorrectas; `403` si la cuenta no corresponde al `account_type` pedido. |
| `GET /api/v1/auth/me` | Devuelve el usuario del token enviado en `Authorization: Bearer <token>` (incluye `two_factor_enabled`). `401` sin token o con token inválido/expirado. |
| `PATCH /api/v1/auth/me` | Con sesión: `full_name`, con las mismas reglas del registro (2 a 255 caracteres, sin espacios al borde). Devuelve el usuario. El correo y el RUT no se editan. |
| `POST /api/v1/auth/change-password` | Con sesión: `current_password` y `new_password` (8 caracteres a 72 bytes). `204`. Contraseña actual incorrecta o nueva igual a la actual: **`400`** (no `401`, para no cerrar la sesión). La sesión actual sigue abierta. |
| `POST /api/v1/auth/verify-code` | Segundo paso del login con verificación en dos pasos: `challenge_id` y `code` (6 dígitos). Devuelve `access_token` y `role`. `401` si el código es incorrecto (dice cuántos intentos quedan), venció o se agotaron los intentos. |
| `POST /api/v1/auth/resend-code` | `challenge_id`: envía un código nuevo y anula el anterior. `429` si no ha pasado 1 minuto desde el último envío. |
| `POST /api/v1/auth/two-factor/enable` | Con sesión: envía un código al correo para activar la verificación (`202` con `challenge_id`). `409` si ya está activa. |
| `POST /api/v1/auth/two-factor/confirm` | Con sesión: `challenge_id` y `code`; recién ahí queda activa. Errores con `400` (no `401`, para no cerrar la sesión). |
| `POST /api/v1/auth/two-factor/disable` | Con sesión: `password`. `400` si la contraseña es incorrecta. |

#### Verificación en dos pasos por correo (HU-I)
* **Opcional:** cada cuenta la activa desde el Perfil de la app (adoptante o fundación) confirmando un código, así nadie se bloquea con un correo que no recibe. Desactivarla pide la contraseña. El portal recibe la pantalla del código al iniciar sesión, pero se activa desde la app.
* **Login:** con la verificación activa, `POST /auth/login` valida la contraseña, envía un código de 6 dígitos al correo y responde **`202`** con `challenge_id`, `email_hint` (`m***r@gmail.com`), `expires_in_minutes` y `resend_in_seconds`, **sin token**. El token llega con `POST /auth/verify-code`.
* **Reglas:** el código vence a los `LOGIN_CODE_MINUTES` (10), tras `LOGIN_CODE_MAX_ATTEMPTS` (5) intentos fallidos hay que volver a iniciar sesión, se puede reenviar cada `LOGIN_CODE_RESEND_SECONDS` (60) y sirve una sola vez.
* **Almacenamiento:** tabla `login_challenges` (migración `0018`, con RLS; idempotente porque en Supabase se creó cuando se llamaba `0016`) con `user_id`, `purpose` (`login` o `enable`), `code_hash`, `expires_at`, `attempts` y `last_sent_at`. El código nunca se guarda: solo su HMAC-SHA256 con `SECRET_KEY` y el id del desafío. Columna nueva `users.two_factor_enabled`.
* **Diseño del correo:** HTML con los colores de la app, el logo incrustado como imagen en línea (`app/assets/email_logo.png`, CID `adoptify-logo`), saludo con el nombre, el código en recuadros y un aviso de seguridad distinto para el login y la activación; también lleva una versión en texto plano.
* **Correo:** `services/email.py` envía por SMTP (Gmail con contraseña de aplicación; variables `SMTP_*` en `.env`, ver `.env.example`). **Sin SMTP configurado y con `ENVIRONMENT=development`, el correo se escribe en `docker compose logs backend`**, así se puede probar sin las credenciales; en otro ambiente el login con verificación responde `503`. Las pruebas nunca envían correos (`conftest.py`).

* **`account_type`:** `user` → `adopter`; `foundation` → `foundation` o `admin`. Sin `account_type` (la app) entra cualquier rol.
* **Contraseñas:** se guardan con bcrypt. Mínimo 8 caracteres y máximo 72 bytes (la `ñ` y las tildes cuentan doble).
* **Correos:** se guardan y comparan en minúsculas.
* **RUT:** atributo obligatorio y único de cada usuario (no se usa para autenticar). Se acepta con o sin puntos (`12.345.678-5` o `12345678-5`), solo se revisa el formato (no el dígito verificador) y se guarda sin puntos con `K` mayúscula. Formato inválido: `422`.
* **RUT cifrado (HU-E, migraciones `0016` y `0017`):** `users` no guarda el RUT en texto. `rut_encrypted` lo guarda cifrado con Fernet (`RUT_ENCRYPTION_KEY`) y solo se descifra para `GET /auth/me`; `rut_hash` es un HMAC-SHA256 del RUT normalizado (`RUT_HASH_KEY`) con índice único, que se usa para buscar por RUT y para responder `409` si se repite. En el código se asigna y se lee `user.rut` como siempre (`models/user.py`); para buscar se compara `User.rut_hash == hash_rut(rut)` (`core/rut_crypto.py`). El RUT de las **fundaciones** queda en texto: es de la organización, no un dato personal.
  * **Claves:** van solo en el `.env` (nunca en el repositorio). Con `DATABASE_URL` (BD compartida) el backend se niega a usar las claves de desarrollo que trae `config.py`. Para generarlas: `python -c "from cryptography.fernet import Fernet; print(Fernet.generate_key().decode())"` (cifrado) y `python -c "import secrets; print(secrets.token_urlsafe(32))"` (hash). **Todo el equipo usa las mismas dos claves**, y deben respaldarse fuera del repo: si se pierde `RUT_ENCRYPTION_KEY`, los RUT no se pueden recuperar; si cambia `RUT_HASH_KEY`, los RUT existentes dejan de encontrarse.
  * **Aplicar en la BD compartida, en dos pasos:** primero `alembic upgrade 0016` (agrega las columnas, cifra cada RUT, comprueba que cada uno se descifra igual y, si algo falla, no cambia nada; un RUT cargado con puntos o `k` minúscula queda normalizado). Después de revisar que registro, login y `/auth/me` funcionan, `alembic upgrade 0017` borra la columna `rut` en texto. Ambas tienen `downgrade`, que reconstruye el RUT descifrándolo con la misma clave. El código de `main` anterior a HU-E deja de poder registrar usuarios después de `0016`: todos deben actualizar el backend junto con la migración.
* **Token:** JWT HS256 firmado con `SECRET_KEY`; dura `ACCESS_TOKEN_EXPIRE_MINUTES` (60 por defecto). Cambia `SECRET_KEY` en `.env` fuera de desarrollo local. Con `ENVIRONMENT` distinto de `development` el backend se niega a arrancar si `SECRET_KEY`, `RUT_ENCRYPTION_KEY` o `RUT_HASH_KEY` siguen con el valor de ejemplo.
* **CORS:** `CORS_ORIGINS` (en `.env`, separados por coma) lista los orígenes web permitidos; en `development` también se aceptan `localhost` y `127.0.0.1` en cualquier puerto. Sin cookies, por eso no se permiten credenciales.
* **Reportes:** `PATCH /api/v1/reports/{id}/status` con `{"status": "resolved"}` cierra un rescate (solo la fundación que tomó el caso o un admin). Los reportes dejan de aparecer en `/reports/nearby` pasados `REPORT_TTL_DAYS` (30) desde su creación.
* **Migrar la BD local de las pruebas:** `docker compose exec -T -e DATABASE_URL= -e DB_SSL=false backend alembic upgrade head` (vaciar `DATABASE_URL` evita tocar la BD compartida).
* **Cuentas de fundación:** no tienen registro público. Se crean desde la terminal:
  ```bash
  docker compose exec backend python -m app.db.create_user --email contacto@fundacion.cl --rut 76.452.189-4 --password Clave1234 --name "Nombre Fundación" --role foundation
  ```

### HU-04: Modelamiento de Datos (PostGIS + Alembic)
* **Tablas creadas y migradas:** Modelos `User`, `Foundation` y `Animal` versionados con **Alembic**.
* **PostGIS Geometry:** El campo `location` de `Animal` utiliza `Geometry('POINT', srid=4326)` con índices espaciales GiST (`idx_animals_location`).
* **Relaciones FK funcionando:** `Animal.foundation_id -> Foundation.id` con eliminación en cascada (`ON DELETE CASCADE`).

### Mapa y búsqueda por cercanía (PostGIS)
* `GET /api/v1/animals` incluye `latitude`, `longitude` y `foundation_name` de cada animal (la geometría cruda `location` no se expone).
* `GET /api/v1/animals/nearby?lat=-33.4378&lng=-70.6505&radius_km=10` devuelve los animales con estado `available` dentro del radio, ordenados del más cercano al más lejano, con `distance_km`.
  * Parámetros: `lat` (-90 a 90), `lng` (-180 a 180) y `radius_km` (mayor que 0, máximo 100; por defecto 10). Fuera de rango: `422`.
  * La distancia se calcula con `ST_Distance` sobre `geography` (metros reales sobre la Tierra) y el filtro usa `ST_DWithin`, que aprovecha el índice GiST de `location`.

### Reportes de mascotas abandonadas
* Tabla `abandoned_dog_reports` (migración `0003`; conserva su nombre aunque ahora admite cualquier animal): comentarios (`description`), foto opcional, estado (`reported`, `in_rescue`, `resolved`), autor y `location` como `Geometry('POINT', srid=4326)` con índice GiST.
* Ficha del animal (migración `0005`): `species`, `size`, `weight_kg`, `color`, `features`, `conditions` y `behaviors` (estas dos son listas, `ARRAY` de PostgreSQL). Son columnas opcionales en la BD porque los reportes anteriores no las tienen; en la respuesta llegan `null` (las listas, vacías).
* `POST /api/v1/reports` (requiere token Bearer): crea un reporte. Devuelve `201`.
  * Obligatorios: `latitude`, `longitude`, `species` (`perro`, `gato`, `otro`), `size` (`pequeño`, `mediano`, `grande`), `color` (2 a 60 caracteres), `conditions` (uno o más, combinables: `bien`, `desnutrido`, `deshidratado`, `herido`, `sangrando`, `cojea`, `atropellado`, `no_se_mueve`, `enfermo`, `problemas_piel`, `parasitos`, `problemas_ojos`, `prenada`, `con_crias`, `deplorable`) y `description` (comentarios sobre la situación, 10 a 1000 caracteres).
  * Opcionales: `weight_kg` (peso aproximado, mayor que 0 y hasta 150), `features` (características como collar o manchas, hasta 300 caracteres), `behaviors` (ninguno, uno o más de `tranquilo`, `amistoso`, `jugueton`, `sigue_personas`, `decaido`, `asustado`, `se_esconde`, `huye`, `nervioso`, `desconfiado`, `ruidoso`, `protector`, `agresivo`) y `photo_url`. Los repetidos se descartan.
  * Fuera de esos valores: `422`.
* `GET /api/v1/reports/nearby?lat=-33.4378&lng=-70.6505&radius_km=10` (público): reportes no resueltos dentro del radio, del más cercano al más lejano, con `distance_km`. Mismos límites de parámetros que `/animals/nearby`.
* La respuesta no expone quién hizo el reporte (`reporter_id`) ni la geometría cruda.

#### Criterio común de búsqueda de reportes (HU-Z)
La app de usuario y la página Reportes del portal consultan el mismo `GET /reports/nearby` con los mismos parámetros, así que con la misma ubicación y el mismo radio muestran **exactamente los mismos reportes** (siempre los que no están resueltos, con el mismo estado y la misma fundación responsable; un reporte nuevo o un cambio de estado aparece en ambas al recargar).
* **Con ubicación:** el punto de quien mira con el radio que elija, de las opciones **5, 10, 25, 50 o 100 km**, por defecto **10 km**. En la app es la ubicación del teléfono (se pide al abrir el mapa; el chip bajo el buscador permite cambiar el radio o "Ver todas"). En el portal es la sede de la fundación de la sesión (`latitude`/`longitude` de `GET /foundations/me`), con un selector de radio en "Zona de búsqueda".
* **Sin ubicación:** Santiago (`-33.4489, -70.6693`) con **100 km**, el radio máximo que acepta la API. Pasa en la app si no se da permiso de ubicación y en el portal si la cuenta no tiene una sede ubicada en el mapa (por ejemplo `admin`).
* El criterio vive en un solo lugar por cliente y los dos deben mantenerse iguales: `reportSearchArea` en `adoptify_app/lib/features/map/map_service.dart` y `portal-fundaciones/src/services/reportArea.ts`. Lo prueban `backend/tests/test_reports_shared_view.py` (compara las dos llamadas sobre los mismos datos), `adoptify_app/test/report_area_test.dart` y `portal-fundaciones/tests/reportArea.test.mjs`.
* Dos búsquedas de la app usan radios propios y no son la vista del mapa: el buscador (100 km desde tu ubicación, para encontrar reportes fuera del radio elegido) y la tarjeta de avisos cercanos (5 km, HU-K). Además, un reporte recién publicado o elegido en el buscador se agrega al mapa aunque quede fuera del radio.

### Comentarios anónimos y "me enteré" en los reportes
* Tablas (migración `0006`), en la misma PostgreSQL: `report_comments` (`report_id`, `author_id`, `body` hasta 500 caracteres, `created_at`; índice por `report_id, created_at`) y `report_likes` (clave primaria `report_id, user_id`: un "me enteré" por persona). Ambas se borran en cascada con el reporte. Un comentario pesa menos de 1 KB, así que miles de comentarios ocupan pocos MB; cuando exista la expiración de reportes, sus comentarios se irán con ellos.
* `GET /api/v1/reports/{id}/comments` (público): comentarios del más antiguo al más nuevo con `id`, `body`, `created_at` e `is_mine` (con token, marca los propios). Nunca expone quién escribió.
* `POST /api/v1/reports/{id}/comments` (requiere token): `{"body": "..."}` de 1 a 500 caracteres (se recortan espacios). Devuelve `201`.
* `GET /api/v1/reports/{id}/likes` (público): `{"count": 3, "liked": false}`; `liked` es `true` si quien consulta (con token) ya lo marcó.
* `PUT /api/v1/reports/{id}/likes` y `DELETE /api/v1/reports/{id}/likes` (requieren token): marcan o quitan tu "me enteré" (marcar dos veces cuenta una) y devuelven el total actualizado.
* Reporte inexistente: `404`. En la app, el detalle del reporte muestra los contadores (♡ y 💬), la conversación ("Anónimo" o "Tú") y una barra fija para escribir; sin sesión invita a iniciarla.

### Gestión de reportes por fundaciones (HU-C)
* `PUT /api/v1/reports/{id}/taken`: registra a su fundación como responsable y pasa el estado a `in_rescue`. Si el reporte no tenía `seen_at`, también lo marca como visto (HU-T). Si otra fundación ya lo tomó, devuelve `409`.
* `POST /api/v1/reports/{id}/seen`: marca un aviso como visto sin cambiar su estado. Se mantiene por compatibilidad, pero desde HU-T ni la app ni el portal lo usan: "visto" se registra al tomar el caso.
* `DELETE /api/v1/reports/{id}/taken`: solo la fundación que tomó el caso puede deshacerlo; vuelve el estado a `reported`.
* Los reportes resueltos no admiten esas marcas (`409`). `GET /reports/nearby` y `GET /reports/{id}` incluyen `foundation_name`, `taken_by_foundation_id`, `seen_at` y `taken_at`, pero nunca `reporter_id`. La app compara `taken_by_foundation_id` con el id de su fundación (`GET /foundations/me`) para ofrecer "Deshacer toma".
* Solo las cuentas con rol `foundation` vinculadas a una fundación pueden marcar: un `admin` recibe `403`.

#### App móvil: vista de fundación (HU-L)
* La barra de fundación es Inicio, Mapa, Mensajes y Mi fundación (los mismos nombres que el portal). `/fundacion/mapa` reutiliza `MapScreen`; los detalles se abren dentro del área de fundación (`/fundacion/reportes/:id`, `/fundacion/animales/:id`, `/fundacion/directorio/:id`) para que `sessionRedirect` no la expulse.
* En el detalle del reporte, la fundación tiene una sola acción (HU-T): "Lo tomamos", o "Deshacer toma" si el caso es suyo. Si otra fundación lo tomó no hay acciones; lo mismo en la página Reportes del portal; un reporte resuelto no muestra acciones y una cuenta de adoptante nunca las ve. Ante `409` o `403` se muestra el mensaje del servidor y se vuelve a leer el reporte.
* La fundación no ve el botón "Reportar mascota": gestiona reportes, no los crea.
* **Decisión sobre el seguimiento por varias fundaciones:** "visto" sigue guardando una sola fundación por reporte (la última reemplaza a la anterior). Es una marca informativa de "alguien ya lo vio", no una lista de seguimiento; lo que da exclusividad es "tomado", que es único por reporte. No se crea la tabla `report_follows` (ni migración ni RLS) hasta que haya un caso real de varias fundaciones siguiendo el mismo reporte; si aparece, bastaría `report_follows (report_id, foundation_id)` con clave única y RLS activada.

#### App móvil: buscador del mapa (HU-X)
* El buscador de `MapScreen` busca por palabras (todas deben aparecer, en cualquier orden, sin tildes ni mayúsculas) en lo que ya cargó el mapa: reportes a 100 km aunque estén fuera del radio elegido (especie, tamaño, color, estados, condiciones, características, comportamiento y descripción), fundaciones (nombre y lugar; no tienen pin, así que al elegir una se abre su perfil), veterinarias (nombre y dirección) y mascotas en adopción no adoptadas (`GET /animals`: nombre, especie, raza, fundación, comuna; "perro" o "gato" las encuentra). No hay endpoint nuevo. Muestra hasta 10 resultados con su tipo (Reporte, En adopción, Fundación, Veterinaria); una mascota en adopción no tiene pin (HU-R), así que al elegirla se abre su ficha; al elegir uno (toque, clic o Enter para el primero) enciende su capa, centra el mapa (acercando lo justo para ver las veterinarias) y abre su tarjeta.

### HU-12: Módulo de fundaciones (backend)
Cada fundación gestiona solo sus propios animales.
* **Vínculo cuenta–fundación (migración `0004`):** `users.foundation_id` (FK nullable a `foundations.id`, `ON DELETE SET NULL`). Solo se usa en cuentas `foundation`; `admin` y `adopter` lo dejan en `NULL`. Una cuenta `foundation` sin fundación asignada no puede gestionar animales (`403`) ni ve ninguno en el listado.
* **Asignar la fundación a una cuenta:** `python -m app.db.create_user ... --role foundation --foundation-id 1`. El seed ya liga `fundacion@adoptify.cl` con "Fundación Garras y Patas". En una BD ya sembrada hay que asignarlo a mano: `UPDATE users SET foundation_id = 1 WHERE email = 'fundacion@adoptify.cl';`
* `POST /api/v1/animals` (requiere token): la fundación del animal sale de la sesión. Una fundación que envíe otro `foundation_id` recibe `403`; un `admin` debe indicarlo (`422` si falta). La foto del animal (`photo_url`) y el lugar de resguardo privado (tipo y texto) son obligatorios para una publicación nueva. Devuelve `201`.
* `PATCH /api/v1/animals/{id}` (requiere token): edición parcial, incluye el cambio de `status` y de ubicación (`latitude` y `longitude` siempre juntas). `404` si no existe y `403` si es de otra fundación.
* `DELETE /api/v1/animals/{id}` (requiere token): `204`; mismos `403` y `404`.
* `GET /api/v1/animals` sigue siendo público. Si el token es de una cuenta `foundation`, solo devuelve los animales de su fundación; visitantes, adoptantes y `admin` ven todos. Un token inválido se trata como visitante. `/animals/nearby` no cambia.
* **Valores válidos:** `species` (`perro`, `gato`), `gender` (`macho`, `hembra`), `size` (`pequeño`, `mediano`, `grande`), `energy_level` (1 a 5), `status` (`available`, `in_process`, `adopted`, `follow_up`; ver HU-Y). Fuera de eso: `422`.
* **Roles:** `admin` puede crear, editar y borrar en cualquier fundación; `adopter` recibe `403`.
* **Lugar de resguardo privado (HU-A):** al crear un animal, la fundación debe indicar `keeping_place_type` (`refugio` o `hogar_temporal`) y `keeping_place_address` (texto de hasta 255 caracteres). Ambos se entregan **solo** por `GET /api/v1/animals/management` y `GET /api/v1/animals/management/{id}` a la fundación dueña o al administrador. No aparecen en `/animals`, `/animals/nearby`, `/foundations` ni en el mapa. Los animales creados antes de esta funcionalidad conservan ambos valores en `null` y el portal muestra “Sin información”. La dirección no se convierte sola en coordenadas: `location` sigue siendo el punto privado de HU-04, pero los formularios la usan como sugerencia del buscador de direcciones (ver abajo).
* **Buscar dirección (`GET /api/v1/geocode?q=...`):** solo `foundation` y `admin` (`403` para adoptantes). Devuelve hasta 5 lugares de Chile con `label`, `latitude`, `longitude` y `commune` (la comuna del catálogo reconocida en el lugar, comparando sin tildes ni mayúsculas; `null` si no se reconoce), para ubicar al animal sin escribir coordenadas y completar sola su comuna pública. Consulta Nominatim de OpenStreetMap desde el backend (máximo una consulta por segundo, caché en memoria y `User-Agent` de la aplicación, como exige su política de uso). `q` va de 3 a 200 caracteres (`422` fuera de eso); si Nominatim falla, `503`.

### Fundaciones
* `GET /api/v1/foundations` (público): fundaciones ordenadas por nombre o, con `lat` y `lng` (opcionales, juntos; si llega solo uno, `422`), de la más cercana a la más lejana con `distance_km` (las sin ubicación al final), con `description`, `address`, `commune`, `city`, `phone`, `email`, `is_verified`, `photo_url` (foto de perfil), `latitude`/`longitude` y `animals` (solo los disponibles, con el mismo formato de `GET /animals`). No expone el RUT ni la geometría cruda. La usan la pestaña Fundaciones y el buscador del mapa de la app (las fundaciones no tienen pin en ningún mapa).
* `GET /api/v1/foundations/me` y `PUT /api/v1/foundations/me` (solo cuentas `foundation` ligadas a una fundación; si no, `403`): perfil de la propia fundación. El `PUT` recibe `description` **obligatoria** (al menos 20 caracteres, se guarda sin espacios sobrantes; si falta o es corta, `422`) y `photo_url` (la URL de `POST /uploads`, o `null` para quitarla). La columna `foundations.photo_url` llega con la migración `0010`.
* **Veterinarias (HU-D):** `veterinary_clinics` (migraciones `0011` y `0014`, con RLS) conserva la carga idempotente de OpenStreetMap (`amenity=veterinary`) y permite altas manuales por administración. El origen queda definido como **importación de OpenStreetMap más alta manual administrativa**: `source` es `importacion`, `manual` o `fundacion`; las respuestas públicas no exponen ese dato ni `is_active`.
  * `GET /api/v1/veterinaries?lat=-33.4489&lng=-70.6693&radius_km=10` es público: devuelve solo activas, en radio de hasta 100 km y ordenadas por distancia, con `name`, contacto, dirección y punto. `/api/v1/veterinary-clinics` se mantiene como alias compatible para clientes antiguos.
  * `POST /api/v1/veterinaries` y `PATCH /api/v1/veterinaries/{id}` son exclusivos para `admin`; una fundación o adoptante recibe `403`.
  * El permiso se revisa antes que los datos (dependencia `require_admin`): un adoptante o una fundación recibe `403` aunque el cuerpo sea inválido.
  * Cada clínica trae `name`, `address`, `commune`, `phone`, `opening_hours`, `emergency` (urgencias o 24 horas) y `latitude`/`longitude`. Sin `lat`/`lng`, el listado va primero con las de urgencias y luego por nombre.
  * La app móvil y el portal las muestran con una cruz distinta de los pines de animales y reportes. Se conserva la atribución © OpenStreetMap, ODbL. Para importar o actualizar OSM: `docker compose exec backend python -m app.db.import_vet_clinics --allow-shared` (por defecto Región Metropolitana; `--region` cambia la región). Es idempotente: cada clínica se identifica por su `osm_id`.
* **Socios de la fundación (HU-F, migración `0015`, tabla `foundation_members` con RLS):** registro interno y privado. CRUD en `GET/POST /api/v1/foundations/me/members` y `PUT/DELETE /api/v1/foundations/me/members/{id}` (campos `name`, `contribution` opcional, `joined_at`, `is_public` por defecto `false`). Solo la fundación dueña edita sus socios (otra recibe `403`, uno inexistente `404`); el administrador ve y edita todos (`?foundation_id=` filtra el listado y al crear debe indicar `foundation_id`). Público: `GET /api/v1/foundations/{id}/members/public` devuelve solo `name` y `joined_at` de los socios con `is_public=true`, nunca el aporte. No hay pasarela ni cobros: el aporte es solo informativo.

### Hogares temporales: postulación (HU-B)
Un adoptante postula para recibir temporalmente a animales rescatados. Tabla `foster_applications` (migración `0019`, con RLS).

| Endpoint | Descripción |
| --- | --- |
| `GET /api/v1/foster-applications/me` | La postulación de la sesión, o `null` si todavía no postula. |
| `POST /api/v1/foster-applications` | Solo rol `adopter` (`403` para otros). Crea la postulación (`201`); `409` si la cuenta ya tiene una. |
| `PUT /api/v1/foster-applications/me` | Edita la postulación mientras está `pending`; `409` si ya fue revisada, `404` si no existe. |
| `DELETE /api/v1/foster-applications/me` | Retira la postulación (`204`); después puede volver a postular. |
| `GET /api/v1/foster-applications` | Solo cuentas `foundation` vinculadas (un adoptante recibe `403`). Lista con el contacto completo: `full_name` y `email` de la cuenta, `phone` y `address`. Primero las pendientes y, en cada estado, de la más antigua a la más nueva; `?status=` filtra. Cada una trae `decided_by_foundation_name` y `can_decide`. |
| `PATCH /api/v1/foster-applications/{id}` | `{"status": "approved" \| "rejected" \| "pending"}`. Una pendiente la decide cualquier fundación; ya decidida, solo la fundación que decidió puede cambiarla o volverla a `pending` (`403` para las demás). `404` si la retiraron. |

* **Campos, todos obligatorios:** `species` (`perro` \| `gato` \| `ambos`), `sizes` (uno o más de `pequeño`, `mediano`, `grande`), `space` (`casa_patio` \| `casa_sin_patio` \| `departamento`), `max_animals` (cuántos puede cuidar a la vez, 1 a 10), `max_days` (días máximos, 1 a 365), `availability` (texto corto, hasta 120), `phone` y `address` (privada, hasta 255). Nombre y correo no se guardan en la postulación: se toman de la cuenta (`users`), así no quedan dos versiones distintas.
* **General:** no lleva `foundation_id`; la ven todas las fundaciones. **Una por cuenta** (`user_id` único): se edita mientras está en revisión y se puede retirar.
* **Decisión: estado global.** Si dos fundaciones contactan a la misma persona, la postulación tiene un solo estado (`pending`, `approved` o `rejected`), y se registra qué fundación decidió (`decided_by_foundation_id`, `decided_at`). Se eligió por simple de mostrar al adoptante y porque la postulación es general. Si más adelante se necesita una decisión por fundación, se agrega la tabla `foster_decisions(application_id, foundation_id, status)` sin cambiar esta.
* **Quién decide:** el estado es global, pero una decisión ya tomada solo la cambia la fundación que la tomó; las demás ven "Aprobada por Fundación X". Los administradores pueden ver la API, pero no deciden (no tienen fundación).
* **Privacidad:** la dirección y el teléfono solo los ven el adoptante dueño y las fundaciones (portal, página **Hogares temporales**). Cada postulación trae el `user_id` del postulante para abrir el chat (botón **Conversar**, HU-G2).

### Errores en español
Todas las respuestas de error llegan en español (`core/errors.py`), sin cambiar su forma:
* **`401`** sin token: `{"detail": "Inicia sesión para continuar."}` (FastAPI respondía "Not authenticated").
  También se traducen "Not Found" (`404`) y "Method Not Allowed" (`405`).
* **`422`** sigue siendo `{"detail": [{"loc", "msg", "type"}]}`, con `msg` en español y el nombre del campo:
  "Nombre: debe tener al menos 2 caracteres.", "Radio: debe ser menor o igual a 100.", "Contraseña: es obligatorio.".
  Los mensajes de los validadores propios llegan tal cual, sin el prefijo "Value error, ". Ya no se devuelve el valor
  enviado (`input`), para no repetir una contraseña en la respuesta.
* El portal y la app muestran el `msg` del primer error (`errorMessage`).
* Los endpoints con sesión nunca responden `401` por un dato mal ingresado (usan `400`): la app y el portal cierran
  sesión ante cualquier `401`.

### HU-16: Subida de imágenes (backend)
* `POST /api/v1/uploads` (requiere token, cualquier rol): recibe `multipart/form-data` con el campo `file` y devuelve `201` con `{"url": "..."}` para guardarla en `photo_url` de un animal o reporte.
* **Validación:** solo JPG y PNG, reconocidos por el contenido del archivo (no por el nombre ni el `Content-Type`). Otro formato: `415`. Más de 5 MB (`MAX_UPLOAD_MB`): `413`. Sin sesión: `401`. Sin archivo: `422`.
* **Almacenamiento:** con `SUPABASE_SERVICE_KEY` en el `.env`, las fotos van al bucket **privado** `fotos` de Supabase Storage y la BD guarda `storage:<archivo>`; el middleware `services/photo_access.py` lo cambia por un enlace firmado (`PHOTO_LINK_HOURS`, 6 h) solo si la petición trae un token válido, y si no, entrega `null`. Sin esa llave (por ejemplo, en las pruebas), se guardan en el disco local `backend/uploads/` (`UPLOAD_DIR`, ignorado por git) y se sirven en `GET /uploads/<archivo>`. En los dos casos el nombre es un UUID: nunca se usa el que envía el cliente. El bucket no se crea solo: en un proyecto nuevo se corre `storage.ensure_bucket()` una vez.
* **URL en disco local:** se arma con `PUBLIC_BASE_URL` si está definida; si no, con la dirección desde la que se llamó a la API. Al probar desde el emulador Android (`10.0.2.2`) la URL saldría con esa dirección y la web no podría abrirla.
* Requiere `python-multipart` (ya en `requirements.txt`), por lo que hay que reconstruir la imagen: `docker compose up --build -d`.

---

## 🗄️ Migraciones y Datos de Prueba (Seed)

* **Aplicar migraciones pendientes con Alembic:**
  ```bash
  docker compose exec backend alembic upgrade head
  ```
* **Crear una migración nueva:** los archivos de `alembic/versions/` se nombran `NNNN_descripcion.py` para que se lean en orden. Al crear una, pasar el siguiente número con `--rev-id`:
  ```bash
  docker compose exec backend alembic revision --autogenerate --rev-id 0003 -m "add_abandoned_dog_reports"
  ```
  Las dos primeras migraciones conservan sus IDs originales (`36de03be1873` y `74255429a3a5`) dentro del archivo porque ya están registrados en la tabla `alembic_version` de las bases existentes; solo se renombró el archivo.
* **Cargar datos de prueba (Seed):**
  ```bash
  docker compose exec backend python -m app.db.seed
  ```
  Esto carga usuarios adoptantes con preferencias, fundaciones con RUTs en Santiago y animales con geolocalización GPS real.
  Cuentas de prueba creadas por el seed (solo para desarrollo local):

  | Correo | RUT | Contraseña | Rol | Dónde entra |
  | --- | --- | --- | --- | --- |
  | `matias.adopter@gmail.com` | `18765432-1` | `Adoptante2026` | `adopter` | App |
  | `sofia.adopter@gmail.com` | `19876543-2` | `Adoptante2026` | `adopter` | App |
  | `fundacion@adoptify.cl` | `20123456-3` | `Fundacion2026` | `foundation` | App y portal |
  | `admin@adoptify.cl` | `11111111-1` | `Admin2026` | `admin` | App y portal |

---

## HU-05: Motor de Match

La función `calculate_match_score(preferences, animal)` en `backend/app/services/match.py`
calcula localmente un `float` entre `0.0` y `100.0`, sin APIs externas ni consultas a BD.
Recibe un diccionario de preferencias (por ejemplo, `user.preferences or {}`) y un objeto `Animal`.

| Clave de preferencia | Atributo de Animal | Peso | Coincidencia |
| --- | --- | --- | --- |
| `preferred_species` | `species` | 30 | Igualdad de texto |
| `preferred_size` | `size` | 25 | Igualdad de texto |
| `min_age_months`, `max_age_months` | `age_months` | 25 | Dentro del rango inclusivo |
| `preferred_energy_level` | `energy_level` | 20 | Igualdad numérica (escala 1 a 5) |

Cada preferencia puede ser un valor o una lista de valores aceptados (`["perro", "gato"]`).
Los textos ignoran mayúsculas y espacios exteriores. Cada criterio aporta todo su
peso si coincide y cero si difiere. La fórmula es `100 * pesos_coincidentes / pesos_comparables`,
redondeada a dos decimales. Las preferencias o atributos ausentes (`None`) se omiten;
sin criterios comparables el resultado es `0.0`. Se permite indicar solo uno de los
límites de edad. Un rango con mínimo mayor que máximo produce `ValueError`.
Otras claves, como `housing_type`, no participan en el cálculo.

```python
from app.models.animal import Animal
from app.services.match import calculate_match_score

animal = Animal(species="perro", size="mediano", age_months=18, energy_level=4)
preferences = {
    "preferred_species": "perro",
    "preferred_size": "pequeño",
    "min_age_months": 6,
    "max_age_months": 24,
    "preferred_energy_level": 2,
}
score = calculate_match_score(preferences, animal)  # 55.0: especie + edad
```

### Formulario "Quiero adoptar" (app móvil)

Es opcional: quien solo reporta animales nunca lo completa y su `preferences` queda vacío.
Se llena y se edita desde **Perfil → Quiero adoptar**.

| Endpoint | Descripción |
| --- | --- |
| `GET /api/v1/users/me/adoption-profile` | Devuelve el formulario guardado, o `null` si aún no lo completó. `401` sin sesión. |
| `PUT /api/v1/users/me/adoption-profile` | Crea o reemplaza el formulario. `422` si falta algo obligatorio (vivienda, niños, otras mascotas, horas solo, especie y tamaño); `403` si la cuenta no es `adopter`. |

Se guarda en `users.preferences` (sin migración): el formulario completo en `adoption_profile` y,
junto a él, las claves que usa el motor (`preferred_species`, `preferred_size`, `preferred_energy_level`,
`min_age_months`, `max_age_months`), derivadas en `services/adoption_profile.py`. Las listas vacías
("me da igual") no entran al cálculo. La actividad se traduce a energía del animal (tranquilo 1-2,
moderado 3, muy activo 4-5) y las edades a meses (cachorro 0-11, adulto 12-83, senior 84+).
Las opciones deben coincidir con `schemas/adoption_profile.py` y `adoption_service.dart`.

Pruebas unitarias (no requieren conexión a BD):

```bash
docker compose exec backend pytest tests/test_match.py -v
```

Incluyen los tres escenarios exigidos (total, parcial y nulo), preferencias
incompletas, edad desconocida y rango de edad invertido. La función puede usarse
desde futuros endpoints; esta HU no agrega una ruta HTTP.

### Conecta (match) y favoritos (backend y app)

En la interfaz el match se llama **Conecta** y el porcentaje se muestra como "83 % compatible"
(app y portal). La API y el código mantienen el nombre `match` (`/animals/match`, `match_score`).

Todos requieren Bearer token y viven bajo `/api/v1/animals`:

| Método | Ruta | Descripción |
| --- | --- | --- |
| `GET` | `/match` | Animales `available` con su `match_score`, de mayor a menor, según "Quiero adoptar". `404` si el usuario no completó ese formulario. No incluye ubicación. |
| `GET` | `/favorites` | Animales marcados con el corazón por el usuario. |
| `PUT` | `/{animal_id}/favorite` | Marca un favorito (`204`). |
| `DELETE` | `/{animal_id}/favorite` | Quita un favorito (`204`). |
| `GET` | `/interested` | Solo fundación o administrador: devuelve por cada animal propio los interesados (`user_id`, `full_name`, `favorited_at`, `match_score`), sin correo, teléfono ni RUT. |
| `GET` | `/{animal_id}/interested` | Igual, para un solo animal. Otra fundación o un adoptante reciben `403`; un id inexistente, `404`. |
| `POST` | `/adoption-applications/animals/{animal_id}` | Adoptante: envía una postulación con una copia de su ficha “Quiero adoptar” y un mensaje opcional. Un favorito no crea una candidatura. |
| `GET` | `/adoption-applications/mine` | Adoptante: consulta el estado de sus propias postulaciones (más reciente primero, sin las retiradas); incluye `animal_photo_url`. |
| `DELETE` | `/adoption-applications/{id}` | Adoptante: retira una postulación en revisión o rechazada (pasa a `withdrawn`, sin borrar la fila). `404` si es ajena o ya retirada; `409` si está aprobada. Puede volver a postular al mismo animal. |
| `GET` | `/adoption-applications/foundation` | Fundación: ve solo las postulaciones a sus animales (sin las retiradas), sin correo, teléfono ni RUT. |
| `PATCH` | `/adoption-applications/{id}/status` | Fundación: revisa, rechaza, preselecciona o invita a conversar a una candidatura propia. Si ya la retiraron: `404` «La postulación ya no existe; quizá la retiraron.». |

Los favoritos se guardan en la tabla `animal_favorites` (migración `0008`).
En la app móvil, la pestaña **Conecta** (`/conecta`; `/match` redirige ahí) muestra las tarjetas (deslizar a la derecha
guarda el favorito) y el corazón de la barra abre la lista de favoritos.

**HU-N (ficha desde Conecta y favoritos):** las tarjetas de `/animals/match` y `/animals/favorites`
incluyen `status` (un favorito puede estar ya adoptado). En la app, "Ver ficha" en la tarjeta y
tocar una fila de favoritos abren `/animales/:id` (descripción, raza, sexo y energía; desde ahí
se postula). Los descartes ("Pasar") se guardan **en el dispositivo** por usuario
(`shared_preferences`, clave `match_discarded_<id>`) y "Ver descartados" los devuelve al mazo.
Bajo 40 % de compatibilidad la tarjeta va al final con el rótulo "Poco compatible".

### Interesados por animal (HU-G1)

Un favorito expresa interés, pero **no crea un chat automáticamente**. La fundación ve los interesados de sus propios animales:

- **Portal:** la card de cada animal en *Mis animales* muestra cuántos interesados tiene, y el detalle (`/animales/:id`) trae la sección **Interesados** con nombre, fecha del favorito y porcentaje de compatibilidad ("83 % compatible").
- **App (vista fundación):** cada card de *Mis animales* tiene el botón **N interesados**, que abre `/fundacion/interesados?animal_id=…` con la misma información y el botón **Conversar**.

Cada respuesta contiene únicamente el ID interno, el nombre, la fecha del favorito y `match_score` (0-100, calculado con `calculate_match_score` sobre las preferencias de “Quiero adoptar”; `null` si la persona no completó la ficha). Nunca expone correo, teléfono ni RUT. Solo cuentan los favoritos de adoptantes; al quitar el corazón, la persona desaparece de la lista.

**Conversar** abre (o retoma) el chat con esa persona (HU-G2), en el portal y en la app.

### Chat entre fundación y adoptante (HU-G2)

Una sola conversación por par fundación-usuario (`conversations`, único por `foundation_id, user_id`), **sin relación con un animal**: si la persona se interesa en otro animal de la misma fundación, se sigue en la misma. Los mensajes (`messages`: `sender_user_id`, `body` de 1 a 1000 caracteres, `created_at`) se borran con la conversación. Migración `0021`, ambas tablas con RLS.

| Endpoint | Descripción |
|---|---|
| `POST /api/v1/conversations` | Solo cuentas `foundation` (`403` para adoptantes y demás). Body `{"user_id"}`. La persona debe estar vinculada a la fundación: dio like a uno de sus animales, postuló a uno de ellos o postuló como hogar temporal (general, la ven todas); si no, `403`. `404` si el `user_id` no es de un adoptante. Crea la conversación (`201`) o devuelve la existente (`200`). |
| `GET /api/v1/conversations` | Las propias: la fundación ve las de su fundación (cualquier socio con cuenta), el adoptante las suyas. Cada una con `user_name`, `foundation_name` y `last_message`; primero las de actividad más reciente. |
| `GET /api/v1/conversations/{id}/messages` | Solo los dos participantes; cualquier otra cuenta recibe `404` (no se revela que existe). Sin `after_id` entrega los últimos 200; con `?after_id=` solo los posteriores, para el sondeo. Cada mensaje trae `from_foundation` y `mine`. |
| `POST /api/v1/conversations/{id}/messages` | Solo los dos participantes (`404` para otros). `{"body"}` de 1 a 1000 caracteres, sin contar espacios al borde; vacío o más largo, `422`. El adoptante responde en las existentes, no abre nuevas. |

* **Sin WebSockets: sondeo.** El portal pide la lista cada 15 s y el chat abierto cada 10 s (solo lo nuevo, con `after_id`), y solo mientras la pestaña está visible. Así un mensaje aparece en 10 s o menos. Se eligió por simple y porque cada consulta a Supabase cuesta ~55 ms; si el uso crece, se puede pasar a WebSockets sin cambiar las tablas.
* **Alcance actual:** vista de chat en el portal (`/mensajes`), pestaña **Mensajes** del adoptante y pestaña **Chat** de la fundación en la app (misma lista y chat, `/fundacion/mensajes/:id`), con el mismo sondeo.

### Cuestionario de adopción por chat (HU-G3)

Al apretar **Conversar** junto a una persona interesada en una mascota (portal: Mis animales → ficha → Interesados;
app: Mis animales → interesados), el chat le hace **las preguntas de la fundación una a una**. Cada respuesta se
guarda y llega la siguiente; al terminar, la fundación abre **Ver postulación** (pop-up en el portal), ve las
respuestas con las que **no cumplen marcadas en rojo** y la **acepta o rechaza** con un mensaje predeterminado que
puede editar. Nada se rechaza solo: decide la fundación.

* **Preguntas sugeridas:** toda fundación parte con 8 (`services/adoption_questionnaire.py`, `DEFAULT_QUESTIONS`):
  mayor de 18, hogar de acuerdo, vivienda que permite mascotas, cierre seguro, gastos y Ley Cholito, qué haría si se
  cambia, visita y seguimiento (las 7 filtran) y por qué quiere adoptar (texto). Se editan en **Mi fundación →
  Preguntas de adopción**; "Volver a las sugeridas" las restablece. Sin preguntas, Conversar solo abre el chat.
* **Una sola vez por persona y mascota** (`UNIQUE (conversation_id, animal_id)`); tampoco empieza otro mientras la
  persona responde uno en la misma conversación. Cada cuestionario guarda una **copia** de las preguntas: editarlas
  después no lo cambia.
* **Migración `0023`** (idempotente; la primera versión de HU-G3 ya estaba en la BD compartida), tablas con RLS:
  * `foundations.adoption_form_customized`: `false` usa las sugeridas.
  * `adoption_form_questions`: `label` (hasta 200), `kind` (`text` | `yes_no` | `choice`), `options` (solo `choice`,
    2 a 10), `required` y `flagged_answers` (lo que no cumple: `false`/`true` o alternativas; al menos una alternativa
    debe cumplir). Máximo 20.
  * `adoption_form_requests`: `conversation_id`, `animal_id`, `questions` (copia), `answers` (crece de a una),
    `answered_at`, `decision` (`accepted` | `rejected`) y `decided_at`.
  * `messages.kind`: `text` | `question` (pregunta automática, sin remitente) | `answer`. Las preguntas traen
    `question: {form_id, animal_id, index, total, kind, options, required}` para mostrar los botones.

| Endpoint | Descripción |
|---|---|
| `POST /api/v1/conversations` | Con `animal_id` (opcional) empieza el cuestionario de esa mascota: saludo y primera pregunta. `404` si la mascota no es de la fundación. |
| `GET / PUT / DELETE /api/v1/foundations/me/adoption-form` | Ver (`customized` indica si son propias), reemplazar o volver a las sugeridas. `403` para adoptantes; `422` con preguntas inválidas. |
| `POST /api/v1/conversations/{id}/forms/{form_id}/answer` | Solo el adoptante. `{"answer": true \| "texto" \| null}` responde la pregunta pendiente (`null` salta una opcional). Devuelve su respuesta y la siguiente pregunta (o el cierre). `422` si no corresponde al tipo, `409` si ya terminó. |
| `GET /api/v1/adoption-form-requests/{id}` | Solo la fundación de la mascota: preguntas, respuestas y `flagged` (cuál no cumple). Sin contacto ni RUT; otra fundación recibe `404`. |
| `POST /api/v1/adoption-form-requests/{id}/decision` | `{"decision": "accepted" \| "rejected", "message": "..."}`. Envía el mensaje por el chat y deja la decisión; `409` si faltan respuestas o ya se decidió. |

`GET /animals/interested` y `/animals/{id}/interested` traen por persona `questionnaire: {id, answered, total,
completed, flagged, decision}` (o `null`), y la tarjeta de Mis animales muestra **N por revisar**.

* **App (adoptante):** en el chat, las preguntas de sí o no y de alternativas se responden con botones (reemplazan
  al campo de texto) y las abiertas escribiendo; "Prefiero no responder" salta las opcionales.
* **App (fundación):** "Conversar" en los interesados manda `animal_id`. Ver la postulación es solo en el portal.

### Animales por estado y Seguimiento (HU-Y)

La fundación gestiona sus animales en **pestañas por estado**, con el conteo de cada una: **Disponibles**,
**En proceso**, **Adoptados** y **Seguimiento** (portal: Mis animales; app: Inicio → Mis animales, con los mismos nombres). Cada animal
aparece en una sola pestaña, la de su estado actual, y al cambiar el estado la tarjeta se mueve de pestaña al
instante, sin recargar la página ni volver a pedir la lista.

* **Seguimiento es un estado nuevo** (`Animal.status = "follow_up"`), no una vista de los adoptados: la fundación
  tiene que poder entrar y salir de él, y con `adoption_profile.accepts_follow_up` (una preferencia del adoptante)
  el animal aparecería en dos pestañas a la vez. La columna `status` es `String(50)` sin restricción en la base,
  así que **no hace falta migración**: solo cambian el `Literal` de `schemas/animal.py` y las etiquetas.
* **Solo se entra desde Adoptado:** `PATCH /api/v1/animals/{id}` con `status: "follow_up"` responde `400`
  ("Solo un animal adoptado puede pasar a Seguimiento.") si el animal no está en `adopted` ni en `follow_up`.
  De `follow_up` se vuelve a `adopted` (o a cualquier otro estado) sin restricción. `POST /api/v1/animals` rechaza
  `follow_up` con `422`: una publicación nueva nunca parte en Seguimiento.
* **Un animal en `follow_up` ya tiene familia:** queda fuera de `/animals/nearby`, de `/animals/match` y del mapa
  de la app, igual que un adoptado. Sigue apareciendo en `/animals` y en `/animals/management`.
* **Etiquetas:** el estado de un animal se muestra en singular (Disponible, En proceso, Adoptado, Seguimiento) y la
  pestaña en plural (Disponibles, En proceso, Adoptados, Seguimiento). Portal: `services/animalStatus.ts`
  (`statuses`, `tabLabels`, `statusTabs`, `statusOptions`); app: `foundation_animals_service.dart`
  (`animalStatusLabels`, `animalStatusTabs`, `animalStatusTabLabels`, `animalStatusOptions`). Mantener las dos
  iguales.
* **Pruebas:** backend `tests/test_animals_crud.py` (`test_follow_up_only_after_adoption`,
  `test_create_rejects_follow_up_status`); portal `tests/animalStatus.test.mjs`; app
  `test/foundation_animal_tabs_test.dart`.

## 🧪 Ejecución de Pruebas Automatizadas (Testing Suite)

Para ejecutar la suite completa de pruebas unitarias y de integración dentro del contenedor:

```bash
docker compose exec backend pytest -v
```

Las pruebas usan siempre el Postgres local (nunca la BD compartida), escriben datos con correos y RUT únicos y los
borran al terminar. Hay un archivo por módulo en `backend/tests/`; entre otras cosas verifican:
1. **Infraestructura (HU-01, HU-02):** `.env`, conexión a PostgreSQL/PostGIS, Swagger (`/docs`) y `/health`.
2. **Cuenta:** registro con RUT obligatorio y único (cifrado), login único y por acceso (app o portal), JWT,
   verificación en dos pasos, edición del nombre y cambio de contraseña (`400`, no `401`, si la actual es incorrecta).
3. **Errores en español:** `401` sin token, `422` traducidos y sin repetir lo enviado, y el orden permiso/validación.
4. **Datos y permisos:** animales y fundaciones (PostGIS), reportes, match, favoritos e interesados, hogares temporales,
   postulaciones, socios, veterinarias, fotos privadas y chat.





### Ubicación pública de adopción y avisos de rescate

Aplicar la migración 0007 con `docker compose exec backend alembic upgrade head`.
En el formulario de animales, elegir la comuna que verá el público. Es opcional:
los animales existentes conservan su punto privado y quedan con «Zona no informada»
hasta que su fundación complete la comuna. El formulario usa `GET /api/v1/animals/communes`.

**Nombres de comunas (migración 0022):** el catálogo `communes.json` venía de GeoNames con
varios nombres mal escritos ("Aisen", "Chillan", "Peñalolen", "O Higgins"...). Se corrigieron
65 a la escritura oficial ("Aysén", "Chillán", "Peñalolén", "O'Higgins"); la lista está en
`services/commune_renames.py` y los puntos no cambian. La migración `0022` actualiza los
animales que ya tenían guardado un nombre antiguo (aplicarla también en la BD compartida,
la persona responsable). La API solo acepta los nombres corregidos.

- El listado público, la búsqueda por radio y los animales de `GET /foundations`
  entregan `public_commune` y `commune_point` (latitud, longitud de referencia).
  Cada animal de una comuna usa el mismo punto fijo. Nunca se deriva del domicilio.
  Sin comuna, ambos valores son nulos. El cálculo del radio se realiza en PostGIS
  con la ubicación real, sin exponer coordenadas privadas ni distancia numérica.
- Solo `GET /animals/management` y `GET /animals/management/{id}` permiten
  consultar puntos privados, con autenticación y autorización de propietario o admin.
- Los avisos activos de rescate mantienen sus coordenadas exactas de avistamiento;
  al superponerse, su marcador tiene prioridad. Las sedes conservan su ubicación pública.
- Las fichas de animales (app y portal) no muestran mapa ni coordenadas, solo la comuna
  como texto (HU-J): el `commune_point` se usa únicamente para ubicar el pin en el mapa
  general. El detalle de un reporte sí conserva su mini mapa, porque sirve para el rescate.
- Referencias comunales: datos ADM3 de Chile de [GeoNames](https://www.geonames.org/),
  [extracto CL](https://download.geonames.org/export/dump/CL.zip) bajo
  [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). El catálogo local
  adapta los nombres y conserva únicamente el nombre y las coordenadas de cada comuna.
