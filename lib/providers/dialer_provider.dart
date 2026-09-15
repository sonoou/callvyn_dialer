import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_contacts/flutter_contacts.dart' as fc;
import 'package:intl/intl.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/call_log.dart';
import '../models/contact.dart';
import '../theme/miui_theme.dart';
import '../utils/phone_number_helper.dart';
import '../utils/t9_search.dart';

enum ActiveCallStatus {
  none,
  incoming,
  outgoing,
  active,
  ended,
}

class DialerProvider extends ChangeNotifier {
  // Empty initial contacts (No fake data)
  final List<Contact> _contacts = [];

  // Empty initial call logs (No fake data)
  final List<CallLogEntry> _callLogs = [];

  static const List<int> _colorPalette = [
    0xFF0C84FF,
    0xFF25D366,
    0xFFFF3B30,
    0xFFFF9500,
    0xFF9C27B0,
    0xFF00C6FF,
    0xFF4CAF50,
    0xFFE91E63,
  ];

  // Settings & Navigation State
  int _selectedTabIndex = 0; // 0: Recents/Call (default), 1: Contacts, 2: Settings
  String _selectedRecentsFilter = 'all'; // 'all', 'missed', 'recorded'
  String _searchQuery = '';
  String _dialPadInput = '';
  bool _isDialPadOpen = true;
  bool _isFirstTimeOnboarding = true;
  ThemeMode _themeMode = ThemeMode.dark;
  final List<String> _searchHistory = [];
  List<String> get searchHistory => _searchHistory;

  void addSearchHistory(String query) {
    if (query.trim().isEmpty) return;
    _searchHistory.remove(query.trim());
    _searchHistory.insert(0, query.trim());
    notifyListeners();
  }

  void removeSearchHistoryItem(String query) {
    _searchHistory.remove(query);
    notifyListeners();
  }

  void clearSearchHistory() {
    _searchHistory.clear();
    notifyListeners();
  }

  bool get isFirstTimeOnboarding => _isFirstTimeOnboarding;
  String _dialPadTones = 'piano'; // 'piano', 'standard', 'silent'
  bool _hapticsEnabled = true;
  bool _autoRecordEnabled = false;
  String _sim1Name = 'Jio 5G';
  String _sim2Name = 'Airtel 5G';
  final Set<String> _blockedNumbers = {};
  final Map<String, String> _ussdLogMap = {
    '06': '*#06#',
    '0': '*#0*#',
    '4636': '*#*#4636#*#*',
    '34971539': '*#*#34971539#*#*',
    '1111': '*#*#1111#*#*',
    '2222': '*#*#2222#*#*',
    '44336': '*#*#44336#*#*',
  };

  void _saveUssdLogMap() {
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('ussdLogMap', jsonEncode(_ussdLogMap));
    });
  }

  // Active Call State
  ActiveCallStatus _callStatus = ActiveCallStatus.none;
  String? _activeCallName;
  String _activeCallNumber = '';
  final int _activeCallAvatarColor = 0xFF0C84FF;
  int _activeSimSlot = 1;
  int _callDurationSeconds = 0;
  Timer? _callTimer;
  bool _isMuted = false;
  bool _isSpeaker = false;
  bool _isOnHold = false;
  bool _isRecording = false;
  int _recordingSeconds = 0;
  String _inCallKeypadInput = '';
  bool _showInCallKeypad = false;
  bool _isIncomingSession = false;
  bool _isVideoCall = false;
  bool get isVideoCall => _isVideoCall;
  bool _hasIncomingVideoUpgradeRequest = false;
  bool get hasIncomingVideoUpgradeRequest => _hasIncomingVideoUpgradeRequest;
  int? _remoteTextureId;
  int? get remoteTextureId => _remoteTextureId;
  int? _localTextureId;
  int? get localTextureId => _localTextureId;

  // Fast O(1) Contact Lookup Map by phone number (raw, digits, cleaned, normalized)
  final Map<String, Contact> _contactLookupMap = {};

  static const MethodChannel _simChannel = MethodChannel('com.sonoou.callvyndialer/sim');
  List<int> _activeSimSlots = [];

  Uint8List? _wallpaperBytes;
  Uint8List? get wallpaperBytes => _wallpaperBytes;

  DialerProvider() {
    _initCallStateChannel();
    _loadPreferences();
    _initStartupData();
  }

  void _initStartupData() {
    // Run data fetching asynchronously without blocking UI initialization
    Future.microtask(() async {
      await fetchDeviceContacts();
      await fetchDeviceCallLogs();
      loadActiveSimSlots();
      loadWallpaper();
      _initBatteryAndForegroundService();
    });
  }

  Future<void> fetchVideoTextures() async {
    try {
      final dynamic res = await _simChannel.invokeMethod('getVideoTextures');
      if (res is Map) {
        _remoteTextureId = (res['remoteTextureId'] as num?)?.toInt();
        _localTextureId = (res['localTextureId'] as num?)?.toInt();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching video textures: $e');
    }
  }

  Future<void> _initBatteryAndForegroundService() async {
    try {
      await _simChannel.invokeMethod('startForegroundService');
      final bool? isIgnoring = await _simChannel.invokeMethod<bool>('isIgnoringBatteryOptimizations');
      if (isIgnoring == false) {
        await _simChannel.invokeMethod('requestIgnoreBatteryOptimizations');
      }
    } catch (e) {
      debugPrint('Error initializing battery/foreground service: $e');
    }
  }

  Future<void> requestIgnoreBatteryOptimizations() async {
    try {
      await _simChannel.invokeMethod('requestIgnoreBatteryOptimizations');
    } catch (e) {
      debugPrint('Error requesting unrestricted battery: $e');
    }
  }

  Future<void> loadWallpaper() async {
    try {
      final dynamic res = await _simChannel.invokeMethod('getWallpaper');
      if (res != null) {
        _wallpaperBytes = res as Uint8List;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error loading wallpaper: $e');
    }
  }

  void _initCallStateChannel() {
    _simChannel.setMethodCallHandler((call) async {
      if (call.method == 'onVideoUpgradeRequested') {
        final Map<dynamic, dynamic>? args = call.arguments as Map<dynamic, dynamic>?;
        _hasIncomingVideoUpgradeRequest = true;
        _remoteTextureId = (args?['remoteTextureId'] as num?)?.toInt();
        _localTextureId = (args?['localTextureId'] as num?)?.toInt();
        notifyListeners();
      } else if (call.method == 'onVideoStateChanged') {
        final Map<dynamic, dynamic>? args = call.arguments as Map<dynamic, dynamic>?;
        final bool isVideo = args?['isVideo'] == true;
        _isVideoCall = isVideo;
        if (isVideo) {
          _hasIncomingVideoUpgradeRequest = false;
        }
        _remoteTextureId = (args?['remoteTextureId'] as num?)?.toInt();
        _localTextureId = (args?['localTextureId'] as num?)?.toInt();
        notifyListeners();
      } else if (call.method == 'onCallStateChanged') {
        final Map<dynamic, dynamic>? args = call.arguments as Map<dynamic, dynamic>?;
        final String state = args?['state'] ?? '';
        final String number = args?['number'] ?? '';
        final bool isVideo = args?['isVideo'] == true;
        _remoteTextureId = (args?['remoteTextureId'] as num?)?.toInt();
        _localTextureId = (args?['localTextureId'] as num?)?.toInt();
        if (state == 'ACTIVE') {
          if (isVideo) _isVideoCall = true;
          _connectCall();
        } else if (state == 'DISCONNECTED') {
          endCall();
        } else if (state == 'DIALING') {
          if (_callStatus == ActiveCallStatus.none && number.isNotEmpty) {
            startCall(number: number, isVideoCall: isVideo);
          }
        } else if (state == 'RINGING') {
          final validNum = number.trim().isNotEmpty ? number.trim() : 'Unknown Caller';
          final String? passedName = (args?['name'] != null && (args!['name'] as String).isNotEmpty)
              ? args['name'] as String
              : null;
          final int passedSim = (args?['simSlot'] as int?) ?? 1;

          final Contact? matchedContact = findContactByNumber(validNum);
          final String? finalName = passedName ?? matchedContact?.name;

          startCall(
            number: validNum,
            name: finalName,
            simSlot: passedSim,
            isIncoming: true,
            isVideoCall: isVideo,
          );

          // Asynchronously resolve contact name in background if missing
          if (finalName == null && _contacts.isEmpty) {
            fetchDeviceContacts().then((_) {
              final Contact? found = findContactByNumber(validNum);
              if (found != null && (_activeCallName == null || _activeCallName!.isEmpty)) {
                _activeCallName = found.name;
                notifyListeners();
              }
            });
          }
        }
      }
    });
  }

  Future<void> requestDefaultDialer() async {
    try {
      await _simChannel.invokeMethod('requestDefaultDialer');
    } catch (e) {
      debugPrint('Error requesting default dialer: $e');
    }
  }

  Future<void> loadActiveSimSlots() async {
    try {
      final List<dynamic>? res = await _simChannel.invokeMethod('getActiveSimSlots');
      if (res != null && res.isNotEmpty) {
        _activeSimSlots = res.cast<int>();
      } else {
        final status = await Permission.phone.request();
        if (status.isGranted) {
          final List<dynamic>? retryRes = await _simChannel.invokeMethod('getActiveSimSlots');
          if (retryRes != null && retryRes.isNotEmpty) {
            _activeSimSlots = retryRes.cast<int>();
          }
        }
      }

      final List<dynamic>? details = await _simChannel.invokeMethod('getSimDetails');
      if (details != null && details.isNotEmpty) {
        for (final item in details) {
          final map = item as Map<dynamic, dynamic>;
          final slot = map['slot'] as int?;
          final name = map['name']?.toString();
          if (slot == 1 && name != null && name.isNotEmpty) {
            _sim1Name = name;
          } else if (slot == 2 && name != null && name.isNotEmpty) {
            _sim2Name = name;
          }
        }
      }
      notifyListeners();
    } catch (e) {
      debugPrint('Error fetching active SIM slots: $e');
    }
  }

  List<int> get activeSimSlots => List.unmodifiable(_activeSimSlots);
  bool get isDualSim => _activeSimSlots.length >= 2;

  // Getters
  List<Contact> get contacts => List.unmodifiable(_contacts);
  List<CallLogEntry> get callLogs => List.unmodifiable(_callLogs);
  int get selectedTabIndex => _selectedTabIndex;
  String get selectedRecentsFilter => _selectedRecentsFilter;
  String get searchQuery => _searchQuery;
  String get dialPadInput => _dialPadInput;
  bool get isDialPadOpen => _isDialPadOpen;
  ThemeMode get themeMode => _themeMode;
  String get dialPadTones => _dialPadTones;
  bool get hapticsEnabled => _hapticsEnabled;
  bool get autoRecordEnabled => _autoRecordEnabled;
  String get sim1Name => _sim1Name;
  String get sim2Name => _sim2Name;
  Set<String> get blockedNumbers => _blockedNumbers;

  // Active Call Getters
  ActiveCallStatus get callStatus => _callStatus;
  bool get inCall => _callStatus != ActiveCallStatus.none;
  String? get activeCallName => _activeCallName;
  String get activeCallNumber => _activeCallNumber;
  int get activeCallAvatarColor => _activeCallAvatarColor;
  int get activeSimSlot => _activeSimSlot;
  int get callDurationSeconds => _callDurationSeconds;
  bool get isMuted => _isMuted;
  bool get isSpeaker => _isSpeaker;
  bool get isOnHold => _isOnHold;
  bool get isRecording => _isRecording;
  int get recordingSeconds => _recordingSeconds;
  String get inCallKeypadInput => _inCallKeypadInput;
  bool get showInCallKeypad => _showInCallKeypad;
  bool get isIncomingSession => _isIncomingSession;

  void _indexSingleContact(Contact contact) {
    final raw = contact.phoneNumber.trim();
    if (raw.isNotEmpty) {
      _contactLookupMap[raw] = contact;
    }
    final digits = PhoneNumberHelper.digitsOnly(raw);
    if (digits.isNotEmpty) {
      _contactLookupMap[digits] = contact;
      if (digits.length >= 10) {
        _contactLookupMap[digits.substring(digits.length - 10)] = contact;
      }
    }
    final normalized = PhoneNumberHelper.normalize(raw);
    if (normalized.isNotEmpty) {
      _contactLookupMap[normalized] = contact;
    }
    final cleaned = PhoneNumberHelper.clean(raw);
    if (cleaned.isNotEmpty) {
      _contactLookupMap[cleaned] = contact;
    }
  }

  // Fast O(1) Contact Lookup (supports +91, 0, spaces, dashes)
  Contact? findContactByNumber(String? number) {
    if (number == null || number.trim().isEmpty) return null;
    final trimmed = number.trim();
    Contact? found = _contactLookupMap[trimmed];
    if (found != null) return found;

    final normalized = PhoneNumberHelper.normalize(trimmed);
    if (normalized.isNotEmpty) {
      found = _contactLookupMap[normalized];
      if (found != null) return found;
    }

    final digits = PhoneNumberHelper.digitsOnly(trimmed);
    if (digits.isNotEmpty) {
      found = _contactLookupMap[digits];
      if (found != null) return found;
      if (digits.length >= 10) {
        found = _contactLookupMap[digits.substring(digits.length - 10)];
        if (found != null) return found;
      }
    }

    final cleaned = PhoneNumberHelper.clean(trimmed);
    if (cleaned.isNotEmpty) {
      found = _contactLookupMap[cleaned];
      if (found != null) return found;
    }

    // Fallback scan
    for (final contact in _contacts) {
      if (PhoneNumberHelper.isMatch(contact.phoneNumber, number)) {
        return contact;
      }
    }
    return null;
  }

  // Synchronize existing call logs with loaded contacts
  void _syncCallLogsWithContacts() {
    bool changed = false;
    for (int i = 0; i < _callLogs.length; i++) {
      final log = _callLogs[i];
      final matched = findContactByNumber(log.phoneNumber);
      if (matched != null) {
        if (log.contactName != matched.name || log.contactId != matched.id) {
          _callLogs[i] = log.copyWith(
            contactName: matched.name,
            contactId: matched.id,
          );
          changed = true;
        }
      }
    }
    if (changed) {
      notifyListeners();
    }
  }

  // Filtered Lists
  List<Contact> get favoriteContacts =>
      _contacts.where((c) => c.isFavorite && !c.isBlocked).toList();

  List<Contact> get filteredContacts {
    if (_searchQuery.trim().isEmpty && _dialPadInput.isEmpty) {
      final list = _contacts.where((c) => !c.isBlocked).toList();
      list.sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));
      return list;
    }
    final q = _searchQuery.isNotEmpty ? _searchQuery : _dialPadInput;
    final lowerQ = q.toLowerCase();
    return _contacts
        .where((c) =>
            !c.isBlocked &&
            (T9Search.matches(c.name, c.phoneNumber, q) ||
             (c.company != null && c.company!.toLowerCase().contains(lowerQ)) ||
             (c.email != null && c.email!.toLowerCase().contains(lowerQ))))
        .toList();
  }

  List<CallLogEntry> get filteredCallLogs {
    Iterable<CallLogEntry> list = _callLogs;

    switch (_selectedRecentsFilter) {
      case 'missed':
        list = list.where((l) => l.callType == CallType.missed);
        break;
      case 'outgoing':
        list = list.where((l) => l.callType == CallType.outgoing);
        break;
      case 'answered':
        list = list.where((l) => l.callType == CallType.incoming);
        break;
      case 'unknown':
        list = list.where((l) =>
            l.contactId == null &&
            findContactByNumber(l.phoneNumber) == null);
        break;
      case 'sim1':
        list = list.where((l) => l.simSlot == 1);
        break;
      case 'sim2':
        list = list.where((l) => l.simSlot == 2);
        break;
      case 'all':
      default:
        break;
    }

    final q = _searchQuery.isNotEmpty ? _searchQuery : _dialPadInput;
    if (q.trim().isNotEmpty) {
      list = list.where((l) => T9Search.matches(l.contactName, l.phoneNumber, q));
    }

    final result = list.toList();
    result.sort((a, b) => b.timestamp.compareTo(a.timestamp));
    return result;
  }

  // Grouped call logs getter (Single entry per contact/number with count)
  List<GroupedCallLog> get groupedCallLogs {
    final rawLogs = filteredCallLogs;
    final Map<String, List<CallLogEntry>> groupedMap = {};

    for (final log in rawLogs) {
      final normalized = PhoneNumberHelper.normalize(log.phoneNumber);
      final mapKey = normalized.isNotEmpty ? normalized : log.phoneNumber;
      if (!groupedMap.containsKey(mapKey)) {
        groupedMap[mapKey] = [];
      }
      groupedMap[mapKey]!.add(log);
    }

    final List<GroupedCallLog> result = [];
    groupedMap.forEach((key, entries) {
      entries.sort((a, b) => b.timestamp.compareTo(a.timestamp));
      result.add(
        GroupedCallLog(
          latestEntry: entries.first,
          count: entries.length,
          allEntries: entries,
        ),
      );
    });

    result.sort((a, b) => b.latestEntry.timestamp.compareTo(a.latestEntry.timestamp));
    return result;
  }

  // Load Real Device Call Logs from Android System via Native MethodChannel
  Future<void> fetchDeviceCallLogs() async {
    try {
      bool canAccess = await Permission.phone.isGranted || await Permission.contacts.isGranted;
      if (!canAccess) {
        final status = await Permission.phone.request();
        canAccess = status.isGranted;
      }

      if (canAccess) {
        final List<dynamic>? res = await _simChannel.invokeMethod('getCallLogs');
        if (res != null) {
          _callLogs.clear();
          for (final raw in res) {
            final Map<dynamic, dynamic> item = raw as Map<dynamic, dynamic>;
            final String id = item['id']?.toString() ?? '';
            String num = item['number']?.toString() ?? '';
            if (num.isEmpty) continue;

            final digitsOnly = num.replaceAll(RegExp(r'\D'), '');
            if (_ussdLogMap.containsKey(num)) {
              num = _ussdLogMap[num]!;
            } else if (digitsOnly.isNotEmpty && _ussdLogMap.containsKey(digitsOnly)) {
              num = _ussdLogMap[digitsOnly]!;
            }

            final String name = item['name']?.toString() ?? '';
            final int timestampMs = item['date'] as int? ?? DateTime.now().millisecondsSinceEpoch;
            final int duration = item['duration'] as int? ?? 0;
            final int rawType = item['type'] as int? ?? 1;
            final String accountId = item['accountId']?.toString() ?? '';

            CallType cType = CallType.incoming;
            switch (rawType) {
              case 1:
                cType = CallType.incoming;
                break;
              case 2:
                cType = CallType.outgoing;
                break;
              case 3:
                cType = CallType.missed;
                break;
              case 5:
                cType = CallType.rejected;
                break;
              case 6:
                cType = CallType.blocked;
                break;
              default:
                cType = CallType.incoming;
            }

            final Contact? matched = findContactByNumber(num);
            final String resolvedName = (name.isNotEmpty && name != num)
                ? name
                : (matched?.name ?? (name.isNotEmpty ? name : num));

            _callLogs.add(
              CallLogEntry(
                id: id.isNotEmpty ? id : 'sys_${_callLogs.length + 1}',
                contactId: matched?.id,
                contactName: resolvedName,
                phoneNumber: num,
                timestamp: DateTime.fromMillisecondsSinceEpoch(timestampMs),
                durationSeconds: duration,
                callType: cType,
                simSlot: accountId.contains('2') ? 2 : 1,
                location: 'Mobile, India',
              ),
            );
          }
          notifyListeners();
        }
      }
    } catch (e) {
      debugPrint('Error fetching device call logs: $e');
    }
  }

  // Load Real Device Contacts
  Future<void> fetchDeviceContacts() async {
    try {
      bool isGranted = await Permission.contacts.isGranted;
      if (!isGranted) {
        final status = await Permission.contacts.request();
        isGranted = status.isGranted;
      }

      if (isGranted) {
        final deviceContacts = await fc.FlutterContacts.getAll(
          properties: {
            fc.ContactProperty.phone,
            fc.ContactProperty.email,
            fc.ContactProperty.organization,
            fc.ContactProperty.photoThumbnail,
          },
        );
        _contacts.clear();
        _contactLookupMap.clear();
        for (var i = 0; i < deviceContacts.length; i++) {
          final c = deviceContacts[i];
          final String displayName = c.displayName ?? '';
          final String phone = c.phones.isNotEmpty ? c.phones.first.number : '';
          if (displayName.isNotEmpty || phone.isNotEmpty) {
            final Uint8List? thumb = c.photo?.thumbnail;
            final contact = Contact(
              id: c.id ?? 'c_$i',
              name: displayName.isNotEmpty ? displayName : (phone.isNotEmpty ? phone : 'Unknown'),
              phoneNumber: phone.isNotEmpty ? phone : 'No number',
              email: c.emails.isNotEmpty ? c.emails.first.address : null,
              company: c.organizations.isNotEmpty ? c.organizations.first.name : null,
              label: 'Mobile',
              photoThumbnail: (thumb != null && thumb.isNotEmpty) ? thumb : null,
              avatarColorValue: _colorPalette[i % _colorPalette.length],
            );
            _contacts.add(contact);
            _indexSingleContact(contact);
          }
        }
        _syncCallLogsWithContacts();
        notifyListeners();
      }
    } catch (e) {
      debugPrint('Error fetching device contacts: $e');
    }
  }

  // Load / Save Preferences
  Future<void> _loadPreferences() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      _dialPadTones = prefs.getString('dialPadTones') ?? 'piano';
      _hapticsEnabled = prefs.getBool('hapticsEnabled') ?? true;
      _autoRecordEnabled = prefs.getBool('autoRecordEnabled') ?? false;
      _sim1Name = prefs.getString('sim1Name') ?? 'Jio 5G';
      _sim2Name = prefs.getString('sim2Name') ?? 'Airtel 5G';
      final isDark = prefs.getBool('isDarkMode') ?? true;
      _themeMode = isDark ? ThemeMode.dark : ThemeMode.light;
      _isFirstTimeOnboarding = prefs.getBool('isFirstTimeOnboarding') ?? true;

      final savedMapJson = prefs.getString('ussdLogMap');
      if (savedMapJson != null && savedMapJson.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(savedMapJson);
        decoded.forEach((key, value) {
          _ussdLogMap[key] = value.toString();
        });
      }

      final savedContactRingtones = prefs.getString('contactRingtones');
      if (savedContactRingtones != null && savedContactRingtones.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(savedContactRingtones);
        decoded.forEach((k, v) => _contactRingtones[k] = v.toString());
      }

      final savedContactRingtoneUris = prefs.getString('contactRingtoneUris');
      if (savedContactRingtoneUris != null && savedContactRingtoneUris.isNotEmpty) {
        final Map<String, dynamic> decoded = jsonDecode(savedContactRingtoneUris);
        decoded.forEach((k, v) => _contactRingtoneUris[k] = v.toString());
      }

      final savedMyRingtones = prefs.getString('myRingtonesList');
      if (savedMyRingtones != null && savedMyRingtones.isNotEmpty) {
        final List<dynamic> decoded = jsonDecode(savedMyRingtones);
        _myRingtones.clear();
        for (final item in decoded) {
          if (item is Map) {
            _myRingtones.add(Map<String, dynamic>.from(item));
          }
        }
      }
      notifyListeners();
    } catch (_) {}
  }

  // Ringtone Management
  final Map<String, String> _contactRingtones = {};
  final Map<String, String> _contactRingtoneUris = {};
  final List<Map<String, dynamic>> _myRingtones = [];
  String? _currentlyPlayingPreviewUri;
  bool _isPlayingPreview = false;

  Map<String, String> get contactRingtones => _contactRingtones;
  List<Map<String, dynamic>> get myRingtones => _myRingtones;
  String? get currentlyPlayingPreviewUri => _currentlyPlayingPreviewUri;
  bool get isPlayingPreview => _isPlayingPreview;

  String? getContactRingtoneTitle(String? id, String? phone) {
    if (id != null && _contactRingtones.containsKey(id)) {
      return _contactRingtones[id];
    }
    final norm = PhoneNumberHelper.normalize(phone);
    if (norm.isNotEmpty && _contactRingtones.containsKey(norm)) {
      return _contactRingtones[norm];
    }
    return null;
  }

  Future<void> setContactRingtone({
    String? contactId,
    String? phoneNumber,
    required String title,
    required String uriOrPath,
  }) async {
    final key = (contactId != null && contactId.isNotEmpty) ? contactId : PhoneNumberHelper.normalize(phoneNumber);
    if (key.isNotEmpty) {
      if (title == 'Default ringtone') {
        _contactRingtones.remove(key);
        _contactRingtoneUris.remove(key);
      } else {
        _contactRingtones[key] = title;
        _contactRingtoneUris[key] = uriOrPath;
      }
      final prefs = await SharedPreferences.getInstance();
      prefs.setString('contactRingtones', jsonEncode(_contactRingtones));
      prefs.setString('contactRingtoneUris', jsonEncode(_contactRingtoneUris));
      notifyListeners();
    }
  }

  Future<void> addMyRingtone(Map<String, dynamic> item) async {
    _myRingtones.removeWhere((r) => r['path'] == item['path']);
    _myRingtones.insert(0, item);
    final prefs = await SharedPreferences.getInstance();
    prefs.setString('myRingtonesList', jsonEncode(_myRingtones));
    notifyListeners();
  }

  Future<List<Map<String, dynamic>>> fetchSystemRingtones() async {
    try {
      final List<dynamic>? res = await _simChannel.invokeMethod('getSystemRingtones');
      if (res != null) {
        return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching system ringtones: $e');
    }
    return [];
  }

  Future<List<Map<String, dynamic>>> fetchDeviceAudioFiles() async {
    try {
      final List<dynamic>? res = await _simChannel.invokeMethod('getDeviceAudioFiles');
      if (res != null) {
        return res.map((e) => Map<String, dynamic>.from(e as Map)).toList();
      }
    } catch (e) {
      debugPrint('Error fetching device audio files: $e');
    }
    return [];
  }

  Future<void> playPreview(String uriOrPath) async {
    if (_currentlyPlayingPreviewUri == uriOrPath && _isPlayingPreview) {
      await stopPreview();
      return;
    }
    _currentlyPlayingPreviewUri = uriOrPath;
    _isPlayingPreview = true;
    notifyListeners();
    try {
      await _simChannel.invokeMethod('playRingtonePreview', {'uri': uriOrPath});
    } catch (e) {
      debugPrint('Error playing ringtone preview: $e');
    }
  }

  Future<void> stopPreview() async {
    _currentlyPlayingPreviewUri = null;
    _isPlayingPreview = false;
    notifyListeners();
    try {
      await _simChannel.invokeMethod('stopRingtonePreview');
    } catch (e) {
      debugPrint('Error stopping ringtone preview: $e');
    }
  }

  void dismissFirstTimeOnboarding() {
    _isFirstTimeOnboarding = false;
    SharedPreferences.getInstance().then((prefs) => prefs.setBool('isFirstTimeOnboarding', false));
    notifyListeners();
  }

  // UI Actions
  void setTab(int index) {
    _selectedTabIndex = index;
    notifyListeners();
  }

  void setRecentsFilter(String filter) {
    _selectedRecentsFilter = filter;
    notifyListeners();
  }

  void setSearchQuery(String query) {
    _searchQuery = query;
    notifyListeners();
  }

  void setDialPadOpen(bool open) {
    _isDialPadOpen = open;
    notifyListeners();
  }

  void toggleDialPad() {
    _isDialPadOpen = !_isDialPadOpen;
    notifyListeners();
  }

  void setDialPadInput(String input) {
    _dialPadInput = input;
    _isDialPadOpen = true;
    _checkAndTriggerAutoUssd();
    notifyListeners();
  }

  void appendDialPadInput(String char) {
    _dialPadInput += char;
    _isDialPadOpen = true;
    _checkAndTriggerAutoUssd();
    notifyListeners();
  }

  void _checkAndTriggerAutoUssd() {
    final trimmed = _dialPadInput.trim();
    const autoTriggerCodes = {
      '*#06#',
      '*#0*#',
      '*#*#4636#*#*',
      '*#*#34971539#*#*',
      '*#*#273282*255*663282*#*#*',
      '*#*#1111#*#*',
      '*#*#2222#*#*',
      '*#*#44336#*#*',
    };
    if (autoTriggerCodes.contains(trimmed)) {
      final codeToRun = _dialPadInput;
      _dialPadInput = '';
      notifyListeners();
      placeRealPhoneCall(codeToRun);
    }
  }

  void backspaceDialPadInput() {
    if (_dialPadInput.isNotEmpty) {
      _dialPadInput = _dialPadInput.substring(0, _dialPadInput.length - 1);
      notifyListeners();
    }
  }

  void clearDialPadInput() {
    _dialPadInput = '';
    notifyListeners();
  }

  String? get lastDialedNumber {
    // 1. First look for most recent outgoing call with a valid number
    for (final log in _callLogs) {
      if (log.callType == CallType.outgoing && log.phoneNumber.trim().isNotEmpty) {
        return log.phoneNumber.trim();
      }
    }
    // 2. Fallback to most recent call log entry of any type
    if (_callLogs.isNotEmpty && _callLogs.first.phoneNumber.trim().isNotEmpty) {
      return _callLogs.first.phoneNumber.trim();
    }
    return null;
  }

  void handleCallButtonPress({int simSlot = 1}) {
    if (_dialPadInput.trim().isNotEmpty) {
      final numberToCall = _dialPadInput.trim();
      startCall(number: numberToCall, simSlot: simSlot);
    } else {
      final lastNum = lastDialedNumber;
      if (lastNum != null && lastNum.isNotEmpty) {
        setDialPadInput(lastNum);
      }
    }
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.dark ? ThemeMode.light : ThemeMode.dark;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setBool('isDarkMode', _themeMode == ThemeMode.dark);
    });
    notifyListeners();
  }

  // Contact Operations
  void addContact(Contact contact) {
    _contacts.add(contact);
    _syncCallLogsWithContacts();
    notifyListeners();
  }

  void updateContact(Contact updated) {
    final idx = _contacts.indexWhere((c) => c.id == updated.id);
    if (idx != -1) {
      _contacts[idx] = updated;
      _syncCallLogsWithContacts();
      notifyListeners();
    }
  }

  void deleteContact(String contactId) {
    _contacts.removeWhere((c) => c.id == contactId);
    _syncCallLogsWithContacts();
    notifyListeners();
  }

  void toggleFavorite(String contactId) {
    final idx = _contacts.indexWhere((c) => c.id == contactId);
    if (idx != -1) {
      final current = _contacts[idx];
      _contacts[idx] = current.copyWith(isFavorite: !current.isFavorite);
      notifyListeners();
    }
  }

  bool isNumberBlocked(String phoneNumber) {
    final clean = phoneNumber.replaceAll(' ', '');
    return _blockedNumbers.contains(clean);
  }

  void toggleBlockContact(String phoneNumber) {
    final clean = phoneNumber.replaceAll(' ', '');
    if (_blockedNumbers.contains(clean)) {
      _blockedNumbers.remove(clean);
    } else {
      _blockedNumbers.add(clean);
    }
    notifyListeners();
  }

  Future<void> sendSms(String phoneNumber) async {
    try {
      final cleanNumber = phoneNumber.replaceAll(' ', '');
      await _simChannel.invokeMethod('sendSms', {'number': cleanNumber});
    } catch (e) {
      debugPrint('Error sending SMS: $e');
    }
  }

  Future<void> deleteCallLog({String? logId, String? phoneNumber}) async {
    final targetPhone = phoneNumber;
    _callLogs.removeWhere((l) {
      if (logId != null && l.id == logId) return true;
      if (targetPhone != null && targetPhone.isNotEmpty) {
        return PhoneNumberHelper.isMatch(l.phoneNumber, targetPhone);
      }
      return false;
    });
    notifyListeners();

    try {
      await _simChannel.invokeMethod('deleteCallLog', {
        'id': logId,
        'number': phoneNumber,
      });
    } catch (e) {
      debugPrint('Error deleting native call log: $e');
    }
  }

  void clearAllCallLogs() {
    _callLogs.clear();
    notifyListeners();
  }

  // Settings Actions
  void setDialPadTones(String tones) {
    _dialPadTones = tones;
    SharedPreferences.getInstance().then((prefs) => prefs.setString('dialPadTones', tones));
    notifyListeners();
  }

  void setHapticsEnabled(bool enabled) {
    _hapticsEnabled = enabled;
    SharedPreferences.getInstance().then((prefs) => prefs.setBool('hapticsEnabled', enabled));
    notifyListeners();
  }

  void setAutoRecordEnabled(bool enabled) {
    _autoRecordEnabled = enabled;
    SharedPreferences.getInstance().then((prefs) => prefs.setBool('autoRecordEnabled', enabled));
    notifyListeners();
  }

  void setSimNames(String sim1, String sim2) {
    _sim1Name = sim1;
    _sim2Name = sim2;
    SharedPreferences.getInstance().then((prefs) {
      prefs.setString('sim1Name', sim1);
      prefs.setString('sim2Name', sim2);
    });
    notifyListeners();
  }

  // -------------------------------------------------------------
  // CALL ENGINE SIMULATION
  // -------------------------------------------------------------
  Future<void> placeRealPhoneCall(String phoneNumber) async {
    final cleanNumber = phoneNumber.replaceAll(RegExp(r'[^\d+*#]'), '');
    if (cleanNumber.isEmpty) return;

    try {
      final status = await Permission.phone.request();
      if (status.isGranted) {
        final bool? success = await _simChannel.invokeMethod<bool>('makeDirectCall', {'number': cleanNumber});
        if (success == true) {
          _addCallLogEntry(cleanNumber);
          return;
        }
      }
      final encoded = Uri.encodeComponent(cleanNumber);
      final uri = Uri.parse('tel:$encoded');
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri);
        _addCallLogEntry(cleanNumber);
      }
    } catch (e) {
      debugPrint('Error placing real phone call: $e');
    }
  }

  void _addCallLogEntry(String phoneNumber) {
    if (phoneNumber.contains('*') || phoneNumber.contains('#')) {
      final digitsOnly = phoneNumber.replaceAll(RegExp(r'\D'), '');
      if (digitsOnly.isNotEmpty) {
        _ussdLogMap[digitsOnly] = phoneNumber;
      }
      _ussdLogMap[phoneNumber] = phoneNumber;
      _saveUssdLogMap();
    }

    final Contact? matchedContact = findContactByNumber(phoneNumber);

    final newLog = CallLogEntry(
      id: DateTime.now().millisecondsSinceEpoch.toString(),
      contactName: matchedContact?.name ?? phoneNumber,
      phoneNumber: phoneNumber,
      callType: CallType.outgoing,
      timestamp: DateTime.now(),
      durationSeconds: 0,
      simSlot: _activeSimSlot,
      contactId: matchedContact?.id,
    );

    _callLogs.insert(0, newLog);
    notifyListeners();
  }

  Future<void> placeVideoCall(String number) async {
    final cleanNumber = number.replaceAll(' ', '').trim();
    try {
      await Permission.camera.request();
    } catch (_) {}
    if (_remoteTextureId == null || _localTextureId == null) {
      await fetchVideoTextures();
    }
    if (_callStatus == ActiveCallStatus.active) {
      _isVideoCall = true;
      notifyListeners();
      try {
        await _simChannel.invokeMethod('upgradeToVideoCall');
      } catch (e) {
        debugPrint('Error upgrading to video call: $e');
      }
      return;
    }
    if (cleanNumber.isEmpty) return;
    try {
      await _simChannel.invokeMethod('makeVideoCall', {'number': cleanNumber});
    } catch (e) {
      debugPrint('Error placing video call: $e');
    }
  }

  void switchToVoiceCall() {
    _isVideoCall = false;
    notifyListeners();
  }

  Future<void> acceptVideoUpgrade() async {
    try {
      await Permission.camera.request();
    } catch (_) {}
    if (_remoteTextureId == null || _localTextureId == null) {
      await fetchVideoTextures();
    }
    _hasIncomingVideoUpgradeRequest = false;
    _isVideoCall = true;
    notifyListeners();
    try {
      await _simChannel.invokeMethod('acceptVideoUpgrade');
    } catch (e) {
      debugPrint('Error accepting video upgrade: $e');
    }
  }

  Future<void> declineVideoUpgrade() async {
    _hasIncomingVideoUpgradeRequest = false;
    notifyListeners();
    try {
      await _simChannel.invokeMethod('declineVideoUpgrade');
    } catch (e) {
      debugPrint('Error declining video upgrade: $e');
    }
  }

  Future<void> switchCamera({required bool useBack}) async {
    try {
      await _simChannel.invokeMethod('switchCamera', {'useBack': useBack});
    } catch (e) {
      debugPrint('Error switching camera: $e');
    }
  }

  void startCall({
    required String number,
    String? name,
    int? avatarColor,
    int simSlot = 1,
    bool isIncoming = false,
    bool isVideoCall = false,
  }) {
    if (number.trim().isEmpty) return;

    FocusManager.instance.primaryFocus?.unfocus();
    SystemChannels.textInput.invokeMethod('TextInput.hide');

    final Contact? matchedContact = findContactByNumber(number);

    _activeCallNumber = number;
    _activeCallName = name ?? matchedContact?.name;
    _activeSimSlot = simSlot;
    _callDurationSeconds = 0;
    _isMuted = false;
    _isSpeaker = false;
    _isOnHold = false;
    _isRecording = false;
    _recordingSeconds = 0;
    _inCallKeypadInput = '';
    _showInCallKeypad = false;
    _isVideoCall = isVideoCall;

    if (isIncoming) {
      _isIncomingSession = true;
      _callStatus = ActiveCallStatus.incoming;
    } else {
      _isIncomingSession = false;
      _callStatus = ActiveCallStatus.outgoing;
      if (isVideoCall) {
        placeVideoCall(number);
      } else {
        placeRealPhoneCall(number);
      }
    }

    notifyListeners();
  }

  void simulateIncomingVideoCall({
    String number = '+91 98765 43210',
    String? name,
    int simSlot = 1,
  }) {
    startCall(
      number: number,
      name: name ?? 'Test Video Caller',
      simSlot: simSlot,
      isIncoming: true,
      isVideoCall: true,
    );
  }

  void answerCall({bool? asVideo}) {
    final bool shouldAnswerAsVideo = asVideo ?? _isVideoCall;
    if (shouldAnswerAsVideo) {
      Permission.camera.request();
      if (_remoteTextureId == null || _localTextureId == null) {
        fetchVideoTextures();
      }
    }
    try {
      _simChannel.invokeMethod('answerNativeCall', {'isVideo': shouldAnswerAsVideo});
    } catch (e) {
      debugPrint('Error answering call: $e');
    }
    _connectCall();
  }

  void _connectCall() {
    _callStatus = ActiveCallStatus.active;
    _callDurationSeconds = 0;
    _callTimer?.cancel();
    _callTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      _callDurationSeconds++;
      if (_isRecording) {
        _recordingSeconds++;
      }
      notifyListeners();
    });
    notifyListeners();
  }

  void toggleMute() {
    _isMuted = !_isMuted;
    try {
      _simChannel.invokeMethod('setMute', {'enabled': _isMuted});
    } catch (e) {
      debugPrint('Error toggling mute: $e');
    }
    notifyListeners();
  }

  void toggleSpeaker() {
    _isSpeaker = !_isSpeaker;
    try {
      _simChannel.invokeMethod('setSpeaker', {'enabled': _isSpeaker});
    } catch (e) {
      debugPrint('Error toggling speaker: $e');
    }
    notifyListeners();
  }

  Future<String?> saveNoteFile(String fileName, String content) async {
    try {
      await Permission.storage.request();
      final String? path = await _simChannel.invokeMethod<String>('saveNoteFile', {
        'fileName': fileName,
        'content': content,
      });
      return path;
    } catch (e) {
      debugPrint('Error saving note file: $e');
      return null;
    }
  }

  Future<void> openWithOtherApp(String filePath) async {
    try {
      await _simChannel.invokeMethod('openWithOtherApp', {'filePath': filePath});
    } catch (e) {
      debugPrint('Error opening file with other app: $e');
    }
  }

  void toggleHold() {
    _isOnHold = !_isOnHold;
    try {
      _simChannel.invokeMethod('setHold', {'enabled': _isOnHold});
    } catch (e) {
      debugPrint('Error toggling hold: $e');
    }
    notifyListeners();
  }

  Future<bool> isRootAvailable() async {
    try {
      final bool? available = await _simChannel.invokeMethod<bool>('isRootAvailable');
      return available ?? false;
    } catch (e) {
      debugPrint('Error checking root: $e');
      return false;
    }
  }

  Future<bool> requestRootPermission() async {
    try {
      final bool? granted = await _simChannel.invokeMethod<bool>('requestRootPermission');
      return granted ?? false;
    } catch (e) {
      debugPrint('Error requesting root: $e');
      return false;
    }
  }

  Future<bool> toggleRecording({
    String? contactName,
    String? contactNumber,
    BuildContext? context,
  }) async {
    if (!_isRecording) {
      final hasRoot = await isRootAvailable();
      if (!hasRoot) {
        final granted = await requestRootPermission();
        if (!granted) {
          if (context != null && context.mounted) {
            showDialog(
              context: context,
              builder: (ctx) => AlertDialog(
                backgroundColor: const Color(0xFF2C2C2E),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                title: const Text(
                  'Root Permission Required',
                  style: TextStyle(
                    fontFamily: MiuiTheme.fontFamily,
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                    fontSize: 18,
                  ),
                ),
                content: const Text(
                  'To record two-way call audio directly from hardware, please grant Root/Superuser permission in Magisk or KernelSU.',
                  style: TextStyle(
                    fontFamily: MiuiTheme.fontFamily,
                    color: Color(0xFFD1D1D6),
                    fontSize: 14,
                    height: 1.4,
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx),
                    child: const Text(
                      'OK',
                      style: TextStyle(
                        color: Color(0xFF0C84FF),
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
            );
          }
          _isRecording = false;
          _recordingSeconds = 0;
          notifyListeners();
          return false;
        }
      }

      final micStatus = await Permission.microphone.request();
      if (!micStatus.isGranted) {
        _isRecording = false;
        _recordingSeconds = 0;
        notifyListeners();
        return false;
      }
      await Permission.storage.request();

      final nameSafe = (contactName ?? _activeCallName ?? 'Unknown')
          .replaceAll(RegExp(r'[^\w\s-]'), '')
          .trim();
      final phoneSafe = (contactNumber ?? _activeCallNumber).replaceAll(' ', '').trim();
      final now = DateTime.now();
      final dateFormatted = DateFormat('ddMMyy_hhmm a').format(now).replaceAll(' ', '');
      final fileName = '$nameSafe($phoneSafe)_$dateFormatted.mp3';

      try {
        final String? path = await _simChannel.invokeMethod<String>('startCallRecording', {'fileName': fileName});
        if (path != null && path.isNotEmpty) {
          _isRecording = true;
          _recordingSeconds = 0;
        } else {
          _isRecording = false;
          _recordingSeconds = 0;
        }
      } catch (e) {
        debugPrint('Error starting call recording: $e');
        _isRecording = false;
        _recordingSeconds = 0;
      }
    } else {
      try {
        await _simChannel.invokeMethod('stopCallRecording');
      } catch (e) {
        debugPrint('Error stopping call recording: $e');
      }
      _isRecording = false;
      _recordingSeconds = 0;
    }
    notifyListeners();
    return _isRecording;
  }

  void toggleInCallKeypad() {
    _showInCallKeypad = !_showInCallKeypad;
    notifyListeners();
  }

  void appendInCallKeypad(String digit) {
    _inCallKeypadInput += digit;
    notifyListeners();
  }

  void sendInCallDtmf(String digit) {
    appendInCallKeypad(digit);
    if (digit.isNotEmpty) {
      try {
        _simChannel.invokeMethod('sendDtmf', {'digit': digit});
      } catch (e) {
        debugPrint('Error sending DTMF: $e');
      }
    }
  }

  void endCall() {
    if (_callStatus == ActiveCallStatus.none) return;

    if (_isRecording) {
      try {
        _simChannel.invokeMethod('stopCallRecording');
      } catch (_) {}
      _isRecording = false;
    }

    try {
      _simChannel.invokeMethod('endNativeCall');
    } catch (_) {}

    final endedStatus = _callStatus;
    _callTimer?.cancel();
    _callTimer = null;

    final finalDuration = _callDurationSeconds;
    final wasRecorded = _isRecording || _autoRecordEnabled;

    CallType type;
    if (endedStatus == ActiveCallStatus.incoming && finalDuration == 0) {
      type = CallType.missed;
    } else if (endedStatus == ActiveCallStatus.incoming) {
      type = CallType.incoming;
    } else if (endedStatus == ActiveCallStatus.outgoing && finalDuration == 0) {
      type = CallType.rejected;
    } else {
      type = CallType.outgoing;
    }

    final newLog = CallLogEntry(
      id: 'l_${DateTime.now().millisecondsSinceEpoch}',
      contactName: _activeCallName ?? _activeCallNumber,
      phoneNumber: _activeCallNumber,
      timestamp: DateTime.now(),
      durationSeconds: finalDuration,
      callType: type,
      simSlot: _activeSimSlot,
      isRecorded: wasRecorded && finalDuration > 0,
      location: _activeSimSlot == 1 ? '$_sim1Name, India' : '$_sim2Name, India',
    );

    final wasIncomingSession = _isIncomingSession;
    _isIncomingSession = false;

    _callLogs.insert(0, newLog);

    if (wasIncomingSession && endedStatus == ActiveCallStatus.incoming) {
      // Rejected/Hung up incoming call without answering: dismiss immediately
      _callStatus = ActiveCallStatus.none;
      _dialPadInput = '';
      _isDialPadOpen = false;
      _isVideoCall = false;
      _hasIncomingVideoUpgradeRequest = false;
      notifyListeners();
      try {
        _simChannel.invokeMethod('moveAppToBack');
      } catch (_) {}
    } else if (wasIncomingSession) {
      // Answered incoming call finished: show Call Ended briefly then dismiss
      _callStatus = ActiveCallStatus.ended;
      notifyListeners();
      try {
        _simChannel.invokeMethod('moveAppToBack');
      } catch (_) {}
      Timer(const Duration(milliseconds: 300), () {
        _callStatus = ActiveCallStatus.none;
        _dialPadInput = '';
        _isDialPadOpen = false;
        _isVideoCall = false;
        _hasIncomingVideoUpgradeRequest = false;
        notifyListeners();
      });
    } else {
      // Outgoing call ended
      _callStatus = ActiveCallStatus.ended;
      notifyListeners();

      Timer(const Duration(milliseconds: 600), () {
        _callStatus = ActiveCallStatus.none;
        _dialPadInput = '';
        _isDialPadOpen = false;
        _isVideoCall = false;
        _hasIncomingVideoUpgradeRequest = false;
        notifyListeners();
      });
    }
  }

  Future<bool> createShortcut({
    required String name,
    required String number,
    required bool isDirectDial,
  }) async {
    try {
      final res = await _simChannel.invokeMethod<bool>('createShortcut', {
        'name': name,
        'number': number,
        'isDirectDial': isDirectDial,
      });
      return res ?? false;
    } catch (e) {
      debugPrint('Error creating shortcut: $e');
      return false;
    }
  }

  Future<void> shareText(String text) async {
    try {
      await _simChannel.invokeMethod('shareText', {'text': text});
    } catch (e) {
      debugPrint('Error sharing text: $e');
    }
  }

  Future<void> shareVCard({required String name, required String number}) async {
    try {
      await _simChannel.invokeMethod('shareVCard', {
        'name': name,
        'number': number,
      });
    } catch (e) {
      debugPrint('Error sharing vCard: $e');
    }
  }

  final Map<String, List<String>> _callNotes = {};

  List<String> getCallNotes(String logId) {
    return _callNotes[logId] ?? [];
  }

  void addCallNote(String logId, String note) {
    if (!_callNotes.containsKey(logId)) {
      _callNotes[logId] = [];
    }
    _callNotes[logId]!.insert(0, note);
    notifyListeners();
  }

  void deleteCallNote(String logId, String note) {
    if (_callNotes.containsKey(logId)) {
      _callNotes[logId]!.remove(note);
      notifyListeners();
    }
  }
}

