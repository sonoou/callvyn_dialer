import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../providers/dialer_provider.dart';
import '../theme/miui_theme.dart';
import 'audio_files_screen.dart';

class RingtoneScreen extends StatefulWidget {
  final String? contactId;
  final String? phoneNumber;
  final String? contactName;

  const RingtoneScreen({
    super.key,
    this.contactId,
    this.phoneNumber,
    this.contactName,
  });

  @override
  State<RingtoneScreen> createState() => _RingtoneScreenState();
}

class _RingtoneScreenState extends State<RingtoneScreen> with SingleTickerProviderStateMixin {
  List<Map<String, dynamic>> _systemRingtones = [];
  bool _isLoadingSystem = true;
  String _searchQuery = '';
  bool _isSearchOpen = false;
  final TextEditingController _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    _loadSystemRingtones();
  }

  @override
  void dispose() {
    _searchController.dispose();
    final provider = Provider.of<DialerProvider>(context, listen: false);
    provider.stopPreview();
    super.dispose();
  }

  Future<void> _loadSystemRingtones() async {
    final provider = Provider.of<DialerProvider>(context, listen: false);
    final list = await provider.fetchSystemRingtones();
    if (mounted) {
      setState(() {
        _systemRingtones = list;
        _isLoadingSystem = false;
      });
    }
  }

  void _openLocalAudioFilesScreen() async {
    final provider = Provider.of<DialerProvider>(context, listen: false);
    provider.stopPreview();

    final result = await Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => AudioFilesScreen(
          contactId: widget.contactId,
          phoneNumber: widget.phoneNumber,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0); // Right to left shutter
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );

    if (result != null && mounted) {
      setState(() {});
    }
  }

  void _showApplyConfirmationDialog({
    required String title,
    required String uriOrPath,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF242832),
            borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(24, 24, 24, 32),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Select tone',
                  style: TextStyle(
                    fontFamily: MiuiTheme.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Select this ringtone?',
                  style: TextStyle(
                    fontFamily: MiuiTheme.fontFamily,
                    fontSize: 15,
                    fontWeight: FontWeight.normal,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                const SizedBox(height: 28),
                Row(
                  children: [
                    // Cancel button (transparent grey capsule)
                    Expanded(
                      child: GestureDetector(
                        onTap: () => Navigator.pop(ctx),
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontFamily: MiuiTheme.fontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.normal,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    // OK button (blue capsule)
                    Expanded(
                      child: GestureDetector(
                        onTap: () async {
                          final provider = Provider.of<DialerProvider>(context, listen: false);
                          await provider.setContactRingtone(
                            contactId: widget.contactId,
                            phoneNumber: widget.phoneNumber,
                            title: title,
                            uriOrPath: uriOrPath,
                          );
                          provider.stopPreview();
                          if (ctx.mounted) {
                            Navigator.pop(ctx);
                          }
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Ringtone set to $title'),
                                duration: const Duration(seconds: 2),
                                backgroundColor: const Color(0xFF2C2C2E),
                              ),
                            );
                            setState(() {});
                          }
                        },
                        child: Container(
                          height: 46,
                          decoration: BoxDecoration(
                            color: const Color(0xFF0C84FF),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'OK',
                            style: TextStyle(
                              fontFamily: MiuiTheme.fontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildRingtoneRow({
    required String title,
    required String uriOrPath,
    String? duration,
    required bool isSelected,
    required bool isPlaying,
    required VoidCallback onPlayToggle,
    required VoidCallback onApply,
  }) {
    return InkWell(
      onTap: onPlayToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            // 1st col: Title, Duration / Selection Badge
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      if (isPlaying) ...[
                        const AudioPulseVisualizer(),
                        const SizedBox(width: 8),
                      ],
                      Expanded(
                        child: Text(
                          title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontFamily: MiuiTheme.fontFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.normal,
                            color: isPlaying ? const Color(0xFF0C84FF) : Colors.white,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      if (duration != null && duration.isNotEmpty) ...[
                        Text(
                          duration,
                          style: const TextStyle(
                            fontFamily: MiuiTheme.fontFamily,
                            fontSize: 12,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                        if (isSelected) const SizedBox(width: 6),
                      ],
                      if (isSelected)
                        Container(
                          width: 14,
                          height: 14,
                          decoration: const BoxDecoration(
                            shape: BoxShape.circle,
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Image.asset(
                            'resources/ic_launcher_phone.webp',
                            fit: BoxFit.cover,
                          ),
                        ),
                    ],
                  ),
                ],
              ),
            ),

            const SizedBox(width: 12),

            // 2nd col: Apply button (capsule with transparent blue background)
            GestureDetector(
              onTap: onApply,
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                decoration: BoxDecoration(
                  color: const Color(0x260C84FF),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: const Text(
                  'Apply',
                  style: TextStyle(
                    fontFamily: MiuiTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                    color: Color(0xFF0C84FF),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DialerProvider>(context);

    final currentSelectedTitle = provider.getContactRingtoneTitle(
          widget.contactId,
          widget.phoneNumber,
        ) ??
        'Default ringtone';

    final isDefaultSelected = currentSelectedTitle == 'Default ringtone';

    // Filter lists by search query if any
    final query = _searchQuery.trim().toLowerCase();
    final myRingtones = query.isEmpty
        ? provider.myRingtones
        : provider.myRingtones
            .where((r) => (r['title'] ?? '').toString().toLowerCase().contains(query))
            .toList();

    final systemRingtones = query.isEmpty
        ? _systemRingtones
        : _systemRingtones
            .where((r) => (r['title'] ?? '').toString().toLowerCase().contains(query))
            .toList();

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // -------------------------------------------------------------
            // TOPBAR (Sticky no scroll effect)
            // -------------------------------------------------------------
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: _isSearchOpen
                  ? Row(
                      children: [
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isSearchOpen = false;
                              _searchQuery = '';
                              _searchController.clear();
                            });
                          },
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
                        const SizedBox(width: 12),
                        Expanded(
                          child: TextField(
                            controller: _searchController,
                            autofocus: true,
                            style: const TextStyle(
                              fontFamily: MiuiTheme.fontFamily,
                              fontSize: 16,
                              color: Colors.white,
                            ),
                            decoration: const InputDecoration(
                              hintText: 'Search ringtones',
                              hintStyle: TextStyle(
                                fontFamily: MiuiTheme.fontFamily,
                                color: Color(0xFF8E8E93),
                              ),
                              border: InputBorder.none,
                            ),
                            onChanged: (val) {
                              setState(() {
                                _searchQuery = val;
                              });
                            },
                          ),
                        ),
                        if (_searchQuery.isNotEmpty)
                          GestureDetector(
                            onTap: () {
                              setState(() {
                                _searchQuery = '';
                                _searchController.clear();
                              });
                            },
                            child: const Icon(Icons.clear, color: Colors.white, size: 20),
                          ),
                      ],
                    )
                  : Row(
                      children: [
                        // 1st column: arrow-back.svg
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
                        // 2nd column: "Ringtone" (Center aligned)
                        const Expanded(
                          child: Text(
                            'Ringtone',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontFamily: MiuiTheme.fontFamily,
                              fontSize: 18,
                              fontWeight: FontWeight.normal,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        // 3rd column: search.svg (Right aligned)
                        GestureDetector(
                          onTap: () {
                            setState(() {
                              _isSearchOpen = true;
                            });
                          },
                          child: SvgPicture.asset(
                            'resources/search.svg',
                            width: 22,
                            height: 22,
                            colorFilter: const ColorFilter.mode(
                              Colors.white,
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ],
                    ),
            ),

            // Scrollable Ringtone Content
            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (!_isSearchOpen) ...[
                      // -------------------------------------------------------------
                      // 1ST ROW: "Choose online ringtone" + right-arrow.svg
                      // -------------------------------------------------------------
                      InkWell(
                        onTap: () {
                          // Currently none
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Choose online ringtone',
                                style: TextStyle(
                                  fontFamily: MiuiTheme.fontFamily,
                                  fontSize: 16,
                                  fontWeight: FontWeight.normal,
                                  color: Colors.white,
                                ),
                              ),
                              SvgPicture.asset(
                                'resources/right-arrow.svg',
                                width: 22,
                                height: 22,
                                colorFilter: const ColorFilter.mode(
                                  Color(0xFF8E8E93),
                                  BlendMode.srcIn,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // -------------------------------------------------------------
                      // 2ND ROW: "Choose local ringtone" + right-arrow.svg
                      // -------------------------------------------------------------
                      InkWell(
                        onTap: _openLocalAudioFilesScreen,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Choose local ringtone',
                                style: TextStyle(
                                  fontFamily: MiuiTheme.fontFamily,
                                  fontSize: 16,
                                  fontWeight: FontWeight.normal,
                                  color: Colors.white,
                                ),
                              ),
                              SvgPicture.asset(
                                'resources/right-arrow.svg',
                                width: 22,
                                height: 22,
                                colorFilter: const ColorFilter.mode(
                                  Color(0xFF8E8E93),
                                  BlendMode.srcIn,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                      // 3RD ROW: Edge to edge separator
                      Container(height: 0.6, color: const Color(0xFF2C2C2E)),

                      // -------------------------------------------------------------
                      // 4TH ROW: "Default ringtone"
                      // -------------------------------------------------------------
                      _buildRingtoneRow(
                        title: 'Default ringtone',
                        uriOrPath: 'default',
                        duration: null,
                        isSelected: isDefaultSelected,
                        isPlaying: provider.currentlyPlayingPreviewUri == 'default' && provider.isPlayingPreview,
                        onPlayToggle: () {
                          provider.playPreview('default');
                        },
                        onApply: () {
                          _showApplyConfirmationDialog(
                            title: 'Default ringtone',
                            uriOrPath: 'default',
                          );
                        },
                      ),

                      // 5TH ROW: Edge to edge separator
                      Container(height: 0.6, color: const Color(0xFF2C2C2E)),
                    ],

                    // -------------------------------------------------------------
                    // 6TH & 7TH ROWS: "My ringtones"
                    // -------------------------------------------------------------
                    if (myRingtones.isNotEmpty || !_isSearchOpen) ...[
                      const Padding(
                        padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                        child: Text(
                          'My ringtones',
                          style: TextStyle(
                            fontFamily: MiuiTheme.fontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.normal,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      ),
                      if (myRingtones.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          child: Text(
                            'No custom ringtones added yet',
                            style: TextStyle(
                              fontFamily: MiuiTheme.fontFamily,
                              fontSize: 14,
                              color: Color(0xFF636366),
                            ),
                          ),
                        )
                      else
                        ...myRingtones.map((item) {
                          final title = item['title']?.toString() ?? 'Custom tone';
                          final path = item['path']?.toString() ?? '';
                          final duration = item['duration']?.toString() ?? '00:30';
                          final isSelected = currentSelectedTitle == title;
                          final isPlaying = provider.currentlyPlayingPreviewUri == path && provider.isPlayingPreview;

                          return _buildRingtoneRow(
                            title: title,
                            uriOrPath: path,
                            duration: duration,
                            isSelected: isSelected,
                            isPlaying: isPlaying,
                            onPlayToggle: () {
                              if (path.isNotEmpty) {
                                provider.playPreview(path);
                              }
                            },
                            onApply: () {
                              _showApplyConfirmationDialog(
                                title: title,
                                uriOrPath: path,
                              );
                            },
                          );
                        }),

                      // 8TH ROW: Edge to edge separator
                      Container(height: 0.6, color: const Color(0xFF2C2C2E)),
                    ],

                    // -------------------------------------------------------------
                    // 9TH & 10TH ROWS: "System ringtones"
                    // -------------------------------------------------------------
                    const Padding(
                      padding: EdgeInsets.fromLTRB(20, 16, 20, 8),
                      child: Text(
                        'System ringtones',
                        style: TextStyle(
                          fontFamily: MiuiTheme.fontFamily,
                          fontSize: 14,
                          fontWeight: FontWeight.normal,
                          color: Color(0xFF8E8E93),
                        ),
                      ),
                    ),

                    if (_isLoadingSystem)
                      const Center(
                        child: Padding(
                          padding: EdgeInsets.all(24.0),
                          child: CircularProgressIndicator(color: Color(0xFF0C84FF)),
                        ),
                      )
                    else
                      ...systemRingtones.map((item) {
                        final title = item['title']?.toString() ?? 'System tone';
                        final uri = item['uri']?.toString() ?? '';
                        final duration = item['duration']?.toString() ?? '00:30';
                        final isSelected = currentSelectedTitle == title;
                        final isPlaying = provider.currentlyPlayingPreviewUri == uri && provider.isPlayingPreview;

                        return _buildRingtoneRow(
                          title: title,
                          uriOrPath: uri,
                          duration: duration,
                          isSelected: isSelected,
                          isPlaying: isPlaying,
                          onPlayToggle: () {
                            if (uri.isNotEmpty) {
                              provider.playPreview(uri);
                            }
                          },
                          onApply: () {
                            _showApplyConfirmationDialog(
                              title: title,
                              uriOrPath: uri,
                            );
                          },
                        );
                      }),

                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Small 3-bar animated blue pulse visualizer
class AudioPulseVisualizer extends StatefulWidget {
  const AudioPulseVisualizer({super.key});

  @override
  State<AudioPulseVisualizer> createState() => _AudioPulseVisualizerState();
}

class _AudioPulseVisualizerState extends State<AudioPulseVisualizer> with TickerProviderStateMixin {
  late final List<AnimationController> _controllers;
  late final List<Animation<double>> _animations;

  @override
  void initState() {
    super.initState();
    _controllers = List.generate(3, (i) {
      return AnimationController(
        vsync: this,
        duration: Duration(milliseconds: 350 + (i * 120)),
      )..repeat(reverse: true);
    });

    _animations = _controllers.map((c) {
      return Tween<double>(begin: 4.0, end: 14.0).animate(
        CurvedAnimation(parent: c, curve: Curves.easeInOut),
      );
    }).toList();
  }

  @override
  void dispose() {
    for (final c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 14,
      height: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.center,
        children: List.generate(3, (i) {
          return AnimatedBuilder(
            animation: _animations[i],
            builder: (ctx, child) {
              return Container(
                width: 2.8,
                height: _animations[i].value,
                decoration: BoxDecoration(
                  color: const Color(0xFF0C84FF),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            },
          );
        }),
      ),
    );
  }
}
