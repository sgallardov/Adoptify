import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../app/theme.dart';
import '../../core/api_client.dart';
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
      // Vuelve a la pantalla desde donde se abrió el login
      if (context.canPop()) {
        context.pop();
      } else {
        context.go('/cuenta');
      }
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
    final title = _isRegister ? 'Crea tu cuenta' : isUser ? 'Hola de nuevo' : 'Portal de fundaciones';
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
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 40),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 448),
              child: Column(
                children: [
                  const _Logo(),
                  const SizedBox(height: 32),
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: AdoptifyColors.surface,
                      borderRadius: BorderRadius.circular(24),
                      border: Border.all(color: AdoptifyColors.border),
                    ),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          _AccountTabs(selected: _tab, onChanged: _changeTab),
                          const SizedBox(height: 32),
                          Text(title, style: textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
                          const SizedBox(height: 8),
                          Text(description, style: textTheme.bodyMedium?.copyWith(color: AdoptifyColors.textMuted)),
                          const SizedBox(height: 28),
                          if (_isRegister) ...[
                            _Field(
                              label: 'Nombre completo',
                              controller: _fullName,
                              hint: 'Tu nombre',
                              autofillHints: const [AutofillHints.name],
                              textCapitalization: TextCapitalization.words,
                              validator: (value) => (value ?? '').trim().length < 2
                                  ? 'El nombre debe tener al menos 2 caracteres'
                                  : null,
                            ),
                            const SizedBox(height: 20),
                            _Field(
                              label: 'RUT',
                              controller: _rut,
                              hint: '12.345.678-5',
                              validator: (value) => (value ?? '').trim().isEmpty ? 'Ingresa tu RUT' : null,
                            ),
                            const SizedBox(height: 20),
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
                          const SizedBox(height: 20),
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
                            const SizedBox(height: 20),
                            _ErrorBox(message: _error!),
                          ],
                          const SizedBox(height: 20),
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
                                  const SizedBox(width: 8),
                                ],
                                Text(
                                  _isRegister ? 'Crear cuenta' : 'Iniciar sesión',
                                  style: const TextStyle(fontWeight: FontWeight.w600),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Divider(height: 1, color: AdoptifyColors.muted),
                          const SizedBox(height: 16),
                          _Footer(
                            isUser: isUser,
                            isRegister: _isRegister,
                            onToggle: _toggleRegister,
                          ),
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

// Logo "adoptify." como en el portal
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: AdoptifyColors.primary,
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.pets, color: Colors.white, size: 24),
        ),
        const SizedBox(width: 10),
        Text.rich(
          const TextSpan(
            text: 'adoptify',
            children: [TextSpan(text: '.', style: TextStyle(color: AdoptifyColors.primary))],
          ),
          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
        ),
      ],
    );
  }
}

class _AccountTabs extends StatelessWidget {
  const _AccountTabs({required this.selected, required this.onChanged});

  final AccountType selected;
  final ValueChanged<AccountType> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(4),
      decoration: BoxDecoration(
        color: AdoptifyColors.muted,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          _tab(AccountType.user, 'Usuario', Icons.person_outline),
          const SizedBox(width: 4),
          _tab(AccountType.foundation, 'Fundación', Icons.business_outlined),
        ],
      ),
    );
  }

  Widget _tab(AccountType type, String label, IconData icon) {
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
            borderRadius: BorderRadius.circular(8),
            boxShadow: active
                ? const [BoxShadow(color: Color(0x14000000), blurRadius: 2, offset: Offset(0, 1))]
                : null,
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(8),
            onTap: () => onChanged(type),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(icon, size: 17, color: color),
                  const SizedBox(width: 8),
                  Text(label, style: TextStyle(color: color, fontWeight: FontWeight.w600, fontSize: 14)),
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
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500)),
        const SizedBox(height: 8),
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

class _ErrorBox extends StatelessWidget {
  const _ErrorBox({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      liveRegion: true,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AdoptifyColors.primarySoft,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Padding(
              padding: EdgeInsets.only(top: 1),
              child: Icon(Icons.warning_amber_rounded, size: 16, color: AdoptifyColors.primaryTextDark),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(message, style: const TextStyle(fontSize: 14, color: AdoptifyColors.primaryTextDark)),
            ),
          ],
        ),
      ),
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
    const muted = TextStyle(fontSize: 14, color: AdoptifyColors.textMuted);
    if (!isUser) {
      return const Text('Las cuentas de fundación las crea el equipo de Adoptify.', style: muted, textAlign: TextAlign.center);
    }
    return Wrap(
      alignment: WrapAlignment.center,
      crossAxisAlignment: WrapCrossAlignment.center,
      children: [
        Text(isRegister ? '¿Ya tienes cuenta?' : '¿No tienes cuenta?', style: muted),
        TextButton(
          onPressed: onToggle,
          style: TextButton.styleFrom(
            foregroundColor: AdoptifyColors.primaryDark,
            padding: const EdgeInsets.symmetric(horizontal: 6),
          ),
          child: Text(isRegister ? 'Inicia sesión' : 'Regístrate', style: const TextStyle(fontWeight: FontWeight.w600)),
        ),
      ],
    );
  }
}
