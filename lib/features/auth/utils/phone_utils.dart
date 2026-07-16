/// KDMC — Phone number helpers
///
/// Supabase Auth requires E.164 format (+<country code><number>, no
/// spaces/dashes). Users just type their 10-digit number; we handle the
/// +91 prefix here so this logic lives in exactly one place.
library;

abstract final class PhoneUtils {
  static String toE164India(String rawInput) {
    final digitsOnly = rawInput.replaceAll(RegExp(r'\D'), '');
    // Handle if user already typed 91XXXXXXXXXX or +91XXXXXXXXXX
    final last10 = digitsOnly.length > 10
        ? digitsOnly.substring(digitsOnly.length - 10)
        : digitsOnly;
    return '+91$last10';
  }

  static bool isValidIndianMobile(String rawInput) {
    final digitsOnly = rawInput.replaceAll(RegExp(r'\D'), '');
    final last10 = digitsOnly.length > 10
        ? digitsOnly.substring(digitsOnly.length - 10)
        : digitsOnly;
    // Indian mobile numbers: 10 digits, starting 6-9
    return RegExp(r'^[6-9]\d{9}$').hasMatch(last10);
  }

  /// Display-friendly version for showing "OTP sent to +91 98765 43210"
  static String formatForDisplay(String e164) {
    if (!e164.startsWith('+91') || e164.length != 13) return e164;
    final number = e164.substring(3);
    return '+91 ${number.substring(0, 5)} ${number.substring(5)}';
  }
}
