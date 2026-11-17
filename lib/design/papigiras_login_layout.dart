import 'package:flutter/material.dart';
import 'package:papigiras_app/design/papigiras_theme.dart';

enum PapigirasLoginRole {
  attorney(
    'Apoderado',
    'Acompaña la gira de tu estudiante.',
    Icons.people_alt_outlined,
  ),
  passenger(
    'Alumno',
    'Este acceso es para estudiantes que viajan.',
    Icons.school_outlined,
  ),
  coordinator(
    'Coordinador',
    'Ingresa para gestionar tus giras.',
    Icons.assignment_outlined,
  );

  const PapigirasLoginRole(this.title, this.description, this.icon);

  final String title;
  final String description;
  final IconData icon;
}

/// Presentation-only shell shared by the three production login flows.
/// Authentication, validation, persistence and navigation stay with each page.
class PapigirasLoginLayout extends StatelessWidget {
  const PapigirasLoginLayout({
    super.key,
    required this.role,
    required this.children,
    this.footer,
  });

  final PapigirasLoginRole role;
  final List<Widget> children;
  final Widget? footer;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 470),
            child: ListView(
              keyboardDismissBehavior: ScrollViewKeyboardDismissBehavior.onDrag,
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 28),
              children: [
                Row(
                  children: [
                    IconButton.filledTonal(
                      tooltip: 'Volver a elegir perfil',
                      style: IconButton.styleFrom(
                        minimumSize: const Size.square(52),
                        backgroundColor: PapigirasColors.soft,
                        foregroundColor: PapigirasColors.ink,
                      ),
                      onPressed: () => Navigator.maybePop(context),
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
                    backgroundColor: role == PapigirasLoginRole.attorney
                        ? PapigirasColors.mint
                        : PapigirasColors.soft,
                    foregroundColor: PapigirasColors.ink,
                    child: Icon(role.icon),
                  ),
                ),
                const SizedBox(height: 14),
                Semantics(
                  header: true,
                  child: Text(
                    role.title,
                    style: Theme.of(context).textTheme.displaySmall,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  role.description,
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: PapigirasColors.muted,
                      ),
                ),
                const SizedBox(height: 28),
                ...children,
                if (footer != null) ...[
                  const SizedBox(height: 22),
                  footer!,
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

InputDecoration papigirasLoginField({
  required String label,
  String? hint,
  String? errorText,
  Widget? suffixIcon,
}) {
  return InputDecoration(
    labelText: label,
    hintText: hint,
    errorText: errorText,
    filled: true,
    fillColor: PapigirasColors.soft,
    counterText: '',
    contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 17),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: BorderSide.none,
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: BorderSide.none,
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(22),
      borderSide: const BorderSide(color: PapigirasColors.teal, width: 1.5),
    ),
    suffixIcon: suffixIcon,
  );
}

class PapigirasLoginHint extends StatelessWidget {
  const PapigirasLoginHint({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '¿Es tu primer ingreso?',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 5),
        Text(
          'Usa los primeros 6 dígitos del RUT del alumno como contraseña inicial. Si ya la cambiaste, usa tu contraseña actual.',
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: PapigirasColors.muted,
              ),
        ),
      ],
    );
  }
}
