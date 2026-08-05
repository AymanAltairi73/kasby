import 'dart:math';

/// Utility for generating cryptographically secure random passwords.
///
/// Requirements:
/// - Minimum 12 characters
/// - Uppercase letters
/// - Lowercase letters
/// - Numbers
/// - Special characters
/// - Cryptographically secure random generation
/// - Avoid confusing characters (O/0, I/l)
class PasswordGenerator {
  static const _lowercase = 'abcdefghjkmnpqrstuvwxyz'; // Excludes i, l
  static const _uppercase = 'ABCDEFGHJKMNPQRSTUVWXYZ'; // Excludes I, O
  static const _numbers = '23456789'; // Excludes 0, 1
  static const _special = '!@#\$%^&*()_+-=[]{}|;:,.<>?';

  static final _secureRandom = Random.secure();

  /// Generates a cryptographically secure random password.
  ///
  /// [length] must be at least 12 characters.
  /// Returns a password containing uppercase, lowercase, numbers, and special characters.
  static String generateSecurePassword({int length = 16}) {
    if (length < 12) {
      throw ArgumentError('Password length must be at least 12 characters');
    }

    // Ensure at least one character from each category
    final password = StringBuffer();
    password.write(_getRandomChar(_lowercase));
    password.write(_getRandomChar(_uppercase));
    password.write(_getRandomChar(_numbers));
    password.write(_getRandomChar(_special));

    // Fill the rest with random characters from all categories
    final allChars = '$_lowercase$_uppercase$_numbers$_special';
    for (int i = 4; i < length; i++) {
      password.write(_getRandomChar(allChars));
    }

    // Shuffle the password to avoid predictable patterns
    return _shuffleString(password.toString());
  }

  /// Gets a random character from the given string using cryptographically secure random.
  static String _getRandomChar(String chars) {
    return chars[_secureRandom.nextInt(chars.length)];
  }

  /// Shuffles a string using Fisher-Yates algorithm with secure random.
  static String _shuffleString(String input) {
    final chars = input.split('');
    for (int i = chars.length - 1; i > 0; i--) {
      final j = _secureRandom.nextInt(i + 1);
      final temp = chars[i];
      chars[i] = chars[j];
      chars[j] = temp;
    }
    return chars.join();
  }
}
