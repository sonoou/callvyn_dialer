class PhoneNumberHelper {
  /// Strips formatting, removes spaces, dashes, parentheses, dots
  static String clean(String? phone) {
    if (phone == null) return '';
    return phone.replaceAll(RegExp(r'[\s\-\(\)\.]'), '').trim();
  }

  /// Extracts only the digit characters
  static String digitsOnly(String? phone) {
    if (phone == null) return '';
    return phone.replaceAll(RegExp(r'\D'), '');
  }

  /// Normalizes phone number to its core standard format for matching & grouping
  /// Handles:
  /// - +919876543210 -> 9876543210
  /// - 09876543210   -> 9876543210
  /// - 919876543210  -> 9876543210
  /// - +91 98765-43210 -> 9876543210
  static String normalize(String? phone) {
    if (phone == null) return '';
    final digits = digitsOnly(phone);
    if (digits.isEmpty) return phone.trim();

    // 12-digit number starting with 91 (India country code)
    if (digits.length == 12 && digits.startsWith('91')) {
      return digits.substring(2);
    }
    // 11-digit number starting with 0 (STD / domestic prefix)
    if (digits.length == 11 && digits.startsWith('0')) {
      return digits.substring(1);
    }
    // General mobile numbers (10 digits)
    if (digits.length > 10) {
      return digits.substring(digits.length - 10);
    }
    return digits;
  }

  /// Compares two phone numbers to see if they refer to the same contact/number
  static bool isMatch(String? phone1, String? phone2) {
    if (phone1 == null || phone2 == null) return false;
    final p1 = phone1.trim();
    final p2 = phone2.trim();
    if (p1.isEmpty || p2.isEmpty) return false;

    // Direct equality check
    if (p1 == p2) return true;

    final c1 = clean(p1);
    final c2 = clean(p2);
    if (c1 == c2) return true;

    final d1 = digitsOnly(p1);
    final d2 = digitsOnly(p2);
    if (d1.isNotEmpty && d1 == d2) return true;

    final n1 = normalize(p1);
    final n2 = normalize(p2);
    if (n1.isNotEmpty && n1 == n2) return true;

    // Check if either ends with the other (when length >= 7)
    if (d1.length >= 7 && d2.length >= 7) {
      if (d1.endsWith(d2) || d2.endsWith(d1)) return true;
    }

    return false;
  }
}
