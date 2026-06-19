import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:local_auth/local_auth.dart';
import 'pin_keypad.dart';

class PinEntryScreen extends StatefulWidget {
  const PinEntryScreen({super.key});

  @override
  State<PinEntryScreen> createState() => _PinEntryScreenState();
}

class _PinEntryScreenState extends State<PinEntryScreen> {
  String _pin = '';
  bool _hasError = false;
  final _storage = const FlutterSecureStorage();
  final LocalAuthentication _localAuth = LocalAuthentication();
  bool _isAuthenticating = false;

  @override
  void initState() {
    super.initState();
    _checkBiometrics();
  }

  Future<void> _checkBiometrics() async {
    try {
      final bool canAuthenticateWithBiometrics = await _localAuth.canCheckBiometrics;
      final bool canAuthenticate = canAuthenticateWithBiometrics || await _localAuth.isDeviceSupported();
      
      if (canAuthenticate) {
        setState(() => _isAuthenticating = true);
        final bool didAuthenticate = await _localAuth.authenticate(
          localizedReason: 'Please authenticate to access your Locked Folder',
        );
        setState(() => _isAuthenticating = false);
        
        if (didAuthenticate && mounted) {
          Navigator.of(context).pop(true);
        }
      }
    } catch (e) {
      debugPrint("Biometric auth error: $e");
      if (mounted) {
        setState(() => _isAuthenticating = false);
      }
    }
  }

  void _onDigitPressed(String digit) {
    if (_hasError) {
      setState(() {
        _hasError = false;
        _pin = '';
      });
    }

    setState(() {
      if (_pin.length < 4) {
        _pin += digit;
        if (_pin.length == 4) {
          _verifyPin();
        }
      }
    });
  }

  void _onBackspacePressed() {
    setState(() {
      if (_pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      }
    });
  }

  Future<void> _verifyPin() async {
    final savedPin = await _storage.read(key: 'memoria_locked_folder_pin');
    if (_pin == savedPin) {
      if (mounted) {
        Navigator.of(context).pop(true);
      }
    } else {
      HapticFeedback.heavyImpact();
      setState(() {
        _hasError = true;
      });
      Future.delayed(const Duration(milliseconds: 1000), () {
        if (mounted) {
          setState(() {
            _pin = '';
            _hasError = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        elevation: 0,
        iconTheme: const IconThemeData(color: Colors.white),
      ),
      body: SafeArea(
        child: Column(
          children: [
            const SizedBox(height: 40),
            const Icon(
              Icons.lock,
              size: 48,
              color: Colors.white,
            ),
            const SizedBox(height: 24),
            Text(
              'Enter PIN',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _hasError ? 'Incorrect PIN. Try again.' : 'Enter your 4-digit PIN',
              style: GoogleFonts.inter(
                color: _hasError ? Colors.redAccent : Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 40),
            if (_isAuthenticating)
              const CircularProgressIndicator(color: Colors.white)
            else
              PinDots(length: _pin.length),
            const Spacer(),
            PinKeypad(
              onDigitPressed: _onDigitPressed,
              onBackspacePressed: _onBackspacePressed,
            ),
            const SizedBox(height: 20),
            TextButton.icon(
              onPressed: _checkBiometrics,
              icon: const Icon(Icons.fingerprint, color: Colors.white),
              label: Text(
                'Use Biometrics',
                style: GoogleFonts.inter(color: Colors.white),
              ),
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}
