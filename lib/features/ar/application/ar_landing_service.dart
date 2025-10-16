import '../../ar/domain/ar_choice.dart';

/// Service responsible for providing the static list of AR choices
/// shown on the AR landing screen. This is a simple, synchronous
/// provider with no I/O or caching logic.
class ARLandingService {
  const ARLandingService();

  /// Returns the list of available AR entry points.
  ///
  /// Each [ARChoice] contains:
  /// - [id]: a stable identifier used for analytics/routing keys
  /// - [title]: the label shown in the UI
  /// - [asset]: path to the preview image displayed in the choice tile
  /// - [route]: the navigation route to push when the choice is selected
  List<ARChoice> loadChoices() => const [
    // XT product family entry
    ARChoice(
      id: 'xt',
      title: 'Select an XT',
      asset: 'lib/images/general/XT.png',
      route: 'xt',
    ),
    // Emax product family entry
    ARChoice(
      id: 'emax',
      title: 'Select an Emax',
      asset: 'lib/images/general/Emax2.png',
      route: 'emax',
    ),
  ];
}
