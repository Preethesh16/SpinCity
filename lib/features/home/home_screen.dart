import 'dart:convert';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../profile/profile_screen.dart';
import '../subscription/subscription_screen.dart';
import '../services/services_screen.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  int _selectedIndex = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [const _HomeTab(), const _OrdersTab(), const _ProfileTab()];

    return Scaffold(
      body: pages[_selectedIndex],
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: _selectedIndex,
        onTap: (i) => setState(() => _selectedIndex = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: 'Home'),
          BottomNavigationBarItem(
            icon: Icon(Icons.shopping_bag_outlined),
            label: 'Orders',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.person_outline),
            label: 'Profile',
          ),
        ],
      ),
    );
  }
}

/// --------- HOME TAB ---------
class _HomeTab extends StatefulWidget {
  const _HomeTab();

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  String? _locationLabel; // e.g. "Kankanady, Mangalore"

  String? _subscriptionType; // 'student' or 'professional'
  bool _subscriptionActive = false;
  // e.g. "Kankanady, Mangalore"
  String? _pincode; // e.g. "575028"
  DateTime? _subscriptionEnd;

  @override
  void initState() {
    super.initState();
    _loadSavedLocation();
  }

  Future<void> _loadSavedLocation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    final data = doc.data();
    if (data != null && mounted) {
      final ts = data['subscriptionEnd'] as Timestamp?;
      DateTime? end = ts?.toDate();

      bool active = (data['subscriptionActive'] as bool?) ?? false;
      if (end != null && end.isBefore(DateTime.now())) {
        // auto-mark as inactive if expired
        active = false;
      }

      setState(() {
        _locationLabel = data['locationLabel'] as String?;
        _pincode = data['pincode']?.toString();
        _subscriptionType = data['subscriptionType'] as String?;
        _subscriptionActive = active;
        _subscriptionEnd = end;
      });
    }
  }

  Future<void> _openLocationPicker() async {
    final result = await Navigator.of(context).push<Map<String, dynamic>>(
      MaterialPageRoute(builder: (_) => const LocationPickerScreen()),
    );

    if (result != null && mounted) {
      setState(() {
        _locationLabel = result['locationLabel'] as String?;
        _pincode = result['pincode']?.toString();
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final displayLocation =
        (_locationLabel != null &&
            _locationLabel!.isNotEmpty &&
            _pincode != null &&
            _pincode!.isNotEmpty)
        ? '$_locationLabel, $_pincode'
        : (_locationLabel ?? 'Set your location');

    return Scaffold(
      appBar: AppBar(
        title: const Text('SpinCity'),
        elevation: 0,
        backgroundColor: Colors.white,
        foregroundColor: Colors.black,
      ),
      backgroundColor: Colors.white,
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            /// 🔹 Blinkit-style location row
            GestureDetector(
              onTap: _openLocationPicker,
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const Icon(Icons.location_on_outlined, size: 22),
                  const SizedBox(width: 8),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Deliver to',
                        style: TextStyle(
                          fontSize: 12,
                          color: Colors.grey.shade600,
                        ),
                      ),
                      Row(
                        children: [
                          Text(
                            displayLocation,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 4),
                          const Icon(Icons.keyboard_arrow_down, size: 18),
                        ],
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(height: 24),

            const Text(
              'Welcome to SpinCity 👕',
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),

            const SizedBox(height: 24),

            // Your two cards: Services & My Subscription
            Row(
              children: [
                Expanded(
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const ServicesScreen(),
                          ),
                        );
                      },
                      child: const Padding(
                        padding: EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.local_laundry_service, size: 32),
                            SizedBox(height: 8),
                            Text('Services'),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

                const SizedBox(width: 12),
                Expanded(
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => SubscriptionScreen(
                              currentType: _subscriptionType,
                              isActive: _subscriptionActive,
                              currentEnd: _subscriptionEnd, // 👈 NEW
                            ),
                          ),
                        );
                        if (mounted) {
                          _loadSavedLocation();
                        }
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(
                              !_subscriptionActive
                                  ? Icons.subscriptions_outlined
                                  : (_subscriptionType == 'student'
                                        ? Icons.school
                                        : Icons.work_outline),
                              size: 32,
                            ),
                            const SizedBox(height: 8),
                            Text(
                              !_subscriptionActive || _subscriptionType == null
                                  ? 'My Subscription'
                                  : (_subscriptionType == 'student'
                                        ? 'SpinCitizen (Student)'
                                        : 'SpinCitizen (Professional)'),
                              textAlign: TextAlign.center,
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 24),
            const Text(
              'More features coming soon...',
              style: TextStyle(color: Colors.grey),
            ),
          ],
        ),
      ),
    );
  }
}

/// --------- ORDERS TAB ---------
class _OrdersTab extends StatelessWidget {
  const _OrdersTab();

  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      return const Scaffold(
        body: Center(child: Text('Not logged in')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('My Orders')),
      body: StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
        stream: FirebaseFirestore.instance
            .collection('orders')
            .where('userId', isEqualTo: user.uid)
            .orderBy('createdAt', descending: true)
            .snapshots(),
        builder: (context, snap) {
          if (snap.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }

          if (!snap.hasData || snap.data!.docs.isEmpty) {
            return const Center(
              child: Text('No orders yet. Go to Services and place one!'),
            );
          }

          final docs = snap.data!.docs;

          return ListView.builder(
            itemCount: docs.length,
            itemBuilder: (context, i) {
              final data = docs[i].data();
              final label = data['serviceLabel']?.toString() ?? 'Service';
              final status = data['status']?.toString() ?? 'placed';
              final count = data['clothesCount']?.toString() ?? '?';
              final location = data['locationLabel']?.toString() ?? '';
              final ts = data['createdAt'] as Timestamp?;
              final dateStr = ts != null
                  ? ts.toDate().toLocal().toString().split('.').first
                  : '';

              return ListTile(
                leading: const Icon(Icons.local_laundry_service),
                title: Text(label),
                subtitle: Text(
                  'Clothes: $count • Status: $status'
                  '${location.isNotEmpty ? '\n$location' : ''}'
                  '${dateStr.isNotEmpty ? '\n$dateStr' : ''}',
                ),
              );
            },
          );
        },
      ),
    );
  }
}


/// --------- PROFILE TAB ---------
class _ProfileTab extends StatelessWidget {
  const _ProfileTab();

  @override
  Widget build(BuildContext context) {
    return const ProfileScreen();
  }
}

/// --------- LOCATION PICKER SCREEN ---------
class LocationPickerScreen extends StatefulWidget {
  const LocationPickerScreen({super.key});

  @override
  State<LocationPickerScreen> createState() => _LocationPickerScreenState();
}

class _LocationPickerScreenState extends State<LocationPickerScreen> {
  final MapController _mapController = MapController();

  LatLng? _current; // blue dot
  LatLng? _selected; // user-tapped pin

  bool _loading = true;
  String? _error;
  bool _mapReady = false; // <-- important to avoid LateInitializationError

  @override
  void initState() {
    super.initState();
    _initLocation();
  }

  Future<void> _initLocation() async {
    try {
      // 1) Check service
      final serviceEnabled = await Geolocator.isLocationServiceEnabled();
      if (!serviceEnabled) {
        setState(() {
          _error = 'Location services are disabled.';
          _loading = false;
        });
        return;
      }

      // 2) Check permission
      LocationPermission permission = await Geolocator.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await Geolocator.requestPermission();
      }
      if (permission == LocationPermission.deniedForever ||
          permission == LocationPermission.denied) {
        setState(() {
          _error = 'Location permission denied.';
          _loading = false;
        });
        return;
      }

      // 3) Get current position
      final position = await Geolocator.getCurrentPosition(
        desiredAccuracy: LocationAccuracy.high,
      );

      final here = LatLng(position.latitude, position.longitude);

      setState(() {
        _current = here;
        _selected = here; // default selection = current
        _loading = false;
      });

      // 4) Optional: listen to live updates (blue dot moves)
      Geolocator.getPositionStream(
        locationSettings: const LocationSettings(
          accuracy: LocationAccuracy.high,
          distanceFilter: 5,
        ),
      ).listen((pos) {
        final live = LatLng(pos.latitude, pos.longitude);
        setState(() {
          _current = live;
          // If user hasn't manually moved pin yet, follow current
          _selected ??= live;
        });

        // If you WANT camera to follow, make sure map is ready:
        if (_mapReady) {
          _mapController.move(live, _mapController.camera.zoom);
        }
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _onMapTap(TapPosition tapPos, LatLng latlng) {
    setState(() {
      _selected = latlng;
    });
  }

  Future<void> _saveLocation() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || _selected == null) {
      Navigator.of(context).pop();
      return;
    }

    final lat = _selected!.latitude;
    final lng = _selected!.longitude;

    // --- Reverse geocode using Nominatim (OpenStreetMap) ---
    String? pincode;
    String? label;

    try {
      final uri = Uri.parse(
        'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lng&zoom=18&addressdetails=1',
      );

      final res = await http.get(
        uri,
        headers: {'User-Agent': 'spincity-app/1.0 (your_email@example.com)'},
      );

      if (res.statusCode == 200) {
        final data = jsonDecode(res.body) as Map<String, dynamic>;
        final address = data['address'] as Map<String, dynamic>?;

        pincode = address?['postcode']?.toString();
        final city =
            address?['city'] ?? address?['town'] ?? address?['village'] ?? '';
        final suburb = address?['suburb'] ?? address?['neighbourhood'] ?? '';

        if (city.toString().isNotEmpty && suburb.toString().isNotEmpty) {
          label = '$suburb, $city';
        } else if (city.toString().isNotEmpty) {
          label = city.toString();
        } else {
          label =
              data['display_name']?.toString().split(',').first ?? 'My area';
        }
      }
    } catch (e) {
      // ignore, we'll just not have pincode/label
    }

    // --- Update Firestore user doc ---
    await FirebaseFirestore.instance.collection('users').doc(user.uid).update({
      'lat': lat,
      'lng': lng,
      if (pincode != null) 'pincode': pincode,
      if (label != null) 'locationLabel': label,
    });

    Navigator.of(context).pop(<String, dynamic>{
      'lat': lat,
      'lng': lng,
      'pincode': pincode,
      'locationLabel': label ?? 'My location',
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Select location')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                if (_error != null)
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(
                      _error!,
                      style: const TextStyle(color: Colors.red),
                    ),
                  ),
                const Padding(
                  padding: EdgeInsets.all(16),
                  child: Align(
                    alignment: Alignment.centerLeft,
                    child: Text(
                      'We use your GPS to detect location.\nTap on the map to mark your exact pickup point.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ),
                ),
                Expanded(
                  child: FlutterMap(
                    mapController: _mapController,
                    options: MapOptions(
                      initialCenter: _current ?? LatLng(12.9716, 77.5946),
                      initialZoom: 14,
                      onTap: _onMapTap,
                      onMapReady: () {
                        _mapReady = true;
                        if (_current != null) {
                          _mapController.move(_current!, 16);
                        }
                      },
                    ),
                    children: [
                      TileLayer(
                        urlTemplate:
                            'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                        userAgentPackageName: 'com.example.spin_city',
                      ),

                      /// Blue circle for current GPS position
                      if (_current != null)
                        CircleLayer(
                          circles: [
                            CircleMarker(
                              point: _current!,
                              radius: 25,
                              useRadiusInMeter: true,
                              color: Colors.blue.withOpacity(0.2),
                              borderStrokeWidth: 2,
                              borderColor: Colors.blue,
                            ),
                          ],
                        ),

                      /// Red pin for selected delivery point
                      if (_selected != null)
                        MarkerLayer(
                          markers: [
                            Marker(
                              point: _selected!,
                              width: 40,
                              height: 40,
                              child: const Icon(
                                Icons.location_pin,
                                size: 40,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: _selected == null ? null : _saveLocation,
                      child: const Text('Use this location'),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
