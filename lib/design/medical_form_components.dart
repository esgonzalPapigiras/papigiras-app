import 'package:flutter/material.dart';

import 'pilo_family_theme.dart';

/// Scoped presentation for the family medical form in all three modes.
class MedicalFormScope extends StatelessWidget {
  const MedicalFormScope({super.key, required this.child});
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final parent = PiloFamilyTheme.theme(Theme.of(context));
    final scheme = parent.colorScheme.copyWith(
      surfaceContainerLow: PiloFamilyTheme.soft,
      surfaceContainerLowest: PiloFamilyTheme.paper,
      outline: const Color(0xFF7E8884),
    );
    final type = parent.textTheme;
    final border = OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: BorderSide(color: scheme.outline),
    );
    final theme = parent.copyWith(
      colorScheme: scheme,
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: scheme.surfaceContainerLowest,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 15,
        ),
        border: border,
        enabledBorder: border,
        focusedBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.primary, width: 2),
        ),
        errorBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.error),
        ),
        focusedErrorBorder: border.copyWith(
          borderSide: BorderSide(color: scheme.error, width: 2),
        ),
        hintStyle: type.bodyLarge?.copyWith(
          color: scheme.onSurfaceVariant,
          fontSize: 17,
        ),
        errorStyle: type.bodyMedium?.copyWith(
          color: scheme.error,
          fontSize: 14,
        ),
        errorMaxLines: 4,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: PiloFamilyTheme.mint,
          foregroundColor: PiloFamilyTheme.ink,
          minimumSize: const Size(48, 52),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(18),
          ),
          textStyle: type.titleMedium?.copyWith(fontSize: 17),
        ),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(minimumSize: const Size(48, 48)),
      ),
    );
    return Theme(
      data: theme,
      child: DefaultTextStyle(style: theme.textTheme.bodyLarge!, child: child),
    );
  }
}

class MedicalFormSection extends StatelessWidget {
  const MedicalFormSection({
    super.key,
    required this.title,
    required this.children,
  });
  final String title;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(top: 28),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Divider(height: 1, color: Theme.of(context).colorScheme.outlineVariant),
        const SizedBox(height: 20),
        Semantics(
          header: true,
          child: Text(title, style: Theme.of(context).textTheme.titleLarge),
        ),
        const SizedBox(height: 16),
        ...children,
      ],
    ),
  );
}

/// One schema and appearance in initial entry, saved view and explicit edit mode.
class MedicalFormReadOnly extends InheritedWidget {
  const MedicalFormReadOnly({
    super.key,
    required this.readOnly,
    required super.child,
  });
  final bool readOnly;
  static bool of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<MedicalFormReadOnly>()
          ?.readOnly ??
      false;
  @override
  bool updateShouldNotify(MedicalFormReadOnly oldWidget) =>
      oldWidget.readOnly != readOnly;
}

class MedicalFormField extends StatelessWidget {
  const MedicalFormField({
    super.key,
    required this.label,
    required this.controller,
    this.validator,
    this.hint,
    this.keyboardType = TextInputType.text,
    this.capitalization = TextCapitalization.sentences,
    this.maxLines = 1,
    this.action = TextInputAction.next,
  });
  final String label;
  final TextEditingController controller;
  final FormFieldValidator<String>? validator;
  final String? hint;
  final TextInputType keyboardType;
  final TextCapitalization capitalization;
  final int maxLines;
  final TextInputAction action;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 7),
        Semantics(
          label: label,
          readOnly: MedicalFormReadOnly.of(context),
          child: MedicalFormReadOnly.of(context)
              ? InputDecorator(
                  decoration: const InputDecoration(),
                  child: Text(
                    controller.text.isEmpty ? 'Sin informar' : controller.text,
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                )
              : TextFormField(
                  controller: controller,
                  validator: validator,
                  autovalidateMode: AutovalidateMode.onUserInteraction,
                  keyboardType: keyboardType,
                  textCapitalization: capitalization,
                  textInputAction: action,
                  minLines: 1,
                  maxLines: maxLines,
                  style: Theme.of(context).textTheme.bodyLarge,
                  decoration: InputDecoration(hintText: hint),
                  // The persistent label is outside; keep its name on the editable node.
                  onTapOutside: (_) =>
                      FocusManager.instance.primaryFocus?.unfocus(),
                  onFieldSubmitted: (_) => action == TextInputAction.next
                      ? FocusScope.of(context).nextFocus()
                      : FocusScope.of(context).unfocus(),
                  scrollPadding: const EdgeInsets.all(28),
                ),
        ),
      ],
    ),
  );
}

class MedicalYesNo extends StatelessWidget {
  const MedicalYesNo({
    super.key,
    required this.label,
    required this.value,
    required this.onChanged,
  });
  final String label;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final scheme = theme.colorScheme;
    final readOnly = MedicalFormReadOnly.of(context);
    final controls = Row(
      children: [
        for (final option in [true, false]) ...[
          if (!option) const SizedBox(width: 8),
          Expanded(
            child: Semantics(
              label: '$label: ${option ? 'Sí' : 'No'}',
              button: true,
              selected: option == value,
              enabled: !readOnly,
              onTap: readOnly ? null : () => onChanged(option),
              child: ExcludeSemantics(
                child: OutlinedButton(
                  key: ValueKey(
                    '${key is ValueKey ? (key as ValueKey).value : label}-${option ? 'yes' : 'no'}',
                  ),
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(48, 48),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 10,
                    ),
                    disabledForegroundColor: value == option
                        ? scheme.onPrimary
                        : scheme.onSurfaceVariant,
                    disabledBackgroundColor: value == option
                        ? scheme.primary
                        : scheme.surfaceContainerLow,
                    foregroundColor: value == option
                        ? scheme.onPrimary
                        : scheme.onSurface,
                    backgroundColor: value == option
                        ? scheme.primary
                        : scheme.surfaceContainerLow,
                    side: BorderSide(
                      color: value == option ? scheme.primary : scheme.outline,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    textStyle: theme.textTheme.bodyLarge,
                  ),
                  onPressed: readOnly ? null : () => onChanged(option),
                  child: Wrap(
                    alignment: WrapAlignment.center,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    spacing: 5,
                    runSpacing: 4,
                    children: [
                      if (option == value) ...[
                        const Icon(Icons.check_rounded, size: 18),
                      ],
                      Text(option ? 'Sí' : 'No'),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ],
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: LayoutBuilder(
        builder: (context, constraints) {
          final text = Text(label, style: theme.textTheme.bodyLarge);
          if (label.length <= 18 &&
              constraints.maxWidth >= 300 &&
              MediaQuery.textScalerOf(context).scale(17) <= 21) {
            return Row(
              children: [
                Expanded(child: text),
                const SizedBox(width: 12),
                SizedBox(width: 184, child: controls),
              ],
            );
          }
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [text, const SizedBox(height: 10), controls],
          );
        },
      ),
    );
  }
}

/// The actions scroll with the content at accessibility sizes; no clipped consent.
class MedicalDecisionDialog extends StatelessWidget {
  const MedicalDecisionDialog({
    super.key,
    required this.title,
    required this.message,
    required this.primaryLabel,
    required this.secondaryLabel,
    this.primaryKey,
  });
  final String title, message, primaryLabel, secondaryLabel;
  final Key? primaryKey;
  @override
  Widget build(BuildContext context) => AlertDialog(
    scrollable: true,
    title: Text(title),
    content: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(message),
        const SizedBox(height: 24),
        FilledButton(
          key: primaryKey,
          onPressed: () => Navigator.pop(context, true),
          child: Text(primaryLabel, textAlign: TextAlign.center),
        ),
        const SizedBox(height: 8),
        TextButton(
          onPressed: () => Navigator.pop(context, false),
          child: Text(secondaryLabel, textAlign: TextAlign.center),
        ),
      ],
    ),
  );
}
