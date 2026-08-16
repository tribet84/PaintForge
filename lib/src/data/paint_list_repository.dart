import 'package:cloud_firestore/cloud_firestore.dart';

import '../models/paint_list.dart';

/// Persistence boundary for the user's custom paint lists.
abstract class PaintListRepository {
  Stream<List<PaintList>> watchLists();

  /// Returns the id of the created list.
  Future<String> create(String name, {List<String> paintIds});

  Future<void> rename(String listId, String name);

  Future<void> setPaints(String listId, List<String> paintIds);

  Future<void> delete(String listId);
}

/// Firestore-backed lists, one document per list under
/// `users/{uid}/paintLists/{listId}`.
class FirestorePaintListRepository implements PaintListRepository {
  FirestorePaintListRepository({
    required this.uid,
    FirebaseFirestore? firestore,
  }) : _firestore = firestore ?? FirebaseFirestore.instance;

  final String uid;
  final FirebaseFirestore _firestore;

  CollectionReference<Map<String, dynamic>> get _collection =>
      _firestore.collection('users').doc(uid).collection('paintLists');

  @override
  Stream<List<PaintList>> watchLists() {
    return _collection.snapshots().map((snapshot) {
      final lists = <PaintList>[];
      for (final doc in snapshot.docs) {
        final data = doc.data();
        final name = data['name'] as String?;
        if (name == null) continue;
        lists.add(
          PaintList(
            id: doc.id,
            name: name,
            paintIds: (data['paintIds'] as List<dynamic>? ?? const [])
                .whereType<String>()
                .toList(),
            // Null while a server timestamp is still pending locally.
            updatedAt:
                (data['updatedAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
          ),
        );
      }
      lists.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return lists;
    });
  }

  @override
  Future<String> create(String name, {List<String> paintIds = const []}) async {
    final doc = await _collection.add({
      'name': name,
      'paintIds': paintIds,
      'updatedAt': FieldValue.serverTimestamp(),
    });
    return doc.id;
  }

  @override
  Future<void> rename(String listId, String name) {
    return _collection.doc(listId).update({
      'name': name,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> setPaints(String listId, List<String> paintIds) {
    return _collection.doc(listId).update({
      'paintIds': paintIds,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  @override
  Future<void> delete(String listId) => _collection.doc(listId).delete();
}
