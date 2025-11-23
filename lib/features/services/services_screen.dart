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

    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      setState(() => _error = 'Not logged in');
      return;
    }

    if (_lat == null || _lng == null) {
      setState(() => _error = 'Please set your pickup location from Home first.');
      return;
    }

    setState(() {
      _error = null;
      _loading = true;
    });

    try {
      final uid = user.uid;
      final clothesCount = int.tryParse(_clothesController.text.trim()) ?? 0;

      // read subscription to decide whether to increment usage
      final userRef =
          FirebaseFirestore.instance.collection('users').doc(uid);
      final userSnap = await userRef.get();
      final uData = userSnap.data() ?? {};
      final bool hasSub = (uData['subscriptionActive'] as bool?) ?? false;

      // create order
      final ordersRef = FirebaseFirestore.instance.collection('orders');
      await ordersRef.add({
        'userId': uid,
        'serviceType': widget.serviceType,
        'serviceLabel': widget.serviceLabel,
        'clothesCount': clothesCount,
        'status': 'placed',
        'createdAt': FieldValue.serverTimestamp(),
        'locationLabel': _locationLabel,
        'pincode': _pincode,
        'lat': _lat,
        'lng': _lng,
      });

      // increment subscriptionOrdersUsed if subscription is active
      if (hasSub) {
        await userRef.update({
          'subscriptionOrdersUsed': FieldValue.increment(1),
        });
      }

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Order placed successfully!')),
      );

      Navigator.of(context).pop(); // back to Services
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
