import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../cart/controllers/cart_controller.dart';

Future<void> showCartPopup(BuildContext context, WidgetRef ref) async {
  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _CartDialog(),
  );
}

class _CartDialog extends ConsumerWidget {
  const _CartDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cart = ref.watch(cartControllerProvider);
    final ctrl  = ref.read(cartControllerProvider.notifier);

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: const EdgeInsets.symmetric(horizontal: 24, vertical: 24),
      child: SizedBox(
        width: 420,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(14, 14, 14, 14),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // header close
              Row(
                children: [
                  const SizedBox(width: 8),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  )
                ],
              ),

              // items
              SizedBox(
                height: 260, // scroll area
                child: cart.items.when(
                  loading: () => const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Errore: $e')),
                  data: (items) {
                    if (items.isEmpty) {
                      return const Center(child: Text('Il carrello è vuoto'));
                    }
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 16),
                      itemBuilder: (_, i) {
                        final it = items[i];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            CircleAvatar(
                              radius: 24,
                              backgroundColor: const Color(0xFFF4F4F4),
                              child: ClipOval(
                                child: Image.asset(
                                  it.imageUrl,
                                  width: 44,
                                  height: 44,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(it.displayName,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w700,
                                      )),
                                  Text(
                                    it.code,
                                    style: const TextStyle(
                                      fontSize: 12,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Text(
                                    '${it.unitPrice.toStringAsFixed(2)} €',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: 16,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),

                            // stepper + delete
                            _QtyStepper(
                              qty: it.qty,
                              onMinus: () => ctrl.setQty(it.productId, it.qty - 1),
                              onPlus:  () => ctrl.setQty(it.productId, it.qty + 1),
                            ),
                            IconButton(
                              onPressed: () => ctrl.remove(it.productId),
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              // totals
              _TotalRow(label: 'Order Amount', value: cart.subtotal),
              _TotalRow(label: 'Tax',          value: cart.tax),
              const Divider(height: 18, thickness: 1),
              _TotalRow(label: 'Total Payment', value: cart.total, bold: true),

              const SizedBox(height: 12),

              // checkout btn
              SizedBox(
                width: 240,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: vai a /checkout
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    elevation: 3,
                  ),
                  child: const Text('Checkout',
                      style: TextStyle(color: Colors.white, fontSize: 18)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _QtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  const _QtyStepper({required this.qty, required this.onMinus, required this.onPlus});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 32,
      padding: const EdgeInsets.symmetric(horizontal: 6),
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        boxShadow: const [
          BoxShadow(color: Color(0x22000000), blurRadius: 6, offset: Offset(0,3)),
        ],
      ),
      child: Row(
        children: [
          _iconBtn(Icons.remove, onMinus),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text('$qty', style: const TextStyle(fontWeight: FontWeight.w800)),
          ),
          _iconBtn(Icons.add, onPlus),
        ],
      ),
    );
  }

  Widget _iconBtn(IconData icon, VoidCallback onTap) => SizedBox(
    width: 28,
    height: 28,
    child: Material(
      color: Colors.white, shape: const CircleBorder(),
      child: InkWell(customBorder: const CircleBorder(), onTap: onTap,
        child: Icon(icon, size: 18)),
    ),
  );
}

class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;
  const _TotalRow({required this.label, required this.value, this.bold = false});

  @override
  Widget build(BuildContext context) {
    final s = TextStyle(
      fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
      fontSize: bold ? 16 : 14,
    );
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 6),
      child: Row(
        children: [
          Expanded(child: Text(label, style: s)),
          Text('${value.toStringAsFixed(2)} €', style: s),
        ],
      ),
    );
  }
}
