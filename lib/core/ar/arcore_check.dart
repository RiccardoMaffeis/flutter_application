import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

enum PopupType { info, success, warning, error }

class ArCoreCheck {
  static const _ch = MethodChannel('arcore/check');

  static Future<String> checkAvailability() async {
    final res = await _ch.invokeMethod<String>('checkAvailability');
    return res ?? 'UNKNOWN';
  }

  static Future<String?> requestInstall({
    bool userRequestedInstall = true,
  }) async {
    return await _ch.invokeMethod<String>('requestInstall', {
      'userRequestedInstall': userRequestedInstall,
    });
  }

  static Future<void> openPlayStore() async {
    try {
      await _ch.invokeMethod('openPlayStore');
    } catch (_) {}
  }

  static Future<void> showAutoDismissPopup(
    BuildContext context, {
    required String title,
    required String message,
    PopupType type = PopupType.info,
    Duration duration = const Duration(seconds: 2),
  }) async {
    final (iconData, iconColor) = switch (type) {
      PopupType.error => (Icons.error_outline, Colors.red),
      PopupType.warning => (Icons.warning_amber_outlined, Colors.orange),
      PopupType.success => (Icons.check_circle_outline, Colors.green),
      PopupType.info => (Icons.info_outline, Colors.blue),
    };

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        icon: Icon(iconData, color: iconColor, size: 32), 
        title: Text(title),
        content: Text(message),
      ),
    );

    await Future.delayed(duration);
    if (!context.mounted) return;
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) nav.pop();
  }

  static Future<bool> ensureAvailable(BuildContext context) async {
    String status = await checkAvailability();

    if (status == 'UNKNOWN_CHECKING' || status == 'UNKNOWN_TIMED_OUT') {
      await Future.delayed(const Duration(milliseconds: 300));
      status = await checkAvailability();
    }

    if (status == 'SUPPORTED_INSTALLED') return true;

    if (status == 'SUPPORTED_APK_TOO_OLD' ||
        status == 'SUPPORTED_NOT_INSTALLED') {
      final res = await requestInstall(userRequestedInstall: true);
      if (res == 'INSTALLED') return true;

      if (context.mounted) {
        await showAutoDismissPopup(
          context,
          type: PopupType.warning,
          title: 'AR service required',
          message:
              'Please install/update "Google Play Services for AR" from the Play Store, then try again.',
        );
      }
      return false;
    }

    if (status == 'UNSUPPORTED_DEVICE_NOT_CAPABLE') {
      if (context.mounted) {
        await showAutoDismissPopup(
          context,
          type: PopupType.error,
          title: 'Unsupported device',
          message: 'This device is not compatible with ARCore.',
        );
      }
      return false;
    }

    if (context.mounted) {
      await showAutoDismissPopup(
        context,
        type: PopupType.info,
        title: 'AR service missing',
        message:
            'Install/update "Google Play Services for AR" from the Play Store.',
      );
    }
    return false;
  }
}
