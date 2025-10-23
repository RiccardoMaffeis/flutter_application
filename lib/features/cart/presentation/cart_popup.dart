import 'dart:math' as math;
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
    final mq = MediaQuery.of(context);
    final w = mq.size.width;
    final h = mq.size.height;
    final shortest = math.min(w, h);
    final scale = (shortest / 375.0).clamp(0.85, 1.30);
    double sp(double v) => v * scale; // scale-by-shortest helper
    final ts = mq.textScaleFactor.clamp(1.0, 1.3);

    // Dialog width and insets.
    final double dialogW = (w * 0.94).clamp(sp(280.0), sp(520.0));
    final EdgeInsets dialogInset = EdgeInsets.symmetric(
      horizontal: (w * 0.06).clamp(sp(10.0), sp(24.0)),
      vertical: (h * 0.04).clamp(sp(10.0), sp(24.0)),
    );

    // Inner padding of the dialog card.
    final EdgeInsets dialogPad = EdgeInsets.fromLTRB(
      (w * 0.03).clamp(sp(8.0), sp(16.0)),
      (h * 0.018).clamp(sp(8.0), sp(18.0)),
      (w * 0.03).clamp(sp(8.0), sp(16.0)),
      (h * 0.018).clamp(sp(8.0), sp(18.0)),
    );

    // Max list height to keep dialog compact.
    final double listH = (h * 0.32).clamp(sp(160.0), sp(340.0));
    final double closeIcon = (w * 0.07).clamp(sp(20.0), sp(30.0));

    // Thumbnail/avatars sizing.
    final double avatarR = (w * 0.06).clamp(sp(18.0), sp(28.0));
    final double thumbWH = avatarR * 1.8;

    // Typography for item lines.
    final double nameFont = ((w * 0.041).clamp(sp(12.0), sp(18.0))) * ts;
    final double codeFont = ((w * 0.033).clamp(sp(10.0), sp(14.0))) * ts;
    final double priceFont = ((w * 0.045).clamp(sp(14.0), sp(20.0))) * ts;

    // Quantity stepper sizes.
    final double stepperH = (h * 0.04).clamp(sp(28.0), sp(38.0));
    final double stepperIcon = (stepperH * 0.55).clamp(sp(14.0), sp(22.0));

    // Totals row typography.
    final double totalsLabelFont = ((w * 0.038).clamp(sp(12.0), sp(16.0))) * ts;
    final double totalsValueFont = ((w * 0.042).clamp(sp(13.0), sp(19.0))) * ts;

    // CTA button (Checkout) sizes.
    final double btnW = (dialogW * 0.60).clamp(sp(180.0), sp(320.0));
    final double btnH = (h * 0.055).clamp(sp(38.0), sp(56.0));
    final double btnFont = ((w * 0.045).clamp(sp(14.0), sp(20.0))) * ts;
    final double btnRadius = (btnH * 0.56).clamp(sp(18.0), sp(28.0));

    // Generic state/empty/error font size.
    final double stateFont = ((w * 0.045).clamp(sp(14.0), sp(18.0))) * ts;

    // Separators thickness/height.
    final double sepH = (h * 0.018).clamp(sp(8.0), sp(16.0));
    final double sepThick = (w * 0.0025).clamp(0.8, 1.6);

    // Small gaps.
    final double gapXS = (w * 0.02).clamp(sp(6.0), sp(12.0));
    final double gapS = (w * 0.03).clamp(sp(8.0), sp(14.0));
    final double gapM = (h * 0.015).clamp(sp(8.0), sp(14.0));

    return Dialog(
      backgroundColor: Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(sp(22)),
      ),
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
                  SizedBox(width: gapXS),
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
                  loading: () =>
                      const Center(child: CircularProgressIndicator()),
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
                    // One row per item.
                    return ListView.separated(
                      itemCount: items.length,
                      separatorBuilder: (_, __) => SizedBox(height: sepH),
                      itemBuilder: (_, i) {
                        final it = items[i];
                        return Row(
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // Product thumbnail.
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
                            SizedBox(width: gapS),

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
                                  SizedBox(
                                    height: (h * 0.007).clamp(sp(4.0), sp(8.0)),
                                  ),
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
                            SizedBox(
                              width: (w * 0.02).clamp(sp(8.0), sp(12.0)),
                            ),

                            // Quantity stepper and delete.
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
                                await Future.delayed(
                                  Duration(milliseconds: (180 * scale).round()),
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

              SizedBox(height: gapM),

              // -------- Totals section --------
              Divider(height: sepH, thickness: sepThick),
              _TotalRow(
                label: 'Total Payment',
                value: cart.total,
                bold: true,
                labelFont: totalsLabelFont + sp(1),
                valueFont: totalsValueFont + sp(1),
              ),

              SizedBox(height: gapM),

              // -------- Checkout CTA --------
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
                    elevation: sp(3),
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
    final hScreen = media.size.height;
    final shortest = math.min(w, hScreen);
    final scale = (shortest / 375.0).clamp(0.85, 1.30);
    double sp(double v) => v * scale;
    final ts = media.textScaleFactor.clamp(1.0, 1.3);

    final double h = height ?? sp(32.0);
    final double ic = iconSize ?? sp(18.0);
    final double qtyFont = ((w * 0.04).clamp(sp(12.0), sp(16.0))) * ts;

    return Container(
      height: h,
      padding: EdgeInsets.symmetric(
        horizontal: (h * 0.18).clamp(sp(6.0), sp(10.0)),
      ),
      margin: EdgeInsets.only(right: sp(6)),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(h * 0.55),
        boxShadow: [
          BoxShadow(
            color: const Color(0x22000000),
            blurRadius: sp(6),
            offset: Offset(0, sp(3)),
          ),
        ],
      ),
      child: Row(
        children: [
          _iconBtn(Icons.remove, onMinus, ic, h, sp),
          Padding(
            padding: EdgeInsets.symmetric(
              horizontal: (h * 0.22).clamp(sp(6.0), sp(12.0)),
            ),
            child: Text(
              '$qty',
              style: TextStyle(fontWeight: FontWeight.w800, fontSize: qtyFont),
            ),
          ),
          _iconBtn(Icons.add, onPlus, ic, h, sp),
        ],
      ),
    );
  }

  // Small circular icon button used inside the stepper.
  Widget _iconBtn(
    IconData icon,
    VoidCallback onTap,
    double size,
    double h,
    double Function(double) sp,
  ) {
    final wh = (h * 0.78).clamp(sp(24.0), sp(34.0));
    return SizedBox(
      width: wh,
      height: wh,
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
}

/// Single row showing a label/value pair of a monetary total.
/// - `bold` increases font weight and value size (for the grand total).
class _TotalRow extends StatelessWidget {
  final String label;
  final double value;
  final bool bold;

  // responsive overrides (if null we compute responsively)
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
    final media = MediaQuery.of(context);
    final w = media.size.width;
    final h = media.size.height;
    final shortest = math.min(w, h);
    final scale = (shortest / 375.0).clamp(0.85, 1.30);
    double sp(double v) => v * scale;
    final ts = media.textScaleFactor.clamp(1.0, 1.3);

    final double lf =
        (labelFont ?? ((w * 0.038).clamp(sp(12.0), sp(16.0)))) * ts;
    final double vf =
        (valueFont ?? ((w * 0.042).clamp(sp(13.0), sp(19.0)))) * ts;

    final s = TextStyle(
      fontWeight: bold ? FontWeight.w900 : FontWeight.w700,
      fontSize: bold ? vf : lf,
    );

    return Padding(
      padding: EdgeInsets.symmetric(vertical: sp(6), horizontal: sp(6)),
      child: Row(
        children: [
          Expanded(child: Text(label, style: s)),
          Text('${value.toStringAsFixed(2)} €', style: s),
        ],
      ),
    );
  }
}
