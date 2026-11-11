import 'package:flutter/material.dart';

import '../../app/theme.dart';
import '../../core/api_client.dart';
import '../../shared/widgets/adoptify_logo.dart';
import '../../shared/widgets/message_box.dart';
import 'auth_controller.dart';
import 'auth_service.dart';
import 'verification_code.dart';

// Inicio de sesión único: adoptantes y fundaciones entran por el mismo formulario.
// Después, el router muestra la vista que corresponde al rol (ver sessionRedirect en router.dart).
// Con la verificación en dos pasos activa (HU-I), tras la contraseña se pide el código que llega al correo.
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _fullName = TextEditingController();
  final _rut = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  final _code = TextEditingController();

  bool _registering = false;
  bool _submitting = false;
  String? _error;
  // Código enviado al correo: mientras exista, la tarjeta muestra el paso del código en vez del formulario
  CodeChallenge? _challenge;

  bool get _isRegister => _registering;

  @override
  void dispose() {
    _fullName.dispose();
    _rut.dispose();
    _email.dispose();
    _password.dispose();
    _code.dispose();
    super.dispose();
  }

  void _toggleRegister() {
    setState(() {
      _registering = !_registering;
      _error = null;
    });
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();
    if (!_formKey.currentState!.validate()) return;
    setState(() {
      _error = null;
      _submitting = true;
    });
    final auth = AuthScope.of(context);
    try {
      final email = _email.text.trim();
      if (_isRegister) {
        await auth.signUp(email, _rut.text.trim(), _password.text, _fullName.text.trim());
      } else {
        final challenge = await auth.signIn(email, _password.text);
        if (challenge != null) {
          if (!mounted) return;
          setState(() {
            _challenge = challenge;
            _submitting = false;
          });
          return;
        }
      }
      // Con la sesión iniciada, el router lleva al mapa o a la vista de fundación según el rol
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(error, 'No pudimos iniciar sesión. Inténtalo nuevamente.');
        _submitting = false;
      });
    }
  }

  Future<void> _verify() async {
    final challenge = _challenge;
    if (challenge == null || _submitting) return;
    if (_code.text.length != 6) {
      setState(() => _error = 'Ingresa los 6 dígitos del código.');
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() {
      _error = null;
      _submitting = true;
    });
    try {
      await AuthScope.of(context).verifyCode(challenge.id, _code.text);
      // Con la sesión iniciada, el router lleva a la vista que corresponde al rol
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(error, 'No pudimos verificar el código. Inténtalo nuevamente.');
        _submitting = false;
        _code.clear();
        // Código vencido o agotado: de vuelta a la contraseña para recibir uno nuevo
        if (mustRestart(error)) {
          _challenge = null;
          _password.clear();
        }
      });
    }
  }

  void _backToPassword() => setState(() {
        _challenge = null;
        _error = null;
        _code.clear();
      });

  // Segundo paso: el código que llegó al correo, reenviarlo o volver a la contraseña
  List<Widget> _codeStep(CodeChallenge challenge) {
    return [
      VerificationCodeField(controller: _code, onCompleted: (_) => _verify()),
      if (_error != null) ...[
        const SizedBox(height: AdoptifySpacing.lg),
        MessageBox.error(message: _error!),
      ],
      const SizedBox(height: AdoptifySpacing.lg),
      FilledButton(
        onPressed: _submitting ? null : _verify,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (_submitting) ...[
              SizedBox.square(
                dimension: 17,
                child: CircularProgressIndicator(strokeWidth: 2, color: context.colors.onAccent),
              ),
              const SizedBox(width: AdoptifySpacing.sm),
            ],
            const Text('Verificar'),
          ],
        ),
      ),
      const SizedBox(height: AdoptifySpacing.sm),
      ResendCodeButton(
        // La clave reinicia la cuenta regresiva si se vuelve a iniciar sesión con otro desafío
        key: ValueKey(challenge.id),
        challenge: challenge,
        onResend: () => AuthScope.of(context).service.resendCode(challenge.id),
        onResent: (fresh) => setState(() {
          _challenge = fresh;
          _error = null;
          _code.clear();
        }),
        onError: (message) => setState(() => _error = message),
      ),
      TextButton(onPressed: _submitting ? null : _backToPassword, child: const Text('Volver')),
    ];
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final challenge = _challenge;
    final title = challenge != null ? 'Revisa tu correo' : (_isRegister ? 'Crea tu cuenta' : 'Hola de nuevo');
    final description = challenge != null
        ? 'Enviamos un código de 6 dígitos a ${challenge.emailHint}. Vence en ${challenge.expiresInMinutes} minutos.'
        : _isRegister
            ? 'Regístrate para encontrar a tu próximo compañero.'
            : 'Inicia sesión para encontrar a tu próximo compañero.';

    return Scaffold(
      appBar: AppBar(),
      body: SafeArea(
        top: false,
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(AdoptifySpacing.lg, 0, AdoptifySpacing.lg, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: Column(
                children: [
                  const AdoptifyLogo(),
                  const SizedBox(height: AdoptifySpacing.xxl),
                  Container(
                    padding: const EdgeInsets.all(AdoptifySpacing.xl),
                    decoration: BoxDecoration(
                      color: context.colors.surface,
                      borderRadius: BorderRadius.circular(AdoptifyRadius.xl),
                      border: Border.all(color: context.colors.border),
                      boxShadow: AdoptifyShadows.soft,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Text(title, style: textTheme.headlineSmall, textAlign: TextAlign.center),
                          const SizedBox(height: AdoptifySpacing.sm),
                          Text(
                            description,
                            style: textTheme.bodyMedium?.copyWith(color: context.colors.textMuted),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AdoptifySpacing.xl),
                          if (challenge != null)
                            ..._codeStep(challenge)
                          else ...[
                          if (_isRegister) ...[
                            _Field(
                              label: 'Nombre completo',
                              controller: _fullName,
                              hint: 'Tu nombre',
                              autofillHints: const [AutofillHints.name],
                              textCapitalization: TextCapitalization.words,
                              validator: (value) =>
                                  (value ?? '').trim().length < 2 ? 'El nombre debe tener al menos 2 caracteres' : null,
                            ),
                            const SizedBox(height: AdoptifySpacing.lg),
                            _Field(
                              label: 'RUT',
                              controller: _rut,
                              hint: '12.345.678-5',
                              validator: (value) => (value ?? '').trim().isEmpty ? 'Ingresa tu RUT' : null,
                            ),
                            const SizedBox(height: AdoptifySpacing.lg),
                          ],
                          _Field(
                            label: 'Correo electrónico',
                            controller: _email,
                            hint: 'tucorreo@ejemplo.cl',
                            keyboardType: TextInputType.emailAddress,
                            autofillHints: const [AutofillHints.email],
                            validator: (value) {
                              final email = (value ?? '').trim();
                              if (email.isEmpty) return 'Ingresa tu correo';
                              if (!email.contains('@') || !email.contains('.')) return 'Ingresa un correo válido';
                              return null;
                            },
                          ),
                          const SizedBox(height: AdoptifySpacing.lg),
                          _Field(
                            label: 'Contraseña',
                            controller: _password,
                            hint: _isRegister ? 'Mínimo 8 caracteres' : 'Tu contraseña',
                            obscureText: true,
                            textInputAction: TextInputAction.done,
                            onSubmitted: (_) => _submit(),
                            autofillHints: [_isRegister ? AutofillHints.newPassword : AutofillHints.password],
                            validator: (value) {
                              final password = value ?? '';
                              if (password.isEmpty) return 'Ingresa tu contraseña';
                              if (_isRegister && password.length < 8) {
                                return 'La contraseña debe tener al menos 8 caracteres';
                              }
                              return null;
                            },
                          ),
                          if (_error != null) ...[
                            const SizedBox(height: AdoptifySpacing.lg),
                            MessageBox.error(message: _error!),
                          ],
                          const SizedBox(height: AdoptifySpacing.lg),
                          FilledButton(
                            onPressed: _submitting ? null : _submit,
                            child: Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (_submitting) ...[
                                  const SizedBox.square(
                                    dimension: 17,
                                    child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                                  ),
                                  const SizedBox(width: AdoptifySpacing.sm),
                                ],
                                Text(_isRegister ? 'Crear cuenta' : 'Iniciar sesión'),
                              ],
                            ),
                          ),
                          const SizedBox(height: AdoptifySpacing.xl),
                          Divider(color: context.colors.muted),
                          const SizedBox(height: AdoptifySpacing.lg),
                          _Footer(isRegister: _isRegister, onToggle: _toggleRegister),
                          ],
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _Field extends StatelessWidget {
  const _Field({
    required this.label,
    required this.controller,
    required this.hint,
    this.validator,
    this.keyboardType,
    this.obscureText = false,
    this.autofillHints,
    this.textCapitalization = TextCapitalization.none,
    this.textInputAction = TextInputAction.next,
    this.onSubmitted,
  });

  final String label;
  final TextEditingController controller;
  final String hint;
  final FormFieldValidator<String>? validator;
  final TextInputType? keyboardType;
  final bool obscureText;
  final Iterable<String>? autofillHints;
  final TextCapitalization textCapitalization;
  final TextInputAction textInputAction;
  final ValueChanged<String>? onSubmitted;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.titleSmall),
        const SizedBox(height: AdoptifySpacing.sm),
        TextFormField(
          controller: controller,
          validator: validator,
          keyboardType: keyboardType,
          obscureText: obscureText,
          autocorrect: false,
          autofillHints: autofillHints,
          textCapitalization: textCapitalization,
          textInputAction: textInputAction,
          onFieldSubmitted: onSubmitted,
          decoration: InputDecoration(hintText: hint),
        ),
      ],
    );
  }
}

class _Footer extends StatelessWidget {
  const _Footer({required this.isRegister, required this.onToggle});

  final bool isRegister;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodyMedium?.copyWith(color: context.colors.textMuted);
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(isRegister ? '¿Ya tienes cuenta?' : '¿No tienes cuenta?', style: muted),
        TextButton(
          onPressed: onToggle,
          style: TextButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: AdoptifySpacing.sm)),
          child: Text(isRegister ? 'Inicia sesión' : 'Regístrate'),
        ),
      ],
    );
  }
}
