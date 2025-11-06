import 'dart:io';

import 'package:device_info_plus/device_info_plus.dart';
import 'package:flutter/material.dart';
import 'package:photo_view/photo_view.dart';
import 'package:image_gallery_saver_plus/image_gallery_saver_plus.dart';
import 'package:permission_handler/permission_handler.dart';
import 'dart:typed_data';

class FullscreenImagePage extends StatefulWidget {
  final Uint8List imageBytes;

  const FullscreenImagePage({
    Key? key,
    required this.imageBytes,
  }) : super(key: key);

  @override
  State<FullscreenImagePage> createState() => _FullscreenImagePageState();
}

class _FullscreenImagePageState extends State<FullscreenImagePage> {
  bool _saving = false;

  Future<void> _saveImage() async {
    setState(() => _saving = true);

    try {
      // Detectar versión de Android
      if (Platform.isAndroid) {
        final deviceInfo = DeviceInfoPlugin();
        final androidInfo = await deviceInfo.androidInfo;
        int sdkInt = androidInfo.version.sdkInt ?? 0;

        if (sdkInt < 33) {
          // Android <13 necesita permiso de almacenamiento
          PermissionStatus status = await Permission.storage.status;

          if (status.isDenied || status.isLimited) {
            PermissionStatus newStatus = await Permission.storage.request();
            if (!newStatus.isGranted) {
              if (newStatus.isPermanentlyDenied) {
                openAppSettings();
              }
              setState(() => _saving = false);
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                    content: Text('Permiso denegado para guardar imagen')),
              );
              return;
            }
          }
        }
        // Android 13+ no necesita permiso de almacenamiento (usa el sistema de medios)
      } else if (Platform.isIOS) {
        // En iOS, sigue siendo necesario el permiso de fotos
        PermissionStatus status = await Permission.photos.request();
        if (!status.isGranted) {
          setState(() => _saving = false);
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Permiso denegado para guardar imagen')),
          );
          return;
        }
      }

      // Guardar imagen
      final result = await ImageGallerySaverPlus.saveImage(
        widget.imageBytes,
        quality: 100,
        name: 'hito_${DateTime.now().millisecondsSinceEpoch}',
      );

      setState(() => _saving = false);

      if (result['isSuccess'] == true) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Imagen guardada en la galería')),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Error al guardar la imagen')),
        );
      }
    } catch (e) {
      setState(() => _saving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          PhotoView(
            imageProvider: MemoryImage(widget.imageBytes),
            minScale: PhotoViewComputedScale.contained,
            maxScale: PhotoViewComputedScale.covered * 4,
            backgroundDecoration: const BoxDecoration(color: Colors.black),
          ),
          // Close button
          Positioned(
            top: 40,
            left: 16,
            child: IconButton(
              icon: const Icon(Icons.close, color: Colors.white, size: 30),
              onPressed: () => Navigator.of(context).pop(),
            ),
          ),
          // Download button
          Positioned(
            top: 40,
            right: 16,
            child: _saving
                ? const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : IconButton(
                    icon: const Icon(Icons.download,
                        color: Colors.white, size: 30),
                    onPressed: _saveImage,
                  ),
          ),
        ],
      ),
    );
  }
}
