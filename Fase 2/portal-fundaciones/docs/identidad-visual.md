# HU-11 — Identidad visual de Adoptify

## Fuente única de diseño

`src/index.css` contiene el `@theme` de Tailwind v4. No definir colores literales
ni familias tipográficas dentro de las vistas.

| Tokens | Uso |
| --- | --- |
| `brand-*` | Identidad naranja, acciones principales, enlaces y selección |
| `base-*`, `surface` | Fondo cálido, superficies, texto y bordes |
| `forest` | Panel destacado de bienvenida |
| `success-*` | Confirmación y animales disponibles |
| `warning-*` | Adopción en proceso |
| `danger-*` | Errores y reportes de perros |
| `info-*` | Ubicación propia y estados informativos |
| `font-sans`, `font-brand` | Fuente local compartida; marca hereda la misma familia |

Las vistas consumen clases como `bg-brand-600`, `text-base-600` y `bg-forest`.
El naranja de las acciones usa un tono más oscuro para que el texto blanco sea
legible. Los controles conservan indicadores de foco visibles y se respeta
`prefers-reduced-motion`. Los mapas Leaflet también heredan la tipografía.

## Logo y favicon

`Brand.tsx` reúne el símbolo y el nombre. Se usa en login, cabecera de usuario,
formulario de reportes y sidebar/cabecera móvil del portal. `AppHeader.tsx`
comparte la distribución de las cabeceras de usuario y reportes.

El símbolo es `public/brand-mark.svg`, también referenciado por `index.html`
como favicon. El SVG conserva sus colores gráficos y el `theme-color` del HTML
coincide con `brand-600`. Si se cambia la identidad de marca, actualizar estos
dos recursos gráficos junto al token; las páginas no necesitan modificaciones.
En pantallas pequeñas, las cabeceras muestran el símbolo para dejar espacio
a las acciones. Su nombre accesible sigue siendo «Adoptify, inicio».

## Estados compartidos

`Feedback.tsx` define `loading`, `error`, `empty` y `success`, con variantes
de panel y aviso compacto. Contiene icono, título, descripción opcional y
acción opcional. Las acciones de recuperación usan `button-primary`.

- Errores usan `role="alert"`; el resto, `role="status"`.
- `AnimalsState.tsx` adapta carga/error de animales al componente común.
- Login y sesión: carga y error de acceso.
- Usuario: carga/error/lista vacía, error de ubicación y confirmación de reporte.
- Portal: carga/error/lista vacía, búsqueda sin resultados y página no encontrada.
- Formulario de reportes: error y estado de envío.

No se modifican endpoints, autenticación, datos, geolocalización ni permisos.

## Verificación de HU-11

Revisión manual con API simulada local, sin modificar la base de datos ni cuentas.
La API de prueba no forma parte de la aplicación ni queda configurada en `.env`.

| Vista | 320 px | 390 px | 768 px | 1440 px |
| --- | --- | --- | --- | --- |
| `/login` | Sin desbordamiento | Sin desbordamiento | Sin desbordamiento | Sin desbordamiento |
| `/usuario` | Sin desbordamiento | Sin desbordamiento | Sin desbordamiento | Sin desbordamiento |
| Portal `/` | Sin desbordamiento | Sin desbordamiento | Sin desbordamiento | Sin desbordamiento |

Se comprobó igualdad de fuente, fondo y origen del logo mediante los estilos
calculados del navegador. Se revisó login con error y carga, lista vacía de
usuario, error del portal con reintento, y lista vacía de Mis casos.
Compilar con `npm run build` antes de integrar los cambios.
