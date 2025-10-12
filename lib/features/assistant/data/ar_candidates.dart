import '../../ar/presentation/select/ar_select_page.dart' show ARItem, kXtModels; // o il path corretto
import '../domain/ai_pick.dart';

List<DeviceCandidate> candidatesFromAR(List<ARItem> items) {
  return items.map((it) {
    final tagz = <String>[];
    tagz.addAll(it.label.toLowerCase().split(RegExp(r'[^a-z0-9]+')).where((t) => t.isNotEmpty));
    // prova a dedurre 3p/4p/xtN dai nomi
    final lower = it.label.toLowerCase();
    if (lower.contains('3')) tagz.add('3p');
    if (lower.contains('4')) tagz.add('4p');
    if (lower.contains('xt')) tagz.add('xt');
    return DeviceCandidate(
      id: it.glbPath, // usa un ID stabile: qui metto il path glb
      code: it.label.replaceAll(' ', '_'),
      label: it.label,
      tags: tagz.toSet().toList(),
    );
  }).toList();
}

// comodo: tutti i tuoi AR attuali
List<DeviceCandidate> allArCandidates() => candidatesFromAR(kXtModels);
