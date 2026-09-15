import 'phone_number_helper.dart';

class T9Search {
  static const Map<String, String> _charToDigit = {
    'a': '2', 'b': '2', 'c': '2',
    'd': '3', 'e': '3', 'f': '3',
    'g': '4', 'h': '4', 'i': '4',
    'j': '5', 'k': '5', 'l': '5',
    'm': '6', 'n': '6', 'o': '6',
    'p': '7', 'q': '7', 'r': '7', 's': '7',
    't': '8', 'u': '8', 'v': '8',
    'w': '9', 'x': '9', 'y': '9', 'z': '9',
  };

  /// Converts a text name like "Leo" into T9 string like "536"
  static String nameToT9(String name) {
    final buffer = StringBuffer();
    final lower = name.toLowerCase();
    for (int i = 0; i < lower.length; i++) {
      final char = lower[i];
      if (_charToDigit.containsKey(char)) {
        buffer.write(_charToDigit[char]);
      } else if (RegExp(r'[0-9]').hasMatch(char)) {
        buffer.write(char);
      } else {
        buffer.write(' ');
      }
    }
    return buffer.toString();
  }

  /// Checks if a contact name or phone number matches the query string (T9 digits or normal text)
  static bool matches(String name, String phoneNumber, String query) {
    if (query.trim().isEmpty) return true;

    final cleanQuery = query.toLowerCase().replaceAll(RegExp(r'[^a-z0-9+]'), '');
    final cleanPhone = phoneNumber.replaceAll(RegExp(r'[^0-9+]'), '');
    final normPhone = PhoneNumberHelper.normalize(phoneNumber);
    final normQuery = PhoneNumberHelper.normalize(query);

    // 1. Direct phone number match (exact substring or normalized substring)
    if (cleanPhone.contains(cleanQuery) ||
        (normPhone.isNotEmpty && normPhone.contains(cleanQuery)) ||
        (normQuery.isNotEmpty && normPhone.contains(normQuery))) {
      return true;
    }

    // 2. Direct name match
    if (name.toLowerCase().contains(cleanQuery)) return true;

    // 3. T9 match on name words
    final t9Name = nameToT9(name);
    final t9Words = t9Name.split(' ');
    for (final word in t9Words) {
      if (word.startsWith(cleanQuery) || word.contains(cleanQuery)) {
        return true;
      }
    }

    // Full T9 match
    if (t9Name.replaceAll(' ', '').contains(cleanQuery)) {
      return true;
    }

    return false;
  }
}
