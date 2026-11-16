import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../design/pilo_family_theme.dart';
import '../dto/responseAttorney.dart';
import '../lab/preferences.dart';
import '../lab/session.dart';
import '../provider/coordinatorProvider.dart';

Future<bool>? _activeRecovery;

/// Confirm a legacy family login in place. Only the server grants the new role;
/// cancelling or a rejected password leaves the existing session untouched.
Future<bool> reauthenticatePhotoLikes(
  BuildContext context, {
  required int tourId,
  CoordinatorProviders? provider,
}) {
  if (_activeRecovery != null) return _activeRecovery!;
  final recovery = _showRecovery(context, tourId, provider);
  _activeRecovery = recovery;
  recovery.whenComplete(() {
    if (identical(_activeRecovery, recovery)) _activeRecovery = null;
  });
  return recovery;
}

Future<bool> _showRecovery(
  BuildContext context,
  int tourId,
  CoordinatorProviders? provider,
) async {
  CoordinatorProviders? ownedProvider;
  try {
    final generation = LabSession.generation;
    final prefs = await SharedPreferences.getInstance();
    final expiry = DateTime.tryParse(prefs.getString('tokenExpiry') ?? '');
    if (generation != LabSession.generation ||
        prefs.getString('userRole') != 'father' ||
        prefs.getBool('isLoggedIn') != true ||
        (prefs.getString('token') ?? '').isEmpty ||
        expiry == null ||
        !expiry.isAfter(DateTime.now()))
      return false;
    final raw = jsonDecode(prefs.getString('loginData') ?? '');
    if (raw is! Map<String, dynamic>) return false;
    final current = ResponseAttorney.fromJson(raw);
    if ((current.passengerId ?? 0) <= 0 ||
        current.tourId != tourId ||
        (current.passengerIdentificacion ?? '').trim().isEmpty ||
        !context.mounted)
      return false;
    final loginProvider = provider ?? (ownedProvider = CoordinatorProviders());
    return await showDialog<bool>(
          context: context,
          barrierDismissible: false,
          builder: (_) => _RecoveryDialog(
            provider: loginProvider,
            current: current,
            expectedGeneration: generation,
          ),
        ) ??
        false;
  } catch (_) {
    return false;
  } finally {
    ownedProvider?.dispose();
  }
}

class _RecoveryDialog extends StatefulWidget {
  const _RecoveryDialog({
    required this.provider,
    required this.current,
    required this.expectedGeneration,
  });
  final CoordinatorProviders provider;
  final ResponseAttorney current;
  final int expectedGeneration;
  @override
  State<_RecoveryDialog> createState() => _RecoveryDialogState();
}

class _RecoveryDialogState extends State<_RecoveryDialog> {
  final _form = GlobalKey<FormState>();
  final _password = TextEditingController();
  late final _rut = TextEditingController(
    text: widget.current.passengerIdentificacion,
  );
  bool _busy = false;
  bool _showPassword = false;
  String? _error;

  Future<void> _submit() async {
    if (_busy || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      final login = await widget.provider.validateLoginUserFather(
        _rut.text,
        _password.text,
      );
      if (!mounted) return;
      if (login == null ||
          login.passengerId != widget.current.passengerId ||
          login.tourId != widget.current.tourId ||
          login.isActive != true ||
          (login.tokenKey ?? '').isEmpty) {
        throw const FormatException('No se pudo confirmar esta cuenta.');
      }
      await LabSession.renewAttorney(
        login: login,
        expectedPassengerId: widget.current.passengerId!,
        expectedTourId: widget.current.tourId!,
        expectedGeneration: widget.expectedGeneration,
      );
      if (!mounted) return;
      TextInput.finishAutofillContext(shouldSave: true);
      _password.clear();
      setState(() => _busy = false);
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = widget.expectedGeneration != LabSession.generation
            ? 'Tu sesión cambió. Cierra esta ventana y vuelve a intentarlo.'
            : 'No pudimos confirmar tu contraseña. Revísala e inténtalo de nuevo.';
      });
    }
  }

  @override
  void dispose() {
    _password.clear();
    _password.dispose();
    _rut.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: PiloFamilyTheme.theme(Theme.of(context)),
    child: PopScope(
      canPop: !_busy,
      child: AlertDialog(
        key: const ValueKey('photo-likes-reauth-dialog'),
        backgroundColor: PiloFamilyTheme.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        titlePadding: const EdgeInsets.fromLTRB(24, 24, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
        actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        title: Text('Activa tus Me gusta', style: PiloFamilyTheme.display(26)),
        content: SingleChildScrollView(
          child: AutofillGroup(
            onDisposeAction: AutofillContextAction.cancel,
            child: Form(
              key: _form,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'Confirma tu contraseña una vez para actualizar tu sesión. Seguirás viendo tus fotos aquí.',
                    style: TextStyle(
                      fontFamily: 'Inter',
                      fontSize: 14,
                      height: 1.4,
                      color: PiloFamilyTheme.secondary,
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    key: const ValueKey('photo-likes-reauth-rut'),
                    controller: _rut,
                    readOnly: true,
                    autofillHints: const [AutofillHints.username],
                    decoration: _decoration('RUT del alumno'),
                  ),
                  const SizedBox(height: 10),
                  TextFormField(
                    key: const ValueKey('photo-likes-reauth-password'),
                    controller: _password,
                    enabled: !_busy,
                    obscureText: !_showPassword,
                    autocorrect: false,
                    enableSuggestions: false,
                    autofillHints: const [AutofillHints.password],
                    textInputAction: TextInputAction.done,
                    onFieldSubmitted: (_) => _submit(),
                    validator: (value) =>
                        (value ?? '').isEmpty ? 'Ingresa tu contraseña' : null,
                    decoration: _decoration('Contraseña').copyWith(
                      suffixIcon: IconButton(
                        tooltip: _showPassword
                            ? 'Ocultar contraseña'
                            : 'Mostrar contraseña',
                        onPressed: _busy
                            ? null
                            : () => setState(
                                () => _showPassword = !_showPassword,
                              ),
                        icon: Icon(
                          _showPassword
                              ? Icons.visibility_off_outlined
                              : Icons.visibility_outlined,
                        ),
                      ),
                    ),
                  ),
                  if (_error != null)
                    Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: Semantics(
                        liveRegion: true,
                        child: Text(
                          _error!,
                          style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('photo-likes-reauth-cancel'),
            onPressed: _busy ? null : () => Navigator.of(context).pop(false),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            key: const ValueKey('photo-likes-reauth-submit'),
            onPressed: _busy ? null : _submit,
            child: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: PiloFamilyTheme.ink,
                    ),
                  )
                : const Text('Confirmar'),
          ),
        ],
      ),
    ),
  );

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: PiloFamilyTheme.soft,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(20),
      borderSide: const BorderSide(color: PiloFamilyTheme.accentText),
    ),
  );
}
