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
  features/       # una carpeta por pantalla: map, report, account, auth
    auth/         # auth_service.dart (/auth), auth_controller.dart (sesión + AuthScope), login_screen.dart
    map/          # map_service.dart (modelos + /animals, /reports), map_screen.dart
    report/       # report_screen.dart (formulario de reporte)
  shared/map/     # map_style.dart (mosaicos OSM, atribución, pines): equivalente a mapTiles.ts
  shared/widgets/ # app_shell.dart (barra inferior), adoptify_logo.dart, content_width.dart, coming_soon.dart, message_box.dart
test/             # widget tests de navegación, login, mapa y reporte (fake_api.dart simula backend, GPS, cámara y galería)
```

## Navegación
La app abre en el **Mapa** (también al iniciar sesión). Barra inferior con 3 elementos
(`StatefulShellRoute`, cada uno conserva su historial), de izquierda a derecha:
- **Reportar mascota** (`/reportar`): acción principal, botón rojo destacado.
- **Mapa** (`/mapa`).
- **Perfil** (`/cuenta`).

`/login` se abre a pantalla completa.

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
- Pestañas **Usuario** y **Fundación** (`account_type` `user` / `foundation`); solo Usuario permite registrarse.
- Consume `POST /auth/login`, `POST /auth/register` y `GET /auth/me`; los mensajes de error son los del backend
  y siguen las mismas reglas que `errorMessage()` del portal.
- El token se guarda cifrado con `flutter_secure_storage` y `ApiClient` lo envía como `Authorization: Bearer` en cada petición.
- Al abrir la app se recupera la sesión con `GET /auth/me`. Si la API responde 401 (token vencido), se cierra la sesión;
  sin conexión el token se conserva para el próximo intento.
- La pestaña **Cuenta** muestra el perfil (nombre, rol, correo, RUT) y permite cerrar sesión.

Para probar con el backend local (desde `Fase 2`): `docker compose up -d` y `python -m app.db.seed`;
cuenta de prueba `matias.adopter@gmail.com` / `Adoptante2026`.

## Mapa y reportes (HU-15)
Mismo proveedor (OpenStreetMap, con `flutter_map`) y mismos colores de pines que el portal:
naranjo = mascota en adopción, rojo = perro reportado, azul = tu ubicación.
- **Mapa** (`/mapa`): sin ubicación muestra todas las mascotas disponibles (`GET /animals`) y los reportes
  a 100 km de Santiago. Con "Usar mi ubicación" busca con `GET /animals/nearby` y `GET /reports/nearby`
  en el radio elegido (5 a 100 km). Tocar un pin o una tarjeta abre su ficha.
- **Reportar** (`/reportar`): requiere sesión. Se marca el punto tocando el mapa o con el GPS
  y se envía con `POST /reports`; al terminar vuelve al mapa con el nuevo pin.
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

## Foto del perro (HU-16)
En "Reportar mascota", la sección **3. Foto del perro (opcional)** tiene dos botones:
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
