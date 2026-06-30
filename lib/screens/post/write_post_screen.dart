import 'dart:io';
import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:any_link_preview/any_link_preview.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:image_picker/image_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:flutter_contacts/flutter_contacts.dart';
import 'package:open_filex/open_filex.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../utils/post_store.dart';
import '../../utils/user_store.dart';
import '../../widgets/running_video_player.dart';
import '../../widgets/interactive_video_player.dart';
import '../post_detail/post_detail_screen.dart';
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

  _AttachItem.audio({required this.duration, this.path, this.name = 'Audio Recording'})
      : type = _AttachType.audio,
        extension = null,
        phone = null;
}

class EditorBlock {
  final String type; // 'text' or 'code'
  final TextEditingController controller;
  final FocusNode focusNode;
  String lang;

  EditorBlock({
    required this.type,
    TextEditingController? controller,
    FocusNode? focusNode,
    this.lang = 'Text',
  })  : controller = controller ?? (type == 'text' ? RichTextController() : TextEditingController()),
        focusNode = focusNode ?? FocusNode();

  void dispose() {
    controller.dispose();
    focusNode.dispose();
  }
}

// ── Screen ────────────────────────────────────────────────────────────────────


class WritePostScreen extends StatefulWidget {
  final bool isSaveItem;
  final Map<String, dynamic>? sharedData;
  final UserPost? editingPost;

  const WritePostScreen({super.key, this.isSaveItem = false, this.sharedData, this.editingPost});

  @override
  State<WritePostScreen> createState() => _WritePostScreenState();
}

class _WritePostScreenState extends State<WritePostScreen>
    with TickerProviderStateMixin {
  final _titleController = TextEditingController();
  final _urlController = TextEditingController();

  final _titleFocusNode = FocusNode();
  
  final List<EditorBlock> _blocks = [EditorBlock(type: 'text')];

  RichTextController get _activeTextController {
    for (var b in _blocks) {
      if (b.type == 'text' && b.focusNode.hasFocus) {
        return b.controller as RichTextController;
      }
    }
    for (var b in _blocks) {
      if (b.type == 'text') return b.controller as RichTextController;
    }
    if (_blocks.isEmpty) {
      _blocks.add(EditorBlock(type: 'text'));
    }
    return _blocks.first.controller as RichTextController;
  }

  FocusNode get _activeFocusNode {
    for (var b in _blocks) {
      if (b.type == 'text' && b.focusNode.hasFocus) {
        return b.focusNode;
      }
    }
    for (var b in _blocks) {
      if (b.type == 'text') return b.focusNode;
    }
    if (_blocks.isEmpty) {
      _blocks.add(EditorBlock(type: 'text'));
    }
    return _blocks.first.focusNode;
  }

  bool _saveInProfile = false;
  bool _isPublicPost = true; // true = public, false = private (only matters in post mode)
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

  EditorBlock _createCodeBlockFromRaw(String rawCode) {
    String lang = 'Text';
    String codeContent = rawCode;
    final firstLineEnd = rawCode.indexOf('\n');
    if (firstLineEnd != -1) {
      final firstLine = rawCode.substring(0, firstLineEnd).trim();
      if (firstLine.isNotEmpty && !firstLine.contains(' ') && firstLine.length < 15) {
        lang = firstLine;
        codeContent = rawCode.substring(firstLineEnd + 1);
      }
    }
    return EditorBlock(type: 'code', lang: lang, controller: TextEditingController(text: codeContent.trim()));
  }

  void _parseBodyToBlocks(String body, [List<RichStyle>? charStyles]) {
    _blocks.clear();
    if (!body.contains('```')) {
      final ctrl = RichTextController()..text = body;
      if (charStyles != null) ctrl.charStyles.addAll(charStyles);
      _blocks.add(EditorBlock(type: 'text', controller: ctrl));
      return;
    }
    
    int start = 0;
    while (start < body.length) {
      int codeStart = body.indexOf('```', start);
      if (codeStart == -1) {
        String text = body.substring(start);
        if (text.isNotEmpty || _blocks.isEmpty) {
          _blocks.add(EditorBlock(type: 'text', controller: RichTextController()..text = text));
        }
        break;
      }
      
      if (codeStart > start) {
        _blocks.add(EditorBlock(type: 'text', controller: RichTextController()..text = body.substring(start, codeStart)));
      }
      
      int codeEnd = body.indexOf('```', codeStart + 3);
      if (codeEnd == -1) {
        String rawCode = body.substring(codeStart + 3);
        _blocks.add(_createCodeBlockFromRaw(rawCode));
        break;
      } else {
        String rawCode = body.substring(codeStart + 3, codeEnd);
        _blocks.add(_createCodeBlockFromRaw(rawCode));
        start = codeEnd + 3;
      }
    }
  }

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
  late bool _isEditingMode;

  @override
  void initState() {
    super.initState();
    _saveInProfile = widget.isSaveItem;
    _isEditingMode = widget.editingPost == null;

    // For post mode: load default visibility from settings
    if (!widget.isSaveItem && widget.editingPost == null) {
      SharedPreferences.getInstance().then((prefs) {
        final defaultPublic = prefs.getBool('default_post_public') ?? true;
        if (mounted) setState(() => _isPublicPost = defaultPublic);
      });
    }

    if (widget.editingPost != null) {
      final post = widget.editingPost!;
      _saveInProfile = post.savedInProfile;
      _titleController.text = post.title;
      _parseBodyToBlocks(post.body, post.charStyles);
      if (post.url != null) _urlController.text = post.url!;
      if (post.imagePath != null) _pickedImagePath = post.imagePath;
      if (post.videoPath != null) _pickedVideoPath = post.videoPath;
      
      _sharedType = post.type;
      _sharedFilePath = post.filePath;
      _contactName = post.contactName;
      _contactPhone = post.contactPhone;
      _audioDuration = post.duration;
      
      if (post.checklistItems != null && post.checklistStates != null) {
        _checklistItemsList.addAll(post.checklistItems!);
        _checklistStatesList.addAll(post.checklistStates!);
      }

      if (post.type == 'document') {
        final paths = post.filePaths ?? (post.filePath != null ? [post.filePath!] : []);
        for (var path in paths) {
          final name = path.split('/').last.split('\\').last;
          _attachedItems.add(_AttachItem.document(
            name: name,
            path: path,
            extension: path.split('.').last.toUpperCase(),
          ));
        }
      } else if (post.type == 'audio' && post.filePath != null) {
        _attachedItems.add(_AttachItem.audio(
          duration: post.duration,
        ));
      } else if (post.type == 'contact') {
        if (post.contactNames != null && post.contactPhones != null) {
          for (int i = 0; i < post.contactNames!.length; i++) {
            _attachedItems.add(_AttachItem.contact(
              name: post.contactNames![i],
              phone: post.contactPhones![i],
            ));
          }
        } else {
          _attachedItems.add(_AttachItem.contact(
            name: post.contactName ?? 'Contact',
            phone: post.contactPhone,
          ));
        }
      }
    } else if (widget.sharedData != null) {
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
          _parseBodyToBlocks(text);
        } else {
          _sharedType = 'text';
          _titleController.text = 'Shared Idea';
          _parseBodyToBlocks(text);
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
        final name = data['name'] as String? ?? 'Shared Audio';
        _titleController.text = name;
        if (_sharedFilePath != null) {
          _attachedItems.add(_AttachItem.audio(
            duration: _audioDuration,
          ));
        }
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
          final name = data['name'] as String? ?? 'Shared Document';
          _titleController.text = name;
          if (filePath.isNotEmpty) {
            _attachedItems.add(_AttachItem.document(
              name: name,
              path: filePath,
              extension: filePath.split('.').last.toUpperCase(),
            ));
          }
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
        // Request focus to keep keyboard open
        _activeFocusNode.requestFocus();
      } else {
        _titleFocusNode.requestFocus();
      }
    });
  }

  @override
  void dispose() {
    _titleController.dispose();
    _urlController.dispose();
    _titleFocusNode.dispose();
    for (var b in _blocks) {
      b.dispose();
    }
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
    final activeStyle = _activeTextController.getActiveStyle();

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
                _activeTextController.applyStyle(bold: !(activeStyle.bold == true));
                _activeFocusNode.requestFocus();
                setState(() {});
              },
            ),
            _buildToolbarToggle(
              icon: Icons.format_italic,
              active: activeStyle.italic == true,
              onTap: () {
                _activeTextController
                    .applyStyle(italic: !(activeStyle.italic == true));
                _activeFocusNode.requestFocus();
                setState(() {});
              },
            ),
            _buildToolbarToggle(
              icon: Icons.format_underlined,
              active: activeStyle.underline == true,
              onTap: () {
                _activeTextController
                    .applyStyle(underline: !(activeStyle.underline == true));
                _activeFocusNode.requestFocus();
                setState(() {});
              },
            ),
            _buildToolbarToggle(
              icon: Icons.format_strikethrough,
              active: activeStyle.strikethrough == true,
              onTap: () {
                _activeTextController.applyStyle(
                    strikethrough: !(activeStyle.strikethrough == true));
                _activeFocusNode.requestFocus();
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
                _activeFocusNode.requestFocus();
              },
            ),
            _buildToolbarToggle(
              icon: Icons.format_align_center,
              active: _bodyAlign == TextAlign.center,
              onTap: () {
                setState(() => _bodyAlign = TextAlign.center);
                _activeFocusNode.requestFocus();
              },
            ),
            _buildToolbarToggle(
              icon: Icons.format_align_right,
              active: _bodyAlign == TextAlign.right,
              onTap: () {
                setState(() => _bodyAlign = TextAlign.right);
                _activeFocusNode.requestFocus();
              },
            ),
            _buildToolbarDivider(),

            // Font Sizes
            _buildSizeChip(
                '12', activeStyle.fontSize == 12.0, () {
              _activeTextController.applyStyle(fontSize: 12.0);
              _activeFocusNode.requestFocus();
              setState(() {});
            }),
            _buildSizeChip(
                '16',
                activeStyle.fontSize == 16.0 || activeStyle.fontSize == null,
                () {
              _activeTextController.applyStyle(fontSize: 16.0);
              _activeFocusNode.requestFocus();
              setState(() {});
            }),
            _buildSizeChip(
                '20', activeStyle.fontSize == 20.0, () {
              _activeTextController.applyStyle(fontSize: 20.0);
              _activeFocusNode.requestFocus();
              setState(() {});
            }),
            _buildSizeChip(
                '26', activeStyle.fontSize == 26.0, () {
              _activeTextController.applyStyle(fontSize: 26.0);
              _activeFocusNode.requestFocus();
              setState(() {});
            }),
            _buildToolbarDivider(),

            // Lists
            _buildToolbarToggle(
              icon: Icons.format_list_bulleted,
              active: false,
              onTap: () {
                _activeTextController.toggleList('• ');
                _activeFocusNode.requestFocus();
                setState(() {});
              },
            ),
            _buildToolbarToggle(
              icon: Icons.format_list_numbered,
              active: false,
              onTap: () {
                _activeTextController.toggleList('1. ');
                _activeFocusNode.requestFocus();
                setState(() {});
              },
            ),
            _buildToolbarToggle(
              icon: Icons.checklist,
              active: false,
              onTap: () {
                _activeTextController.toggleList('[ ] ');
                _activeFocusNode.requestFocus();
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
                _activeTextController.applyStyle(color: col);
                _activeFocusNode.requestFocus();
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
              _activeTextController.applyStyle(clearHighlight: true);
              _activeFocusNode.requestFocus();
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
                _activeTextController.applyStyle(highlightColor: hlCol);
                _activeFocusNode.requestFocus();
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
        allowMultiple: true,
        withData: false,
      );

      if (result != null && result.files.isNotEmpty && mounted) {
        setState(() {
          for (var file in result.files) {
            if (file.path != null) {
              _attachedItems.add(_AttachItem.document(
                name: file.name,
                path: file.path!,
                extension: file.extension?.toUpperCase(),
              ));
            }
          }
        });
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

  // ── Audio Picker ──────────────────────────────────────────────────────────

  Future<void> _pickAudioFile() async {
    _togglePlusMenu();
    try {
      final result = await FilePicker.platform.pickFiles(type: FileType.audio);
      if (result != null && result.files.single.path != null) {
        final path = result.files.single.path!;
        final name = result.files.single.name;
        
        String durText = '00:00';
        try {
          final player = AudioPlayer();
          await player.setSource(DeviceFileSource(path));
          final duration = await player.getDuration();
          if (duration != null) {
            final int m = duration.inSeconds ~/ 60;
            final int s = duration.inSeconds % 60;
            durText = '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
          }
          await player.dispose();
        } catch (e) {
          debugPrint("Could not get duration: $e");
          durText = '00:45';
        }

        setState(() {
          _attachedItems.add(_AttachItem.audio(
            duration: durText,
            path: path,
            name: name,
          ));
          _activeTextController.text += '\n\n[Audio Recording: $durText]';
        });
      }
    } catch (e) {
      if (mounted) {
        _showSnack('Could not pick audio: $e');
      }
    }
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

    return GestureDetector(
      onTap: () async {
        try {
          if (item.path != null) {
            await OpenFilex.open(item.path!);
          }
        } catch (e) {
          debugPrint('Error opening file: $e');
        }
      },
      child: Container(
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
    ));
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
      child: AudioPlayerBlock(
        durationText: item.duration ?? '0:00',
        filePath: item.path,
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
    return Container(
      width: MediaQuery.of(context).size.width - 40,
      decoration: BoxDecoration(
        color: const Color(0xFF2C2C2E).withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.5),
            blurRadius: 24,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      padding: const EdgeInsets.all(20),
      child: Wrap(
        spacing: 16,
        runSpacing: 20,
        alignment: WrapAlignment.center,
        children: [
          _buildMenuGridItem(
            'Document',
            Icons.description_rounded,
            _openDocumentSelector,
          ),
          _buildMenuGridItem(
            'Contact',
            Icons.person_rounded,
            _openContactSelector,
          ),
          _buildMenuGridItem(
            'Audio',
            Icons.audio_file_rounded,
            _pickAudioFile,
          ),
          _buildMenuGridItem(
            'Checklist',
            Icons.check_box_rounded,
            () {
              _activeTextController.toggleList('[ ] ');
              _togglePlusMenu();
            },
          ),
          _buildMenuGridItem(
            'Bullet List',
            Icons.format_list_bulleted_rounded,
            () {
              _activeTextController.toggleList('• ');
              _togglePlusMenu();
            },
          ),
          _buildMenuGridItem(
            'Code Block',
            Icons.code_rounded,
            () {
              setState(() {
                _blocks.add(EditorBlock(type: 'code', lang: 'dart'));
                _blocks.add(EditorBlock(type: 'text'));
              });
              _togglePlusMenu();
            },
          ),
        ],
      ),
    );
  }

  Widget _buildMenuGridItem(String label, IconData icon, VoidCallback onTap) {
    return GestureDetector(
      onTap: onTap,
      child: SizedBox(
        width: 70,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                color: Colors.transparent,
                shape: BoxShape.circle,
                border: Border.all(color: const Color(0xFFFAF096), width: 1.0),
              ),
              child: Center(
                child: Icon(icon, color: Colors.white, size: 24),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 11,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 2,
            ),
          ],
        ),
      ),
    );
  }

  // ── Post / Save ────────────────────────────────────────────────────────────

  String _serializeBody() {
    return _blocks.map((b) {
      if (b.type == 'code') {
        return '```${b.lang}\n${b.controller.text.trim()}\n```';
      }
      return b.controller.text;
    }).where((t) => t.isNotEmpty).join('\n\n');
  }

  List<RichStyle> _serializeCharStyles() {
    List<RichStyle> allStyles = [];
    for (int i = 0; i < _blocks.length; i++) {
      var b = _blocks[i];
      if (b.type == 'code') {
        int len = '```${b.lang}\n${b.controller.text.trim()}\n```'.length;
        if (i != _blocks.length - 1) len += 2; // \n\n
        for (int j = 0; j < len; j++) {
          allStyles.add(const RichStyle());
        }
      } else {
        final ctrl = b.controller as RichTextController;
        allStyles.addAll(ctrl.charStyles);
        if (i != _blocks.length - 1) {
          allStyles.add(const RichStyle()); // \n
          allStyles.add(const RichStyle()); // \n
        }
      }
    }
    return allStyles;
  }

  Future<void> _post() async {
    final title = _titleController.text.trim();

    // Build body: text content only. We no longer serialize attachments into the text.
    final String body = _serializeBody();

    // No content at all — reject
    if (body.isEmpty &&
        _pickedImagePath == null &&
        _pickedVideoPath == null &&
        _attachedItems.isEmpty &&
        _sharedFilePath == null) {
      _showSnack(widget.isSaveItem
          ? 'Please add some content, attachment or media!'
          : 'Please enter some content to post!');
      return;
    }

    setState(() => _isPosting = true);
    await Future.delayed(const Duration(milliseconds: 300));

    String resolvedTitle = title;
    if (widget.isSaveItem && resolvedTitle.isEmpty) {
      final bodyLines = body.split('\n');
      if (bodyLines.isNotEmpty && bodyLines.first.trim().isNotEmpty) {
        resolvedTitle = bodyLines.first.trim();
        if (resolvedTitle.length > 30) {
          resolvedTitle = '${resolvedTitle.substring(0, 27)}...';
        }
      } else if (_attachedItems.isNotEmpty) {
        resolvedTitle = _attachedItems.first.name;
      } else if (_sharedFilePath != null) {
        resolvedTitle = _sharedFilePath!.split('/').last.split('\\').last;
      } else {
        resolvedTitle = 'Saved Item';
      }
    }

    String? resolvedFilePath = _sharedFilePath;
    List<String> resolvedFilePaths = [];
    String? resolvedContactName = _contactName;
    String? resolvedContactPhone = _contactPhone;
    String? resolvedDuration = _audioDuration;
    List<String> resolvedContactNames = [];
    List<String> resolvedContactPhones = [];

    if (_attachedItems.isNotEmpty) {
      for (var item in _attachedItems) {
        if (item.type == _AttachType.contact) {
          resolvedContactNames.add(item.name);
          resolvedContactPhones.add(item.phone ?? '');
        } else if (item.type == _AttachType.document && item.path != null) {
          resolvedFilePaths.add(item.path!);
        }
      }

      final first = _attachedItems.first;
      if (first.type == _AttachType.document) {
        resolvedFilePath = first.path;
      } else if (first.type == _AttachType.contact) {
        resolvedContactName = first.name;
        resolvedContactPhone = first.phone;
      } else if (first.type == _AttachType.audio) {
        resolvedDuration = first.duration;
        resolvedFilePath = first.path;
      }
    }

    final String resolvedType = _getResolvedType();

    final post = UserPost(
      id: widget.editingPost?.id ?? DateTime.now().millisecondsSinceEpoch.toString(),
      title: resolvedTitle.isEmpty ? 'Untitled' : resolvedTitle,
      body: body,
      url: _urlController.text.trim().isEmpty
          ? null
          : _urlController.text.trim(),
      username: widget.editingPost?.username ?? UserStore.instance.currentUser?.userId ?? 'gangster_vagas',
      imagePath: _pickedImagePath,
      videoPath: _pickedVideoPath,
      // Save mode: always saved in profile (personal vault), never private-post
      // Post mode: savedInProfile=false always; isPrivate=true when user chose "Private"
      savedInProfile: widget.isSaveItem ? true : false,
      isPrivate: widget.isSaveItem ? false : !_isPublicPost,
      createdAt: widget.editingPost?.createdAt ?? DateTime.now(),
      charStyles: _serializeCharStyles(),
      type: resolvedType,
      filePath: resolvedFilePath,
      filePaths: resolvedFilePaths.isNotEmpty ? resolvedFilePaths : null,
      contactName: resolvedContactName,
      contactPhone: resolvedContactPhone,
      contactNames: resolvedContactNames.isNotEmpty ? resolvedContactNames : null,
      contactPhones: resolvedContactPhones.isNotEmpty ? resolvedContactPhones : null,
      duration: resolvedDuration,
      checklistItems: _checklistItemsList.isNotEmpty ? _checklistItemsList : null,
      checklistStates: _checklistStatesList.isNotEmpty ? _checklistStatesList : null,
    );

    if (widget.editingPost != null) {
      PostStore.instance.updateUserPost(post);
    } else {
      PostStore.instance.addPost(post);
    }

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
        _blocks.any((b) => b.type == 'code') ? 'code' : 'text'
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

  Widget _buildBodyInput(String resolvedType) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: _blocks.asMap().entries.map((entry) {
        int idx = entry.key;
        EditorBlock block = entry.value;

        if (block.type == 'code') {
          return _buildEditableCodeBlock(block, idx);
        }

        return TextField(
          controller: block.controller,
          focusNode: block.focusNode,
          readOnly: !_isEditingMode,
          maxLines: null,
          textAlign: _bodyAlign,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w400,
          ),
          decoration: const InputDecoration(
            border: InputBorder.none,
            contentPadding: EdgeInsets.zero,
          ),
        );
      }).toList(),
    );
  }

  Widget _buildEditableCodeBlock(EditorBlock block, int index) {
    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(top: 12.0, bottom: 12.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: const BoxDecoration(
              color: Color(0xFF2D2D30),
              borderRadius: BorderRadius.vertical(top: Radius.circular(8)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Row(
                  children: [
                    Text(
                      block.lang,
                      style: GoogleFonts.inter(
                        color: const Color(0xFFD4D4D4),
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(Icons.keyboard_arrow_down, color: Color(0xFF98989E), size: 16),
                  ],
                ),
                Row(
                  children: [
                    GestureDetector(
                      onTap: () {
                        Clipboard.setData(ClipboardData(text: block.controller.text));
                        _showSnack('Copied to clipboard');
                      },
                      child: const Icon(Icons.copy_rounded, color: Color(0xFF98989E), size: 14),
                    ),
                    const SizedBox(width: 16),
                    GestureDetector(
                      onTap: () {
                        setState(() {
                          final removed = _blocks.removeAt(index);
                          removed.dispose();
                          if (_blocks.isEmpty) {
                            _blocks.add(EditorBlock(type: 'text'));
                          }
                        });
                      },
                      child: const Icon(Icons.close, color: Color(0xFF98989E), size: 14),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(16.0),
            child: TextField(
              controller: block.controller,
              focusNode: block.focusNode,
              readOnly: !_isEditingMode,
              maxLines: null,
              style: const TextStyle(
                fontFamily: 'Cascadia Code',
                color: Color(0xFFD4D4D4),
                fontSize: 14,
                height: 1.5,
              ),
              decoration: const InputDecoration(
                hintText: '// Your code snippet here',
                hintStyle: TextStyle(
                  fontFamily: 'Cascadia Code',
                  color: Color(0xFF7C7C81),
                  fontSize: 14,
                ),
                border: InputBorder.none,
                contentPadding: EdgeInsets.zero,
                isDense: true,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTitleInput() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        TextField(
          controller: _titleController,
          focusNode: _titleFocusNode,
          readOnly: !_isEditingMode,
          maxLines: null,
          keyboardType: TextInputType.multiline,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => setState(() {}),
          inputFormatters: [
            WordLimitTextInputFormatter(6),
          ],
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
          decoration: InputDecoration(
            hintText: 'Heading',
            hintStyle: GoogleFonts.inter(
              color: const Color(0xFF7C7C81),
              fontSize: 24,
              fontWeight: FontWeight.w700,
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
      ],
    );
  }

  void _openLinkDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          backgroundColor: const Color(0xFF1C1C1E),
          title: Text('Add Link', style: GoogleFonts.inter(color: Colors.white)),
          content: TextField(
            controller: _urlController,
            style: GoogleFonts.inter(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'https://...',
              hintStyle: GoogleFonts.inter(color: Colors.white54),
              filled: true,
              fillColor: const Color(0xFF2C2C2E),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(8),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context),
              child: Text('Cancel', style: GoogleFonts.inter(color: Colors.white54)),
            ),
            TextButton(
              onPressed: () {
                setState(() {});
                Navigator.pop(context);
              },
              child: Text('Save', style: GoogleFonts.inter(color: const Color(0xFFFAF096))),
            ),
          ],
        );
      },
    );
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    final resolvedType = _getResolvedType();
    return Scaffold(
      backgroundColor: Colors.black,
      resizeToAvoidBottomInset: false, // We'll manage inset manually for the floating bar
      body: Stack(
        children: [
          // ── CANVAS (Full Screen Scroll) ────────────────────────────
          Positioned.fill(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: EdgeInsets.only(
                top: MediaQuery.of(context).padding.top + 80,
                bottom: MediaQuery.of(context).viewInsets.bottom + 140, // Space for floating bar
                left: 20,
                right: 20,
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildTitleInput(),
                  const SizedBox(height: 10),
                  _buildBodyInput(resolvedType),
                  const SizedBox(height: 10),
                  if (_urlController.text.isNotEmpty) ...[
                    Builder(
                      builder: (context) {
                        return AnyLinkPreview(
                          link: _urlController.text,
                          displayDirection: UIDirection.uiDirectionHorizontal,
                          showMultimedia: true,
                          bodyMaxLines: 3,
                          bodyTextOverflow: TextOverflow.ellipsis,
                          titleStyle: GoogleFonts.inter(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 15,
                          ),
                          bodyStyle: GoogleFonts.inter(
                            color: const Color(0xFFAEAEB2),
                            fontSize: 12,
                          ),
                          errorWidget: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2C2C2E),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                const Icon(Icons.link, color: Color(0xFF8E8E93), size: 16),
                                const SizedBox(width: 8),
                                Flexible(
                                  child: Text(
                                    _urlController.text,
                                    style: GoogleFonts.inter(
                                      color: const Color(0xFF8E8E93),
                                      fontSize: 13,
                                      fontWeight: FontWeight.w400,
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                                if (_isEditingMode) ...[
                                  const SizedBox(width: 8),
                                  GestureDetector(
                                    onTap: () => setState(() => _urlController.clear()),
                                    child: const Icon(Icons.close, color: Color(0xFF8E8E93), size: 16),
                                  ),
                                ],
                              ],
                            ),
                          ),
                          errorImage: "https://via.placeholder.com/150",
                          cache: const Duration(days: 7),
                          backgroundColor: const Color(0xFF2C2C2E),
                          borderRadius: 8,
                          removeElevation: true,
                          boxShadow: const [],
                          onTap: () async {
                            String urlString = _urlController.text.trim();
                            if (!urlString.startsWith('http://') && !urlString.startsWith('https://')) {
                              urlString = 'https://$urlString';
                            }
                            final Uri uri = Uri.parse(urlString);
                            if (await canLaunchUrl(uri)) {
                              await launchUrl(uri, mode: LaunchMode.externalApplication);
                            } else {
                              try {
                                await launchUrl(uri, mode: LaunchMode.externalApplication);
                              } catch (e) {
                                debugPrint('Could not launch $uri');
                              }
                            }
                          },
                        );
                      },
                    ),
                    const SizedBox(height: 10),
                  ],

                          // ── Attachment preview cards ────────────────────────
                          _buildAttachmentPreviews(),

                          // ── Image preview ────────────────────────────────────
                          if (_pickedImagePath != null) ...[
                            const SizedBox(height: 20),
                            Stack(
                              children: [
                                Container(
                                  width: double.infinity,
                                  height: 200,
                                  decoration: BoxDecoration(
                                    color: const Color(0xFF1C1C1E),
                                    borderRadius: BorderRadius.circular(14),
                                    border: Border.all(color: Colors.white12, width: 0.5),
                                  ),
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.file(
                                      File(_pickedImagePath!),
                                      fit: BoxFit.contain,
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
                          if (_pickedVideoPath != null) ...[
                            const SizedBox(height: 20),
                            Stack(
                              children: [
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(14),
                                  child: InteractiveVideoPlayer(
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
                        ],
                      ),
                    ),
                  ),

          // ── HEADER (Frosted Glass) ──────────────────────────────────
          Positioned(
            top: 0, left: 0, right: 0,
            child: ClipRect(
              child: BackdropFilter(
                filter: ui.ImageFilter.blur(sigmaX: 15, sigmaY: 15),
                child: Container(
                  color: Colors.black.withValues(alpha: 0.6),
                  padding: EdgeInsets.only(
                    top: MediaQuery.of(context).padding.top > 0
                        ? MediaQuery.of(context).padding.top + 10
                        : 20,
                    bottom: 16,
                    left: 12,
                    right: 20,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      IconButton(
                        onPressed: () => Navigator.pop(context),
                        icon: const Icon(Icons.arrow_back_ios_new, color: Colors.white, size: 20),
                        padding: const EdgeInsets.all(8),
                        constraints: const BoxConstraints(),
                        splashRadius: 20,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        widget.editingPost != null
                            ? 'Edit Item'
                            : (widget.isSaveItem ? 'Save anything' : 'Write a Post'),
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.5,
                        ),
                      ),
                      const Spacer(),
                      if (!_isEditingMode && (widget.editingPost != null || widget.isSaveItem)) ...[
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isEditingMode = true;
                              if (widget.isSaveItem) {
                                _activeFocusNode.requestFocus();
                              } else {
                                _titleFocusNode.requestFocus();
                              }
                            });
                          },
                          child: const Icon(Icons.edit, color: Colors.white, size: 22),
                        ),
                        const SizedBox(width: 16),
                      ],
                      _isPosting
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(strokeWidth: 2.5, color: Colors.white),
                            )
                          : Container(
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: Material(
                                color: Colors.transparent,
                                child: InkWell(
                                  onTap: _saveInProfile
                                      ? _post
                                      : ((_pickedImagePath == null && _pickedVideoPath == null)
                                          ? () => _showSnack('Please upload an image or video to post!')
                                          : _post),
                                  borderRadius: BorderRadius.circular(20),
                                  child: Padding(
                                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                                    child: Text(
                                      _saveInProfile ? 'Save' : 'Post',
                                      style: GoogleFonts.inter(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600,
                                        color: Colors.black,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // ── BOTTOM TOOLBAR (Floating) ──────────────────────────────
          if (_isEditingMode)
            Positioned(
              bottom: MediaQuery.of(context).viewInsets.bottom > 0 ? MediaQuery.of(context).viewInsets.bottom + 12 : 24,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (_isFormattingToolOpen) _buildInlineFormattingToolbar(),
                Container(
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E).withValues(alpha: 0.95),
                    borderRadius: BorderRadius.circular(30),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.5),
                        blurRadius: 24,
                        offset: const Offset(0, 8),
                      ),
                      BoxShadow(
                        color: Colors.white.withValues(alpha: 0.05),
                        blurRadius: 0,
                        spreadRadius: 1,
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                  child: Row(
                    children: [
                      // Image picker
                      IconButton(
                        onPressed: _pickImage,
                        icon: Icon(
                          Icons.image_outlined,
                          color: _pickedImagePath != null ? const Color(0xFFFAF096) : Colors.white,
                          size: 22,
                        ),
                        splashRadius: 20,
                      ),
                      // Video picker
                      IconButton(
                        onPressed: _pickVideo,
                        icon: Icon(
                          Icons.play_circle_outline,
                          color: _pickedVideoPath != null ? const Color(0xFFFAF096) : Colors.white,
                          size: 22,
                        ),
                        splashRadius: 20,
                      ),
                      // Formatting toolbar toggle
                      IconButton(
                        onPressed: _openRichTextEditor,
                        icon: Icon(
                          Icons.text_format_rounded,
                          color: _isFormattingToolOpen ? const Color(0xFFFAF096) : Colors.white,
                          size: 22,
                        ),
                        splashRadius: 20,
                      ),
                      // Add Link Button
                      IconButton(
                        onPressed: _openLinkDialog,
                        icon: Icon(
                          Icons.link,
                          color: _urlController.text.isNotEmpty ? const Color(0xFFFAF096) : Colors.white,
                          size: 22,
                        ),
                        splashRadius: 20,
                      ),
                      // Drawing canvas
                      IconButton(
                        onPressed: _openDrawingMode,
                        icon: const Icon(Icons.edit_outlined, color: Colors.white, size: 22),
                        splashRadius: 20,
                      ),
                      const Spacer(),
                      if (widget.isSaveItem)
                        // Plus button
                        GestureDetector(
                          onTap: _togglePlusMenu,
                          child: AnimatedContainer(
                            duration: const Duration(milliseconds: 300),
                            curve: Curves.easeOutBack,
                            width: 40,
                            height: 40,
                            decoration: BoxDecoration(
                              color: _isPlusMenuOpen ? Colors.white : Colors.transparent,
                              border: Border.all(color: const Color(0xFFFAF096), width: 1.0),
                              shape: BoxShape.circle,
                            ),
                            child: Icon(
                              _isPlusMenuOpen ? Icons.close_rounded : Icons.add_rounded,
                              color: _isPlusMenuOpen ? Colors.black : Colors.white,
                              size: 26,
                            ),
                          ),
                        ),
                       if (!widget.isSaveItem)
                         // Public / Private visibility pill
                         GestureDetector(
                           onTap: () {
                             setState(() => _isPublicPost = !_isPublicPost);
                           },
                           child: AnimatedContainer(
                             duration: const Duration(milliseconds: 220),
                             curve: Curves.easeOutCubic,
                             padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                             decoration: BoxDecoration(
                               color: _isPublicPost
                                   ? const Color(0xFF7B61FF).withValues(alpha: 0.18)
                                   : Colors.white.withValues(alpha: 0.06),
                               borderRadius: BorderRadius.circular(20),
                               border: Border.all(
                                 color: _isPublicPost
                                     ? const Color(0xFF7B61FF).withValues(alpha: 0.55)
                                     : Colors.white.withValues(alpha: 0.18),
                                 width: 1,
                               ),
                             ),
                             child: Row(
                               mainAxisSize: MainAxisSize.min,
                               children: [
                                 Icon(
                                   _isPublicPost ? Icons.public_rounded : Icons.lock_outline_rounded,
                                   color: _isPublicPost
                                       ? const Color(0xFF7B61FF)
                                       : Colors.white60,
                                   size: 15,
                                 ),
                                 const SizedBox(width: 5),
                                 Text(
                                   _isPublicPost ? 'Public' : 'Private',
                                   style: GoogleFonts.inter(
                                     color: _isPublicPost
                                         ? const Color(0xFF7B61FF)
                                         : Colors.white60,
                                     fontSize: 12,
                                     fontWeight: FontWeight.w600,
                                   ),
                                 ),
                               ],
                             ),
                           ),
                         ),
                      const SizedBox(width: 4),
                    ],
                  ),
                ),
              ],
            ),
          ),

          // ── Plus Menu floating widget ──────────────────────────────────
          if (_isPlusMenuOpen)
            Positioned(
              bottom: (MediaQuery.of(context).viewInsets.bottom > 0 ? MediaQuery.of(context).viewInsets.bottom + 12 : 24) + 60 + (_isFormattingToolOpen ? 50.0 : 0.0),
              right: 20,
              left: 20, // Make it span more width for the grid
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
