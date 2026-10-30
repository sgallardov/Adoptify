# Adoptify — Portal de fundaciones (HU-06 y HU-07)

Maqueta web con Vite, React, TypeScript, TailwindCSS y React Router.

## HU-11 — Identidad visual

Los colores y la tipografía se definen en `src/index.css` mediante `@theme` de
Tailwind v4. `Brand` comparte el logo con el favicon y `Feedback` unifica los
estados de carga, error, vacío y éxito en login, usuario y portal.
Ver [guía de identidad visual y revisión responsive](docs/identidad-visual.md).

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

## Carrusel de adopción en `/usuario`

El mapa ocupa el ancho superior y las mascotas disponibles aparecen debajo en
`AdoptionCarousel`. Las tarjetas se recorren deslizando horizontalmente, con los
botones anterior/siguiente o con las flechas del teclado al enfocar el carrusel.
No hay avance automático. Si el contenedor tiene al menos 900 px, se muestran
tres tarjetas completas dentro del mismo ancho del mapa, con solo la central
resaltada. En espacios menores se muestra una tarjeta completa. Las flechas y
el desplazamiento táctil recorren el resto; al detenerse, las tarjetas encajan
sin recortes. Al llegar al inicio o al final quedan espacios libres a los lados
para mantener centrada la tarjeta activa, sin duplicar animales. Al cambiar el
ancho de pantalla se conserva la tarjeta activa. Solo se muestran las flechas
inferiores, sin barra de desplazamiento ni contador visible.

El mapa y las tarjetas comparten los resultados y el filtro de cercanía.
Seleccionar un marcador centra su tarjeta; «Ver en el mapa» abre la ubicación
del animal y desplaza la página hasta el mapa. Los animales sin coordenadas
siguen apareciendo, con el aviso «Ubicación no registrada». Si falta la foto o
falla su carga, aparece una huella. Se conservan los estados de carga, error
con reintento y lista vacía. El carrusel es de exploración: no registra likes
ni solicitudes de adopción.

## HU-13: publicar, editar y cambiar estado

Requiere el backend de HU-12 y su migración `0004`. Esta rama incorpora
`origin/feat/hu12-fundaciones-backend`; no es necesario recrear el CRUD.
Desde `Fase 2`, ejecutar `docker compose exec backend alembic upgrade head`.
Las cuentas con rol `foundation` deben tener `users.foundation_id` asignado a
una fundación existente. La migración no asigna automáticamente las cuentas
antiguas: esa vinculación corresponde al administrador. Para cuentas nuevas,
el comando `python -m app.db.create_user` de HU-12 admite `--foundation-id`.

- En **Mis casos → Publicar animal** (`/animales/nuevo`) se abre el formulario de alta.
- En la ficha, **Editar animal** (`/animales/:id/editar`) carga los valores guardados.
- **Estado de adopción → Cambiar estado** permite Disponible, En proceso o Adoptado.
- `ReportLocationPicker` se reutiliza para marcar o arrastrar el punto; también
  se pueden introducir coordenadas con teclado. Conserva la atribución de OSM.
- La ubicación es opcional al crear. Sin ella, el animal no aparece por cercanía.
  Una ubicación existente se puede mover, pero no borrar: HU-12 rechaza
  coordenadas nulas en PATCH. Siempre se envían latitud y longitud juntas.
- Nombre, especie, tamaño y sexo son obligatorios (sexo lo exige HU-12).
  Se validan además edad (0–360 meses), energía (1–5), largos de texto y URL de foto.
  La carga de archivos no forma parte de esta HU; se admite un enlace HTTP(S).
- Los administradores indican el ID de la fundación al crear. HU-12 no incluye
  un listado de fundaciones para poblar un selector. Las cuentas de fundación
  no eligen otra fundación: el backend utiliza su asignación y verifica permisos.

Axios consume `GET /animals`, `POST /animals` y `PATCH /animals/:id`, enviando
el token de sesión. No existe GET individual en HU-12: ficha y edición buscan
el ID en la lista autorizada. Un ID ausente muestra la página de no encontrado.
Las respuestas 422 se traducen por campo al español. Los errores de conexión,
sesión o permisos se muestran sin perder los datos escritos. Guardar bloquea
envíos duplicados; cancelar no escribe en el backend. Editar datos no envía
`status`, para no sobrescribir un cambio de estado hecho desde otra sesión.

### Verificación

Desde el portal (Node 22.18+ o 24):

```powershell
npm run build
npm run lint
npm test
```

Desde `Fase 2`:

```powershell
docker compose exec backend pytest tests/test_animals_crud.py tests/test_animals.py tests/test_animals_nearby.py -q
```

Validado con 8 pruebas de validación/payload y 28 pruebas del backend. El flujo
de navegador se comprobó contra FastAPI/PostGIS reales con una fundación de
prueba: obligatorios vacíos, alta con clic en el mapa, edición de nombre/historia
y coordenadas, cambios a En proceso y Adoptado, recarga, cancelación y revisión
en móvil/escritorio. Los registros temporales se retiran después de la prueba.
