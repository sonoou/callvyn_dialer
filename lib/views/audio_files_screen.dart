import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:provider/provider.dart';

import '../providers/dialer_provider.dart';
import '../theme/miui_theme.dart';

enum AudioSortOption {
  name,
  biggerToSmaller,
  smallerToBigger,
  type,
  modificationTime,
}

class AudioFilesScreen extends StatefulWidget {
  final String? contactId;
  final String? phoneNumber;

  const AudioFilesScreen({
    super.key,
    this.contactId,
    this.phoneNumber,
  });

  @override
  State<AudioFilesScreen> createState() => _AudioFilesScreenState();
}

class _AudioFilesScreenState extends State<AudioFilesScreen> {
  bool _isLoading = true;
  List<Map<String, dynamic>> _audioFiles = [];
  Map<String, dynamic>? _selectedFile;
  AudioSortOption _sortOption = AudioSortOption.modificationTime;

  @override
  void initState() {
    super.initState();
    _loadAudioFiles();
  }

  @override
  void dispose() {
    // Stop preview on exit
    final provider = Provider.of<DialerProvider>(context, listen: false);
    provider.stopPreview();
    super.dispose();
  }

  Future<void> _loadAudioFiles() async {
    setState(() => _isLoading = true);
    final provider = Provider.of<DialerProvider>(context, listen: false);

    // Request storage / media permissions
    if (Platform.isAndroid) {
      await [
        Permission.audio,
        Permission.storage,
      ].request();
    }

    final rawFiles = await provider.fetchDeviceAudioFiles();
    _audioFiles = List<Map<String, dynamic>>.from(rawFiles);
    _applySort();
    if (mounted) {
      setState(() => _isLoading = false);
    }
  }

  void _applySort() {
    switch (_sortOption) {
      case AudioSortOption.name:
        _audioFiles.sort((a, b) => (a['name'] ?? '').toString().toLowerCase().compareTo((b['name'] ?? '').toString().toLowerCase()));
        break;
      case AudioSortOption.biggerToSmaller:
        _audioFiles.sort((a, b) => ((b['size'] as num?) ?? 0).compareTo((a['size'] as num?) ?? 0));
        break;
      case AudioSortOption.smallerToBigger:
        _audioFiles.sort((a, b) => ((a['size'] as num?) ?? 0).compareTo((b['size'] as num?) ?? 0));
        break;
      case AudioSortOption.type:
        _audioFiles.sort((a, b) {
          final extA = (a['name'] ?? '').toString().split('.').last.toLowerCase();
          final extB = (b['name'] ?? '').toString().split('.').last.toLowerCase();
          return extA.compareTo(extB);
        });
        break;
      case AudioSortOption.modificationTime:
        _audioFiles.sort((a, b) => ((b['dateModified'] as num?) ?? 0).compareTo((a['dateModified'] as num?) ?? 0));
        break;
    }
  }

  String _formatFileSize(dynamic rawSize) {
    final size = (rawSize as num?)?.toDouble() ?? 0.0;
    if (size >= 1024 * 1024) {
      return '${(size / (1024 * 1024)).toStringAsFixed(2)}MB';
    } else {
      return '${(size / 1024).toStringAsFixed(2)}KB';
    }
  }

  String _formatDate(dynamic timestamp) {
    if (timestamp == null) return '';
    final num val = timestamp as num;
    final dt = val > 100000000000 ? DateTime.fromMillisecondsSinceEpoch(val.toInt()) : DateTime.fromMillisecondsSinceEpoch((val * 1000).toInt());
    return DateFormat('dd/MM/yy h:mm a').format(dt);
  }

  void _showMoreMenu(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    _showSortByDialog(context);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: const Text(
                      'Sort by',
                      style: TextStyle(
                        fontFamily: MiuiTheme.fontFamily,
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ),
                Container(height: 0.6, color: const Color(0xFF2C2C2E)),
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    _loadAudioFiles();
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: const Text(
                      'Refresh',
                      style: TextStyle(
                        fontFamily: MiuiTheme.fontFamily,
                        fontSize: 16,
                        color: Colors.white,
                        fontWeight: FontWeight.normal,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showSortByDialog(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            final options = [
              {'option': AudioSortOption.name, 'label': 'Name'},
              {'option': AudioSortOption.biggerToSmaller, 'label': 'Bigger to smaller'},
              {'option': AudioSortOption.smallerToBigger, 'label': 'Smaller to bigger'},
              {'option': AudioSortOption.type, 'label': 'Type'},
              {'option': AudioSortOption.modificationTime, 'label': 'Modification time'},
            ];

            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF2C2C2E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 28),
              child: SafeArea(
                top: false,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Center(
                      child: Text(
                        'Sort by',
                        style: TextStyle(
                          fontFamily: MiuiTheme.fontFamily,
                          fontSize: 18,
                          fontWeight: FontWeight.w600,
                          color: Colors.white,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),
                    ...options.map((opt) {
                      final isSelected = _sortOption == opt['option'];
                      return InkWell(
                        onTap: () {
                          setState(() {
                            _sortOption = opt['option'] as AudioSortOption;
                            _applySort();
                          });
                          Navigator.pop(ctx);
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 13),
                          child: Row(
                            children: [
                              if (isSelected) ...[
                                SvgPicture.asset(
                                  'resources/right-arrow.svg',
                                  width: 18,
                                  height: 18,
                                  colorFilter: const ColorFilter.mode(
                                    Color(0xFF0C84FF),
                                    BlendMode.srcIn,
                                  ),
                                ),
                                const SizedBox(width: 8),
                              ] else
                                const SizedBox(width: 26),
                              Text(
                                opt['label'] as String,
                                style: TextStyle(
                                  fontFamily: MiuiTheme.fontFamily,
                                  fontSize: 16,
                                  fontWeight: FontWeight.normal,
                                  color: isSelected ? const Color(0xFF0C84FF) : Colors.white,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _onOkPressed() async {
    if (_selectedFile == null) return;
    final provider = Provider.of<DialerProvider>(context, listen: false);

    final String name = _selectedFile!['name'] ?? 'Custom Ringtone';
    final String path = _selectedFile!['path'] ?? '';
    final rawDur = _selectedFile!['durationMs'] as num? ?? 0;
    final mins = (rawDur ~/ 60000);
    final secs = ((rawDur % 60000) ~/ 1000);
    final durStr = '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';

    final myRingtoneItem = {
      'title': name,
      'path': path,
      'uri': path,
      'size': _selectedFile!['size'],
      'duration': durStr,
      'dateModified': _selectedFile!['dateModified'],
    };

    await provider.addMyRingtone(myRingtoneItem);
    await provider.setContactRingtone(
      contactId: widget.contactId,
      phoneNumber: widget.phoneNumber,
      title: name,
      uriOrPath: path,
    );

    if (mounted) {
      Navigator.pop(context, myRingtoneItem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DialerProvider>(context);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // -------------------------------------------------------------
            // TOPBAR (Sticky no scroll effect)
            // -------------------------------------------------------------
            Container(
              height: 54,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: Row(
                children: [
                  GestureDetector(
                    onTap: () => Navigator.pop(context),
                    child: SvgPicture.asset(
                      'resources/arrow-back.svg',
                      width: 24,
                      height: 24,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'Audio files',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: MiuiTheme.fontFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.normal,
                        color: Colors.white,
                      ),
                    ),
                  ),
                  const SizedBox(width: 24), // Balance back icon
                ],
              ),
            ),

            // 1st row: Left edge to right edge separator complete
            Container(
              height: 0.6,
              color: const Color(0xFF2C2C2E),
            ),

            // -------------------------------------------------------------
            // BODY (2nd row: Empty state / 3rd row: List of audio files)
            // -------------------------------------------------------------
            Expanded(
              child: _isLoading
                  ? const Center(
                      child: CircularProgressIndicator(color: Color(0xFF0C84FF)),
                    )
                  : _audioFiles.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              SvgPicture.asset(
                                'resources/music.svg',
                                width: 56,
                                height: 56,
                                colorFilter: const ColorFilter.mode(
                                  Color(0xFF8E8E93),
                                  BlendMode.srcIn,
                                ),
                              ),
                              const SizedBox(height: 14),
                              const Text(
                                'No audio files',
                                style: TextStyle(
                                  fontFamily: MiuiTheme.fontFamily,
                                  fontSize: 16,
                                  color: Color(0xFF8E8E93),
                                  fontWeight: FontWeight.normal,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.separated(
                          physics: const BouncingScrollPhysics(),
                          itemCount: _audioFiles.length,
                          separatorBuilder: (ctx, i) => Container(
                            margin: const EdgeInsets.only(left: 64),
                            height: 0.5,
                            color: const Color(0xFF2C2C2E),
                          ),
                          itemBuilder: (context, index) {
                            final file = _audioFiles[index];
                            final isSelected = _selectedFile?['path'] == file['path'];
                            final fileName = file['name'] ?? 'Audio file';
                            final fileSizeStr = _formatFileSize(file['size']);
                            final dateStr = _formatDate(file['dateModified']);

                            return InkWell(
                              onTap: () {
                                setState(() {
                                  _selectedFile = file;
                                });
                                final path = file['path']?.toString() ?? '';
                                if (path.isNotEmpty) {
                                  provider.playPreview(path);
                                }
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                child: Row(
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // 1st col: music.svg (color green)
                                    Container(
                                      width: 40,
                                      height: 40,
                                      decoration: const BoxDecoration(
                                        shape: BoxShape.circle,
                                        color: Color(0xFF1E2822),
                                      ),
                                      alignment: Alignment.center,
                                      child: SvgPicture.asset(
                                        'resources/music.svg',
                                        width: 22,
                                        height: 22,
                                        colorFilter: const ColorFilter.mode(
                                          Color(0xFF25D366),
                                          BlendMode.srcIn,
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 14),

                                    // 2nd col: File name (1st row), File size | Date (2nd row)
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment: CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            fileName,
                                            maxLines: 1,
                                            overflow: TextOverflow.ellipsis,
                                            style: const TextStyle(
                                              fontFamily: MiuiTheme.fontFamily,
                                              fontSize: 16,
                                              fontWeight: FontWeight.normal,
                                              color: Colors.white,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '$fileSizeStr | $dateStr',
                                            style: const TextStyle(
                                              fontFamily: MiuiTheme.fontFamily,
                                              fontSize: 12,
                                              color: Color(0xFF8E8E93),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    const SizedBox(width: 12),

                                    // 3rd col: Selection indicator
                                    if (isSelected)
                                      Image.asset(
                                        'resources/bh_ic_pay_checked.png',
                                        width: 22,
                                        height: 22,
                                      )
                                    else
                                      Container(
                                        width: 22,
                                        height: 22,
                                        decoration: BoxDecoration(
                                          shape: BoxShape.circle,
                                          border: Border.all(
                                            color: const Color(0xFF8E8E93),
                                            width: 1.2,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
            ),

            // -------------------------------------------------------------
            // BOTTOM BAR
            // -------------------------------------------------------------
            Container(
              height: 0.6,
              color: const Color(0xFF2C2C2E),
            ),
            Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceAround,
                children: [
                  // 1st col: OK
                  InkWell(
                    onTap: _selectedFile != null ? _onOkPressed : null,
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'resources/checkmark.svg',
                            width: 22,
                            height: 22,
                            colorFilter: ColorFilter.mode(
                              _selectedFile != null ? const Color(0xFF0C84FF) : const Color(0xFF8E8E93),
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'OK',
                            style: TextStyle(
                              fontFamily: MiuiTheme.fontFamily,
                              fontSize: 12,
                              color: _selectedFile != null ? const Color(0xFF0C84FF) : const Color(0xFF8E8E93),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 2nd col: Cancel
                  InkWell(
                    onTap: () => Navigator.pop(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'resources/cross-thin.svg',
                            width: 22,
                            height: 22,
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Cancel',
                            style: TextStyle(
                              fontFamily: MiuiTheme.fontFamily,
                              fontSize: 12,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3rd col: More
                  InkWell(
                    onTap: () => _showMoreMenu(context),
                    borderRadius: BorderRadius.circular(12),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SvgPicture.asset(
                            'resources/circle-dots-horizontal.svg',
                            width: 22,
                            height: 22,
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'More',
                            style: TextStyle(
                              fontFamily: MiuiTheme.fontFamily,
                              fontSize: 12,
                              color: Colors.white,
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
    );
  }
}
