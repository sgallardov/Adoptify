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

### HU-03: Autenticación (Validación de RUT Institucional)
* **Endpoint:** `POST /api/v1/auth/validate-rut`
* **Validación de Sintaxis:** Validación estricta de RUT chileno con Regex en Pydantic (`^(\d{1,2}(?:\.\d{3}){2}-[\dkK]|\d{7,8}-[\dkK])$`). Retorna `HTTP 422` ante formatos incorrectos.
* **Lógica Mock de Autenticidad:**
  * Retorna `HTTP 200` con `{"is_valid": true}` si el RUT termina en dígito par (`0, 2, 4, 6, 8`).
  * Retorna `HTTP 400` con `{"is_valid": false}` si el RUT termina en dígito impar (`1, 3, 5, 7, 9`) o letra `K`.

### HU-04: Modelamiento de Datos (PostGIS + Alembic)
* **Tablas creadas y migradas:** Modelos `User`, `Foundation` y `Animal` versionados con **Alembic**.
* **PostGIS Geometry:** El campo `location` de `Animal` utiliza `Geometry('POINT', srid=4326)` con índices espaciales GiST (`idx_animals_location`).
* **Relaciones FK funcionando:** `Animal.foundation_id -> Foundation.id` con eliminación en cascada (`ON DELETE CASCADE`).

---

## 🗄️ Migraciones y Datos de Prueba (Seed)

* **Aplicar migraciones pendientes con Alembic:**
  ```bash
  docker compose exec backend alembic upgrade head
  ```
* **Cargar datos de prueba (Seed):**
  ```bash
  docker compose exec backend python -m app.db.seed
  ```
  Esto carga usuarios adoptantes con preferencias, fundaciones con RUTs en Santiago y animales con geolocalización GPS real.

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
3. **HU-03:** Sintaxis de RUT chileno con Regex y regla Mock de dígito par/impar para HTTP 200 y 400.
4. **HU-04:** Creación de usuarios con preferencias JSON, fundaciones con RUT y validación de geometrías PostGIS en animales con integridad referencial en cascada.



