import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../providers/dialer_provider.dart';
import '../theme/miui_theme.dart';
import '../widgets/call_log_item.dart';
import '../widgets/contact_tile.dart';
import '../widgets/miui_dialpad.dart';
import 'contact_detail_screen.dart';
import 'contact_form_screen.dart';
import 'in_call_screen.dart';
import 'settings_screen.dart';

class _SmoothTabsScrollPhysics extends ScrollPhysics {
  const _SmoothTabsScrollPhysics({super.parent = const PageScrollPhysics(parent: ClampingScrollPhysics())});

  @override
  _SmoothTabsScrollPhysics applyTo(ScrollPhysics? ancestor) {
    return _SmoothTabsScrollPhysics(parent: buildParent(ancestor));
  }

  @override
  double applyBoundaryConditions(ScrollMetrics position, double value) {
    // 1st Problem: Block left-to-right swipe on Tab 0 (0 movement, no animation)
    if (value < position.pixels && position.pixels <= position.minScrollExtent) {
      return value - position.pixels;
    }
    // 3rd Problem: Block right-to-left swipe on Tab 1 (0 movement, no animation)
    if (value > position.pixels && position.pixels >= position.maxScrollExtent) {
      return value - position.pixels;
    }
    if (value < position.minScrollExtent) {
      return value - position.minScrollExtent;
    }
    if (value > position.maxScrollExtent) {
      return value - position.maxScrollExtent;
    }
    return super.applyBoundaryConditions(position, value);
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  static const double _maxHeaderHeight = 60.0;
  static const double _minHeaderHeight = 0.0;

  final TextEditingController _searchController = TextEditingController();
  final ScrollController _recentsScrollController = ScrollController();
  final ScrollController _contactsScrollController = ScrollController();
  double _recentsHeaderExtent = _maxHeaderHeight;
  double _contactsHeaderExtent = _maxHeaderHeight;

  bool _isSearchActive = false;
  bool _isSearchHeaderExpanded = false;
  final FocusNode _searchFocusNode = FocusNode();

  late PageController _pageController;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
    _pageController.addListener(() {
      if (mounted) setState(() {});
    });
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final provider = Provider.of<DialerProvider>(context, listen: false);
      await provider.checkAndRequestDefaultDialer();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _searchController.dispose();
    _recentsScrollController.dispose();
    _contactsScrollController.dispose();
    _pageController.dispose();
    _searchFocusNode.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      final provider = Provider.of<DialerProvider>(context, listen: false);
      provider.isDefaultDialer();
      provider.fetchDeviceCallLogs();
      provider.fetchDeviceContacts();
    }
  }

  void _openDedicatedSearch() {
    setState(() {
      _isSearchActive = true;
      _isSearchHeaderExpanded = false;
    });
    Future.delayed(const Duration(milliseconds: 100), () {
      if (mounted && _isSearchActive) {
        setState(() {
          _isSearchHeaderExpanded = true;
        });
        _searchFocusNode.requestFocus();
      }
    });
  }

  void _closeDedicatedSearch(DialerProvider provider) {
    if (_searchController.text.trim().isNotEmpty) {
      provider.addSearchHistory(_searchController.text);
    }
    _searchFocusNode.unfocus();
    setState(() {
      _isSearchHeaderExpanded = false;
    });
    Future.delayed(const Duration(milliseconds: 200), () {
      if (mounted) {
        setState(() {
          _isSearchActive = false;
          _searchController.clear();
          provider.setSearchQuery('');
        });
      }
    });
  }

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

  void _onTabSelected(DialerProvider provider, int tabIndex) {
    if (provider.selectedTabIndex != tabIndex) {
      provider.setTab(tabIndex);
    }
    if (tabIndex < 2 && _pageController.hasClients && (_pageController.page?.round() ?? 0) != tabIndex) {
      _pageController.animateToPage(
        tabIndex,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DialerProvider>(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // DIRECT IN-CALL SCREEN:
    // If incoming or active in-call, render InCallScreen directly as the entire page
    // without loading or rendering any part of HomeScreen
    if (provider.inCall) {
      return const InCallScreen();
    }

    return PopScope(
      canPop: !_isSearchActive,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _isSearchActive) {
          _closeDedicatedSearch(provider);
        }
      },
      child: Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (_) {
        if (provider.isFirstTimeOnboarding) {
          provider.dismissFirstTimeOnboarding();
        }
      },
      onPointerMove: (event) {
        if (provider.isFirstTimeOnboarding) {
          provider.dismissFirstTimeOnboarding();
        }
      },
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onTap: () {
          if (provider.isDialPadOpen) {
            provider.setDialPadOpen(false);
          }
        },
        child: Scaffold(
          resizeToAvoidBottomInset: false,
          backgroundColor: isDark ? MiuiColors.darkBackground : MiuiColors.lightBackground,
          body: Stack(
            children: [
              SafeArea(
                child: Column(
                  children: [
                    // -------------------------------------------------------------
                    // TOPBAR (No Green background, No underlines)
                    // Center: Container wrapping Call (call.svg) & Contact (person.svg)
                    // Right: Settings Icon (settings.svg) in WHITE color
                    // -------------------------------------------------------------
                    Container(
                      height: 56,
                      color: isDark ? MiuiColors.darkBackground : MiuiColors.lightBackground,
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: provider.dialPadInput.isNotEmpty
                          ? Stack(
                              alignment: Alignment.center,
                              children: [
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: IconButton(
                                    icon: const Icon(Icons.arrow_back),
                                    onPressed: () => provider.clearDialPadInput(),
                                  ),
                                ),
                                Center(
                                  child: Text(
                                    'Recents',
                                    style: TextStyle(
                                      fontFamily: MiuiTheme.fontFamily,
                                      fontSize: 18,
                                      fontWeight: FontWeight.normal,
                                      color: isDark ? Colors.white : Colors.black87,
                                    ),
                                  ),
                                ),
                              ],
                            )
                          : Stack(
                              children: [
                                // Center Aligned Container wrapping Call (call.svg) and Person (person.svg)
                                Align(
                                  alignment: Alignment.center,
                                  child: Row(
                                    mainAxisSize: MainAxisSize.min,
                                    children: [
                                      // Call Button (call.svg) - Tab 0 (Transparent Container for expanded tap area)
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          _onTabSelected(provider, 0);
                                        },
                                        child: Container(
                                          color: Colors.transparent,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 180),
                                            padding: const EdgeInsets.all(5),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: provider.selectedTabIndex == 0
                                                  ? const Color(0xFF25D366)
                                                  : Colors.transparent,
                                              border: Border.all(
                                                color: provider.selectedTabIndex == 0
                                                    ? const Color(0xFF25D366)
                                                    : Colors.grey,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: SvgPicture.asset(
                                              'resources/call.svg',
                                              width: 12,
                                              height: 12,
                                              colorFilter: ColorFilter.mode(
                                                provider.selectedTabIndex == 0
                                                    ? Colors.black
                                                    : Colors.grey,
                                                BlendMode.srcIn,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 30),
                                      // Person / Contact Button (person.svg) - Tab 1 (Transparent Container for expanded tap area)
                                      GestureDetector(
                                        behavior: HitTestBehavior.opaque,
                                        onTap: () {
                                          _onTabSelected(provider, 1);
                                        },
                                        child: Container(
                                          color: Colors.transparent,
                                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                                          child: AnimatedContainer(
                                            duration: const Duration(milliseconds: 180),
                                            padding: const EdgeInsets.all(5),
                                            decoration: BoxDecoration(
                                              shape: BoxShape.circle,
                                              color: provider.selectedTabIndex == 1
                                                  ? const Color(0xFF00B0FF)
                                                  : Colors.transparent, // Sky Blue
                                              border: Border.all(
                                                color: provider.selectedTabIndex == 1
                                                    ? const Color(0xFF00B0FF)
                                                    : Colors.grey,
                                                width: 1.5,
                                              ),
                                            ),
                                            child: SvgPicture.asset(
                                              'resources/person.svg',
                                              width: 12,
                                              height: 12,
                                              colorFilter: ColorFilter.mode(
                                                provider.selectedTabIndex == 1
                                                    ? Colors.black
                                                    : Colors.grey,
                                                BlendMode.srcIn,
                                              ),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ),

                                // Right End Aligned Settings Icon (settings.svg)
                                Align(
                                  alignment: Alignment.centerRight,
                                  child: IconButton(
                                    onPressed: () {
                                      _openSettingsWithShutterAnimation(context);
                                    },
                                    tooltip: 'Settings',
                                    icon: SvgPicture.asset(
                                      'resources/settings.svg',
                                      width: 22,
                                      height: 22,
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
                    // MAIN CONTENT BODY (Tab 0: Calls, Tab 1: Contacts, Tab 2: Settings)
                    // -------------------------------------------------------------
                    Expanded(
                      child: Stack(
                        children: [
                          provider.selectedTabIndex == 2
                              ? const SettingsScreen()
                              : PageView(
                                  controller: _pageController,
                                  onPageChanged: (index) {
                                    if (provider.selectedTabIndex != index && index < 2) {
                                      provider.setTab(index);
                                    }
                                  },
                                  physics: provider.dialPadInput.isNotEmpty
                                      ? const NeverScrollableScrollPhysics()
                                      : const _SmoothTabsScrollPhysics(),
                                  children: [
                                     _buildRecentsTab(context, provider, isDark),
                                     _buildContactsTab(context, provider, isDark),
                                   ],
                                 ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              // Dedicated Search Page Overlay
              if (_isSearchActive)
                Positioned.fill(
                  child: _buildDedicatedSearchPage(context, provider, isDark),
                ),
              // Animated Floating Action Buttons (Recents Call Button & Contacts Plus Button)
              if (!_isSearchActive && provider.selectedTabIndex != 2) ...[
                // 1. Recents / Dialer Call Button (Single SIM or Dual SIM)
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 300),
                  curve: Curves.easeOutCubic,
                  left: 0,
                  right: 0,
                  bottom: 25 + MediaQuery.of(context).padding.bottom,
                  child: AnimatedBuilder(
                    animation: _pageController,
                    builder: (context, child) {
                      double pageScrollOffset = 0.0;
                      if (_pageController.hasClients && _pageController.position.haveDimensions) {
                        pageScrollOffset = _pageController.page ?? _pageController.initialPage.toDouble();
                      } else {
                        pageScrollOffset = provider.selectedTabIndex.toDouble();
                      }
                      final translationX = provider.isDialPadOpen
                          ? (-pageScrollOffset * MediaQuery.of(context).size.width)
                          : (-pageScrollOffset * 100.0);

                      final double opacity = (1.0 - pageScrollOffset * 1.5).clamp(0.0, 1.0);

                      return Opacity(
                        opacity: opacity,
                        child: provider.isDualSim
                            ? _buildDualSimCallButtonLayer(context, provider, translationX)
                            : _buildSingleSimCallButtonLayer(context, provider, translationX),
                      );
                    },
                  ),
                ),

                // 2. Contacts Tab Floating Plus Button with bottom slide animation
                AnimatedBuilder(
                  animation: _pageController,
                  builder: (context, child) {
                    double pageScrollOffset = 0.0;
                    if (_pageController.hasClients && _pageController.position.haveDimensions) {
                      pageScrollOffset = _pageController.page ?? _pageController.initialPage.toDouble();
                    } else {
                      pageScrollOffset = provider.selectedTabIndex.toDouble();
                    }

                    final double contactsProgress = pageScrollOffset.clamp(0.0, 1.0);
                    // Bottom slide animation: slides up from bottom (offset 100dp -> 0dp)
                    final double slideOffsetY = (1.0 - contactsProgress) * 100.0;
                    final double opacity = contactsProgress.clamp(0.0, 1.0);

                    if (contactsProgress <= 0.02) {
                      return const SizedBox.shrink();
                    }

                    return Positioned(
                      right: 20,
                      bottom: 25 + MediaQuery.of(context).padding.bottom,
                      child: Transform.translate(
                        offset: Offset(0, slideOffsetY),
                        child: Opacity(
                          opacity: opacity,
                          child: Container(
                            width: 56,
                            height: 56,
                            decoration: const BoxDecoration(
                              color: Color(0xFF25D366),
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black26,
                                  blurRadius: 8,
                                  offset: Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                customBorder: const CircleBorder(),
                                onTap: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const ContactFormScreen(),
                                    ),
                                  );
                                },
                                child: Center(
                                  child: SvgPicture.asset(
                                    'resources/plus.svg',
                                    width: 24,
                                    height: 24,
                                    colorFilter: const ColorFilter.mode(
                                      Colors.white,
                                      BlendMode.srcIn,
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ],

              // VERY TOPMOST LAYER: Full-screen Custom In-Call Screen Overlay (Covers Entire Screen, No Route Push)
              if (provider.inCall)
                const Positioned.fill(
                  child: InCallScreen(),
                ),
            ],
          ),
          floatingActionButton: null,
        ),
      ),
    ),
    );
  }

  // -------------------------------------------------------------
  // DEDICATED SEARCH PAGE OVERLAY (Instant page without route animation)
  // -------------------------------------------------------------
  Widget _buildDedicatedSearchPage(BuildContext context, DialerProvider provider, bool isDark) {
    final searchBgColor = isDark ? MiuiColors.darkBackground : MiuiColors.lightBackground;
    final searchBarBgColor = isDark ? MiuiColors.darkSurface : Colors.white;

    return Container(
      color: searchBgColor,
      child: SafeArea(
        bottom: false,
        child: Column(
          children: [
            // Top Header Row: Contracting Search Bar + Animated "Cancel" Button
            AnimatedPadding(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              padding: EdgeInsets.fromLTRB(
                16,
                _isSearchHeaderExpanded ? 8 : 63,
                16,
                8,
              ),
              child: Row(
                children: [
                  // Contracting Search Bar (Attributes same as home screen search bar)
                  Expanded(
                    child: AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      curve: Curves.easeOutCubic,
                      height: 43,
                      padding: const EdgeInsets.only(left: 16, right: 13),
                      decoration: BoxDecoration(
                        color: searchBarBgColor,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Left search.svg icon
                          SvgPicture.asset(
                            'resources/search.svg',
                            width: 18,
                            height: 18,
                            colorFilter: ColorFilter.mode(
                              isDark ? Colors.white60 : Colors.black54,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(width: 10),

                          // Search TextField (1st Change: NO PLACEHOLDER TEXT!)
                          Expanded(
                            child: TextField(
                              controller: _searchController,
                              focusNode: _searchFocusNode,
                              textAlignVertical: TextAlignVertical.center,
                              style: TextStyle(
                                fontFamily: MiuiTheme.fontFamily,
                                fontSize: 15,
                                color: isDark ? Colors.white : Colors.black87,
                              ),
                              onChanged: (val) {
                                provider.setSearchQuery(val);
                                setState(() {});
                              },
                              decoration: const InputDecoration(
                                hintText: '', // NO PLACEHOLDER TEXT!
                                border: InputBorder.none,
                                contentPadding: EdgeInsets.zero,
                                isDense: true,
                              ),
                            ),
                          ),

                          // Right side inside search bar -> cross.svg with solid grey color and transparent grey background
                          const SizedBox(width: 8),
                          GestureDetector(
                            onTap: () {
                              _searchController.clear();
                              provider.setSearchQuery('');
                              setState(() {});
                            },
                            child: Container(
                              width: 20,
                              height: 20,
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: isDark
                                    ? Colors.white.withValues(alpha: 0.18)
                                    : Colors.black.withValues(alpha: 0.12), // Transparent grey background!
                              ),
                              alignment: Alignment.center,
                              child: SvgPicture.asset(
                                'resources/cross.svg',
                                width: 16,
                                height: 16,
                                colorFilter: ColorFilter.mode(
                                  isDark ? const Color(0xFFB0B0B0) : const Color(0xFF666666), // Solid grey color!
                                  BlendMode.srcIn,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  // 3rd & 4th Changes: "Cancel" button with Blue text, sliding in from offscreen right
                  AnimatedContainer(
                    duration: const Duration(milliseconds: 300),
                    curve: Curves.easeOutCubic,
                    width: _isSearchHeaderExpanded ? 64 : 0,
                    margin: EdgeInsets.only(left: _isSearchHeaderExpanded ? 12 : 0),
                    clipBehavior: Clip.antiAlias,
                    decoration: const BoxDecoration(),
                    child: SingleChildScrollView(
                      scrollDirection: Axis.horizontal,
                      physics: const NeverScrollableScrollPhysics(),
                      child: SizedBox(
                        width: 64,
                        child: GestureDetector(
                          onTap: () => _closeDedicatedSearch(provider),
                          child: const Text(
                            'Cancel',
                            style: TextStyle(
                              fontFamily: MiuiTheme.fontFamily,
                              fontSize: 16,
                              fontWeight: FontWeight.w500,
                              color: Color(0xFF0C84FF), // Blue Text
                            ),
                            maxLines: 1,
                            softWrap: false,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Search Results Content List Below Header (Only when typing)
            Expanded(
              child: _buildSearchResultsBody(context, provider, isDark),
            ),
          ],
        ),
      ),
    );
  }

  void _openContactDetailsWithShutterAnimation(
    BuildContext context, {
    required String phoneNumber,
    String? contactName,
    String? contactId,
  }) {
    FocusScope.of(context).unfocus();
    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');
    Navigator.push(
      context,
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) => ContactDetailScreen(
          phoneNumber: phoneNumber,
          contactName: contactName,
          contactId: contactId,
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

  Widget _buildHighlightedText({
    required String text,
    required String query,
    required TextStyle baseStyle,
    Color highlightColor = const Color(0xFF0C84FF), // Blue Highlight
    bool highlightOnlyFirstMatch = true,
    FontWeight highlightFontWeight = FontWeight.bold,
  }) {
    if (query.trim().isEmpty || !text.toLowerCase().contains(query.toLowerCase())) {
      return Text(
        text,
        style: baseStyle,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      );
    }

    final List<InlineSpan> spans = [];
    final String lowerText = text.toLowerCase();
    final String lowerQuery = query.toLowerCase();

    if (highlightOnlyFirstMatch) {
      final int firstIndex = lowerText.indexOf(lowerQuery);
      if (firstIndex != -1) {
        if (firstIndex > 0) {
          spans.add(TextSpan(text: text.substring(0, firstIndex), style: baseStyle));
        }
        spans.add(
          TextSpan(
            text: text.substring(firstIndex, firstIndex + lowerQuery.length),
            style: baseStyle.copyWith(
              color: highlightColor,
              fontWeight: highlightFontWeight,
            ),
          ),
        );
        if (firstIndex + lowerQuery.length < text.length) {
          spans.add(TextSpan(text: text.substring(firstIndex + lowerQuery.length), style: baseStyle));
        }
      } else {
        spans.add(TextSpan(text: text, style: baseStyle));
      }
    } else {
      int start = 0;
      while (true) {
        final int index = lowerText.indexOf(lowerQuery, start);
        if (index == -1) {
          spans.add(TextSpan(text: text.substring(start), style: baseStyle));
          break;
        }
        if (index > start) {
          spans.add(TextSpan(text: text.substring(start, index), style: baseStyle));
        }
        spans.add(
          TextSpan(
            text: text.substring(index, index + lowerQuery.length),
            style: baseStyle.copyWith(
              color: highlightColor,
              fontWeight: highlightFontWeight,
            ),
          ),
        );
        start = index + lowerQuery.length;
      }
    }

    return Text.rich(
      TextSpan(children: spans),
      maxLines: 1,
      overflow: TextOverflow.ellipsis,
    );
  }

  Widget _buildSearchResultsBody(BuildContext context, DialerProvider provider, bool isDark) {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      return _buildSearchHistoryList(context, provider, isDark);
    }

    final isDigitSearch = RegExp(r'^\d+$').hasMatch(query);

    var matchedContacts = List.of(provider.filteredContacts);
    var matchedLogs = List.of(provider.groupedCallLogs);

    // Problem 4 & 5: Sorting logic
    if (isDigitSearch) {
      // Problem 5: Digit Search Sorting (Start match -> Top, Middle -> Middle, End -> End)
      int getDigitMatchPosition(String phone, String q) {
        final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
        final cleanQ = q.replaceAll(RegExp(r'\D'), '');
        final idx = cleanPhone.indexOf(cleanQ);
        return idx == -1 ? 9999 : idx;
      }

      matchedContacts.sort((a, b) {
        final posA = getDigitMatchPosition(a.phoneNumber, query);
        final posB = getDigitMatchPosition(b.phoneNumber, query);
        if (posA != posB) return posA.compareTo(posB);
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      matchedLogs.sort((a, b) {
        final posA = getDigitMatchPosition(a.latestEntry.phoneNumber, query);
        final posB = getDigitMatchPosition(b.latestEntry.phoneNumber, query);
        if (posA != posB) return posA.compareTo(posB);
        return a.latestEntry.phoneNumber.compareTo(b.latestEntry.phoneNumber);
      });
    } else {
      // Problem 4: Alphabet Search Sorting (Alphabetical Ascending Order A -> Z)
      matchedContacts.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      matchedLogs.sort((a, b) {
        final nameA = a.latestEntry.contactName.isNotEmpty ? a.latestEntry.contactName : a.latestEntry.phoneNumber;
        final nameB = b.latestEntry.contactName.isNotEmpty ? b.latestEntry.contactName : b.latestEntry.phoneNumber;
        return nameA.toLowerCase().compareTo(nameB.toLowerCase());
      });
    }

    final totalMatches = matchedContacts.length + matchedLogs.length;

    // Case 3: No matching contact found -> Empty State with list_empty_no_contact.webp
    if (totalMatches == 0) {
      return Align(
        alignment: Alignment.topCenter,
        child: Padding(
          padding: const EdgeInsets.only(top: 190),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Image.asset(
                'resources/list_empty_no_contact.webp',
                width: 50,
                height: 50,
                fit: BoxFit.contain,
              ),
              Text(
                'No contacts',
                style: TextStyle(
                  fontFamily: MiuiTheme.fontFamily,
                  fontSize: 12,
                  fontWeight: FontWeight.normal,
                  color: isDark ? Colors.white38 : Colors.black38,
                ),
              ),
            ],
          ),
        ),
      );
    }

    // Case 1 & Case 2: Matching results found -> "$totalMatches found" header & formatted items
    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        // Header: "$totalMatches found"
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            '$totalMatches found',
            style: TextStyle(
              fontFamily: MiuiTheme.fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: isDark ? Colors.white38 : Colors.black38,
            ),
          ),
        ),

        // Matched Contacts List
        ...matchedContacts.map((c) {
          final extraInfo = (c.company != null && c.company!.trim().isNotEmpty)
              ? c.company!.trim()
              : ((c.email != null && c.email!.trim().isNotEmpty) ? c.email!.trim() : '');

          return InkWell(
            onTap: () {
              provider.addSearchHistory(c.name);
              _openContactDetailsWithShutterAnimation(
                context,
                phoneNumber: c.phoneNumber,
                contactName: c.name,
                contactId: c.id,
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12.5),
              child: Row(
                children: [
                  // 1st Column: contact_detail_circle_photo_night.png
                  Image.asset(
                    'resources/contact_detail_circle_photo_night.png',
                    width: 39,
                    height: 39,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 14),

                  // 2nd Column: Contact Name & Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Problem 2: Highlight ONLY FIRST MATCH
                        _buildHighlightedText(
                          text: c.name,
                          query: query,
                          highlightOnlyFirstMatch: true,
                          highlightFontWeight: FontWeight.w500, // Same font weight as baseStyle!
                          baseStyle: TextStyle(
                            fontFamily: MiuiTheme.fontFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        // Problem 1 & 3: Subtitle rendering logic
                        if (isDigitSearch) ...[
                          // Problem 3: Digit Search -> Contact Number (Normal font weight, Highlight FIRST match ONLY)
                          Transform.translate(
                            offset: const Offset(0, -3),
                            child: _buildHighlightedText(
                              text: c.phoneNumber,
                              query: query,
                              highlightOnlyFirstMatch: true,
                              highlightFontWeight: FontWeight.w400, // NORMAL font weight!
                              baseStyle: TextStyle(
                                fontFamily: MiuiTheme.fontFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.w400, // NORMAL font weight!
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ),
                        ] else if (extraInfo.isNotEmpty) ...[
                          // Problem 1: Letter Search -> Extra Info (Normal font weight, Highlight FIRST match ONLY)
                          Transform.translate(
                            offset: const Offset(0, -3),
                            child: _buildHighlightedText(
                              text: extraInfo,
                              query: query,
                              highlightOnlyFirstMatch: true,
                              highlightFontWeight: FontWeight.w400, // NORMAL font weight!
                              baseStyle: TextStyle(
                                fontFamily: MiuiTheme.fontFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.w400, // NORMAL font weight!
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),

        // Matched Call Logs List
        ...matchedLogs.map((g) {
          final log = g.latestEntry;
          final displayName = log.contactName.isNotEmpty ? log.contactName : log.phoneNumber;

          return InkWell(
            onTap: () {
              provider.addSearchHistory(displayName);
              _openContactDetailsWithShutterAnimation(
                context,
                phoneNumber: log.phoneNumber,
                contactName: log.contactName,
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12.5),
              child: Row(
                children: [
                  // 1st Column: contact_detail_circle_photo_night.png
                  Image.asset(
                    'resources/contact_detail_circle_photo_night.png',
                    width: 39,
                    height: 39,
                    fit: BoxFit.contain,
                  ),
                  const SizedBox(width: 14),

                  // 2nd Column: Contact Name & Subtitle
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _buildHighlightedText(
                          text: displayName,
                          query: query,
                          highlightOnlyFirstMatch: true,
                          highlightFontWeight: FontWeight.w500, // Same font weight as baseStyle!
                          baseStyle: TextStyle(
                            fontFamily: MiuiTheme.fontFamily,
                            fontSize: 16,
                            fontWeight: FontWeight.w500,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                        ),
                        if (isDigitSearch) ...[
                          Transform.translate(
                            offset: const Offset(0, -3),
                            child: _buildHighlightedText(
                              text: log.phoneNumber,
                              query: query,
                              highlightOnlyFirstMatch: true,
                              highlightFontWeight: FontWeight.w400, // NORMAL font weight!
                              baseStyle: TextStyle(
                                fontFamily: MiuiTheme.fontFamily,
                                fontSize: 13,
                                fontWeight: FontWeight.w400, // NORMAL font weight!
                                color: isDark ? Colors.white38 : Colors.black38,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildSearchHistoryList(BuildContext context, DialerProvider provider, bool isDark) {
    final history = provider.searchHistory;
    if (history.isEmpty) {
      return const SizedBox.shrink();
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          child: Text(
            'History',
            style: TextStyle(
              fontFamily: MiuiTheme.fontFamily,
              fontSize: 14,
              fontWeight: FontWeight.w400, // Normal font!
              color: isDark ? Colors.white38 : Colors.black38, // Transparent grey color!
            ),
          ),
        ),
        ...history.map((item) {
          return Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Row(
              children: [
                Expanded(
                  child: GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () {
                      _searchController.text = item;
                      _searchController.selection = TextSelection.fromPosition(
                        TextPosition(offset: item.length),
                      );
                      provider.setSearchQuery(item);
                      provider.addSearchHistory(item);
                      setState(() {});
                    },
                    child: Text(
                      item,
                      textAlign: TextAlign.left,
                      style: TextStyle(
                        fontFamily: MiuiTheme.fontFamily,
                        fontSize: 16,
                        fontWeight: FontWeight.w400,
                        color: isDark ? Colors.white : Colors.black87,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                GestureDetector(
                  onTap: () {
                    provider.removeSearchHistoryItem(item);
                  },
                  child: Container(
                    width: 22,
                    height: 22,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isDark
                          ? Colors.white.withValues(alpha: 0.18)
                          : Colors.black.withValues(alpha: 0.12),
                    ),
                    alignment: Alignment.center,
                    child: SvgPicture.asset(
                      'resources/cross.svg',
                      width: 18,
                      height: 18,
                      colorFilter: ColorFilter.mode(
                        isDark ? const Color(0xFFB0B0B0) : const Color(0xFF666666),
                        BlendMode.srcIn,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
          child: Align(
            alignment: Alignment.centerLeft, // Left aligned!
            child: GestureDetector(
              onTap: () {
                provider.clearSearchHistory();
              },
              child: Text(
                'Clear history',
                style: TextStyle(
                  fontFamily: MiuiTheme.fontFamily,
                  fontSize: 16, // Increased size!
                  fontWeight: FontWeight.bold, // Bold font!
                  color: isDark ? Colors.white38 : Colors.black38, // Transparent grey color!
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  String _getFilterLabel(String key) {
    switch (key) {
      case 'missed':
        return 'Missed calls';
      case 'outgoing':
        return 'Outgoing calls';
      case 'answered':
        return 'Answered calls';
      case 'unknown':
        return 'Calls from unknown numbers';
      case 'sim1':
        return 'SIM card 1 calls';
      case 'sim2':
        return 'SIM card 2 calls';
      case 'all':
      default:
        return 'All calls';
    }
  }

  // -------------------------------------------------------------
  // HELPER: BUILD DYNAMIC / STATIC SEARCH BAR WIDGET
  // -------------------------------------------------------------
  Widget _buildSearchBar(BuildContext context, DialerProvider provider, bool isDark, double headerExtent) {
    final progress = (headerExtent / _maxHeaderHeight).clamp(0.0, 1.0);
    final containerHeight = progress * 43.0;
    final topMargin = progress * 7.0;
    final bottomMargin = progress * 8.0;
    final alpha = (progress * 255).round();

    if (progress <= 0.001) {
      return const SizedBox.shrink();
    }

    return GestureDetector(
      onTap: () => _openDedicatedSearch(),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 100),
        curve: Curves.fastOutSlowIn,
        height: containerHeight,
        margin: EdgeInsets.fromLTRB(16, topMargin, 16, bottomMargin),
        padding: const EdgeInsets.symmetric(horizontal: 16),
        decoration: BoxDecoration(
          color: (isDark ? MiuiColors.darkSurface : Colors.white).withAlpha(alpha),
          borderRadius: BorderRadius.circular(24),
        ),
        clipBehavior: Clip.antiAlias,
        child: AnimatedOpacity(
          duration: const Duration(milliseconds: 100),
          curve: Curves.fastOutSlowIn,
          opacity: progress,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // search.svg Icon (Aligned to the LEFT of placeholder text)
              SvgPicture.asset(
                'resources/search.svg',
                width: 18,
                height: 18,
                colorFilter: ColorFilter.mode(
                  Colors.grey.withAlpha(alpha),
                  BlendMode.srcIn,
                ),
              ),
              const SizedBox(width: 10),

              // Placeholder text / search input ("<count> contacts")
              Expanded(
                child: TextField(
                  readOnly: true,
                  onTap: () => _openDedicatedSearch(),
                  textAlignVertical: TextAlignVertical.center,
                  style: TextStyle(
                    fontFamily: MiuiTheme.fontFamily,
                    fontSize: 15,
                    color: Colors.grey.withAlpha(alpha),
                  ),
                  decoration: InputDecoration(
                    hintText: '${provider.contacts.length} contacts',
                    hintStyle: TextStyle(
                      fontFamily: MiuiTheme.fontFamily,
                      fontSize: 14,
                      color: (isDark
                          ? MiuiColors.darkTextSecondary
                          : MiuiColors.lightTextSecondary).withAlpha(alpha),
                    ),
                    border: InputBorder.none,
                    contentPadding: EdgeInsets.zero,
                    isDense: true,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // -------------------------------------------------------------
  // HELPER: SCROLL NOTIFICATION HANDLER FOR LIVE DELTA COLLAPSE
  // -------------------------------------------------------------
  bool _handleScrollNotification(
    ScrollNotification scrollInfo,
    ScrollController scrollController,
    DialerProvider provider,
    int tabIndex,
  ) {
    if (scrollInfo.metrics.axis != Axis.vertical) return false;

    if ((scrollInfo is ScrollStartNotification || scrollInfo is ScrollUpdateNotification) &&
        provider.isDialPadOpen) {
      provider.setDialPadOpen(false);
    }

    final double currentExtent = (tabIndex == 0) ? _recentsHeaderExtent : _contactsHeaderExtent;

    void updateExtent(double newExtent) {
      if (newExtent != currentExtent) {
        setState(() {
          if (tabIndex == 0) {
            _recentsHeaderExtent = newExtent;
          } else {
            _contactsHeaderExtent = newExtent;
          }
        });
      }
    }

    if (scrollInfo is ScrollUpdateNotification) {
      final delta = scrollInfo.scrollDelta ?? 0.0;
      if (delta != 0) {
        final double currentPixels = scrollController.hasClients ? scrollController.position.pixels : 0.0;

        if (delta > 0) {
          // UPWARD DRAG: collapse search bar height & opacity
          if (currentExtent > _minHeaderHeight) {
            final newExtent = (currentExtent - delta).clamp(_minHeaderHeight, _maxHeaderHeight);
            updateExtent(newExtent);
          }
        } else if (delta < 0) {
          // DOWNWARD DRAG: expand search bar height & opacity when near/at top
          if (currentPixels <= 5.0) {
            if (currentExtent < _maxHeaderHeight) {
              final newExtent = (currentExtent - delta).clamp(_minHeaderHeight, _maxHeaderHeight);
              updateExtent(newExtent);
            }
          }
        }
      }
    } else if (scrollInfo is OverscrollNotification) {
      // SHORT LIST OVERSCROLL (e.g. 1-4 entries where content fits without scrolling)
      final overscroll = scrollInfo.overscroll;
      if (overscroll > 0) {
        // Dragging UP: collapse search bar height & opacity
        if (currentExtent > _minHeaderHeight) {
          final newExtent = (currentExtent - overscroll).clamp(_minHeaderHeight, _maxHeaderHeight);
          updateExtent(newExtent);
        }
      } else if (overscroll < 0) {
        // Dragging DOWN: expand search bar height & opacity
        if (currentExtent < _maxHeaderHeight) {
          final newExtent = (currentExtent - overscroll).clamp(_minHeaderHeight, _maxHeaderHeight);
          updateExtent(newExtent);
        }
      }
    } else if (scrollInfo is ScrollEndNotification) {
      // Magnetic snap: snap to min or max depending on 50% threshold
      if (currentExtent < (_maxHeaderHeight / 2) && currentExtent > _minHeaderHeight) {
        updateExtent(_minHeaderHeight);
      } else if (currentExtent >= (_maxHeaderHeight / 2) && currentExtent < _maxHeaderHeight) {
        updateExtent(_maxHeaderHeight);
      }
    }

    return false;
  }

  // -------------------------------------------------------------
  // TAB 0: RECENTS / CALL LOGS
  // -------------------------------------------------------------
  Widget _buildRecentsTab(BuildContext context, DialerProvider provider, bool isDark) {
    final logs = provider.groupedCallLogs;
    const primaryBlue = Color(0xFF0C84FF);

    final filterItems = [
      {'key': 'all', 'label': 'All calls'},
      {'key': 'missed', 'label': 'Missed calls'},
      {'key': 'outgoing', 'label': 'Outgoing calls'},
      {'key': 'answered', 'label': 'Answered calls'},
      {'key': 'unknown', 'label': 'Calls from unknown numbers'},
    ];

    if (provider.activeSimSlots.contains(1)) {
      filterItems.add({'key': 'sim1', 'label': 'SIM card 1 calls'});
    }
    if (provider.activeSimSlots.contains(2)) {
      filterItems.add({'key': 'sim2', 'label': 'SIM card 2 calls'});
    }

    final totalCallLogsCount = provider.callLogs.length;

    Widget recentsContent;
    if (totalCallLogsCount == 0) {
      recentsContent = RefreshIndicator(
        onRefresh: () => provider.fetchDeviceCallLogs(),
        child: Column(
          children: [
            _buildSearchBar(context, provider, isDark, _recentsHeaderExtent),
            Expanded(
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: [
                  SizedBox(
                    height: MediaQuery.of(context).size.height * 0.45,
                    child: Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          SvgPicture.asset(
                            'resources/call-outlined.svg',
                            width: 31,
                            height: 31,
                            colorFilter: ColorFilter.mode(
                              isDark ? Colors.white38 : Colors.black38,
                              BlendMode.srcIn,
                            ),
                          ),
                          const SizedBox(height: 14),
                          Text(
                            'No recent contacts',
                            style: TextStyle(
                              fontFamily: MiuiTheme.fontFamily,
                              fontSize: 13,
                              color: isDark ? MiuiColors.darkTextSecondary : MiuiColors.lightTextSecondary,
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
      );
    } else {
      recentsContent = NotificationListener<ScrollNotification>(
        onNotification: (scrollInfo) => _handleScrollNotification(scrollInfo, _recentsScrollController, provider, 0),
        child: Column(
          children: [
            // 1. Search bar stays stationary (ONLY height and opacity collapse in place)
            _buildSearchBar(context, provider, isDark, _recentsHeaderExtent),

            // 2. Pinned/Fixed Filter Dropdown Button Row (STAYS AT TOP, ALWAYS VISIBLE!)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.start,
                children: [
                  Theme(
                    data: Theme.of(context).copyWith(
                      splashColor: Colors.transparent,
                      highlightColor: Colors.transparent,
                      hoverColor: Colors.transparent,
                    ),
                    child: PopupMenuButton<String>(
                      onSelected: (key) => provider.setRecentsFilter(key),
                      color: isDark ? MiuiColors.darkSurface : Colors.white,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(21),
                      ),
                      clipBehavior: Clip.antiAlias,
                      padding: EdgeInsets.zero,
                      menuPadding: EdgeInsets.zero,
                      elevation: 8,
                      offset: const Offset(-5, -3),
                      itemBuilder: (ctx) {
                        return filterItems.asMap().entries.map((entry) {
                          final idx = entry.key;
                          final item = entry.value;
                          final key = item['key']!;
                          final label = item['label']!;
                          final isSelected = provider.selectedRecentsFilter == key;

                          BorderRadius? itemRadius;
                          if (idx == 0) {
                            itemRadius = const BorderRadius.vertical(top: Radius.circular(21));
                          } else if (idx == filterItems.length - 1) {
                            itemRadius = const BorderRadius.vertical(bottom: Radius.circular(21));
                          }

                          return PopupMenuItem<String>(
                            value: key,
                            padding: EdgeInsets.zero,
                            child: Container(
                              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                              decoration: BoxDecoration(
                                color: isSelected
                                    ? primaryBlue.withAlpha(51)
                                    : Colors.transparent,
                                borderRadius: itemRadius,
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      label,
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TextStyle(
                                        fontFamily: MiuiTheme.fontFamily,
                                        fontSize: 15,
                                        fontWeight: FontWeight.w500,
                                        color: isSelected
                                            ? primaryBlue
                                            : (isDark ? Colors.white : Colors.black87),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  if (isSelected)
                                    SvgPicture.asset(
                                      'resources/checkmark.svg',
                                      width: 18,
                                      height: 18,
                                      colorFilter: const ColorFilter.mode(
                                        primaryBlue,
                                        BlendMode.srcIn,
                                      ),
                                    )
                                  else
                                    const SizedBox(width: 18),
                                ],
                              ),
                            ),
                          );
                        }).toList();
                      },
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            _getFilterLabel(provider.selectedRecentsFilter),
                            style: TextStyle(
                              fontFamily: MiuiTheme.fontFamily,
                              fontSize: 13,
                              fontWeight: FontWeight.normal,
                              color: isDark ? MiuiColors.darkTextSecondary : MiuiColors.lightTextSecondary,
                            ),
                          ),
                          const SizedBox(width: 6),
                          SvgPicture.asset(
                            'resources/arrow-down-up.svg',
                            width: 14,
                            height: 14,
                            colorFilter: ColorFilter.mode(
                              isDark ? MiuiColors.darkTextSecondary : MiuiColors.lightTextSecondary,
                              BlendMode.srcIn,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // 3. Scrollable List of Call Logs or Filter Empty State
            Expanded(
              child: logs.isEmpty
                  ? RefreshIndicator(
                      onRefresh: () => provider.fetchDeviceCallLogs(),
                      child: ListView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: [
                          SizedBox(
                            height: MediaQuery.of(context).size.height * 0.35,
                            child: Center(
                              child: Text(
                                'No ${_getFilterLabel(provider.selectedRecentsFilter).toLowerCase()}',
                                style: TextStyle(
                                  fontFamily: MiuiTheme.fontFamily,
                                  fontSize: 13,
                                  color: isDark ? MiuiColors.darkTextSecondary : MiuiColors.lightTextSecondary,
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      controller: _recentsScrollController,
                      physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
                      itemCount: logs.length,
                      separatorBuilder: (_, _) => const SizedBox.shrink(),
                      itemBuilder: (ctx, i) {
                        return CallLogItem(
                          log: logs[i].latestEntry,
                          count: logs[i].count,
                        );
                      },
                    ),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        recentsContent,

        // Dedicated T9 Search Results View Page in Tab 0
        if (provider.dialPadInput.isNotEmpty)
          Positioned.fill(
            child: Container(
              color: isDark ? MiuiColors.darkBackground : MiuiColors.lightBackground,
              child: _buildT9SearchResultsView(context, provider, isDark),
            ),
          ),

        // Bottom Keypad Slide Sheet Overlay (Embedded in Tab 0: slides out natively with PageView!)
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: GestureDetector(
            onTap: () {}, // Intercept taps on dialpad sheet
            child: AnimatedSlide(
              offset: provider.isDialPadOpen ? Offset.zero : const Offset(0, 1.2),
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (provider.isFirstTimeOnboarding && provider.dialPadInput.isEmpty) ...[
                    _buildFirstTimeOnboardingDialog(context, provider, isDark),
                    const SizedBox(height: 25),
                  ],
                  const MiuiDialpad(),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  // -------------------------------------------------------------
  // TAB 1: CONTACTS
  // -------------------------------------------------------------
  Widget _buildContactsTab(BuildContext context, DialerProvider provider, bool isDark) {
    final contacts = provider.filteredContacts;

    // EMPTY CONTACTS STATE: Search bar in static non-scrolling Column above empty state
    if (contacts.isEmpty) {
      return Column(
        children: [
          _buildSearchBar(context, provider, isDark, _contactsHeaderExtent),
          Expanded(
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.contacts_outlined,
                    size: 64,
                    color: isDark ? Colors.white24 : Colors.black26,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    'No contacts found',
                    style: TextStyle(
                      fontFamily: MiuiTheme.fontFamily,
                      fontSize: 16,
                      color: isDark ? MiuiColors.darkTextSecondary : MiuiColors.lightTextSecondary,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ElevatedButton.icon(
                    onPressed: () => provider.fetchDeviceContacts(),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: const Color(0xFF25D366),
                      foregroundColor: Colors.white,
                    ),
                    icon: const Icon(Icons.refresh, size: 18),
                    label: const Text('Refresh Device Contacts'),
                  ),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // CONTACTS LIST HAS ITEMS: Static search bar at top of Column + CustomScrollView below
    return NotificationListener<ScrollNotification>(
      onNotification: (scrollInfo) => _handleScrollNotification(scrollInfo, _contactsScrollController, provider, 1),
      child: Column(
        children: [
          // Search bar stays stationary (ONLY height and opacity collapse in place)
          _buildSearchBar(context, provider, isDark, _contactsHeaderExtent),

          // Scrollable area below search bar
          Expanded(
            child: CustomScrollView(
              controller: _contactsScrollController,
              physics: const AlwaysScrollableScrollPhysics(parent: ClampingScrollPhysics()),
              slivers: [
                // Create New Contact Tile
                SliverToBoxAdapter(
                  child: Column(
                    children: [
                      ListTile(
                        leading: const CircleAvatar(
                          backgroundColor: Color(0xFF25D366),
                          child: Icon(Icons.person_add, color: Colors.white, size: 20),
                        ),
                        title: const Text(
                          'Create new contact',
                          style: TextStyle(
                            fontFamily: MiuiTheme.fontFamily,
                            fontWeight: FontWeight.w600,
                            color: Color(0xFF25D366),
                          ),
                        ),
                        onTap: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => const ContactFormScreen()),
                          );
                        },
                      ),
                      const Divider(height: 1),
                    ],
                  ),
                ),

                // Contacts List View
                SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (ctx, i) {
                      return Column(
                        children: [
                          ContactTile(contact: contacts[i]),
                          if (i < contacts.length - 1)
                            const Divider(height: 1, indent: 68),
                        ],
                      );
                    },
                    childCount: contacts.length,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _sendSms(String phoneNumber) async {
    const channel = MethodChannel('com.sonoou.callvyndialer/sim');
    try {
      final bool? success = await channel.invokeMethod<bool>('sendSms', {'number': phoneNumber});
      if (success != true) {
        final Uri smsToUri = Uri.parse('smsto:$phoneNumber');
        await launchUrl(smsToUri, mode: LaunchMode.externalNonBrowserApplication);
      }
    } catch (_) {
      try {
        final Uri smsToUri = Uri.parse('smsto:$phoneNumber');
        await launchUrl(smsToUri, mode: LaunchMode.externalNonBrowserApplication);
      } catch (_) {}
    }
  }

  // -------------------------------------------------------------
  // T9 SEARCH MATCH RESULTS VIEW (Dedicated background page)
  // -------------------------------------------------------------
  Widget _buildT9SearchResultsView(BuildContext context, DialerProvider provider, bool isDark) {
    final query = provider.dialPadInput.trim();
    final isDigitSearch = RegExp(r'^\d+$').hasMatch(query);

    var matchedContacts = List.of(provider.filteredContacts);
    var matchedLogs = List.of(provider.groupedCallLogs);

    if (isDigitSearch) {
      int getDigitMatchPosition(String phone, String q) {
        final cleanPhone = phone.replaceAll(RegExp(r'\D'), '');
        final cleanQ = q.replaceAll(RegExp(r'\D'), '');
        final idx = cleanPhone.indexOf(cleanQ);
        return idx == -1 ? 9999 : idx;
      }

      matchedContacts.sort((a, b) {
        final posA = getDigitMatchPosition(a.phoneNumber, query);
        final posB = getDigitMatchPosition(b.phoneNumber, query);
        if (posA != posB) return posA.compareTo(posB);
        return a.name.toLowerCase().compareTo(b.name.toLowerCase());
      });

      matchedLogs.sort((a, b) {
        final posA = getDigitMatchPosition(a.latestEntry.phoneNumber, query);
        final posB = getDigitMatchPosition(b.latestEntry.phoneNumber, query);
        if (posA != posB) return posA.compareTo(posB);
        return a.latestEntry.phoneNumber.compareTo(b.latestEntry.phoneNumber);
      });
    }

    final totalMatches = matchedContacts.length + matchedLogs.length;

    if (totalMatches == 0) {
      const blueColor = Color(0xFF0C84FF);

      return ListView(
        physics: const BouncingScrollPhysics(),
        padding: const EdgeInsets.only(bottom: 340),
        children: [
          // 1st Action: "New contact"
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ContactFormScreen(initialPhone: query),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Text(
                'New contact',
                style: TextStyle(
                  fontFamily: MiuiTheme.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: blueColor,
                ),
              ),
            ),
          ),

          // 2nd Action: "Add to contact"
          InkWell(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => ContactFormScreen(initialPhone: query),
                ),
              );
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Text(
                'Add to contact',
                style: TextStyle(
                  fontFamily: MiuiTheme.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: blueColor,
                ),
              ),
            ),
          ),

          // 3rd Action: "Send message"
          InkWell(
            onTap: () => _sendSms(query),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
              child: Text(
                'Send message',
                style: TextStyle(
                  fontFamily: MiuiTheme.fontFamily,
                  fontSize: 16,
                  fontWeight: FontWeight.w500,
                  color: blueColor,
                ),
              ),
            ),
          ),
        ],
      );
    }

    return ListView(
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.only(bottom: 340),
      children: [
                    // DIRECT LIST (No label, exact current item UI preserved!)
                    ...matchedContacts.map((c) {
                      final extraInfo = (c.company != null && c.company!.trim().isNotEmpty)
                          ? c.company!.trim()
                          : ((c.email != null && c.email!.trim().isNotEmpty) ? c.email!.trim() : '');

                      return InkWell(
                        onTap: () {
                          provider.startCall(
                            number: c.phoneNumber,
                            name: c.name,
                            avatarColor: c.avatarColorValue,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12.5),
                          child: Row(
                            children: [
                              // 1st Column: contact_detail_circle_photo_night.png
                              Image.asset(
                                'resources/contact_detail_circle_photo_night.png',
                                width: 39,
                                height: 39,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 14),

                              // 2nd Column: Contact Name & Subtitle
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildHighlightedText(
                                      text: c.name,
                                      query: query,
                                      highlightOnlyFirstMatch: true,
                                      highlightFontWeight: FontWeight.w500,
                                      baseStyle: TextStyle(
                                        fontFamily: MiuiTheme.fontFamily,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    if (isDigitSearch) ...[
                                      Transform.translate(
                                        offset: const Offset(0, -3),
                                        child: _buildHighlightedText(
                                          text: c.phoneNumber,
                                          query: query,
                                          highlightOnlyFirstMatch: true,
                                          highlightFontWeight: FontWeight.w400,
                                          baseStyle: TextStyle(
                                            fontFamily: MiuiTheme.fontFamily,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                            color: isDark ? Colors.white38 : Colors.black38,
                                          ),
                                        ),
                                      ),
                                    ] else if (extraInfo.isNotEmpty) ...[
                                      Transform.translate(
                                        offset: const Offset(0, -3),
                                        child: _buildHighlightedText(
                                          text: extraInfo,
                                          query: query,
                                          highlightOnlyFirstMatch: true,
                                          highlightFontWeight: FontWeight.w400,
                                          baseStyle: TextStyle(
                                            fontFamily: MiuiTheme.fontFamily,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                            color: isDark ? Colors.white38 : Colors.black38,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),

                              // 3rd Column: Circular Dark Grey Button with Right Arrow SVG
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  _openContactDetailsWithShutterAnimation(
                                    context,
                                    phoneNumber: c.phoneNumber,
                                    contactName: c.name,
                                    contactId: c.id,
                                  );
                                },
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
                        ),
                      );
                    }),

                    ...matchedLogs.map((g) {
                      final log = g.latestEntry;
                      final displayName = log.contactName.isNotEmpty ? log.contactName : log.phoneNumber;

                      return InkWell(
                        onTap: () {
                          provider.startCall(
                            number: log.phoneNumber,
                            name: log.contactName,
                          );
                        },
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12.5),
                          child: Row(
                            children: [
                              // 1st Column: contact_detail_circle_photo_night.png
                              Image.asset(
                                'resources/contact_detail_circle_photo_night.png',
                                width: 39,
                                height: 39,
                                fit: BoxFit.contain,
                              ),
                              const SizedBox(width: 14),

                              // 2nd Column: Contact Name & Subtitle
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    _buildHighlightedText(
                                      text: displayName,
                                      query: query,
                                      highlightOnlyFirstMatch: true,
                                      highlightFontWeight: FontWeight.w500,
                                      baseStyle: TextStyle(
                                        fontFamily: MiuiTheme.fontFamily,
                                        fontSize: 16,
                                        fontWeight: FontWeight.w500,
                                        color: isDark ? Colors.white : Colors.black87,
                                      ),
                                    ),
                                    if (isDigitSearch) ...[
                                      Transform.translate(
                                        offset: const Offset(0, -3),
                                        child: _buildHighlightedText(
                                          text: log.phoneNumber,
                                          query: query,
                                          highlightOnlyFirstMatch: true,
                                          highlightFontWeight: FontWeight.w400,
                                          baseStyle: TextStyle(
                                            fontFamily: MiuiTheme.fontFamily,
                                            fontSize: 13,
                                            fontWeight: FontWeight.w400,
                                            color: isDark ? Colors.white38 : Colors.black38,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),

                              // 3rd Column: Circular Dark Grey Button with Right Arrow SVG
                              GestureDetector(
                                behavior: HitTestBehavior.opaque,
                                onTap: () {
                                  _openContactDetailsWithShutterAnimation(
                                    context,
                                    phoneNumber: log.phoneNumber,
                                    contactName: log.contactName,
                                  );
                                },
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
                        ),
                      );
                    }),
                  ],
                );
  }

  // -------------------------------------------------------------
  // FIRST TIME ONBOARDING DIALOG CARD (20dp gap above dialpad)
  // -------------------------------------------------------------
  Widget _buildFirstTimeOnboardingDialog(BuildContext context, DialerProvider provider, bool isDark) {
    final greenColor = const Color(0xFF25D366);
    final cardBgColor = isDark ? const Color(0xFF1E2633) : Colors.white;

    return GestureDetector(
      onTap: () => provider.dismissFirstTimeOnboarding(),
      child: Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.bottomCenter,
        children: [
          Container(
            margin: const EdgeInsets.symmetric(horizontal: 16),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: cardBgColor,
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withAlpha(isDark ? 90 : 35),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Enter number to find contacts',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontFamily: MiuiTheme.fontFamily,
                    fontSize: 13,
                    fontWeight: FontWeight.normal,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 1),
                RichText(
                  textAlign: TextAlign.center,
                  text: TextSpan(
                    style: TextStyle(
                      fontFamily: MiuiTheme.fontFamily,
                      fontSize: 13,
                      fontWeight: FontWeight.normal,
                      color: Colors.white,
                    ),
                    text: 'Enter "3" and "7" to search for "Debbie Smith"',
                  ),
                ),
                const SizedBox(height: 17),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    // 3 DEF key badge with 1px border and D highlighted in green
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 35, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? Colors.white12 : Colors.black12, width: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '3',
                            style: TextStyle(
                              fontFamily: MiuiTheme.fontFamily,
                              fontSize: 28,
                              fontWeight: FontWeight.normal,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontFamily: MiuiTheme.fontFamily,
                                fontSize: 10,
                                fontWeight: FontWeight.normal,
                                color: isDark ? Colors.white60 : Colors.black45,
                              ),
                              children: [
                                TextSpan(text: 'D', style: TextStyle(color: greenColor)),
                                const TextSpan(text: 'EF'),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 12),
                      child: Text(
                        '+',
                        style: TextStyle(
                          fontFamily: MiuiTheme.fontFamily,
                          fontSize: 18,
                          fontWeight: FontWeight.normal,
                          color: isDark ? Colors.white70 : Colors.black54,
                        ),
                      ),
                    ),
                    // 7 PQRS key badge with 1px border and S highlighted in green
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 30, vertical: 4),
                      decoration: BoxDecoration(
                        border: Border.all(color: isDark ? Colors.white12 : Colors.black12, width: 0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            '7',
                            style: TextStyle(
                              fontFamily: MiuiTheme.fontFamily,
                              fontSize: 28,
                              fontWeight: FontWeight.normal,
                              color: isDark ? Colors.white : Colors.black87,
                            ),
                          ),
                          RichText(
                            text: TextSpan(
                              style: TextStyle(
                                fontFamily: MiuiTheme.fontFamily,
                                fontSize: 10,
                                fontWeight: FontWeight.normal,
                                color: isDark ? Colors.white60 : Colors.black45,
                              ),
                              children: [
                                const TextSpan(text: 'PQR'),
                                TextSpan(text: 'S', style: TextStyle(color: greenColor)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Attached Horizontally Centered Down Arrow Pointer (down-arrow-filled.svg)
          Positioned(
            bottom: -16,
            child: SvgPicture.asset(
              'resources/down-arrow-filled.svg',
              width: 30,
              height: 24,
              colorFilter: ColorFilter.mode(
                cardBgColor,
                BlendMode.srcIn,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSingleSimCallButtonLayer(BuildContext context, DialerProvider provider, double translationX) {
    return Transform.translate(
      offset: Offset(translationX, 0),
      child: AnimatedAlign(
        alignment: provider.isDialPadOpen
            ? Alignment.bottomCenter
            : Alignment.bottomRight,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: EdgeInsets.only(
            right: provider.isDialPadOpen ? 0 : 20,
          ),
          child: AnimatedRotation(
            turns: provider.isDialPadOpen ? (-90 / 360) : 0.0, // Live 0° -> 90° anti-clockwise rotation!
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 300),
              curve: Curves.easeOutCubic,
              width: provider.isDialPadOpen ? 66 : 56,
              height: provider.isDialPadOpen ? 66 : 56,
              child: FloatingActionButton(
                onPressed: () {
                  if (provider.isDialPadOpen) {
                    provider.handleCallButtonPress(simSlot: 1);
                  } else {
                    provider.toggleDialPad();
                  }
                },
                backgroundColor: const Color(0xFF25D366),
                child: provider.isDialPadOpen
                    ? AnimatedContainer(
                        duration: const Duration(milliseconds: 300),
                        curve: Curves.easeOutCubic,
                        width: provider.isDialPadOpen ? 34 : 24,
                        height: provider.isDialPadOpen ? 34 : 24,
                        child: Image.asset(
                          'resources/dialer_btn_call_pressed.webp',
                          fit: BoxFit.contain,
                        ),
                      )
                    : Transform.scale(
                        scaleY: -1, // Vertical flip to position single dot at the top
                        child: const Icon(Icons.dialpad, color: Colors.white, size: 24),
                      ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildDualSimCallButtonLayer(BuildContext context, DialerProvider provider, double translationX) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final dialerBgColor = isDark ? MiuiColors.darkBackground : MiuiColors.lightBackground;
    final double targetWidth = provider.isDialPadOpen
        ? (MediaQuery.of(context).size.width * 0.72 - 110.0).clamp(130.0, 175.0)
        : 56.0;
    final double targetHeight = provider.isDialPadOpen ? 41.0 : 56.0;
    final double targetRadius = targetHeight / 2;

    return Transform.translate(
      offset: Offset(translationX, provider.isDialPadOpen ? -15.0 : 0.0),
      child: AnimatedAlign(
        alignment: provider.isDialPadOpen
            ? Alignment.bottomCenter
            : Alignment.bottomRight,
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeOutCubic,
        child: Padding(
          padding: EdgeInsets.only(
            right: provider.isDialPadOpen ? 0 : 20,
          ),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
            width: targetWidth,
            height: targetHeight,
            decoration: BoxDecoration(
              color: const Color(0xFF25D366),
              borderRadius: BorderRadius.circular(targetRadius),
              boxShadow: const [
                BoxShadow(
                  color: Colors.black26,
                  blurRadius: 8,
                  offset: Offset(0, 3),
                ),
              ],
            ),
            clipBehavior: Clip.antiAlias,
            child: Stack(
              fit: StackFit.expand,
              alignment: Alignment.center,
              children: [
                // 10 Dots Button (Visible when dialpad is closed)
                AnimatedOpacity(
                  opacity: provider.isDialPadOpen ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  curve: Curves.easeInOut,
                  child: IgnorePointer(
                    ignoring: provider.isDialPadOpen,
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: () => provider.toggleDialPad(),
                        child: Center(
                          child: Transform.scale(
                            scaleY: -1, // Vertical flip to position single dot at the top
                            child: const Icon(Icons.dialpad, color: Colors.white, size: 24),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),

                // Dual SIM Expanded View (Visible when dialpad is open)
                AnimatedOpacity(
                  opacity: provider.isDialPadOpen ? 1.0 : 0.0,
                  duration: const Duration(milliseconds: 250),
                  curve: Curves.easeIn,
                  child: IgnorePointer(
                    ignoring: !provider.isDialPadOpen,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        // SIM 1 (Left Child)
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => provider.handleCallButtonPress(simSlot: 1),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        'resources/call_btn_icon_sim1.webp',
                                        width: 17,
                                        height: 17,
                                        fit: BoxFit.contain,
                                      ),
                                      const SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          provider.sim1Name,
                                          style: const TextStyle(
                                            fontFamily: MiuiTheme.fontFamily,
                                            color: Colors.white,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            height: 1.0,
                                          ),
                                          textAlign: TextAlign.center,
                                          softWrap: true,
                                          maxLines: 2,
                                          overflow: TextOverflow.visible,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),
                        ),

                        // End-to-End Separator Line matching Dialer Background Color
                        Container(
                          width: 2.0,
                          height: double.infinity,
                          color: dialerBgColor,
                        ),

                        // SIM 2 (Right Child)
                        Expanded(
                          child: Material(
                            color: Colors.transparent,
                            child: InkWell(
                              onTap: () => provider.handleCallButtonPress(simSlot: 2),
                              child: Center(
                                child: Padding(
                                  padding: const EdgeInsets.symmetric(horizontal: 4),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Image.asset(
                                        'resources/call_btn_icon_sim2.webp',
                                        width: 17,
                                        height: 17,
                                        fit: BoxFit.contain,
                                      ),
                                      const SizedBox(width: 3),
                                      Flexible(
                                        child: Text(
                                          provider.sim2Name,
                                          style: const TextStyle(
                                            fontFamily: MiuiTheme.fontFamily,
                                            color: Colors.white,
                                            fontSize: 10.5,
                                            fontWeight: FontWeight.w600,
                                            height: 1.0,
                                          ),
                                          textAlign: TextAlign.center,
                                          softWrap: true,
                                          maxLines: 2,
                                          overflow: TextOverflow.visible,
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
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}


