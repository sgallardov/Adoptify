# Adoptify — App móvil (HU-08)

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
  core/           # config.dart (URL de la API)
  features/       # una carpeta por pantalla: home, map, report, account, auth
  shared/widgets/ # app_shell.dart (barra inferior), coming_soon.dart
test/             # widget tests de navegación
```

## Navegación
Barra inferior con cuatro pestañas (`StatefulShellRoute`, cada una conserva su historial):
`/inicio`, `/mapa`, `/reportar`, `/cuenta`. `/login` se abre a pantalla completa.

## Librerías
`go_router` (rutas), `http` (API), `geolocator` (ubicación), `camera` (fotos de reportes).
Permisos declarados en `android/app/src/main/AndroidManifest.xml` (internet, ubicación, cámara)
e `ios/Runner/Info.plist` (ubicación y cámara).

## Próximas HU
- **HU-14:** login y registro con la cuenta del portal (token en `flutter_secure_storage`).
- **HU-15:** mapa con `flutter_map` + OpenStreetMap y reporte con GPS.
