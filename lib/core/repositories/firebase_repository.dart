import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user_list.dart';
import '../models/list_item.dart';

/// Repository class that handles all Firebase operations
class FirebaseRepository {
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;
  final FirebaseAuth _auth = FirebaseAuth.instance;
  final GoogleSignIn _googleSignIn = GoogleSignIn();

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

    // Update timestamps before saving
    list.updateLastModified();
    list.updateLastOpened();
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

    // Update modification timestamp before updating
    list.updateLastModified();
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

    final list = await getList(listId);
    if (list != null) {
      list.updateLastOpened();
      await _listsCollection(user.uid).doc(listId).update(list.toJson());
    }
  }

  /// Signs in a user with Google
  Future<UserCredential> signInWithGoogle() async {
    try {
      // Trigger the authentication flow
      final GoogleSignInAccount? googleUser = await _googleSignIn.signIn();

      if (googleUser == null) {
        throw Exception('Google sign in aborted');
      }

      // Obtain the auth details from the request
      final GoogleSignInAuthentication googleAuth =
          await googleUser.authentication;

      // Create a new credential
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );

      // Sign in to Firebase with the Google credential
      final userCredential = await _auth.signInWithCredential(credential);

      // Create user document if it doesn't exist
      if (userCredential.user != null) {
        final userDoc =
            await _usersCollection.doc(userCredential.user!.uid).get();
        if (!userDoc.exists) {
          await createUserDocument(userCredential.user!);
        }
      }

      return userCredential;
    } catch (e) {
      throw Exception('Failed to sign in with Google: $e');
    }
  }

  /// Signs out the current user
  Future<void> signOut() async {
    await Future.wait([
      _auth.signOut(),
      _googleSignIn.signOut(),
    ]);
  }

  /// Gets the current authenticated user
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
