import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:font_awesome_flutter/font_awesome_flutter.dart';
import 'package:image_picker/image_picker.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/pages/welcome.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';
import 'package:quickalert/quickalert.dart';
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
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => WelcomeScreen()),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = CoordinatorProviders();
    return Drawer(
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          // ── Header ──────────────────────────────────────────────────────────
          Container(
            color: Colors.white,
            padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.teal,
                    shape: BoxShape.circle,
                  ),
                  child: CircleAvatar(
                    radius: 40,
                    backgroundImage: _resolveImage(),
                  ),
                ),
                const SizedBox(width: 16),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '${login.passengerName}\n${login.passengerApellidos}',
                      style: const TextStyle(
                        fontSize: 14,
                        color: Colors.black,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      login.passengerIdentificacion ?? '',
                      style: const TextStyle(fontSize: 14, color: Colors.black),
                    ),
                  ],
                ),
              ],
            ),
          ),
          // ── Contactar Agencia ────────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.phone, color: Colors.teal),
            title: Text(
              'Contactar Agencia',
              style: TextStyle(color: Colors.grey[800]),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: const [
                Icon(Icons.phone, color: Colors.teal),
                SizedBox(width: 10),
                Icon(FontAwesomeIcons.whatsapp, color: Colors.teal),
              ],
            ),
            onTap: () => _sendMessage('+56932157564', 'Hola! Necesito ayuda'),
          ),
          // ── Reportar Problema ────────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.report_problem, color: Colors.teal),
            title: Text(
              'Reportar un Problema',
              style: TextStyle(color: Colors.grey[800]),
            ),
            onTap: () => _sendMessage('+56932157564', 'Hola! Necesito ayuda'),
          ),
          // ── Desactivar Cuenta ────────────────────────────────────────────────
          /*
          ListTile(
            leading: const Icon(
              Icons.desktop_access_disabled_outlined,
              color: Colors.teal,
            ),
            title: Text(
              'Desactivar Cuenta',
              style: TextStyle(color: Colors.grey[800]),
            ),
            onTap: () {
              QuickAlert.show(
                context: context,
                type: QuickAlertType.error,
                title: 'Eliminar Cuenta',
                text: 'Desactivar tu cuenta no te permitirá ingresar más',
                confirmBtnText: 'Continuar',
                onConfirmBtnTap: () {
                  provider.desactivateAccount(
                      login.passengerIdentificacion.toString());
                  _logout(context);
                },
              );
            },
          ),
          */
          // ── Cerrar Sesión ────────────────────────────────────────────────────
          ListTile(
            leading: const Icon(Icons.logout, color: Colors.teal),
            title: Text(
              'Cerrar Sesión',
              style: TextStyle(color: Colors.grey[800]),
            ),
            onTap: () => _logout(context),
          ),
        ],
      ),
    );
  }
}
