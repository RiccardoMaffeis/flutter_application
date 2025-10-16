import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

class ComingSoonPage extends StatelessWidget {
  final String title;
  final String message;

  const ComingSoonPage({
    super.key,
    this.title = 'Coming soon',
    this.message = 'This feature is on the way.\nStay tuned!',
  });

  void _handleBack(BuildContext context) {
    if (Navigator.of(context).canPop()) {
      context.pop();
    } else {
      context.go('/ar');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF2F2F7),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 6),
            Padding(
              padding: const EdgeInsets.fromLTRB(6, 8, 6, 6),
              child: Row(
                children: [
                  IconButton(
                    icon: const Icon(Icons.arrow_back),
                    iconSize: 28,
                    onPressed: () => _handleBack(context),
                  ),
                  Expanded(
                    child: Text(
                      'Augmented Reality',
                      textAlign: TextAlign.center,
                      style: Theme.of(context)
                          .textTheme
                          .headlineMedium
                          ?.copyWith(fontWeight: FontWeight.w900, fontSize: 31),
                    ),
                  ),
                  const Opacity(
                    opacity: 0,
                    child: IconButton(
                      icon: Icon(Icons.arrow_back),
                      onPressed: null,
                    ),
                  ),
                ],
              ),
            ),
            Container(
              height: 4,
              margin: const EdgeInsets.symmetric(horizontal: 16),
              decoration: BoxDecoration(
                color: const Color(0xFFE53935),
                borderRadius: BorderRadius.circular(3),
              ),
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Icon(Icons.construction_outlined, size: 72),
                    const SizedBox(height: 12),
                    Text(
                      title,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      message,
                      textAlign: TextAlign.center,
                      style: const TextStyle(fontSize: 16, color: Colors.black54),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}
