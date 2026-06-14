import 'package:flutter/material.dart';

class RichStyle {
  final bool? bold;
  final bool? italic;
  final bool? underline;
  final bool? strikethrough;
  final String? weight; // 'light', 'regular', 'medium', 'semibold'
  final double? fontSize;
  final Color? color;
  final Color? highlightColor;

  const RichStyle({
    this.bold,
    this.italic,
    this.underline,
    this.strikethrough,
    this.weight,
    this.fontSize,
    this.color,
    this.highlightColor,
  });

  Map<String, dynamic> toJson() {
    return {
      'bold': bold,
      'italic': italic,
      'underline': underline,
      'strikethrough': strikethrough,
      'weight': weight,
      'fontSize': fontSize,
      'color': color?.value,
      'highlightColor': highlightColor?.value,
    };
  }

  factory RichStyle.fromJson(Map<String, dynamic> json) {
    return RichStyle(
      bold: json['bold'] as bool?,
      italic: json['italic'] as bool?,
      underline: json['underline'] as bool?,
      strikethrough: json['strikethrough'] as bool?,
      weight: json['weight'] as String?,
      fontSize: (json['fontSize'] as num?)?.toDouble(),
      color: json['color'] != null ? Color(json['color'] as int) : null,
      highlightColor: json['highlightColor'] != null ? Color(json['highlightColor'] as int) : null,
    );
  }

  RichStyle copyWith({
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    String? weight,
    double? fontSize,
    Color? color,
    Color? highlightColor,
    bool clearColor = false,
    bool clearHighlight = false,
  }) {
    return RichStyle(
      bold: bold ?? this.bold,
      italic: italic ?? this.italic,
      underline: underline ?? this.underline,
      strikethrough: strikethrough ?? this.strikethrough,
      weight: weight ?? this.weight,
      fontSize: fontSize ?? this.fontSize,
      color: clearColor ? null : (color ?? this.color),
      highlightColor: clearHighlight ? null : (highlightColor ?? this.highlightColor),
    );
  }
}

class RichTextController extends TextEditingController {
  /// Maps each index of the text to its corresponding RichStyle.
  final List<RichStyle> charStyles = [];

  /// Holds the style to apply to subsequent typing characters when selection is collapsed
  RichStyle? _typingStyle;

  /// Helper to check if a specific style check matches the last styled character
  RichStyle getActiveStyle([TextSelection? customSelection]) {
    if (_typingStyle != null) return _typingStyle!;
    if (text.isEmpty || charStyles.isEmpty) return const RichStyle();
    final selection = customSelection ?? this.selection;
    int index = selection.start;
    if (selection.isCollapsed) {
      index = selection.start - 1;
    }
    if (index < 0) index = 0;
    if (index >= charStyles.length) index = charStyles.length - 1;

    return charStyles[index];
  }

  bool _keepTypingStyle = false;

  /// Applies styling to the current selection range.
  void applyStyle({
    TextSelection? customSelection,
    bool? bold,
    bool? italic,
    bool? underline,
    bool? strikethrough,
    String? weight,
    double? fontSize,
    Color? color,
    Color? highlightColor,
    bool clearColor = false,
    bool clearHighlight = false,
  }) {
    final selection = customSelection ?? this.selection;
    if (selection.isCollapsed || selection.start < 0 || selection.end < 0) {
      _typingStyle = (_typingStyle ?? getActiveStyle()).copyWith(
        bold: bold,
        italic: italic,
        underline: underline,
        strikethrough: strikethrough,
        weight: weight,
        fontSize: fontSize,
        color: color,
        highlightColor: highlightColor,
        clearColor: clearColor,
        clearHighlight: clearHighlight,
      );
      _keepTypingStyle = true;
      notifyListeners();
      return;
    }

    // Ensure charStyles matches text length
    _syncCharStylesLength();

    for (int i = selection.start; i < selection.end; i++) {
      if (i >= 0 && i < charStyles.length) {
        charStyles[i] = charStyles[i].copyWith(
          bold: bold,
          italic: italic,
          underline: underline,
          strikethrough: strikethrough,
          weight: weight,
          fontSize: fontSize,
          color: color,
          highlightColor: highlightColor,
          clearColor: clearColor,
          clearHighlight: clearHighlight,
        );
      }
    }
    notifyListeners();
  }

  /// Formats the current selection as a list
  void toggleList(String listPrefix, [TextSelection? customSelection]) {
    final selection = customSelection ?? this.selection;
    final int start = selection.start;
    final int end = selection.end;
    if (start < 0) return;

    final String selectedText = text.substring(start, end);
    final String replacement = '\n$listPrefix$selectedText';
    
    final newText = text.replaceRange(start, end, replacement);
    text = newText;
    this.selection = TextSelection.collapsed(offset: start + replacement.length);
  }

  @override
  set value(TextEditingValue newValue) {
    final oldVal = value;
    final oldText = oldVal.text;
    final newText = newValue.text;

    if (oldText != newText) {
      _adjustCharStyles(oldText, newText, oldVal.selection, newValue.selection);
      _keepTypingStyle = false;
    } else if (oldVal.selection != newValue.selection) {
      if (!_keepTypingStyle) {
        _typingStyle = null;
      }
      _keepTypingStyle = false;
    }
    super.value = newValue;
  }

  void _syncCharStylesLength() {
    if (charStyles.length < text.length) {
      final diff = text.length - charStyles.length;
      final defaultStyle = charStyles.isNotEmpty ? charStyles.last : const RichStyle();
      charStyles.addAll(List<RichStyle>.filled(diff, defaultStyle));
    } else if (charStyles.length > text.length) {
      charStyles.removeRange(text.length, charStyles.length);
    }
  }

  void _adjustCharStyles(String oldText, String newText, TextSelection oldSel, TextSelection newSel) {
    if (newText.isEmpty) {
      charStyles.clear();
      _typingStyle = null;
      return;
    }

    // Adjust length of charStyles to match oldText first
    while (charStyles.length < oldText.length) {
      charStyles.add(const RichStyle());
    }
    if (charStyles.length > oldText.length) {
      charStyles.removeRange(oldText.length, charStyles.length);
    }

    // Find the prefix length that matches
    int prefixLen = 0;
    while (prefixLen < oldText.length && prefixLen < newText.length && oldText[prefixLen] == newText[prefixLen]) {
      prefixLen++;
    }

    // Find the suffix length that matches
    int suffixLen = 0;
    while (suffixLen < (oldText.length - prefixLen) &&
           suffixLen < (newText.length - prefixLen) &&
           oldText[oldText.length - 1 - suffixLen] == newText[newText.length - 1 - suffixLen]) {
      suffixLen++;
    }

    final int oldMiddleLen = oldText.length - prefixLen - suffixLen;
    final int newMiddleLen = newText.length - prefixLen - suffixLen;

    // Remove the styles that were in the deleted/replaced middle region
    if (oldMiddleLen > 0) {
      charStyles.removeRange(prefixLen, prefixLen + oldMiddleLen);
    }

    // Insert new styles for the inserted middle region, inheriting from the active style
    if (newMiddleLen > 0) {
      RichStyle insertionStyle = const RichStyle();
      if (_typingStyle != null) {
        insertionStyle = _typingStyle!;
      } else if (prefixLen > 0 && prefixLen - 1 < charStyles.length) {
        insertionStyle = charStyles[prefixLen - 1];
      } else if (charStyles.isNotEmpty) {
        insertionStyle = charStyles.first;
      }
      
      final newStyles = List<RichStyle>.filled(newMiddleLen, insertionStyle);
      charStyles.insertAll(prefixLen, newStyles);
    }

    // Final safety sync
    while (charStyles.length < newText.length) {
      charStyles.add(const RichStyle());
    }
    if (charStyles.length > newText.length) {
      charStyles.removeRange(newText.length, charStyles.length);
    }
  }

  List<bool> _getCodeBlockMask(String text) {
    final List<bool> mask = List<bool>.filled(text.length, false);
    int start = -1;
    while (true) {
      start = text.indexOf('```', start + 1);
      if (start == -1) break;
      int end = text.indexOf('```', start + 3);
      if (end == -1) {
        for (int i = start; i < text.length; i++) {
          mask[i] = true;
        }
        break;
      } else {
        for (int i = start; i <= end + 2; i++) {
          mask[i] = true;
        }
        start = end + 2;
      }
    }
    return mask;
  }

  @override
  TextSpan buildTextSpan({required BuildContext context, TextStyle? style, required bool withComposing}) {
    if (text.isEmpty) {
      return TextSpan(style: style, text: text);
    }

    _syncCharStylesLength();

    final codeMask = _getCodeBlockMask(text);

    final List<TextSpan> children = [];
    TextStyle? lastStyle;
    String currentChunk = "";

    for (int i = 0; i < text.length; i++) {
      final activeStyle = charStyles[i];

      FontWeight fw = FontWeight.normal;
      if (activeStyle.weight == 'light') fw = FontWeight.w300;
      if (activeStyle.weight == 'regular') fw = FontWeight.w400;
      if (activeStyle.weight == 'medium') fw = FontWeight.w500;
      if (activeStyle.weight == 'semibold') fw = FontWeight.w600;
      if (activeStyle.bold == true) fw = FontWeight.bold;

      final List<TextDecoration> decs = [];
      if (activeStyle.underline == true) decs.add(TextDecoration.underline);
      if (activeStyle.strikethrough == true) decs.add(TextDecoration.lineThrough);

      TextStyle charStyle = (style ?? const TextStyle()).copyWith(
        fontWeight: fw,
        fontStyle: activeStyle.italic == true ? FontStyle.italic : FontStyle.normal,
        decoration: decs.isEmpty ? TextDecoration.none : TextDecoration.combine(decs),
        fontSize: activeStyle.fontSize ?? style?.fontSize ?? 16.0,
        color: activeStyle.color ?? style?.color ?? Colors.white,
        backgroundColor: activeStyle.highlightColor ?? Colors.transparent,
      );

      if (codeMask[i]) {
        charStyle = charStyle.copyWith(
          fontFamily: 'Cascadia Code',
          color: const Color(0xFFB71C1C),
        );
      }

      if (lastStyle == null) {
        lastStyle = charStyle;
        currentChunk = text[i];
      } else if (_isSameStyle(lastStyle, charStyle)) {
        currentChunk += text[i];
      } else {
        children.add(TextSpan(text: currentChunk, style: lastStyle));
        lastStyle = charStyle;
        currentChunk = text[i];
      }
    }

    if (currentChunk.isNotEmpty && lastStyle != null) {
      children.add(TextSpan(text: currentChunk, style: lastStyle));
    }

    return TextSpan(style: style, children: children);
  }

  bool _isSameStyle(TextStyle s1, TextStyle s2) {
    return s1.fontWeight == s2.fontWeight &&
        s1.fontStyle == s2.fontStyle &&
        s1.decoration == s2.decoration &&
        s1.fontSize == s2.fontSize &&
        s1.color == s2.color &&
        s1.backgroundColor == s2.backgroundColor &&
        s1.fontFamily == s2.fontFamily;
  }

  /// Helper to build a RichText/TextSpan widget representing rich formatted text.
  static Widget buildRichText(
    String text,
    List<RichStyle>? charStyles, {
    required TextStyle defaultStyle,
    int? maxLines,
    TextOverflow? overflow,
  }) {
    final List<bool> codeMask = _getCodeBlockMaskStatic(text);

    if (charStyles == null || charStyles.isEmpty || charStyles.length != text.length) {
      final List<TextSpan> children = [];
      TextStyle? lastStyle;
      String currentChunk = "";

      for (int i = 0; i < text.length; i++) {
        TextStyle charStyle = defaultStyle;
        if (codeMask[i]) {
          charStyle = defaultStyle.copyWith(
            fontFamily: 'Cascadia Code',
            color: const Color(0xFFB71C1C),
          );
        }

        if (lastStyle == null) {
          lastStyle = charStyle;
          currentChunk = text[i];
        } else if (lastStyle.fontFamily == charStyle.fontFamily &&
                   lastStyle.color == charStyle.color) {
          currentChunk += text[i];
        } else {
          children.add(TextSpan(text: currentChunk, style: lastStyle));
          lastStyle = charStyle;
          currentChunk = text[i];
        }
      }
      if (currentChunk.isNotEmpty && lastStyle != null) {
        children.add(TextSpan(text: currentChunk, style: lastStyle));
      }

      return RichText(
        maxLines: maxLines,
        overflow: overflow ?? TextOverflow.clip,
        text: TextSpan(style: defaultStyle, children: children),
      );
    }

    final List<TextSpan> children = [];
    TextStyle? lastStyle;
    String currentChunk = "";

    for (int i = 0; i < text.length; i++) {
      final activeStyle = charStyles[i];

      FontWeight fw = defaultStyle.fontWeight ?? FontWeight.normal;
      if (activeStyle.weight == 'light') fw = FontWeight.w300;
      if (activeStyle.weight == 'regular') fw = FontWeight.w400;
      if (activeStyle.weight == 'medium') fw = FontWeight.w500;
      if (activeStyle.weight == 'semibold') fw = FontWeight.w600;
      if (activeStyle.bold == true) fw = FontWeight.bold;

      final List<TextDecoration> decs = [];
      if (activeStyle.underline == true) decs.add(TextDecoration.underline);
      if (activeStyle.strikethrough == true) decs.add(TextDecoration.lineThrough);

      TextStyle charStyle = defaultStyle.copyWith(
        fontWeight: fw,
        fontStyle: activeStyle.italic == true ? FontStyle.italic : FontStyle.normal,
        decoration: decs.isEmpty ? TextDecoration.none : TextDecoration.combine(decs),
        fontSize: activeStyle.fontSize ?? defaultStyle.fontSize,
        color: activeStyle.color ?? defaultStyle.color,
        backgroundColor: activeStyle.highlightColor ?? Colors.transparent,
      );

      if (codeMask[i]) {
        charStyle = charStyle.copyWith(
          fontFamily: 'Cascadia Code',
          color: const Color(0xFFB71C1C),
        );
      }

      if (lastStyle == null) {
        lastStyle = charStyle;
        currentChunk = text[i];
      } else if (lastStyle.fontWeight == charStyle.fontWeight &&
                 lastStyle.fontStyle == charStyle.fontStyle &&
                 lastStyle.decoration == charStyle.decoration &&
                 lastStyle.fontSize == charStyle.fontSize &&
                 lastStyle.color == charStyle.color &&
                 lastStyle.backgroundColor == charStyle.backgroundColor &&
                 lastStyle.fontFamily == charStyle.fontFamily) {
        currentChunk += text[i];
      } else {
        children.add(TextSpan(text: currentChunk, style: lastStyle));
        lastStyle = charStyle;
        currentChunk = text[i];
      }
    }

    if (currentChunk.isNotEmpty && lastStyle != null) {
      children.add(TextSpan(text: currentChunk, style: lastStyle));
    }

    return RichText(
      maxLines: maxLines,
      overflow: overflow ?? TextOverflow.clip,
      text: TextSpan(
        style: defaultStyle,
        children: children,
      ),
    );
  }

  static List<bool> _getCodeBlockMaskStatic(String text) {
    final List<bool> mask = List<bool>.filled(text.length, false);
    int start = -1;
    while (true) {
      start = text.indexOf('```', start + 1);
      if (start == -1) break;
      int end = text.indexOf('```', start + 3);
      if (end == -1) {
        for (int i = start; i < text.length; i++) {
          mask[i] = true;
        }
        break;
      } else {
        for (int i = start; i <= end + 2; i++) {
          mask[i] = true;
        }
        start = end + 2;
      }
    }
    return mask;
  }
}
