import 'package:flutter/material.dart';
import 'package:quickalert/models/quickalert_type.dart';
import 'papigiras_design.dart';
export 'package:quickalert/models/quickalert_type.dart';

/// Presentation adapter: existing callbacks and confirmations remain explicit.
abstract final class QuickAlert {
  static Future<void> show({
    required BuildContext context,
    required QuickAlertType type,
    String? title,
    String? text,
    String confirmBtnText = 'Aceptar',
    String cancelBtnText = 'Cancelar',
    VoidCallback? onConfirmBtnTap,
    VoidCallback? onCancelBtnTap,
    Color? confirmBtnColor,
    bool barrierDismissible = true,
    bool disableBackBtn = false,
    bool? showConfirmBtn,
    bool? showCancelBtn,
  }) async {
    final loading = type == QuickAlertType.loading;
    final confirm = type == QuickAlertType.confirm;
    final icon = switch (type) {
      QuickAlertType.success => Icons.check_circle_outline,
      QuickAlertType.error => Icons.error_outline,
      QuickAlertType.warning => Icons.info_outline,
      QuickAlertType.confirm => Icons.help_outline,
      _ => Icons.info_outline,
    };
    await showDialog<void>(
      context: context,
      barrierDismissible: barrierDismissible && !loading,
      animationStyle: MediaQuery.disableAnimationsOf(context)
          ? AnimationStyle.noAnimation
          : null,
      builder: (dialogContext) => PopScope(
        canPop: !disableBackBtn,
        child: AlertDialog(
          scrollable: true,
          icon: loading
              ? const Center(
                  child: SizedBox.square(
                    dimension: 24,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  ),
                )
              : Icon(
                  icon,
                  color: type == QuickAlertType.error
                      ? PapiColors.danger
                      : PapiColors.teal,
                  size: 30,
                ),
          title: title == null || title.isEmpty ? null : Text(title),
          content: text == null || text.isEmpty ? null : Text(text),
          actions: [
            if (showCancelBtn ?? confirm)
              TextButton(
                onPressed: onCancelBtnTap ?? () => Navigator.pop(dialogContext),
                child: Text(cancelBtnText),
              ),
            if (showConfirmBtn ?? !loading)
              TextButton(
                onPressed:
                    onConfirmBtnTap ?? () => Navigator.pop(dialogContext),
                child: Text(confirmBtnText),
              ),
          ],
        ),
      ),
    );
  }
}
