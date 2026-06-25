/// Maps backend wallet restriction errors to user-facing messages.
class WalletRestrictionHelper {
  WalletRestrictionHelper._();

  static const restrictedMessage =
      'Your wallet is temporarily restricted. Please contact support.';

  static const restrictedMessageAr =
      'محفظتك مقيدة مؤقتاً. يرجى التواصل مع الدعم.';

  static bool isWalletRestrictedError(Object error) {
    final text = error.toString().toLowerCase();
    return text.contains('wallet is frozen') ||
        text.contains('wallet is temporarily restricted') ||
        text.contains('temporarily restricted');
  }

  static String messageFor(Object error, {bool arabic = true}) {
    if (isWalletRestrictedError(error)) {
      return arabic ? restrictedMessageAr : restrictedMessage;
    }
    return error.toString().replaceFirst('Exception: ', '');
  }
}
