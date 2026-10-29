import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api_client.dart';
import '../../shared/widgets/adoptify_logo.dart';
import '../../shared/widgets/message_box.dart';
import 'auth_controller.dart';
import 'auth_service.dart';

// Inicio de sesión con pestañas Usuario / Fundación, igual que el login del portal
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

  AccountType _tab = AccountType.user;
  bool _registering = false;
  bool _submitting = false;
  String? _error;

  bool get _isRegister => _tab == AccountType.user && _registering;

  @override
  void dispose() {
    _fullName.dispose();
    _rut.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  void _changeTab(AccountType next) {
    setState(() {
      _tab = next;
      _registering = false;
      _error = null;
    });
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
        await auth.signIn(email, _password.text, _tab);
      }
      if (!mounted) return;
      // Con la sesión iniciada, la app abre en el mapa
      context.go('/mapa');
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = errorMessage(error, 'No pudimos iniciar sesión. Inténtalo nuevamente.');
        _submitting = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    final isUser = _tab == AccountType.user;
    final title = _isRegister
        ? 'Crea tu cuenta'
        : isUser
        ? 'Hola de nuevo'
        : 'Portal de fundaciones';
    final description = _isRegister
        ? 'Regístrate para encontrar a tu próximo compañero.'
        : isUser
        ? 'Inicia sesión para encontrar a tu próximo compañero.'
        : 'Inicia sesión para gestionar a tus rescatados.';

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
                      color: AdoptifyColors.surface,
                      borderRadius: BorderRadius.circular(AdoptifyRadius.xl),
                      border: Border.all(color: AdoptifyColors.border),
                      boxShadow: AdoptifyShadows.soft,
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _AccountTabs(selected: _tab, onChanged: _changeTab),
                          const SizedBox(height: AdoptifySpacing.xxl),
                          Text(title, style: textTheme.headlineSmall, textAlign: TextAlign.center),
                          const SizedBox(height: AdoptifySpacing.sm),
                          Text(
                            description,
                            style: textTheme.bodyMedium?.copyWith(color: AdoptifyColors.textMuted),
                            textAlign: TextAlign.center,
                          ),
                          const SizedBox(height: AdoptifySpacing.xl),
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
                            hint: isUser ? 'tucorreo@ejemplo.cl' : 'contacto@fundacion.cl',
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
                          const Divider(color: AdoptifyColors.muted),
                          const SizedBox(height: AdoptifySpacing.lg),
                          _Footer(isUser: isUser, isRegister: _isRegister, onToggle: _toggleRegister),
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

class _AccountTabs extends StatelessWidget {
  const _AccountTabs({required this.selected, required this.onChanged});

  final AccountType selected;
  final ValueChanged<AccountType> onChanged;

  @override
  Widget build(BuildContext context) {
    final labelStyle = Theme.of(context).textTheme.labelLarge;
    return Container(
      padding: const EdgeInsets.all(AdoptifySpacing.xs),
      decoration: BoxDecoration(color: AdoptifyColors.muted, borderRadius: BorderRadius.circular(AdoptifyRadius.md)),
      child: Row(
        children: [
          _tab(AccountType.user, 'Usuario', Icons.person_outline, labelStyle),
          const SizedBox(width: AdoptifySpacing.xs),
          _tab(AccountType.foundation, 'Fundación', Icons.business_outlined, labelStyle),
        ],
      ),
    );
  }

  Widget _tab(AccountType type, String label, IconData icon, TextStyle? labelStyle) {
    final active = selected == type;
    final color = active ? AdoptifyColors.primaryText : AdoptifyColors.textMuted;
    return Expanded(
      child: Semantics(
        selected: active,
        button: true,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 150),
          decoration: BoxDecoration(
            color: active ? AdoptifyColors.surface : Colors.transparent,
            borderRadius: BorderRadius.circular(AdoptifyRadius.sm),
            boxShadow: active ? AdoptifyShadows.soft : null,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(AdoptifyRadius.sm),
            onTap: () => onChanged(type),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: AdoptifySpacing.sm),
                  Text(label, style: labelStyle?.copyWith(color: color)),
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
  const _Footer({required this.isUser, required this.isRegister, required this.onToggle});

  final bool isUser;
  final bool isRegister;
  final VoidCallback onToggle;

  @override
  Widget build(BuildContext context) {
    final muted = Theme.of(context).textTheme.bodyMedium?.copyWith(color: AdoptifyColors.textMuted);
    if (!isUser) {
      return Text(
        'Las cuentas de fundación las crea el equipo de Adoptify.',
        style: muted,
        textAlign: TextAlign.center,
      );
    }
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
