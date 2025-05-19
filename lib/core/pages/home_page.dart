import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';
import '../widgets/platform_navigation.dart';
import '../widgets/empty_lists_state.dart';
import '../widgets/login_dialog.dart';
import '../repositories/firebase_repository.dart';
import '../models/user_list.dart';

/// Main screen of the application with platform-adaptive navigation
/// Renders differently on iOS and Android while maintaining consistent functionality
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  void _handleCreateList(BuildContext context) {
    // TODO: Implement list creation dialog
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('List creation coming soon!')),
    );
  }

  @override
  Widget build(BuildContext context) {
    const platformNav = PlatformNavigation();
    final firebaseRepository = FirebaseRepository();

    Widget buildBody() {
      // If user is not logged in, show empty state with login prompt
      if (firebaseRepository.currentUser == null) {
        return EmptyListsState(
          onCreateList: () {
            showDialog(
              context: context,
              builder: (context) => LoginDialog(
                firebaseRepository: firebaseRepository,
              ),
            );
          },
        );
      }

      return StreamBuilder<List<UserList>>(
        stream: firebaseRepository.streamLists(),
        builder: (context, snapshot) {
          if (snapshot.hasError) {
            return Center(
              child: Text('Error: ${snapshot.error}'),
            );
          }

          if (!snapshot.hasData) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          final lists = snapshot.data!;
          if (lists.isEmpty) {
            return EmptyListsState(
              onCreateList: () => _handleCreateList(context),
            );
          }

          // TODO: Implement list grid/list view
          return const Center(
            child: Text('Your lists will appear here'),
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
      ),
      drawer: platformNav,
      body: buildBody(),
    );
  }
}
