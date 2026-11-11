import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../app/theme.dart';
import '../../core/api_client.dart';
import 'auth_service.dart';

// Piezas del código de verificación por correo (HU-I), compartidas por el login y por la activación en el Perfil

// Campo de 6 dígitos: teclado numérico y autocompletado del código cuando el teléfono lo ofrece
class VerificationCodeField extends StatelessWidget {
  const VerificationCodeField({super.key, required this.controller, this.onCompleted, this.errorText});

  final TextEditingController controller;
  final ValueChanged<String>? onCompleted;
  final String? errorText;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return TextField(
      controller: controller,
      autofocus: true,
      keyboardType: TextInputType.number,
      textAlign: TextAlign.center,
      maxLength: 6,
      autofillHints: const [AutofillHints.oneTimeCode],
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      style: textTheme.headlineSmall?.copyWith(letterSpacing: AdoptifySpacing.sm),
      onChanged: (value) {
        if (value.length == 6) onCompleted?.call(value);
      },
      decoration: InputDecoration(
        hintText: '000000',
        counterText: '',
        errorText: errorText,
        semanticCounterText: 'Código de 6 dígitos',
      ),
    );
  }
}

// "Reenviar código": se habilita cuando termina la espera que indica la API (60 s) y vuelve a esperar
// después de cada reenvío. Avisa el desafío nuevo con onResent y los errores con onError.
class ResendCodeButton extends StatefulWidget {
  const ResendCodeButton({
    super.key,
    required this.challenge,
    required this.onResend,
    required this.onResent,
    required this.onError,
  });

  final CodeChallenge challenge;
  final Future<CodeChallenge> Function() onResend;
  final ValueChanged<CodeChallenge> onResent;
  final ValueChanged<String> onError;

  @override
  State<ResendCodeButton> createState() => _ResendCodeButtonState();
}

class _ResendCodeButtonState extends State<ResendCodeButton> {
  Timer? _timer;
  int _left = 0;
  bool _sending = false;

  @override
  void initState() {
    super.initState();
    _wait(widget.challenge.resendInSeconds);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _wait(int seconds) {
    _timer?.cancel();
    setState(() => _left = seconds);
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return timer.cancel();
      setState(() => _left--);
      if (_left <= 0) timer.cancel();
    });
  }

  Future<void> _resend() async {
    setState(() => _sending = true);
    try {
      final challenge = await widget.onResend();
      if (!mounted) return;
      widget.onResent(challenge);
      _wait(challenge.resendInSeconds);
    } catch (error) {
      if (!mounted) return;
      widget.onError(errorMessage(error, 'No pudimos reenviar el código. Inténtalo nuevamente.'));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final waiting = _left > 0;
    return TextButton.icon(
      onPressed: waiting || _sending ? null : _resend,
      icon: const Icon(Icons.refresh, size: 18),
      label: Text(waiting ? 'Reenviar código en $_left s' : (_sending ? 'Enviando…' : 'Reenviar código')),
    );
  }
}

// El error de la API obliga a empezar de nuevo (código vencido, agotado o ya usado), salvo un código incorrecto
// al que todavía le quedan intentos. En el login llega como 401; al activar desde el Perfil, como 400.
bool mustRestart(Object error) =>
    error is ApiException &&
    (error.statusCode == 401 || error.statusCode == 400) &&
    !(error.detail is String && (error.detail as String).startsWith('El código no es correcto'));
