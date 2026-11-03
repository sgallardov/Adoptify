import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
import '../core/token_storage.dart';
import '../features/auth/auth_controller.dart';
import 'router.dart';
import 'theme.dart';
import 'theme_controller.dart';

class AdoptifyApp extends StatefulWidget {
  // auth y theme se pueden inyectar en los tests
  const AdoptifyApp({super.key, this.auth, this.theme});

  final AuthController? auth;
  final ThemeController? theme;

  @override
  State<AdoptifyApp> createState() => _AdoptifyAppState();
}

class _AdoptifyAppState extends State<AdoptifyApp> {
  // Un router por instancia: así cada arranque (y cada test) parte revisando la sesión
  late final GoRouter _router = createAppRouter(_auth);
  late final AuthController _auth =
      widget.auth ?? AuthController(ApiClient(tokenStorage: SecureTokenStorage()));
  late final ThemeController _theme = widget.theme ?? ThemeController();

  @override
  void initState() {
    super.initState();
    _auth.restore();
    _theme.restore();
  }

  @override
  void dispose() {
    _router.dispose();
    if (widget.auth == null) _auth.dispose();
    if (widget.theme == null) _theme.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      controller: _auth,
      child: ThemeScope(
        controller: _theme,
        child: ListenableBuilder(
          listenable: _theme,
          builder: (context, _) => MaterialApp.router(
            title: 'Adoptify',
            debugShowCheckedModeBanner: false,
            theme: buildAdoptifyTheme(),
            darkTheme: buildAdoptifyTheme(Brightness.dark),
            themeMode: _theme.mode,
            routerConfig: _router,
          ),
        ),
      ),
    );
  }
}
