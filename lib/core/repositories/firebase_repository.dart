import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../models/user_list.dart';
import '../models/list_item.dart';

/// Repository class that handles all Firebase operations
class FirebaseRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;

  // Collection references
  CollectionReference get _usersCollection => _firestore.collection('users');
  CollectionReference _listsCollection(String userId) =>
      _usersCollection.doc(userId).collection('lists');

  /// Creates a new user document in Firestore after registration
  Future<void> createUserDocument(User user) async {
    await _usersCollection.doc(user.uid).set({
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Saves a list to Firestore
  Future<void> saveList(UserList list) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    await _listsCollection(user.uid).doc(list.id).set(list.toJson());
  }

  /// Deletes a list from Firestore
  Future<void> deleteList(String listId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    await _listsCollection(user.uid).doc(listId).delete();
  }

  /// Updates a list in Firestore
  Future<void> updateList(UserList list) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    await _listsCollection(user.uid).doc(list.id).update(list.toJson());
  }

  /// Streams all lists for the current user
  Stream<List<UserList>> streamLists({bool includeArchived = false}) {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    return _listsCollection(user.uid).snapshots().map((snapshot) => snapshot
        .docs
        .map((doc) => UserList.fromJson(doc.data() as Map<String, dynamic>))
        .where((list) => includeArchived || !list.isArchived)
        .toList());
  }

  /// Gets a single list by ID
  Future<UserList?> getList(String listId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    final doc = await _listsCollection(user.uid).doc(listId).get();
    if (!doc.exists) return null;

    return UserList.fromJson(doc.data() as Map<String, dynamic>);
  }

  /// Updates the last accessed timestamp of a list
  Future<void> updateListAccess(String listId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    await _listsCollection(user.uid).doc(listId).update({
      'lastAccessedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Signs in a user with email and password
  Future<UserCredential> signInWithEmailAndPassword(
      String email, String password) async {
    return await _auth.signInWithEmailAndPassword(
      email: email,
      password: password,
    );
  }

  /// Creates a new user with email and password
  Future<UserCredential> createUserWithEmailAndPassword(
      String email, String password) async {
    final credential = await _auth.createUserWithEmailAndPassword(
      email: email,
      password: password,
    );

    // Create the user document in Firestore
    await createUserDocument(credential.user!);

    return credential;
  }

  /// Signs out the current user
  Future<void> signOut() async {
    await _auth.signOut();
  }

  /// Gets the current authenticated user
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
