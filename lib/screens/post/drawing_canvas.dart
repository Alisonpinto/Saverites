import 'dart:io';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

enum DrawingTool { pencil, pen, brush, marker, highlighter, eraser }

class DrawingPath {
  final List<Offset> points;
  final Color color;
  final double width;
  final DrawingTool tool;

  DrawingPath({
    required this.points,
    required this.color,
    required this.width,
    required this.tool,
  });

  bool get isEraser => tool == DrawingTool.eraser;
  bool get isHighlighter => tool == DrawingTool.highlighter;
}

class DrawingCanvas extends StatefulWidget {
  final String? backgroundImagePath;

  const DrawingCanvas({super.key, this.backgroundImagePath});

  @override
  State<DrawingCanvas> createState() => _DrawingCanvasState();
}

class _DrawingCanvasState extends State<DrawingCanvas> {
  final List<DrawingPath> _paths = [];
  final List<DrawingPath> _redoPaths = [];
  DrawingPath? _currentPath;

  DrawingTool _selectedTool = DrawingTool.pen;
  Color _selectedColor = Colors.white;
  double _selectedWidth = 5.0;

  // Swatch colors
  final List<Color> _swatchColors = [
    Colors.white,
    Colors.black,
    const Color(0xFFFF453A), // Premium red
    const Color(0xFF0A84FF), // Premium blue
    const Color(0xFF30D158), // Premium green
    const Color(0xFFFFD60A), // Premium yellow
  ];

  @override
  void initState() {
    super.initState();
    _updateWidthForTool(_selectedTool);
  }

  void _updateWidthForTool(DrawingTool tool) {
    switch (tool) {
      case DrawingTool.pencil:
        _selectedWidth = 2.0;
        break;
      case DrawingTool.pen:
        _selectedWidth = 5.0;
        break;
      case DrawingTool.brush:
        _selectedWidth = 12.0;
        break;
      case DrawingTool.marker:
        _selectedWidth = 18.0;
        break;
      case DrawingTool.highlighter:
        _selectedWidth = 32.0;
        break;
      case DrawingTool.eraser:
        _selectedWidth = 24.0;
        break;
    }
  }

  void _undo() {
    if (_paths.isNotEmpty) {
      setState(() {
        _redoPaths.add(_paths.removeLast());
      });
    }
  }

  void _redo() {
    if (_redoPaths.isNotEmpty) {
      setState(() {
        _paths.add(_redoPaths.removeLast());
      });
    }
  }

  void _clear() {
    setState(() {
      _paths.clear();
      _redoPaths.clear();
      _currentPath = null;
    });
  }

  Future<void> _save() async {
    final String? path = await _saveDrawingToFile();
    if (mounted) {
      Navigator.pop(context, path);
    }
  }

  Future<String?> _saveDrawingToFile() async {
    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder);
    
    // Obtain screen size
    final Size size = MediaQuery.of(context).size;
    final double w = size.width;
    final double h = size.height;

    // 1. Draw solid background color (black if blank canvas, transparent/skip if overlaying on image)
    if (widget.backgroundImagePath == null) {
      canvas.drawColor(Colors.black, BlendMode.srcOver);
    } else {
      // Paint the background image scaled to fit the canvas
      try {
        final imageFile = File(widget.backgroundImagePath!);
        if (await imageFile.exists()) {
          final bytes = await imageFile.readAsBytes();
          final codec = await ui.instantiateImageCodec(bytes);
          final frame = await codec.getNextFrame();
          final ui.Image uiImage = frame.image;
          
          paintImage(
            canvas: canvas,
            rect: Rect.fromLTWH(0, 0, w, h),
            image: uiImage,
            fit: BoxFit.cover,
          );
        }
      } catch (e) {
        debugPrint("Error loading background image for rendering: $e");
      }
    }

    // 2. Paint drawing paths
    final painter = DrawingPainter(paths: _paths);
    painter.paint(canvas, size);

    // 3. Export to file
    final picture = recorder.endRecording();
    try {
      final img = await picture.toImage(w.toInt(), h.toInt());
      final pngBytes = await img.toByteData(format: ui.ImageByteFormat.png);
      if (pngBytes != null) {
        final tempDir = Directory.systemTemp;
        final file = File('${tempDir.path}/sketch_${DateTime.now().millisecondsSinceEpoch}.png');
        await file.writeAsBytes(pngBytes.buffer.asUint8List());
        return file.path;
      }
    } catch (e) {
      debugPrint("Error generating canvas image: $e");
    }
    return null;
  }

  void _showCustomColorPicker() {
    double hue = 0.0;
    Color pickedColor = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (BuildContext ctx) {
        return StatefulBuilder(
          builder: (BuildContext context, StateSetter setModalState) {
            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Text(
                      'Custom Color',
                      style: GoogleFonts.inter(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.w600,
                      ),
                      textAlign: TextAlign.center,
                    ),
                    const SizedBox(height: 24),
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          color: pickedColor,
                          shape: BoxShape.circle,
                          border: Border.all(color: Colors.white24, width: 2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Hue',
                      style: GoogleFonts.inter(color: Colors.white70, fontSize: 13),
                    ),
                    Slider(
                      value: hue,
                      min: 0.0,
                      max: 360.0,
                      onChanged: (val) {
                        setModalState(() {
                          hue = val;
                          pickedColor = HSVColor.fromAHSV(1.0, hue, 1.0, 1.0).toColor();
                        });
                      },
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: () {
                        setState(() {
                          _selectedColor = pickedColor;
                        });
                        Navigator.pop(ctx);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.white,
                        foregroundColor: Colors.black,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Text(
                        'Select',
                        style: GoogleFonts.inter(fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Stack(
          children: [
            // ── Background Canvas Area ─────────────────────────────────────────
            Positioned.fill(
              child: widget.backgroundImagePath != null
                  ? Image.file(
                      File(widget.backgroundImagePath!),
                      fit: BoxFit.cover,
                    )
                  : Container(color: Colors.black),
            ),

            // ── Gesture Drawer ────────────────────────────────────────────────
            Positioned.fill(
              child: GestureDetector(
                onPanStart: (details) {
                  setState(() {
                    _currentPath = DrawingPath(
                      points: [details.localPosition],
                      color: _selectedColor,
                      width: _selectedWidth,
                      tool: _selectedTool,
                    );
                    _paths.add(_currentPath!);
                    _redoPaths.clear();
                  });
                },
                onPanUpdate: (details) {
                  setState(() {
                    _currentPath?.points.add(details.localPosition);
                  });
                },
                onPanEnd: (details) {
                  _currentPath = null;
                },
                child: CustomPaint(
                  painter: DrawingPainter(paths: _paths),
                  size: Size.infinite,
                ),
              ),
            ),

            // ── Header controls (Undo, Redo, Clear, Back, Save) ────────────────
            Positioned(
              top: 10,
              left: 10,
              right: 10,
              child: Row(
                children: [
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close, color: Colors.white, size: 24),
                    splashRadius: 20,
                  ),
                  const Spacer(),
                  IconButton(
                    onPressed: _paths.isNotEmpty ? _undo : null,
                    icon: Icon(
                      Icons.undo,
                      color: _paths.isNotEmpty ? Colors.white : Colors.white24,
                      size: 22,
                    ),
                    splashRadius: 20,
                  ),
                  IconButton(
                    onPressed: _redoPaths.isNotEmpty ? _redo : null,
                    icon: Icon(
                      Icons.redo,
                      color: _redoPaths.isNotEmpty ? Colors.white : Colors.white24,
                      size: 22,
                    ),
                    splashRadius: 20,
                  ),
                  IconButton(
                    onPressed: _paths.isNotEmpty ? _clear : null,
                    icon: Icon(
                      Icons.delete_outline,
                      color: _paths.isNotEmpty ? Colors.white : Colors.white24,
                      size: 22,
                    ),
                    splashRadius: 20,
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton(
                    onPressed: _save,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.white,
                      foregroundColor: Colors.black,
                      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Save',
                      style: GoogleFonts.inter(fontSize: 13, fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
            ),

            // ── Bottom Tool panel (Brushes, colors, size) ─────────────────────
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Stroke width slider
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(20),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.line_weight, color: Colors.white70, size: 18),
                        Expanded(
                          child: Slider(
                            value: _selectedWidth,
                            min: 1.0,
                            max: 50.0,
                            activeColor: Colors.white,
                            inactiveColor: Colors.white24,
                            onChanged: (val) {
                              setState(() {
                                _selectedWidth = val;
                              });
                            },
                          ),
                        ),
                        Text(
                          '${_selectedWidth.toInt()}px',
                          style: GoogleFonts.inter(color: Colors.white70, fontSize: 12),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Colors Swatch and Picker
                  Container(
                    height: 52,
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    child: Row(
                      children: [
                        ..._swatchColors.map((color) {
                          final bool active = _selectedColor == color;
                          return Expanded(
                            child: GestureDetector(
                              onTap: () {
                                setState(() {
                                  _selectedColor = color;
                                });
                              },
                              child: Center(
                                child: Container(
                                  width: 28,
                                  height: 28,
                                  decoration: BoxDecoration(
                                    color: color,
                                    shape: BoxShape.circle,
                                    border: Border.all(
                                      color: active ? Colors.white : Colors.transparent,
                                      width: 2,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          );
                        }),
                        // Custom picker icon
                        Expanded(
                          child: IconButton(
                            onPressed: _showCustomColorPicker,
                            icon: const Icon(Icons.color_lens_outlined, color: Colors.white, size: 24),
                            splashRadius: 20,
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 10),

                  // Tool Select Row
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.black87,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 12),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceAround,
                      children: [
                        _buildToolButton(DrawingTool.pencil, Icons.edit_outlined, 'Pencil'),
                        _buildToolButton(DrawingTool.pen, Icons.mode_edit, 'Pen'),
                        _buildToolButton(DrawingTool.brush, Icons.brush, 'Brush'),
                        _buildToolButton(DrawingTool.marker, Icons.border_color_outlined, 'Marker'),
                        _buildToolButton(DrawingTool.highlighter, Icons.highlight_alt, 'Highlight'),
                        _buildToolButton(DrawingTool.eraser, Icons.cleaning_services_outlined, 'Eraser'),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildToolButton(DrawingTool tool, IconData icon, String label) {
    final bool active = _selectedTool == tool;
    return GestureDetector(
      onTap: () {
        setState(() {
          _selectedTool = tool;
          _updateWidthForTool(tool);
        });
      },
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            color: active ? const Color(0xFF0A84FF) : Colors.white54,
            size: 22,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: GoogleFonts.inter(
              color: active ? const Color(0xFF0A84FF) : Colors.white30,
              fontSize: 9,
              fontWeight: FontWeight.w400,
            ),
          ),
        ],
      ),
    );
  }
}

class DrawingPainter extends CustomPainter {
  final List<DrawingPath> paths;

  DrawingPainter({required this.paths});

  @override
  void paint(Canvas canvas, Size size) {
    // Save layer to process eraser blend mode properly
    canvas.saveLayer(Rect.fromLTWH(0, 0, size.width, size.height), Paint());

    for (final path in paths) {
      if (path.points.length < 2) continue;

      final paint = Paint()
        ..color = path.isEraser
            ? Colors.transparent
            : (path.isHighlighter ? path.color.withValues(alpha: 0.4) : path.color)
        ..strokeWidth = path.width
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..style = PaintingStyle.stroke;

      if (path.isEraser) {
        paint.blendMode = BlendMode.clear;
      } else {
        paint.blendMode = BlendMode.srcOver;
      }

      final drawPath = Path();
      drawPath.moveTo(path.points.first.dx, path.points.first.dy);
      for (int i = 1; i < path.points.length; i++) {
        drawPath.lineTo(path.points[i].dx, path.points[i].dy);
      }

      canvas.drawPath(drawPath, paint);
    }

    canvas.restore();
  }

  @override
  bool shouldRepaint(covariant DrawingPainter oldDelegate) => true;
}
