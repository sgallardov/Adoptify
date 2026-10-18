# Adoptify — Portal de fundaciones (HU-06 y HU-07)

Maqueta web con Vite, React, TypeScript, TailwindCSS y React Router.

## Iniciar

Requiere Node.js 22.12+ (o 20.19+) y npm. Desde esta carpeta: Adoptify\Fase 2\portal-fundaciones

```powershell
npm ci
npm run dev
```

Abrir la dirección que indique Vite, normalmente http://localhost:5173.
Si las dependencias ya están instaladas, basta con `npm run dev`.
Detener el servidor con Ctrl+C.

## Compilar

```powershell
npm run build
npm run preview
```

`build` verifica TypeScript y genera `dist/`. Para desplegar con BrowserRouter,
el servidor debe devolver `index.html` para rutas como `/animales/1`.

## Contenido

- `/`: bienvenida, estadísticas calculadas desde la API y animales disponibles.
- `/animales` (Mis casos): tarjetas de PostgreSQL, búsqueda por nombre y filtros por especie y estado.
- `/animales/:id`: ficha de cada animal; IDs desconocidos muestran página no encontrada.
- `/fundacion`: perfil de la organización de ejemplo.
- Sidebar en escritorio y menú desplegable en pantallas pequeñas.
- Etiquetas accesibles, navegación por teclado y estados sin resultados.

## Estructura

```text
src/
  App.tsx              # Rutas y layout compartido
  components/          # Sidebar, encabezados y tarjetas
  pages/               # Inicio, listado, detalle, fundación y página no encontrada
  data/demo.ts         # Datos ficticios de la maqueta
  index.css            # TailwindCSS y estilos globales
vite.config.ts         # Plugins de React y TailwindCSS
```

Tailwind se integra con `@tailwindcss/vite` y `@import "tailwindcss"`.
Referencia: https://tailwindcss.com/docs/installation/using-vite
La navegación utiliza el modo declarativo de React Router:
https://reactrouter.com/start/declarative/installation

## Alcance y validación

El listado, el detalle y los contadores consumen `GET /api/v1/animals` con Axios.
Se muestra carga, error con reintento y lista vacía. Las peticiones se cancelan al
desmontar la vista. Los estados del backend se traducen al español y las edades
se muestran en años y meses. Una foto ausente o fallida muestra un icono alternativo.
El perfil de la organización sigue siendo una maqueta.
No hay autenticación ni creación, edición o eliminación de animales.
La API lista animales de todas las fundaciones: el filtrado por la organización
autenticada queda pendiente para la HU de autenticación.

## Configurar la API (HU-07)

El valor predeterminado es `http://localhost:8000/api/v1`. Para cambiarlo, copiar
`.env.example` a `.env.local`, ajustar `VITE_API_URL` y reiniciar Vite.
Esta variable es pública; no debe contener credenciales.

Desde `Fase 2`, levantar el backend y aplicar las migraciones:

```powershell
docker compose up -d db backend
docker compose exec backend alembic upgrade head
```

Opcional, si se necesitan animales de prueba:

```powershell
docker compose exec backend python -m app.db.seed
```

La API devuelve un arreglo JSON (`[]` si no hay animales), ordenado por ID.
Las geometrías PostGIS y relaciones ORM no se exponen en este contrato.
Ante errores SQL devuelve HTTP 503 con un mensaje público.

Pruebas de backend:

```powershell
docker compose exec backend pytest tests/test_animals.py -v
```

Validado: `npm run build`, navegación móvil, búsqueda, filtros combinados,
estado sin resultados, restablecimiento y apertura del detalle de un animal.

## FALTA POR AGREGAR¡¡¡¡¡
Una seccion en donde se pueda agregar un nuevo animal en adopcion en portal-fundaciones
