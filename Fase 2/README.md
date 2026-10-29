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
| `POST /api/v1/auth/login` | Recibe `email`, `password` y `account_type` (`"user"` o `"foundation"`). Devuelve `access_token` (JWT) y `role`. `401` si las credenciales son incorrectas; `403` si la cuenta no corresponde a la pestaña. |
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

### Reportes de perros abandonados
* Tabla `abandoned_dog_reports` (migración `0003`): descripción, foto opcional, estado (`reported`, `in_rescue`, `resolved`), autor y `location` como `Geometry('POINT', srid=4326)` con índice GiST.
* `POST /api/v1/reports` (requiere token Bearer): crea un reporte con `latitude`, `longitude` y `description` (10 a 1000 caracteres). Devuelve `201`.
* `GET /api/v1/reports/nearby?lat=-33.4378&lng=-70.6505&radius_km=10` (público): reportes no resueltos dentro del radio, del más cercano al más lejano, con `distance_km`. Mismos límites de parámetros que `/animals/nearby`.
* La respuesta no expone quién hizo el reporte (`reporter_id`) ni la geometría cruda.

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

Pruebas unitarias (no requieren conexión a BD):

```bash
docker compose exec backend pytest tests/test_match.py -v
```

Incluyen los tres escenarios exigidos (total, parcial y nulo), preferencias
incompletas, edad desconocida y rango de edad invertido. La función puede usarse
desde futuros endpoints; esta HU no agrega una ruta HTTP.

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



