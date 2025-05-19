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

  // Top-level lists collection
  CollectionReference get _listsCollection => _firestore.collection('lists');

  /// Creates a new user document in Firestore after registration
  Future<void> createUserDocument(User user) async {
    await _firestore.collection('users').doc(user.uid).set({
      'email': user.email,
      'createdAt': FieldValue.serverTimestamp(),
    });
  }

  /// Saves a list to Firestore
  Future<void> saveList(UserList list) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    // Set ownerId if not set
    if (list.ownerId == null) {
      list.ownerId = user.uid;
    }

    print('Saving list ${list.id} to Firebase');
    print('List has unsynchronized changes: ${list.hasUnsynchronizedChanges}');

    // Use set with merge option to prevent overwriting other fields
    await _listsCollection
        .doc(list.id)
        .set(list.toJson(), SetOptions(merge: true));
  }

  /// Deletes a list from Firestore
  Future<void> deleteList(String listId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');
    await _listsCollection.doc(listId).delete();
  }

  /// Updates a list in Firestore
  Future<void> updateList(UserList list) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');
    list.updateLastModified();
    await _listsCollection.doc(list.id).update(list.toJson());
  }

  /// Streams all lists for the current user (owned or shared)
  Stream<List<UserList>> streamLists({bool includeArchived = false}) {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');
    return _listsCollection
        .where('ownerId', isEqualTo: user.uid)
        .snapshots()
        .map((snapshot) => snapshot.docs
            .map((doc) => UserList.fromJson(doc.data() as Map<String, dynamic>))
            .where((list) => includeArchived || !list.isArchived)
            .toList());
    // For sharing: add .where('sharedWith', arrayContains: user.uid) in the future
  }

  /// Synchronizes local lists with cloud storage
  /// Returns a list of all lists after synchronization
  Future<List<UserList>> synchronizeLists(List<UserList> localLists) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');

    // Get all lists from Firestore
    final cloudSnapshot =
        await _listsCollection.where('ownerId', isEqualTo: user.uid).get();

    final cloudLists = cloudSnapshot.docs
        .map((doc) => UserList.fromJson(doc.data() as Map<String, dynamic>))
        .toList();

    // Create maps for easier lookup
    final localMap = {for (var list in localLists) list.id: list};
    final cloudMap = {for (var list in cloudLists) list.id: list};

    // Lists to be updated in Firestore (local changes)
    final listsToUpdate = <UserList>[];
    // Lists to be added to local storage (new cloud lists)
    final listsToAdd = <UserList>[];
    // Lists to be updated in local storage (newer cloud versions)
    final listsToUpdateLocal = <UserList>[];

    // Check for local changes that need to be synced to cloud
    for (var localList in localLists) {
      final cloudList = cloudMap[localList.id];
      if (cloudList == null) {
        // List only exists locally, add to cloud
        listsToUpdate.add(localList);
      } else if (localList.lastModifiedAt.isAfter(cloudList.lastModifiedAt)) {
        // Local version is newer, update cloud
        listsToUpdate.add(localList);
      } else if (cloudList.lastModifiedAt.isAfter(localList.lastModifiedAt)) {
        // Cloud version is newer, update local
        listsToUpdateLocal.add(cloudList);
      }
    }

    // Check for cloud lists that need to be added to local storage
    for (var cloudList in cloudLists) {
      if (!localMap.containsKey(cloudList.id)) {
        listsToAdd.add(cloudList);
      }
    }

    // Update cloud with local changes
    for (var list in listsToUpdate) {
      // Create a copy of the list to save to Firebase
      final listToSave = UserList(
        name: list.name,
        icon: list.icon,
        id: list.id,
        items: List<ListItem>.from(list.items),
        ownerId: list.ownerId,
        shared: List<SharedUser>.from(list.shared),
        isArchived: list.isArchived,
        createdAt: list.createdAt,
        lastOpenedAt: list.lastOpenedAt,
        lastModifiedAt: DateTime.now(),
        hasUnsynchronizedChanges: false, // Always false in Firebase
      );

      print('Saving list ${listToSave.id} to Firebase during sync');
      print(
          'List has unsynchronized changes: ${listToSave.hasUnsynchronizedChanges}');

      await _listsCollection.doc(listToSave.id).set(listToSave.toJson());
    }

    // Return combined list of all lists, with newer versions taking precedence
    final updatedLocalLists = localLists.map((localList) {
      final cloudList = cloudMap[localList.id];
      if (cloudList != null &&
          cloudList.lastModifiedAt.isAfter(localList.lastModifiedAt)) {
        // If we're using the cloud version, it should be marked as synchronized
        final synchronizedList = UserList(
          name: cloudList.name,
          icon: cloudList.icon,
          id: cloudList.id,
          items: List<ListItem>.from(cloudList.items),
          ownerId: cloudList.ownerId,
          shared: List<SharedUser>.from(cloudList.shared),
          isArchived: cloudList.isArchived,
          createdAt: cloudList.createdAt,
          lastOpenedAt: cloudList.lastOpenedAt,
          lastModifiedAt: cloudList.lastModifiedAt,
          hasUnsynchronizedChanges: false, // Mark as synchronized
        );
        return synchronizedList;
      }
      return localList;
    }).toList();

    return [...updatedLocalLists, ...listsToAdd];
  }

  /// Gets a single list by ID
  Future<UserList?> getList(String listId) async {
    final user = _auth.currentUser;
    if (user == null) throw Exception('No authenticated user found');
    final doc = await _listsCollection.doc(listId).get();
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
      await _listsCollection.doc(listId).update(list.toJson());
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
        final userDoc = await _firestore
            .collection('users')
            .doc(userCredential.user!.uid)
            .get();
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
    try {
      // Sign out from both Firebase and Google
      await Future.wait([
        _auth.signOut(),
        _googleSignIn.signOut(),
      ]);
    } catch (e) {
      // Even if there's an error, we want to ensure the user is signed out
      await _auth.signOut();
      await _googleSignIn.signOut();
      throw Exception('Error during sign out: $e');
    }
  }

  /// Gets the current authenticated user
  User? get currentUser => _auth.currentUser;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();
}
