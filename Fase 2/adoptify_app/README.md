# Adoptify — App móvil (HU-08, HU-14 y HU-15)

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
  core/           # config.dart (URL de la API), api_client.dart (HTTP + Bearer), token_storage.dart, location_service.dart (GPS)
  features/       # una carpeta por pantalla: map, report, account, auth
    auth/         # auth_service.dart (/auth), auth_controller.dart (sesión + AuthScope), login_screen.dart
    map/          # map_service.dart (modelos + /animals, /reports), map_screen.dart
    report/       # report_screen.dart (formulario de reporte)
  shared/map/     # map_style.dart (mosaicos OSM, atribución, pines): equivalente a mapTiles.ts
  shared/widgets/ # app_shell.dart (barra inferior), adoptify_logo.dart, content_width.dart, coming_soon.dart, message_box.dart
test/             # widget tests de navegación, login, mapa y reporte (fake_api.dart simula backend y GPS)
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

**GPS en el emulador:** por defecto está en California. Para probar la búsqueda por cercanía, en el emulador
abrir los tres puntos (Extended controls) → Location, buscar Santiago y pulsar **Set location**.

## Librerías
`go_router` (rutas), `http` (API), `flutter_secure_storage` (token), `flutter_map` + `latlong2` (mapa),
`geolocator` (ubicación), `camera` (fotos de reportes, para HU-16).
Permisos declarados en `android/app/src/main/AndroidManifest.xml` (internet, ubicación, cámara)
e `ios/Runner/Info.plist` (ubicación y cámara).

## Próximas HU
- **HU-16:** subir una foto real al reportar (depende del endpoint `POST /uploads`).
