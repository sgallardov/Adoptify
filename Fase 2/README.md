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
Inicio de sesión único con dos tipos de cuenta, que corresponden a las pestañas **Usuario** y **Fundación** del login web.

| Endpoint | Descripción |
| --- | --- |
| `POST /api/v1/auth/register` | Registra un **adoptante** (`email`, `rut`, `password`, `full_name`). `201`, o `409` si el correo o el RUT ya existen. |
| `POST /api/v1/auth/login` | Recibe `email`, `password` y, opcional, `account_type` (`"user"` o `"foundation"`). Sin `account_type` entra cualquier cuenta (login único de la app, que muestra la vista según el `role`); con él, solo ese tipo (el portal manda `"foundation"`). Devuelve `access_token` (JWT) y `role`. `401` si las credenciales son incorrectas; `403` si la cuenta no corresponde al `account_type` pedido. |
| `GET /api/v1/auth/me` | Devuelve el usuario del token enviado en `Authorization: Bearer <token>`. `401` sin token o con token inválido/expirado. |

* **Roles por pestaña:** `user` → `adopter`; `foundation` → `foundation` o `admin`.
* **Contraseñas:** se guardan con bcrypt. Mínimo 8 caracteres y máximo 72 bytes (la `ñ` y las tildes cuentan doble).
* **Correos:** se guardan y comparan en minúsculas.
* **RUT:** atributo obligatorio y único de cada usuario (no se usa para autenticar). Se acepta con o sin puntos (`12.345.678-5` o `12345678-5`), solo se revisa el formato (no el dígito verificador) y se guarda sin puntos con `K` mayúscula. Formato inválido: `422`.
* **Token:** JWT HS256 firmado con `SECRET_KEY`; dura `ACCESS_TOKEN_EXPIRE_MINUTES` (60 por defecto). Cambia `SECRET_KEY` en `.env` fuera de desarrollo local.
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

### Comentarios anónimos y "me enteré" en los reportes
* Tablas (migración `0006`), en la misma PostgreSQL: `report_comments` (`report_id`, `author_id`, `body` hasta 500 caracteres, `created_at`; índice por `report_id, created_at`) y `report_likes` (clave primaria `report_id, user_id`: un "me enteré" por persona). Ambas se borran en cascada con el reporte. Un comentario pesa menos de 1 KB, así que miles de comentarios ocupan pocos MB; cuando exista la expiración de reportes, sus comentarios se irán con ellos.
* `GET /api/v1/reports/{id}/comments` (público): comentarios del más antiguo al más nuevo con `id`, `body`, `created_at` e `is_mine` (con token, marca los propios). Nunca expone quién escribió.
* `POST /api/v1/reports/{id}/comments` (requiere token): `{"body": "..."}` de 1 a 500 caracteres (se recortan espacios). Devuelve `201`.
* `GET /api/v1/reports/{id}/likes` (público): `{"count": 3, "liked": false}`; `liked` es `true` si quien consulta (con token) ya lo marcó.
* `PUT /api/v1/reports/{id}/likes` y `DELETE /api/v1/reports/{id}/likes` (requieren token): marcan o quitan tu "me enteré" (marcar dos veces cuenta una) y devuelven el total actualizado.
* Reporte inexistente: `404`. En la app, el detalle del reporte muestra los contadores (♡ y 💬), la conversación ("Anónimo" o "Tú") y una barra fija para escribir; sin sesión invita a iniciarla.

### Gestión de reportes por fundaciones (HU-C)
* `POST /api/v1/reports/{id}/seen`: una cuenta `foundation` vinculada puede marcar un aviso como visto sin cambiar su estado.
* `PUT /api/v1/reports/{id}/taken`: registra a su fundación como responsable y pasa el estado a `in_rescue`. Si otra fundación ya lo tomó, devuelve `409`.
* `DELETE /api/v1/reports/{id}/taken`: solo la fundación que tomó el caso puede deshacerlo; vuelve el estado a `reported`.
* Los reportes resueltos no admiten esas marcas (`409`). `GET /reports/nearby` y `GET /reports/{id}` incluyen `foundation_name`, `seen_at` y `taken_at`, pero nunca `reporter_id`.

### HU-12: Módulo de fundaciones (backend)
Cada fundación gestiona solo sus propios animales.
* **Vínculo cuenta–fundación (migración `0004`):** `users.foundation_id` (FK nullable a `foundations.id`, `ON DELETE SET NULL`). Solo se usa en cuentas `foundation`; `admin` y `adopter` lo dejan en `NULL`. Una cuenta `foundation` sin fundación asignada no puede gestionar animales (`403`) ni ve ninguno en el listado.
* **Asignar la fundación a una cuenta:** `python -m app.db.create_user ... --role foundation --foundation-id 1`. El seed ya liga `fundacion@adoptify.cl` con "Fundación Garras y Patas". En una BD ya sembrada hay que asignarlo a mano: `UPDATE users SET foundation_id = 1 WHERE email = 'fundacion@adoptify.cl';`
* `POST /api/v1/animals` (requiere token): la fundación del animal sale de la sesión. Una fundación que envíe otro `foundation_id` recibe `403`; un `admin` debe indicarlo (`422` si falta). La foto del animal (`photo_url`) y el lugar de resguardo privado (tipo y texto) son obligatorios para una publicación nueva. Devuelve `201`.
* `PATCH /api/v1/animals/{id}` (requiere token): edición parcial, incluye el cambio de `status` y de ubicación (`latitude` y `longitude` siempre juntas). `404` si no existe y `403` si es de otra fundación.
* `DELETE /api/v1/animals/{id}` (requiere token): `204`; mismos `403` y `404`.
* `GET /api/v1/animals` sigue siendo público. Si el token es de una cuenta `foundation`, solo devuelve los animales de su fundación; visitantes, adoptantes y `admin` ven todos. Un token inválido se trata como visitante. `/animals/nearby` no cambia.
* **Valores válidos:** `species` (`perro`, `gato`), `gender` (`macho`, `hembra`), `size` (`pequeño`, `mediano`, `grande`), `energy_level` (1 a 5), `status` (`available`, `in_process`, `adopted`). Fuera de eso: `422`.
* **Roles:** `admin` puede crear, editar y borrar en cualquier fundación; `adopter` recibe `403`.
* **Lugar de resguardo privado (HU-A):** al crear un animal, la fundación debe indicar `keeping_place_type` (`refugio` o `hogar_temporal`) y `keeping_place_address` (texto de hasta 255 caracteres). Ambos se entregan **solo** por `GET /api/v1/animals/management` y `GET /api/v1/animals/management/{id}` a la fundación dueña o al administrador. No aparecen en `/animals`, `/animals/nearby`, `/foundations` ni en el mapa. Los animales creados antes de esta funcionalidad conservan ambos valores en `null` y el portal muestra “Sin información”. La dirección no se geocodifica: `location` continúa siendo el punto privado ya existente de HU-04.
* **Lugar de resguardo privado (HU-A):** al crear un animal, la fundación debe indicar `keeping_place_type` (`refugio` o `hogar_temporal`) y `keeping_place_address` (texto de hasta 255 caracteres). Ambos se entregan **solo** por `GET /api/v1/animals/management` y `GET /api/v1/animals/management/{id}` a la fundación dueña o al administrador. No aparecen en `/animals`, `/animals/nearby`, `/foundations` ni en el mapa. Los animales creados antes de esta funcionalidad conservan ambos valores en `null` y el portal muestra “Sin información”. La dirección no se geocodifica: `location` continúa siendo el punto privado ya existente de HU-04.

### Fundaciones
* `GET /api/v1/foundations` (público): fundaciones ordenadas por nombre o, con `lat` y `lng` (opcionales, juntos; si llega solo uno, `422`), de la más cercana a la más lejana con `distance_km` (las sin ubicación al final), con `description`, `address`, `commune`, `city`, `phone`, `email`, `is_verified`, `photo_url` (foto de perfil), `latitude`/`longitude` y `animals` (solo los disponibles, con el mismo formato de `GET /animals`). No expone el RUT ni la geometría cruda. La usan la pestaña Fundaciones y los pines de fundaciones del mapa de la app.
* `GET /api/v1/foundations/me` y `PUT /api/v1/foundations/me` (solo cuentas `foundation` ligadas a una fundación; si no, `403`): perfil de la propia fundación. El `PUT` recibe `description` **obligatoria** (al menos 20 caracteres, se guarda sin espacios sobrantes; si falta o es corta, `422`) y `photo_url` (la URL de `POST /uploads`, o `null` para quitarla). La columna `foundations.photo_url` llega con la migración `0010`.
* **Veterinarias (HU-D):** `veterinary_clinics` (migraciones `0011` y `0014`, con RLS) conserva la carga idempotente de OpenStreetMap (`amenity=veterinary`) y permite altas manuales por administración. El origen queda definido como **importación de OpenStreetMap más alta manual administrativa**: `source` es `importacion`, `manual` o `fundacion`; las respuestas públicas no exponen ese dato ni `is_active`.
  * `GET /api/v1/veterinaries?lat=-33.4489&lng=-70.6693&radius_km=10` es público: devuelve solo activas, en radio de hasta 100 km y ordenadas por distancia, con `name`, contacto, dirección y punto. `/api/v1/veterinary-clinics` se mantiene como alias compatible para clientes antiguos.
  * `POST /api/v1/veterinaries` y `PATCH /api/v1/veterinaries/{id}` son exclusivos para `admin`; una fundación o adoptante recibe `403`.
  * La app móvil y el portal las muestran con una cruz distinta de los pines de animales y reportes. Se conserva la atribución © OpenStreetMap, ODbL. Para importar o actualizar OSM: `docker compose exec backend python -m app.db.import_vet_clinics --allow-shared` (por defecto Región Metropolitana; `--region` cambia la región).

### HU-16: Subida de imágenes (backend)
* `POST /api/v1/uploads` (requiere token, cualquier rol): recibe `multipart/form-data` con el campo `file` y devuelve `201` con `{"url": "..."}` para guardarla en `photo_url` de un animal o reporte.
* **Validación:** solo JPG y PNG, reconocidos por el contenido del archivo (no por el nombre ni el `Content-Type`). Otro formato: `415`. Más de 5 MB (`MAX_UPLOAD_MB`): `413`. Sin sesión: `401`. Sin archivo: `422`.
* **Almacenamiento (decisión provisoria):** volumen local `backend/uploads/` (`UPLOAD_DIR`), ignorado por git y servido en `GET /uploads/<archivo>`. El nombre es un UUID: nunca se usa el nombre que envía el cliente. Para migrar a S3 o Cloudinary solo habría que cambiar la escritura en `endpoints/uploads.py`.
* **URL devuelta:** se arma con `PUBLIC_BASE_URL` si está definida; si no, con la dirección desde la que se llamó a la API. Al probar desde el emulador Android (`10.0.2.2`) la URL saldría con esa dirección y la web no podría abrirla; en un entorno desplegado hay que definir `PUBLIC_BASE_URL`.
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

  | Correo | RUT | Contraseña | Rol | Pestaña del login |
  | --- | --- | --- | --- | --- |
  | `matias.adopter@gmail.com` | `18765432-1` | `Adoptante2026` | `adopter` | Usuario |
  | `sofia.adopter@gmail.com` | `19876543-2` | `Adoptante2026` | `adopter` | Usuario |
  | `fundacion@adoptify.cl` | `20123456-3` | `Fundacion2026` | `foundation` | Fundación |
  | `admin@adoptify.cl` | `11111111-1` | `Admin2026` | `admin` | Fundación |

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

### Match y favoritos (backend y app)

Todos requieren Bearer token y viven bajo `/api/v1/animals`:

| Método | Ruta | Descripción |
| --- | --- | --- |
| `GET` | `/match` | Animales `available` con su `match_score`, de mayor a menor, según "Quiero adoptar". `404` si el usuario no completó ese formulario. No incluye ubicación. |
| `GET` | `/favorites` | Animales marcados con el corazón por el usuario. |
| `PUT` | `/{animal_id}/favorite` | Marca un favorito (`204`). |
| `DELETE` | `/{animal_id}/favorite` | Quita un favorito (`204`). |

Los favoritos se guardan en la tabla `animal_favorites` (migración `0008`).
En la app móvil, la pestaña **Match** muestra las tarjetas (deslizar a la derecha
guarda el favorito) y el corazón de la barra abre la lista de favoritos.

## 🧪 Ejecución de Pruebas Automatizadas (Testing Suite)

Para ejecutar la suite completa de pruebas unitarias y de integración dentro del contenedor:

```bash
docker compose exec backend pytest -v
```

Esto ejecuta 18 pruebas asíncronas verificando automáticamente:
1. **HU-01:** Carga de `.env`, conexión asíncrona a PostgreSQL, PostGIS 15 y persistencia.
2. **HU-02:** Swagger UI (`/docs`), OpenAPI v3 y endpoint `/health` validado con Pydantic v2.
3. **Login:** registro con RUT obligatorio y único, login por pestaña (usuario/fundación), sesión con JWT y casos borde (mayúsculas, 72 bytes).
4. **HU-04:** Creación de usuarios con preferencias JSON, fundaciones con RUT y validación de geometrías PostGIS en animales con integridad referencial en cascada.





### Ubicación pública de adopción y avisos de rescate

Aplicar la migración 0007 con `docker compose exec backend alembic upgrade head`.
En el formulario de animales, elegir la comuna que verá el público. Es opcional:
los animales existentes conservan su punto privado y quedan con «Zona no informada»
hasta que su fundación complete la comuna. El formulario usa `GET /api/v1/animals/communes`.

- El listado público, la búsqueda por radio y los animales de `GET /foundations`
  entregan `public_commune` y `commune_point` (latitud, longitud de referencia).
  Cada animal de una comuna usa el mismo punto fijo. Nunca se deriva del domicilio.
  Sin comuna, ambos valores son nulos. El cálculo del radio se realiza en PostGIS
  con la ubicación real, sin exponer coordenadas privadas ni distancia numérica.
- Solo `GET /animals/management` y `GET /animals/management/{id}` permiten
  consultar puntos privados, con autenticación y autorización de propietario o admin.
- Los avisos activos de rescate mantienen sus coordenadas exactas de avistamiento;
  al superponerse, su marcador tiene prioridad. Las sedes conservan su ubicación pública.
- Referencias comunales: datos ADM3 de Chile de [GeoNames](https://www.geonames.org/),
  [extracto CL](https://download.geonames.org/export/dump/CL.zip) bajo
  [CC BY 4.0](https://creativecommons.org/licenses/by/4.0/). El catálogo local
  adapta los nombres y conserva únicamente el nombre y las coordenadas de cada comuna.
