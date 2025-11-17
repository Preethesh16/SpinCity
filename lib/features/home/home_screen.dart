import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final uid = FirebaseAuth.instance.currentUser!.uid;
    final userDoc =
        FirebaseFirestore.instance.collection('users').doc(uid).snapshots();

    return Scaffold(
      appBar: AppBar(
        title: const Text('SpinCity'),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await FirebaseAuth.instance.signOut();
            },
          )
        ],
      ),
      body: StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
        stream: userDoc,
        builder: (context, snapshot) {
          if (!snapshot.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final data = snapshot.data!.data() ?? {};
          final name = data['name'] ?? 'Customer';

          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Hi, $name 👋',
                    style: Theme.of(context).textTheme.headlineSmall),
                const SizedBox(height: 16),
                const Text('What do you want to do today?'),
                const SizedBox(height: 12),
                ElevatedButton(
                  onPressed: () {
                    // TODO: go to Place Order screen
                  },
                  child: const Text('Place a new order'),
                ),
                const SizedBox(height: 8),
                ElevatedButton(
                  onPressed: () {
                    // TODO: go to My Orders screen
                  },
                  child: const Text('View my orders'),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}
