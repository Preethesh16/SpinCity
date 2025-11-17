import 'package:flutter/material.dart';
import 'features/auth/phone_auth_screen.dart';
import 'features/auth/email_auth_screen.dart';

class AuthChoiceScreen extends StatelessWidget {
  const AuthChoiceScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('SpinCity Login')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const EmailAuthScreen()),
                );
              },
              child: const Text('Login with Email'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
                );
              },
              child: const Text('Login with Phone'),
            ),
          ],
        ),
      ),
    );
  }
}
