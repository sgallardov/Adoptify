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

- `/login`: inicio de sesión único con pestañas **Usuario** y **Fundación**; la pestaña Usuario permite registrarse.
- `/usuario`: inicio del adoptante (requiere cuenta `adopter`). Mapa de OpenStreetMap con las mascotas disponibles
  (pines naranjos) y los perros abandonados reportados (pines rojos), con la lista de mascotas al costado;
  "Usar mi ubicación" filtra por radio (5 a 100 km) y ordena por distancia con `GET /animals/nearby` y `GET /reports/nearby`.
  Sin ubicación, los reportes se buscan a 100 km de Santiago.
- `/reportar`: formulario para reportar un perro abandonado (requiere cuenta `adopter`). Se marca el lugar haciendo clic
  en el mapa, arrastrando el pin o con "Usar mi ubicación", y se envía con `POST /reports`. No se publican los datos de quien reporta.
- Las rutas siguientes requieren una cuenta `foundation` o `admin`; sin sesión redirigen a `/login`.
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
La sesión usa el JWT de `POST /api/v1/auth/login`, guardado en `localStorage` y
enviado en cada petición (`src/services/api.ts`); al recargar se recupera con `GET /auth/me`.
No hay creación, edición o eliminación de animales.
La API lista animales de todas las fundaciones: falta vincular cada cuenta de fundación
con su organización para filtrar por la fundación autenticada.

## Configurar la API (HU-07)

El valor predeterminado es `http://localhost:8000/api/v1`. Para cambiarlo, copiar
`.env.example` a `.env.local`, ajustar `VITE_API_URL` y reiniciar Vite.
Esta variable es pública; no debe contener credenciales.

## Mapa (Leaflet + OpenStreetMap)

Los mapas usan [Leaflet](https://leafletjs.com/) con `react-leaflet` y los mosaicos públicos de OpenStreetMap.
No requieren API key, cuenta ni tarjeta. La configuración compartida (URL de mosaicos, atribución, íconos)
está en `src/components/mapTiles.ts`.

- La atribución "© OpenStreetMap" es obligatoria y ya se muestra en el mapa.
- Los mosaicos de `tile.openstreetmap.org` tienen una [política de uso justo](https://operations.osmfoundation.org/policies/tiles/):
  sirven para desarrollo y un piloto. Si el tráfico crece, cambiar `OSM_TILES` por la URL de un proveedor de mosaicos
  (por ejemplo MapTiler); los componentes no cambian.
- Al ver un mapa, el navegador del usuario pide mosaicos a OpenStreetMap, que recibe su IP y la zona que está viendo.
- "Usar mi ubicación" requiere `localhost` o HTTPS.

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
docker compose exec backend pytest tests/test_animals.py tests/test_reports.py -v
```

Validado: `npm run build`, navegación móvil, búsqueda, filtros combinados,
estado sin resultados, restablecimiento y apertura del detalle de un animal.

## FALTA POR AGREGAR¡¡¡¡¡
Una seccion en donde se pueda agregar un nuevo animal en adopcion en portal-fundaciones
