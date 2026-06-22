import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../utils/rich_text_controller.dart';

class ParsedTextWithCodeBlocks extends StatelessWidget {
  final String text;
  final List<RichStyle>? charStyles;
  final TextStyle defaultStyle;
  final int? maxLinesForText;
  final TextOverflow? overflowForText;
  final bool isPreviewMode;

  const ParsedTextWithCodeBlocks({
    super.key,
    required this.text,
    this.charStyles,
    required this.defaultStyle,
    this.maxLinesForText,
    this.overflowForText,
    this.isPreviewMode = false,
  });

  @override
  Widget build(BuildContext context) {
    if (!text.contains('```')) {
      return RichTextController.buildRichText(
        text,
        charStyles,
        defaultStyle: defaultStyle,
        maxLines: maxLinesForText,
        overflow: overflowForText,
      );
    }

    final List<Widget> children = [];
    int currentIndex = 0;
    
    while (true) {
      int startCode = text.indexOf('```', currentIndex);
      if (startCode == -1) {
        // No more code blocks, add remaining text
        if (currentIndex < text.length) {
          final String textChunk = text.substring(currentIndex);
          final List<RichStyle>? styleChunk = (charStyles != null && charStyles!.length == text.length)
              ? charStyles!.sublist(currentIndex)
              : null;
          
          if (textChunk.trim().isNotEmpty) {
            children.add(Padding(
              padding: const EdgeInsets.only(bottom: 8.0),
              child: RichTextController.buildRichText(
                textChunk,
                styleChunk,
                defaultStyle: defaultStyle,
                maxLines: maxLinesForText,
                overflow: overflowForText,
              ),
            ));
          }
        }
        break;
      }

      // Add text before code block
      if (startCode > currentIndex) {
        final String textChunk = text.substring(currentIndex, startCode);
        final List<RichStyle>? styleChunk = (charStyles != null && charStyles!.length == text.length)
            ? charStyles!.sublist(currentIndex, startCode)
            : null;
            
        if (textChunk.trim().isNotEmpty) {
          children.add(Padding(
            padding: const EdgeInsets.only(bottom: 8.0),
            child: RichTextController.buildRichText(
              textChunk,
              styleChunk,
              defaultStyle: defaultStyle,
              maxLines: maxLinesForText,
              overflow: overflowForText,
            ),
          ));
        }
      }

      // Find end of code block
      int endCode = text.indexOf('```', startCode + 3);
      String rawCode = endCode == -1 ? text.substring(startCode + 3) : text.substring(startCode + 3, endCode);

      // Extract language if present on the first line
      String codeContent = rawCode;
      String lang = 'Text';
      final firstLineEnd = rawCode.indexOf('\n');
      if (firstLineEnd != -1) {
        final firstLine = rawCode.substring(0, firstLineEnd).trim();
        // If the first line is short and has no spaces, treat it as language identifier
        if (firstLine.isNotEmpty && !firstLine.contains(' ') && firstLine.length < 15) {
          lang = firstLine;
          codeContent = rawCode.substring(firstLineEnd + 1);
        }
      }

      children.add(_CodeBlockCard(
        codeContent: codeContent,
        lang: lang,
        isPreviewMode: isPreviewMode,
      ));

      if (endCode == -1) {
        break;
      } else {
        currentIndex = endCode + 3;
      }
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: children,
    );
  }
}

class _CodeBlockCard extends StatefulWidget {
  final String codeContent;
  final String lang;
  final bool isPreviewMode;

  const _CodeBlockCard({
    required this.codeContent,
    this.lang = 'Text',
    this.isPreviewMode = false,
  });

  @override
  State<_CodeBlockCard> createState() => _CodeBlockCardState();
}

class _CodeBlockCardState extends State<_CodeBlockCard> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final String cleanCode = widget.codeContent.trim();
    if (cleanCode.isEmpty) return const SizedBox.shrink();

    // In preview mode (e.g. profile feed), limit size without toggle
    if (widget.isPreviewMode) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 8.0),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: const Color(0xFF1E1E1E),
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: const Color(0xFF2C2C2E)),
        ),
        child: Text(
          cleanCode,
          style: GoogleFonts.firaCode(
            color: const Color(0xFFD4D4D4),
            fontSize: 11,
            height: 1.5,
          ),
          maxLines: 5,
          overflow: TextOverflow.ellipsis,
        ),
      );
    }

    // Detailed mode (post details or save item preview)
    final bool isLong = '\n'.allMatches(cleanCode).length > 8 || cleanCode.length > 300;

    TextSpan highlightCode(String rawCode) {
      final keywords = RegExp(r'\b(class|import|void|final|const|return|if|else|var|let|function|def|int|double|String|bool|Map|List|static|override)\b');
      final comments = RegExp(r'(//.*|#.*)');
      final strings = RegExp(r'(\u0022[^\u0022]*\u0022|\u0027[^\u0027]*\u0027)');
      final htmlTags = RegExp(r'(<[^>]+>)');

      final List<TextSpan> spans = [];
      final lines = rawCode.split('\n');

      for (int i = 0; i < lines.length; i++) {
        final line = lines[i];
        int currentPos = 0;

        final List<RegExpMatch> matches = [];
        matches.addAll(keywords.allMatches(line));
        matches.addAll(comments.allMatches(line));
        matches.addAll(strings.allMatches(line));
        matches.addAll(htmlTags.allMatches(line));
        matches.sort((a, b) => a.start.compareTo(b.start));

        final List<RegExpMatch> cleanMatches = [];
        int lastEnd = 0;
        for (final match in matches) {
          if (match.start >= lastEnd) {
            cleanMatches.add(match);
            lastEnd = match.end;
          }
        }

        for (final match in cleanMatches) {
          if (match.start > currentPos) {
            spans.add(TextSpan(text: line.substring(currentPos, match.start), style: const TextStyle(color: Color(0xFFDCDCAA))));
          }

          final textMatch = line.substring(match.start, match.end);
          Color c = Colors.white;
          if (htmlTags.hasMatch(textMatch)) {
            c = const Color(0xFF569CD6);
          } else if (keywords.hasMatch(textMatch)) {
            c = const Color(0xFF569CD6);
          } else if (comments.hasMatch(textMatch)) {
            c = const Color(0xFF6A9955);
          } else if (strings.hasMatch(textMatch)) {
            c = const Color(0xFFCE9178);
          }
          spans.add(TextSpan(text: textMatch, style: TextStyle(color: c)));
          currentPos = match.end;
        }

        if (currentPos < line.length) {
          spans.add(TextSpan(text: line.substring(currentPos), style: const TextStyle(color: Color(0xFFDCDCAA))));
        }

        if (i < lines.length - 1) {
          spans.add(const TextSpan(text: '\n'));
        }
      }
      return TextSpan(children: spans);
    }

    final displayCode = _isExpanded ? cleanCode : (isLong ? cleanCode.split('\n').take(8).join('\n') + (cleanCode.split('\n').length > 8 ? '\n...' : '') : cleanCode);

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 12.0),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1E1E),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.only(left: 16.0, right: 16.0, top: 40.0, bottom: 16.0),
            child: SelectableText.rich(
              highlightCode(displayCode),
              style: GoogleFonts.firaCode(
                fontSize: 13,
                height: 1.5,
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: const Color(0xFF2C2C2E).withValues(alpha: 0.8),
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    widget.lang,
                    style: GoogleFonts.inter(
                      color: const Color(0xFF98989E),
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.keyboard_arrow_down, color: Color(0xFF98989E), size: 14),
                  const SizedBox(width: 8),
                  Container(width: 1, height: 12, color: const Color(0xFF48484A)),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: () {
                      // copy code
                    },
                    child: const Icon(Icons.copy_rounded, color: Color(0xFF98989E), size: 14),
                  ),
                  const SizedBox(width: 8),
                  const Icon(Icons.more_horiz, color: Color(0xFF98989E), size: 14),
                ],
              ),
            ),
          ),
          if (isLong)
            Positioned(
              bottom: 0,
              left: 0,
              right: 0,
              child: InkWell(
                onTap: () {
                  setState(() {
                    _isExpanded = !_isExpanded;
                  });
                },
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E).withValues(alpha: 0.9),
                    borderRadius: const BorderRadius.only(
                      bottomLeft: Radius.circular(8),
                      bottomRight: Radius.circular(8),
                    ),
                  ),
                  child: Center(
                    child: Text(
                      _isExpanded ? 'Show Less' : 'Show More',
                      style: GoogleFonts.inter(
                        color: Colors.white70,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
