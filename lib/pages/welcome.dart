import 'package:flutter/material.dart';
import 'package:papigiras_app/design/pilo_family_theme.dart';
import 'package:papigiras_app/pages/alumns/loginpassenger.dart';
import 'package:papigiras_app/pages/attorney/loginFather.dart';
import 'package:papigiras_app/pages/coordinator/loginCoordinator.dart';
import 'package:papigiras_app/utils/session_utils.dart';

class WelcomeScreen extends StatefulWidget {
  const WelcomeScreen({super.key});

  @override
  State<WelcomeScreen> createState() => _WelcomeScreenState();
}

class _WelcomeScreenState extends State<WelcomeScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) checkLoginStatus(context, replace: false);
    });
  }

  void _openProfile(WidgetBuilder builder) {
    Navigator.of(context).push(MaterialPageRoute<void>(builder: builder));
  }

  @override
  Widget build(BuildContext context) => Theme(
    data: PiloFamilyTheme.theme(Theme.of(context)),
    child: Scaffold(
      body: SafeArea(
        child: Align(
          alignment: Alignment.topCenter,
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 520),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
              children: [
                Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: Image.asset(
                    'assets/logo-letras-papigiras.png',
                    width: 148,
                    semanticLabel: 'PapiGiras',
                  ),
                ),
                const SizedBox(height: 28),
                Semantics(
                  header: true,
                  child: Text(
                    'Elige tu perfil',
                    style: PiloFamilyTheme.display(50),
                  ),
                ),
                const SizedBox(height: 24),
                _ProfileChoice(
                  title: 'Apoderado',
                  description: 'Sigo la gira de un estudiante',
                  icon: Icons.people_alt_outlined,
                  primary: true,
                  onTap: () => _openProfile((_) => LoginFather()),
                ),
                const SizedBox(height: 10),
                _ProfileChoice(
                  title: 'Alumno',
                  description: 'Viajo con mi colegio',
                  icon: Icons.school_outlined,
                  onTap: () => _openProfile((_) => LoginPassenger()),
                ),
                const SizedBox(height: 10),
                _ProfileChoice(
                  title: 'Coordinador',
                  description: 'Gestiono una gira asignada',
                  icon: Icons.assignment_outlined,
                  onTap: () => _openProfile((_) => LoginCoordinator()),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

class _ProfileChoice extends StatelessWidget {
  const _ProfileChoice({
    required this.title,
    required this.description,
    required this.icon,
    required this.onTap,
    this.primary = false,
  });

  final String title;
  final String description;
  final IconData icon;
  final VoidCallback onTap;
  final bool primary;

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final detail = primary ? PiloFamilyTheme.ink : PiloFamilyTheme.secondary;
    return MergeSemantics(
      child: Semantics(
        button: true,
        child: Material(
          color: primary ? PiloFamilyTheme.mint : PiloFamilyTheme.soft,
          borderRadius: BorderRadius.circular(30),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Row(
                children: [
                  ExcludeSemantics(
                    child: CircleAvatar(
                      radius: 22,
                      foregroundColor: PiloFamilyTheme.ink,
                      backgroundColor: PiloFamilyTheme.paper,
                      child: Icon(icon, size: 21),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: text.titleLarge),
                        const SizedBox(height: 4),
                        Text(
                          description,
                          style: text.bodyMedium?.copyWith(color: detail),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  const ExcludeSemantics(
                    child: Icon(
                      Icons.arrow_forward_rounded,
                      size: 21,
                      color: PiloFamilyTheme.ink,
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
