import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

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

  Future<void> _sendOTP() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await FirebaseAuth.instance.verifyPhoneNumber(
        phoneNumber: _phone.text.trim(),
        verificationCompleted: (cred) async {
          // Mostly Android auto-fill; on web you rarely hit this.
          await FirebaseAuth.instance.signInWithCredential(cred);
          if (mounted) {
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(builder: (_) => const LoginSuccessPage()),
            );
          }
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
      setState(() => _loading = false);
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
      if (mounted) {
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(builder: (_) => const LoginSuccessPage()),
        );
      }
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message);
    } catch (e) {
      setState(() => _error = e.toString());
    } finally {
      setState(() => _loading = false);
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

class LoginSuccessPage extends StatelessWidget {
  const LoginSuccessPage({super.key});
  @override
  Widget build(BuildContext context) {
    final user = FirebaseAuth.instance.currentUser!;
    return Scaffold(
      appBar: AppBar(title: const Text('Logged In')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('✅ Phone auth success!'),
            const SizedBox(height: 8),
            Text('UID: ${user.uid}'),
            Text('Phone: ${user.phoneNumber}'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () async {
                await FirebaseAuth.instance.signOut();
                if (context.mounted) {
                  Navigator.of(context).pushAndRemoveUntil(
                    MaterialPageRoute(builder: (_) => const PhoneAuthScreen()),
                    (_) => false,
                  );
                }
              },
              child: const Text('Sign out'),
            ),
          ],
        ),
      ),
    );
  }
}
