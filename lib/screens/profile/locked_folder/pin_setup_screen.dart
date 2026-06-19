import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'pin_keypad.dart';

class PinSetupScreen extends StatefulWidget {
  const PinSetupScreen({super.key});

  @override
  State<PinSetupScreen> createState() => _PinSetupScreenState();
}

class _PinSetupScreenState extends State<PinSetupScreen> {
  String _pin = '';
  String _confirmPin = '';
  bool _isConfirming = false;
  bool _hasError = false;
  final _storage = const FlutterSecureStorage();

  void _onDigitPressed(String digit) {
    if (_hasError) {
      setState(() {
        _hasError = false;
        if (_isConfirming) {
          _confirmPin = '';
        } else {
          _pin = '';
        }
      });
    }

    setState(() {
      if (_isConfirming) {
        if (_confirmPin.length < 4) {
          _confirmPin += digit;
          if (_confirmPin.length == 4) {
            _verifyAndSave();
          }
        }
      } else {
        if (_pin.length < 4) {
          _pin += digit;
          if (_pin.length == 4) {
            Future.delayed(const Duration(milliseconds: 200), () {
              if (mounted) {
                setState(() {
                  _isConfirming = true;
                });
              }
            });
          }
        }
      }
    });
  }

  void _onBackspacePressed() {
    setState(() {
      if (_isConfirming && _confirmPin.isNotEmpty) {
        _confirmPin = _confirmPin.substring(0, _confirmPin.length - 1);
      } else if (!_isConfirming && _pin.isNotEmpty) {
        _pin = _pin.substring(0, _pin.length - 1);
      }
    });
  }

  Future<void> _verifyAndSave() async {
    if (_pin == _confirmPin) {
      await _storage.write(key: 'memoria_locked_folder_pin', value: _pin);
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
            _isConfirming = false;
            _pin = '';
            _confirmPin = '';
            _hasError = false;
          });
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final currentLength = _isConfirming ? _confirmPin.length : _pin.length;
    
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
            Icon(
              _isConfirming ? Icons.lock_clock : Icons.lock_outline,
              size: 48,
              color: Colors.white,
            ),
            const SizedBox(height: 24),
            Text(
              _isConfirming ? 'Confirm PIN' : 'Set a PIN',
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _isConfirming
                  ? 'Re-enter your 4-digit PIN'
                  : 'Create a 4-digit PIN for your locked items',
              style: GoogleFonts.inter(
                color: _hasError ? Colors.redAccent : Colors.white.withValues(alpha: 0.6),
                fontSize: 14,
                fontWeight: FontWeight.w400,
              ),
            ),
            const SizedBox(height: 40),
            PinDots(length: currentLength),
            const Spacer(),
            PinKeypad(
              onDigitPressed: _onDigitPressed,
              onBackspacePressed: _onBackspacePressed,
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
