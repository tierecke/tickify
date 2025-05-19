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
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _handleCreateList(BuildContext context) async {
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
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => _ListDetailPage(list: newList),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    const platformNav = PlatformNavigation();
    final firebaseRepository = FirebaseRepository();

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
                onCreateList: () => _handleCreateList(context),
              );
            }
            // TODO: Implement list grid/list view for local lists
            return const Center(child: Text('Your lists will appear here'));
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
                onCreateList: () => _handleCreateList(context),
              );
            }
            // TODO: Implement list grid/list view for Firestore lists
            return const Center(child: Text('Your lists will appear here'));
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
      ),
      drawer: platformNav,
      body: buildBody(),
    );
  }
}

class _ListDetailPage extends StatefulWidget {
  final UserList list;
  const _ListDetailPage({required this.list});

  @override
  State<_ListDetailPage> createState() => _ListDetailPageState();
}

class _ListDetailPageState extends State<_ListDetailPage> {
  bool isWriteMode = true;
  bool showArchived = false;

  @override
  Widget build(BuildContext context) {
    final list = widget.list;
    return Scaffold(
      appBar: AppBar(
        actions: [
          IconButton(
            icon: Icon(isWriteMode ? Icons.visibility : Icons.edit),
            onPressed: () => setState(() => isWriteMode = !isWriteMode),
            tooltip:
                isWriteMode ? 'Switch to read-only' : 'Switch to write mode',
          ),
          if (isWriteMode)
            IconButton(
              icon:
                  Icon(showArchived ? Icons.visibility_off : Icons.visibility),
              onPressed: () => setState(() => showArchived = !showArchived),
              tooltip:
                  showArchived ? 'Hide archived items' : 'Show archived items',
            ),
        ],
      ),
      body: Padding(
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
                if (isWriteMode)
                  IconButton(
                    icon: const Icon(Icons.edit),
                    onPressed: () {
                      // TODO: Implement edit dialog
                    },
                  ),
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
      ),
    );
  }
}
