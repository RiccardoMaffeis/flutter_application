// Global UI flag to hide/show app "chrome" (e.g., bottom nav, FAB, headers).
// Usage:
//   - Read:  ref.watch(hideChromeProvider)            -> bool
//   - Write: ref.read(hideChromeProvider.notifier).state = true/false
// Typical scenarios to set `true`: full-screen search, immersive pages, modal flows.
// Note: This uses Riverpod's legacy StateProvider API.

import 'package:flutter_riverpod/legacy.dart';

// When `true`, surrounding UI elements should be hidden to emphasize content.
final hideChromeProvider = StateProvider<bool>((ref) => false);
