import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:papigiras_app/design/papigiras_theme.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/pages/welcome.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

class AppDrawerFather extends StatelessWidget {
  final ResponseAttorney login;
  final XFile? imageFile;
  final String? imageUrl;

  const AppDrawerFather({
    Key? key,
    required this.login,
    this.imageFile,
    this.imageUrl,
  }) : super(key: key);
  bool _isBase64(String data) {
    try {
      base64Decode(data.split(',').last);
      return true;
    } catch (_) {
      return false;
    }
  }

  ImageProvider<Object> _resolveImage() {
    if (imageFile != null) {
      return FileImage(File(imageFile!.path));
    }
    if (imageUrl != null && imageUrl!.isNotEmpty) {
      return _isBase64(imageUrl!)
          ? MemoryImage(base64Decode(imageUrl!.split(',').last))
          : NetworkImage(imageUrl!) as ImageProvider<Object>;
    }
    return const AssetImage('assets/profile.jpg');
  }

  Future<void> _sendMessage(String phone, String message) async {
    final whatsappUrl =
        Uri.parse('https://wa.me/$phone?text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(whatsappUrl)) {
      await launchUrl(whatsappUrl, mode: LaunchMode.externalApplication);
      return;
    }
    final direct = Uri.parse(
        'whatsapp://send?phone=$phone&text=${Uri.encodeComponent(message)}');
    if (await canLaunchUrl(direct)) {
      await launchUrl(direct, mode: LaunchMode.externalApplication);
    }
  }

  Future<void> _logout(BuildContext context) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('userRut');
    await prefs.remove('userPassword');
    await prefs.clear();
    if (!context.mounted) return;
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Drawer(
      backgroundColor: PapigirasColors.canvas,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 24),
        children: [
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: PapigirasColors.soft,
              borderRadius: BorderRadius.circular(28),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  radius: 34,
                  backgroundColor: PapigirasColors.surface,
                  backgroundImage: _resolveImage(),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${login.passengerName ?? ''} ${login.passengerApellidos ?? ''}'
                            .trim(),
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        login.passengerIdentificacion ?? '',
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 18),
          ListTile(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: const Icon(Icons.phone_outlined),
            title: const Text('Contactar agencia'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: const <Widget>[
                Icon(Icons.phone, color: PapigirasColors.teal),
                SizedBox(width: 10),
                FaIcon(FontAwesomeIcons.whatsapp, color: PapigirasColors.teal),
              ],
            ),
            onTap: () => _sendMessage('+56932157564', 'Hola! Necesito ayuda'),
          ),
          ListTile(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: const Icon(Icons.report_problem_outlined),
            title: const Text('Reportar un problema'),
            onTap: () => _sendMessage('+56932157564', 'Hola! Necesito ayuda'),
          ),
          const Divider(height: 28),
          ListTile(
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            leading: const Icon(Icons.logout_rounded),
            title: const Text('Cerrar sesión'),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}
