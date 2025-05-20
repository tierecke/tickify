import 'package:flutter/material.dart';
import 'package:flutter_slidable/flutter_slidable.dart';
import '../models/user_list.dart';
import '../repositories/local_repository.dart';
import '../widgets/emoji_icon.dart';
import '../widgets/empty_lists_state.dart';
import '../widgets/confirm_dialog.dart';

class ManageListsPage extends StatefulWidget {
  const ManageListsPage({Key? key}) : super(key: key);

  @override
  State<ManageListsPage> createState() => _ManageListsPageState();
}

class _ManageListsPageState extends State<ManageListsPage> {
  List<UserList> _lists = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _loadLists();
  }

  Future<void> _loadLists() async {
    final lists = await LocalRepository().loadLists();
    lists.sort((a, b) => b.lastOpenedAt.compareTo(a.lastOpenedAt));
    setState(() {
      _lists = lists;
      _loading = false;
    });
  }

  Future<void> _deleteList(UserList list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: 'Delete List',
        message:
            'Are you sure you want to delete "${list.name}"? This cannot be undone.',
        yesTitle: 'Delete',
        noTitle: 'Cancel',
      ),
    );
    if (confirmed == true) {
      _lists.removeWhere((l) => l.id == list.id);
      await LocalRepository().saveAllLists(_lists);
      setState(() {});
    }
  }

  Future<void> _archiveList(UserList list) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => ConfirmDialog(
        title: list.isArchived ? 'Unarchive List' : 'Archive List',
        message: list.isArchived
            ? 'Unarchive "${list.name}"?'
            : 'Archive "${list.name}"? You can always unarchive it later.',
        yesTitle: list.isArchived ? 'Unarchive' : 'Archive',
        noTitle: 'Cancel',
      ),
    );
    if (confirmed == true) {
      setState(() {
        list.isArchived = !list.isArchived;
        list.updateLastModified();
      });
      await LocalRepository().saveAllLists(_lists);
    }
  }

  void _setActiveList(UserList list) async {
    // Update lastOpenedAt and save
    setState(() {
      list.updateLastOpened();
    });
    await LocalRepository().saveAllLists(_lists);
    if (mounted) {
      Navigator.of(context).pop(list);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Manage Lists'),
        centerTitle: true,
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _lists.isEmpty
              ? EmptyListsState(onCreateList: () async {
                  // Optionally, you could navigate to create a new list here
                  Navigator.of(context).pop();
                })
              : ListView.separated(
                  itemCount: _lists.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final list = _lists[index];
                    return Slidable(
                      key: ValueKey(list.id),
                      startActionPane: ActionPane(
                        motion: const DrawerMotion(),
                        extentRatio: 0.5,
                        children: [
                          SlidableAction(
                            onPressed: (_) => _deleteList(list),
                            backgroundColor: Colors.red[900]!,
                            foregroundColor: Colors.white,
                            icon: Icons.delete,
                            label: 'Delete',
                          ),
                          SlidableAction(
                            onPressed: (_) => _archiveList(list),
                            backgroundColor: list.isArchived
                                ? Colors.blue[900]!
                                : Colors.blueGrey[900]!,
                            foregroundColor: Colors.white,
                            icon: list.isArchived
                                ? Icons.unarchive
                                : Icons.archive,
                            label: list.isArchived ? 'Unarchive' : 'Archive',
                          ),
                        ],
                      ),
                      child: ListTile(
                        leading: EmojiIcon(
                          emoji: list.icon,
                          size: 32,
                          editable: false,
                          onEmojiSelected: (_) {},
                        ),
                        title: Text(
                          list.name,
                          style: const TextStyle(
                              fontSize: 20, fontWeight: FontWeight.w500),
                        ),
                        onTap: () => _setActiveList(list),
                        trailing: list.isArchived
                            ? const Icon(Icons.lock_outline, color: Colors.grey)
                            : null,
                      ),
                    );
                  },
                ),
    );
  }
}
