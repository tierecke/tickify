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
import '../models/list_item.dart';
import 'package:emoji_picker_flutter/emoji_picker_flutter.dart';
import '../widgets/editable_text_field.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'dart:convert';
import '../widgets/emoji_icon.dart';
import '../widgets/add_item_tile.dart';

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
    final localRepository = LocalRepository();
    final user = firebaseRepository.currentUser;
    List<UserList> lists;

    // Always load from local storage first
    lists = await localRepository.loadLists();
    print('Loaded ${lists.length} lists from local storage');
    for (var list in lists) {
      print(
          'Local list ${list.id} has unsynchronized changes: ${list.hasUnsynchronizedChanges}');
    }

    if (user != null) {
      // If logged in, also load from Firestore but preserve local changes
      try {
        final cloudLists = await firebaseRepository.streamLists().first;
        print('Loaded ${cloudLists.length} lists from cloud');

        // Create a map of local lists for easy lookup
        final localMap = {for (var list in lists) list.id: list};

        // Merge cloud lists with local lists, preserving local changes
        for (var cloudList in cloudLists) {
          final localList = localMap[cloudList.id];
          if (localList != null) {
            // If we have a local version, only update if it's not modified
            if (!localList.hasUnsynchronizedChanges) {
              // Create a new instance with the cloud data but preserve sync state
              final updatedList = UserList(
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
                hasUnsynchronizedChanges:
                    false, // Cloud lists are always synchronized
              );
              lists.removeWhere((l) => l.id == cloudList.id);
              lists.add(updatedList);
            }
          } else {
            // If we don't have a local version, add the cloud version
            lists.add(cloudList);
          }
        }

        // Save the merged lists back to local storage
        await localRepository.saveAllLists(lists);
      } catch (e) {
        print('Error loading from cloud: $e');
        // Continue with local lists if cloud load fails
      }
    }

    if (lists.isNotEmpty) {
      // Sort lists by lastOpenedAt to find the most recent
      lists.sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
      if (mounted) {
        // Use Future.microtask to schedule the setState after the current build
        Future.microtask(() {
          if (mounted) {
            setState(() {
              recentList = lists.first;
              print(
                  'Selected recent list ${recentList!.id} with unsynchronized changes: ${recentList!.hasUnsynchronizedChanges}');
            });
          }
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
      await localRepository.saveList(newList); // Also save locally
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
    print('Local lists before login: ${localLists.length}');
    for (var list in localLists) {
      print(
          'Local list ${list.id} has unsynchronized changes: ${list.hasUnsynchronizedChanges}');
    }

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
        print('Synchronized lists: ${synchronizedLists.length}');
        for (var list in synchronizedLists) {
          print(
              'Synchronized list ${list.id} has unsynchronized changes: ${list.hasUnsynchronizedChanges}');
        }

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
        print('Error during login sync: $e');
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
              // Use Future.microtask to schedule the setState after the current build
              Future.microtask(() {
                if (mounted) {
                  setState(() {
                    recentList = lists.first;
                  });
                }
              });
              // Show loading indicator while waiting for recentList to be set
              return const Center(child: CircularProgressIndicator());
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
            // Use Future.microtask to schedule the setState after the current build
            Future.microtask(() {
              if (mounted) {
                setState(() {
                  recentList = lists.first;
                });
              }
            });
            // Show loading indicator while waiting for recentList to be set
            return const Center(child: CircularProgressIndicator());
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
  late UserList _currentList;
  final FocusNode _newItemFocusNode = FocusNode();
  bool _isAddingNewItem = false;
  String _newItemText = '';
  String _newItemEmoji = '📝';
  bool _isSubmittingNewItem = false;

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
    _newItemFocusNode.dispose();
    super.dispose();
  }

  Future<void> _saveLocally() async {
    try {
      // Save to SharedPreferences
      final localRepository = LocalRepository();
      print(
          'Before save - List ID: ${_currentList.id}, Items count: ${_currentList.items.length}');
      print(
          'Has unsynchronized changes: ${_currentList.hasUnsynchronizedChanges}');

      // Save the current list directly
      await localRepository.saveList(_currentList);

      // Verify the save
      final savedList = await localRepository.loadList(_currentList.id);
      print(
          'After save - List ID: ${savedList?.id}, Items count: ${savedList?.items.length}');
      print(
          'Has unsynchronized changes: ${savedList?.hasUnsynchronizedChanges}');

      if (savedList != null) {
        if (savedList.items.length != _currentList.items.length) {
          throw Exception('Item count mismatch after save');
        }
        setState(() {
          _currentList = savedList;
        });
      }
    } catch (e) {
      print('Error saving list locally: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error saving changes: $e')),
        );
      }
    }
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

  Future<void> _addNewItem() async {
    setState(() {
      _isAddingNewItem = true;
      _newItemText = '';
    });
    // Focus the text field after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _newItemFocusNode.requestFocus();
    });
  }

  Future<void> _submitNewItem() async {
    if (_isSubmittingNewItem) return;
    _isSubmittingNewItem = true;
    try {
      if (_newItemText.trim().isEmpty) {
        setState(() {
          _isAddingNewItem = false;
        });
        return;
      }

      // Create new item
      final newItem = ListItem(
        name: _newItemText.trim(),
        icon: _newItemEmoji,
        id: DateTime.now().millisecondsSinceEpoch.toString(),
      );

      print('Adding new item: ${newItem.name} with icon: ${newItem.icon}');

      // Create a new list instance with the updated items
      final updatedList = UserList(
        name: _currentList.name,
        icon: _currentList.icon,
        id: _currentList.id,
        items: [..._currentList.items, newItem],
        ownerId: _currentList.ownerId,
        shared: _currentList.shared,
        isArchived: _currentList.isArchived,
        createdAt: _currentList.createdAt,
        lastOpenedAt: _currentList.lastOpenedAt,
        lastModifiedAt: DateTime.now(),
        hasUnsynchronizedChanges: true,
      );

      setState(() {
        _currentList = updatedList;
        _isAddingNewItem = false;
        _newItemText = '';
        _newItemEmoji = '📝';
      });

      print('Current list items count: ${_currentList.items.length}');
      print(
          'Has unsynchronized changes: ${_currentList.hasUnsynchronizedChanges}');

      // Save to local storage
      await _saveLocally();
    } finally {
      _isSubmittingNewItem = false;
    }
  }

  Future<void> _pickNewItemEmoji() async {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return EmojiPicker(
          onEmojiSelected: (category, emoji) {
            setState(() {
              _newItemEmoji = emoji.emoji;
            });
            Navigator.of(context).pop();
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    print('Building with ${_currentList.items.length} items');
    print(
        'Has unsynchronized changes: ${_currentList.hasUnsynchronizedChanges}');
    return Padding(
      padding: const EdgeInsets.all(24.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              EmojiIcon(
                emoji: _currentList.icon,
                size: 40,
                editable: widget.isWriteMode,
                onEmojiSelected: (newEmoji) async {
                  setState(() {
                    _currentList.icon = newEmoji;
                    _currentList.updateLastModified();
                  });
                  await _saveLocally();
                },
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
              if (_currentList.hasUnsynchronizedChanges)
                IconButton(
                  icon: Icon(
                    Icons.sync,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onPressed: () async {
                    final firebaseRepository = FirebaseRepository();
                    if (firebaseRepository.currentUser != null) {
                      try {
                        // Create a new instance with all current changes
                        final listToSync = UserList(
                          name: _currentList.name,
                          icon: _currentList.icon,
                          id: _currentList.id,
                          items: List<ListItem>.from(_currentList.items),
                          ownerId: firebaseRepository.currentUser!.uid,
                          shared: List<SharedUser>.from(_currentList.shared),
                          isArchived: _currentList.isArchived,
                          createdAt: _currentList.createdAt,
                          lastOpenedAt: DateTime.now(),
                          lastModifiedAt: DateTime.now(),
                          hasUnsynchronizedChanges: false,
                        );

                        // Save to Firebase
                        await firebaseRepository.saveList(listToSync);

                        // Update local state and save to local storage
                        setState(() {
                          _currentList = listToSync;
                        });
                        await _saveLocally();

                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('List synchronized')),
                          );
                        }
                      } catch (e) {
                        print('Error syncing list: $e');
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text('Error synchronizing list: $e')),
                          );
                        }
                      }
                    }
                  },
                  tooltip: 'Synchronize list',
                ),
            ],
          ),
          const SizedBox(height: 32),
          if (_isAddingNewItem)
            Padding(
              padding: const EdgeInsets.only(bottom: 16.0),
              child: Row(
                children: [
                  EmojiIcon(
                    emoji: _newItemEmoji,
                    size: 20,
                    editable: true,
                    onEmojiSelected: (newEmoji) {
                      setState(() {
                        _newItemEmoji = newEmoji;
                      });
                    },
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: EditableTextField(
                      text: _newItemText,
                      isEditable: true,
                      autofocus: true,
                      style: const TextStyle(fontSize: 16),
                      onSubmitted: (value) {
                        _newItemText = value;
                        _submitNewItem();
                      },
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: _currentList.items.isEmpty
                ? Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'No items yet. Add items to your list!',
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                        const SizedBox(height: 24),
                        if (widget.isWriteMode)
                          SizedBox(
                            height: 56,
                            width: 56,
                            child: FloatingActionButton(
                              onPressed: _addNewItem,
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
                  )
                : ListView.builder(
                    itemCount: _currentList.items.length +
                        1, // Add 1 for the AddItemTile
                    itemBuilder: (context, index) {
                      // If this is the last item, show the AddItemTile
                      if (index == _currentList.items.length) {
                        return AddItemTile(
                          onTap: _addNewItem,
                          isWriteMode: widget.isWriteMode,
                        );
                      }

                      final item = _currentList.items[index];
                      print('Building item $index: ${item.name}');
                      return ListTile(
                        leading: EmojiIcon(
                          emoji: item.icon,
                          size: 20,
                          editable: widget.isWriteMode,
                          onEmojiSelected: (newEmoji) async {
                            setState(() {
                              // Create a new item with the updated emoji
                              final updatedItem = ListItem(
                                name: item.name,
                                icon: newEmoji,
                                id: item.id,
                                parentId: item.parentId,
                                isDone: item.isDone,
                                isArchived: item.isArchived,
                                children: item.children,
                                createdAt: item.createdAt,
                              );

                              // Create a new list with the updated item
                              final updatedList = UserList(
                                name: _currentList.name,
                                icon: _currentList.icon,
                                id: _currentList.id,
                                items: _currentList.items
                                    .map((i) =>
                                        i.id == item.id ? updatedItem : i)
                                    .toList(),
                                ownerId: _currentList.ownerId,
                                shared: _currentList.shared,
                                isArchived: _currentList.isArchived,
                                createdAt: _currentList.createdAt,
                                lastOpenedAt: _currentList.lastOpenedAt,
                                lastModifiedAt: DateTime.now(),
                                hasUnsynchronizedChanges: true,
                              );

                              _currentList = updatedList;
                            });
                            await _saveLocally();
                          },
                        ),
                        title: EditableTextField(
                          text: item.name,
                          isEditable: widget.isWriteMode,
                          style: const TextStyle(fontSize: 16),
                          onSubmitted: (newName) async {
                            setState(() {
                              // Create a new item with the updated name
                              final updatedItem = ListItem(
                                name: newName,
                                icon: item.icon,
                                id: item.id,
                                parentId: item.parentId,
                                isDone: item.isDone,
                                isArchived: item.isArchived,
                                children: item.children,
                                createdAt: item.createdAt,
                              );

                              // Create a new list with the updated item
                              final updatedList = UserList(
                                name: _currentList.name,
                                icon: _currentList.icon,
                                id: _currentList.id,
                                items: _currentList.items
                                    .map((i) =>
                                        i.id == item.id ? updatedItem : i)
                                    .toList(),
                                ownerId: _currentList.ownerId,
                                shared: _currentList.shared,
                                isArchived: _currentList.isArchived,
                                createdAt: _currentList.createdAt,
                                lastOpenedAt: _currentList.lastOpenedAt,
                                lastModifiedAt: DateTime.now(),
                                hasUnsynchronizedChanges: true,
                              );

                              _currentList = updatedList;
                            });
                            await _saveLocally();
                          },
                        ),
                        trailing: widget.isWriteMode
                            ? Row(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  IconButton(
                                    icon: Icon(
                                      item.isDone
                                          ? Icons.check_circle
                                          : Icons.circle_outlined,
                                    ),
                                    onPressed: () async {
                                      setState(() {
                                        item.toggleDone();
                                        _currentList.updateLastModified();
                                      });
                                      await _saveLocally();
                                    },
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.archive_outlined),
                                    onPressed: () async {
                                      setState(() {
                                        item.isArchived = true;
                                        _currentList.updateLastModified();
                                      });
                                      await _saveLocally();
                                    },
                                  ),
                                ],
                              )
                            : null,
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
