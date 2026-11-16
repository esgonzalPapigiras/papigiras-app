import 'dart:convert';
import 'package:flutter/material.dart';
import 'pilo_family_theme.dart';

enum PiloPasswordChangeResult { updated, updatedWithoutRemembering }

/// API success and saving on this device are separate operations: once the
/// server accepts the new password, a local storage failure must not retry it.
Future<PiloPasswordChangeResult?> showPiloChangePasswordSheet(
  BuildContext context, {
  required Future<void> Function(String current, String next) onChangePassword,
  required Future<void> Function(String next) onUpdateRememberedPassword,
  bool attorneyPassword = false,
}) => showModalBottomSheet<PiloPasswordChangeResult>(
  context: context,
  isScrollControlled: true,
  useSafeArea: true,
  isDismissible: false,
  enableDrag: false,
  backgroundColor: PiloFamilyTheme.paper,
  barrierColor: PiloFamilyTheme.ink.withValues(alpha: .34),
  shape: const RoundedRectangleBorder(
    borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
  ),
  clipBehavior: Clip.antiAlias,
  builder: (context) => Theme(
    data: PiloFamilyTheme.theme(Theme.of(context)),
    child: _PasswordSheet(
      onChangePassword: onChangePassword,
      onUpdateRememberedPassword: onUpdateRememberedPassword,
      attorneyPassword: attorneyPassword,
    ),
  ),
);

void showPiloPasswordChangeFeedback(
  BuildContext context,
  PiloPasswordChangeResult? result,
) {
  if (result == null) return;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      behavior: SnackBarBehavior.floating,
      backgroundColor: PiloFamilyTheme.ink,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      content: Text(
        result == PiloPasswordChangeResult.updated
            ? 'Contraseña actualizada.'
            : 'Contraseña actualizada. No se pudo guardar en este dispositivo; '
                  'ingrésala al iniciar sesión nuevamente.',
      ),
    ),
  );
}

class _PasswordSheet extends StatefulWidget {
  const _PasswordSheet({
    required this.onChangePassword,
    required this.onUpdateRememberedPassword,
    required this.attorneyPassword,
  });
  final Future<void> Function(String current, String next) onChangePassword;
  final Future<void> Function(String next) onUpdateRememberedPassword;
  final bool attorneyPassword;

  @override
  State<_PasswordSheet> createState() => _PasswordSheetState();
}

class _PasswordSheetState extends State<_PasswordSheet> {
  final _form = GlobalKey<FormState>();
  final _current = TextEditingController();
  final _next = TextEditingController();
  final _confirmation = TextEditingController();
  final _hidden = [true, true, true];
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    _current.dispose();
    _next.dispose();
    _confirmation.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    final newPassword = _next.text;
    try {
      await widget.onChangePassword(_current.text, newPassword);
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _saving = false;
        _error = error.toString().replaceFirst('Exception: ', '');
      });
      return;
    }

    var result = PiloPasswordChangeResult.updated;
    try {
      await widget.onUpdateRememberedPassword(newPassword);
    } catch (_) {
      result = PiloPasswordChangeResult.updatedWithoutRemembering;
    }
    if (!mounted) return;
    // Permit the successful close after blocking back navigation while saving.
    setState(() => _saving = false);
    Navigator.of(context).pop(result);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.viewInsetsOf(context).bottom),
      child: SafeArea(
        top: false,
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
          child: Form(
            key: _form,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        'Cambiar contraseña',
                        style: PiloFamilyTheme.display(29),
                      ),
                    ),
                    const SizedBox(width: 8),
                    IconButton.filledTonal(
                      key: const ValueKey('password-close'),
                      tooltip: 'Cerrar',
                      style: IconButton.styleFrom(
                        backgroundColor: PiloFamilyTheme.soft,
                      ),
                      onPressed: _saving
                          ? null
                          : () => Navigator.of(context).pop(),
                      icon: const Icon(Icons.close_rounded),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                Text(
                  widget.attorneyPassword
                      ? 'Esta contraseña es sólo para tu acceso como apoderado.'
                      : 'Elige una contraseña personal para tu cuenta.',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: PiloFamilyTheme.secondary,
                  ),
                ),
                const SizedBox(height: 20),
                _field(
                  index: 0,
                  controller: _current,
                  label: 'Contraseña actual',
                  keyName: 'password-current',
                  validator: (value) => (value ?? '').trim().isEmpty
                      ? 'Ingresa tu contraseña actual.'
                      : null,
                ),
                const SizedBox(height: 12),
                _field(
                  index: 1,
                  controller: _next,
                  label: 'Nueva contraseña',
                  keyName: 'password-new',
                  helper: 'Al menos 6 caracteres',
                  validator: (value) {
                    final password = value ?? '';
                    if (password.trim().isEmpty || password.runes.length < 6) {
                      return 'Usa al menos 6 caracteres.';
                    }
                    if (utf8.encode(password).length > 72) {
                      return 'Esta contraseña es demasiado larga. Usa una más corta.';
                    }
                    if (password == _current.text) {
                      return 'Elige una contraseña diferente a la actual.';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                _field(
                  index: 2,
                  controller: _confirmation,
                  label: 'Repetir nueva contraseña',
                  keyName: 'password-confirmation',
                  validator: (value) => value != _next.text
                      ? 'Las contraseñas no coinciden.'
                      : null,
                ),
                if (_error != null) ...[
                  const SizedBox(height: 14),
                  Semantics(
                    liveRegion: true,
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 20),
                FilledButton.icon(
                  key: const ValueKey('password-save'),
                  onPressed: _saving ? null : _save,
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 16,
                    ),
                  ),
                  icon: _saving
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check_rounded, size: 22),
                  label: Text(_saving ? 'Guardando…' : 'Guardar contraseña'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _field({
    required int index,
    required TextEditingController controller,
    required String label,
    required String keyName,
    required FormFieldValidator<String> validator,
    String? helper,
  }) => TextFormField(
    key: ValueKey(keyName),
    controller: controller,
    enabled: !_saving,
    obscureText: _hidden[index],
    autocorrect: false,
    enableSuggestions: false,
    keyboardType: TextInputType.visiblePassword,
    textInputAction: index == 2 ? TextInputAction.done : TextInputAction.next,
    onFieldSubmitted: index == 2 ? (_) => _save() : null,
    validator: validator,
    decoration: InputDecoration(
      labelText: label,
      helperText: helper,
      errorMaxLines: 3,
      filled: true,
      fillColor: PiloFamilyTheme.soft,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: BorderSide.none,
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: PiloFamilyTheme.accentText),
      ),
      suffixIcon: IconButton(
        tooltip: _hidden[index] ? 'Mostrar $label' : 'Ocultar $label',
        onPressed: _saving
            ? null
            : () => setState(() => _hidden[index] = !_hidden[index]),
        icon: Icon(
          _hidden[index]
              ? Icons.visibility_off_outlined
              : Icons.visibility_outlined,
        ),
      ),
    ),
  );
}
