# Adoptify — App móvil (HU-08, HU-14, HU-15 y HU-16)

App Flutter para ciudadanos y adoptantes. Consume la misma API que el portal web (`Fase 2/backend`).

## Requisitos
- Flutter 3.47+ (stable). Verificar con `flutter doctor`.
- Android Studio con Android SDK, Command-line Tools y un emulador creado (Virtual Device Manager).
- Para probar sin emulador: Google Chrome (`flutter run -d chrome`).

## Iniciar
Desde esta carpeta (`Fase 2/adoptify_app`):

```powershell
flutter pub get
flutter run                 # elige el emulador o Chrome
flutter run -d chrome       # versión web
```

Con la app abierta: `r` recarga en caliente, `R` reinicia, `q` sale.

## Verificar
```powershell
flutter analyze
flutter test
```

## API
La URL se define en `lib/core/config.dart`:
- Emulador Android: `http://10.0.2.2:8000/api/v1` (10.0.2.2 es el `localhost` del computador).
- Web: `http://localhost:8000/api/v1`.
- Celular físico: pasar la IP del computador en la red local:
  `flutter run --dart-define=API_URL=http://192.168.1.10:8000/api/v1`

Android permite `http` sin cifrar (`usesCleartextTraffic`) solo para desarrollo; quitarlo al desplegar con HTTPS.

## Estructura
```text
lib/
  main.dart
  app/            # app.dart (MaterialApp.router), router.dart (go_router), theme.dart (paleta del portal)
  core/           # config.dart (URL de la API), api_client.dart (HTTP + Bearer), token_storage.dart, location_service.dart (GPS), photo_service.dart (cámara y galería)
  features/       # una carpeta por pantalla: map, report, account, auth, messages, foundation_chat, foundation_add, foundation_profile
    auth/         # auth_service.dart (/auth), auth_controller.dart (sesión + AuthScope), login_screen.dart
    map/          # map_service.dart (modelos + /animals, /reports), map_screen.dart
    report/       # report_screen.dart (formulario de reporte)
  shared/map/     # map_style.dart (mosaicos OSM, atribución, pines): equivalente a mapTiles.ts; map_controls.dart (botón redondo y tarjeta sobre el mapa)
  shared/widgets/ # app_shell.dart (barra inferior), adoptify_logo.dart, content_width.dart, coming_soon.dart, message_box.dart
test/             # widget tests de navegación, login, mapa y reporte (fake_api.dart simula backend, GPS, cámara y galería)
```

## Navegación
El login es obligatorio y único: la app abre en una pantalla de carga mientras revisa la sesión guardada y
de ahí va al login o, con sesión, a la vista que corresponde al rol (`sessionRedirect` en `router.dart`).
Cada vista tiene su barra inferior (`StatefulShellRoute`, cada pestaña conserva su historial) con el mismo
diseño (`shared/widgets/app_shell.dart`).

**Adoptante** (`adopter`): abre en el **Mapa**. Barra de izquierda a derecha:
- **Fundaciones** (`/fundaciones`): fundaciones con sus mascotas en adopción.
- **Mensajes** (`/mensajes`): conversaciones con fundaciones (HU-G2); cada chat se abre en `/mensajes/:id`.
- **Mapa** (`/mapa`).
- **Conecta** (`/conecta`): tarjetas de mascotas compatibles con "Quiero adoptar" (el match). `/match` redirige aquí.
- **Perfil** (`/cuenta`).

**Fundación** (`foundation` o `admin`): abre en **Inicio** (`/fundacion`). Barra de izquierda a derecha:
- **Inicio** (`/fundacion`): resumen, **Mis animales** (con interesados y postulaciones) y **Agregar mascota**.
- **Mapa** (`/fundacion/mapa`): el mismo mapa, con la gestión de reportes (HU-L).
- **Chat** (`/fundacion/chat`): la misma lista y chat que el adoptante (HU-G2). "Conversar" en los interesados de una mascota abre el chat y empieza el cuestionario de adopción (HU-G3); la postulación se revisa en el portal.
- **Perfil** (`/fundacion/perfil`), descrito abajo.

**Agregar mascota** (`/fundacion/agregar`, desde Inicio). La ubicación privada del animal se marca con **Buscar dirección** (`GET /geocode`, parte con el texto del lugar de resguardo), con **Usar mi ubicación actual** o tocando el mapa; nunca se escriben coordenadas (`AnimalLocationPicker`). La comuna pública se completa sola con la dirección elegida o se escribe con sugerencias (`CommuneField`, `GET /animals/communes`).
- **Perfil de la fundación** (`/fundacion/perfil`): foto de perfil (cámara o galería, se sube con `POST /uploads`) y descripción **obligatoria** de al menos 20 caracteres, que se guardan con `PUT /foundations/me` y los adoptantes ven al tocar el pin de la fundación en el mapa. También permite cerrar sesión y cambiar entre modo claro y oscuro con una luna / sol arriba a la derecha (el mismo `ThemeController` que la tarjeta Apariencia del Perfil de adoptante).

Cada rol solo ve su vista: una fundación que intente abrir el mapa vuelve a la suya, y un adoptante que
intente abrir `/fundacion/...` vuelve al mapa. Un adoptante no ve ninguna pista de que existen cuentas de fundación.

`/login`, `/reportar` y los detalles se abren a pantalla completa, con flecha para volver. Reportar se abre con el
botón rojo "Reportar mascota" del mapa.

## Fotos
Toda foto que viene de la red se muestra con `shared/widgets/network_photo.dart` (`NetworkPhoto`, también dentro de `AnimalPhoto`):
- **Caché en disco** (`cached_network_image`): una foto ya vista no se vuelve a descargar, ni al cerrar la app. La clave es la ruta sin el `token` del enlace firmado, que cambia aunque la foto sea la misma.
- **Tamaño justo:** se decodifica al ancho en que se muestra (`pixelsWide`); las de Unsplash se piden ya achicadas (`?w=`).
- **Indicador de carga** mientras baja, y la huella si falla.
- En las pruebas no hay disco ni plugins: `test/flutter_test_config.dart` pone `useDiskImageCache = false` y se usa `Image.network`.

## Diseño
Todo el estilo sale de `lib/app/theme.dart` (misma paleta que el portal):
- `AdoptifyColors`: colores. `AdoptifySpacing` (4/8/12/16/24/32) y `AdoptifyRadius` (8/12/16/24): medidas.
- `AdoptifyShadows.soft`: la única sombra, para tarjetas, fichas y la barra.
- Escala tipográfica en `textTheme` (`headlineSmall` títulos de página, `titleLarge` headers, `titleMedium`
  títulos de tarjeta, `titleSmall` etiquetas, `bodyMedium` texto, `bodySmall` notas). No usar tamaños sueltos.
- Botones con estados hover, focus (contorno naranjo oscuro) y presionado. Títulos y logo centrados.
- En pantallas anchas el contenido se limita a 640 px y se centra (`shared/widgets/content_width.dart`).

## Inicio de sesión (HU-14)
Mismo formato y mismas cuentas que el login del portal web:
- Un solo formulario, sin pestañas: no manda `account_type` y el backend decide el rol; cualquiera puede registrarse como adoptante (las cuentas de fundación las crea el equipo).
- Consume `POST /auth/login`, `POST /auth/register` y `GET /auth/me`; los mensajes de error son los del backend
  y siguen las mismas reglas que `errorMessage()` del portal.
- El token se guarda cifrado con `flutter_secure_storage` y `ApiClient` lo envía como `Authorization: Bearer` en cada petición.
- Al abrir la app se recupera la sesión con `GET /auth/me`. Si la API responde 401 (token vencido), se cierra la sesión;
  sin conexión el token se conserva para el próximo intento.
- **Verificación en dos pasos (HU-I):** si la cuenta la tiene activa, tras la contraseña la tarjeta pasa a
  "Revisa tu correo": campo de 6 dígitos (teclado numérico y autocompletado del código), **Reenviar código** con
  cuenta regresiva de 60 s y **Volver**. Un código incorrecto muestra los intentos que quedan; vencido o agotado,
  vuelve a pedir la contraseña. Se activa en el Perfil (adoptante y fundación) con la tarjeta
  **Verificación en dos pasos** (`features/auth/two_factor_card.dart`): llega un código al correo y queda activa al
  ingresarlo; desactivarla pide la contraseña. Piezas compartidas en `features/auth/verification_code.dart`.
- La pestaña **Perfil** (`/cuenta`) muestra nombre, rol, correo y RUT, y permite cerrar sesión. **Editar nombre**
  (`PATCH /auth/me`, mismas reglas del registro) y **Cambiar contraseña** (`POST /auth/change-password`, pide la actual
  y repetir la nueva) se abren en diálogos (`features/account/account_dialogs.dart`). Una contraseña actual incorrecta
  responde `400`: el diálogo muestra el error y la sesión sigue abierta. El correo y el RUT no se editan.
  "Activar" la verificación en dos pasos es un botón secundario: la acción principal del Perfil es **Quiero adoptar**.

Para probar con el backend local (desde `Fase 2`): `docker compose up -d` y `python -m app.db.seed`;
cuenta de prueba `matias.adopter@gmail.com` / `Adoptante2026`.

## Mapa y reportes (HU-15)
Mismo proveedor (OpenStreetMap, con `flutter_map`) y mismos colores de pines que el portal:
naranjo = mascota en adopción, rojo = mascota reportada, azul = tu ubicación. Los pines de mascotas llevan un
corazón blanco y borde blanco, y el mapa base va un poco menos saturado (60 %) en modo claro: así no se confunden con
los íconos naranjos y rojos que trae OpenStreetMap.
- **Mapa** (`/mapa`): a pantalla completa. Sin ubicación muestra todas las mascotas disponibles (`GET /animals`)
  y los reportes a 100 km de Santiago. Encima flotan:
  - el **buscador**, que filtra las mascotas cargadas por nombre, especie o fundación (sin distinguir tildes).
    Al tocar un resultado (o con Enter, el primero) se cierra la lista, se limpia el buscador, el mapa se centra en
    la mascota y se abre su ficha; tocar fuera del buscador y de la lista la cierra. La lista va dentro de un
    `TextFieldTapRegion`: en web, presionar el mouse sobre un resultado ya no le quita el foco al campo (lo que
    cerraba la lista antes de que llegara el clic). Debajo, con "Usar mi ubicación", el radio (5 a 100 km) y "Ver todas";
  - el botón de **avisos** (HU-H): una píldora chica arriba a la derecha con la huella y el número de mascotas
    reportadas a menos de 5 km de tu ubicación (`GET /reports/nearby?radius_km=5`). Al tocarla se despliega una
    **lista** (alto máximo 40% de la pantalla) con foto, resumen, estado y distancia de cada aviso; tocar una fila
    abre el detalle del reporte y la x o la píldora la cierran. La ubicación se pide sola al abrir el mapa y,
    mientras espera, la píldora dice "Buscando tu ubicación…". Sin permiso, o si el navegador o el teléfono no
    responden la pregunta (`permissionTimeout`, 15 s; tope total `locationTimeout`, 20 s, en `core/location_service.dart`),
    dice "Activar ubicación" y al tocarla la pide de nuevo; el mapa sigue funcionando y encuadra todo. Si falla la
    consulta de avisos, dice "Reintentar". Las pantallas piden la ubicación con `currentLocation()`, que aplica el tope.
    *Decisión de diseño:* se eligió la lista desplegable (frente a una pantalla de avisos con filtros o a enfocar
    el mapa) porque lleva del conteo al aviso en un toque, sin pantalla nueva y ocupando menos mapa que la
    tarjeta anterior. El radio queda fijo en 5 km (`_alertsRadiusKm`); el mapa ya tiene su propio selector;
  - **Reportes**: el pin cambia según la especie: perro y gato son un círculo rojo con una patita de perro o una manito de gato en blanco; "otro" es el punto rojo (`MapPins.reportFor`);
  - **Veterinarias**: gota roja con una cruz roja sobre blanco, del mismo tamaño que la de fundaciones (`GET /veterinary-clinics`). Solo se muestran con el mapa acercado (zoom 13 o más), porque son cientos. Su ficha trae nombre, dirección, "Urgencias 24 h" u horario, **Cómo llegar** (ruta en Google Maps) y **Llamar** si hay teléfono, con `url_launcher`;
  - **Fundaciones**: pin fijo calipso en forma de gota con una huella en la sede de cada fundación con ubicación (no depende del radio). Al tocarlo aparece una ficha con su foto de perfil, nombre, comuna y descripción; al tocar la ficha se abre `/fundaciones/:id`, la misma vista que desde la pestaña Fundaciones;
  - **Leyenda** (botón de información, arriba de Capas): qué significa cada pin, con los mismos dibujos del mapa;
  - **Capas**: opción de mostrar u ocultar mascotas, reportes, fundaciones y veterinarias;
  - **Al abrir el mapa** (por ejemplo, después de iniciar sesión) se pide la ubicación y la cámara se centra en ti a nivel de
    barrio (zoom 14), con tu punto azul y sin filtrar por radio. Mientras llega no se encuadra todo el país (evita el salto);
    sin permiso, se encuadran las mascotas y reportes. Si mueves el mapa con el dedo, deja de reencuadrarse solo;
  - **Usar mi ubicación**: centra el mapa en ti con zoom de calles (16) y busca con `GET /animals/nearby` y
    `GET /reports/nearby`; al cambiar el radio se encuadran los resultados. Mientras busca, su tooltip dice
    "Buscando tu ubicación…" y nunca queda cargando más que el tope de tiempo;
  - el botón **Reportar mascota**. Tocar un pin abre su ficha sobre ese botón. Al publicar, el mapa recibe el id del
    reporte nuevo, lo marca aunque quede fuera del radio elegido (si `/reports/nearby` no lo trae, lo pide con
    `GET /reports/{id}`), abre su ficha y se mueve hasta él;
  - la atribución "© OpenStreetMap" (obligatoria por la licencia de OSM), mínima, bajo el botón de reportar.
- `OsmTileLayer` (`shared/map/map_style.dart`) crea la capa de mosaicos recién cuando el mapa tiene tamaño y
  lleva un momento quieto. Al abrir, el mapa nace sin tamaño y se encuadra en los pines; en ese primer segundo
  flutter_map creaba y descartaba tandas de mosaicos y algunos quedaban cargando hasta mover el mapa. También
  usa un solo proveedor de mosaicos y reintenta si alguno falla por la red.
- **Reportar** (`/reportar`): requiere sesión. Primero se abre un **mapa a pantalla completa** con tu ubicación
  ya marcada (si diste permiso); mientras la busca, el aviso de arriba dice "Buscando tu ubicación…" y se puede
  marcar a mano igual. Si no hay respuesta en 20 s, deja de esperar. Tocar el mapa mueve el punto y **Confirmar ubicación** pasa al formulario. Ahí el
  paso 1 muestra una vista previa con **Cambiar ubicación** (el botón atrás también vuelve al mapa, sin perder lo
  escrito). Luego, igual que la web: **¿Cómo es?** (tipo y tamaño con chips, color, peso aproximado, características), **¿Cómo está?** (estado y
  comportamiento opcional; en ambos se marcan varias opciones), **Comentarios** y **Foto**. Cada campo muestra su error; el mensaje dice qué campos revisar y la pantalla baja al primero.
  Se envía con `POST /reports`; al terminar vuelve al mapa con el nuevo pin, cuya ficha muestra los datos.
  Los reportes creados en la app se ven en la web y viceversa (es la misma API).
- La API ya entrega `latitude` y `longitude`: no hay que decodificar WKB.

## Modo oscuro
En **Perfil → Apariencia** se elige **Sistema** (por defecto, sigue al teléfono), **Claro** u **Oscuro**.
La elección se guarda en el dispositivo (`shared_preferences`) y está disponible con o sin sesión.
- `app/theme.dart`: `AdoptifyColors` es una extensión del tema con versión `light` y `dark`. Los widgets la leen
  con `context.colors` (nunca colores fijos), así cambian solos con el modo.
- `app/theme_controller.dart`: `ThemeController` + `ThemeScope`, mismo patrón que `AuthController` y `AuthScope`.
- Mapas: en modo oscuro se usan los mismos mosaicos de OSM con los colores invertidos (`darkModeTileBuilder`).
  Los pines mantienen sus colores.

## Fundaciones
`/fundaciones` lista las fundaciones (`GET /foundations`) con su comuna, descripción, contacto (teléfono,
correo y dirección, seleccionables) y una fila con sus mascotas en adopción. Se actualiza deslizando hacia abajo.
Con hasta 2 mascotas la fila queda quieta; con más se desliza como carrusel (se ven dos fotos y media, para que se
note que hay más). Tocar una foto abre el perfil de la fundación y, encima, la ficha de esa mascota: al volver desde
la ficha se llega al perfil de la fundación.
Si el teléfono entrega tu ubicación, las pide con `lat`/`lng` y quedan de la más cercana a la más lejana, con la distancia en cada tarjeta ("a 4,2 km"); sin permiso, quedan por nombre y sin mostrar errores.
La versión web de esta vista queda pendiente.

## Mensajes (HU-G2)
La pestaña **Mensajes** del adoptante (`features/messages/`) lista las conversaciones que le abrieron las
fundaciones (`GET /conversations`), con el último mensaje y la hora. El adoptante no abre conversaciones nuevas:
una fundación le escribe desde el portal (Interesados u Hogares temporales) y desde ahí responde. Al tocar una se abre
`/mensajes/:id` a pantalla completa (`chat_screen.dart`): sus mensajes a la derecha y los de la fundación a la
izquierda, con un campo de hasta 1000 caracteres; no se envían mensajes vacíos.

Sin WebSockets, igual que el portal: la lista se consulta cada 15 s mientras la pestaña está a la vista y el chat
abierto cada 10 s, pidiendo solo lo nuevo (`after_id`). Así lo que escribe la fundación aparece en 10 s o menos. La
lista también se actualiza deslizando hacia abajo. Un fallo del sondeo no borra lo que ya se ve.

## Carruseles
Las listas horizontales (por ejemplo, "Historias que buscan hogar" y las fotos de cada fundación) usan
`shared/widgets/horizontal_carousel.dart`: en web y escritorio se arrastran con el mouse y el trackpad
(`AdoptifyScrollBehavior`, registrado en `MaterialApp.scrollBehavior`), la rueda vertical del mouse las mueve hacia el
lado y, desde 600 px de ancho, tienen flechas **Anterior** y **Siguiente**. En el teléfono se deslizan con el dedo, igual que antes.

## Hogar temporal (HU-B)
En el Perfil del adoptante, la tarjeta **Hogar temporal** invita a postular o muestra el estado de su postulación
(En revisión, Aprobada o No aprobada) con un resumen. Al tocarla se abre `/hogar-temporal` a pantalla completa
(`features/foster/`): nombre y correo vienen de la cuenta; se piden teléfono, dirección (privada, solo la ven las
fundaciones), tipo de mascota (perros, gatos o ambos), tamaños, cuántos a la vez, días máximos, espacio y
disponibilidad, todos obligatorios. Junto al botón se listan los campos pendientes, porque los errores de arriba
pueden quedar fuera de la pantalla. Mientras está en revisión se edita; ya revisada queda solo para leer y se puede
retirar. Usa `GET/POST/PUT/DELETE /foster-applications`.

## Foto de la mascota (HU-16)
En "Reportar mascota", la sección **5. Foto (opcional)** tiene dos botones:
**Tomar foto** (cámara) y **Galería**. Usa `image_picker`.
- La foto se achica a 1600 px como máximo, en calidad 85, para no pasar los 5 MB del backend.
- Se sube apenas se elige (`POST /uploads`, multipart) para avisar enseguida si no sirve.
  Mientras sube, "Enviar reporte" queda deshabilitado. "Quitar foto" la descarta.
- El reporte se envía con la URL devuelta en `photo_url`, y la ficha del reporte en el mapa muestra la foto.
- `mediaUrl()` (`core/config.dart`) pide las fotos de `/uploads/` al mismo servidor que la API. El backend
  arma la URL con la dirección desde la que se subió, así que una foto subida desde el portal (`localhost`)
  no abriría en el emulador (`10.0.2.2`).
- En las pruebas, `PhotoService.instance` se reemplaza por `FakePhotos` (igual que el GPS).

**Cámara en el emulador:** la cámara trasera del emulador muestra una escena virtual; sirve para probar el flujo.
Para la galería, arrastrar una imagen a la ventana del emulador la guarda en Descargas.

**GPS en el emulador:** por defecto está en California. Para probar la búsqueda por cercanía, en el emulador
abrir los tres puntos (Extended controls) → Location, buscar Santiago y pulsar **Set location**.

## Librerías
`go_router` (rutas), `http` (API), `flutter_secure_storage` (token), `flutter_map` + `latlong2` (mapa),
`geolocator` (ubicación), `image_picker` (cámara y galería, HU-16), `shared_preferences` (modo oscuro), `camera` (sin uso por ahora).
Permisos declarados en `android/app/src/main/AndroidManifest.xml` (internet, ubicación, cámara)
e `ios/Runner/Info.plist` (ubicación, cámara y fotos).
