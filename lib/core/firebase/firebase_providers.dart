// Riverpod provider for a shared FirebaseFirestore instance.
// Purpose:
//   - Centralize access to Firestore across the app.
//   - Improve testability (override with emulator/mock in tests).
//   - Enable dependency injection for widgets/controllers.
// Usage:
//   - Read once (no rebuild): final db = ref.read(firestoreProvider);
//   - Watch (rebuild on override changes): final db = ref.watch(firestoreProvider);
// Testing/Emulator example:
//   ProviderScope(overrides: [
//     firestoreProvider.overrideWithValue(FirebaseFirestore.instanceFor(app: testApp)),
//   ]);
// Notes:
//   - This uses the default Firebase app configuration.
//   - Do not perform heavy work here; keep it as a simple provider factory.

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final firestoreProvider =
    Provider<FirebaseFirestore>((_) => FirebaseFirestore.instance);
