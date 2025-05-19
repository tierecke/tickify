import 'dart:io';
import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import 'package:firebase_auth/firebase_auth.dart';
import '../widgets/platform_navigation.dart';
import '../widgets/empty_lists_state.dart';
import '../widgets/login_dialog.dart';
import '../repositories/firebase_repository.dart';
import '../repositories/local_repository.dart';
import '../models/user_list.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../widgets/editable_text_field.dart';

/// Main screen of the application with platform-adaptive navigation
/// Renders differently on iOS and Android while maintaining consistent functionality
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  bool isWriteMode = true;
  StreamSubscription<User?>? _authSubscription;

  @override
  void initState() {
    super.initState();
    // Listen to auth state changes
    _authSubscription = FirebaseRepository().authStateChanges.listen((user) {
      if (mounted) {
        setState(() {}); // Rebuild when auth state changes
      }
    });
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleCreateList() async {
    final firebaseRepository = FirebaseRepository();
    final localRepository = LocalRepository();
    final user = firebaseRepository.currentUser;
    final newList = UserList(
      name: 'New List',
      icon: '📝',
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      items: [],
    );
    if (user == null) {
      await localRepository.saveList(newList);
    } else {
      await firebaseRepository.saveList(newList);
    }
    setState(() {}); // Triggers rebuild to show the new list
  }

  Future<void> handleLogin() async {
    final firebaseRepository = FirebaseRepository();
    final localRepository = LocalRepository();

    // Get local lists before login
    final localLists = await localRepository.loadLists();

    // Show login dialog
    if (!mounted) return;
    await showDialog(
      context: context,
      builder: (context) => LoginDialog(
        firebaseRepository: firebaseRepository,
      ),
    );

    // After successful login, synchronize lists
    if (firebaseRepository.currentUser != null) {
      try {
        // Synchronize lists between local and cloud storage
        final synchronizedLists =
            await firebaseRepository.synchronizeLists(localLists);
        // Save synchronized lists to local storage
        await localRepository.saveAllLists(synchronizedLists);

        // If there are lists and no list is currently open, switch to the most recently opened list
        if (synchronizedLists.isNotEmpty) {
          // Sort lists by lastOpenedAt to find the most recent
          synchronizedLists
              .sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
          final mostRecentList = synchronizedLists.first;

          // Update the lastOpenedAt timestamp
          mostRecentList.updateLastOpened();
          await localRepository.saveList(mostRecentList);
          if (firebaseRepository.currentUser != null) {
            await firebaseRepository.saveList(mostRecentList);
          }
        }

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Successfully logged in and synchronized lists')),
          );
          // Trigger rebuild to show the most recent list
          setState(() {});
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Error synchronizing lists: $e')),
          );
        }
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    const platformNav = PlatformNavigation();
    final firebaseRepository = FirebaseRepository();

    UserList? recentList;
    Widget buildBody() {
      final user = firebaseRepository.currentUser;
      // Always use local storage when not logged in
      if (user == null) {
        return FutureBuilder<List<UserList>>(
          future: LocalRepository().loadLists(),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return Center(child: Text('Error: ${snapshot.error}'));
            }
            if (!snapshot.hasData) {
              return const Center(child: CircularProgressIndicator());
            }
            final lists = snapshot.data!;
            if (lists.isEmpty) {
              return EmptyListsState(
                onCreateList: _handleCreateList,
              );
            }
            // Find the most recently opened list
            lists.sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
            recentList = lists.first;
            return _ListDetailPage(
              list: recentList!,
              isWriteMode: isWriteMode,
              onToggleWriteMode: () =>
                  setState(() => isWriteMode = !isWriteMode),
              showBackButton: false,
            );
          },
        );
      }

      // Only use Firestore when logged in
      return StreamBuilder<List<UserList>>(
        stream: firebaseRepository.streamLists(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(child: Text('Error: ${snapshot.error}'));
          }
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final lists = snapshot.data!;
          if (lists.isEmpty) {
            return EmptyListsState(
              onCreateList: _handleCreateList,
            );
          }
          // Find the most recently opened list
          lists.sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
          recentList = lists.first;
          return _ListDetailPage(
            list: recentList!,
            isWriteMode: isWriteMode,
            onToggleWriteMode: () => setState(() => isWriteMode = !isWriteMode),
            showBackButton: false,
          );
        },
      );
    }

    if (Platform.isIOS) {
      return CupertinoPageScaffold(
        navigationBar: CupertinoNavigationBar(
          middle: const Text('Tickify'),
          leading: CupertinoButton(
            padding: EdgeInsets.zero,
            child: const Icon(CupertinoIcons.line_horizontal_3),
            onPressed: () => platformNav.showPlatformNavigation(context),
          ),
        ),
        child: SafeArea(
          child: buildBody(),
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Tickify'),
        actions: [
          if (recentList != null) // Only show toggle when there is a list open
            IconButton(
              icon: Icon(isWriteMode ? Icons.edit : Icons.visibility),
              onPressed: () => setState(() => isWriteMode = !isWriteMode),
              tooltip:
                  isWriteMode ? 'Switch to read-only' : 'Switch to write mode',
            ),
        ],
      ),
      drawer: platformNav,
      body: buildBody(),
    );
  }
}

class _ListDetailPage extends StatefulWidget {
  final UserList list;
  final bool isWriteMode;
  final VoidCallback onToggleWriteMode;
  final bool showBackButton;
  const _ListDetailPage({
    required this.list,
    required this.isWriteMode,
    required this.onToggleWriteMode,
    this.showBackButton = true,
  });

  @override
  State<_ListDetailPage> createState() => _ListDetailPageState();
}

class _ListDetailPageState extends State<_ListDetailPage> {
  bool showArchived = false;
  bool isEditingName = false;
  late TextEditingController _nameController;
  bool showEmojiPicker = false;

  @override
  void initState() {
    super.initState();
    _nameController = TextEditingController(text: widget.list.name);
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _submitName() async {
    setState(() {
      widget.list.name = _nameController.text.trim().substring(
          0,
          _nameController.text.trim().length > 30
              ? 30
              : _nameController.text.trim().length);
      widget.list.updateLastModified();
      isEditingName = false;
    });
    // Save to SharedPreferences
    final localRepository = LocalRepository();
    await localRepository.saveList(widget.list);
    // If logged in, also save to Firestore
    final firebaseRepository = FirebaseRepository();
    if (firebaseRepository.currentUser != null) {
      await firebaseRepository.saveList(widget.list);
    }
  }

  Future<void> _pickEmoji() async {
    if (!widget.isWriteMode) return;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return EmojiPicker(
          onEmojiSelected: (category, emoji) async {
            setState(() {
              widget.list.icon = emoji.emoji;
              widget.list.updateLastModified();
            });
            // Save to SharedPreferences
            final localRepository = LocalRepository();
            await localRepository.saveList(widget.list);
            // If logged in, also save to Firestore
            final firebaseRepository = FirebaseRepository();
            if (firebaseRepository.currentUser != null) {
              await firebaseRepository.saveList(widget.list);
            }
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final list = widget.list;
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (widget.isWriteMode)
                GestureDetector(
                  onTap: _pickEmoji,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 0, right: 8),
                    child: Text(
                      list.icon,
                      style: const TextStyle(fontSize: 40),
                    ),
                  ),
                ),
              Expanded(
                child: EditableTextField(
                  text: list.name,
                  isEditable: widget.isWriteMode,
                  maxLength: 30,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 32),
                  onSubmitted: (newName) async {
                    setState(() {
                      list.name = newName;
                      list.updateLastModified();
                    });
                    // Save to SharedPreferences
                    final localRepository = LocalRepository();
                    await localRepository.saveList(list);
                    // If logged in, also save to Firestore
                    final firebaseRepository = FirebaseRepository();
                    if (firebaseRepository.currentUser != null) {
                      await firebaseRepository.saveList(list);
                    }
                  },
                ),
              ),
              if (widget.isWriteMode) ...[
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    setState(() {
                      isEditingName = true;
                      _nameController.text = list.name;
                    });
                  },
                ),
                IconButton(
                  icon: Icon(
                      showArchived ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => showArchived = !showArchived),
                  tooltip: showArchived
                      ? 'Hide archived items'
                      : 'Show archived items',
                ),
              ],
            ],
          ),
          const SizedBox(height: 32),
          // TODO: Render the list items as a tree with categories and subcategories
          Expanded(
            child: Center(
              child: Text(
                'No items yet. Add items to your list!',
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
