import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/api_client.dart';
import '../../shared/widgets/message_box.dart';
import 'auth_controller.dart';
import 'auth_service.dart';
import 'verification_code.dart';

// Tarjeta del Perfil (adoptante y fundación) para activar o desactivar la verificación en dos pasos (HU-I).
// Activar envía un código al correo y solo queda activa al ingresarlo; desactivar pide la contraseña.
class TwoFactorCard extends StatefulWidget {
  const TwoFactorCard({super.key});

  @override
  State<TwoFactorCard> createState() => _TwoFactorCardState();
}

class _TwoFactorCardState extends State<TwoFactorCard> {
  bool _busy = false;

  Future<void> _enable() async {
    final auth = AuthScope.of(context);
    setState(() => _busy = true);
    final CodeChallenge challenge;
    try {
      challenge = await auth.service.startTwoFactor();
    } catch (error) {
      if (mounted) {
        setState(() => _busy = false);
        _notify(errorMessage(error, 'No pudimos enviar el código a tu correo. Inténtalo nuevamente.'));
      }
      return;
    }
    if (!mounted) return;
    setState(() => _busy = false);
    final user = await showDialog<AppUser>(
      context: context,
      barrierDismissible: false,
      builder: (_) => _ConfirmCodeDialog(auth: auth, challenge: challenge),
    );
    if (user == null || !mounted) return;
    auth.updateUser(user);
    _notify('Listo: desde ahora te pediremos un código al iniciar sesión.');
  }

  Future<void> _disable() async {
    final auth = AuthScope.of(context);
    final user = await showDialog<AppUser>(context: context, builder: (_) => _DisableDialog(auth: auth));
    if (user == null || !mounted) return;
    auth.updateUser(user);
    _notify('Desactivaste la verificación en dos pasos.');
  }

  void _notify(String message) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));

  @override
  Widget build(BuildContext context) {
    final colors = context.colors;
    final textTheme = Theme.of(context).textTheme;
    final enabled = AuthScope.of(context).user?.twoFactorEnabled ?? false;
    return Container(
      padding: const EdgeInsets.all(AdoptifySpacing.lg),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(AdoptifyRadius.lg),
        border: Border.all(color: colors.border),
        boxShadow: AdoptifyShadows.soft,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              Icon(enabled ? Icons.verified_user : Icons.shield_outlined, color: colors.primaryDark),
              const SizedBox(width: AdoptifySpacing.sm),
              Expanded(child: Text('Verificación en dos pasos', style: textTheme.titleMedium)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: AdoptifySpacing.sm, vertical: AdoptifySpacing.xs),
                decoration: BoxDecoration(
                  color: enabled ? colors.successStrong : colors.muted,
                  borderRadius: BorderRadius.circular(99),
                ),
                child: Text(
                  enabled ? 'Activa' : 'Inactiva',
                  style: textTheme.labelMedium?.copyWith(color: enabled ? colors.onAccent : colors.textMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: AdoptifySpacing.xs),
          Text(
            enabled
                ? 'Al iniciar sesión te pedimos un código que llega a tu correo.'
                : 'Protege tu cuenta: además de la contraseña, te pediremos un código que llega a tu correo.',
            style: textTheme.bodySmall,
          ),
          const SizedBox(height: AdoptifySpacing.md),
          enabled
              ? OutlinedButton(onPressed: _busy ? null : _disable, child: const Text('Desactivar'))
              : FilledButton(
                  onPressed: _busy ? null : _enable,
                  child: Text(_busy ? 'Enviando código…' : 'Activar'),
                ),
        ],
      ),
    );
  }
}

// Ingresar el código enviado al correo para confirmar la activación
class _ConfirmCodeDialog extends StatefulWidget {
  const _ConfirmCodeDialog({required this.auth, required this.challenge});

  final AuthController auth;
  final CodeChallenge challenge;

  @override
  State<_ConfirmCodeDialog> createState() => _ConfirmCodeDialogState();
}

class _ConfirmCodeDialogState extends State<_ConfirmCodeDialog> {
  final _code = TextEditingController();
  late CodeChallenge _challenge = widget.challenge;
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _code.dispose();
    super.dispose();
  }

  Future<void> _confirm() async {
    if (_sending) return;
    if (_code.text.length != 6) {
      setState(() => _error = 'Ingresa los 6 dígitos del código.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final user = await widget.auth.service.confirmTwoFactor(_challenge.id, _code.text);
      if (mounted) Navigator.of(context).pop(user);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _code.clear();
        _error = mustRestart(error)
            ? 'El código ya no sirve. Cierra esta ventana y vuelve a tocar Activar.'
            : errorMessage(error, 'No pudimos verificar el código. Inténtalo nuevamente.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Revisa tu correo', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Enviamos un código de 6 dígitos a ${_challenge.emailHint}. Ingrésalo para activar la verificación.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AdoptifySpacing.lg),
          VerificationCodeField(controller: _code, onCompleted: (_) => _confirm()),
          if (_error != null) ...[
            const SizedBox(height: AdoptifySpacing.md),
            MessageBox.error(message: _error!),
          ],
          ResendCodeButton(
            challenge: _challenge,
            onResend: () => widget.auth.service.resendCode(_challenge.id),
            onResent: (fresh) => setState(() {
              _challenge = fresh;
              _error = null;
              _code.clear();
            }),
            onError: (message) => setState(() => _error = message),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _sending ? null : () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _sending ? null : _confirm, child: const Text('Activar')),
      ],
    );
  }
}

// Desactivar pide la contraseña, para que no la apague cualquiera que tome el teléfono desbloqueado
class _DisableDialog extends StatefulWidget {
  const _DisableDialog({required this.auth});

  final AuthController auth;

  @override
  State<_DisableDialog> createState() => _DisableDialogState();
}

class _DisableDialogState extends State<_DisableDialog> {
  final _password = TextEditingController();
  bool _sending = false;
  String? _error;

  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  Future<void> _disable() async {
    if (_password.text.isEmpty) {
      setState(() => _error = 'Ingresa tu contraseña.');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      final user = await widget.auth.service.disableTwoFactor(_password.text);
      if (mounted) Navigator.of(context).pop(user);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _sending = false;
        _error = errorMessage(error, 'No pudimos desactivarla. Inténtalo nuevamente.');
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('Desactivar verificación', textAlign: TextAlign.center),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            'Para desactivarla, confirma tu contraseña. Después entrarás solo con tu contraseña.',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AdoptifySpacing.lg),
          TextField(
            controller: _password,
            obscureText: true,
            autofocus: true,
            autofillHints: const [AutofillHints.password],
            onSubmitted: (_) => _disable(),
            decoration: InputDecoration(labelText: 'Contraseña', errorText: _error),
          ),
        ],
      ),
      actions: [
        TextButton(onPressed: _sending ? null : () => Navigator.of(context).pop(), child: const Text('Cancelar')),
        FilledButton(onPressed: _sending ? null : _disable, child: const Text('Desactivar')),
      ],
    );
  }
}
