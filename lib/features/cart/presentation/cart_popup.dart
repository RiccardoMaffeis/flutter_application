import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/theme/app_theme.dart';
import '../../cart/controllers/cart_controller.dart';

/// Shows the cart dialog on top of the current route.
/// - Uses Riverpod to read cart state and perform mutations
/// - Dismissible by tapping outside or the close button
Future<void> showCartPopup(BuildContext context, WidgetRef ref) async {
  await showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => const _CartDialog(),
  );
}

/// Modal dialog that renders the cart contents with:
/// - List of line items (thumbnail, name, code, unit price)
/// - Quantity stepper and delete action per item
/// - Subtotal / tax / total rows
/// - Checkout button (closes the dialog; hook your flow where needed)
class _CartDialog extends ConsumerWidget {
  const _CartDialog();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Cart read-only state and controller (mutations).
    final cart = ref.watch(cartControllerProvider);
    final ctrl = ref.read(cartControllerProvider.notifier);

    // ---------- Responsive metrics ----------
    // Scale dialog and typography using MediaQuery and a clamped text scale factor.
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    final ts = mq.textScaleFactor.clamp(1.0, 1.3);

    // Dialog width and insets (screen edge spacing).
    final double dialogW = (w * 0.94).clamp(300.0, 480.0);
    final EdgeInsets dialogInset = EdgeInsets.symmetric(
      horizontal: (w * 0.06).clamp(12.0, 24.0),
      vertical: (h * 0.04).clamp(12.0, 24.0),
    );

    // Inner padding of the dialog card.
    final EdgeInsets dialogPad = EdgeInsets.fromLTRB(
      (w * 0.03).clamp(10.0, 16.0),
      (h * 0.018).clamp(10.0, 16.0),
      (w * 0.03).clamp(10.0, 16.0),
      (h * 0.018).clamp(10.0, 16.0),
    );

    // Max list height to keep dialog compact.
    final double listH = (h * 0.32).clamp(180.0, 320.0);
    final double closeIcon = (w * 0.07).clamp(22.0, 28.0);

    // Thumbnail/avatars sizing.
    final double avatarR = (w * 0.06).clamp(20.0, 26.0);
    final double thumbWH = avatarR * 1.8;

    // Typography for item lines.
    final double nameFont = (w * 0.041).clamp(13.0, 16.0) * ts;
    final double codeFont = (w * 0.033).clamp(11.0, 13.0) * ts;
    final double priceFont = (w * 0.045).clamp(15.0, 18.0) * ts;

    // Quantity stepper sizes.
    final double stepperH = (h * 0.04).clamp(30.0, 36.0);
    final double stepperIcon = (stepperH * 0.55).clamp(16.0, 20.0);

    // Totals row typography.
    final double totalsLabelFont = (w * 0.038).clamp(13.0, 15.0) * ts;
    final double totalsValueFont = (w * 0.042).clamp(14.0, 18.0) * ts;

    // CTA button (Checkout) sizes.
    final double btnW = (dialogW * 0.60).clamp(200.0, 280.0);
    final double btnH = (h * 0.055).clamp(42.0, 50.0);
    final double btnFont = (w * 0.045).clamp(16.0, 18.0) * ts;
    final double btnRadius = (btnH * 0.56).clamp(22.0, 26.0);

    // Generic state/empty/error font size.
    final double stateFont = (w * 0.045).clamp(14.0, 18.0) * ts;

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
      insetPadding: dialogInset,
      child: SizedBox(
        width: dialogW,
        child: Padding(
          padding: dialogPad,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header: right-aligned close button (keeps header compact).
              Row(
                children: [
                  const SizedBox(width: 8),
                  const Spacer(),
                  IconButton(
                    onPressed: () => Navigator.of(context).pop(),
                    icon: Icon(Icons.close, size: closeIcon),
                  ),
                ],
              ),

              // -------- Line items list --------
              SizedBox(
                height: listH,
                child: cart.items.when(
                  // Loading spinner while items resolve.
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
                  // Error message (shows the thrown error string).
                  error: (e, _) => Center(
                    child: Text(
                      'Error: $e',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: stateFont,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                  // Data case: either empty state or the actual list.
                  data: (items) {
                    if (items.isEmpty) {
                      return Center(
                        child: Text(
                          'The cart is empty',
                          style: TextStyle(
                            fontSize: stateFont,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      );
                    }
                    // One row per item: thumb, info (name/code/price), qty stepper, delete.
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => const Divider(height: 16),
                      itemBuilder: (_, i) {
                        final it = items[i];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Product thumbnail (from local asset path).
                            CircleAvatar(
                              radius: avatarR,
                              backgroundColor: const Color(0xFFF4F4F4),
                              child: ClipOval(
                                child: Image.asset(
                                  it.imageUrl,
                                  width: thumbWH,
                                  height: thumbWH,
                                  fit: BoxFit.contain,
                                  errorBuilder: (_, __, ___) =>
                                      const Icon(Icons.broken_image_outlined),
                                ),
                              ),
                            ),
                            SizedBox(width: (w * 0.03).clamp(10.0, 14.0)),
                            // Textual details (name/code/price).
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    it.displayName,
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontWeight: FontWeight.w700,
                                      fontSize: nameFont,
                                    ),
                                  ),
                                  Text(
                                    it.code,
                                    style: TextStyle(
                                      fontSize: codeFont,
                                      color: Colors.black54,
                                    ),
                                  ),
                                  SizedBox(height: (h * 0.007).clamp(4.0, 8.0)),
                                  Text(
                                    '${it.unitPrice.toStringAsFixed(2)} €',
                                    style: TextStyle(
                                      fontWeight: FontWeight.w800,
                                      fontSize: priceFont,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            SizedBox(width: (w * 0.02).clamp(8.0, 12.0)),

                            // Quantity stepper and delete action.
                            _QtyStepper(
                              qty: it.qty,
                              onMinus: () =>
                                  ctrl.setQty(it.productId, it.qty - 1),
                              onPlus: () =>
                                  ctrl.setQty(it.productId, it.qty + 1),
                              height: stepperH,
                              iconSize: stepperIcon,
                            ),
                            IconButton(
                              onPressed: () async {
                                // Small delay for a nicer UI feedback before removal.
                                await Future.delayed(
                                  const Duration(milliseconds: 350),
                                );
                                await ctrl.remove(it.productId);
                              },
                              icon: const Icon(Icons.delete_outline),
                            ),
                          ],
                        );
                      },
                    );
                  },
                ),
              ),

              SizedBox(height: (h * 0.015).clamp(8.0, 14.0)),

              // -------- Totals section --------
              _TotalRow(
                label: 'Order Amount',
                value: cart.subtotal,
                labelFont: totalsLabelFont,
                valueFont: totalsValueFont,
              ),
              _TotalRow(
                label: 'Tax',
                value: cart.tax,
                labelFont: totalsLabelFont,
                valueFont: totalsValueFont,
              ),
              const Divider(height: 18, thickness: 1),
              _TotalRow(
                label: 'Total Payment',
                value: cart.total,
                bold: true,
                // Slightly larger font for the final total.
                labelFont: totalsLabelFont + 1,
                valueFont: totalsValueFont + 1,
              ),

              SizedBox(height: (h * 0.015).clamp(8.0, 14.0)),

              // -------- Checkout CTA --------
              // Currently just closes the dialog; integrate navigation/payment here.
              SizedBox(
                width: btnW,
                height: btnH,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.accent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(btnRadius),
                    ),
                    elevation: 3,
                  ),
                  child: Text(
                    'Checkout',
                    style: TextStyle(color: Colors.white, fontSize: btnFont),
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

/// Compact quantity stepper used per line item:
/// - Minus / current qty / Plus
/// - Elevation and rounded pill shape for a tactile feel
class _QtyStepper extends StatelessWidget {
  final int qty;
  final VoidCallback onMinus;
  final VoidCallback onPlus;

  // responsive overrides
  final double? height;
  final double? iconSize;

  const _QtyStepper({
    required this.qty,
    required this.onMinus,
    required this.onPlus,
    this.height,
    this.iconSize,
  });

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final ts = media.textScaleFactor.clamp(1.0, 1.3);

    final double h = height ?? 32.0;
    final double ic = (iconSize ?? 18.0);
    final double qtyFont = (w * 0.04).clamp(13.0, 15.0) * ts;

    return Container(
      height: h,
      padding: EdgeInsets.symmetric(horizontal: (h * 0.18).clamp(6.0, 8.0)),
      margin: const EdgeInsets.only(right: 6),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(h * 0.55),
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
          _iconBtn(Icons.remove, onMinus, ic, h),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: (h * 0.22).clamp(6.0, 10.0),
            ),
            child: Text(
              '$qty',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: qtyFont),
            ),
          ),
          _iconBtn(Icons.add, onPlus, ic, h),
        ],
      ),
    );
  }

  // Small circular icon button used inside the stepper.
  Widget _iconBtn(IconData icon, VoidCallback onTap, double size, double h) =>
      SizedBox(
        width: (h * 0.78).clamp(26.0, 32.0),
        height: (h * 0.78).clamp(26.0, 32.0),
        child: Material(
          color: Colors.white,
          shape: const CircleBorder(),
          child: InkWell(
            customBorder: const CircleBorder(),
            onTap: onTap,
            child: Icon(icon, size: size),
          ),
        ),
      );
}

/// Single row showing a label/value pair of a monetary total.
/// - `bold` increases font weight and value size (for the grand total).
class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;

  // responsive overrides
  final double? labelFont;
  final double? valueFont;

  const _TotalRow({
    required this.label,
    required this.value,
    this.bold = false,
    this.labelFont,
    this.valueFont,
  });

  @override
  Widget build(BuildContext context) {
    final double lf = labelFont ?? 14.0;
    final double vf = valueFont ?? (bold ? 16.0 : 14.0);

    final s = TextStyle(
      fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
      fontSize: bold ? vf : lf,
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
