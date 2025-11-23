import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class SubscriptionScreen extends StatefulWidget {
  final String? currentType; // 'student' or 'professional'
  final bool isActive;
  final DateTime? currentEnd;

  const SubscriptionScreen({
    super.key,
    this.currentType,
    this.isActive = false,
    this.currentEnd,
  });

  @override
  State<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends State<SubscriptionScreen> {
  bool _loading = false;
  String? _error;

  int _laundryLimitKg = 12;
  int _laundryUsedKg = 0;
  int _orderLimit = 4;
  int _ordersUsed = 0;

  @override
  void initState() {
    super.initState();
    _loadUsage();
  }

  Future<void> _loadUsage() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data();
      if (data == null) return;

      setState(() {
        _laundryLimitKg =
            (data['subscriptionLaundryLimitKg'] as int?) ?? 12;
        _laundryUsedKg =
            (data['subscriptionLaundryUsedKg'] as int?) ?? 0;
        _orderLimit = (data['subscriptionOrderLimit'] as int?) ?? 4;
        _ordersUsed =
            (data['subscriptionOrdersUsed'] as int?) ?? 0;
      });
    } catch (e) {
      // optional: show error
    }
  }

  Future<void> _subscribe(String type) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _error = 'Not logged in');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      // 28 days = 4 weeks
      final now = DateTime.now();
      final end = now.add(const Duration(days: 28));

      await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
        'subscriptionType': type,                 // 'student' or 'professional'
        'subscriptionActive': true,
        'subscriptionStart': FieldValue.serverTimestamp(),
        'subscriptionEnd': Timestamp.fromDate(end),
        'subscriptionDurationDays': 28,

        // usage limits and reset on new subscription / renew
        'subscriptionLaundryLimitKg': 12,
        'subscriptionLaundryUsedKg': 0,
        'subscriptionOrderLimit': 4,
        'subscriptionOrdersUsed': 0,
      });

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Payment successful! You are now a SpinCitizen (${type == 'student' ? 'Student' : 'Professional'}).',
          ),
        ),
      );

      Navigator.of(context).pop();
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Widget _planCard({
    required String type,
    required String title,
    required String price,
    required IconData icon,
  }) {
    final now = DateTime.now();
    final bool isCurrent = widget.currentType == type;
    final bool hasEnd = widget.currentEnd != null;
    final bool isExpired =
        isCurrent && hasEnd && widget.currentEnd!.isBefore(now);

    String? expiryLabel;
    if (isCurrent && hasEnd) {
      final dateStr =
          widget.currentEnd!.toLocal().toString().split(' ').first; // yyyy-mm-dd
      expiryLabel = isExpired ? 'Expired on $dateStr' : 'Expires on $dateStr';
    }

    final laundryText = isCurrent
        ? 'Laundry used: $_laundryUsedKg / $_laundryLimitKg kg'
        : 'Laundry limit: 12 kg per cycle';
    final ordersText = isCurrent
        ? 'Orders used: $_ordersUsed / $_orderLimit'
        : 'Order limit: 4 per cycle';

    return Card(
      elevation: 3,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(icon, size: 32),
                const SizedBox(width: 12),
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const Spacer(),
                if (isCurrent && !isExpired)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.green.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Active',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.green,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  )
                else if (isCurrent && isExpired)
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.red.shade100,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Text(
                      'Expired',
                      style: TextStyle(
                        fontSize: 12,
                        color: Colors.red,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 8),
            Text(
              price,
              style: const TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              '• Free pickup & delivery\n'
              '• 28 days validity (4 weeks)\n'
              '• Priority support',
              style: TextStyle(fontSize: 13, color: Colors.black54),
            ),
            const SizedBox(height: 8),
            Text(
              laundryText,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            Text(
              ordersText,
              style: const TextStyle(fontSize: 13, color: Colors.black87),
            ),
            if (expiryLabel != null) ...[
              const SizedBox(height: 6),
              Text(
                expiryLabel,
                style: TextStyle(
                  fontSize: 12,
                  color: isExpired ? Colors.red : Colors.grey.shade700,
                ),
              ),
            ],
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading
                    ? null
                    : () {
                        // If expired OR not current → subscribe/renew
                        if (!isCurrent || isExpired) {
                          _subscribe(type);
                        }
                      },
                child: Text(
                  isCurrent
                      ? (isExpired ? 'Renew subscription' : 'Already subscribed')
                      : 'Pay & Subscribe',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('SpinCitizen Subscription'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Text(
                  _error!,
                  style: const TextStyle(color: Colors.red),
                ),
              ),
            _planCard(
              type: 'student',
              title: 'Student Plan',
              price: '₹1500 / 28 days',
              icon: Icons.school,
            ),
            const SizedBox(height: 16),
            _planCard(
              type: 'professional',
              title: 'Professional Plan',
              price: '₹2000 / 28 days',
              icon: Icons.work_outline,
            ),
          ],
        ),
      ),
    );
  }
}
