import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import '../home/home_screen.dart';

class EmailAuthScreen extends StatefulWidget {
  const EmailAuthScreen({super.key});

  @override
  State<EmailAuthScreen> createState() => _EmailAuthScreenState();
}

class _EmailAuthScreenState extends State<EmailAuthScreen> {
  final _formKey = GlobalKey<FormState>();

  bool _isLogin = true; // false = register
  bool _loading = false;
  String? _error;

  // Controllers
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _phone = TextEditingController();

  // Extra fields (for register)
  final _name = TextEditingController();
  final _age = TextEditingController();
  final _address = TextEditingController();
  final _pincode = TextEditingController();

  String _gender = 'Male';
  String _role = 'Student'; // or Professional

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _phone.dispose();
    _name.dispose();
    _age.dispose();
    _address.dispose();
    _pincode.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      if (_isLogin) {
        // LOGIN FLOW
        final cred = await FirebaseAuth.instance.signInWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text.trim(),
        );

        final uid = cred.user!.uid;

        final doc = await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .get();

        if (!doc.exists) {
          // user logged in but no profile (edge case)
          setState(() {
            _error = 'No profile found. Please register again.';
          });
          await FirebaseAuth.instance.signOut();
          return;
        }

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      } else {
        // REGISTER FLOW
        final phoneDigits = _phone.text.replaceAll(RegExp(r'\D'), '');
        final phone = '+91$phoneDigits';

        // 1) Check if this phone is already used by another user
        final existingPhone = await FirebaseFirestore.instance
            .collection('users')
            .where('phone', isEqualTo: phone)
            .limit(1)
            .get();

        if (existingPhone.docs.isNotEmpty) {
          setState(() {
            _error =
                'This phone number is already registered.\nPlease login using that account or use a different phone.';
          });
          return;
        }

        // 2) Create auth user with email/password
        final cred = await FirebaseAuth.instance.createUserWithEmailAndPassword(
          email: _email.text.trim(),
          password: _password.text.trim(),
        );

        final uid = cred.user!.uid;

        final profile = {
          'name': _name.text.trim(),
          'age': int.tryParse(_age.text.trim()) ?? 0,
          'address': _address.text.trim(),
          'pincode': _pincode.text.trim(),
          'gender': _gender,
          'role': _role,
          'email': _email.text.trim(),
          'phone': phone,
          'createdAt': FieldValue.serverTimestamp(),
        };

        await FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .set(profile);

        if (!mounted) return;
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const HomeScreen()),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() {
        _error = e.message ?? e.code;
      });
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
      appBar: AppBar(title: Text(_isLogin ? 'Login with Email' : 'Register')),
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

              // REGISTER-ONLY FIELDS
              if (!_isLogin) ...[
                TextFormField(
                  controller: _name,
                  decoration: const InputDecoration(labelText: 'Name'),
                  validator: (v) =>
                      v == null || v.trim().isEmpty ? 'Enter name' : null,
                ),
                TextFormField(
                  controller: _phone,
                  keyboardType: TextInputType.phone,
                  decoration: const InputDecoration(
                    labelText: 'Phone',
                    prefixText: '+91 ',
                  ),
                  validator: (v) {
                    final digits = v?.replaceAll(RegExp(r'\D'), '') ?? '';
                    if (digits.length != 10) {
                      return 'Enter 10-digit phone number';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 8),

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
                const SizedBox(height: 8),
              ],

              // COMMON: EMAIL + PASSWORD
              TextFormField(
                controller: _email,
                decoration: const InputDecoration(labelText: 'Email'),
                keyboardType: TextInputType.emailAddress,
                validator: (v) =>
                    v == null || !v.contains('@') ? 'Enter valid email' : null,
              ),
              TextFormField(
                controller: _password,
                decoration: const InputDecoration(labelText: 'Password'),
                obscureText: true,
                validator: (v) =>
                    v == null || v.length < 6 ? 'Min 6 characters' : null,
              ),
              const SizedBox(height: 16),

              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: _loading ? null : _submit,
                  child: Text(_isLogin ? 'Login' : 'Register'),
                ),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _loading
                    ? null
                    : () {
                        setState(() {
                          _isLogin = !_isLogin;
                          _error = null;
                        });
                      },
                child: Text(
                  _isLogin
                      ? 'New here? Create an account'
                      : 'Already have an account? Login',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
