import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ar/domain/ar_choice.dart';
import '../../ar/application/ar_landing_service.dart';

/// Riverpod provider that exposes a single instance of [ARLandingController].
/// The controller is responsible for retrieving AR landing choices for the UI.
final arLandingControllerProvider = Provider<ARLandingController>((ref) {
  return ARLandingController(const ARLandingService());
});

/// Lightweight controller for the AR landing page:
/// - Holds a reference to [ARLandingService]
/// - Exposes computed data (choices) for the presentation layer
class ARLandingController {
  /// Underlying service supplying static AR choices.
  final ARLandingService _service;

  /// Inject the service to keep the controller easily testable and replaceable.
  ARLandingController(this._service);

  /// Returns the list of available AR choices to be rendered by the UI.
  List<ARChoice> get choices => _service.loadChoices();
}
