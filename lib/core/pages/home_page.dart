import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../widgets/platform_navigation.dart';
import '../widgets/empty_lists_state.dart';
import '../widgets/login_dialog.dart';
import '../repositories/firebase_repository.dart';
import '../repositories/local_repository.dart';
import '../models/user_list.dart';

/// Main screen of the application with platform-adaptive navigation
/// Renders differently on iOS and Android while maintaining consistent functionality
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  bool isWriteMode = true;

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

  @override
  Widget build(BuildContext context) {
    const platformNav = PlatformNavigation();
    final firebaseRepository = FirebaseRepository();

    UserList? recentList;
    Widget buildBody() {
      if (firebaseRepository.currentUser == null) {
        // Not logged in, load lists from local storage
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
      } else {
        // Logged in, use Firestore
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
              onToggleWriteMode: () =>
                  setState(() => isWriteMode = !isWriteMode),
              showBackButton: false,
            );
          },
        );
      }
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
              Text(
                list.icon,
                style: const TextStyle(fontSize: 40),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  list.name,
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    fontSize: 32,
                  ),
                ),
              ),
              if (widget.isWriteMode) ...[
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () {
                    // TODO: Implement edit dialog
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
