import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:shared_preferences/shared_preferences.dart';

class DiceAvatar extends StatefulWidget {
  final double radius;
  final Color backgroundColor;
  final String? seed;

  static final ValueNotifier<String> seedNotifier = ValueNotifier<String>('memoria');
  static bool _isInitialized = false;

  const DiceAvatar({
    super.key,
    required this.radius,
    this.backgroundColor = Colors.transparent,
    this.seed,
  });

  static Future<void> loadSeed() async {
    final prefs = await SharedPreferences.getInstance();
    final savedSeed = prefs.getString('dice_bear_seed');
    if (savedSeed != null && savedSeed.isNotEmpty) {
      seedNotifier.value = savedSeed;
    }
    _isInitialized = true;
  }

  @override
  State<DiceAvatar> createState() => _DiceAvatarState();
}

class _DiceAvatarState extends State<DiceAvatar> {
  @override
  void initState() {
    super.initState();
    if (!DiceAvatar._isInitialized) {
      DiceAvatar.loadSeed();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.seed != null) {
      final normalizedSeed = widget.seed!.toLowerCase().replaceAll(' ', '_');
      return SizedBox(
        width: widget.radius * 2,
        height: widget.radius * 2,
        child: SvgPicture.network(
          'https://api.dicebear.com/9.x/notionists/svg?seed=$normalizedSeed&backgroundColor=transparent',
          fit: BoxFit.contain,
          placeholderBuilder: (BuildContext context) => const CircularProgressIndicator(color: Colors.white),
        ),
      );
    }
    return ValueListenableBuilder<String>(
      valueListenable: DiceAvatar.seedNotifier,
      builder: (context, currentSeed, child) {
        final normalizedSeed = currentSeed.toLowerCase().replaceAll(' ', '_');
        return SizedBox(
          width: widget.radius * 2,
          height: widget.radius * 2,
          child: SvgPicture.network(
            'https://api.dicebear.com/9.x/notionists/svg?seed=$normalizedSeed&backgroundColor=transparent',
            fit: BoxFit.contain,
            placeholderBuilder: (BuildContext context) => const CircularProgressIndicator(color: Colors.white),
          ),
        );
      },
    );
  }
}
