import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter_contacts/flutter_contacts.dart';

import '../../utils/post_store.dart';
import '../../utils/user_store.dart';
import '../../widgets/running_video_player.dart';
import '../../utils/rich_text_controller.dart';
import 'drawing_canvas.dart';

// ── Attachment model ──────────────────────────────────────────────────────────

enum _AttachType { document, contact, audio }

class _AttachItem {
  final _AttachType type;
  final String name;
  final String? path;
  final String? extension;
  final String? phone;
  final String? duration;

  _AttachItem.document({
    required this.name,
    required this.path,
    this.extension,
  })  : type = _AttachType.document,
        phone = null,
        duration = null;

  _AttachItem.contact({
    required this.name,
    required this.phone,
  })  : type = _AttachType.contact,
        path = null,
        extension = null,
        duration = null;

  _AttachItem.audio({required this.duration})
      : type = _AttachType.audio,
        name = 'Audio Recording',
        path = null,
        extension = null,
        phone = null;
}

// ── Screen ────────────────────────────────────────────────────────────────────

class WritePostScreen extends StatefulWidget {
  final bool isSaveItem;
  final Map<String, dynamic>? sharedData;

  const WritePostScreen({super.key, this.isSaveItem = false, this.sharedData});

  @override
  State<WritePostScreen> createState() => _WritePostScreenState();
}

class _WritePostScreenState extends State<WritePostScreen>
    with TickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _bodyController = RichTextController();
  final _urlController = TextEditingController();

  final _titleFocusNode = FocusNode();
  final _bodyFocusNode = FocusNode();

  bool _saveInProfile = false;
  String? _pickedImagePath;
  String? _pickedVideoPath;
  bool _isPosting = false;
  TextAlign _bodyAlign = TextAlign.left;

  final ImagePicker _picker = ImagePicker();

  // Attachments (real picks – shown as preview cards, not text)
  final List<_AttachItem> _attachedItems = [];

  // Rich Save to Memoria variables
  String? _sharedType;
  String? _sharedFilePath;
  String? _contactName;
  String? _contactPhone;
  String? _audioDuration;
  final List<String> _checklistItemsList = [];
  final List<bool> _checklistStatesList = [];

  Future<void> _parseAndLoadVcf(String path) async {
    try {
      final file = File(path);
      if (await file.exists()) {
        final lines = await file.readAsLines();
        String name = '';
        String phone = '';
        for (var line in lines) {
          final trimLine = line.trim();
          if (trimLine.startsWith('FN:')) {
            name = trimLine.substring(3).trim();
          } else if (trimLine.startsWith('TEL;') || trimLine.startsWith('TEL:')) {
            final colonIdx = trimLine.indexOf(':');
            if (colonIdx != -1) {
              phone = trimLine.substring(colonIdx + 1).trim();
            }
          }
        }
        if (name.isEmpty) {
          name = file.uri.pathSegments.last.replaceAll('.vcf', '');
        }
        setState(() {
          _contactName = name;
          _contactPhone = phone;
        });
      }
    } catch (e) {
      debugPrint("Error parsing VCF: $e");
    }
  }

  // Plus menu animation controllers
  late AnimationController _plusMenuController;
  late Animation<double> _plusMenuOpacity;
  late Animation<Offset> _plusMenuSlide;
  bool _isPlusMenuOpen = false;
  bool _isFormattingToolOpen = false;

  @override
  void initState() {
    super.initState();
    _saveInProfile = widget.isSaveItem;

    if (widget.sharedData != null) {
      _saveInProfile = true; // Shared content is private (Save an Item) by default
      final data = widget.sharedData!;
      final type = data['type'] as String?;
      if (type == 'text') {
        final text = data['text'] as String? ?? '';
        if (text.startsWith('http://') || text.startsWith('https://')) {
          _sharedType = 'link';
          _urlController.text = text;
          _titleController.text = 'Shared Link';
        } else if (text.contains('[ ]') || text.contains('- [ ]')) {
          _sharedType = 'checklist';
          _titleController.text = 'Shared Checklist';
          final lines = text.split('\n');
          for (var line in lines) {
            var itemText = line.trim();
            if (itemText.startsWith('- [ ]')) {
              itemText = itemText.substring(5).trim();
            } else if (itemText.startsWith('[ ]')) {
              itemText = itemText.substring(3).trim();
            }
            if (itemText.isNotEmpty) {
              _checklistItemsList.add(itemText);
              _checklistStatesList.add(false);
            }
          }
        } else if (text.contains('```')) {
          _sharedType = 'code';
          _titleController.text = 'Shared Code';
          _bodyController.text = text;
        } else {
          _sharedType = 'text';
          _titleController.text = 'Shared Idea';
          _bodyController.text = text;
        }
      } else if (type == 'image') {
        _sharedType = 'image';
        _pickedImagePath = data['filePath'] as String?;
        _titleController.text = data['name'] as String? ?? 'Shared Image';
      } else if (type == 'video') {
        _sharedType = 'video';
        _pickedVideoPath = data['filePath'] as String?;
        _titleController.text = data['name'] as String? ?? 'Shared Video';
      } else if (type == 'audio') {
        _sharedType = 'audio';
        _sharedFilePath = data['filePath'] as String?;
        _audioDuration = '00:05';
        _titleController.text = data['name'] as String? ?? 'Shared Audio';
      } else if (type == 'document') {
        final filePath = data['filePath'] as String? ?? '';
        final lowerPath = filePath.toLowerCase();
        if (lowerPath.endsWith('.vcf') || lowerPath.endsWith('.vcard')) {
          _sharedType = 'contact';
          _sharedFilePath = filePath;
          _titleController.text = 'Shared Contact';
          _parseAndLoadVcf(filePath);
        } else {
          _sharedType = 'document';
          _sharedFilePath = filePath;
          _titleController.text = data['name'] as String? ?? 'Shared Document';
        }
      }
    }

    _plusMenuController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 250),
    );
    _plusMenuOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _plusMenuController, curve: Curves.easeOut),
    );
    _plusMenuSlide = Tween<Offset>(
      begin: const Offset(0.0, 0.15),
      end: Offset.zero,
    ).animate(
        CurvedAnimation(parent: _plusMenuController, curve: Curves.easeOutCubic));

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (widget.isSaveItem) {
        _bodyFocusNode.requestFocus();
      } else {
        _titleFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _bodyController.dispose();
    _urlController.dispose();
    _titleFocusNode.dispose();
    _bodyFocusNode.dispose();
    _plusMenuController.dispose();
    super.dispose();
  }

  // ── Media pickers ──────────────────────────────────────────────────────────

  Future<void> _pickImage() async {
    try {
      final XFile? file = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 90,
      );
      if (file != null && mounted) {
        setState(() {
          _pickedImagePath = file.path;
          _pickedVideoPath = null;
        });
      }
    } catch (e) {
      debugPrint("Error picking image: $e");
      if (mounted) {
        _showSnack('Failed to pick image: $e');
      }
    }
  }

  Future<void> _pickVideo() async {
    try {
      final XFile? file = await _picker.pickVideo(source: ImageSource.gallery);
      if (file != null && mounted) {
        setState(() {
          _pickedVideoPath = file.path;
          _pickedImagePath = null;
        });
      }
    } catch (e) {
      debugPrint("Error picking video: $e");
      if (mounted) {
        _showSnack('Failed to pick video: $e');
      }
    }
  }

  void _openDrawingMode() async {
    final String? resultPath = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => DrawingCanvas(backgroundImagePath: _pickedImagePath),
      ),
    );
    if (resultPath != null) {
      setState(() {
        _pickedImagePath = resultPath;
        _pickedVideoPath = null;
      });
    }
  }

  void _clearMedia() {
    setState(() {
      _pickedImagePath = null;
      _pickedVideoPath = null;
    });
  }

  // ── Rich-text toolbar ──────────────────────────────────────────────────────

  void _openRichTextEditor() {
    setState(() {
      _isFormattingToolOpen = !_isFormattingToolOpen;
    });
  }

  Widget _buildInlineFormattingToolbar() {
    final activeStyle = _bodyController.getActiveStyle();

    return Container(
      height: 50,
      decoration: const BoxDecoration(
        color: Color(0xFF1C1C1E),
        border: Border(top: BorderSide(color: Colors.white12, width: 0.5)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Row(
          children: [
            _buildToolbarToggle(
              icon: Icons.format_bold,
              active: activeStyle.bold == true,
              onTap: () {
                _bodyController.applyStyle(bold: !(activeStyle.bold == true));
                _bodyFocusNode.requestFocus();
                setState(() {});
              },
            ),
            _buildToolbarToggle(
              icon: Icons.format_italic,
              active: activeStyle.italic == true,
              onTap: () {
                _bodyController
                    .applyStyle(italic: !(activeStyle.italic == true));
                _bodyFocusNode.requestFocus();
                setState(() {});
              },
            ),
            _buildToolbarToggle(
              icon: Icons.format_underlined,
              active: activeStyle.underline == true,
              onTap: () {
                _bodyController
                    .applyStyle(underline: !(activeStyle.underline == true));
                _bodyFocusNode.requestFocus();
                setState(() {});
              },
            ),
            _buildToolbarToggle(
              icon: Icons.format_strikethrough,
              active: activeStyle.strikethrough == true,
              onTap: () {
                _bodyController.applyStyle(
                    strikethrough: !(activeStyle.strikethrough == true));
                _bodyFocusNode.requestFocus();
                setState(() {});
              },
            ),
            _buildToolbarDivider(),

            // Alignments
            _buildToolbarToggle(
              icon: Icons.format_align_left,
              active: _bodyAlign == TextAlign.left,
              onTap: () {
                setState(() => _bodyAlign = TextAlign.left);
                _bodyFocusNode.requestFocus();
              },
            ),
            _buildToolbarToggle(
              icon: Icons.format_align_center,
              active: _bodyAlign == TextAlign.center,
              onTap: () {
                setState(() => _bodyAlign = TextAlign.center);
                _bodyFocusNode.requestFocus();
              },
            ),
            _buildToolbarToggle(
              icon: Icons.format_align_right,
              active: _bodyAlign == TextAlign.right,
              onTap: () {
                setState(() => _bodyAlign = TextAlign.right);
                _bodyFocusNode.requestFocus();
              },
            ),
            _buildToolbarDivider(),

            // Font Sizes
            _buildSizeChip(
                '12', activeStyle.fontSize == 12.0, () {
              _bodyController.applyStyle(fontSize: 12.0);
              _bodyFocusNode.requestFocus();
              setState(() {});
            }),
            _buildSizeChip(
                '16',
                activeStyle.fontSize == 16.0 || activeStyle.fontSize == null,
                () {
              _bodyController.applyStyle(fontSize: 16.0);
              _bodyFocusNode.requestFocus();
              setState(() {});
            }),
            _buildSizeChip(
                '20', activeStyle.fontSize == 20.0, () {
              _bodyController.applyStyle(fontSize: 20.0);
              _bodyFocusNode.requestFocus();
              setState(() {});
            }),
            _buildSizeChip(
                '26', activeStyle.fontSize == 26.0, () {
              _bodyController.applyStyle(fontSize: 26.0);
              _bodyFocusNode.requestFocus();
              setState(() {});
            }),
            _buildToolbarDivider(),

            // Lists
            _buildToolbarToggle(
              icon: Icons.format_list_bulleted,
              active: false,
              onTap: () {
                _bodyController.toggleList('• ');
                _bodyFocusNode.requestFocus();
                setState(() {});
              },
            ),
            _buildToolbarToggle(
              icon: Icons.format_list_numbered,
              active: false,
              onTap: () {
                _bodyController.toggleList('1. ');
                _bodyFocusNode.requestFocus();
                setState(() {});
              },
            ),
            _buildToolbarToggle(
              icon: Icons.checklist,
              active: false,
              onTap: () {
                _bodyController.toggleList('[ ] ');
                _bodyFocusNode.requestFocus();
                setState(() {});
              },
            ),
            _buildToolbarDivider(),

            // Colors
            const Icon(Icons.palette_outlined, color: Colors.white60, size: 16),
            const SizedBox(width: 4),
            ...[
              Colors.white,
              Colors.grey,
              Colors.red,
              Colors.orange,
              Colors.yellow,
              Colors.green,
              Colors.blue
            ].map((col) {
              final bool isAct = activeStyle.color == col;
              return _buildColorDot(col, isAct, () {
                _bodyController.applyStyle(color: col);
                _bodyFocusNode.requestFocus();
                setState(() {});
              });
            }),
            _buildToolbarDivider(),

            // Highlights
            const Icon(Icons.format_color_fill,
                color: Colors.white60, size: 16),
            const SizedBox(width: 4),
            _buildColorDot(
                Colors.transparent,
                activeStyle.highlightColor == Colors.transparent ||
                    activeStyle.highlightColor == null, () {
              _bodyController.applyStyle(clearHighlight: true);
              _bodyFocusNode.requestFocus();
              setState(() {});
            }, isHighlight: true),
            ...[
              Colors.grey,
              Colors.red,
              Colors.orange,
              Colors.yellow,
              Colors.green,
              Colors.blue
            ].map((col) {
              final Color hlCol = col.withValues(alpha: 0.3);
              final bool isAct = activeStyle.highlightColor == hlCol;
              return _buildColorDot(col, isAct, () {
                _bodyController.applyStyle(highlightColor: hlCol);
                _bodyFocusNode.requestFocus();
                setState(() {});
              }, isHighlight: true);
            }),
          ],
        ),
      ),
    );
  }

  Widget _buildToolbarToggle(
      {required IconData icon, required bool active, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 32,
        height: 32,
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: active ? Colors.white : Colors.transparent,
          borderRadius: BorderRadius.circular(6),
        ),
        child: Icon(icon,
            color: active ? Colors.black : Colors.white70, size: 18),
      ),
    );
  }

  Widget _buildToolbarDivider() {
    return Container(
      width: 1,
      height: 20,
      margin: const EdgeInsets.symmetric(horizontal: 6),
      color: Colors.white12,
    );
  }

  Widget _buildSizeChip(String text, bool active, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
        margin: const EdgeInsets.symmetric(horizontal: 2),
        decoration: BoxDecoration(
          color: active ? Colors.white : const Color(0xFF2C2C2E),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(color: Colors.white12, width: 0.5),
        ),
        child: Text(
          text,
          style: GoogleFonts.inter(
            color: active ? Colors.black : Colors.white70,
            fontSize: 11,
            fontWeight: FontWeight.bold,
          ),
        ),
      ),
    );
  }

  Widget _buildColorDot(Color color, bool active, VoidCallback onTap,
      {bool isHighlight = false}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 18,
        height: 18,
        margin: const EdgeInsets.symmetric(horizontal: 3),
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: active ? Colors.white : Colors.white24,
            width: active ? 1.5 : 0.5,
          ),
        ),
        child: color == Colors.transparent
            ? const Center(
                child: Icon(Icons.close, color: Colors.white54, size: 10))
            : null,
      ),
    );
  }

  // ── Real Document Picker ───────────────────────────────────────────────────

  Future<void> _openDocumentSelector() async {
    // Close plus menu first
    _togglePlusMenu();

    try {
      final result = await FilePicker.platform.pickFiles(
        type: FileType.any,
        allowMultiple: false,
        withData: false,
      );

      if (result != null && result.files.isNotEmpty && mounted) {
        final file = result.files.single;
        if (file.path != null) {
          setState(() {
            _attachedItems.add(_AttachItem.document(
              name: file.name,
              path: file.path!,
              extension: file.extension?.toUpperCase(),
            ));
          });
        }
      }
    } catch (e) {
      debugPrint("Error picking file: $e");
      if (mounted) {
        _showSnack('Could not open file picker: $e');
      }
    }
  }

  // ── Real Contact Picker ────────────────────────────────────────────────────

  Future<void> _openContactSelector() async {
    // Close plus menu first
    _togglePlusMenu();

    try {
      // Request READ permission using v2.2.1 API
      final status =
          await FlutterContacts.permissions.request(PermissionType.read);
      if (status != PermissionStatus.granted &&
          status != PermissionStatus.limited) {
        if (mounted) {
          _showSnack('Contacts permission denied. Please allow in Settings.');
        }
        return;
      }

      // Open native contact picker — passing {phone} fetches phone numbers inline
      final contact = await FlutterContacts.native
          .showPicker(properties: {ContactProperty.phone});

      if (contact != null && mounted) {
        final displayName =
            (contact.displayName?.isNotEmpty == true)
                ? contact.displayName!
                : 'Unknown';
        final phone = contact.phones.isNotEmpty
            ? contact.phones.first.number
            : 'No number';

        setState(() {
          _attachedItems.add(_AttachItem.contact(
            name: displayName,
            phone: phone,
          ));
        });
      }
    } catch (e) {
      debugPrint("Error picking contact: $e");
      if (mounted) {
        _showSnack('Could not open contacts: $e');
      }
    }
  }

  // ── Audio Recorder ─────────────────────────────────────────────────────────

  void _openAudioRecorder() {
    // Close plus menu first
    _togglePlusMenu();

    showModalBottomSheet(
      context: context,
      isDismissible: false,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (BuildContext ctx) {
        int durationSeconds = 0;
        bool isRecording = false;
        bool hasRecorded = false;
        Timer? recordTimer;

        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setSheetState) {
            String formatDuration(int sec) {
              final int m = sec ~/ 60;
              final int s = sec % 60;
              return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
            }

            void startRecording() {
              setSheetState(() {
                isRecording = true;
                hasRecorded = true;
              });
              recordTimer =
                  Timer.periodic(const Duration(seconds: 1), (t) {
                setSheetState(() => durationSeconds++);
              });
            }

            void pauseRecording() {
              recordTimer?.cancel();
              setSheetState(() => isRecording = false);
            }

            return Container(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: const Color(0xFF48484A),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                  const SizedBox(height: 20),
                  Text(
                    'RECORD AUDIO',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      fontSize: 13,
                      letterSpacing: 1.2,
                    ),
                  ),
                  const SizedBox(height: 24),
                  Text(
                    formatDuration(durationSeconds),
                    style: GoogleFonts.robotoMono(
                      color: isRecording ? Colors.redAccent : Colors.white,
                      fontSize: 52,
                      fontWeight: FontWeight.w300,
                    ),
                  ),
                  const SizedBox(height: 16),
                  SizedBox(
                    height: 50,
                    child: isRecording
                        ? Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: List.generate(18, (index) {
                              final h = 10.0 +
                                  (1.0 +
                                          math.sin(
                                              durationSeconds.toDouble() +
                                                  index.toDouble())) *
                                      15.0;
                              return AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                width: 4,
                                height: h,
                                margin:
                                    const EdgeInsets.symmetric(horizontal: 2),
                                decoration: BoxDecoration(
                                  color: Colors.redAccent,
                                  borderRadius: BorderRadius.circular(2),
                                ),
                              );
                            }),
                          )
                        : Center(
                            child: Container(
                              height: 2,
                              width: 140,
                              color: Colors.white12,
                            ),
                          ),
                  ),
                  const SizedBox(height: 28),
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      TextButton(
                        onPressed: () {
                          recordTimer?.cancel();
                          Navigator.pop(ctx);
                        },
                        child: Text(
                          'Cancel',
                          style: GoogleFonts.inter(
                              color: Colors.white54, fontSize: 15),
                        ),
                      ),
                      GestureDetector(
                        onTap: () {
                          if (isRecording) {
                            pauseRecording();
                          } else {
                            startRecording();
                          }
                        },
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          width: 68,
                          height: 68,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            color: isRecording ? Colors.white : Colors.red,
                            border: Border.all(color: Colors.white, width: 4),
                          ),
                          child: Center(
                            child: Icon(
                              isRecording
                                  ? Icons.pause
                                  : Icons.fiber_manual_record,
                              color: isRecording ? Colors.black : Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: hasRecorded && durationSeconds > 0
                            ? () {
                                recordTimer?.cancel();
                                final dur = formatDuration(durationSeconds);
                                Navigator.pop(ctx);
                                // Add as attachment (preview card, not text)
                                setState(() {
                                  _attachedItems
                                      .add(_AttachItem.audio(duration: dur));
                                });
                              }
                            : null,
                        child: Text(
                          'Save',
                          style: GoogleFonts.inter(
                            color: hasRecorded && durationSeconds > 0
                                ? Colors.white
                                : Colors.white24,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                ],
              ),
            );
          },
        );
      },
    );
  }

  // ── Attachment preview cards (shown inline in canvas) ──────────────────────

  Widget _buildAttachmentPreviews() {
    if (_attachedItems.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: _attachedItems.asMap().entries.map((entry) {
        final idx = entry.key;
        final item = entry.value;
        switch (item.type) {
          case _AttachType.document:
            return _buildDocumentPreviewCard(item, idx);
          case _AttachType.contact:
            return _buildContactPreviewCard(item, idx);
          case _AttachType.audio:
            return _buildAudioPreviewCard(item, idx);
        }
      }).toList(),
    );
  }

  Widget _buildDocumentPreviewCard(_AttachItem item, int idx) {
    final ext = item.extension ?? 'FILE';
    IconData icon = Icons.description_outlined;
    Color color = const Color(0xFF8E8E93);
    if (ext == 'PDF') {
      icon = Icons.picture_as_pdf_outlined;
      color = Colors.redAccent;
    } else if (ext == 'DOC' || ext == 'DOCX') {
      icon = Icons.description_outlined;
      color = const Color(0xFF6B9BF7);
    } else if (ext == 'XLS' || ext == 'XLSX') {
      icon = Icons.table_chart_outlined;
      color = Colors.greenAccent;
    } else if (ext == 'ZIP' || ext == 'RAR') {
      icon = Icons.folder_zip_outlined;
      color = Colors.amberAccent;
    } else if (ext == 'PNG' || ext == 'JPG' || ext == 'JPEG') {
      icon = Icons.image_outlined;
      color = Colors.purpleAccent;
    } else if (ext == 'MP4' || ext == 'MOV' || ext == 'AVI') {
      icon = Icons.video_file_outlined;
      color = Colors.orangeAccent;
    } else if (ext == 'MP3' || ext == 'AAC' || ext == 'WAV') {
      icon = Icons.audio_file_outlined;
      color = Colors.tealAccent;
    } else if (ext == 'TXT') {
      icon = Icons.text_snippet_outlined;
      color = Colors.white70;
    }

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12, width: 0.5),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(icon, color: color, size: 24),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  '$ext Document',
                  style: GoogleFonts.inter(
                    color: Colors.white38,
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _attachedItems.removeAt(idx)),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.close, color: Colors.white54, size: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildContactPreviewCard(_AttachItem item, int idx) {
    final initial = item.name.isNotEmpty ? item.name[0].toUpperCase() : '?';
    final gradients = [
      [const Color(0xFF7B61FF), const Color(0xFF4A90E2)],
      [const Color(0xFFE24A6A), const Color(0xFFFF8A00)],
      [const Color(0xFF2ECC71), const Color(0xFF1ABC9C)],
      [const Color(0xFFF39C12), const Color(0xFFE74C3C)],
    ];
    final grad = gradients[item.name.codeUnitAt(0) % gradients.length];

    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12, width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: LinearGradient(
                colors: grad,
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
            ),
            child: Center(
              child: Text(
                initial,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 18,
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  item.phone ?? 'No number',
                  style: GoogleFonts.inter(
                    color: const Color(0xFF6B9BF7),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          GestureDetector(
            onTap: () => setState(() => _attachedItems.removeAt(idx)),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.close, color: Colors.white54, size: 14),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAudioPreviewCard(_AttachItem item, int idx) {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white12, width: 0.5),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: Colors.redAccent.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.mic, color: Colors.redAccent, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Audio Recording',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    const Icon(Icons.play_circle_filled,
                        color: Colors.redAccent, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Container(
                        height: 3,
                        decoration: BoxDecoration(
                          color: Colors.white12,
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      item.duration ?? '00:00',
                      style: GoogleFonts.robotoMono(
                        color: Colors.white54,
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          GestureDetector(
            onTap: () => setState(() => _attachedItems.removeAt(idx)),
            child: Container(
              width: 26,
              height: 26,
              decoration: BoxDecoration(
                color: Colors.white12,
                borderRadius: BorderRadius.circular(6),
              ),
              child: const Icon(Icons.close, color: Colors.white54, size: 14),
            ),
          ),
        ],
      ),
    );
  }

  // ── Plus menu ──────────────────────────────────────────────────────────────

  void _togglePlusMenu() {
    setState(() {
      _isPlusMenuOpen = !_isPlusMenuOpen;
      if (_isPlusMenuOpen) {
        _plusMenuController.forward();
      } else {
        _plusMenuController.reverse();
      }
    });
  }

  Widget _buildPlusMenu() {
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final double screenHeight = MediaQuery.of(context).size.height;
    final double bottomOffset =
        60.0 + (_isFormattingToolOpen ? 50.0 : 0.0) + keyboardHeight + 16.0;
    final double maxMenuHeight = screenHeight - bottomOffset - 120.0;

    return Container(
      width: 190,
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.white12, width: 0.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.4),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: ConstrainedBox(
        constraints: BoxConstraints(
          maxHeight: maxMenuHeight > 50.0 ? maxMenuHeight : 120.0,
        ),
        child: SingleChildScrollView(
          physics: const BouncingScrollPhysics(),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              _buildMenuItem('Document', Icons.description_outlined,
                  _openDocumentSelector),
              _buildMenuItem(
                  'Contact', Icons.person_outline, _openContactSelector),
              _buildMenuItem(
                  'Record Audio', Icons.mic_none_outlined, _openAudioRecorder),
              _buildMenuItem('Checklist', Icons.check_box_outlined, () {
                _bodyController.toggleList('[ ] ');
                _togglePlusMenu();
              }),
              _buildMenuItem('Bulleted List', Icons.format_list_bulleted, () {
                _bodyController.toggleList('• ');
                _togglePlusMenu();
              }),
              _buildMenuItem('To-do List', Icons.playlist_add_check, () {
                _bodyController.toggleList('[ ] To-do item: ');
                _togglePlusMenu();
              }),
              _buildMenuItem('Code Block', Icons.code_outlined, () {
                _bodyController.text +=
                    '\n```dart\n// Your code snippet here\n\n```\n';
                _togglePlusMenu();
              }),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildMenuItem(String label, IconData icon, VoidCallback onTap) {
    final double keyboardHeight = MediaQuery.of(context).viewInsets.bottom;
    final bool isKeyboardOpen = keyboardHeight > 0;
    return InkWell(
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
            horizontal: 16, vertical: isKeyboardOpen ? 5.0 : 10.0),
        child: Row(
          children: [
            Icon(icon, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                label,
                style: GoogleFonts.inter(
                  color: Colors.white,
                  fontSize: 14,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Post / Save ────────────────────────────────────────────────────────────

  Future<void> _post() async {
    final title = _titleController.text.trim();

    // Build body: text content + serialized attachment tokens
    final StringBuffer bodyBuf =
        StringBuffer(_bodyController.text.trim());
    for (final item in _attachedItems) {
      switch (item.type) {
        case _AttachType.document:
          bodyBuf.write('\n[Document: ${item.name}]');
          break;
        case _AttachType.contact:
          bodyBuf.write('\n[Contact: ${item.name} (${item.phone})]');
          break;
        case _AttachType.audio:
          bodyBuf.write('\n[Audio Recording: ${item.duration ?? "00:00"} min]');
          break;
      }
    }
    final body = bodyBuf.toString().trim();

    if (body.isEmpty &&
        _pickedImagePath == null &&
        _pickedVideoPath == null) {
      _showSnack(widget.isSaveItem
          ? 'Please add some content, attachment or media!'
          : 'Please enter some content!');
      return;
    }

    if (!widget.isSaveItem &&
        _pickedImagePath == null &&
        _pickedVideoPath == null) {
      _showSnack('Please upload an image or video to post!');
      return;
    }

    setState(() => _isPosting = true);
    await Future.delayed(const Duration(milliseconds: 300));

    String resolvedTitle = title;
    if (widget.isSaveItem && resolvedTitle.isEmpty) {
      final bodyLines = body.split('\n');
      if (bodyLines.isNotEmpty && bodyLines.first.trim().isNotEmpty) {
        resolvedTitle = bodyLines.first.trim();
        if (resolvedTitle.startsWith('[')) {
          // Attachment-only post → use attachment name
          final match = RegExp(r'\[(?:Document|Contact|Audio Recording): ([^\]]+)\]')
              .firstMatch(resolvedTitle);
          resolvedTitle = match != null ? match.group(1)! : 'Saved Item';
        }
        if (resolvedTitle.length > 30) {
          resolvedTitle = '${resolvedTitle.substring(0, 27)}...';
        }
      } else {
        resolvedTitle = 'Saved Item';
      }
    }

    String? resolvedFilePath = _sharedFilePath;
    String? resolvedContactName = _contactName;
    String? resolvedContactPhone = _contactPhone;
    String? resolvedDuration = _audioDuration;

    if (_attachedItems.isNotEmpty) {
      final first = _attachedItems.first;
      if (first.type == _AttachType.document) {
        resolvedFilePath = first.path;
      } else if (first.type == _AttachType.contact) {
        resolvedContactName = first.name;
        resolvedContactPhone = first.phone;
      } else if (first.type == _AttachType.audio) {
        resolvedDuration = first.duration;
      }
    }

    final String resolvedType = _getResolvedType();

    final post = UserPost(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      title: resolvedTitle.isEmpty ? 'Untitled' : resolvedTitle,
      body: body,
      url: _urlController.text.trim().isEmpty
          ? null
          : _urlController.text.trim(),
      username: UserStore.instance.currentUser?.userId ?? 'gangster_vagas',
      imagePath: _pickedImagePath,
      videoPath: _pickedVideoPath,
      savedInProfile: _saveInProfile,
      createdAt: DateTime.now(),
      charStyles: List<RichStyle>.from(_bodyController.charStyles),
      type: resolvedType,
      filePath: resolvedFilePath,
      contactName: resolvedContactName,
      contactPhone: resolvedContactPhone,
      duration: resolvedDuration,
      checklistItems: _checklistItemsList.isNotEmpty ? _checklistItemsList : null,
      checklistStates: _checklistStatesList.isNotEmpty ? _checklistStatesList : null,
    );

    PostStore.instance.addPost(post);

    if (mounted) {
      setState(() => _isPosting = false);
      Navigator.pop(context);
    }
  }

  String _getResolvedType() {
    return _sharedType ?? (
      _pickedImagePath != null ? 'image' : (
      _pickedVideoPath != null ? 'video' : (
      _attachedItems.isNotEmpty ? (
        _attachedItems.first.type == _AttachType.document ? 'document' : (
        _attachedItems.first.type == _AttachType.contact ? 'contact' : 'audio'
      )) : (
        _urlController.text.isNotEmpty ? 'link' : (
        _checklistItemsList.isNotEmpty ? 'checklist' : (
        _bodyController.text.contains('```') ? 'code' : 'text'
      ))
    ))));
  }

  void _showSnack(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: const Color(0xFF2C2C2E),
        content: Text(msg, style: GoogleFonts.inter(color: Colors.white)),
      ),
    );
  }

  int _getWordCount(String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return 0;
    return trimmed.split(RegExp(r'\s+')).length;
  }

  Widget _buildAutomaticPreview() {
    final String resolvedType = _getResolvedType();

    if (resolvedType == 'image') {
      final path = _pickedImagePath;
      if (path == null) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 200,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12, width: 0.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: path.startsWith('assets/')
              ? Image.asset(path, fit: BoxFit.cover, width: double.infinity, height: 200)
              : Image.file(File(path), fit: BoxFit.cover, width: double.infinity, height: 200),
        ),
      );
    }

    if (resolvedType == 'video') {
      final path = _pickedVideoPath;
      if (path == null) return const SizedBox.shrink();
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        height: 200,
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: Colors.white12, width: 0.5),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Stack(
            alignment: Alignment.center,
            children: [
              path.startsWith('assets/')
                  ? RunningVideoPlayer(assetPath: path)
                  : RunningVideoPlayer(file: File(path)),
              Container(
                width: 50,
                height: 50,
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.5),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.play_arrow, color: Colors.white, size: 28),
              ),
            ],
          ),
        ),
      );
    }

    if (resolvedType == 'document') {
      final path = _sharedFilePath ?? (_attachedItems.isNotEmpty ? _attachedItems[0].path : null);
      final name = path != null ? path.split('/').last.split('\\').last : 'document.pdf';
      final isPdf = name.toLowerCase().endsWith('.pdf');
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: isPdf ? Colors.redAccent.withValues(alpha: 0.15) : Colors.blue.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(
                isPdf ? Icons.picture_as_pdf_outlined : Icons.description_outlined,
                color: isPdf ? Colors.redAccent : Colors.blue,
                size: 24,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isPdf ? 'PDF Document' : 'Document File',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF7C7C81),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (resolvedType == 'contact') {
      final name = _contactName ?? (_attachedItems.isNotEmpty ? _attachedItems[0].name : 'Unknown Contact');
      final String phone = _contactPhone ?? (_attachedItems.isNotEmpty ? (_attachedItems[0].phone ?? '') : '');
      final initial = name.isNotEmpty ? name[0].toUpperCase() : '?';
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: const BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  colors: [Color(0xFF7B61FF), Color(0xFF4A90E2)],
                ),
              ),
              child: Center(
                child: Text(
                  initial,
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                    fontSize: 18,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    phone.isNotEmpty ? phone : 'No phone number',
                    style: GoogleFonts.inter(
                      color: const Color(0xFF6B9BF7),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (resolvedType == 'audio') {
      final dur = _audioDuration ?? (_attachedItems.isNotEmpty ? _attachedItems[0].duration : '00:05');
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.redAccent.withValues(alpha: 0.15),
                shape: BoxShape.circle,
              ),
              child: const Icon(Icons.mic, color: Colors.redAccent, size: 22),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Audio Recording',
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Row(
                    children: [
                      const Icon(Icons.play_circle_filled, color: Colors.redAccent, size: 20),
                      const SizedBox(width: 8),
                      Expanded(
                        child: CustomPaint(
                          size: const Size(double.infinity, 8),
                          painter: WaveformPainter(),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        dur ?? '00:05',
                        style: GoogleFonts.robotoMono(color: Colors.white54, fontSize: 11),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (resolvedType == 'link') {
      final url = _urlController.text;
      final uri = Uri.tryParse(url);
      final domain = uri?.host ?? 'link';
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12, width: 0.5),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: Colors.purpleAccent.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Icon(Icons.link_rounded, color: Colors.purpleAccent, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    url,
                    style: GoogleFonts.inter(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  Text(
                    domain,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF7C7C81),
                      fontSize: 12,
                      fontWeight: FontWeight.w400,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      );
    }

    if (resolvedType == 'checklist') {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1C1C1E),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white12, width: 0.5),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.checklist_rounded, color: Colors.greenAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Checklist',
                  style: GoogleFonts.inter(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            for (int i = 0; i < _checklistItemsList.length; i++)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          _checklistStatesList[i] = !_checklistStatesList[i];
                        });
                      },
                      child: Icon(
                        _checklistStatesList[i] ? Icons.check_box_rounded : Icons.check_box_outline_blank_rounded,
                        color: _checklistStatesList[i] ? Colors.greenAccent : const Color(0xFF7C7C81),
                        size: 20,
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        _checklistItemsList[i],
                        style: GoogleFonts.inter(
                          color: _checklistStatesList[i] ? const Color(0xFF7C7C81) : Colors.white,
                          fontSize: 14,
                          decoration: _checklistStatesList[i] ? TextDecoration.lineThrough : null,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.add_rounded, color: Color(0xFF7C7C81), size: 18),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    style: GoogleFonts.inter(color: Colors.white, fontSize: 13),
                    decoration: InputDecoration(
                      hintText: 'Add checklist item...',
                      hintStyle: GoogleFonts.inter(color: const Color(0xFF7C7C81), fontSize: 13),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                    onSubmitted: (val) {
                      if (val.trim().isNotEmpty) {
                        setState(() {
                          _checklistItemsList.add(val.trim());
                          _checklistStatesList.add(false);
                        });
                      }
                    },
                  ),
                ),
              ],
            ),
          ],
        ),
      );
    }

    if (resolvedType == 'code') {
      return Container(
        margin: const EdgeInsets.only(bottom: 16),
        width: double.infinity,
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFFE5E5EA),
          borderRadius: BorderRadius.circular(10),
        ),
        child: Text(
          _bodyController.text.isNotEmpty ? _bodyController.text : 'hello world',
          style: const TextStyle(
            fontFamily: 'Cascadia Code',
            color: Color(0xFFB71C1C),
            fontSize: 13,
          ),
        ),
      );
    }

    return const SizedBox.shrink();
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final resolvedType = _getResolvedType();
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: true,
      body: Container(
        width: double.infinity,
        height: double.infinity,
        color: Colors.black,
        child: SafeArea(
          top: false,
          child: Stack(
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // ── HEADER ─────────────────────────────────────────────────
                  Container(
                    padding: EdgeInsets.only(
                      top: MediaQuery.of(context).padding.top > 0
                          ? MediaQuery.of(context).padding.top
                          : 10,
                      bottom: 12,
                      left: 8,
                      right: 16,
                    ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        IconButton(
                          onPressed: () => Navigator.pop(context),
                          icon: const Icon(Icons.arrow_back,
                              color: Colors.white, size: 24),
                          padding: const EdgeInsets.all(8),
                          constraints: const BoxConstraints(),
                          splashRadius: 20,
                        ),
                        const SizedBox(width: 4),
                        Text(
                          widget.isSaveItem ? 'Save an Item' : 'Write a Post',
                          style: GoogleFonts.inter(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const Spacer(),
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
                                onPressed: widget.isSaveItem
                                    ? _post
                                    : ((_pickedImagePath == null &&
                                            _pickedVideoPath == null)
                                        ? () => _showSnack(
                                            'Please upload an image or video to post!')
                                        : _post),
                                style: TextButton.styleFrom(
                                  backgroundColor: (!widget.isSaveItem &&
                                            _pickedImagePath == null &&
                                            _pickedVideoPath == null)
                                        ? Colors.white.withValues(alpha: 0.3)
                                        : Colors.white,
                                  foregroundColor: Colors.black,
                                  padding: const EdgeInsets.symmetric(
                                      horizontal: 20, vertical: 8),
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                                child: Text(
                                  widget.isSaveItem ? 'Save' : 'Post',
                                  style: GoogleFonts.inter(
                                    fontSize: 14,
                                    fontWeight: FontWeight.w600,
                                    color: (!widget.isSaveItem &&
                                            _pickedImagePath == null &&
                                            _pickedVideoPath == null)
                                        ? Colors.black38
                                        : Colors.black,
                                  ),
                                ),
                              ),
                      ],
                    ),
                  ),

                  // ── CANVAS ─────────────────────────────────────────────────
                  Expanded(
                    child: SingleChildScrollView(
                      physics: const BouncingScrollPhysics(),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 8),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Always show Title input at the top
                          TextField(
                            controller: _titleController,
                            focusNode: _titleFocusNode,
                            maxLines: null,
                            keyboardType: TextInputType.multiline,
                            textCapitalization: TextCapitalization.sentences,
                            onChanged: (_) => setState(() {}),
                            inputFormatters: [
                              WordLimitTextInputFormatter(6),
                            ],
                            style: GoogleFonts.inter(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.w400,
                            ),
                            decoration: InputDecoration(
                              hintText: 'Title',
                              hintStyle: GoogleFonts.inter(
                                color: const Color(0xFF7C7C81),
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                              border: InputBorder.none,
                              contentPadding: EdgeInsets.zero,
                            ),
                          ),
                          Align(
                            alignment: Alignment.centerRight,
                            child: Padding(
                              padding: const EdgeInsets.only(top: 2, bottom: 6),
                              child: Text(
                                '${_getWordCount(_titleController.text)}/6 words',
                                style: GoogleFonts.inter(
                                  color: _getWordCount(_titleController.text) >= 6
                                      ? const Color(0xFFFAF096)
                                      : const Color(0xFF7C7C81),
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                          ),

                          if (widget.isSaveItem) ...[
                            _buildAutomaticPreview(),
                            const SizedBox(height: 6),
                            TextField(
                              controller: _bodyController,
                              focusNode: _bodyFocusNode,
                              maxLines: null,
                              textAlign: _bodyAlign,
                              keyboardType: TextInputType.multiline,
                              textCapitalization: TextCapitalization.sentences,
                              style: resolvedType == 'code'
                                  ? const TextStyle(
                                      fontFamily: 'Cascadia Code',
                                      color: Color(0xFFB71C1C),
                                      fontSize: 16,
                                    )
                                  : GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                    ),
                              decoration: InputDecoration(
                                hintText: 'save anything.....',
                                hintStyle: GoogleFonts.inter(
                                  color: const Color(0xFF7C7C81),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ] else ...[
                            // Body input
                            TextField(
                              controller: _bodyController,
                              focusNode: _bodyFocusNode,
                              maxLines: null,
                              textAlign: _bodyAlign,
                              keyboardType: TextInputType.multiline,
                              textCapitalization: TextCapitalization.sentences,
                              style: resolvedType == 'code'
                                  ? const TextStyle(
                                      fontFamily: 'Cascadia Code',
                                      color: Color(0xFFB71C1C),
                                      fontSize: 16,
                                    )
                                  : GoogleFonts.inter(
                                      color: Colors.white,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w400,
                                    ),
                              decoration: InputDecoration(
                                hintText:
                                    'Share your saved item to all..(optional)',
                                hintStyle: GoogleFonts.inter(
                                  color: const Color(0xFF7C7C81),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                ),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                            const SizedBox(height: 10),

                            // Link input
                            TextField(
                              controller: _urlController,
                              maxLines: 1,
                              keyboardType: TextInputType.url,
                              style: GoogleFonts.inter(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w400,
                              ),
                              decoration: InputDecoration(
                                hintText: 'Add a link (optional)',
                                hintStyle: GoogleFonts.inter(
                                  color: const Color(0xFF7C7C81),
                                  fontSize: 16,
                                  fontWeight: FontWeight.w400,
                                ),
                                prefixIcon: const Padding(
                                  padding: EdgeInsets.only(right: 8.0),
                                  child: Icon(Icons.link,
                                      color: Color(0xFF7C7C81), size: 20),
                                ),
                                prefixIconConstraints: const BoxConstraints(
                                    minWidth: 0, minHeight: 0),
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                              ),
                            ),
                          ],

                          // ── Attachment preview cards ────────────────────────
                          _buildAttachmentPreviews(),

                          // ── Image preview ────────────────────────────────────
                          if (!widget.isSaveItem && _pickedImagePath != null) ...[
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
                                        color: Colors.black
                                            .withValues(alpha: 0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close,
                                          color: Colors.white, size: 16),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                          if (!widget.isSaveItem && _pickedVideoPath != null) ...[
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
                                        color: Colors.black
                                            .withValues(alpha: 0.6),
                                        shape: BoxShape.circle,
                                      ),
                                      child: const Icon(Icons.close,
                                          color: Colors.white, size: 16),
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
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_isFormattingToolOpen) _buildInlineFormattingToolbar(),
                      Container(
                        color: widget.isSaveItem
                            ? const Color(0xFF7C7C81)
                            : const Color(0xFF4A4A4C),
                        padding: const EdgeInsets.symmetric(
                            horizontal: 12, vertical: 8),
                        child: Row(
                          children: [
                            // Image picker
                            IconButton(
                              onPressed: _pickImage,
                              icon: Icon(
                                Icons.image,
                                color: _pickedImagePath != null
                                    ? const Color(0xFF6B9BF7)
                                    : Colors.white,
                                size: 24,
                              ),
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(6),
                            ),
                            const SizedBox(width: 2),
                            // Video picker
                            IconButton(
                              onPressed: _pickVideo,
                              icon: Icon(
                                Icons.smart_display,
                                color: _pickedVideoPath != null
                                    ? const Color(0xFF6B9BF7)
                                    : Colors.white,
                                size: 24,
                              ),
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(6),
                            ),
                            const SizedBox(width: 2),
                            // Formatting toolbar toggle
                            IconButton(
                              onPressed: _openRichTextEditor,
                              icon: Icon(
                                Icons.text_fields_rounded,
                                color: _isFormattingToolOpen
                                    ? const Color(0xFF6B9BF7)
                                    : Colors.white,
                                size: 24,
                              ),
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(6),
                            ),
                            const SizedBox(width: 2),
                            // Drawing canvas
                            IconButton(
                              onPressed: _openDrawingMode,
                              icon: const Icon(
                                Icons.edit_outlined,
                                color: Colors.white,
                                size: 24,
                              ),
                              constraints: const BoxConstraints(),
                              padding: const EdgeInsets.all(6),
                            ),
                            const Spacer(),
                            if (widget.isSaveItem)
                              // Plus button
                              GestureDetector(
                                onTap: _togglePlusMenu,
                                child: AnimatedContainer(
                                  duration: const Duration(milliseconds: 200),
                                  width: 36,
                                  height: 36,
                                  decoration: BoxDecoration(
                                    color: _isPlusMenuOpen
                                        ? const Color(0xFF6B9BF7)
                                        : Colors.white,
                                    shape: BoxShape.circle,
                                  ),
                                  child: Icon(
                                    _isPlusMenuOpen ? Icons.close : Icons.add,
                                    color: _isPlusMenuOpen
                                        ? Colors.white
                                        : Colors.black,
                                    size: 24,
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ],
              ),

              // ── Plus Menu floating widget ──────────────────────────────────
              if (_isPlusMenuOpen)
                Positioned(
                  bottom: 60.0 + (_isFormattingToolOpen ? 50.0 : 0.0) + 10.0,
                  right: 16,
                  child: FadeTransition(
                    opacity: _plusMenuOpacity,
                    child: SlideTransition(
                      position: _plusMenuSlide,
                      child: _buildPlusMenu(),
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

class WaveformPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.redAccent.withValues(alpha: 0.6)
      ..style = PaintingStyle.fill;
    final activePaint = Paint()
      ..color = Colors.redAccent
      ..style = PaintingStyle.fill;

    final double barWidth = 3;
    final double spacing = 2;
    final int barCount = (size.width / (barWidth + spacing)).floor();
    final double midY = size.height / 2;

    for (int i = 0; i < barCount; i++) {
      final h = 4.0 + (math.sin(i * 0.5) * 8.0).abs() + (i % 3 == 0 ? 6.0 : 0.0);
      final x = i * (barWidth + spacing);
      final rrect = RRect.fromRectAndRadius(
        Rect.fromLTWH(x, midY - h/2, barWidth, h),
        const Radius.circular(1),
      );
      canvas.drawRRect(rrect, i < barCount * 0.35 ? activePaint : paint);
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class WordLimitTextInputFormatter extends TextInputFormatter {
  final int maxWords;

  WordLimitTextInputFormatter(this.maxWords);

  @override
  TextEditingValue formatEditUpdate(
      TextEditingValue oldValue, TextEditingValue newValue) {
    final text = newValue.text.trim();
    if (text.isEmpty) {
      return newValue;
    }
    final words = text.split(RegExp(r'\s+'));
    if (words.length > maxWords) {
      return oldValue;
    }
    return newValue;
  }
}
