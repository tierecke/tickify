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
  UserList? recentList;

  @override
  void initState() {
    super.initState();
    // Listen to auth state changes
    _authSubscription = FirebaseRepository().authStateChanges.listen((user) {
      if (mounted) {
        setState(() {}); // Rebuild when auth state changes
      }
    });
    // Load initial list
    _loadRecentList();
  }

  Future<void> _loadRecentList() async {
    final firebaseRepository = FirebaseRepository();
    final user = firebaseRepository.currentUser;
    List<UserList> lists;

    if (user == null) {
      // Load from local storage
      lists = await LocalRepository().loadLists();
    } else {
      // Load from Firestore
      lists = await firebaseRepository.streamLists().first;
    }

    if (lists.isNotEmpty) {
      // Sort lists by lastOpenedAt to find the most recent
      lists.sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
      if (mounted) {
        setState(() {
          recentList = lists.first;
        });
      }
    }
  }

  @override
  void dispose() {
    _authSubscription?.cancel();
    super.dispose();
  }

  Future<void> _handleModeToggle() async {
    if (recentList != null) {
      // Save any pending changes before switching modes
      final localRepository = LocalRepository();
      await localRepository.saveList(recentList!);

      // Reload the list to ensure we have the latest state
      final updatedList = await localRepository.loadList(recentList!.id);
      if (updatedList != null) {
        setState(() {
          recentList = updatedList;
          isWriteMode = !isWriteMode;
        });
      } else {
        setState(() => isWriteMode = !isWriteMode);
      }
    } else {
      setState(() => isWriteMode = !isWriteMode);
    }
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
    setState(() {
      recentList = newList;
    });
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
            if (recentList == null) {
              // Find the most recently opened list
              lists.sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
              setState(() {
                recentList = lists.first;
              });
            }
            return _ListDetailPage(
              list: recentList!,
              isWriteMode: isWriteMode,
              onToggleWriteMode: _handleModeToggle,
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
          if (recentList == null) {
            // Find the most recently opened list
            lists.sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
            setState(() {
              recentList = lists.first;
            });
          }
          return _ListDetailPage(
            list: recentList!,
            isWriteMode: isWriteMode,
            onToggleWriteMode: _handleModeToggle,
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
          trailing: recentList != null
              ? CupertinoButton(
                  padding: EdgeInsets.zero,
                  child: Icon(
                      isWriteMode ? CupertinoIcons.pencil : CupertinoIcons.eye),
                  onPressed: _handleModeToggle,
                )
              : null,
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
              onPressed: _handleModeToggle,
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
  bool hasUnsynchronizedChanges = false;
  late UserList _currentList;

  @override
  void initState() {
    super.initState();
    _currentList = widget.list;
    _nameController = TextEditingController(text: _currentList.name);
  }

  @override
  void didUpdateWidget(_ListDetailPage oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.list != oldWidget.list) {
      _currentList = widget.list;
      _nameController.text = _currentList.name;
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    super.dispose();
  }

  Future<void> _saveLocally() async {
    setState(() {
      hasUnsynchronizedChanges = true;
    });
    // Save to SharedPreferences
    final localRepository = LocalRepository();
    await localRepository.saveList(_currentList);
  }

  Future<void> _handleModeToggle() async {
    // Save any pending changes before switching modes
    await _saveLocally();
    widget.onToggleWriteMode();
  }

  Future<void> _submitName() async {
    setState(() {
      _currentList.name = _nameController.text.trim().substring(
          0,
          _nameController.text.trim().length > 30
              ? 30
              : _nameController.text.trim().length);
      _currentList.updateLastModified();
      isEditingName = false;
    });
    await _saveLocally();
  }

  Future<void> _pickEmoji() async {
    if (!widget.isWriteMode) return;
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return EmojiPicker(
          onEmojiSelected: (category, emoji) async {
            setState(() {
              _currentList.icon = emoji.emoji;
              _currentList.updateLastModified();
            });
            await _saveLocally();
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              GestureDetector(
                onTap: widget.isWriteMode ? _pickEmoji : null,
                child: Padding(
                  padding: const EdgeInsets.only(left: 0, right: 8),
                  child: Text(
                    _currentList.icon,
                    style: const TextStyle(fontSize: 40),
                  ),
                ),
              ),
              Expanded(
                child: EditableTextField(
                  text: _currentList.name,
                  isEditable: widget.isWriteMode,
                  maxLength: 30,
                  style: const TextStyle(
                      fontWeight: FontWeight.bold, fontSize: 32),
                  onSubmitted: (newName) async {
                    setState(() {
                      _currentList.name = newName;
                      _currentList.updateLastModified();
                    });
                    await _saveLocally();
                  },
                ),
              ),
              if (widget.isWriteMode)
                IconButton(
                  icon: Icon(
                      showArchived ? Icons.visibility_off : Icons.visibility),
                  onPressed: () => setState(() => showArchived = !showArchived),
                  tooltip: showArchived
                      ? 'Hide archived items'
                      : 'Show archived items',
                ),
              if (hasUnsynchronizedChanges)
                IconButton(
                  icon: Icon(
                    Icons.sync,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () async {
                    // Save to Firestore
                    final firebaseRepository = FirebaseRepository();
                    if (firebaseRepository.currentUser != null) {
                      await firebaseRepository.saveList(_currentList);
                      setState(() {
                        hasUnsynchronizedChanges = false;
                      });
                      if (mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('List synchronized')),
                        );
                      }
                    }
                  },
                  tooltip: 'Synchronize list',
                ),
            ],
          ),
          const SizedBox(height: 32),
          // TODO: Render the list items as a tree with categories and subcategories
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'No items yet. Add items to your list!',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  const SizedBox(height: 24),
                  SizedBox(
                    height: 56,
                    width: 56,
                    child: FloatingActionButton(
                      onPressed: widget.isWriteMode
                          ? () {
                              // TODO: Implement add item functionality
                            }
                          : null,
                      shape: const CircleBorder(),
                      child: const Text(
                        '+',
                        style: TextStyle(
                          fontSize: 32,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
