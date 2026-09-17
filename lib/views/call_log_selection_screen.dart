import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../models/call_log.dart';
import '../providers/dialer_provider.dart';
import '../theme/miui_theme.dart';
import '../widgets/miui_avatar.dart';

class CallLogSelectionScreen extends StatefulWidget {
  final String? initialSelectedNumber;

  const CallLogSelectionScreen({
    super.key,
    this.initialSelectedNumber,
  });

  @override
  State<CallLogSelectionScreen> createState() => _CallLogSelectionScreenState();
}

class _CallLogSelectionScreenState extends State<CallLogSelectionScreen> {
  final Set<String> _selectedNumbers = {};

  @override
  void initState() {
    super.initState();
    if (widget.initialSelectedNumber != null && widget.initialSelectedNumber!.isNotEmpty) {
      _selectedNumbers.add(widget.initialSelectedNumber!);
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DialerProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final groups = provider.groupedCallLogs;

    return Scaffold(
      backgroundColor: isDark ? MiuiColors.darkBackground : MiuiColors.lightBackground,
      body: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // -------------------------------------------------------------
            // TOP BAR: Left Cross, Center "$count selected", Right List-Check
            // -------------------------------------------------------------
            Container(
              height: 56,
              color: isDark ? MiuiColors.darkBackground : MiuiColors.lightBackground,
              padding: const EdgeInsets.symmetric(horizontal: 8),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Left Align: Cross icon
                  Align(
                    alignment: Alignment.centerLeft,
                    child: IconButton(
                      onPressed: () => Navigator.pop(context),
                      tooltip: 'Close',
                      icon: SvgPicture.asset(
                        'resources/cross-big.svg',
                        width: 20,
                        height: 20,
                        colorFilter: const ColorFilter.mode(
                          Colors.white,
                          BlendMode.srcIn,
                        ),
                      ),
                    ),
                  ),

                  // Center Align: "$count selected"
                  Center(
                    child: Text(
                      '${_selectedNumbers.length} selected',
                      style: const TextStyle(
                        fontFamily: MiuiTheme.fontFamily,
                        fontSize: 18,
                        fontWeight: FontWeight.w600, // normal bold
                        color: Colors.white,
                      ),
                    ),
                  ),

                  // Right Align: List check icon (Select all / Deselect all)
                  Align(
                    alignment: Alignment.centerRight,
                    child: IconButton(
                      onPressed: () {
                        final allNumbers = groups.map((g) => g.latestEntry.phoneNumber).toSet();
                        setState(() {
                          if (_selectedNumbers.length == allNumbers.length && allNumbers.isNotEmpty) {
                            _selectedNumbers.clear();
                          } else {
                            _selectedNumbers.addAll(allNumbers);
                          }
                        });
                      },
                      tooltip: 'Select all',
                      icon: SvgPicture.asset(
                        'resources/list-check.svg',
                        width: 24,
                        height: 24,
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

            // -------------------------------------------------------------
            // CALL LOGS LIST
            // -------------------------------------------------------------
            Expanded(
              child: groups.isEmpty
                  ? Center(
                      child: Text(
                        'No call logs',
                        style: TextStyle(
                          fontFamily: MiuiTheme.fontFamily,
                          fontSize: 14,
                          color: isDark ? MiuiColors.darkTextSecondary : MiuiColors.lightTextSecondary,
                        ),
                      ),
                    )
                  : ListView.builder(
                      itemCount: groups.length,
                      itemBuilder: (ctx, i) {
                        final group = groups[i];
                        final log = group.latestEntry;
                        final count = group.count;
                        final isSelected = _selectedNumbers.contains(log.phoneNumber);
                        final isMissed = log.callType == CallType.missed;

                        final bool isSaved = log.contactName.trim().isNotEmpty &&
                            log.contactName.trim() != log.phoneNumber.trim();
                        final String rawName = isSaved ? log.contactName : log.phoneNumber;
                        final String displayName = count > 1 ? "$rawName ($count)" : rawName;

                        final now = DateTime.now();
                        final isToday = log.timestamp.year == now.year &&
                            log.timestamp.month == now.month &&
                            log.timestamp.day == now.day;
                        final timeOrDate = isToday
                            ? DateFormat('h:mm a').format(log.timestamp)
                            : DateFormat('MMM d').format(log.timestamp);

                        final matchedContact = provider.findContactByNumber(log.phoneNumber);
                        String statusText;
                        if (log.durationSeconds > 0) {
                          final mins = (log.durationSeconds / 60).ceil();
                          statusText = '$mins min';
                        } else if (log.callType == CallType.missed) {
                          if (log.ringCount != null && log.ringCount! > 0) {
                            statusText = 'Rang ${log.ringCount} times';
                          } else {
                            statusText = 'Missed';
                          }
                        } else if (log.callType == CallType.rejected) {
                          statusText = 'Rejected';
                        } else {
                          statusText = "Didn't connect";
                        }

                        final String subText = "${log.phoneNumber}  $timeOrDate  $statusText";

                        return GestureDetector(
                          behavior: HitTestBehavior.opaque,
                          onTap: () {
                            setState(() {
                              if (isSelected) {
                                _selectedNumbers.remove(log.phoneNumber);
                              } else {
                                _selectedNumbers.add(log.phoneNumber);
                              }
                            });
                          },
                          child: Container(
                            color: isSelected
                                ? (isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06))
                                : Colors.transparent,
                            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.center,
                              children: [
                                // 1st Column: Avatar / Photo
                                MiuiAvatar(
                                  name: log.contactName,
                                  radius: 19.5,
                                  avatarUrl: matchedContact?.avatarUrl,
                                  photoBytes: matchedContact?.photoThumbnail,
                                ),
                                const SizedBox(width: 14),

                                // 2nd Column: Name & Details
                                Expanded(
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
                                const SizedBox(width: 12),

                                // 3rd Column: Circular Button Background with Checked icon if selected
                                Container(
                                  width: 23,
                                  height: 23,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: isDark ? const Color(0xFF2A2E39) : Colors.grey.shade300,
                                  ),
                                  alignment: Alignment.center,
                                  child: isSelected
                                      ? Image.asset(
                                          'resources/bh_ic_pay_checked.png',
                                          width: 23,
                                          height: 23,
                                          fit: BoxFit.contain,
                                        )
                                      : null,
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),

            // -------------------------------------------------------------
            // BOTTOM BAR: Garbage Bin with complete horizontal transparent grey background
            // -------------------------------------------------------------
            SafeArea(
              top: false,
              child: Container(
                height: 64,
                width: double.infinity,
                color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.black.withValues(alpha: 0.06),
                alignment: Alignment.center,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: _selectedNumbers.isEmpty
                      ? null
                      : () async {
                          final nav = Navigator.of(context);
                          final toDelete = _selectedNumbers.toList();
                          for (final num in toDelete) {
                            await provider.deleteCallLog(phoneNumber: num);
                          }
                          nav.pop();
                        },
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 6),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        SvgPicture.asset(
                          'resources/garbage-bin.svg',
                          width: 19,
                          height: 19,
                          colorFilter: ColorFilter.mode(
                            _selectedNumbers.isNotEmpty
                                ? (isDark ? Colors.white : Colors.black87)
                                : (isDark ? Colors.white38 : Colors.black26),
                            BlendMode.srcIn,
                          ),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          'Delete',
                          style: TextStyle(
                            fontFamily: MiuiTheme.fontFamily,
                            fontSize: 11,
                            fontWeight: FontWeight.normal,
                            color: isDark ? MiuiColors.darkTextSecondary : MiuiColors.lightTextSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
