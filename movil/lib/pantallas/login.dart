import 'package:flutter/material.dart';

import '../config.dart';
import '../servicios/api.dart';
import '../tema.dart';
import 'inicio.dart';

/// Pantalla de inicio de sesión: email, contraseña y un botón grande.
class LoginPantalla extends StatefulWidget {
  const LoginPantalla({super.key});

  @override
  State<LoginPantalla> createState() => _LoginPantallaState();
}

class _LoginPantallaState extends State<LoginPantalla> {
  final _formulario = GlobalKey<FormState>();
  final _email = TextEditingController();
  final _password = TextEditingController();
  bool _cargando = false;
  bool _verPassword = false;
  String? _error;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  Future<void> _entrar() async {
    if (!_formulario.currentState!.validate()) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final usuario = await api.login(emailCompleto(_email.text), _password.text);
      if (!mounted) return;
      // Sustituye la pantalla de login por la de inicio (no se puede volver atrás)
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => InicioPantalla(usuario: usuario)),
      );
    } on ApiError catch (e) {
      setState(() => _error = e.mensaje);
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final colores = Theme.of(context).colorScheme;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formulario,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const _Logo(),
                    const SizedBox(height: 20),
                    const Text(
                      'PrevenApp',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 34, fontWeight: FontWeight.w800, letterSpacing: -0.5),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Tu día, bajo control',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 16, color: Paleta.tintaSuave),
                    ),
                    const SizedBox(height: 36),
                    TextFormField(
                      controller: _email,
                      keyboardType: TextInputType.emailAddress,
                      autocorrect: false,
                      autofillHints: const [AutofillHints.username],
                      textInputAction: TextInputAction.next,
                      decoration: const InputDecoration(
                        labelText: 'Usuario',
                        hintText: 'ana',
                        // Se ve "@previs.es" al final: el técnico solo escribe su usuario
                        suffixText: '@$dominioEmpresa',
                        helperText: 'Escribe solo tu usuario, sin @$dominioEmpresa',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: (valor) =>
                          (valor == null || valor.trim().isEmpty) ? 'Escribe tu usuario' : null,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _password,
                      obscureText: !_verPassword,
                      autofillHints: const [AutofillHints.password],
                      textInputAction: TextInputAction.done,
                      onFieldSubmitted: (_) => _entrar(),
                      decoration: InputDecoration(
                        labelText: 'Contraseña',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          tooltip: _verPassword ? 'Ocultar contraseña' : 'Ver contraseña',
                          icon: Icon(_verPassword ? Icons.visibility_off : Icons.visibility),
                          onPressed: () => setState(() => _verPassword = !_verPassword),
                        ),
                      ),
                      validator: (valor) =>
                          (valor == null || valor.isEmpty) ? 'Escribe tu contraseña' : null,
                    ),
                    if (_error != null) ...[
                      const SizedBox(height: 16),
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: colores.errorContainer,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(_error!, style: TextStyle(color: colores.onErrorContainer)),
                      ),
                    ],
                    const SizedBox(height: 24),
                    FilledButton(
                      onPressed: _cargando ? null : _entrar,
                      child: _cargando
                          ? SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 3, color: Paleta.morado),
                            )
                          : const Text('Entrar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// Logo: un escudo blanco sobre un círculo naranja de alta visibilidad,
/// con un anillo de "cinta" alrededor.
class _Logo extends StatelessWidget {
  const _Logo();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        width: 104,
        height: 104,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Paleta.lavanda,
          border: Border.all(color: Paleta.morado, width: 2),
        ),
        child: Icon(Icons.shield_outlined, size: 52, color: Paleta.morado),
      ),
    );
  }
}
