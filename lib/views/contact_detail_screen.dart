import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';

import '../models/call_log.dart';
import '../models/contact.dart';
import '../providers/dialer_provider.dart';
import '../theme/miui_theme.dart';
import '../utils/phone_number_helper.dart';
import 'contact_form_screen.dart';
import 'ringtone_screen.dart';

class ContactDetailScreen extends StatefulWidget {
  final String? contactId;
  final String? phoneNumber;
  final String? contactName;

  const ContactDetailScreen({
    super.key,
    this.contactId,
    this.phoneNumber,
    this.contactName,
  });

  @override
  State<ContactDetailScreen> createState() => _ContactDetailScreenState();
}

class _ContactDetailScreenState extends State<ContactDetailScreen> {
  late final ScrollController _scrollController;
  bool _showStickyTitle = false;
  String? _customProfilePhotoPath;

  @override
  void initState() {
    super.initState();
    _scrollController = ScrollController();
    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (!_scrollController.hasClients) return;
    final maxScroll = _scrollController.position.maxScrollExtent;
    final currentScroll = _scrollController.offset;
    // 40 percent scroll trigger
    final bool shouldShow =
        (maxScroll > 0 && (currentScroll / maxScroll) >= 0.40) || (currentScroll >= 95);
    if (shouldShow != _showStickyTitle) {
      setState(() {
        _showStickyTitle = shouldShow;
      });
    }
  }

  @override
  void dispose() {
    _scrollController.removeListener(_onScroll);
    _scrollController.dispose();
    super.dispose();
  }

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final day = dt.day;
    final month = months[dt.month - 1];
    final hour12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$day $month $hour12:$minute $ampm';
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0 sec';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    if (mins > 0 && secs > 0) {
      return '$mins min $secs sec';
    } else if (mins > 0) {
      return '$mins min';
    } else {
      return '$secs sec';
    }
  }


  // ---------------------------------------------------------------------------
  // PLACE ON HOME SCREEN MODAL
  // ---------------------------------------------------------------------------
  void _showPlaceOnHomeScreenModal(
    BuildContext context,
    DialerProvider provider,
    String contactName,
    String contactNumber,
  ) {
    int selectedShortcut = 0; // 0 = View contact, 1 = Direct dial

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (context, setModalState) {
            return Container(
              decoration: const BoxDecoration(
                color: Color(0xFF1C1C1E),
                borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
              ),
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
              child: SafeArea(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(
                      width: double.infinity,
                      child: Text(
                        'Choose a shortcut',
                        style: TextStyle(
                          fontFamily: MiuiTheme.fontFamily,
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // 1st row: View contact
                    InkWell(
                      onTap: () => setModalState(() => selectedShortcut = 0),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: selectedShortcut == 0
                              ? const Color(0xFF0C84FF).withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'View contact',
                              style: TextStyle(
                                fontFamily: MiuiTheme.fontFamily,
                                fontSize: 16,
                                color: selectedShortcut == 0
                                    ? const Color(0xFF0C84FF)
                                    : Colors.white,
                              ),
                            ),
                            if (selectedShortcut == 0)
                              SvgPicture.asset(
                                'resources/checkmark.svg',
                                width: 20,
                                height: 20,
                                colorFilter: const ColorFilter.mode(
                                  Color(0xFF0C84FF),
                                  BlendMode.srcIn,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 8),

                    // 2nd row: Direct dial
                    InkWell(
                      onTap: () => setModalState(() => selectedShortcut = 1),
                      borderRadius: BorderRadius.circular(12),
                      child: Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                        decoration: BoxDecoration(
                          color: selectedShortcut == 1
                              ? const Color(0xFF0C84FF).withValues(alpha: 0.15)
                              : Colors.transparent,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              'Direct dial($contactNumber)',
                              style: TextStyle(
                                fontFamily: MiuiTheme.fontFamily,
                                fontSize: 16,
                                color: selectedShortcut == 1
                                    ? const Color(0xFF0C84FF)
                                    : Colors.white,
                              ),
                            ),
                            if (selectedShortcut == 1)
                              SvgPicture.asset(
                                'resources/checkmark.svg',
                                width: 20,
                                height: 20,
                                colorFilter: const ColorFilter.mode(
                                  Color(0xFF0C84FF),
                                  BlendMode.srcIn,
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),

                    // 3rd row: Cancel / OK buttons
                    Row(
                      children: [
                        Expanded(
                          child: InkWell(
                            onTap: () => Navigator.pop(ctx),
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
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
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: InkWell(
                            onTap: () {
                              Navigator.pop(ctx);
                              provider.createShortcut(
                                name: contactName,
                                number: contactNumber,
                                isDirectDial: selectedShortcut == 1,
                              );
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text(
                                    selectedShortcut == 1
                                        ? 'Direct dial shortcut added for $contactName'
                                        : 'Contact shortcut added for $contactName',
                                  ),
                                  duration: const Duration(seconds: 2),
                                ),
                              );
                            },
                            borderRadius: BorderRadius.circular(24),
                            child: Container(
                              padding: const EdgeInsets.symmetric(vertical: 14),
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
                                  fontWeight: FontWeight.w500,
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
      },
    );
  }

  // ---------------------------------------------------------------------------
  // VOICEMAIL MODAL
  // ---------------------------------------------------------------------------
  void _showVoicemailModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 24, 20, 16),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: double.infinity,
                  child: Text(
                    'Before settings up your mailbox, check the terms and conditions of your contract with your mobile network provider',
                    style: TextStyle(
                      fontFamily: MiuiTheme.fontFamily,
                      fontSize: 15,
                      color: Color(0xFF8E8E93),
                      height: 1.4,
                    ),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.pop(ctx),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.pop(ctx),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                              fontWeight: FontWeight.w500,
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

  // ---------------------------------------------------------------------------
  // DELETE CONTACT MODAL
  // ---------------------------------------------------------------------------
  void _showDeleteContactModal(BuildContext context, DialerProvider provider, Contact contact) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: double.infinity,
                  child: Text(
                    'Delete this contact?',
                    style: TextStyle(
                      fontFamily: MiuiTheme.fontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    'Delete "${contact.name}"?',
                    style: const TextStyle(
                      fontFamily: MiuiTheme.fontFamily,
                      fontSize: 15,
                      color: Color(0xFF8E8E93),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.pop(ctx),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          provider.deleteContact(contact.id);
                          Navigator.pop(ctx);
                          Navigator.of(context).pop();
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0C84FF),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Delete',
                            style: TextStyle(
                              fontFamily: MiuiTheme.fontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
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

  // ---------------------------------------------------------------------------
  // BLOCK MODAL
  // ---------------------------------------------------------------------------
  void _showBlockModal(BuildContext context, DialerProvider provider, String displayPhone) {
    final bool isBlocked = provider.isNumberBlocked(displayPhone);
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    isBlocked ? 'Unblock this phone number?' : 'Block this phone number?',
                    style: const TextStyle(
                      fontFamily: MiuiTheme.fontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: Text(
                    isBlocked ? 'Unblock 1 phone number?' : 'Block 1 phone number?',
                    style: const TextStyle(
                      fontFamily: MiuiTheme.fontFamily,
                      fontSize: 15,
                      color: Color(0xFF8E8E93),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.pop(ctx),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          provider.toggleBlockContact(displayPhone);
                          Navigator.pop(ctx);
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0C84FF),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          alignment: Alignment.center,
                          child: Text(
                            isBlocked ? 'Unblock' : 'Delete',
                            style: const TextStyle(
                              fontFamily: MiuiTheme.fontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
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

  // ---------------------------------------------------------------------------
  // SHARE MODAL
  // ---------------------------------------------------------------------------
  void _showShareModal(BuildContext context, DialerProvider provider, String contactName, String displayPhone) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(
                  width: double.infinity,
                  child: Text(
                    'Share contact as',
                    style: TextStyle(
                      fontFamily: MiuiTheme.fontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 16),

                // 1st row: File
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    provider.shareVCard(name: contactName, number: displayPhone);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: const Text(
                      'File',
                      style: TextStyle(
                        fontFamily: MiuiTheme.fontFamily,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                // 2nd row: Text
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    provider.shareText('$contactName\n$displayPhone');
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: const Text(
                      'Text',
                      style: TextStyle(
                        fontFamily: MiuiTheme.fontFamily,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),

                // 3rd row: QR code
                InkWell(
                  onTap: () {
                    Navigator.pop(ctx);
                    _openQrCodePage(context, contactName, displayPhone, null, null);
                  },
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    child: const Text(
                      'QR code',
                      style: TextStyle(
                        fontFamily: MiuiTheme.fontFamily,
                        fontSize: 16,
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),

                // 4th row: Cancel
                InkWell(
                  onTap: () => Navigator.pop(ctx),
                  borderRadius: BorderRadius.circular(24),
                  child: Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(vertical: 14),
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
                        fontWeight: FontWeight.w500,
                        color: Colors.white,
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

  Widget _buildMenuItem({
    required String text,
    required VoidCallback onTap,
    Color textColor = Colors.white,
  }) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
        child: Text(
          text,
          style: TextStyle(
            fontFamily: MiuiTheme.fontFamily,
            fontSize: 16,
            fontWeight: FontWeight.normal,
            color: textColor,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // 1ST ROW: PHOTO MODAL
  // ---------------------------------------------------------------------------
  void _showPhotoModal(BuildContext context) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.symmetric(vertical: 16),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text(
                  'Photo',
                  style: TextStyle(
                    fontFamily: MiuiTheme.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                    color: Colors.white,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 16),

                // 1st row: Take photo
                _buildMenuItem(
                  text: 'Take photo',
                  onTap: () {
                    Navigator.pop(ctx);
                    _showTakePhotoFlow(context);
                  },
                ),

                // 2nd row: Choose photo from gallery
                _buildMenuItem(
                  text: 'Choose photo from gallery',
                  onTap: () {
                    Navigator.pop(ctx);
                    _openGalleryPicker(context);
                  },
                ),

                // 3rd row: Remove photo
                if (_customProfilePhotoPath != null)
                  _buildMenuItem(
                    text: 'Remove photo',
                    textColor: const Color(0xFFFF3B30),
                    onTap: () {
                      Navigator.pop(ctx);
                      setState(() {
                        _customProfilePhotoPath = null;
                      });
                    },
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showTakePhotoFlow(BuildContext context) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Take photo',
          style: TextStyle(fontFamily: MiuiTheme.fontFamily, color: Colors.white),
        ),
        content: const Text(
          'Camera capture is ready. Confirm to use preview as profile image.',
          style: TextStyle(fontFamily: MiuiTheme.fontFamily, color: Colors.grey),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              setState(() {
                _customProfilePhotoPath = 'resources/contact_detail_circle_photo_night.png';
              });
            },
            child: const Text('OK', style: TextStyle(color: Color(0xFF0C84FF))),
          ),
        ],
      ),
    );
  }

  void _openGalleryPicker(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => _GalleryPhotoPickerScreen(
          onPhotoSelected: (path) {
            setState(() {
              _customProfilePhotoPath = path;
            });
          },
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // HOLD POPUP FOR PHONE NUMBER
  // ---------------------------------------------------------------------------
  void _showNumberHoldPopup(BuildContext context, DialerProvider provider, String number, Offset tapPosition) {
    final screenSize = MediaQuery.of(context).size;
    const cardWidth = 200.0;
    final left = min(tapPosition.dx, screenSize.width - cardWidth - 16);
    final top = min(tapPosition.dy, screenSize.height - 180);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.3),
      pageBuilder: (ctx, anim1, anim2) {
        return Stack(
          children: [
            Positioned(
              left: max(16.0, left),
              top: max(16.0, top),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: cardWidth,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHoldMenuItem('Copy to clipboard', () {
                        Clipboard.setData(ClipboardData(text: number));
                        Navigator.pop(ctx);
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Copied to clipboard'), duration: Duration(seconds: 1)),
                        );
                      }),
                      const Divider(height: 1, color: Color(0xFF3A3A3C)),
                      _buildHoldMenuItem('Dial on SIM1', () {
                        Navigator.pop(ctx);
                        provider.startCall(number: number, simSlot: 1);
                      }),
                      const Divider(height: 1, color: Color(0xFF3A3A3C)),
                      _buildHoldMenuItem('Dial on SIM2', () {
                        Navigator.pop(ctx);
                        provider.startCall(number: number, simSlot: 2);
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Widget _buildHoldMenuItem(String title, VoidCallback onTap) {
    return InkWell(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        child: Text(
          title,
          style: const TextStyle(
            fontFamily: MiuiTheme.fontFamily,
            fontSize: 15,
            color: Colors.white,
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // ADD TO EXISTING CONTACT DIALOG
  // ---------------------------------------------------------------------------
  void _showAddToExistingContactDialog(BuildContext context, DialerProvider provider, String number) {
    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF1C1C1E),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 16),
                child: Text(
                  'Select Contact',
                  style: TextStyle(
                    fontFamily: MiuiTheme.fontFamily,
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: Colors.white,
                  ),
                ),
              ),
              Expanded(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: provider.contacts.length,
                  itemBuilder: (context, index) {
                    final c = provider.contacts[index];
                    return ListTile(
                      title: Text(
                        c.name,
                        style: const TextStyle(
                          fontFamily: MiuiTheme.fontFamily,
                          color: Colors.white,
                        ),
                      ),
                      subtitle: Text(
                        c.phoneNumber,
                        style: const TextStyle(
                          fontFamily: MiuiTheme.fontFamily,
                          color: Colors.grey,
                        ),
                      ),
                      onTap: () {
                        Navigator.pop(ctx);
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ContactFormScreen(
                              contact: c,
                              initialPhone: number,
                            ),
                          ),
                        );
                      },
                    );
                  },
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------------
  // QR CODE SCREEN NAVIGATION
  // ---------------------------------------------------------------------------
  void _openQrCodePage(
    BuildContext context,
    String name,
    String number,
    String? company,
    String? position,
  ) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => _ContactQrCodeScreen(
          name: name,
          number: number,
          company: company,
          position: position,
          customPhotoPath: _customProfilePhotoPath,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // FULL CALL HISTORY SCREEN
  // ---------------------------------------------------------------------------
  void _openFullHistoryScreen(BuildContext context, DialerProvider provider, List<CallLogEntry> allLogs, String contactName) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => _FullCallHistoryScreen(
          logs: allLogs,
          contactName: contactName,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // CALL HISTORY DETAIL PAGE (Tap on history entry)
  // ---------------------------------------------------------------------------
  void _openCallHistoryDetailPage(BuildContext context, DialerProvider provider, CallLogEntry log, String contactName) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => _CallHistoryDetailPage(
          log: log,
          contactName: contactName,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0);
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;
          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          return SlideTransition(position: animation.drive(tween), child: child);
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DialerProvider>(context);

    Contact? contact;
    if (widget.contactId != null) {
      try {
        contact = provider.contacts.firstWhere((c) => c.id == widget.contactId);
      } catch (_) {}
    }
    if (contact == null && widget.phoneNumber != null) {
      contact = provider.findContactByNumber(widget.phoneNumber);
    }

    final bool isSaved = contact != null;
    final String contactName = contact?.name ?? widget.contactName ?? '';
    final String displayName = isSaved
        ? (contactName.isNotEmpty ? contactName : 'Unknown contact')
        : 'Unknown contact';
    final String displayPhone = contact?.phoneNumber ?? widget.phoneNumber ?? '';
    final bool isBlocked = provider.isNumberBlocked(displayPhone);
    final bool isFavorite = contact?.isFavorite ?? false;
    final String labelType = contact?.label ?? 'Mobile';
    final String? emailAddress = contact?.email;
    final String? companyName = contact?.company;

    // Filter call logs for this specific phone number / contact
    final List<CallLogEntry> historyLogs = provider.callLogs.where((l) {
      return (displayPhone.isNotEmpty && PhoneNumberHelper.isMatch(l.phoneNumber, displayPhone)) ||
          (contact != null && l.contactId == contact.id);
    }).toList();

    final visibleLogs = historyLogs.take(3).toList();

    // Sticky bar title: Saved contact name or unsaved contact phone number
    final String stickyTitleText = isSaved ? contactName : displayPhone;

    Offset lastTapPosition = Offset.zero;

    return Scaffold(
      backgroundColor: Colors.black, // Overall background: AMOLED complete black
      body: SafeArea(
        child: Column(
          children: [
            // ---------------------------------------------------------
            // TOP BAR:
            // 1st col: arrow-back.svg (white, left)
            // 2nd col: 40% scroll text (center, weight normal)
            // 3rd col: $saved ? three-dots-vertical.svg : empty
            // ---------------------------------------------------------
            Container(
              color: Colors.black,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  // 1st column: Back icon
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.of(context).pop(),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: SvgPicture.asset(
                        'resources/arrow-back.svg',
                        width: 34,
                        height: 34,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),

                  // 2nd column: 40% scroll center title
                  Expanded(
                    child: AnimatedOpacity(
                      opacity: _showStickyTitle ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      curve: Curves.easeInOut,
                      child: Text(
                        stickyTitleText,
                        style: const TextStyle(
                          fontFamily: MiuiTheme.fontFamily,
                          fontSize: 18,
                          fontWeight: FontWeight.normal,
                          color: Colors.white,
                        ),
                        textAlign: TextAlign.center,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ),
                  ),

                  // 3rd column: $saved ? three-dots-vertical.svg
                  if (contact != null)
                    Theme(
                      data: Theme.of(context).copyWith(
                        splashColor: Colors.transparent,
                        highlightColor: Colors.transparent,
                        hoverColor: Colors.transparent,
                      ),
                      child: PopupMenuButton<String>(
                        onSelected: (key) {
                          if (key == 'shortcut') {
                            _showPlaceOnHomeScreenModal(context, provider, contact!.name, displayPhone);
                          } else if (key == 'voicemail') {
                            _showVoicemailModal(context);
                          } else if (key == 'delete') {
                            _showDeleteContactModal(context, provider, contact!);
                          } else if (key == 'block') {
                            _showBlockModal(context, provider, displayPhone);
                          } else if (key == 'share') {
                            _showShareModal(context, provider, contact!.name, displayPhone);
                          }
                        },
                        color: const Color(0xFF242426),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(21),
                        ),
                        clipBehavior: Clip.antiAlias,
                        padding: EdgeInsets.zero,
                        menuPadding: EdgeInsets.zero,
                        elevation: 8,
                        offset: const Offset(0, 10),
                        icon: SvgPicture.asset(
                          'resources/three-dots-vertical.svg',
                          width: 22,
                          height: 22,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                        itemBuilder: (ctx) {
                          final menuItems = [
                            {'key': 'shortcut', 'label': 'Place on Home screen'},
                            {'key': 'voicemail', 'label': 'Voicemail not in use'},
                            {'key': 'delete', 'label': 'Delete contact'},
                            {'key': 'block', 'label': isBlocked ? 'Unblock' : 'Block'},
                            {'key': 'share', 'label': 'Share'},
                          ];

                          return menuItems.asMap().entries.map((entry) {
                            final idx = entry.key;
                            final item = entry.value;
                            final key = item['key']!;
                            final label = item['label']!;
                            final isDelete = key == 'delete';

                            BorderRadius? itemRadius;
                            if (idx == 0) {
                              itemRadius = const BorderRadius.vertical(top: Radius.circular(21));
                            } else if (idx == menuItems.length - 1) {
                              itemRadius = const BorderRadius.vertical(bottom: Radius.circular(21));
                            }

                            return PopupMenuItem<String>(
                              value: key,
                              padding: EdgeInsets.zero,
                              child: Container(
                                width: double.infinity,
                                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 15),
                                decoration: BoxDecoration(
                                  borderRadius: itemRadius,
                                ),
                                child: Text(
                                  label,
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                  style: TextStyle(
                                    fontFamily: MiuiTheme.fontFamily,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w400,
                                    color: isDelete ? const Color(0xFFFF3B30) : Colors.white,
                                  ),
                                ),
                              ),
                            );
                          }).toList();
                        },
                      ),
                    )
                  else
                    const SizedBox(width: 34),
                ],
              ),
            ),

            // Scrollable Content
            Expanded(
              child: SingleChildScrollView(
                controller: _scrollController,
                physics: const BouncingScrollPhysics(),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const SizedBox(height: 30),

                      // ---------------------------------------------------------
                      // 1ST ROW: Contact photo (contact_detail_circle_photo_night.png) left aligned
                      // ---------------------------------------------------------
                      Align(
                        alignment: Alignment.centerLeft,
                        child: GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () => _showPhotoModal(context),
                          child: Container(
                            width: 76,
                            height: 76,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                            ),
                            clipBehavior: Clip.antiAlias,
                            child: _customProfilePhotoPath != null
                                ? (_customProfilePhotoPath!.startsWith('assets/') || _customProfilePhotoPath!.startsWith('resources/')
                                    ? Image.asset(_customProfilePhotoPath!, fit: BoxFit.cover)
                                    : Image.file(File(_customProfilePhotoPath!), fit: BoxFit.cover))
                                : Image.asset(
                                    'resources/contact_detail_circle_photo_night.png',
                                    width: 76,
                                    height: 76,
                                    fit: BoxFit.contain,
                                  ),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // ---------------------------------------------------------
                      // 2ND ROW: ($saved ? $contact_name : "Unknown contact")
                      // child: Row with $company_name, $position (grey)
                      // ---------------------------------------------------------
                      Text(
                        displayName,
                        style: const TextStyle(
                          fontFamily: MiuiTheme.fontFamily,
                          fontSize: 30,
                          fontWeight: FontWeight.normal,
                          color: Colors.white,
                          letterSpacing: -0.3,
                        ),
                      ),

                      if (isSaved && companyName != null && companyName.isNotEmpty) ...[
                        const SizedBox(height: 4),
                        Row(
                          children: [
                            Text(
                              companyName,
                              style: const TextStyle(
                                fontFamily: MiuiTheme.fontFamily,
                                fontSize: 14,
                                color: Color(0xFF8E8E93),
                              ),
                            ),
                          ],
                        ),
                      ],

                      const SizedBox(height: 36),

                      // ---------------------------------------------------------
                      // 3RD ROW: Separator
                      // ---------------------------------------------------------
                      Container(
                        height: 0.6,
                        color: const Color(0xFF2C2C2E),
                      ),

                      // ---------------------------------------------------------
                      // 4TH ROW:
                      // 1st col: $contact_number + [Mobile/Work..., |, $contact_country]
                      // 2nd col: Green Call circle + Blue Message circle
                      // on hold: hold coordinates popup (Copy, SIM1, SIM2)
                      // ---------------------------------------------------------
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 16),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 1st column: number + type & country
                            Expanded(
                              child: Listener(
                                onPointerDown: (event) => lastTapPosition = event.position,
                                child: GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onLongPress: () {
                                    _showNumberHoldPopup(context, provider, displayPhone, lastTapPosition);
                                  },
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        displayPhone,
                                        style: const TextStyle(
                                          fontFamily: MiuiTheme.fontFamily,
                                          fontSize: 17,
                                          fontWeight: FontWeight.w500,
                                          color: Colors.white,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Row(
                                        children: [
                                          Text(
                                            labelType,
                                            style: const TextStyle(
                                              fontFamily: MiuiTheme.fontFamily,
                                              fontSize: 13,
                                              color: Color(0xFF8E8E93),
                                            ),
                                          ),
                                          const Padding(
                                            padding: EdgeInsets.symmetric(horizontal: 6),
                                            child: Text(
                                              '|',
                                              style: TextStyle(
                                                fontFamily: MiuiTheme.fontFamily,
                                                fontSize: 13,
                                                color: Color(0xFF8E8E93),
                                              ),
                                            ),
                                          ),
                                          const Text(
                                            'India',
                                            style: TextStyle(
                                              fontFamily: MiuiTheme.fontFamily,
                                              fontSize: 13,
                                              color: Color(0xFF8E8E93),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),

                            // 2nd column: Call and Message buttons
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                // Green Call Button
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    FocusScope.of(context).unfocus();
                                    FocusManager.instance.primaryFocus?.unfocus();
                                    SystemChannels.textInput.invokeMethod('TextInput.hide');
                                    if (displayPhone.isNotEmpty) {
                                      Navigator.of(context).pop();
                                      provider.startCall(
                                        number: displayPhone,
                                        name: isSaved ? contactName : null,
                                        simSlot: 1,
                                      );
                                    }
                                  },
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF25D366),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: Image.asset(
                                      'resources/contact_details_dialer_btn_call.webp',
                                      width: 20,
                                      height: 20,
                                      fit: BoxFit.contain,
                                    ),
                                  ),
                                ),

                                const SizedBox(width: 14),

                                // Blue Message Button
                                GestureDetector(
                                  behavior: HitTestBehavior.opaque,
                                  onTap: () {
                                    if (displayPhone.isNotEmpty) {
                                      provider.sendSms(displayPhone);
                                    }
                                  },
                                  child: Container(
                                    width: 38,
                                    height: 38,
                                    decoration: const BoxDecoration(
                                      color: Color(0xFF0C84FF),
                                      shape: BoxShape.circle,
                                    ),
                                    alignment: Alignment.center,
                                    child: SvgPicture.asset(
                                      'resources/message.svg',
                                      width: 20,
                                      height: 20,
                                      colorFilter: const ColorFilter.mode(
                                        Colors.white,
                                        BlendMode.srcIn,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // ---------------------------------------------------------
                      // 5TH ROW:
                      // 1st col: $contact_number + [Mobile, |, India]
                      // 2nd col: video.webp (background blue, size 38x38)
                      // ---------------------------------------------------------
                      Padding(
                        padding: const EdgeInsets.symmetric(vertical: 12),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          crossAxisAlignment: CrossAxisAlignment.center,
                          children: [
                            // 1st column: number + type & country
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    displayPhone,
                                    style: const TextStyle(
                                      fontFamily: MiuiTheme.fontFamily,
                                      fontSize: 17,
                                      fontWeight: FontWeight.w500,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      Text(
                                        labelType,
                                        style: const TextStyle(
                                          fontFamily: MiuiTheme.fontFamily,
                                          fontSize: 13,
                                          color: Color(0xFF8E8E93),
                                        ),
                                      ),
                                      const Padding(
                                        padding: EdgeInsets.symmetric(horizontal: 6),
                                        child: Text(
                                          '|',
                                          style: TextStyle(
                                            fontFamily: MiuiTheme.fontFamily,
                                            fontSize: 13,
                                            color: Color(0xFF8E8E93),
                                          ),
                                        ),
                                      ),
                                      const Text(
                                        'India',
                                        style: TextStyle(
                                          fontFamily: MiuiTheme.fontFamily,
                                          fontSize: 13,
                                          color: Color(0xFF8E8E93),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),

                            // 2nd column: Video Button
                            GestureDetector(
                              behavior: HitTestBehavior.opaque,
                              onTap: () {
                                FocusScope.of(context).unfocus();
                                FocusManager.instance.primaryFocus?.unfocus();
                                SystemChannels.textInput.invokeMethod('TextInput.hide');
                                if (displayPhone.isNotEmpty) {
                                  Navigator.of(context).pop();
                                  provider.startCall(
                                    number: displayPhone,
                                    name: isSaved ? contactName : null,
                                    simSlot: 1,
                                    isVideoCall: true,
                                  );
                                }
                              },
                              onLongPress: () {
                                FocusScope.of(context).unfocus();
                                FocusManager.instance.primaryFocus?.unfocus();
                                SystemChannels.textInput.invokeMethod('TextInput.hide');
                                if (displayPhone.isNotEmpty) {
                                  Navigator.of(context).pop();
                                  provider.simulateIncomingVideoCall(
                                    number: displayPhone,
                                    name: isSaved ? contactName : null,
                                  );
                                }
                              },
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0C84FF),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: SvgPicture.asset(
                                  'resources/video-call.svg',
                                  width: 20,
                                  height: 20,
                                  colorFilter: const ColorFilter.mode(
                                    Colors.white,
                                    BlendMode.srcIn,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                      // ---------------------------------------------------------
                      // 6TH ROW: Email address row (if exists)
                      // ---------------------------------------------------------
                      if (emailAddress != null && emailAddress.isNotEmpty) ...[
                        Padding(
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                emailAddress,
                                style: const TextStyle(
                                  fontFamily: MiuiTheme.fontFamily,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 4),
                              const Text(
                                'Home',
                                style: TextStyle(
                                  fontFamily: MiuiTheme.fontFamily,
                                  fontSize: 13,
                                  color: Color(0xFF8E8E93),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      // ---------------------------------------------------------
                      // 7TH ROW: Separator
                      // ---------------------------------------------------------
                      Container(
                        height: 0.6,
                        color: const Color(0xFF2C2C2E),
                      ),

                      // ---------------------------------------------------------
                      // 8TH, 9TH, 10TH ROWS (Only if not saved / $not_saved)
                      // ---------------------------------------------------------
                      if (!isSaved) ...[
                        // 8th Row: "New" (Blue)
                        InkWell(
                          onTap: () {
                            Navigator.push(
                              context,
                              MaterialPageRoute(
                                builder: (_) => ContactFormScreen(
                                  initialPhone: displayPhone,
                                ),
                              ),
                            );
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: const Text(
                              'New',
                              style: TextStyle(
                                fontFamily: MiuiTheme.fontFamily,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF0C84FF),
                              ),
                            ),
                          ),
                        ),

                        // 9th Row: "Existing" (Blue)
                        InkWell(
                          onTap: () {
                            _showAddToExistingContactDialog(context, provider, displayPhone);
                          },
                          child: Container(
                            width: double.infinity,
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: const Text(
                              'Existing',
                              style: TextStyle(
                                fontFamily: MiuiTheme.fontFamily,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF0C84FF),
                              ),
                            ),
                          ),
                        ),

                        // 10th Row: Separator
                        Container(
                          height: 0.6,
                          color: const Color(0xFF2C2C2E),
                        ),
                      ],

                      // ---------------------------------------------------------
                      // 11TH ROW: "Call history" (Grey)
                      // ---------------------------------------------------------
                      const Padding(
                        padding: EdgeInsets.only(top: 22, bottom: 12),
                        child: Text(
                          'Call history',
                          style: TextStyle(
                            fontFamily: MiuiTheme.fontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      ),

                      // ---------------------------------------------------------
                      // 12TH ROW: Call history entries (Last 3 by default)
                      // ---------------------------------------------------------
                      if (visibleLogs.isEmpty)
                        const Padding(
                          padding: EdgeInsets.symmetric(vertical: 12),
                          child: Text(
                            'No call history',
                            style: TextStyle(
                              fontFamily: MiuiTheme.fontFamily,
                              fontSize: 14,
                              color: Color(0xFF8E8E93),
                            ),
                          ),
                        )
                      else
                        ...visibleLogs.map((log) {
                          final isIncoming = log.callType == CallType.incoming;
                          final isMissed = log.callType == CallType.missed;

                          final String iconPath = isMissed
                              ? 'resources/dialer_ic_call_log_header_missed_call.webp'
                              : (isIncoming
                                  ? 'resources/dialer_ic_call_log_header_incoming_call.webp'
                                  : 'resources/dialer_ic_call_log_header_outgoing_call.webp');

                          final String rightText = isMissed
                              ? "Didn't connect"
                              : _formatDuration(log.durationSeconds);

                          return Listener(
                            onPointerDown: (event) => lastTapPosition = event.position,
                            child: InkWell(
                              onTap: () {
                                _openCallHistoryDetailPage(context, provider, log, displayName);
                              },
                              onLongPress: () {
                                _showCallHistoryItemHoldPopup(context, provider, log, lastTapPosition);
                              },
                              child: Padding(
                                padding: const EdgeInsets.symmetric(vertical: 10),
                                child: Row(
                                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                  crossAxisAlignment: CrossAxisAlignment.center,
                                  children: [
                                    // 1st column: Date text on top, ($contact_number + call type icon) below
                                    Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        // 1st row: Date text
                                        Text(
                                          _formatDate(log.timestamp),
                                          style: const TextStyle(
                                            fontFamily: MiuiTheme.fontFamily,
                                            fontSize: 18,
                                            fontWeight: FontWeight.w500,
                                            color: Colors.white,
                                          ),
                                        ),
                                        const SizedBox(height: 2),
                                        // 2nd row: $contact_number + call type icon
                                        Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Text(
                                              log.phoneNumber,
                                              style: const TextStyle(
                                                fontFamily: MiuiTheme.fontFamily,
                                                fontSize: 13,
                                                color: Color(0xFF8E8E93),
                                              ),
                                            ),
                                            const SizedBox(width: 6),
                                            Image.asset(
                                              iconPath,
                                              width: 14,
                                              height: 14,
                                              fit: BoxFit.contain,
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),

                                    // 2nd column: right aligned duration / "Didn't connect" + right-arrow.svg
                                    Row(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        Text(
                                          rightText,
                                          style: const TextStyle(
                                            fontFamily: MiuiTheme.fontFamily,
                                            fontSize: 13,
                                            color: Color(0xFF8E8E93),
                                          ),
                                        ),
                                        const SizedBox(width: 8),
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
                                  ],
                                ),
                              ),
                            ),
                          );
                        }),

                      // ---------------------------------------------------------
                      // 13TH ROW: "Show more" (Blue)
                      // ---------------------------------------------------------
                      if (historyLogs.length > 3)
                        InkWell(
                          onTap: () {
                            _openFullHistoryScreen(context, provider, historyLogs, displayName);
                          },
                          child: const Padding(
                            padding: EdgeInsets.symmetric(vertical: 14),
                            child: Text(
                              'Show more',
                              style: TextStyle(
                                fontFamily: MiuiTheme.fontFamily,
                                fontSize: 15,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFF0C84FF),
                              ),
                            ),
                          ),
                        ),

                      // ---------------------------------------------------------
                      // 14TH ROW: "Block" / "Unblock" (Red, only if not saved)
                      // ---------------------------------------------------------
                      if (!isSaved)
                        InkWell(
                          onTap: () {
                            if (displayPhone.isNotEmpty) {
                              _showBlockModal(context, provider, displayPhone);
                            }
                          },
                          child: Padding(
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            child: Text(
                              isBlocked ? 'Unblock' : 'Block',
                              style: const TextStyle(
                                fontFamily: MiuiTheme.fontFamily,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                                color: Color(0xFFFF3B30),
                              ),
                            ),
                          ),
                        ),

                      // ---------------------------------------------------------
                      // 15TH ROW: Separator
                      // ---------------------------------------------------------
                      Container(
                        height: 0.6,
                        color: const Color(0xFF2C2C2E),
                      ),

                      // ---------------------------------------------------------
                      // 16TH ROW: "More" (Grey)
                      // ---------------------------------------------------------
                      const Padding(
                        padding: EdgeInsets.only(top: 22, bottom: 12),
                        child: Text(
                          'More',
                          style: TextStyle(
                            fontFamily: MiuiTheme.fontFamily,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Color(0xFF8E8E93),
                          ),
                        ),
                      ),

                      // ---------------------------------------------------------
                      // 17TH ROW: "Default ringtone" + right arrow
                      // ---------------------------------------------------------
                      InkWell(
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const RingtoneScreen(),
                            ),
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  const Text(
                                    'Default ringtone',
                                    style: TextStyle(
                                      fontFamily: MiuiTheme.fontFamily,
                                      fontSize: 16,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    provider.getContactRingtoneTitle(contact?.id, displayPhone) ?? 'Mi Remix',
                                    style: const TextStyle(
                                      fontFamily: MiuiTheme.fontFamily,
                                      fontSize: 13,
                                      color: Color(0xFF8E8E93),
                                    ),
                                  ),
                                ],
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

                      // ---------------------------------------------------------
                      // 18TH ROW: "QR code" + right arrow
                      // ---------------------------------------------------------
                      InkWell(
                        onTap: () {
                          _openQrCodePage(
                            context,
                            displayName,
                            displayPhone,
                            companyName,
                            null,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'QR code',
                                style: TextStyle(
                                  fontFamily: MiuiTheme.fontFamily,
                                  fontSize: 16,
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

                      const SizedBox(height: 40),
                    ],
                  ),
                ),
              ),
            ),

            // ---------------------------------------------------------
            // BOTTOM BAR: Center aligned Favourite & Edit contact
            // ---------------------------------------------------------
            Container(
              padding: const EdgeInsets.symmetric(vertical: 12),
              decoration: const BoxDecoration(
                color: Colors.black,
                border: Border(
                  top: BorderSide(
                    color: Color(0xFF1C1C1E),
                    width: 0.8,
                  ),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  // 1st Item: Favourite Toggle
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (contact != null) {
                        provider.toggleFavorite(contact.id);
                      }
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          isFavorite
                              ? 'resources/favourite-fill.svg'
                              : 'resources/favourite.svg',
                          width: 24,
                          height: 24,
                          colorFilter: ColorFilter.mode(
                            isFavorite ? const Color(0xFFFF3B30) : Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          isFavorite ? 'Unfavourite' : 'Favourite',
                          style: TextStyle(
                            fontFamily: MiuiTheme.fontFamily,
                            fontSize: 11,
                            color: isFavorite ? const Color(0xFFFF3B30) : Colors.white,
                          ),
                        ),
                      ],
                    ),
                  ),

                  // 2nd Item: Edit Contact
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      if (contact != null) {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ContactFormScreen(contact: contact),
                          ),
                        );
                      } else {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => ContactFormScreen(
                              initialPhone: displayPhone,
                            ),
                          ),
                        );
                      }
                    },
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SvgPicture.asset(
                          'resources/edit.svg',
                          width: 24,
                          height: 24,
                          colorFilter: const ColorFilter.mode(
                            Colors.white,
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(height: 4),
                        const Text(
                          'Edit contact',
                          style: TextStyle(
                            fontFamily: MiuiTheme.fontFamily,
                            fontSize: 11,
                            color: Colors.white,
                          ),
                        ),
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

  // ---------------------------------------------------------------------------
  // CALL HISTORY ITEM HOLD POPUP
  // ---------------------------------------------------------------------------
  void _showCallHistoryItemHoldPopup(
    BuildContext context,
    DialerProvider provider,
    CallLogEntry log,
    Offset tapPosition,
  ) {
    final screenSize = MediaQuery.of(context).size;
    const cardWidth = 230.0;
    final left = min(tapPosition.dx, screenSize.width - cardWidth - 16);
    final top = min(tapPosition.dy, screenSize.height - 140);

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withValues(alpha: 0.3),
      pageBuilder: (ctx, anim1, anim2) {
        return Stack(
          children: [
            Positioned(
              left: max(16.0, left),
              top: max(16.0, top),
              child: Material(
                color: Colors.transparent,
                child: Container(
                  width: cardWidth,
                  decoration: BoxDecoration(
                    color: const Color(0xFF2C2C2E),
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withValues(alpha: 0.4),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      _buildHoldMenuItem('Remove from call history', () {
                        Navigator.pop(ctx);
                        _showClearHistoryConfirmation(context, provider, log);
                      }),
                      const Divider(height: 1, color: Color(0xFF3A3A3C)),
                      _buildHoldMenuItem('Add call note', () {
                        Navigator.pop(ctx);
                        _showAddCallNoteDialog(context, provider, log);
                      }),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _showClearHistoryConfirmation(BuildContext context, DialerProvider provider, CallLogEntry log) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          decoration: const BoxDecoration(
            color: Color(0xFF1C1C1E),
            borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: SafeArea(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Clear call history',
                  style: TextStyle(
                    fontFamily: MiuiTheme.fontFamily,
                    fontSize: 18,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'Clear call history?',
                  style: TextStyle(
                    fontFamily: MiuiTheme.fontFamily,
                    fontSize: 15,
                    color: Color(0xFF8E8E93),
                  ),
                ),
                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => Navigator.pop(ctx),
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
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
                              fontWeight: FontWeight.w500,
                              color: Colors.white,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: InkWell(
                        onTap: () {
                          provider.deleteCallLog(logId: log.id);
                          Navigator.pop(ctx);
                        },
                        borderRadius: BorderRadius.circular(24),
                        child: Container(
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          decoration: BoxDecoration(
                            color: const Color(0xFF0C84FF),
                            borderRadius: BorderRadius.circular(24),
                          ),
                          alignment: Alignment.center,
                          child: const Text(
                            'Delete',
                            style: TextStyle(
                              fontFamily: MiuiTheme.fontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
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

  void _showAddCallNoteDialog(BuildContext context, DialerProvider provider, CallLogEntry log) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Add Call Note',
          style: TextStyle(fontFamily: MiuiTheme.fontFamily, color: Colors.white),
        ),
        content: TextField(
          controller: noteController,
          style: const TextStyle(fontFamily: MiuiTheme.fontFamily, color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter note...',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0C84FF))),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              final text = noteController.text.trim();
              if (text.isNotEmpty) {
                provider.addCallNote(log.id, text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Color(0xFF0C84FF))),
          ),
        ],
      ),
    );
  }
}

// =============================================================================
// GALLERY PHOTO PICKER SCREEN (4 columns, dynamic rows, latest to oldest)
// =============================================================================
class _GalleryPhotoPickerScreen extends StatelessWidget {
  final ValueChanged<String> onPhotoSelected;

  const _GalleryPhotoPickerScreen({required this.onPhotoSelected});

  @override
  Widget build(BuildContext context) {
    // Sample gallery items & pre-bundled avatars/images
    final List<String> samplePhotos = [
      'resources/contact_detail_circle_photo_night.png',
      'resources/contact_detail_circle_photo.png',
      'resources/contact_details_dialer_btn_call.webp',
      'resources/callvyn_dialer_launcher_icon.png',
    ];

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: cross-big.svg + Select 1 photo
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context),
                    child: Padding(
                      padding: const EdgeInsets.all(4.0),
                      child: SvgPicture.asset(
                        'resources/cross-big.svg',
                        width: 24,
                        height: 24,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Select 1 photo',
                    style: TextStyle(
                      fontFamily: MiuiTheme.fontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.w600,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            // 4-Column Grid
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.all(12),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 8,
                  mainAxisSpacing: 8,
                ),
                itemCount: samplePhotos.length,
                itemBuilder: (ctx, i) {
                  final item = samplePhotos[i];
                  return GestureDetector(
                    onTap: () {
                      onPhotoSelected(item);
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2E),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      clipBehavior: Clip.antiAlias,
                      child: Image.asset(item, fit: BoxFit.cover),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// =============================================================================
// CONTACT QR CODE SCREEN
// =============================================================================
class _ContactQrCodeScreen extends StatelessWidget {
  final String name;
  final String number;
  final String? company;
  final String? position;
  final String? customPhotoPath;

  const _ContactQrCodeScreen({
    required this.name,
    required this.number,
    this.company,
    this.position,
    this.customPhotoPath,
  });

  @override
  Widget build(BuildContext context) {
    final sub = [
      if (company != null && company!.isNotEmpty) company!,
      if (position != null && position!.isNotEmpty) position!,
    ].join(', ');

    return Scaffold(
      backgroundColor: Colors.black, // Amoled black
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Back arrow + Center title
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context),
                    child: SvgPicture.asset(
                      'resources/arrow-back.svg',
                      width: 32,
                      height: 32,
                      colorFilter: const ColorFilter.mode(
                        Colors.white,
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                  const Expanded(
                    child: Text(
                      'QR code',
                      style: TextStyle(
                        fontFamily: MiuiTheme.fontFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.normal,
                        color: Colors.white,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(width: 32),
                ],
              ),
            ),

            const Spacer(),

            // White Container Card
            Container(
              margin: const EdgeInsets.symmetric(horizontal: 24),
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(24),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // 1st row: Avatar + Name & Company
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration: const BoxDecoration(shape: BoxShape.circle),
                        clipBehavior: Clip.antiAlias,
                        child: customPhotoPath != null
                            ? Image.asset(customPhotoPath!, fit: BoxFit.cover)
                            : Image.asset(
                                'resources/contact_detail_circle_photo.png',
                                fit: BoxFit.cover,
                              ),
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              name,
                              style: const TextStyle(
                                fontFamily: MiuiTheme.fontFamily,
                                fontSize: 18,
                                fontWeight: FontWeight.w600,
                                color: Colors.black,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            if (sub.isNotEmpty)
                              Text(
                                sub,
                                style: const TextStyle(
                                  fontFamily: MiuiTheme.fontFamily,
                                  fontSize: 13,
                                  color: Colors.grey,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                          ],
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 24),

                  // 2nd row: QR Code pattern
                  Container(
                    width: 200,
                    height: 200,
                    decoration: BoxDecoration(
                      border: Border.all(color: Colors.grey.shade300, width: 1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    padding: const EdgeInsets.all(12),
                    child: CustomPaint(
                      painter: _QrMatrixPainter('MECARD:N:$name;TEL:$number;;'),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // 3rd row: Share QR code button (wide blue capsule)
                  InkWell(
                    onTap: () {
                      final provider = Provider.of<DialerProvider>(context, listen: false);
                      provider.shareText('Contact: $name\nNumber: $number');
                    },
                    borderRadius: BorderRadius.circular(28),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: const Color(0xFF0C84FF),
                        borderRadius: BorderRadius.circular(28),
                      ),
                      alignment: Alignment.center,
                      child: const Text(
                        'Share QR code',
                        style: TextStyle(
                          fontFamily: MiuiTheme.fontFamily,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const Spacer(),
          ],
        ),
      ),
    );
  }
}

// QR Code Canvas Painter
class _QrMatrixPainter extends CustomPainter {
  final String data;
  _QrMatrixPainter(this.data);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = Colors.black;
    final int gridSize = 21;
    final cellWidth = size.width / gridSize;
    final cellHeight = size.height / gridSize;

    final random = Random(data.hashCode);

    for (int r = 0; r < gridSize; r++) {
      for (int c = 0; c < gridSize; c++) {
        // Corner squares
        if ((r < 7 && c < 7) || (r < 7 && c >= gridSize - 7) || (r >= gridSize - 7 && c < 7)) {
          if (r == 0 || r == 6 || c == 0 || c == 6 ||
              r == gridSize - 1 || r == gridSize - 7 || c == gridSize - 1 || c == gridSize - 7 ||
              (r >= 2 && r <= 4 && c >= 2 && c <= 4) ||
              (r >= 2 && r <= 4 && c >= gridSize - 5 && c <= gridSize - 3) ||
              (r >= gridSize - 5 && r <= gridSize - 3 && c >= 2 && c <= 4)) {
            canvas.drawRect(
              Rect.fromLTWH(c * cellWidth, r * cellHeight, cellWidth, cellHeight),
              paint,
            );
          }
        } else if (random.nextBool()) {
          canvas.drawRect(
            Rect.fromLTWH(c * cellWidth, r * cellHeight, cellWidth, cellHeight),
            paint,
          );
        }
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// =============================================================================
// CALL HISTORY DETAIL PAGE (Tap on a log entry)
// =============================================================================
class _CallHistoryDetailPage extends StatefulWidget {
  final CallLogEntry log;
  final String contactName;

  const _CallHistoryDetailPage({
    required this.log,
    required this.contactName,
  });

  @override
  State<_CallHistoryDetailPage> createState() => _CallHistoryDetailPageState();
}

class _CallHistoryDetailPageState extends State<_CallHistoryDetailPage> {
  bool _isPlayingRecording = false;

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final day = dt.day.toString().padLeft(2, '0');
    final month = months[dt.month - 1];
    final hour12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$day $month, $hour12:$minute $ampm';
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return "Didn't connect";
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    if (mins > 0 && secs > 0) return '$mins min $secs sec';
    if (mins > 0) return '$mins min';
    return '$secs sec';
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DialerProvider>(context);
    final isMissed = widget.log.callType == CallType.missed;
    final isIncoming = widget.log.callType == CallType.incoming;

    final String statusInfo = isMissed
        ? "Didn't connect"
        : (isIncoming
            ? 'Incoming ${_formatDuration(widget.log.durationSeconds)}'
            : 'Outgoing ${_formatDuration(widget.log.durationSeconds)}');

    final notes = provider.getCallNotes(widget.log.id);

    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Back arrow
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              alignment: Alignment.centerLeft,
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () => Navigator.pop(context),
                child: SvgPicture.asset(
                  'resources/arrow-back.svg',
                  width: 32,
                  height: 32,
                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                ),
              ),
            ),

            Expanded(
              child: SingleChildScrollView(
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // 1st Row: Date & Status
                    Text(
                      _formatDate(widget.log.timestamp),
                      style: const TextStyle(
                        fontFamily: MiuiTheme.fontFamily,
                        fontSize: 24,
                        fontWeight: FontWeight.normal,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      statusInfo,
                      style: const TextStyle(
                        fontFamily: MiuiTheme.fontFamily,
                        fontSize: 14,
                        color: Color(0xFF8E8E93),
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Divider(height: 1, color: Color(0xFF2C2C2E)),
                    const SizedBox(height: 16),

                    // 2nd Row: Number + Call & SMS Buttons
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              widget.log.phoneNumber,
                              style: const TextStyle(
                                fontFamily: MiuiTheme.fontFamily,
                                fontSize: 17,
                                fontWeight: FontWeight.w500,
                                color: Colors.white,
                              ),
                            ),
                            const SizedBox(height: 4),
                            const Text(
                              'Mobile | India',
                              style: TextStyle(
                                fontFamily: MiuiTheme.fontFamily,
                                fontSize: 13,
                                color: Color(0xFF8E8E93),
                              ),
                            ),
                          ],
                        ),
                        Row(
                          children: [
                            // Call Button
                            GestureDetector(
                              onTap: () {
                                provider.startCall(number: widget.log.phoneNumber);
                              },
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF25D366),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: Image.asset(
                                  'resources/contact_details_dialer_btn_call.webp',
                                  width: 20,
                                  height: 20,
                                ),
                              ),
                            ),
                            const SizedBox(width: 14),
                            // SMS Button
                            GestureDetector(
                              onTap: () {
                                provider.sendSms(widget.log.phoneNumber);
                              },
                              child: Container(
                                width: 38,
                                height: 38,
                                decoration: const BoxDecoration(
                                  color: Color(0xFF0C84FF),
                                  shape: BoxShape.circle,
                                ),
                                alignment: Alignment.center,
                                child: SvgPicture.asset(
                                  'resources/message.svg',
                                  width: 20,
                                  height: 20,
                                  colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),
                    const Divider(height: 1, color: Color(0xFF2C2C2E)),
                    const SizedBox(height: 20),

                    // 3rd Row: Call recordings
                    const Text(
                      'Call recordings',
                      style: TextStyle(
                        fontFamily: MiuiTheme.fontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 12),
                    if (widget.log.isRecorded)
                      Container(
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: const Color(0xFF1C1C1E),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    _formatDate(widget.log.timestamp),
                                    style: const TextStyle(
                                      fontFamily: MiuiTheme.fontFamily,
                                      fontSize: 14,
                                      color: Colors.white,
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  Row(
                                    children: [
                                      Text(
                                        _isPlayingRecording ? '0:15' : '0:00',
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                      Expanded(
                                        child: Slider(
                                          value: _isPlayingRecording ? 0.3 : 0.0,
                                          onChanged: (_) {},
                                          activeColor: const Color(0xFF0C84FF),
                                          inactiveColor: const Color(0xFF3A3A3C),
                                        ),
                                      ),
                                      Text(
                                        _formatDuration(widget.log.durationSeconds),
                                        style: const TextStyle(fontSize: 11, color: Colors.grey),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                            IconButton(
                              icon: Icon(
                                _isPlayingRecording ? Icons.pause_circle_filled : Icons.play_circle_filled,
                                color: const Color(0xFF0C84FF),
                                size: 36,
                              ),
                              onPressed: () {
                                setState(() {
                                  _isPlayingRecording = !_isPlayingRecording;
                                });
                              },
                            ),
                          ],
                        ),
                      )
                    else
                      const Text(
                        'No call recordings for this session',
                        style: TextStyle(fontFamily: MiuiTheme.fontFamily, fontSize: 13, color: Color(0xFF8E8E93)),
                      ),

                    const SizedBox(height: 24),
                    const Divider(height: 1, color: Color(0xFF2C2C2E)),
                    const SizedBox(height: 20),

                    // 4th Row: Call notes
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        const Text(
                          'Call notes',
                          style: TextStyle(
                            fontFamily: MiuiTheme.fontFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.add, color: Color(0xFF0C84FF)),
                          onPressed: () {
                            _showAddCallNoteDialog(context, provider);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),

                    if (notes.isEmpty)
                      const Text(
                        'No call notes',
                        style: TextStyle(fontFamily: MiuiTheme.fontFamily, fontSize: 13, color: Color(0xFF8E8E93)),
                      )
                    else
                      ...notes.map((n) {
                        return Container(
                          margin: const EdgeInsets.only(bottom: 8),
                          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          decoration: BoxDecoration(
                            color: const Color(0xFF1C1C1E),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            children: [
                              Expanded(
                                child: Text(
                                  n,
                                  style: const TextStyle(
                                    fontFamily: MiuiTheme.fontFamily,
                                    fontSize: 14,
                                    color: Colors.white,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ),
                              IconButton(
                                icon: SvgPicture.asset(
                                  'resources/down-arrow-lined.svg',
                                  width: 18,
                                  height: 18,
                                  colorFilter: const ColorFilter.mode(Colors.grey, BlendMode.srcIn),
                                ),
                                onPressed: () {
                                  _openNoteViewer(context, provider, n);
                                },
                              ),
                              IconButton(
                                icon: const Icon(Icons.delete_outline, color: Color(0xFFFF3B30), size: 20),
                                onPressed: () {
                                  provider.deleteCallNote(widget.log.id, n);
                                },
                              ),
                            ],
                          ),
                        );
                      }),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showAddCallNoteDialog(BuildContext context, DialerProvider provider) {
    final noteController = TextEditingController();
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF1C1C1E),
        title: const Text(
          'Add Call Note',
          style: TextStyle(fontFamily: MiuiTheme.fontFamily, color: Colors.white),
        ),
        content: TextField(
          controller: noteController,
          style: const TextStyle(fontFamily: MiuiTheme.fontFamily, color: Colors.white),
          decoration: const InputDecoration(
            hintText: 'Enter note...',
            hintStyle: TextStyle(color: Colors.grey),
            enabledBorder: UnderlineInputBorder(borderSide: BorderSide(color: Colors.grey)),
            focusedBorder: UnderlineInputBorder(borderSide: BorderSide(color: Color(0xFF0C84FF))),
          ),
          maxLines: 3,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          TextButton(
            onPressed: () {
              final text = noteController.text.trim();
              if (text.isNotEmpty) {
                provider.addCallNote(widget.log.id, text);
              }
              Navigator.pop(ctx);
            },
            child: const Text('Save', style: TextStyle(color: Color(0xFF0C84FF))),
          ),
        ],
      ),
    );
  }

  void _openNoteViewer(BuildContext context, DialerProvider provider, String noteText) {
    final editController = TextEditingController(text: noteText);
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => Scaffold(
          backgroundColor: Colors.black,
          appBar: AppBar(
            backgroundColor: Colors.black,
            title: const Text('Note', style: TextStyle(fontFamily: MiuiTheme.fontFamily, color: Colors.white)),
            leading: IconButton(
              icon: SvgPicture.asset('resources/arrow-back.svg', width: 28, height: 28, colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn)),
              onPressed: () => Navigator.pop(context),
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.check, color: Color(0xFF25D366)),
                onPressed: () {
                  final newText = editController.text.trim();
                  if (newText.isNotEmpty) {
                    provider.deleteCallNote(widget.log.id, noteText);
                    provider.addCallNote(widget.log.id, newText);
                  }
                  Navigator.pop(context);
                },
              ),
              IconButton(
                icon: const Icon(Icons.delete, color: Color(0xFFFF3B30)),
                onPressed: () {
                  provider.deleteCallNote(widget.log.id, noteText);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: TextField(
              controller: editController,
              style: const TextStyle(fontFamily: MiuiTheme.fontFamily, fontSize: 16, color: Colors.white),
              maxLines: null,
              decoration: const InputDecoration(border: InputBorder.none),
            ),
          ),
        ),
      ),
    );
  }
}

// =============================================================================
// FULL CALL HISTORY SCREEN
// =============================================================================
class _FullCallHistoryScreen extends StatelessWidget {
  final List<CallLogEntry> logs;
  final String contactName;

  const _FullCallHistoryScreen({
    required this.logs,
    required this.contactName,
  });

  String _formatDate(DateTime dt) {
    const months = [
      'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun',
      'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
    ];
    final day = dt.day;
    final month = months[dt.month - 1];
    final hour12 = dt.hour == 0 ? 12 : (dt.hour > 12 ? dt.hour - 12 : dt.hour);
    final minute = dt.minute.toString().padLeft(2, '0');
    final ampm = dt.hour >= 12 ? 'PM' : 'AM';
    return '$day $month $hour12:$minute $ampm';
  }

  String _formatDuration(int seconds) {
    if (seconds <= 0) return '0 sec';
    final mins = seconds ~/ 60;
    final secs = seconds % 60;
    if (mins > 0 && secs > 0) return '$mins min $secs sec';
    if (mins > 0) return '$mins min';
    return '$secs sec';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: Column(
          children: [
            // Top Bar: Back button + Call history details
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => Navigator.pop(context),
                    child: SvgPicture.asset(
                      'resources/arrow-back.svg',
                      width: 32,
                      height: 32,
                      colorFilter: const ColorFilter.mode(Colors.white, BlendMode.srcIn),
                    ),
                  ),
                  const SizedBox(width: 16),
                  const Text(
                    'Call history details',
                    style: TextStyle(
                      fontFamily: MiuiTheme.fontFamily,
                      fontSize: 18,
                      fontWeight: FontWeight.normal,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
            ),

            Expanded(
              child: ListView.separated(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                itemCount: logs.length,
                separatorBuilder: (_, _) => const Divider(height: 1, color: Color(0xFF2C2C2E)),
                itemBuilder: (ctx, i) {
                  final log = logs[i];
                  final isIncoming = log.callType == CallType.incoming;
                  final isMissed = log.callType == CallType.missed;

                  final String iconPath = isMissed
                      ? 'resources/dialer_ic_call_log_header_missed_call.webp'
                      : (isIncoming
                          ? 'resources/dialer_ic_call_log_header_incoming_call.webp'
                          : 'resources/dialer_ic_call_log_header_outgoing_call.webp');

                  final String rightText = isMissed
                      ? "Didn't connect"
                      : _formatDuration(log.durationSeconds);

                  return InkWell(
                    onTap: () {
                      Navigator.push(
                        context,
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) => _CallHistoryDetailPage(
                            log: log,
                            contactName: contactName,
                          ),
                          transitionsBuilder: (context, animation, secondaryAnimation, child) {
                            const begin = Offset(1.0, 0.0);
                            const end = Offset.zero;
                            const curve = Curves.easeInOutCubic;
                            var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
                            return SlideTransition(position: animation.drive(tween), child: child);
                          },
                        ),
                      );
                    },
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _formatDate(log.timestamp),
                                style: const TextStyle(
                                  fontFamily: MiuiTheme.fontFamily,
                                  fontSize: 18,
                                  fontWeight: FontWeight.w500,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Row(
                                children: [
                                  Text(
                                    log.phoneNumber,
                                    style: const TextStyle(
                                      fontFamily: MiuiTheme.fontFamily,
                                      fontSize: 13,
                                      color: Color(0xFF8E8E93),
                                    ),
                                  ),
                                  const SizedBox(width: 6),
                                  Image.asset(
                                    iconPath,
                                    width: 14,
                                    height: 14,
                                    fit: BoxFit.contain,
                                  ),
                                ],
                              ),
                            ],
                          ),
                          Row(
                            children: [
                              Text(
                                rightText,
                                style: const TextStyle(
                                  fontFamily: MiuiTheme.fontFamily,
                                  fontSize: 13,
                                  color: Color(0xFF8E8E93),
                                ),
                              ),
                              const SizedBox(width: 8),
                              SvgPicture.asset(
                                'resources/right-arrow.svg',
                                width: 22,
                                height: 22,
                                colorFilter: const ColorFilter.mode(Color(0xFF8E8E93), BlendMode.srcIn),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
