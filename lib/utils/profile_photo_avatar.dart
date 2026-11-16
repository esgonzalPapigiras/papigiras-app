import 'package:papigiras_app/lab/media_data.dart';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:papigiras_app/dto/responseAttorney.dart';
import 'package:papigiras_app/lab/media.dart';
import 'package:papigiras_app/provider/coordinatorProvider.dart';

/// One photo editor for the passenger shown to families/students and for the
/// signed-in coordinator. All persistence uses the existing local API.
class ProfilePhotoAvatar extends StatefulWidget {
  const ProfilePhotoAvatar({
    super.key,
    required this.radius,
    this.passenger,
    this.provider,
    this.pickImage,
    this.onOpenProfile,
    this.showEditBadge = true,
  });

  final double radius;

  /// A compact profile shortcut can defer photo editing to the profile page.
  final bool showEditBadge;

  /// Optional coordinator shortcut. The camera remains a separate edit action.
  /// Passenger avatars keep their existing photo-edit behavior.
  final VoidCallback? onOpenProfile;
  // The family dashboard shows the passenger's profile, not a separate parent.
  // A null passenger means the authenticated coordinator's own profile.
  final ResponseAttorney? passenger;
  @visibleForTesting
  final CoordinatorProviders? provider;
  @visibleForTesting
  final Future<XFile?> Function()? pickImage;

  @override
  State<ProfilePhotoAvatar> createState() => _ProfilePhotoAvatarState();
}

class _ProfilePhotoAvatarState extends State<ProfilePhotoAvatar> {
  // Invalidate visible profile/menu copies after a successful upload. No image
  // or credentials are kept in this shared notification.
  static final _photoChanges = ValueNotifier<int>(0);
  late final CoordinatorProviders _provider;
  Uint8List? _bytes;
  bool _saving = false;
  int _request = 0;

  @override
  void initState() {
    super.initState();
    _provider = widget.provider ?? CoordinatorProviders();
    _photoChanges.addListener(_reload);
    _load();
  }

  @override
  void didUpdateWidget(covariant ProfilePhotoAvatar oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.passenger?.passengerId != widget.passenger?.passengerId ||
        oldWidget.passenger?.tourId != widget.passenger?.tourId) {
      _bytes = null;
      _load();
    }
  }

  @override
  void dispose() {
    _photoChanges.removeListener(_reload);
    if (widget.provider == null) _provider.dispose();
    super.dispose();
  }

  void _reload() {
    if (!_saving) _load();
  }

  Future<void> _load() async {
    final request = ++_request;
    try {
      final passenger = widget.passenger;
      final Uint8List? bytes;
      if (passenger == null) {
        bytes = await _provider.getCoordinatorPicture();
      } else {
        final result = await _provider.getPicturePassenger(
          passenger.passengerIdentificacion.toString(),
          passenger.tourId.toString(),
        );
        bytes = LocalImageData.decode(result.image);
      }
      if (mounted && request == _request) setState(() => _bytes = bytes);
    } catch (_) {
      // Keep the last displayed photo on a read failure. Upload failures are
      // reported explicitly below; a failed upload never replaces the photo.
    }
  }

  Future<void> _changePhoto() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final image =
          await (widget.pickImage?.call() ??
              ImagePicker().pickImage(source: ImageSource.gallery));
      if (image == null || !mounted) return;
      final bytes = await image.readAsBytes();
      if (!mounted) return;
      ++_request;
      final passenger = widget.passenger;
      if (passenger == null) {
        await _provider.updateCoordinatorPicture(image);
      } else {
        await _provider.addHitoFotoPassenger(
          passenger.passengerId.toString(),
          passenger.tourId.toString(),
          image,
        );
      }
      _photoChanges.value++;
      if (!mounted) return;
      setState(() => _bytes = bytes);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Foto de perfil actualizada')),
      );
    } on PlatformException catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            error.code.contains('access_denied')
                ? 'Permite el acceso a Fotos en Configuración para cambiar tu foto.'
                : 'No se pudo abrir la foto. Inténtalo de nuevo.',
          ),
        ),
      );
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo guardar la foto. Inténtalo de nuevo.'),
        ),
      );
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final label = _saving
        ? 'Actualizando foto de perfil'
        : 'Cambiar foto de perfil';
    final badgeSize = widget.radius >= 80 ? 44.0 : 36.0;
    if (widget.passenger == null && widget.onOpenProfile != null) {
      return _buildProfileShortcut(label, badgeSize);
    }
    return Tooltip(
      message: label,
      excludeFromSemantics: true,
      child: Semantics(
        button: true,
        enabled: !_saving,
        label: label,
        onTap: _saving ? null : _changePhoto,
        child: ExcludeSemantics(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              onTap: _saving ? null : _changePhoto,
              customBorder: const CircleBorder(),
              child: SizedBox.square(
                dimension: widget.radius * 2,
                child: Stack(
                  children: [
                    _buildAvatarImage(),
                    Positioned(
                      right: widget.radius * 0.04,
                      bottom: widget.radius * 0.04,
                      child: _buildCameraBadge(badgeSize),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildAvatarImage() => CircleAvatar(
    radius: widget.radius,
    backgroundImage: _bytes == null
        ? const AssetImage('assets/profile.jpg')
        : MemoryImage(_bytes!) as ImageProvider,
  );

  Widget _buildCameraBadge(double badgeSize) => Container(
    width: badgeSize,
    height: badgeSize,
    decoration: BoxDecoration(
      color: Colors.teal,
      shape: BoxShape.circle,
      border: Border.all(color: Colors.white, width: 3),
      boxShadow: const [
        BoxShadow(
          color: Color(0x26000000),
          blurRadius: 4,
          offset: Offset(0, 2),
        ),
      ],
    ),
    child: Center(
      child: _saving
          ? const SizedBox.square(
              dimension: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: Colors.white,
              ),
            )
          : Icon(
              Icons.camera_alt_rounded,
              size: badgeSize * 0.5,
              color: Colors.white,
            ),
    ),
  );

  Widget _buildProfileShortcut(String photoLabel, double badgeSize) {
    final openProfile = _saving ? null : widget.onOpenProfile;
    return SizedBox.square(
      dimension: widget.radius * 2,
      child: Stack(
        children: [
          Positioned.fill(
            child: Tooltip(
              message: 'Abrir mi perfil',
              excludeFromSemantics: true,
              child: Semantics(
                button: true,
                enabled: !_saving,
                label: 'Abrir mi perfil',
                onTap: openProfile,
                child: ExcludeSemantics(
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      customBorder: const CircleBorder(),
                      onTap: openProfile,
                      child: _buildAvatarImage(),
                    ),
                  ),
                ),
              ),
            ),
          ),
          if (widget.showEditBadge)
            Positioned(
              right: widget.radius * 0.04 - (44 - badgeSize) / 2,
              bottom: widget.radius * 0.04 - (44 - badgeSize) / 2,
              child: ClipOval(
                child: Tooltip(
                  message: photoLabel,
                  excludeFromSemantics: true,
                  child: Semantics(
                    button: true,
                    enabled: !_saving,
                    label: photoLabel,
                    onTap: _saving ? null : _changePhoto,
                    child: ExcludeSemantics(
                      child: Material(
                        color: Colors.transparent,
                        child: InkWell(
                          onTap: _saving ? null : _changePhoto,
                          customBorder: const CircleBorder(),
                          child: SizedBox.square(
                            dimension: 44,
                            child: Center(child: _buildCameraBadge(badgeSize)),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
