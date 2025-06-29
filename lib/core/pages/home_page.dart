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
import '../widgets/emoji_icon.dart';
import '../widgets/add_item_tile.dart';
import '../widgets/confirm_dialog.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import 'package:uuid/uuid.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Main screen of the application with platform-adaptive navigation
/// Renders differently on iOS and Android while maintaining consistent functionality
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => HomePageState();
}

class HomePageState extends State<HomePage> {
  static const bool kInitialWriteMode =
      false; // Set to false for read-only mode
  bool isWriteMode = kInitialWriteMode;
  StreamSubscription<User?>? _authSubscription;
  UserList? recentList;
  final _uuid = Uuid();
  final String kActiveListIdKey = 'active_list_id';

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

    // Try to load the active list id from SharedPreferences
    final prefs = await SharedPreferences.getInstance();
    final activeListId = prefs.getString(kActiveListIdKey);

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
      // Try to find the active list by id
      UserList? activeList;
      if (activeListId != null) {
        activeList = lists.firstWhere(
          (l) => l.id == activeListId,
          orElse: () => lists.first,
        );
      } else {
        // Sort lists by lastOpenedAt to find the most recent
        lists.sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
        activeList = lists.first;
      }
      if (mounted) {
        setState(() {
          recentList = activeList;
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

  Future<void> handleCreateList() async {
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

  Future<void> updateRecentList(UserList updatedList) async {
    if (mounted) {
      setState(() {
        recentList = updatedList;
      });
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
                onCreateList: handleCreateList,
              );
            }
            // Use recentList if set, otherwise find the active list
            UserList? selectedList = recentList;
            if (selectedList == null) {
              // Try to find the active list by id
              SharedPreferences.getInstance().then((prefs) {
                final activeListId = prefs.getString(kActiveListIdKey);
                if (activeListId != null) {
                  selectedList = lists.firstWhere(
                    (l) => l.id == activeListId,
                    orElse: () => lists.first,
                  );
                } else {
                  // If no active list, use the most recent one
                  lists
                      .sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
                  selectedList = lists.first;
                }
                if (mounted) {
                  setState(() {
                    recentList = selectedList;
                  });
                }
              });
              return const Center(child: CircularProgressIndicator());
            }
            return _ListDetailPage(
              key: ValueKey(selectedList.createdAt.toIso8601String()),
              list: selectedList,
              isWriteMode: isWriteMode,
              onToggleWriteMode: _handleModeToggle,
              showBackButton: false,
              onListChanged: updateRecentList,
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
              onCreateList: handleCreateList,
            );
          }
          // Use recentList if set, otherwise find the active list
          UserList? selectedList = recentList;
          if (selectedList == null) {
            // Try to find the active list by id
            SharedPreferences.getInstance().then((prefs) {
              final activeListId = prefs.getString(kActiveListIdKey);
              if (activeListId != null) {
                selectedList = lists.firstWhere(
                  (l) => l.id == activeListId,
                  orElse: () => lists.first,
                );
              } else {
                // If no active list, use the most recent one
                lists.sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
                selectedList = lists.first;
              }
              if (mounted) {
                setState(() {
                  recentList = selectedList;
                });
              }
            });
            return const Center(child: CircularProgressIndicator());
          }
          return _ListDetailPage(
            key: ValueKey(selectedList.createdAt.toIso8601String()),
            list: selectedList,
            isWriteMode: isWriteMode,
            onToggleWriteMode: _handleModeToggle,
            showBackButton: false,
            onListChanged: updateRecentList,
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
  final void Function(UserList)? onListChanged;
  const _ListDetailPage({
    Key? key,
    required this.list,
    required this.isWriteMode,
    required this.onToggleWriteMode,
    this.showBackButton = true,
    this.onListChanged,
  }) : super(key: key);

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
  String _newItemEmoji = '🐶';
  bool _isSubmittingNewItem = false;
  final uuid = Uuid();

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
      await localRepository.saveList(_currentList);
      // Verify the save
      final savedList = await localRepository.loadList(_currentList.id);
      if (savedList != null) {
        if (savedList.items.length != _currentList.items.length) {
          throw Exception('Item count mismatch after save');
        }
        setState(() {
          _currentList = savedList;
        });
        if (widget.onListChanged != null) {
          widget.onListChanged!(savedList);
        }
      }
    } catch (e) {
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
      _newItemEmoji = '🐶';
    });
    // Focus the text field after the widget is built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_currentList.items.isNotEmpty) {
        Scrollable.ensureVisible(
          context,
          duration: const Duration(milliseconds: 300),
          alignment: 1.0,
        );
      }
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
        id: uuid.v4(),
      );

      // Create a new list instance with the updated items (append to end)
      final updatedList = UserList(
        name: _currentList.name,
        icon: _currentList.icon,
        id: _currentList.id,
        items: [
          ..._currentList.items,
          newItem
        ], // Use spread operator to ensure proper order
        ownerId: _currentList.ownerId,
        shared: _currentList.shared,
        isArchived: _currentList.isArchived,
        createdAt: _currentList.createdAt,
        lastOpenedAt: _currentList.lastOpenedAt,
        lastModifiedAt: DateTime.now(),
        hasUnsynchronizedChanges: true,
      );

      // Update state in a single setState call
      setState(() {
        _currentList = updatedList;
        _isAddingNewItem = false;
        _newItemText = '';
        _newItemEmoji = '🐶';
      });

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

  Future<void> _handleArchiveAction(int index) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: showArchived ? 'Unarchive Item' : 'Archive Item',
        message: showArchived
            ? 'Are you sure you want to unarchive this item?'
            : 'Are you sure you want to archive this item?',
        yesTitle: showArchived ? 'Unarchive' : 'Archive',
        noTitle: 'Cancel',
      ),
    );
    if (result == true) {
      setState(() {
        _currentList.items[index].isArchived =
            !_currentList.items[index].isArchived;
        _currentList.updateLastModified();
      });
      await _saveLocally();
    }
  }

  Widget _buildReorderableItem(BuildContext context, int index) {
    if (index == _currentList.items.length) {
      if (_isAddingNewItem) {
        return Padding(
          key: const ValueKey('new_item_input'),
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
        );
      } else {
        return AddItemTile(
          key: const ValueKey('add_item_tile'),
          onTap: _addNewItem,
          isWriteMode: widget.isWriteMode,
        );
      }
    }
    final item = _currentList.items[index];
    return Slidable(
      key: ValueKey(item.id),
      enabled: widget.isWriteMode,
      endActionPane: widget.isWriteMode
          ? ActionPane(
              motion: const DrawerMotion(),
              extentRatio: 0.70,
              children: [
                SlidableAction(
                  onPressed: (context) async {
                    final result = await showDialog<bool>(
                      context: context,
                      builder: (context) => const ConfirmDialog(
                        title: 'Delete Item',
                        message: 'Are you sure you want to delete this item?',
                        yesTitle: 'Delete',
                        noTitle: 'Cancel',
                      ),
                    );
                    if (result == true) {
                      setState(() {
                        _currentList.items.removeAt(index);
                        _currentList.updateLastModified();
                      });
                      await _saveLocally();
                    }
                  },
                  backgroundColor: Colors.red[900]!,
                  foregroundColor: Colors.white,
                  icon: Icons.delete,
                  label: 'Delete',
                ),
                SlidableAction(
                  onPressed: (context) => _handleArchiveAction(index),
                  backgroundColor: item.isArchived
                      ? Colors.blue[900]!
                      : Colors.blueGrey[900]!,
                  foregroundColor: Colors.white,
                  icon: item.isArchived ? Icons.unarchive : Icons.archive,
                  label: item.isArchived ? 'Unarchive' : 'Archive',
                ),
              ],
            )
          : null,
      child: ListTile(
        leading: Checkbox(
          value: item.isDone,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
          onChanged: !widget.isWriteMode
              ? (checked) async {
                  setState(() {
                    item.isDone = checked ?? false;
                    _currentList.updateLastModified();
                  });
                  await _saveLocally();
                }
              : null,
        ),
        title: Row(
          children: [
            EmojiIcon(
              emoji: item.icon,
              size: 20,
              editable: widget.isWriteMode,
              onEmojiSelected: (newEmoji) async {
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
                final updatedList = UserList(
                  name: _currentList.name,
                  icon: _currentList.icon,
                  id: _currentList.id,
                  items: _currentList.items
                      .map((i) => i.id == item.id ? updatedItem : i)
                      .toList(),
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
                });
                await _saveLocally();
              },
            ),
            const SizedBox(width: 8),
            Expanded(
              child: EditableTextField(
                text: item.name,
                isEditable: widget.isWriteMode,
                style: const TextStyle(fontSize: 16),
                onSubmitted: (newName) async {
                  setState(() {
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
                    final updatedList = UserList(
                      name: _currentList.name,
                      icon: _currentList.icon,
                      id: _currentList.id,
                      items: _currentList.items
                          .map((i) => i.id == item.id ? updatedItem : i)
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
            ),
          ],
        ),
        trailing: widget.isWriteMode
            ? ReorderableDragStartListener(
                index: index,
                child: const Icon(Icons.more_vert),
              )
            : null,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 24.0),
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
          const SizedBox(height: 16),
          Expanded(
            child: ((_currentList.items.isEmpty && !_isAddingNewItem) ||
                    (_currentList.items
                            .where((item) => !item.isArchived || showArchived)
                            .isEmpty &&
                        !_isAddingNewItem))
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
                : ReorderableListView.builder(
                    itemCount: _currentList.items
                            .where((item) => !item.isArchived || showArchived)
                            .length +
                        (widget.isWriteMode
                            ? 1
                            : 0), // Only add 1 for Add Item tile in write mode
                    onReorder: (oldIndex, newIndex) async {
                      if (!widget.isWriteMode) return;
                      final visibleItems = _currentList.items
                          .where((item) => !item.isArchived || showArchived)
                          .toList();

                      if (oldIndex >= visibleItems.length ||
                          newIndex > visibleItems.length) return;

                      setState(() {
                        if (newIndex > oldIndex) newIndex--;
                        final item = visibleItems[oldIndex];
                        final actualOldIndex = _currentList.items.indexOf(item);
                        final actualNewIndex = newIndex == visibleItems.length
                            ? _currentList.items.length
                            : _currentList.items
                                .indexOf(visibleItems[newIndex]);

                        _currentList.items.removeAt(actualOldIndex);
                        _currentList.items.insert(actualNewIndex, item);
                        _currentList.updateLastModified();
                      });
                      await _saveLocally();
                      if (widget.onListChanged != null) {
                        widget.onListChanged!(_currentList);
                      }
                    },
                    buildDefaultDragHandles: false,
                    itemBuilder: (context, index) {
                      final visibleItems = _currentList.items
                          .where((item) => !item.isArchived || showArchived)
                          .toList();

                      if (index == visibleItems.length && widget.isWriteMode) {
                        return _buildReorderableItem(
                            context, _currentList.items.length);
                      }

                      final item = visibleItems[index];
                      final actualIndex = _currentList.items.indexOf(item);
                      return _buildReorderableItem(context, actualIndex);
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
