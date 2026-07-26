import 'package:flutter_dotenv/flutter_dotenv.dart';

class StoreConfig {
  static String get apiKey => dotenv.env['TOPUP_DEV_API_KEY'] ?? '';
  static String get baseUrl => dotenv.env['TOPUP_DEV_BASE_URL'] ?? 'https://topup.dev';

  static Map<String, String> get headers => {
        'Authorization': 'Bearer $apiKey',
        'Content-Type': 'application/json',
        'Accept': 'application/json',
      };
}
