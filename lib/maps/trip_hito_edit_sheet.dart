import 'package:flutter/material.dart';
import 'package:papigiras_app/dto/DetailHitoList.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/maps/hito_location_draft.dart';
import 'package:papigiras_app/maps/pilo_hito_location_picker.dart';

/// Edits text and, when explicitly selected, the location of the same hito.
/// IDs, author, date and attachments remain outside this form.
class TripHitoEditSheet extends StatefulWidget {
  const TripHitoEditSheet({
    super.key,
    required this.detail,
    required this.onSave,
    this.initialLocation,
    this.onSaveWithLocation,
    this.locationNeedsConfirmation = false,
  });
  final DetailHitoList detail;
  final HitoLocationDraft? initialLocation;
  final bool locationNeedsConfirmation;
  final Future<void> Function(
    String title,
    String description,
    String closingNote,
    HitoLocationDraft? location,
  )?
  onSaveWithLocation;
  final Future<void> Function(
    String title,
    String description,
    String closingNote,
  )
  onSave;

  @override
  State<TripHitoEditSheet> createState() => _TripHitoEditSheetState();
}

class _TripHitoEditSheetState extends State<TripHitoEditSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _title;
  late final TextEditingController _description;
  late final TextEditingController _closing;
  bool _saving = false;
  bool _completed = false;
  bool _choosingLocation = false;
  HitoLocationDraft? _changedLocation;
  String? _error;

  @override
  void initState() {
    super.initState();
    _title = TextEditingController(text: widget.detail.titulo ?? '');
    _description = TextEditingController(text: widget.detail.descripcion ?? '');
    _closing = TextEditingController(text: widget.detail.notaCierre ?? '');
  }

  @override
  void dispose() {
    _title.dispose();
    _description.dispose();
    _closing.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    if (_saving ||
        _completed ||
        _choosingLocation ||
        !_form.currentState!.validate())
      return;
    FocusScope.of(context).unfocus();
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      if (widget.onSaveWithLocation case final save?) {
        await save(
          _title.text.trim(),
          _description.text.trim(),
          _closing.text.trim(),
          _changedLocation,
        );
      } else {
        await widget.onSave(
          _title.text.trim(),
          _description.text.trim(),
          _closing.text.trim(),
        );
      }
      if (!mounted) return;
      // Unlock PopScope before closing the sheet after a successful operation.
      setState(() {
        _saving = false;
        _completed = true;
      });
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) Navigator.of(context).pop(true);
      });
    } catch (_) {
      if (mounted)
        setState(() {
          _saving = false;
          _error =
              'No pudimos guardar los cambios. Tu borrador sigue aquí; vuelve a intentarlo.';
        });
    }
  }

  Future<void> _adjustLocation() async {
    final initial = _changedLocation ?? widget.initialLocation;
    if (_saving || _completed || _choosingLocation || initial == null) return;
    FocusScope.of(context).unfocus();
    setState(() => _choosingLocation = true);
    try {
      final selected = await showPiloHitoLocationPicker(
        context,
        initial: initial,
      );
      if (mounted && selected != null) {
        setState(
          () => _changedLocation =
              !widget.locationNeedsConfirmation &&
                  selected.point == widget.initialLocation?.point
              ? null
              : selected,
        );
      }
    } finally {
      if (mounted) setState(() => _choosingLocation = false);
    }
  }

  Widget _codePointCounter(String value) {
    final length = value.trim().runes.length;
    return Text(
      '$length / 255',
      semanticsLabel: '$length de 255 caracteres',
      style: TextStyle(
        color: length > 255
            ? const Color(0xFF9D2525)
            : PiloFamilyTheme.secondary,
      ),
    );
  }

  InputDecoration _decoration(String label) => InputDecoration(
    labelText: label,
    alignLabelWithHint: true,
    filled: true,
    fillColor: PiloFamilyTheme.soft,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: PiloFamilyTheme.hairline),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: PiloFamilyTheme.accentText, width: 2),
    ),
  );

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving && !_choosingLocation,
    child: SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          bottom: MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(22, 22, 22, 24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              mainAxisSize: MainAxisSize.min,
              children: [
                Semantics(
                  header: true,
                  child: Text(
                    'Editar hito',
                    style: PiloFamilyTheme.display(34),
                  ),
                ),
                const SizedBox(height: 24),
                TextFormField(
                  key: const ValueKey('hito-edit-title'),
                  controller: _title,
                  enabled: !_saving && !_completed,
                  textCapitalization: TextCapitalization.sentences,
                  textInputAction: TextInputAction.next,
                  maxLength: 255,
                  buildCounter:
                      (
                        context, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => _codePointCounter(_title.text),
                  decoration: _decoration('Título'),
                  validator: (value) {
                    if (value?.trim().isNotEmpty != true)
                      return 'Escribe un título.';
                    if (value!.trim().runes.length > 255)
                      return 'Usa hasta 255 caracteres.';
                    return null;
                  },
                ),
                const SizedBox(height: 18),
                TextFormField(
                  key: const ValueKey('hito-edit-description'),
                  controller: _description,
                  enabled: !_saving && !_completed,
                  minLines: 3,
                  maxLines: 5,
                  maxLength: 140,
                  buildCounter:
                      (
                        context, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) {
                        final length = _description.text.trim().length;
                        return Text(
                          '$length / 140',
                          semanticsLabel: '$length de 140 caracteres',
                          style: TextStyle(
                            color: length > 140
                                ? const Color(0xFF9D2525)
                                : PiloFamilyTheme.secondary,
                          ),
                        );
                      },
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  decoration: _decoration('Descripción'),
                  validator: (value) {
                    if (value?.trim().isNotEmpty != true)
                      return 'Escribe una descripción.';
                    if (value!.trim().length > 140)
                      return 'Usa hasta 140 caracteres.';
                    return null;
                  },
                ),
                const SizedBox(height: 12),
                TextFormField(
                  key: const ValueKey('hito-edit-closing'),
                  controller: _closing,
                  enabled: !_saving && !_completed,
                  minLines: 2,
                  maxLines: 5,
                  textCapitalization: TextCapitalization.sentences,
                  keyboardType: TextInputType.multiline,
                  maxLength: 255,
                  buildCounter:
                      (
                        context, {
                        required currentLength,
                        required isFocused,
                        maxLength,
                      }) => _codePointCounter(_closing.text),
                  decoration: _decoration('Nota de cierre (opcional)'),
                  validator: (value) => (value ?? '').trim().runes.length > 255
                      ? 'Usa hasta 255 caracteres.'
                      : null,
                ),
                if (widget.onSaveWithLocation != null &&
                    widget.initialLocation != null) ...[
                  const SizedBox(height: 12),
                  OutlinedButton.icon(
                    key: const ValueKey('hito-edit-location'),
                    onPressed: _saving || _completed || _choosingLocation
                        ? null
                        : _adjustLocation,
                    style: OutlinedButton.styleFrom(
                      foregroundColor: PiloFamilyTheme.accentText,
                      backgroundColor: PiloFamilyTheme.soft,
                      side: BorderSide.none,
                      minimumSize: const Size(0, 52),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    icon: const Icon(Icons.edit_location_alt_outlined),
                    label: Text(
                      _changedLocation == null
                          ? 'Ajustar ubicación en el mapa'
                          : 'Ubicación ajustada · Revisar',
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _changedLocation?.label ?? widget.initialLocation!.label,
                    style: const TextStyle(
                      fontSize: 12,
                      color: PiloFamilyTheme.secondary,
                    ),
                  ),
                ],
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Semantics(
                      liveRegion: true,
                      child: Text(
                        _error!,
                        style: const TextStyle(
                          color: Color(0xFF9D2525),
                          height: 1.4,
                        ),
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  key: const ValueKey('hito-edit-save'),
                  onPressed: _saving || _completed ? null : _save,
                  style: FilledButton.styleFrom(
                    backgroundColor: PiloFamilyTheme.mint,
                    foregroundColor: PiloFamilyTheme.ink,
                    shape: const StadiumBorder(),
                    minimumSize: const Size(0, 48),
                  ),
                  icon: _saving
                      ? const SizedBox.square(
                          dimension: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.check),
                  label: Text(_saving ? 'Guardando…' : 'Guardar cambios'),
                ),
                const SizedBox(height: 8),
                TextButton(
                  key: const ValueKey('hito-edit-cancel'),
                  onPressed: _saving || _completed
                      ? null
                      : () => Navigator.of(context).pop(false),
                  style: TextButton.styleFrom(
                    foregroundColor: PiloFamilyTheme.secondary,
                    minimumSize: const Size(0, 48),
                  ),
                  child: const Text('Cancelar'),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}
