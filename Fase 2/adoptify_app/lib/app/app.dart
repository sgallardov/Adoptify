import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../core/api_client.dart';
import '../core/token_storage.dart';
import '../features/auth/auth_controller.dart';
import 'router.dart';
import 'theme.dart';

class AdoptifyApp extends StatefulWidget {
  // auth se puede inyectar en los tests para usar una API simulada
  const AdoptifyApp({super.key, this.auth});

  final AuthController? auth;

  @override
  State<AdoptifyApp> createState() => _AdoptifyAppState();
}

class _AdoptifyAppState extends State<AdoptifyApp> {
  // Un router por instancia: así cada arranque (y cada test) parte en /inicio
  late final GoRouter _router = createAppRouter();
  late final AuthController _auth =
      widget.auth ?? AuthController(ApiClient(tokenStorage: SecureTokenStorage()));

  @override
  void initState() {
    super.initState();
    _auth.restore();
  }

  @override
  void dispose() {
    _router.dispose();
    if (widget.auth == null) _auth.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AuthScope(
      controller: _auth,
      child: MaterialApp.router(
        title: 'Adoptify',
        debugShowCheckedModeBanner: false,
        theme: buildAdoptifyTheme(),
        routerConfig: _router,
      ),
    );
  }
}
