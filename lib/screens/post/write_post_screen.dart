import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';

import '../../utils/post_store.dart';
import '../../widgets/running_video_player.dart';

class WritePostScreen extends StatefulWidget {
  const WritePostScreen({super.key});

  @override
  State<WritePostScreen> createState() => _WritePostScreenState();
}

class _WritePostScreenState extends State<WritePostScreen> {
  final _titleController = TextEditingController();
  final _bodyController = TextEditingController();
  final _titleFocusNode = FocusNode();
  bool _saveInProfile = false;

  String? _pickedImagePath;
  String? _pickedVideoPath;
  bool _isPosting = false;

  final ImagePicker _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _titleFocusNode.requestFocus();
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _titleFocusNode.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (file != null && mounted) {
        setState(() {
          _pickedImagePath = file.path;
          _pickedVideoPath = null; // clear video if image chosen
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2C2C2E),
            content: Text(
              'Failed to pick image: $e',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? file = await _picker.pickVideo(
        source: ImageSource.gallery,
      );
      if (file != null && mounted) {
        setState(() {
          _pickedVideoPath = file.path;
          _pickedImagePath = null; // clear image if video chosen
        });
      }
    } catch (e) {
      debugPrint("Error picking video: $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: const Color(0xFF2C2C2E),
            content: Text(
              'Failed to pick video: $e',
              style: GoogleFonts.inter(color: Colors.white),
            ),
          ),
        );
      }
    }
  }

  Future<void> _post() async {
    final title = _titleController.text.trim();
    final body = _bodyController.text.trim();

    if (_pickedImagePath == null && _pickedVideoPath == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          backgroundColor: const Color(0xFF2C2C2E),
          content: Text(
            'Please upload an image or video to post!',
            style: GoogleFonts.inter(color: Colors.white),
          ),
        ),
      );
      return;
    }

    setState(() => _isPosting = true);
    await Future.delayed(const Duration(milliseconds: 300)); // brief feedback

    final post = UserPost(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: title.isEmpty ? 'Untitled' : title,
      body: body,
      imagePath: _pickedImagePath,
      videoPath: _pickedVideoPath,
      savedInProfile: _saveInProfile,
      createdAt: DateTime.now(),
    );

    PostStore.instance.addPost(post);

    if (mounted) {
      setState(() => _isPosting = false);
      Navigator.pop(context);
    }
  }

  void _clearMedia() {
    setState(() {
      _pickedImagePath = null;
      _pickedVideoPath = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Center(
        child: ClipRRect(
          borderRadius: BorderRadius.circular(40),
          child: Container(
            width: double.infinity,
            height: double.infinity,
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  Color(0xFF7C7C81),
                  Color(0xFF1A1A1B),
                  Color(0xFF000000),
                ],
                stops: [0.0, 0.24, 1.0],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
            child: SafeArea(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── HEADER ──────────────────────────────────────────────────
                  Padding(
                    padding: const EdgeInsets.only(top: 10, bottom: 12, left: 8, right: 16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back, color: Colors.white, size: 24),
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                          splashRadius: 20,
                        ),
                        _isPosting
                            ? const SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  color: Colors.white,
                                ),
                              )
                            : TextButton(
                                onPressed: (_pickedImagePath == null && _pickedVideoPath == null)
                                    ? () {
                                        ScaffoldMessenger.of(context).showSnackBar(
                                          SnackBar(
                                            backgroundColor: const Color(0xFF2C2C2E),
                                            content: Text(
                                              'Please upload an image or video to post!',
                                              style: GoogleFonts.inter(color: Colors.white),
                                            ),
                                          ),
                                        );
                                      }
                                    : _post,
                                style: TextButton.styleFrom(
                                  backgroundColor: (_pickedImagePath == null && _pickedVideoPath == null)
                                      ? Colors.white.withValues(alpha: 0.3)
                                      : Colors.white,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  'Post',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: (_pickedImagePath == null && _pickedVideoPath == null)
                                        ? Colors.black38
                                        : Colors.black,
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),

                  // ── CANVAS ──────────────────────────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Title input
                          TextField(
                            controller: _titleController,
                            focusNode: _titleFocusNode,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            textCapitalization: TextCapitalization.sentences,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 36,
                              fontWeight: FontWeight.w600,
                              letterSpacing: -0.8,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Write a Post',
                              hintStyle: GoogleFonts.inter(
                                color: Colors.white.withValues(alpha: 0.35),
                                fontSize: 36,
                                fontWeight: FontWeight.w600,
                                letterSpacing: -0.8,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          const SizedBox(height: 20),

                          // Body input
                          TextField(
                            controller: _bodyController,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            textCapitalization: TextCapitalization.sentences,
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w200,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Share your saved item to all.. (optional)',
                              hintStyle: GoogleFonts.inter(
                                color: const Color(0xFF515151),
                                fontSize: 16,
                                fontWeight: FontWeight.w200,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),

                          // Media preview
                          if (_pickedImagePath != null) ...[
                            const SizedBox(height: 20),
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: Image.file(
                                    File(_pickedImagePath!),
                                    fit: BoxFit.cover,
                                    width: double.infinity,
                                    height: 200,
                                    errorBuilder: (context, error, stackTrace) {
                                      return Container(
                                        width: double.infinity,
                                        height: 200,
                                        color: const Color(0xFF2A2A2E),
                                        child: const Center(
                                          child: Icon(Icons.broken_image,
                                              color: Colors.white54, size: 40),
                                        ),
                                      );
                                    },
                                  ),
                                ),
                                Positioned(
                                  top: 8,
                                  right: 8,
                                  child: GestureDetector(
                                    onTap: _clearMedia,
                                    child: Container(
                                      width: 28,
                                      height: 28,
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(alpha: 0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close, color: Colors.white, size: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                           if (_pickedVideoPath != null) ...[
                             const SizedBox(height: 20),
                             Stack(
                               children: [
                                 ClipRRect(
                                   borderRadius: BorderRadius.circular(14),
                                   child: RunningVideoPlayer(
                                     file: File(_pickedVideoPath!),
                                     height: 200,
                                   ),
                                 ),
                                 Positioned(
                                   top: 8,
                                   right: 8,
                                   child: GestureDetector(
                                     onTap: _clearMedia,
                                     child: Container(
                                       width: 28,
                                       height: 28,
                                       decoration: BoxDecoration(
                                         color: Colors.black.withValues(alpha: 0.6),
                                         shape: BoxShape.circle,
                                       ),
                                       child: const Icon(Icons.close, color: Colors.white, size: 16),
                                     ),
                                   ),
                                 ),
                               ],
                             ),
                           ],
                          const SizedBox(height: 80),
                        ],
                      ),
                    ),
                  ),

                  // ── BOTTOM TOOLBAR ──────────────────────────────────────────
                  Container(
                    color: const Color(0xFF4A4A4C),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                    child: Row(
                      children: [
                        // Image picker
                        IconButton(
                          onPressed: _pickImage,
                          icon: Icon(
                            Icons.image,
                            color: _pickedImagePath != null ? const Color(0xFF6B9BF7) : Colors.white,
                            size: 24,
                          ),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                        ),
                        const SizedBox(width: 4),
                        // Video picker
                        IconButton(
                          onPressed: _pickVideo,
                          icon: Icon(
                            Icons.smart_display,
                            color: _pickedVideoPath != null ? const Color(0xFF6B9BF7) : Colors.white,
                            size: 24,
                          ),
                          constraints: const BoxConstraints(),
                          padding: const EdgeInsets.all(8),
                        ),
                        const Spacer(),
                        // Save in profile capsule toggle
                        GestureDetector(
                          onTap: () => setState(() => _saveInProfile = !_saveInProfile),
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 200),
                            decoration: BoxDecoration(
                              color: _saveInProfile
                                  ? const Color(0xFF6B9BF7)
                                  : const Color(0xFFE1E1E3),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Text(
                                  'save in profile',
                                  style: GoogleFonts.inter(
                                    color: _saveInProfile ? Colors.white : Colors.black,
                                    fontSize: 13,
                                    fontWeight: FontWeight.w400,
                                  ),
                                ),
                                const SizedBox(width: 8),
                                AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 38,
                                  height: 20,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    color: _saveInProfile
                                        ? Colors.white.withValues(alpha: 0.3)
                                        : const Color(0xFF8E8E93),
                                  ),
                                  padding: const EdgeInsets.all(2),
                                  child: AnimatedAlign(
                                    duration: const Duration(milliseconds: 200),
                                    alignment: _saveInProfile
                                        ? Alignment.centerRight
                                        : Alignment.centerLeft,
                                    child: Container(
                                      width: 16,
                                      height: 16,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Colors.white,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
