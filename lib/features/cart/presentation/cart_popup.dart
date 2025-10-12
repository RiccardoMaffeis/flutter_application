import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../cart/controllers/cart_controller.dart';

/// Shows the cart dialog on top of the current route.
/// Uses Riverpod [WidgetRef] to access the cart controller/state inside the dialog.
Future<void> showCartPopup(BuildContext context, WidgetRef ref) async {
  await showDialog(
    context: context,
    barrierDismissible: true, // allow tap outside to close
    builder: (_) => const _CartDialog(),
  );
}

/// Modal dialog that displays cart contents, totals, and a checkout button.
/// Listens to [cartControllerProvider] for reactive updates.
class _CartDialog extends ConsumerWidget {
  const _CartDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Read current cart state (AsyncValue<List<CartItem>> + totals).
    final cart = ref.watch(cartControllerProvider);
    // Controller to perform mutations (set qty, remove, clear, etc.).
    final ctrl = ref.read(cartControllerProvider.notifier);

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
              // Header row with only a close button aligned to the right
              Row(
                children: [
                  const SizedBox(width: 8),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: const Icon(Icons.close),
                  ),
                ],
              ),

              // Cart items list (fixed height, scrollable)
              SizedBox(
                height: 260,
                child: cart.items.when(
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  error: (e, _) => Center(child: Text('Error: $e')),
                  data: (items) {
                    if (items.isEmpty) {
                      // Empty state message
                      return const Center(child: Text('The cart is empty'));
                    }
                    // Render each item with thumbnail, info, price, qty stepper, and delete
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 16),
                      itemBuilder: (_, i) {
                        final it = items[i];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Circular thumbnail with asset image fallback
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
                            // Product title, code and unit price
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    it.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
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

                            // Quantity stepper and delete action
                            _QtyStepper(
                              qty: it.qty,
                              onMinus: () =>
                                  ctrl.setQty(it.productId, it.qty - 1),
                              onPlus: () =>
                                  ctrl.setQty(it.productId, it.qty + 1),
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

              // Totals summary (subtotal, tax, and total)
              _TotalRow(label: 'Order Amount', value: cart.subtotal),
              _TotalRow(label: 'Tax', value: cart.tax),
              const Divider(height: 18, thickness: 1),
              _TotalRow(label: 'Total Payment', value: cart.total, bold: true),

              const SizedBox(height: 12),

              // Checkout button (placeholder action -> just closes the dialog)
              SizedBox(
                width: 240,
                height: 46,
                child: ElevatedButton(
                  onPressed: () {
                    // TODO: go to /checkout
                    Navigator.of(context).pop();
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(26),
                    ),
                    elevation: 3,
                  ),
                  child: const Text(
                    'Checkout',
                    style: TextStyle(color: Colors.white, fontSize: 18),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Compact quantity selector with minus/plus buttons.
class _QtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;
  const _QtyStepper({
    required this.qty,
    required this.onMinus,
    required this.onPlus,
  });

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
          BoxShadow(
            color: Color(0x22000000),
            blurRadius: 6,
            offset: Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        children: [
          // Decrease quantity
          _iconBtn(Icons.remove, onMinus),
          // Current quantity value
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Text(
              '$qty',
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
          // Increase quantity
          _iconBtn(Icons.add, onPlus),
        ],
      ),
    );
  }

  /// Small circular icon button used by the stepper.
  Widget _iconBtn(IconData icon, VoidCallback onTap) => SizedBox(
    width: 28,
    height: 28,
    child: Material(
      color: Colors.white,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Icon(icon, size: 18),
      ),
    ),
  );
}

/// Row widget to display a label + formatted euro amount (with optional emphasis).
class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;
  const _TotalRow({
    required this.label,
    required this.value,
    this.bold = false,
  });

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
