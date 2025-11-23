import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ServicesScreen extends StatelessWidget {
  const ServicesScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Services')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: ListView(
          children: [
            _ServiceCard(
              title: 'Wash & Iron',
              subtitle: 'Complete care for your clothes',
              icon: Icons.local_laundry_service,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => OrderDetailsScreen(
                      serviceType: 'wash_iron',
                      serviceLabel: 'Wash & Iron',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _ServiceCard(
              title: 'Only Wash',
              subtitle: 'Washing service only',
              icon: Icons.water_drop_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => OrderDetailsScreen(
                      serviceType: 'wash_only',
                      serviceLabel: 'Only Wash',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _ServiceCard(
              title: 'Only Iron',
              subtitle: 'Ironing service only',
              icon: Icons.iron_outlined,
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => OrderDetailsScreen(
                      serviceType: 'iron_only',
                      serviceLabel: 'Only Iron',
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 12),
            _ServiceCard(
              title: 'More services coming soon',
              subtitle: 'Stay tuned 👀',
              icon: Icons.upcoming_outlined,
              disabled: true,
              onTap: () {},
            ),
          ],
        ),
      ),
    );
  }
}

class _ServiceCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final VoidCallback onTap;
  final bool disabled;

  const _ServiceCard({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.onTap,
    this.disabled = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: disabled ? 0 : 3,
      color: disabled ? Colors.grey.shade100 : null,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: disabled ? null : onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              Icon(icon, size: 32),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        fontSize: 13,
                        color: Colors.black54,
                      ),
                    ),
                  ],
                ),
              ),
              if (!disabled)
                const Icon(Icons.arrow_forward_ios, size: 16),
            ],
          ),
        ),
      ),
    );
  }
}

/// --------- ORDER DETAILS (ASK NUMBER OF CLOTHES & PLACE ORDER) ---------
class OrderDetailsScreen extends StatefulWidget {
  final String serviceType;  // 'wash_iron', 'wash_only', 'iron_only'
  final String serviceLabel; // for display

  const OrderDetailsScreen({
    super.key,
    required this.serviceType,
    required this.serviceLabel,
  });

  @override
  State<OrderDetailsScreen> createState() => _OrderDetailsScreenState();
}

class _OrderDetailsScreenState extends State<OrderDetailsScreen> {
  final _formKey = GlobalKey<FormState>();
  final _clothesController = TextEditingController();

  bool _loading = true;
  String? _error;

  String? _locationLabel;
  String? _pincode;
  double? _lat;
  double? _lng;

  @override
  void initState() {
    super.initState();
    _loadUserLocationAndSub();
  }

  Future<void> _loadUserLocationAndSub() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() {
        _error = 'Not logged in';
        _loading = false;
      });
      return;
    }

    try {
      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();
      final data = doc.data() ?? {};

      setState(() {
        _locationLabel = data['locationLabel'] as String?;
        _pincode = data['pincode']?.toString();
        _lat = (data['lat'] as num?)?.toDouble();
        _lng = (data['lng'] as num?)?.toDouble();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }
Future<void> _placeOrder() async {
  if (!_formKey.currentState!.validate()) return;

  setState(() {
    _loading = true;
    _error = null;
  });

  try {
    final user = FirebaseAuth.instance.currentUser!;
    final userRef =
        FirebaseFirestore.instance.collection('users').doc(user.uid);

    final userSnap = await userRef.get();
    final data = userSnap.data() ?? {};

    final bool active = data['subscriptionActive'] == true;
    final Timestamp? endTs = data['subscriptionEnd'] as Timestamp?;
    final int limit = (data['subscriptionOrderLimit'] ?? 4) as int;
    final int used = (data['subscriptionOrdersUsed'] ?? 0) as int;

    // 1) Check subscription active + not expired
    if (!active || endTs == null ||
        DateTime.now().isAfter(endTs.toDate())) {
      setState(() {
        _error =
            'No active subscription or it has expired. Please subscribe/renew.';
        _loading = false;
      });
      return;
    }

    // 2) Check that user still has orders left
    if (used >= limit) {
      setState(() {
        _error =
            'You have used all $limit orders in this subscription.';
        _loading = false;
      });
      return;
    }

    // 3) Read location info from user doc (we stored earlier)
    final pickupLabel = data['locationLabel'] ?? 'Not set';
    final pickupPincode = data['pincode'] ?? '';
    final pickupLat = (data['lat'] as num?)?.toDouble();
    final pickupLng = (data['lng'] as num?)?.toDouble();

    // 👇 use your existing controller name
    final clothesCount = int.parse(_clothesController.text.trim());

    // 4) Create the order AND update subscriptionOrdersUsed
    final ordersRef = FirebaseFirestore.instance.collection('orders');

    await ordersRef.add({
      'userId': user.uid,
      'serviceType': widget.serviceType,   // e.g. 'wash_iron'
      'serviceLabel': widget.serviceLabel, // e.g. 'Wash & Iron'
      'clothesCount': clothesCount,
      'pickupLabel': pickupLabel,
      'pickupPincode': pickupPincode,
      'pickupLat': pickupLat,
      'pickupLng': pickupLng,
      'createdAt': FieldValue.serverTimestamp(),
      'status': 'pending',                 // later: picked_up, in_wash, delivered
    });

    // increment orders used
    await userRef.update({
      'subscriptionOrdersUsed': used + 1,
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Order placed ✅')),
    );
    Navigator.of(context).pop(); // go back after placing order
  } catch (e) {
    setState(() {
      _error = e.toString();
    });
  } finally {
    if (mounted) {
      setState(() => _loading = false);
    }
  }
}

  @override
  void dispose() {
    _clothesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: Text(widget.serviceLabel)),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    _error!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              Text(
                'Service: ${widget.serviceLabel}',
                style:
                    const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 12),
              TextFormField(
                controller: _clothesController,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Number of clothes',
                ),
                validator: (v) {
                  final n = int.tryParse(v ?? '');
                  if (n == null || n <= 0) return 'Enter a valid number';
                  return null;
                },
              ),
              const SizedBox(height: 16),
              const Text(
                'Pickup location',
                style: TextStyle(fontSize: 14, fontWeight: FontWeight.w600),
              ),
              const SizedBox(height: 4),
              Text(
                _locationLabel != null
                    ? '${_locationLabel!}${_pincode != null ? ' - $_pincode' : ''}'
                    : 'No location set. Go to Home and set your location.',
                style: const TextStyle(fontSize: 13, color: Colors.black87),
              ),
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _placeOrder,
                  child: const Text('Place Order'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
