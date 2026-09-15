import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/call_log.dart';
import '../providers/dialer_provider.dart';
import '../theme/miui_theme.dart';
import '../views/call_log_selection_screen.dart';
import '../views/contact_detail_screen.dart';
import 'miui_avatar.dart';

class CallLogItem extends StatefulWidget {
  final CallLogEntry log;
  final int count;

  const CallLogItem({super.key, required this.log, this.count = 1});

  @override
  State<CallLogItem> createState() => _CallLogItemState();
}

class _CallLogItemState extends State<CallLogItem> {
  Offset _tapPosition = Offset.zero;
  bool _isPressed = false;

  void _openContactDetailsWithShutterAnimation(BuildContext context, DialerProvider provider) {
    final matchedContact = provider.findContactByNumber(widget.log.phoneNumber);
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ContactDetailScreen(
          contactId: matchedContact?.id ?? widget.log.contactId,
          phoneNumber: widget.log.phoneNumber,
          contactName: matchedContact?.name ?? widget.log.contactName,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          const begin = Offset(1.0, 0.0); // Right to Left shutter animation
          const end = Offset.zero;
          const curve = Curves.easeInOutCubic;

          var tween = Tween(begin: begin, end: end).chain(CurveTween(curve: curve));
          var offsetAnimation = animation.drive(tween);

          return SlideTransition(
            position: offsetAnimation,
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 300),
      ),
    );
  }

  void _showCoordinatePopupCard(BuildContext context, DialerProvider provider, Offset tapPosition) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final screenSize = MediaQuery.of(context).size;
    final cardWidth = 180.0;
    final estimatedTotalHeight = 270.0;

    double left = tapPosition.dx.clamp(16.0, screenSize.width - cardWidth - 16.0);
    double top = tapPosition.dy.clamp(
      MediaQuery.of(context).padding.top + 16.0,
      screenSize.height - estimatedTotalHeight - MediaQuery.of(context).padding.bottom - 16.0,
    );

    showGeneralDialog(
      context: context,
      barrierDismissible: true,
      barrierLabel: 'Dismiss',
      barrierColor: Colors.black.withAlpha(90),
      transitionDuration: const Duration(milliseconds: 180),
      pageBuilder: (ctx, anim1, anim2) {
        final cardBgColor = isDark ? const Color(0xFF222732) : const Color(0xFFFAFAFC);
        final textColor = isDark ? Colors.white : Colors.black87;

        return Stack(
          children: [
            Positioned(
              left: left,
              top: top,
              child: Material(
                color: Colors.transparent,
                child: SizedBox(
                  width: cardWidth,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      // -------------------------------------------------------
                      // TOP CARD: "Send a message", "Edit", "Copy", "Delete"
                      // -------------------------------------------------------
                      Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black38,
                              blurRadius: 16,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            _buildPopupMenuItem(
                              ctx: ctx,
                              label: 'Send a message',
                              textColor: textColor,
                              onTap: () async {
                                Navigator.pop(ctx);
                                final cleanNumber = widget.log.phoneNumber.replaceAll(RegExp(r'[^\d+]'), '');
                                const simChannel = MethodChannel('com.sonoou.callvyndialer/sim');
                                try {
                                  final bool? success = await simChannel.invokeMethod<bool>('sendSms', {'number': cleanNumber});
                                  if (success == true) return;
                                } catch (_) {}

                                final Uri smstoUri = Uri.parse('smsto:$cleanNumber');
                                try {
                                  if (await canLaunchUrl(smstoUri)) {
                                    await launchUrl(smstoUri);
                                  } else {
                                    await launchUrl(Uri(scheme: 'sms', path: cleanNumber));
                                  }
                                } catch (e) {
                                  debugPrint('Error launching direct SMS app: $e');
                                }
                              },
                            ),
                            _buildPopupMenuItem(
                              ctx: ctx,
                              label: 'Edit',
                              textColor: textColor,
                              onTap: () {
                                Navigator.pop(ctx);
                                provider.setDialPadInput(widget.log.phoneNumber);
                              },
                            ),
                            _buildPopupMenuItem(
                              ctx: ctx,
                              label: 'Copy',
                              textColor: textColor,
                              onTap: () async {
                                Navigator.pop(ctx);
                                const simChannel = MethodChannel('com.sonoou.callvyndialer/sim');
                                try {
                                  await simChannel.invokeMethod('copyToClipboard', {'text': widget.log.phoneNumber});
                                } catch (_) {
                                  Clipboard.setData(ClipboardData(text: widget.log.phoneNumber));
                                }
                              },
                            ),
                            _buildPopupMenuItem(
                              ctx: ctx,
                              label: 'Delete',
                              textColor: textColor,
                              onTap: () {
                                Navigator.pop(ctx);
                                provider.deleteCallLog(
                                  logId: widget.log.id,
                                  phoneNumber: widget.log.phoneNumber,
                                );
                              },
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 10),

                      // -------------------------------------------------------
                      // BOTTOM CARD: Single "Select" label
                      // -------------------------------------------------------
                      Container(
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(
                          color: cardBgColor,
                          borderRadius: BorderRadius.circular(18),
                          boxShadow: const [
                            BoxShadow(
                              color: Colors.black38,
                              blurRadius: 16,
                              offset: Offset(0, 6),
                            ),
                          ],
                        ),
                        child: _buildPopupMenuItem(
                          ctx: ctx,
                          label: 'Select',
                          textColor: textColor,
                          onTap: () {
                            Navigator.pop(ctx);
                            Navigator.push(
                              context,
                              PageRouteBuilder(
                                pageBuilder: (ctx, _, _) => CallLogSelectionScreen(
                                  initialSelectedNumber: widget.log.phoneNumber,
                                ),
                                transitionDuration: Duration.zero,
                                reverseTransitionDuration: Duration.zero,
                              ),
                            );
                          },
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
      transitionBuilder: (ctx, anim1, anim2, child) {
        return FadeTransition(
          opacity: CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1.0).animate(
              CurvedAnimation(parent: anim1, curve: Curves.easeOutCubic),
            ),
            child: child,
          ),
        );
      },
    );
  }

  Widget _buildPopupMenuItem({
    required BuildContext ctx,
    required String label,
    required Color textColor,
    required VoidCallback onTap,
  }) {
    return _PopupMenuItemWidget(
      label: label,
      textColor: textColor,
      onTap: onTap,
    );
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DialerProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMissed = widget.log.callType == CallType.missed;
    final pressedBg = isDark
        ? Colors.white.withValues(alpha: 0.12)
        : Colors.black.withValues(alpha: 0.08);

    final matchedContact = provider.findContactByNumber(widget.log.phoneNumber);
    final String resolvedContactName = matchedContact?.name ?? widget.log.contactName;
    final bool isSaved = resolvedContactName.trim().isNotEmpty &&
        resolvedContactName.trim() != widget.log.phoneNumber.trim();
    final String rawName = isSaved ? resolvedContactName : widget.log.phoneNumber;
    final String displayName = widget.count > 1 ? "$rawName (${widget.count})" : rawName;

    final now = DateTime.now();
    final isToday = widget.log.timestamp.year == now.year &&
        widget.log.timestamp.month == now.month &&
        widget.log.timestamp.day == now.day;
    final timeOrDate = isToday
        ? DateFormat('h:mm a').format(widget.log.timestamp)
        : DateFormat('MMM d').format(widget.log.timestamp);

    String statusText;
    if (widget.log.durationSeconds > 0) {
      final mins = (widget.log.durationSeconds / 60).ceil();
      statusText = '$mins min';
    } else if (widget.log.callType == CallType.missed) {
      if (widget.log.ringCount != null && widget.log.ringCount! > 0) {
        statusText = 'Rang ${widget.log.ringCount} times';
      } else {
        statusText = 'Missed';
      }
    } else if (widget.log.callType == CallType.rejected) {
      statusText = 'Rejected';
    } else {
      statusText = "Didn't connect";
    }

    final String subText = "${widget.log.phoneNumber}  $timeOrDate  $statusText";

    return AnimatedContainer(
      duration: const Duration(milliseconds: 50),
      color: _isPressed ? pressedBg : Colors.transparent,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          // -------------------------------------------------------------
          // 1ST COLUMN: Photo / Avatar (Tapping shows contact details with Right to Left shutter animation)
          // -------------------------------------------------------------
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openContactDetailsWithShutterAnimation(context, provider),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 2),
              child: MiuiAvatar(
                name: resolvedContactName,
                radius: 19.5,
                avatarUrl: matchedContact?.avatarUrl,
                photoBytes: matchedContact?.photoThumbnail,
              ),
            ),
          ),
          const SizedBox(width: 14),

          // -------------------------------------------------------------
          // 2ND COLUMN: Name & Details (Tapping starts call, Long press shows popup)
          // -------------------------------------------------------------
          Expanded(
            child: Listener(
              onPointerDown: (event) {
                _tapPosition = event.position;
                if (!_isPressed) {
                  setState(() => _isPressed = true);
                }
              },
              onPointerUp: (_) {
                if (_isPressed) {
                  Future.delayed(const Duration(milliseconds: 120), () {
                    if (mounted) setState(() => _isPressed = false);
                  });
                }
              },
              onPointerCancel: (_) {
                if (_isPressed) {
                  if (mounted) setState(() => _isPressed = false);
                }
              },
              child: GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: () {
                  provider.startCall(
                    number: widget.log.phoneNumber,
                    name: resolvedContactName,
                    simSlot: widget.log.simSlot,
                  );
                },
                onLongPress: () {
                  setState(() => _isPressed = false);
                  _showCoordinatePopupCard(context, provider, _tapPosition);
                },
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 4),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Text(
                        displayName,
                        style: TextStyle(
                          fontFamily: MiuiTheme.fontFamily,
                          fontWeight: FontWeight.w500,
                          fontSize: 17,
                          height: 1.1,
                          color: isMissed
                              ? MiuiColors.callRed
                              : (isDark ? Colors.white : Colors.black87),
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subText,
                        style: TextStyle(
                          fontFamily: MiuiTheme.fontFamily,
                          fontWeight: FontWeight.normal,
                          fontSize: 12,
                          color: isDark ? MiuiColors.darkTextSecondary : MiuiColors.lightTextSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
          const SizedBox(width: 12),

          // -------------------------------------------------------------
          // 3RD COLUMN: Circular Dark Grey Button with Right Arrow SVG
          // -------------------------------------------------------------
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openContactDetailsWithShutterAnimation(context, provider),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: isDark ? const Color(0xFF2A2E39) : Colors.grey.shade300,
                ),
                alignment: Alignment.center,
                child: SvgPicture.asset(
                  'resources/right-arrow.svg',
                  width: 22,
                  height: 22,
                  colorFilter: ColorFilter.mode(
                    isDark ? Colors.grey.shade400 : Colors.grey.shade600,
                    BlendMode.srcIn,
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

class _PopupMenuItemWidget extends StatefulWidget {
  final String label;
  final Color textColor;
  final VoidCallback onTap;

  const _PopupMenuItemWidget({
    required this.label,
    required this.textColor,
    required this.onTap,
  });

  @override
  State<_PopupMenuItemWidget> createState() => _PopupMenuItemWidgetState();
}

class _PopupMenuItemWidgetState extends State<_PopupMenuItemWidget> {
  bool _isPressed = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final pressedBg = isDark
        ? Colors.white.withValues(alpha: 0.16)
        : Colors.black.withValues(alpha: 0.12);

    return Listener(
      onPointerDown: (_) => setState(() => _isPressed = true),
      onPointerUp: (_) {
        Future.delayed(const Duration(milliseconds: 100), () {
          if (mounted) setState(() => _isPressed = false);
        });
      },
      onPointerCancel: (_) {
        if (mounted) setState(() => _isPressed = false);
      },
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onTap,
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 50),
          width: double.infinity,
          color: _isPressed ? pressedBg : Colors.transparent,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          child: Text(
            widget.label,
            style: TextStyle(
              fontFamily: MiuiTheme.fontFamily,
              fontSize: 16,
              fontWeight: FontWeight.w500,
              color: widget.textColor,
            ),
          ),
        ),
      ),
    );
  }
}
