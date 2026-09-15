import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../providers/dialer_provider.dart';
import '../theme/miui_theme.dart';

class TextViewerScreen extends StatefulWidget {
  final String filePath;
  final String? initialContent;

  const TextViewerScreen({
    super.key,
    required this.filePath,
    this.initialContent,
  });

  @override
  State<TextViewerScreen> createState() => _TextViewerScreenState();
}

class _TextViewerScreenState extends State<TextViewerScreen> {
  String _content = '';
  bool _isLoading = true;
  String _fileSize = '';
  String _lastModified = '';
  int _lineCount = 0;

  @override
  void initState() {
    super.initState();
    _loadFile();
  }

  Future<void> _loadFile() async {
    if (widget.initialContent != null) {
      setState(() {
        _content = widget.initialContent!;
        _lineCount = _content.split('\n').length;
        _isLoading = false;
      });
      return;
    }

    try {
      final file = File(widget.filePath);
      if (await file.exists()) {
        final text = await file.readAsString();
        final stat = await file.stat();
        final sizeKb = (stat.size / 1024).toStringAsFixed(1);
        final dateStr = DateFormat('dd MMM yyyy, hh:mm a').format(stat.modified);

        setState(() {
          _content = text;
          _lineCount = text.split('\n').length;
          _fileSize = '$sizeKb KB';
          _lastModified = dateStr;
          _isLoading = false;
        });
      } else {
        setState(() {
          _content = 'File not found: ${widget.filePath}';
          _isLoading = false;
        });
      }
    } catch (e) {
      setState(() {
        _content = 'Error reading file: $e';
        _isLoading = false;
      });
    }
  }

  String get _fileName {
    return widget.filePath.split(Platform.pathSeparator).last;
  }

  void _copyToClipboard() {
    if (_content.isNotEmpty) {
      Clipboard.setData(ClipboardData(text: _content));
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Text copied to clipboard'),
          backgroundColor: const Color(0xFF1C1C1E),
          behavior: SnackBarBehavior.floating,
          duration: const Duration(seconds: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    }
  }

  void _openWithOtherApp() {
    final provider = Provider.of<DialerProvider>(context, listen: false);
    provider.openWithOtherApp(widget.filePath);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F1218),
      appBar: AppBar(
        backgroundColor: const Color(0xFF141A24),
        elevation: 0,
        scrolledUnderElevation: 0,
        leading: IconButton(
          icon: SvgPicture.asset(
            'resources/arrow-back.svg',
            width: 22,
            height: 22,
            colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          _fileName,
          style: const TextStyle(
            fontFamily: MiuiTheme.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: Colors.white,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        actions: [
          IconButton(
            tooltip: 'Copy all',
            icon: const Icon(Icons.copy_rounded, color: Colors.white, size: 20),
            onPressed: _copyToClipboard,
          ),
          IconButton(
            tooltip: 'Open with other app',
            icon: const Icon(Icons.open_in_new_rounded, color: Color(0xFF0C84FF), size: 20),
            onPressed: _openWithOtherApp,
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFF0C84FF)))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  if (_fileSize.isNotEmpty || _lastModified.isNotEmpty)
                    Container(
                      margin: const EdgeInsets.only(bottom: 16),
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.05),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
                      ),
                      child: Row(
                        children: [
                          if (_fileSize.isNotEmpty) ...[
                            Text(
                              _fileSize,
                              style: const TextStyle(
                                fontFamily: MiuiTheme.fontFamily,
                                fontSize: 12,
                                color: Color(0xFF8E8E93),
                              ),
                            ),
                            const Text(' • ', style: TextStyle(color: Color(0xFF8E8E93))),
                          ],
                          Text(
                            '$_lineCount lines',
                            style: const TextStyle(
                              fontFamily: MiuiTheme.fontFamily,
                              fontSize: 12,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                          if (_lastModified.isNotEmpty) ...[
                            const Spacer(),
                            Text(
                              _lastModified,
                              style: const TextStyle(
                                fontFamily: MiuiTheme.fontFamily,
                                fontSize: 11,
                                color: Color(0xFF8E8E93),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                  SelectableText(
                    _content,
                    style: const TextStyle(
                      fontFamily: MiuiTheme.fontFamily,
                      fontSize: 15,
                      height: 1.5,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}
