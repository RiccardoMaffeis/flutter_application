import '../../shop/domain/product.dart';
import '../domain/ai_pick.dart';

List<DeviceCandidate> candidatesFromProducts(List<Product> items) {
  return items.map((p) {
    final tagz = <String>[];
    tagz.addAll(p.displayName.toLowerCase().split(RegExp(r'[^a-z0-9]+')).where((t) => t.isNotEmpty));
    tagz.addAll(p.code.toLowerCase().split(RegExp(r'[^a-z0-9]+')).where((t) => t.isNotEmpty));
    return DeviceCandidate(
      id: p.id,
      code: p.code,
      label: p.displayName,
      tags: tagz.toSet().toList(),
    );
  }).toList();
}
