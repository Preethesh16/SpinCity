import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'firebase_options.dart';
import 'features/auth/email_auth_screen.dart';
import 'features/auth/phone_auth_screen.dart';
import 'features/home/home_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const SpinCityApp());
}

class SpinCityApp extends StatelessWidget {
  const SpinCityApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'SpinCity',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.blue,
      ),
      home: const RootGate(),
    );
  }
}

/// Listens to FirebaseAuth and decides which screen to show.
class RootGate extends StatelessWidget {
  const RootGate({super.key});

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: FirebaseAuth.instance.authStateChanges(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;
        if (user == null) {
          // Not logged in → choose auth method
          return const AuthChoiceScreen();
        } else {
          // Logged in → go to home
          return const HomeScreen();
        }
      },
    );
  }
}

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
              child: const Text('Login / Register with Email'),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {
                Navigator.of(context).push(
                  MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
                );
              },
              child: const Text('Login with Phone (test numbers only)'),
            ),
          ],
        ),
      ),
    );
  }
}
