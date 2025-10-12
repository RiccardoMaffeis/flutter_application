import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

/// Types of popups used by [showAutoDismissPopup] to convey status/severity.
enum PopupType { info, success, warning, error }

/// Utility class to:
/// - Query ARCore / Google Play Services for AR availability via a platform channel
/// - Request installation of required AR services
/// - Open the Play Store (platform side)
/// - Show small auto-dismiss informational popups
///
/// NOTE:
/// This class talks to native code through a MethodChannel named 'arcore/check'.
/// Make sure you implement the corresponding platform methods on Android/iOS.
class ArCoreCheck {
  /// Platform channel used to communicate with native (Android/iOS) code.
  static const _ch = MethodChannel('arcore/check');

  /// Checks ARCore / Google Play Services for AR availability on the device.
  ///
  /// Returns a string status such as:
  /// - 'SUPPORTED_INSTALLED'
  /// - 'SUPPORTED_APK_TOO_OLD'
  /// - 'SUPPORTED_NOT_INSTALLED'
  /// - 'UNSUPPORTED_DEVICE_NOT_CAPABLE'
  /// - 'UNKNOWN_CHECKING', 'UNKNOWN_TIMED_OUT', etc.
  static Future<String> checkAvailability() async {
    final res = await _ch.invokeMethod<String>('checkAvailability');
    return res ?? 'UNKNOWN';
  }

  /// Requests installation/update of AR services if missing or outdated.
  ///
  /// [userRequestedInstall] indicates whether the user explicitly triggered the flow.
  /// Returns:
  /// - 'INSTALLED' on success
  /// - Other strings or null if the install did not complete.
  static Future<String?> requestInstall({
    bool userRequestedInstall = true,
  }) async {
    return await _ch.invokeMethod<String>('requestInstall', {
      'userRequestedInstall': userRequestedInstall,
    });
  }

  /// Tries to open the Play Store page for "Google Play Services for AR".
  /// Errors are swallowed to avoid crashing if the device has no Play Store.
  static Future<void> openPlayStore() async {
    try {
      await _ch.invokeMethod('openPlayStore');
    } catch (_) {}
  }

  /// Shows a small modal popup (AlertDialog) that auto-dismisses after [duration].
  ///
  /// - The dialog is **non-dismissible** by tapping the barrier.
  /// - The icon and its color change based on [type].
  /// - The dialog is closed automatically after [duration] if still mounted.
  static Future<void> showAutoDismissPopup(
    BuildContext context, {
    required String title,
    required String message,
    PopupType type = PopupType.info,
    Duration duration = const Duration(seconds: 2),
  }) async {
    // Pick icon and color based on the popup type using a Dart pattern switch.
    final (iconData, iconColor) = switch (type) {
      PopupType.error => (Icons.error_outline, Colors.red),
      PopupType.warning => (Icons.warning_amber_outlined, Colors.orange),
      PopupType.success => (Icons.check_circle_outline, Colors.green),
      PopupType.info => (Icons.info_outline, Colors.blue),
    };

    // Show a simple alert dialog with icon, title and message.
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        icon: Icon(iconData, color: iconColor, size: 32), // Leading visual hint
        title: Text(title),
        content: Text(message),
      ),
    );

    // Wait for the specified duration, then dismiss if possible.
    await Future.delayed(duration);
    if (!context.mounted) return;
    final nav = Navigator.of(context, rootNavigator: true);
    if (nav.canPop()) nav.pop();
  }

  /// Ensures AR services are available before starting an AR session.
  ///
  /// Flow:
  /// 1) Check availability. If the result is still "unknown", retry after a short delay.
  /// 2) If already installed → return true.
  /// 3) If supported but not installed / too old → trigger install flow. If installed → true,
  ///    otherwise show a warning popup and return false.
  /// 4) If the device is not capable → show error popup and return false.
  /// 5) Fallback for any other state → show info popup and return false.
  static Future<bool> ensureAvailable(BuildContext context) async {
    String status = await checkAvailability();

    // Some devices report a transient unknown state; retry once after a brief delay.
    if (status == 'UNKNOWN_CHECKING' || status == 'UNKNOWN_TIMED_OUT') {
      await Future.delayed(const Duration(milliseconds: 300));
      status = await checkAvailability();
    }

    // Happy path: AR services are present and ready.
    if (status == 'SUPPORTED_INSTALLED') return true;

    // Supported device but services missing or outdated → prompt install/update.
    if (status == 'SUPPORTED_APK_TOO_OLD' ||
        status == 'SUPPORTED_NOT_INSTALLED') {
      final res = await requestInstall(userRequestedInstall: true);
      if (res == 'INSTALLED') return true;

      // Install did not complete, inform the user.
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

    // Device not capable of AR (no required hardware/features).
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

    // Generic fallback for any other unknown/unexpected status.
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
