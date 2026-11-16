import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'pilo_family_theme.dart';
import 'pilo_password_reminder.dart';
import 'pilo_rut_input_formatter.dart';
import '../lab/mode.dart';
import '../auth/saved_credentials.dart';
import '../pages/welcome.dart';

enum PiloLoginRole {
  attorney('Apoderado', Icons.people_outline_rounded),
  passenger('Alumno', Icons.school_outlined),
  coordinator('Coordinador', Icons.assignment_outlined);

  const PiloLoginRole(this.label, this.icon);
  final String label;
  final IconData icon;

  String get rutLabel => this == coordinator ? 'Tu RUT' : 'RUT del alumno';
}

class PiloLoginForm extends StatefulWidget {
  const PiloLoginForm({
    super.key,
    required this.role,
    required this.authenticate,
    this.onOpenAttorney,
  });

  final PiloLoginRole role;

  /// Saves the authenticated session and reports whether the password is temporary.
  final Future<({Widget destination, bool temporaryPassword})> Function(
    String rut,
    String password,
  )
  authenticate;
  final VoidCallback? onOpenAttorney;

  @override
  State<PiloLoginForm> createState() => _PiloLoginFormState();
}

class _PiloLoginFormState extends State<PiloLoginForm> {
  final _form = GlobalKey<FormState>();
  final _rut = TextEditingController();
  final _password = TextEditingController();
  bool _obscure = true;
  bool _busy = false;
  bool _remember = false;
  bool _hasSaved = false;
  String? _message;

  bool _restoreStarted = false;
  bool _restoring = false;

  bool get _useSecureStorage =>
      (Theme.of(context).platform == TargetPlatform.iOS ||
          Theme.of(context).platform == TargetPlatform.android) &&
      !LabMode.fixturesForTests;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_restoreStarted && _useSecureStorage) {
      _restoreStarted = true;
      _restoreSaved();
    }
  }

  Future<void> _restoreSaved({bool explicit = false}) async {
    if (_busy || _restoring) return;
    _restoring = true;
    final originalRut = _rut.text;
    final originalPassword = _password.text;
    try {
      final saved = await SavedCredentials.read(widget.role.name);
      if (!mounted || saved == null) return;
      setState(() {
        _hasSaved = true;
        // Do not replace typing or a password-manager fill that completed
        // while the native secure-store read was in flight.
        if (!_busy &&
            _rut.text == originalRut &&
            _password.text == originalPassword &&
            (explicit || (originalRut.isEmpty && originalPassword.isEmpty))) {
          _rut.text = PiloRutInputFormatter.formatDisplay(saved['rut']!);
          _password.text = saved['password']!;
          _remember = true;
        }
      });
    } on PlatformException {
      if (mounted)
        setState(
          () => _message =
              'No pudimos leer la contraseña guardada. Puedes ingresarla de nuevo.',
        );
    } on MissingPluginException {
      // Manual login and system autofill remain available on unsupported hosts.
    } finally {
      _restoring = false;
    }
  }

  Future<void> _forget() async {
    if (_busy) return;
    setState(() => _busy = true);
    try {
      await SavedCredentials.delete(widget.role.name);
      if (mounted)
        setState(() {
          _hasSaved = false;
          _remember = false;
          _rut.clear();
          _password.clear();
        });
    } on PlatformException {
      if (mounted)
        setState(() => _message = 'No se pudo quitar la clave guardada.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    setState(() {
      _busy = true;
      _message = null;
      _obscure = true;
    });
    FocusManager.instance.primaryFocus?.unfocus();
    final rawRut = _rut.text.trim();
    final digits = rawRut.replaceAll(RegExp(r'[.-]'), '').toUpperCase();
    final rut = RegExp(r'^[0-9]+[0-9K]$').hasMatch(digits)
        ? '${digits.substring(0, digits.length - 1)}-${digits[digits.length - 1]}'
        : rawRut;
    final password = _password.text;
    try {
      final login = await widget.authenticate(rut, password);
      if (!mounted) return;
      final starterDigits = rut.replaceAll(RegExp(r'[^0-9]'), '');
      final initialPassword =
          widget.role != PiloLoginRole.coordinator &&
          starterDigits.length >= 6 &&
          password == starterDigits.substring(0, 6);
      // Explicit consent applies to every successfully accepted credential,
      // including the initial password; the change reminder is independent.
      TextInput.finishAutofillContext(
        shouldSave: !_useSecureStorage && _remember,
      );
      if (_useSecureStorage) {
        try {
          if (_remember) {
            await SavedCredentials.save(widget.role.name, rut, password);
          } else {
            await SavedCredentials.delete(widget.role.name);
          }
        } on PlatformException {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'La sesión se inició, pero no se pudo actualizar la contraseña guardada en este dispositivo.',
                ),
              ),
            );
          }
        } on MissingPluginException {
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'El guardado de contraseñas no está disponible en este dispositivo.',
                ),
              ),
            );
          }
        }
      }
      if (!mounted) return;
      _password.clear();
      if (initialPassword || login.temporaryPassword) {
        await showPiloPasswordReminder(context);
        if (!mounted) return;
      }
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute<void>(builder: (_) => login.destination),
        (_) => false,
      );
    } catch (error) {
      if (!mounted) return;
      setState(
        () => _message = error is FormatException
            ? error.message
            : error.toString().startsWith('Exception: Revisa')
            ? 'Revisa el RUT y la contraseña, y vuelve a intentar.'
            : 'No pudimos iniciar sesión. Revisa tus datos e inténtalo de nuevo.',
      );
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _back() {
    final navigator = Navigator.of(context);
    if (navigator.canPop()) {
      navigator.pop();
    } else {
      navigator.pushReplacement(
        MaterialPageRoute<void>(builder: (_) => WelcomeScreen()),
      );
    }
  }

  @override
  void dispose() {
    _rut.dispose();
    _password.dispose();
    super.dispose();
  }

  InputDecoration _field(String label, {Widget? suffix}) {
    final corners = BorderRadius.circular(22);
    return InputDecoration(
      labelText: label,
      filled: true,
      fillColor: PiloFamilyTheme.soft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
      border: OutlineInputBorder(
        borderRadius: corners,
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: corners,
        borderSide: const BorderSide(
          color: PiloFamilyTheme.accentText,
          width: 1.5,
        ),
      ),
      suffixIcon: suffix,
    );
  }

  @override
  Widget build(BuildContext context) {
    final role = widget.role;
    return PopScope(
      canPop: !_busy,
      child: Theme(
        data: PiloFamilyTheme.theme(Theme.of(context)),
        child: Scaffold(
          body: SafeArea(
            child: Align(
              alignment: Alignment.topCenter,
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 470),
                child: ListView(
                  keyboardDismissBehavior:
                      ScrollViewKeyboardDismissBehavior.onDrag,
                  padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
                  children: [
                    Row(
                      children: [
                        IconButton.filledTonal(
                          tooltip: 'Volver a elegir perfil',
                          style: IconButton.styleFrom(
                            minimumSize: const Size.square(52),
                            backgroundColor: PiloFamilyTheme.soft,
                            foregroundColor: PiloFamilyTheme.ink,
                          ),
                          onPressed: _busy ? null : _back,
                          icon: const Icon(Icons.arrow_back_rounded),
                        ),
                        const Spacer(),
                        Image.asset(
                          'assets/logo-letras-papigiras.png',
                          width: 116,
                          excludeFromSemantics: true,
                        ),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Align(
                      alignment: Alignment.centerLeft,
                      child: CircleAvatar(
                        radius: 24,
                        backgroundColor: role == PiloLoginRole.attorney
                            ? PiloFamilyTheme.mint
                            : PiloFamilyTheme.soft,
                        foregroundColor: PiloFamilyTheme.ink,
                        child: Icon(role.icon),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Semantics(
                      header: true,
                      child: Text(
                        role.label,
                        style: PiloFamilyTheme.display(49),
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      switch (role) {
                        PiloLoginRole.attorney =>
                          'Acompaña la gira de tu estudiante.',
                        PiloLoginRole.passenger =>
                          'Este acceso es para estudiantes que viajan.',
                        PiloLoginRole.coordinator =>
                          'Ingresa para gestionar tus giras.',
                      },
                      style: const TextStyle(
                        fontSize: 15,
                        height: 1.35,
                        color: PiloFamilyTheme.secondary,
                      ),
                    ),
                    if (widget.onOpenAttorney != null)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: TextButton.icon(
                          onPressed: _busy ? null : widget.onOpenAttorney,
                          icon: const Icon(Icons.swap_horiz_rounded, size: 20),
                          label: const Text('Soy apoderado'),
                        ),
                      ),
                    const SizedBox(height: 20),
                    if (_hasSaved)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12),
                        child: Wrap(
                          spacing: 6,
                          crossAxisAlignment: WrapCrossAlignment.center,
                          children: [
                            OutlinedButton.icon(
                              onPressed: _busy
                                  ? null
                                  : () => _restoreSaved(explicit: true),
                              icon: const Icon(Icons.key_rounded, size: 18),
                              label: const Text('Usar clave guardada'),
                            ),
                            IconButton(
                              tooltip: 'Quitar clave guardada',
                              onPressed: _busy ? null : _forget,
                              icon: const Icon(Icons.delete_outline_rounded),
                            ),
                          ],
                        ),
                      ),
                    AutofillGroup(
                      onDisposeAction: AutofillContextAction.cancel,
                      child: Form(
                        key: _form,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            TextFormField(
                              controller: _rut,
                              inputFormatters: const [PiloRutInputFormatter()],
                              readOnly: _busy,
                              autofillHints: const [AutofillHints.username],
                              autocorrect: false,
                              enableSuggestions: false,
                              textCapitalization: TextCapitalization.characters,
                              textInputAction: TextInputAction.next,
                              decoration: _field(role.rutLabel),
                              validator: (value) =>
                                  value?.trim().isNotEmpty == true
                                  ? null
                                  : 'Ingresa ${role == PiloLoginRole.coordinator ? 'tu RUT' : 'el RUT del alumno'}.',
                            ),
                            const SizedBox(height: 12),
                            TextFormField(
                              controller: _password,
                              readOnly: _busy,
                              autofillHints: const [AutofillHints.password],
                              autocorrect: false,
                              enableSuggestions: false,
                              obscureText: _obscure,
                              textInputAction: TextInputAction.done,
                              onFieldSubmitted: (_) => _submit(),
                              decoration: _field(
                                'Contraseña',
                                suffix: IconButton(
                                  tooltip: _obscure
                                      ? 'Mostrar contraseña'
                                      : 'Ocultar contraseña',
                                  onPressed: () =>
                                      setState(() => _obscure = !_obscure),
                                  icon: Icon(
                                    _obscure
                                        ? Icons.visibility
                                        : Icons.visibility_off,
                                  ),
                                ),
                              ),
                              validator: (value) => value?.isNotEmpty == true
                                  ? null
                                  : 'Ingresa la contraseña.',
                            ),
                            if (_useSecureStorage)
                              CheckboxListTile(
                                value: _remember,
                                onChanged: _busy
                                    ? null
                                    : (checked) => setState(
                                        () => _remember = checked == true,
                                      ),
                                contentPadding: EdgeInsets.zero,
                                controlAffinity:
                                    ListTileControlAffinity.leading,
                                title: const Text(
                                  'Guardar contraseña en este dispositivo',
                                ),
                              ),
                            if (_message != null)
                              Semantics(
                                liveRegion: true,
                                child: Padding(
                                  padding: const EdgeInsets.only(top: 12),
                                  child: Text(
                                    _message!,
                                    style: const TextStyle(
                                      color: Color(0xFF9C2626),
                                      fontSize: 14,
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(height: 14),
                            FilledButton(
                              onPressed: _busy ? null : _submit,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  vertical: 10,
                                ),
                                child: Text(_busy ? 'Ingresando…' : 'Ingresar'),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    if (role != PiloLoginRole.coordinator) ...[
                      const SizedBox(height: 22),
                      const Text(
                        '¿Es tu primer ingreso?',
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 5),
                      const Text(
                        'Usa los primeros 6 dígitos del RUT del alumno como contraseña inicial. Si ya la cambiaste, usa tu contraseña actual.',
                        style: TextStyle(
                          fontSize: 14,
                          height: 1.45,
                          color: PiloFamilyTheme.secondary,
                        ),
                      ),
                    ],
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
