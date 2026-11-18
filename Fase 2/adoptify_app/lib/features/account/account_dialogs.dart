import 'dart:convert';

import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/api_client.dart';
import '../auth/auth_controller.dart';

// Mismas reglas que el registro y la API: nombre de 2 a 255 caracteres; contraseña de 8 caracteres y máx. 72 bytes
const _minName = 2;
const _maxName = 255;
const _minPassword = 8;
const _maxPasswordBytes = 72;

String? validateFullName(String? value) {
  final clean = (value ?? '').trim();
  if (clean.length < _minName) return 'El nombre debe tener al menos $_minName caracteres.';
  if (clean.length > _maxName) return 'El nombre puede tener como máximo $_maxName caracteres.';
  return null;
}

String? validateNewPassword(String? value) {
  final password = value ?? '';
  if (password.length < _minPassword) return 'La contraseña debe tener al menos $_minPassword caracteres.';
  if (utf8.encode(password).length > _maxPasswordBytes) {
    return 'La contraseña es demasiado larga (las letras con tilde o ñ cuentan doble).';
  }
  return null;
}

// Editar el nombre completo. Al guardar, el Perfil muestra el nombre nuevo.
Future<void> showEditNameDialog(BuildContext context) async {
  final saved = await showDialog<bool>(context: context, builder: (_) => const _EditNameDialog());
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Guardamos tu nombre.')));
  }
}

// Cambiar la contraseña pidiendo la actual. La sesión sigue abierta después del cambio.
Future<void> showChangePasswordDialog(BuildContext context) async {
  final saved = await showDialog<bool>(context: context, builder: (_) => const _ChangePasswordDialog());
  if (saved == true && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Cambiamos tu contraseña.')));
  }
}

class _EditNameDialog extends StatefulWidget {
  const _EditNameDialog();

  @override
  State<_EditNameDialog> createState() => _EditNameDialogState();
}

class _EditNameDialogState extends State<_EditNameDialog> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: AuthScope.of(context).user?.fullName ?? '');
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    final auth = AuthScope.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      auth.updateUser(await auth.service.updateProfile(_name.text.trim()));
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = errorMessage(error, 'No pudimos guardar tu nombre. Inténtalo nuevamente.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Editar nombre'),
      content: Form(
        key: _form,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextFormField(
              key: const ValueKey('edit-full-name'),
              controller: _name,
              autofocus: true,
              enabled: !_saving,
              maxLength: _maxName,
              textCapitalization: TextCapitalization.words,
              decoration: const InputDecoration(labelText: 'Nombre completo', counterText: ''),
              validator: validateFullName,
              onFieldSubmitted: (_) => _save(),
            ),
            if (_error != null) _DialogError(message: _error!),
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Guardando…' : 'Guardar')),
      ],
    );
  }
}

class _ChangePasswordDialog extends StatefulWidget {
  const _ChangePasswordDialog();

  @override
  State<_ChangePasswordDialog> createState() => _ChangePasswordDialogState();
}

class _ChangePasswordDialogState extends State<_ChangePasswordDialog> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _new = TextEditingController();
  final _repeat = TextEditingController();
  bool _visible = false;
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _new.dispose();
    _repeat.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (!_form.currentState!.validate() || _saving) return;
    final auth = AuthScope.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await auth.service.changePassword(_current.text, _new.text);
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      // Una contraseña actual mal escrita llega como 400: la sesión no se cierra y se puede reintentar
      setState(() {
        _saving = false;
        _error = errorMessage(error, 'No pudimos cambiar tu contraseña. Inténtalo nuevamente.');
      });
    }
  }

  InputDecoration _decoration(String label) => InputDecoration(
        labelText: label,
        suffixIcon: IconButton(
          tooltip: _visible ? 'Ocultar contraseñas' : 'Mostrar contraseñas',
          icon: Icon(_visible ? Icons.visibility_off_outlined : Icons.visibility_outlined),
          onPressed: () => setState(() => _visible = !_visible),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Cambiar contraseña'),
      content: Form(
        key: _form,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TextFormField(
                key: const ValueKey('current-password'),
                controller: _current,
                autofocus: true,
                enabled: !_saving,
                obscureText: !_visible,
                autofillHints: const [AutofillHints.password],
                decoration: _decoration('Contraseña actual'),
                validator: (value) => (value ?? '').isEmpty ? 'Escribe tu contraseña actual.' : null,
              ),
              const SizedBox(height: AdoptifySpacing.md),
              TextFormField(
                key: const ValueKey('new-password'),
                controller: _new,
                enabled: !_saving,
                obscureText: !_visible,
                autofillHints: const [AutofillHints.newPassword],
                decoration: _decoration('Nueva contraseña'),
                validator: validateNewPassword,
              ),
              const SizedBox(height: AdoptifySpacing.md),
              TextFormField(
                key: const ValueKey('repeat-password'),
                controller: _repeat,
                enabled: !_saving,
                obscureText: !_visible,
                decoration: _decoration('Repite la nueva contraseña'),
                validator: (value) => value == _new.text ? null : 'Las contraseñas no coinciden.',
                onFieldSubmitted: (_) => _save(),
              ),
              if (_error != null) _DialogError(message: _error!),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(onPressed: _saving ? null : () => Navigator.of(context).pop(false), child: const Text('Cancelar')),
        FilledButton(onPressed: _saving ? null : _save, child: Text(_saving ? 'Cambiando…' : 'Cambiar')),
      ],
    );
  }
}

class _DialogError extends StatelessWidget {
  const _DialogError({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) => Padding(
        padding: const EdgeInsets.only(top: AdoptifySpacing.md),
        child: Text(
          message,
          style: Theme.of(context).textTheme.bodySmall?.copyWith(color: context.colors.reportText),
        ),
      );
}
