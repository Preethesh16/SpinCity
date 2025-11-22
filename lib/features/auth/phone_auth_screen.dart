import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../home/home_screen.dart';

import 'email_auth_screen.dart'; // for ProfileScreen

class PhoneAuthScreen extends StatefulWidget {
  const PhoneAuthScreen({super.key});

  @override
  State<PhoneAuthScreen> createState() => _PhoneAuthScreenState();
}

class _PhoneAuthScreenState extends State<PhoneAuthScreen> {
  final _phone = TextEditingController(text: '+91');
  final _otp = TextEditingController();

  String? _verificationId;
  bool _otpSent = false;
  bool _loading = false;
  String? _error;

  @override
  void dispose() {
    _phone.dispose();
    _otp.dispose();
    super.dispose();
  }

  Future<void> _sendOTP() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _phone.text.trim(),
        verificationCompleted: (cred) async {
          // Android auto-fill case
          await FirebaseAuth.instance.signInWithCredential(cred);
          if (!mounted) return;
          await _handleAfterPhoneLogin();
        },
        verificationFailed: (e) {
          setState(() => _error = e.message ?? 'Verification failed');
        },
        codeSent: (verId, _) {
          setState(() {
            _verificationId = verId;
            _otpSent = true;
          });
        },
        codeAutoRetrievalTimeout: (_) {},
      );
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _verifyOTP() async {
    if (_verificationId == null) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final cred = PhoneAuthProvider.credential(
        verificationId: _verificationId!,
        smsCode: _otp.text.trim(),
      );
      await FirebaseAuth.instance.signInWithCredential(cred);
      if (!mounted) return;
      await _handleAfterPhoneLogin();
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  /// After phone auth success:
  /// - If user has profile → go to ProfileScreen
  /// - Else → go to PhoneProfileScreen to collect full details + email
  Future<void> _handleAfterPhoneLogin() async {
    final user = FirebaseAuth.instance.currentUser!;
    final uid = user.uid;

    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .get();

    if (!mounted) return;

    if (doc.exists) {
      // Profile already exists (maybe from email signup)
      final data = doc.data() ?? {};

      final currentPhone = data['phone'] as String?;
      String phone = user.phoneNumber ?? _phone.text.trim();
      if (!phone.startsWith('+')) {
        phone = '+91${phone.replaceAll('+', '')}';
      }

      if (currentPhone == null || currentPhone.isEmpty) {
        await doc.reference.update({'phone': phone});
      }

      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
    } else {
      // First time with this phone → ask for full profile
      final phone = user.phoneNumber ?? _phone.text.trim();
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => PhoneProfileScreen(phone: phone)),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Phone Login')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Colors.red)),
            if (!_otpSent)
              TextField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone (e.g. +91XXXXXXXXXX)',
                ),
              ),
            if (_otpSent)
              TextField(
                controller: _otp,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Enter OTP'),
              ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: _loading ? null : (_otpSent ? _verifyOTP : _sendOTP),
              child: Text(_otpSent ? 'Verify OTP' : 'Send OTP'),
            ),
          ],
        ),
      ),
    );
  }
}

class PhoneProfileScreen extends StatefulWidget {
  final String phone;
  const PhoneProfileScreen({super.key, required this.phone});

  @override
  State<PhoneProfileScreen> createState() => _PhoneProfileScreenState();
}

class _PhoneProfileScreenState extends State<PhoneProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _loading = false;
  String? _error;

  final _name = TextEditingController();
  final _age = TextEditingController();
  final _address = TextEditingController();
  final _pincode = TextEditingController();
  final _email = TextEditingController();

  String _gender = 'Male';
  String _role = 'Student';

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _address.dispose();
    _pincode.dispose();
    _email.dispose();
    super.dispose();
  }

  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser!;
      final uid = user.uid;
      final email = _email.text.trim();

      // 1) Check if this email is already used by someone else
      final existingEmail = await FirebaseFirestore.instance
          .collection('users')
          .where('email', isEqualTo: email)
          .limit(1)
          .get();

      if (existingEmail.docs.isNotEmpty) {
        setState(() {
          _error =
              'This email is already registered.\nPlease login using email instead.';
        });
        return;
      }

      final profile = {
        'name': _name.text.trim(),
        'age': int.tryParse(_age.text.trim()) ?? 0,
        'address': _address.text.trim(),
        'pincode': _pincode.text.trim(),
        'gender': _gender,
        'role': _role,
        'email': email,
        'phone': widget.phone,
        'createdAt': FieldValue.serverTimestamp(),
      };

      await FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .set(profile);

      if (!mounted) return;
      Navigator.of(
        context,
      ).pushReplacement(MaterialPageRoute(builder: (_) => const HomeScreen()));
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
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Complete your profile')),
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
              Text('Phone: ${widget.phone}'),
              const SizedBox(height: 8),
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    v == null || !v.contains('@') ? 'Enter valid email' : null,
              ),
              TextFormField(
                controller: _name,
                decoration: const InputDecoration(labelText: 'Name'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter name' : null,
              ),
              TextFormField(
                controller: _age,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Age'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter age' : null,
              ),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(labelText: 'Address'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter address' : null,
              ),
              TextFormField(
                controller: _pincode,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Pincode'),
                validator: (v) =>
                    v == null || v.trim().isEmpty ? 'Enter pincode' : null,
              ),
              const SizedBox(height: 8),
              const Text('Gender'),
              Row(
                children: [
                  Radio<String>(
                    value: 'Male',
                    groupValue: _gender,
                    onChanged: (v) => setState(() => _gender = v!),
                  ),
                  const Text('Male'),
                  Radio<String>(
                    value: 'Female',
                    groupValue: _gender,
                    onChanged: (v) => setState(() => _gender = v!),
                  ),
                  const Text('Female'),
                  Radio<String>(
                    value: 'Other',
                    groupValue: _gender,
                    onChanged: (v) => setState(() => _gender = v!),
                  ),
                  const Text('Other'),
                ],
              ),
              const SizedBox(height: 8),
              const Text('You are'),
              Row(
                children: [
                  Radio<String>(
                    value: 'Student',
                    groupValue: _role,
                    onChanged: (v) => setState(() => _role = v!),
                  ),
                  const Text('Student'),
                  Radio<String>(
                    value: 'Professional',
                    groupValue: _role,
                    onChanged: (v) => setState(() => _role = v!),
                  ),
                  const Text('Professional'),
                ],
              ),
              const SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _saveProfile,
                  child: const Text('Save profile'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
