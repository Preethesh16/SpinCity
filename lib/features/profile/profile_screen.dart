import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';

class ProfileScreen extends StatefulWidget {
  const ProfileScreen({super.key});

  @override
  State<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends State<ProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _name = TextEditingController();
  final _age = TextEditingController();
  final _address = TextEditingController();
  final _pincode = TextEditingController();
  final _phone = TextEditingController();
  final _emailDisplay = TextEditingController(); // shown but not edited here

  String _gender = 'Male';
  String _role = 'Student';

  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() {
          _error = 'Not logged in';
          _loading = false;
        });
        return;
      }

      final doc = await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .get();

      final data = doc.data() ?? {};

      _name.text = data['name'] ?? '';
      _age.text = (data['age'] ?? '').toString();
      _address.text = data['address'] ?? '';
      _pincode.text = data['pincode'] ?? '';
      _phone.text = (data['phone'] ?? '').toString().replaceFirst('+91', '');
      _gender = data['gender'] ?? 'Male';
      _role = data['role'] ?? 'Student';
      _emailDisplay.text = data['email'] ?? user.email ?? '';

      setState(() => _loading = false);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  void dispose() {
    _name.dispose();
    _age.dispose();
    _address.dispose();
    _pincode.dispose();
    _phone.dispose();
    _emailDisplay.dispose();
    super.dispose();
  }

  /// Save normal profile fields (name, age, address, pincode, gender, role, phone)
  Future<void> _saveProfile() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _error = null;
    });

    try {
      final user = FirebaseAuth.instance.currentUser;
      if (user == null) {
        setState(() => _error = 'Not logged in');
        return;
      }

      // Normalize phone: always "+91XXXXXXXXXX"
      final digits = _phone.text.replaceAll(RegExp(r'\D'), '');
      final phone = digits.isEmpty ? '' : '+91$digits';

      await FirebaseFirestore.instance
          .collection('users')
          .doc(user.uid)
          .update({
        'name': _name.text.trim(),
        'age': int.tryParse(_age.text.trim()) ?? 0,
        'address': _address.text.trim(),
        'pincode': _pincode.text.trim(),
        'gender': _gender,
        'role': _role,
        'phone': phone,
      });

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Profile updated')),
      );
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  /// Change email with re-auth (needs current password)
  Future<void> _changeEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final emailController = TextEditingController(text: _emailDisplay.text);
    final passwordController = TextEditingController();
    String? localError;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Change email'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (localError != null)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: Text(
                        localError!,
                        style: const TextStyle(color: Colors.red),
                      ),
                    ),
                  TextField(
                    controller: emailController,
                    keyboardType: TextInputType.emailAddress,
                    decoration:
                        const InputDecoration(labelText: 'New email'),
                  ),
                  TextField(
                    controller: passwordController,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Current password',
                    ),
                  ),
                ],
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context, false),
                  child: const Text('Cancel'),
                ),
                TextButton(
                  onPressed: () async {
                    final newEmail = emailController.text.trim();
                    final password = passwordController.text.trim();

                    try {
                      // 1) Re-auth with old email + password
                      final cred = EmailAuthProvider.credential(
                        email: user.email!,
                        password: password,
                      );
                      await user.reauthenticateWithCredential(cred);

                      // 2) Ask Firebase to send verification link
                      await user.verifyBeforeUpdateEmail(newEmail);

                      // 3) (Optional) update Firestore now to keep in sync
                      await FirebaseFirestore.instance
                          .collection('users')
                          .doc(user.uid)
                          .update({'email': newEmail});

                      Navigator.pop(context, true);
                    } on FirebaseAuthException catch (e) {
                      setStateDialog(() {
                        localError = e.message ?? e.code;
                      });
                    } catch (e) {
                      setStateDialog(() {
                        localError = e.toString();
                      });
                    }
                  },
                  child: const Text('Save'),
                ),
              ],
            );
          },
        );
      },
    );

    if (ok == true && mounted) {
      _emailDisplay.text = emailController.text.trim();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Email update requested.\nCheck your inbox to confirm.'),
        ),
      );
    }
  }



  /// Change password with re-auth
  Future<void> _changePassword() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) return;

    final currentController = TextEditingController();
    final newController = TextEditingController();
    String? localError;

    final ok = await showDialog<bool>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Change password'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (localError != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    localError!,
                    style: const TextStyle(color: Colors.red),
                  ),
                ),
              TextField(
                controller: currentController,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'Current password'),
              ),
              TextField(
                controller: newController,
                obscureText: true,
                decoration:
                    const InputDecoration(labelText: 'New password'),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            TextButton(
              onPressed: () async {
                final current = currentController.text.trim();
                final newPass = newController.text.trim();

                try {
                  final cred = EmailAuthProvider.credential(
                    email: _emailDisplay.text.trim(),
                    password: current,
                  );

                  await user.reauthenticateWithCredential(cred);
                  await user.updatePassword(newPass);

                  Navigator.pop(context, true);
                } on FirebaseAuthException catch (e) {
                  localError = e.message ?? e.code;
                  (context as Element).markNeedsBuild();
                } catch (e) {
                  localError = e.toString();
                  (context as Element).markNeedsBuild();
                }
              },
              child: const Text('Save'),
            ),
          ],
        );
      },
    );

    if (ok == true && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Password updated')),
      );
    }
  }

  Future<void> _logout() async {
    await FirebaseAuth.instance.signOut();
    if (!mounted) return;
    Navigator.of(context).pushNamedAndRemoveUntil('/', (_) => false);
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Your Profile')),
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
                  child: Text(_error!, style: const TextStyle(color: Colors.red)),
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
              ),
              TextFormField(
                controller: _address,
                decoration: const InputDecoration(labelText: 'Address'),
              ),
              TextFormField(
                controller: _pincode,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(labelText: 'Pincode'),
              ),
              const SizedBox(height: 8),
              TextFormField(
                controller: _phone,
                keyboardType: TextInputType.phone,
                decoration: const InputDecoration(
                  labelText: 'Phone',
                  prefixText: '+91 ',
                ),
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
              TextFormField(
                controller: _emailDisplay,
                readOnly: true,
                decoration: const InputDecoration(
                  labelText: 'Email (tap button below to change)',
                ),
              ),
              const SizedBox(height: 8),

              Row(
                children: [
                  Expanded(
                    child: ElevatedButton(
                      onPressed: _saveProfile,
                      child: const Text('Save profile'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _changeEmail,
                      child: const Text('Change email'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _changePassword,
                      child: const Text('Change password'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Center(
                child: TextButton(
                  onPressed: _logout,
                  child: const Text(
                    'Logout',
                    style: TextStyle(color: Colors.red),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
