enum CallType {
  incoming,
  outgoing,
  missed,
  rejected,
  blocked,
}

class CallLogEntry {
  final String id;
  final String? contactId;
  final String contactName;
  final String phoneNumber;
  final DateTime timestamp;
  final int durationSeconds;
  final CallType callType;
  final int simSlot; // 1 or 2
  final bool isRecorded;
  final String? recordingPath;
  final String location; // e.g. "Jio 5G, India" or "Airtel, Mumbai"
  final int? ringCount; // Optional ring count for missed calls
  final bool? isNoAnswered; // Outgoing call rang (caller tune) but wasn't answered

  CallLogEntry({
    required this.id,
    this.contactId,
    required this.contactName,
    required this.phoneNumber,
    required this.timestamp,
    required this.durationSeconds,
    required this.callType,
    required this.simSlot,
    this.isRecorded = false,
    this.recordingPath,
    this.location = 'Mobile, India',
    this.ringCount,
    this.isNoAnswered = false,
  });

  CallLogEntry copyWith({
    String? id,
    String? contactId,
    String? contactName,
    String? phoneNumber,
    DateTime? timestamp,
    int? durationSeconds,
    CallType? callType,
    int? simSlot,
    bool? isRecorded,
    String? recordingPath,
    String? location,
    int? ringCount,
    bool? isNoAnswered,
  }) {
    return CallLogEntry(
      id: id ?? this.id,
      contactId: contactId ?? this.contactId,
      contactName: contactName ?? this.contactName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      timestamp: timestamp ?? this.timestamp,
      durationSeconds: durationSeconds ?? this.durationSeconds,
      callType: callType ?? this.callType,
      simSlot: simSlot ?? this.simSlot,
      isRecorded: isRecorded ?? this.isRecorded,
      recordingPath: recordingPath ?? this.recordingPath,
      location: location ?? this.location,
      ringCount: ringCount ?? this.ringCount,
      isNoAnswered: isNoAnswered ?? this.isNoAnswered,
    );
  }

  String get formattedDuration {
    if (durationSeconds <= 0) return '0s';
    final mins = durationSeconds ~/ 60;
    final secs = durationSeconds % 60;
    if (mins > 0) {
      return '${mins}m ${secs}s';
    }
    return '${secs}s';
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'contactId': contactId,
      'contactName': contactName,
      'phoneNumber': phoneNumber,
      'timestamp': timestamp.toIso8601String(),
      'durationSeconds': durationSeconds,
      'callType': callType.index,
      'simSlot': simSlot,
      'isRecorded': isRecorded,
      'recordingPath': recordingPath,
      'location': location,
      'ringCount': ringCount,
      'isNoAnswered': isNoAnswered,
    };
  }

  factory CallLogEntry.fromJson(Map<String, dynamic> json) {
    return CallLogEntry(
      id: json['id'],
      contactId: json['contactId'],
      contactName: json['contactName'],
      phoneNumber: json['phoneNumber'],
      timestamp: DateTime.parse(json['timestamp']),
      durationSeconds: json['durationSeconds'] ?? 0,
      callType: CallType.values[json['callType'] ?? 0],
      simSlot: json['simSlot'] ?? 1,
      isRecorded: json['isRecorded'] ?? false,
      recordingPath: json['recordingPath'],
      location: json['location'] ?? 'Mobile, India',
      ringCount: json['ringCount'],
      isNoAnswered: json['isNoAnswered'] ?? false,
    );
  }
}

class GroupedCallLog {
  final CallLogEntry latestEntry;
  final int count;
  final List<CallLogEntry> allEntries;

  GroupedCallLog({
    required this.latestEntry,
    required this.count,
    required this.allEntries,
  });
}
