import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/inventory_entry.dart';

/// Persistence boundary for the user's inventory.
abstract class InventoryRepository {
  Stream<Map<String, InventoryEntry>> watchEntries();

  Future<void> setStatus(String paintId, PaintStatus status);

  Future<void> remove(String paintId);
}

/// Firestore-backed inventory, one document per paint under
/// `users/{uid}/inventory/{paintId}`. Firestore's built-in offline
/// persistence keeps the app usable without a connection.
class FirestoreInventoryRepository implements InventoryRepository {
  FirestoreInventoryRepository({required this.uid, FirebaseFirestore? firestore})
      : _firestore = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(uid).collection('inventory');

  @override
  Stream<Map<String, InventoryEntry>> watchEntries() {
    return _collection.snapshots().map((snapshot) {
      final entries = <String, InventoryEntry>{};
      for (final doc in snapshot.docs) {
        final status = PaintStatus.tryParse(doc.data()['status'] as String?);
        if (status == null) continue;
        entries[doc.id] = InventoryEntry(paintId: doc.id, status: status);
      }
      return entries;
    });
  }

  @override
  Future<void> setStatus(String paintId, PaintStatus status) {
    return _collection.doc(paintId).set({
      'status': status.name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> remove(String paintId) => _collection.doc(paintId).delete();
}
