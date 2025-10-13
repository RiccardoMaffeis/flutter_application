import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

final firestoreProvider =
    Provider<FirebaseFirestore>((_) => FirebaseFirestore.instance);
