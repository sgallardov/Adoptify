import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api_client.dart';
import '../../features/auth/auth_controller.dart';

// Pantalla de detalle que llega con el objeto ya cargado (`initial`) o, al recargar la página o abrir el
// enlace directo, lo pide por id. Si no existe o falla, muestra el motivo y un botón para volver.
class DetailLoader<T> extends StatefulWidget {
  const DetailLoader({
    super.key,
    required this.initial,
    required this.load,
    required this.builder,
  });

  final T? initial;
  final Future<T> Function(ApiClient api) load;
  final Widget Function(BuildContext context, T data) builder;

  @override
  State<DetailLoader<T>> createState() => _DetailLoaderState<T>();
}

class _DetailLoaderState<T> extends State<DetailLoader<T>> {
  T? _data;
  Object? _error;
  bool _started = false;

  @override
  void initState() {
    super.initState();
    _data = widget.initial;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_started || _data != null) return;
    _started = true;
    _fetch();
  }

  Future<void> _fetch() async {
    setState(() => _error = null);
    try {
      final data = await widget.load(AuthScope.of(context).api);
      if (mounted) setState(() => _data = data);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final data = _data;
    if (data != null) return widget.builder(context, data);
    final error = _error;
    return Scaffold(
      appBar: AppBar(),
      body: Center(
        child: error == null
            ? const CircularProgressIndicator()
            : Padding(
                padding: const EdgeInsets.all(AdoptifySpacing.lg),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      error is ApiException && error.statusCode == 404
                          ? 'No encontramos lo que buscas. Puede que ya no exista.'
                          : errorMessage(
                              error,
                              'No pudimos cargar esta pantalla.',
                            ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: AdoptifySpacing.md),
                    FilledButton(
                      onPressed: () => context.canPop()
                          ? context.pop()
                          : context.go('/mapa'),
                      child: const Text('Volver'),
                    ),
                  ],
                ),
              ),
      ),
    );
  }
}
