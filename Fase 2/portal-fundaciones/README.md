# Adoptify — Portal de fundaciones (HU-06 y HU-07)

Maqueta web con Vite, React, TypeScript, TailwindCSS y React Router.

## HU-11 — Identidad visual

Los colores y la tipografía se definen en `src/index.css` mediante `@theme` de
Tailwind v4. `Brand` comparte el logo con el favicon y `Feedback` unifica los
estados de carga, error, vacío y éxito en login y portal.
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

- `/login`: inicio de sesión de fundaciones (sin registro). La vista de usuario (mapa, reportes, adopción) vive solo en la app móvil.
- Las rutas siguientes requieren una cuenta `foundation` o `admin`; sin sesión redirigen a `/login`.
- `/`: bienvenida, estadísticas calculadas desde la API y animales disponibles.
- `/animales` (Mis casos): tarjetas de PostgreSQL, búsqueda por nombre y filtros por especie y estado.
- `/animales/:id`: ficha de cada animal; IDs desconocidos muestran página no encontrada.
- `/fundacion`: perfil de la organización de ejemplo y sección **Socios** (HU-F): listar, agregar, editar, borrar y marcar cuáles se muestran en la ficha pública "Nuestros socios" (`services/members.ts`, `components/MembersSection.tsx`). El aporte es privado y no hay cobros; un admin solo ve el listado.
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
Si la cuenta tiene la verificación en dos pasos activa (HU-I, se activa desde la app), el login pasa a
"Revisa tu correo": código de 6 dígitos (`POST /auth/verify-code`), **Reenviar código** cada 60 s
(`POST /auth/resend-code`) y **Volver**. Las reglas del campo están en `src/services/verificationCode.ts`.
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
- Nombre, especie, tamaño, sexo, **foto del animal** y lugar de resguardo (tipo y texto) son obligatorios al publicar. El formulario y la API rechazan una publicación sin alguno de ellos.
  Se validan además edad (0–360 meses), energía (1–5), largos de texto y URL de foto.
  La foto se sube desde el computador (ver HU-16).
- Los administradores indican el ID de la fundación al crear. HU-12 no incluye
  un listado de fundaciones para poblar un selector. Las cuentas de fundación
  no eligen otra fundación: el backend utiliza su asignación y verifica permisos.

El portal consulta `GET /animals/management` y `GET /animals/management/:id`
con sesión autorizada. Crear y editar siguen usando `POST /animals` y
`PATCH /animals/:id`. Un ID ajeno devuelve 403 y uno inexistente, 404.
Las respuestas 422 se traducen por campo al español. Los errores de conexión,
sesión o permisos se muestran sin perder los datos escritos. Guardar bloquea
envíos duplicados; cancelar no escribe en el backend. Editar datos no envía
`status`, para no sobrescribir un cambio de estado hecho desde otra sesión.

## Hogares temporales (HU-B)
`/hogares-temporales` (ítem del menú) lista las postulaciones de adoptantes que ofrecen su hogar
(`GET /foster-applications`): nombre, correo y teléfono enlazados, dirección privada, qué pueden recibir
(especie, tamaños, cuántos a la vez, días máximos), espacio y disponibilidad. Filtros Pendientes, Aprobadas,
No aprobadas y Todas, con conteo. **Aprobar** y **Rechazar** en las pendientes; **Volver a pendiente** solo en las que
decidió la propia fundación (`PATCH /foster-applications/{id}`). El estado es compartido entre fundaciones: si otra ya
decidió, se muestra quién y no hay botones. "Abrir chat" espera HU-G2 (`CHAT_ENABLED` en
`pages/FosterApplications.tsx`). Textos en `services/fosterLabels.ts`.

## Modo oscuro

El botón de luna/sol (`ThemeToggle`) cambia entre modo claro y oscuro. Está en la cabecera del portal de
fundaciones, en la de adoptantes (`AppHeader`) y en el login.

- Sin elección guardada se sigue la apariencia del sistema. La elección queda en `localStorage`
  (`adoptify_theme`) y la aplica `hooks/useTheme.ts` como `data-theme` en `<html>`. Un script en `index.html`
  hace lo mismo antes de pintar, para que la página no parpadee en blanco.
- `index.css` redefine las mismas variables de color en `:root[data-theme="dark"]`: las clases de Tailwind
  no cambian. Para texto sobre fondos de color (botones, pines, banners) se usa `text-on-accent`, que es blanco
  en ambos modos; `text-surface` ya no sirve para eso porque en oscuro la superficie es oscura.
- Mapas: los mosaicos de OSM se invierten con un filtro CSS y los popups usan los colores del tema.

## HU-16: subir fotos

`PhotoPicker` (`components/PhotoPicker.tsx`) reemplaza el campo de enlace de la foto en
**Publicar / Editar animal** y agrega **Foto del animal***. No se puede publicar un animal sin una foto; las fichas históricas sin foto se pueden editar para completarla.

- Botón **Subir foto**: abre el selector de archivos del computador o recibe una imagen arrastrada.
  En el celular, el selector del navegador ofrece también la cámara y la galería.
- Revisa antes de subir que sea JPG o PNG de hasta 5 MB (`services/photo.ts`); el backend vuelve a
  validar por el contenido. Sube apenas se elige (`POST /uploads`, `services/uploads.ts`) y guarda la
  URL devuelta en `photo_url`. Mientras sube, guardar o enviar queda deshabilitado.
- Con foto: vista previa, **Cambiar foto** y **Quitar**. Los errores del backend (415, 413) se muestran en español.
- `mediaUrl()` pide las fotos de `/uploads/` al mismo servidor que la API: una foto subida desde el
  emulador (`10.0.2.2`) se ve igual en el navegador.

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
