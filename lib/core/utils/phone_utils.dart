/// Converts local Pakistani numbers (e.g. "03001234567" or "3001234567")
/// into E.164 format ("+923001234567") consistently across the app.
class PhoneUtils {
  static String toE164(String rawLocal) {
    var digits = rawLocal.replaceAll(RegExp(r'\D'), '');
    if (digits.startsWith('0')) digits = digits.substring(1);
    if (digits.startsWith('92')) digits = digits.substring(2);
    return '+92$digits';
  }

  /// Realtime Database keys can't contain '.', '#', '$', '[', ']', or '+'.
  static String toDbKey(String e164) => e164.replaceAll('+', '');

  static bool isValid(String e164) {
    return RegExp(r'^\+923\d{9}$').hasMatch(e164);
  }
}