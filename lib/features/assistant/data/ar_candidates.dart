import '../../ar/presentation/select/ar_xt_page.dart' show ARItem, kXtModels;
import '../domain/ai_pick.dart';

List<DeviceCandidate> candidatesFromAR(List<ARItem> items) {
  return items.map((it) {
    final tagz = <String>[];
    tagz.addAll(it.label.toLowerCase().split(RegExp(r'[^a-z0-9]+')).where((t) => t.isNotEmpty));
    final lower = it.label.toLowerCase();
    if (lower.contains('3')) tagz.add('3p');
    if (lower.contains('4')) tagz.add('4p');
    if (lower.contains('xt')) tagz.add('xt');
    return DeviceCandidate(
      id: it.glbPath,
      code: it.label.replaceAll(' ', '_'),
      label: it.label,
      tags: tagz.toSet().toList(),
    );
  }).toList();
}

List<DeviceCandidate> allArCandidates() => candidatesFromAR(kXtModels);
