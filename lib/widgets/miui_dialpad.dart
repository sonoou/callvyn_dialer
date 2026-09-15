import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import '../providers/dialer_provider.dart';
import '../theme/miui_theme.dart';
import '../views/settings_screen.dart';

class MiuiDialpad extends StatefulWidget {
  const MiuiDialpad({super.key});

  @override
  State<MiuiDialpad> createState() => _MiuiDialpadState();
}

class _MiuiDialpadState extends State<MiuiDialpad> {
  late TextEditingController _textController;

  static const List<Map<String, String>> _keys = [
    {'digit': '1', 'letters': ''},
    {'digit': '2', 'letters': 'ABC'},
    {'digit': '3', 'letters': 'DEF'},
    {'digit': '4', 'letters': 'GHI'},
    {'digit': '5', 'letters': 'JKL'},
    {'digit': '6', 'letters': 'MNO'},
    {'digit': '7', 'letters': 'PQRS'},
    {'digit': '8', 'letters': 'TUV'},
    {'digit': '9', 'letters': 'WXYZ'},
    {'digit': '*', 'letters': ','},
    {'digit': '0', 'letters': '+'},
    {'digit': '#', 'letters': ''},
  ];

  void _openSettingsWithShutterAnimation(BuildContext context) {
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => const SettingsScreen(),
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

  void _showMenuOptionsModal(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final cardBgColor = isDark ? const Color(0xFF222732) : const Color(0xFFFFFFFF);
    final itemBgColor = isDark ? Colors.white.withValues(alpha: 0.07) : Colors.black.withValues(alpha: 0.05);
    final iconColor = isDark ? const Color(0xFFB0B0B0) : const Color(0xFF757575);
    final titleColor = isDark ? Colors.white : Colors.black87;
    final labelColor = isDark ? const Color(0xFFE0E0E0) : const Color(0xFF424242);

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (ctx) {
        return Container(
          decoration: BoxDecoration(
            color: cardBgColor,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
          ),
          padding: const EdgeInsets.fromLTRB(20, 20, 20, 16),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                Center(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 18),
                    child: Text(
                      'Menu options',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontFamily: MiuiTheme.fontFamily,
                        fontSize: 19,
                        fontWeight: FontWeight.w600,
                        color: titleColor,
                      ),
                    ),
                  ),
                ),

                // 1st Row: 2 Cards (Settings & Identify phone numbers)
                Row(
                  children: [
                    // Card 1: Settings
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: itemBgColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {
                              Navigator.pop(ctx);
                              _openSettingsWithShutterAnimation(context);
                            },
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SvgPicture.asset(
                                    'resources/settings_in_hamburger.svg',
                                    width: 28,
                                    height: 28,
                                    colorFilter: ColorFilter.mode(
                                      iconColor,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Settings',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontFamily: MiuiTheme.fontFamily,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: labelColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 12),

                    // Card 2: Identify phone numbers
                    Expanded(
                      child: Container(
                        decoration: BoxDecoration(
                          color: itemBgColor,
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Material(
                          color: Colors.transparent,
                          child: InkWell(
                            borderRadius: BorderRadius.circular(16),
                            onTap: () {},
                            child: Padding(
                              padding: const EdgeInsets.symmetric(vertical: 20, horizontal: 8),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                crossAxisAlignment: CrossAxisAlignment.center,
                                children: [
                                  SvgPicture.asset(
                                    'resources/flag_identify_in_hamburger.svg',
                                    width: 28,
                                    height: 28,
                                    colorFilter: ColorFilter.mode(
                                      iconColor,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    'Identify phone numbers',
                                    textAlign: TextAlign.center,
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    style: TextStyle(
                                      fontFamily: MiuiTheme.fontFamily,
                                      fontSize: 12.5,
                                      fontWeight: FontWeight.w500,
                                      color: labelColor,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 14),

                // 2nd Row: Complete wide transparent grey background Cancel button
                Container(
                  width: double.infinity,
                  height: 52,
                  decoration: BoxDecoration(
                    color: itemBgColor,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(16),
                      onTap: () => Navigator.pop(ctx),
                      child: Center(
                        child: Text(
                          'Cancel',
                          style: TextStyle(
                            fontFamily: MiuiTheme.fontFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: titleColor,
                          ),
                        ),
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

  @override
  void initState() {
    super.initState();
    final provider = Provider.of<DialerProvider>(context, listen: false);
    _textController = TextEditingController(text: provider.dialPadInput);
  }

  @override
  void dispose() {
    _textController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DialerProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    if (_textController.text != provider.dialPadInput) {
      final currentSelection = _textController.selection;
      _textController.value = TextEditingValue(
        text: provider.dialPadInput,
        selection: currentSelection.end <= provider.dialPadInput.length
            ? currentSelection
            : TextSelection.collapsed(offset: provider.dialPadInput.length),
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: isDark ? MiuiColors.darkKeypadBg : MiuiColors.lightKeypadBg,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withAlpha(isDark ? 80 : 30),
            blurRadius: 16,
            spreadRadius: 2,
            offset: const Offset(0, 0),
          )
        ],
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Match preview list above keypad
            if (provider.dialPadInput.isNotEmpty) ...[
              const SizedBox(height: 10),
              SizedBox(
                height: 44,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // 100% Dead-Center Typed Number Display (Editable TextField)
                    Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 56),
                        child: _buildEditableInput(
                          provider.dialPadInput,
                          const Color(0xFF25D366), // Green text color!
                          29,
                          provider,
                        ),
                      ),
                    ),

                    // Right-Aligned Clear Button
                    Positioned(
                      right: 12,
                      child: GestureDetector(
                        onTap: provider.backspaceDialPadInput,
                        onLongPress: provider.clearDialPadInput,
                        child: Padding(
                          padding: const EdgeInsets.all(2.0),
                          child: Image.asset(
                            'resources/dialer_digits_clear_btn_night.webp',
                            width: 60,
                            height: 60,
                            fit: BoxFit.contain,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],

            // 4x3 Dialpad Keys Grid (Shifted up to reduce gap with typed number header)
            Transform.translate(
              offset: const Offset(0, 5),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 0),
                child: GridView.builder(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: 12,
                  gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                    crossAxisCount: 3,
                    childAspectRatio: 1.5,
                    crossAxisSpacing: 20,
                    mainAxisSpacing: 1,
                  ),
                  itemBuilder: (ctx, index) {
                    final item = _keys[index];
                    final digit = item['digit']!;

                    return _DialpadKeyButton(
                      item: item,
                      isDark: isDark,
                      onTap: () {
                        provider.appendDialPadInput(digit);
                      },
                      onLongPress: () {
                        if (digit == '0') {
                          provider.appendDialPadInput('+');
                        } else if (digit == '1') {
                          provider.startCall(number: '121', name: 'Voicemail');
                        }
                      },
                    );
                  },
                ),
              ),
            ),

            // Extra Bottom Action Row (Shifted 20dp down from previous!)
            Transform.translate(
              offset: const Offset(0, 25),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 0),
                child: Row(
                  children: [
                    Expanded(
                      child: InkWell(
                        onTap: () => _showMenuOptionsModal(context),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: SvgPicture.asset(
                            'resources/hamburger.svg',
                            width: 22,
                            height: 22,
                            colorFilter: ColorFilter.mode(
                              isDark ? const Color(0xFF9E9E9E) : const Color(0xFF616161),
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const Expanded(
                      child: SizedBox.shrink(),
                    ),
                    Expanded(
                      child: InkWell(
                        onTap: () => provider.toggleDialPad(),
                        borderRadius: BorderRadius.circular(12),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(vertical: 4),
                          child: SvgPicture.asset(
                            'resources/dial.svg',
                            width: 18,
                            height: 18,
                            colorFilter: ColorFilter.mode(
                              isDark ? const Color(0xFF9E9E9E) : const Color(0xFF616161),
                              BlendMode.srcIn,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 68),
          ],
        ),
      ),
    );
  }

  Widget _buildEditableInput(String input, Color color, double fontSize, DialerProvider provider) {
    return TextField(
      controller: _textController,
      textAlign: TextAlign.center,
      readOnly: true,
      autofocus: false,
      showCursor: true,
      cursorColor: color, // Cursor color same as font color!
      cursorWidth: 1.0, // Reduced width by 1dp!
      style: TextStyle(
        fontFamily: MiuiTheme.fontFamily,
        fontSize: fontSize,
        fontWeight: FontWeight.w500,
        letterSpacing: 1.2,
        color: color,
      ),
      decoration: const InputDecoration(
        border: InputBorder.none,
        isDense: true,
        contentPadding: EdgeInsets.zero,
      ),
      onChanged: (val) {
        provider.setDialPadInput(val);
      },
    );
  }
}

class _DialpadKeyButton extends StatefulWidget {
  final Map<String, String> item;
  final bool isDark;
  final VoidCallback onTap;
  final VoidCallback onLongPress;

  const _DialpadKeyButton({
    required this.item,
    required this.isDark,
    required this.onTap,
    required this.onLongPress,
  });

  @override
  State<_DialpadKeyButton> createState() => _DialpadKeyButtonState();
}

class _DialpadKeyButtonState extends State<_DialpadKeyButton> {
  bool _isPressed = false;

  void _handlePressStart() {
    setState(() => _isPressed = true);
  }

  void _handlePressEnd() {
    Future.delayed(const Duration(milliseconds: 120), () {
      if (mounted) {
        setState(() => _isPressed = false);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final digit = widget.item['digit']!;
    final letters = widget.item['letters']!;
    final isDark = widget.isDark;

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _handlePressStart(),
      onTapUp: (_) => _handlePressEnd(),
      onTapCancel: () => _handlePressEnd(),
      onTap: widget.onTap,
      onLongPress: widget.onLongPress,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.easeOut,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: _isPressed
              ? (isDark ? Colors.white.withAlpha(35) : Colors.black.withAlpha(25))
              : Colors.transparent,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            if (digit == '*')
              SvgPicture.asset(
                'resources/asterisk.svg',
                width: 40,
                height: 40,
                colorFilter: ColorFilter.mode(
                  isDark ? Colors.white : Colors.black87,
                  BlendMode.srcIn,
                ),
              )
            else if (digit == '#')
              SvgPicture.asset(
                'resources/hash.svg',
                width: 25,
                height: 25,
                colorFilter: ColorFilter.mode(
                  isDark ? Colors.white : Colors.black87,
                  BlendMode.srcIn,
                ),
              )
            else
              Text(
                digit,
                style: TextStyle(
                  fontFamily: MiuiTheme.mitypeFont,
                  fontSize: 30,
                  height: 1.0,
                  fontWeight: FontWeight.normal,
                  color: isDark ? Colors.white : Colors.black87,
                ),
              ),
            const SizedBox(height: 2),
            if (digit == '1')
              SvgPicture.asset(
                'resources/voicemail.svg',
                width: 14,
                height: 14,
                colorFilter: ColorFilter.mode(
                  isDark ? Colors.white54 : Colors.black45,
                  BlendMode.srcIn,
                ),
              )
            else if (letters.isNotEmpty)
              Transform.translate(
                offset: Offset(0, digit == '*' ? -1 : 0),
                child: Text(
                  letters,
                  style: TextStyle(
                    fontFamily: MiuiTheme.fontFamily,
                    fontSize: 10,
                    height: 1.0,
                    fontWeight: FontWeight.w400,
                    color: isDark ? Colors.white54 : Colors.black45,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
