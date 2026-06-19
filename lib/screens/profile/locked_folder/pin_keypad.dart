import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class PinKeypad extends StatelessWidget {
  final Function(String) onDigitPressed;
  final VoidCallback onBackspacePressed;

  const PinKeypad({
    super.key,
    required this.onDigitPressed,
    required this.onBackspacePressed,
  });

  Widget _buildKey(String label, {VoidCallback? onTap, Widget? icon}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(40),
      child: Container(
        width: 80,
        height: 80,
        alignment: Alignment.center,
        child: icon ??
            Text(
              label,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 32,
                fontWeight: FontWeight.w400,
              ),
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey('1', onTap: () => onDigitPressed('1')),
            _buildKey('2', onTap: () => onDigitPressed('2')),
            _buildKey('3', onTap: () => onDigitPressed('3')),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey('4', onTap: () => onDigitPressed('4')),
            _buildKey('5', onTap: () => onDigitPressed('5')),
            _buildKey('6', onTap: () => onDigitPressed('6')),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _buildKey('7', onTap: () => onDigitPressed('7')),
            _buildKey('8', onTap: () => onDigitPressed('8')),
            _buildKey('9', onTap: () => onDigitPressed('9')),
          ],
        ),
        const SizedBox(height: 16),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            const SizedBox(width: 80, height: 80),
            _buildKey('0', onTap: () => onDigitPressed('0')),
            _buildKey(
              '',
              icon: const Icon(Icons.backspace_outlined, color: Colors.white, size: 28),
              onTap: onBackspacePressed,
            ),
          ],
        ),
      ],
    );
  }
}

class PinDots extends StatelessWidget {
  final int length;
  final int maxLength;

  const PinDots({super.key, required this.length, this.maxLength = 4});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(maxLength, (index) {
        final isFilled = index < length;
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 12),
          width: 16,
          height: 16,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            color: isFilled ? Colors.white : Colors.transparent,
            border: Border.all(
              color: isFilled ? Colors.white : Colors.white.withValues(alpha: 0.3),
              width: 2,
            ),
          ),
        );
      }),
    );
  }
}
