import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/contact.dart';
import '../providers/dialer_provider.dart';
import '../theme/miui_theme.dart';
import '../views/contact_detail_screen.dart';
import 'miui_avatar.dart';

class ContactTile extends StatelessWidget {
  final Contact contact;

  const ContactTile({super.key, required this.contact});

  @override
  Widget build(BuildContext context) {
    final provider = Provider.of<DialerProvider>(context, listen: false);
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return InkWell(
      onTap: () {
        Navigator.push(
          context,
          MaterialPageRoute(
            builder: (_) => ContactDetailScreen(contactId: contact.id),
          ),
        );
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            MiuiAvatar(
              name: contact.name,
              radius: 22,
              avatarUrl: contact.avatarUrl,
              photoBytes: contact.photoThumbnail,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Flexible(
                        child: Text(
                          contact.name,
                          style: TextStyle(
                            fontFamily: MiuiTheme.fontFamily,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                            color: isDark ? Colors.white : Colors.black87,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (contact.company != null && contact.company!.isNotEmpty) ...[
                        const SizedBox(width: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: MiuiColors.primaryBlue.withAlpha(30),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            contact.company!,
                            style: const TextStyle(
                              fontFamily: MiuiTheme.fontFamily,
                              fontSize: 10,
                              color: MiuiColors.primaryBlue,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '${contact.label} • ${contact.phoneNumber}',
                    style: TextStyle(
                      fontFamily: MiuiTheme.fontFamily,
                      fontSize: 13,
                      color: isDark ? MiuiColors.darkTextSecondary : MiuiColors.lightTextSecondary,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: Icon(
                contact.isFavorite ? Icons.star : Icons.star_border,
                color: contact.isFavorite ? Colors.amber : (isDark ? Colors.white38 : Colors.black38),
                size: 22,
              ),
              onPressed: () {
                provider.toggleFavorite(contact.id);
              },
            ),
            IconButton(
              icon: const Icon(Icons.call_outlined, color: MiuiColors.callGreen, size: 22),
              onPressed: () {
                provider.startCall(
                  number: contact.phoneNumber,
                  name: contact.name,
                  avatarColor: contact.avatarColorValue,
                );
              },
            ),
          ],
        ),
      ),
    );
  }
}
