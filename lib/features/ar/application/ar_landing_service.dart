import '../../ar/domain/ar_choice.dart';

class ARLandingService {
  const ARLandingService();

  List<ARChoice> loadChoices() => const [
    ARChoice(
      id: 'xt',
      title: 'Select an XT',
      asset: 'lib/images/general/XT.png',
      route: '/ar/xt',
    ),
    ARChoice(
      id: 'emax',
      title: 'Select an Emax',
      asset: 'lib/images/general/Emax2.png',
      route: '/ar/emax',
    ),
  ];
}
