import 'dart:typed_data';
import 'package:flutter/material.dart';

class MiuiAvatar extends StatelessWidget {
  final String name;
  final int colorValue;
  final double radius;
  final String? avatarUrl;
  final Uint8List? photoBytes;

  const MiuiAvatar({
    super.key,
    required this.name,
    this.colorValue = 0xFF0C84FF,
    this.radius = 24.0,
    this.avatarUrl,
    this.photoBytes,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final defaultIconAsset = isDark
        ? 'resources/contact_detail_circle_photo_night.png'
        : 'resources/contact_detail_circle_photo.png';

    Widget childWidget;
    if (photoBytes != null && photoBytes!.isNotEmpty) {
      childWidget = Image.memory(
        photoBytes!,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => Image.asset(
          defaultIconAsset,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
        ),
      );
    } else if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      childWidget = Image.network(
        avatarUrl!,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
        errorBuilder: (ctx, err, stack) => Image.asset(
          defaultIconAsset,
          width: radius * 2,
          height: radius * 2,
          fit: BoxFit.cover,
        ),
      );
    } else {
      childWidget = Image.asset(
        defaultIconAsset,
        width: radius * 2,
        height: radius * 2,
        fit: BoxFit.cover,
      );
    }

    return Container(
      width: radius * 2,
      height: radius * 2,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
      ),
      clipBehavior: Clip.antiAlias,
      child: childWidget,
    );
  }
}
