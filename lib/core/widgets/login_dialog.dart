import 'package:flutter/material.dart';
import '../repositories/firebase_repository.dart';

class LoginDialog extends StatelessWidget {
  final FirebaseRepository _firebaseRepository;

  const LoginDialog({
    super.key,
    required FirebaseRepository firebaseRepository,
  }) : _firebaseRepository = firebaseRepository;

  @override
  Widget build(BuildContext context) {
    return Dialog(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Sign in to sync your lists',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () async {
                try {
                  await _firebaseRepository.signInWithGoogle();
                  if (context.mounted) {
                    Navigator.of(context).pop();
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(e.toString())),
                    );
                  }
                }
              },
              icon: const Icon(Icons.g_mobiledata, size: 24),
              label: const Text('Continue with Google'),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: const Text('Maybe later'),
            ),
          ],
        ),
      ),
    );
  }
}
