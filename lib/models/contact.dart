import 'dart:typed_data';

class Contact {
  final String id;
  final String name;
  final String phoneNumber;
  final String? email;
  final String? company;
  final String label; // Mobile, Work, Home
  final bool isFavorite;
  final bool isBlocked;
  final String? avatarUrl;
  final Uint8List? photoThumbnail;
  final int avatarColorValue; // Color integer representation

  Contact({
    required this.id,
    required this.name,
    required this.phoneNumber,
    this.email,
    this.company,
    this.label = 'Mobile',
    this.isFavorite = false,
    this.isBlocked = false,
    this.avatarUrl,
    this.photoThumbnail,
    required this.avatarColorValue,
  });

  String get initials {
    if (name.trim().isEmpty) return '?';
    final parts = name.trim().split(' ');
    if (parts.length > 1 && parts[1].isNotEmpty) {
      return '${parts[0][0]}${parts[1][0]}'.toUpperCase();
    }
    return parts[0][0].toUpperCase();
  }

  Contact copyWith({
    String? id,
    String? name,
    String? phoneNumber,
    String? email,
    String? company,
    String? label,
    bool? isFavorite,
    bool? isBlocked,
    String? avatarUrl,
    Uint8List? photoThumbnail,
    int? avatarColorValue,
  }) {
    return Contact(
      id: id ?? this.id,
      name: name ?? this.name,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      email: email ?? this.email,
      company: company ?? this.company,
      label: label ?? this.label,
      isFavorite: isFavorite ?? this.isFavorite,
      isBlocked: isBlocked ?? this.isBlocked,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      photoThumbnail: photoThumbnail ?? this.photoThumbnail,
      avatarColorValue: avatarColorValue ?? this.avatarColorValue,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'phoneNumber': phoneNumber,
      'email': email,
      'company': company,
      'label': label,
      'isFavorite': isFavorite,
      'isBlocked': isBlocked,
      'avatarUrl': avatarUrl,
      'avatarColorValue': avatarColorValue,
    };
  }

  factory Contact.fromJson(Map<String, dynamic> json) {
    return Contact(
      id: json['id'],
      name: json['name'],
      phoneNumber: json['phoneNumber'],
      email: json['email'],
      company: json['company'],
      label: json['label'] ?? 'Mobile',
      isFavorite: json['isFavorite'] ?? false,
      isBlocked: json['isBlocked'] ?? false,
      avatarUrl: json['avatarUrl'],
      avatarColorValue: json['avatarColorValue'] ?? 0xFF0C84FF,
    );
  }
}
