import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/inventory_entry.dart';

/// Persistence boundary for the user's inventory.
abstract class InventoryRepository {
  Stream<Map<String, InventoryEntry>> watchEntries();

  Future<void> setStatus(String paintId, PaintStatus status);

  Future<void> remove(String paintId);

  /// Applies one status to many paints in a single round trip.
  ///
  /// Bulk actions used to await one write per paint, which is one network
  /// round trip and one billed operation each — marking 40 paints meant 40 of
  /// both, and the UI updated in visible dribs as each landed.
  Future<void> setStatusForAll(Iterable<String> paintIds, PaintStatus status);

  /// Removes many paints in a single round trip.
  Future<void> removeAll(Iterable<String> paintIds);
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

  @override
  Future<void> setStatusForAll(
    Iterable<String> paintIds,
    PaintStatus status,
  ) {
    return _writeInBatches(
      paintIds,
      (batch, id) => batch.set(_collection.doc(id), {
        'status': status.name,
        'updatedAt': FieldValue.serverTimestamp(),
      }),
    );
  }

  @override
  Future<void> removeAll(Iterable<String> paintIds) {
    return _writeInBatches(
      paintIds,
      (batch, id) => batch.delete(_collection.doc(id)),
    );
  }

  /// Firestore caps a batch at 500 writes, so anything larger is split.
  /// Chunks are committed in sequence rather than in parallel to keep the
  /// write rate predictable.
  Future<void> _writeInBatches(
    Iterable<String> paintIds,
    void Function(WriteBatch batch, String paintId) op,
  ) async {
    const maxPerBatch = 450;
    final ids = paintIds.toList();
    if (ids.isEmpty) return;
    for (var start = 0; start < ids.length; start += maxPerBatch) {
      final end =
          start + maxPerBatch < ids.length ? start + maxPerBatch : ids.length;
      final batch = _firestore.batch();
      for (final id in ids.sublist(start, end)) {
        op(batch, id);
      }
      await batch.commit();
    }
  }
}
