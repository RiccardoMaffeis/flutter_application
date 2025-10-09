import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../ar/domain/ar_choice.dart';
import '../../ar/application/ar_landing_service.dart';

final arLandingControllerProvider = Provider<ARLandingController>((ref) {
  return ARLandingController(const ARLandingService());
});

class ARLandingController {
  final ARLandingService _service;
  ARLandingController(this._service);

  List<ARChoice> get choices => _service.loadChoices();
}
