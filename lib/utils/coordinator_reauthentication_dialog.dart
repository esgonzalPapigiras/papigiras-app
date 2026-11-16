import 'package:flutter/material.dart';
import '../design/pilo_family_theme.dart';
import '../dto/TourSales.dart';
import '../provider/coordinatorProvider.dart';

/// Renew the same coordinator without replacing the composing route or draft.
class CoordinatorReauthenticationDialog extends StatefulWidget {
  const CoordinatorReauthenticationDialog({
    super.key,
    required this.provider,
    required this.expectedTour,
  });
  final CoordinatorProviders provider;
  final TourSales expectedTour;
  @override
  State<CoordinatorReauthenticationDialog> createState() =>
      _ReauthenticationState();
}

class _ReauthenticationState extends State<CoordinatorReauthenticationDialog> {
  final _form = GlobalKey<FormState>();
  final _rut = TextEditingController();
  final _password = TextEditingController();
  bool _busy = false, _completed = false;
  String? _error;
  Future<void> _submit() async {
    if (_busy || _completed || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await widget.provider.reauthenticateHitoDraft(
        rut: _rut.text.trim(),
        password: _password.text,
        expectedTour: widget.expectedTour,
      );
      if (!mounted) return;
      _password.clear();
      setState(() {
        _completed = true;
        _busy = false;
      });
      await WidgetsBinding.instance.endOfFrame;
      if (mounted) Navigator.of(context).pop(true);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _busy = false;
        _error = error is CoordinatorReauthenticationException
            ? error.message
            : 'No pudimos renovar la sesión. Revisa el RUT y la contraseña e inténtalo de nuevo.';
      });
    }
  }

  @override
  void dispose() {
    _rut.dispose();
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: PiloFamilyTheme.theme(Theme.of(context)),
    child: PopScope(
      canPop: !_busy,
      child: AlertDialog(
        key: const ValueKey('hito-reauth-dialog'),
        backgroundColor: PiloFamilyTheme.paper,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
        insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
        titlePadding: const EdgeInsets.fromLTRB(24, 28, 24, 12),
        contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
        actionsPadding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
        title: Text('Vuelve a ingresar', style: PiloFamilyTheme.display(26)),
        content: SingleChildScrollView(
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Tu sesión venció. Ingresa con la misma cuenta de coordinación. Tu hito sigue aquí.',
                  style: TextStyle(
                    fontFamily: 'Inter',
                    fontSize: 14,
                    height: 1.4,
                    color: PiloFamilyTheme.secondary,
                  ),
                ),
                const SizedBox(height: 16),
                TextFormField(
                  key: const ValueKey('hito-reauth-rut'),
                  controller: _rut,
                  enabled: !_busy && !_completed,
                  autocorrect: false,
                  decoration: _fieldDecoration('RUT'),
                  textInputAction: TextInputAction.next,
                  validator: (value) =>
                      (value ?? '').trim().isEmpty ? 'Ingresa tu RUT' : null,
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('hito-reauth-password'),
                  controller: _password,
                  enabled: !_busy && !_completed,
                  obscureText: true,
                  autocorrect: false,
                  enableSuggestions: false,
                  decoration: _fieldDecoration('Contraseña'),
                  textInputAction: TextInputAction.done,
                  onFieldSubmitted: (_) => _submit(),
                  validator: (value) =>
                      (value ?? '').isEmpty ? 'Ingresa tu contraseña' : null,
                ),
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        actions: [
          TextButton(
            key: const ValueKey('hito-reauth-cancel'),
            onPressed: _busy || _completed
                ? null
                : () => Navigator.of(context).pop(false),
            style: TextButton.styleFrom(
              foregroundColor: PiloFamilyTheme.accentText,
              minimumSize: const Size(48, 48),
            ),
            child: const Text('Ahora no'),
          ),
          FilledButton(
            key: const ValueKey('hito-reauth-submit'),
            style: FilledButton.styleFrom(
              backgroundColor: PiloFamilyTheme.mint,
              foregroundColor: PiloFamilyTheme.ink,
            ),
            onPressed: _busy || _completed ? null : _submit,
            child: _busy
                ? const SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: PiloFamilyTheme.ink,
                    ),
                  )
                : const Text('Ingresar'),
          ),
        ],
      ),
    ),
  );

  InputDecoration _fieldDecoration(String label) => InputDecoration(
    labelText: label,
    filled: true,
    fillColor: PiloFamilyTheme.soft,
    contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
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
