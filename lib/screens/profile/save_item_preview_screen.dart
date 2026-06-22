import 'dart:io';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:syncfusion_flutter_pdfviewer/pdfviewer.dart';
import '../../utils/post_store.dart';
import '../../widgets/running_video_player.dart';
import '../post_detail/post_detail_screen.dart';
import '../../widgets/parsed_text_with_code_blocks.dart';

class SaveItemPreviewScreen extends StatelessWidget {
  final UserPost post;

  const SaveItemPreviewScreen({super.key, required this.post});

  String _formatDate(DateTime dt) {
    return '${dt.day}-${dt.month.toString().padLeft(2, '0')}-${dt.year}';
  }

  Widget _buildContent(BuildContext context, String resolvedType) {
    switch (resolvedType) {
      case 'image':
        final path = post.imagePath;
        if (path != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: Image.file(
              File(path),
              width: double.infinity,
              fit: BoxFit.cover,
            ),
          );
        }
        break;
      case 'video':
        final path = post.videoPath;
        if (path != null) {
          return ClipRRect(
            borderRadius: BorderRadius.circular(12),
            child: RunningVideoPlayer(file: File(path)),
          );
        }
        break;
      case 'document':
        final paths = post.filePaths ?? (post.filePath != null ? [post.filePath!] : []);
        if (paths.isNotEmpty) {
          return Column(
            children: paths.map((path) {
              final name = path.split('/').last.split('\\').last;
              if (name.toLowerCase().endsWith('.pdf') && File(path).existsSync()) {
                return Container(
                  height: MediaQuery.of(context).size.height * 0.65,
                  margin: const EdgeInsets.only(bottom: 24),
                  decoration: BoxDecoration(
                    color: const Color(0xFF1C1C1E),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: const Color(0xFF2C2C2E)),
                  ),
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: SfPdfViewer.file(File(path)),
                  ),
                );
              }
              return Container(
                padding: const EdgeInsets.all(20),
                margin: const EdgeInsets.only(bottom: 24),
                decoration: BoxDecoration(
                  color: const Color(0xFF1C1C1E),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: const Color(0xFF2C2C2E)),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.description_outlined, color: Colors.blue, size: 40),
                    const SizedBox(width: 16),
                    Expanded(
                      child: Text(
                        name,
                        style: GoogleFonts.inter(
                          color: Colors.white,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          );
        }
        return const SizedBox.shrink();
      case 'contact':
        if (post.contactNames != null && post.contactNames!.isNotEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2C2C2E)),
            ),
            child: Column(
              children: List.generate(post.contactNames!.length, (index) {
                final cName = post.contactNames![index];
                final cPhone = (post.contactPhones != null && post.contactPhones!.length > index) 
                    ? post.contactPhones![index] 
                    : 'No Phone Number';
                return Padding(
                  padding: EdgeInsets.only(bottom: index == post.contactNames!.length - 1 ? 0 : 24),
                  child: Column(
                    children: [
                      CircleAvatar(
                        radius: 40,
                        backgroundColor: const Color(0xFF2C2C2E),
                        child: Text(
                          cName.isNotEmpty ? cName[0].toUpperCase() : '?',
                          style: GoogleFonts.inter(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                        ),
                      ),
                      const SizedBox(height: 16),
                      Text(
                        cName.isEmpty ? 'Unknown Contact' : cName,
                        style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        cPhone,
                        style: GoogleFonts.inter(color: const Color(0xFFAEAEB2), fontSize: 16),
                      ),
                    ],
                  ),
                );
              }),
            ),
          );
        }
        return Container(
          width: double.infinity,
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2C2C2E)),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 40,
                backgroundColor: const Color(0xFF2C2C2E),
                child: Text(
                  post.contactName?.isNotEmpty == true ? post.contactName![0].toUpperCase() : '?',
                  style: GoogleFonts.inter(color: Colors.white, fontSize: 32, fontWeight: FontWeight.bold),
                ),
              ),
              const SizedBox(height: 16),
              Text(
                post.contactName ?? 'Unknown Contact',
                style: GoogleFonts.inter(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 8),
              Text(
                post.contactPhone ?? 'No Phone Number',
                style: GoogleFonts.inter(color: const Color(0xFFAEAEB2), fontSize: 16),
              ),
            ],
          ),
        );
      case 'audio':
        return AudioPlayerBlock(
          durationText: post.duration ?? '0:00',
          filePath: post.filePath,
        );
      case 'checklist':
        if (post.checklistItems != null && post.checklistItems!.isNotEmpty) {
          return Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1C1C1E),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFF2C2C2E)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: List.generate(post.checklistItems!.length, (index) {
                final text = post.checklistItems![index];
                final isChecked = post.checklistStates != null && post.checklistStates!.length > index ? post.checklistStates![index] : false;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        decoration: BoxDecoration(
                          color: isChecked 
                            ? const Color(0xFF4255FF) 
                            : Colors.transparent,
                          borderRadius: BorderRadius.circular(6),
                          border: Border.all(
                            color: isChecked 
                              ? Colors.transparent 
                              : const Color(0xFFC7C7CC), 
                            width: 2.0
                          ),
                        ),
                        child: isChecked 
                          ? const Icon(Icons.check, color: Colors.white, size: 16) 
                          : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          text,
                          style: GoogleFonts.inter(
                            color: isChecked ? const Color(0xFF7C7C81) : Colors.white,
                            fontSize: 15,
                            decoration: isChecked ? TextDecoration.lineThrough : null,
                          ),
                        ),
                      ),
                    ],
                  ),
                );
              }),
            ),
          );
        }
        break;
      case 'code':
        return ParsedTextWithCodeBlocks(
          text: post.body,
          charStyles: post.charStyles,
          defaultStyle: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 16,
            height: 1.5,
          ),
        );
      case 'link':
        return Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: const Color(0xFF1C1C1E),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: const Color(0xFF2C2C2E)),
          ),
          child: Row(
            children: [
              const Icon(Icons.link_rounded, color: Colors.blueAccent, size: 28),
              const SizedBox(width: 16),
              Expanded(
                child: Text(
                  post.url ?? post.body,
                  style: GoogleFonts.inter(
                    color: Colors.blueAccent,
                    fontSize: 15,
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        );
    }
    
    // Fallback or pure text
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: const Color(0xFF1C1C1E),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFF2C2C2E)),
      ),
      child: ParsedTextWithCodeBlocks(
        text: post.body,
        charStyles: post.charStyles,
        defaultStyle: GoogleFonts.inter(
          color: Colors.white,
          fontSize: 16,
          height: 1.5,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final String resolvedType = post.type ?? (
      post.imagePath != null ? 'image' : (
      post.videoPath != null ? 'video' : (
      post.url != null ? 'link' : (
      (post.checklistItems?.isNotEmpty ?? false) ? 'checklist' : 'text'
    ))));

    return Scaffold(
      backgroundColor: const Color(0xFF121212),
      appBar: AppBar(
        backgroundColor: const Color(0xFF121212),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded, color: Colors.white, size: 20),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Preview',
          style: GoogleFonts.inter(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              post.title,
              style: GoogleFonts.inter(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              _formatDate(post.createdAt),
              style: GoogleFonts.inter(
                color: const Color(0xFF7C7C81),
                fontSize: 14,
              ),
            ),
            const SizedBox(height: 24),
            
            _buildContent(context, resolvedType),
            
            const SizedBox(height: 24),
            
            if (resolvedType != 'text' && resolvedType != 'code' && post.body.trim().isNotEmpty) ...[
              Text(
                post.body,
                style: GoogleFonts.inter(
                  color: const Color(0xFFE5E5EA),
                  fontSize: 15,
                  height: 1.5,
                ),
              ),
            ],
            
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}
