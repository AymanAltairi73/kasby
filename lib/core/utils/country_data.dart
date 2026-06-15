import 'package:kasby/features/auth/domain/models/country_model.dart';

class CountryData {
  static const List<Country> countries = [
    Country(code: 'YE', name: 'Yemen', dialCode: '+967', flag: '🇾🇪'),
    Country(code: 'SA', name: 'Saudi Arabia', dialCode: '+966', flag: '🇸🇦'),
    Country(
      code: 'AE',
      name: 'United Arab Emirates',
      dialCode: '+971',
      flag: '🇦🇪',
    ),
    Country(code: 'KW', name: 'Kuwait', dialCode: '+965', flag: '🇰🇼'),
    Country(code: 'QA', name: 'Qatar', dialCode: '+974', flag: '🇶🇦'),
    Country(code: 'OM', name: 'Oman', dialCode: '+968', flag: '🇴🇲'),
    Country(code: 'BH', name: 'Bahrain', dialCode: '+973', flag: '🇧🇭'),
    Country(code: 'EG', name: 'Egypt', dialCode: '+20', flag: '🇪🇬'),
    Country(code: 'IQ', name: 'Iraq', dialCode: '+964', flag: '🇮🇶'),
    Country(code: 'JO', name: 'Jordan', dialCode: '+962', flag: '🇯🇴'),
    Country(code: 'LB', name: 'Lebanon', dialCode: '+961', flag: '🇱🇧'),
    Country(code: 'PS', name: 'Palestine', dialCode: '+970', flag: '🇵🇸'),
    Country(code: 'SY', name: 'Syria', dialCode: '+963', flag: '🇸🇾'),
    Country(code: 'US', name: 'United States', dialCode: '+1', flag: '🇺🇸'),
    Country(code: 'GB', name: 'United Kingdom', dialCode: '+44', flag: '🇬🇧'),
    Country(code: 'CA', name: 'Canada', dialCode: '+1', flag: '🇨🇦'),
    Country(code: 'DE', name: 'Germany', dialCode: '+49', flag: '🇩🇪'),
    Country(code: 'FR', name: 'France', dialCode: '+33', flag: '🇫🇷'),
    Country(code: 'IT', name: 'Italy', dialCode: '+39', flag: '🇮🇹'),
    Country(code: 'ES', name: 'Spain', dialCode: '+34', flag: '🇪🇸'),
    Country(code: 'TR', name: 'Turkey', dialCode: '+90', flag: '🇹🇷'),
    Country(code: 'CN', name: 'China', dialCode: '+86', flag: '🇨🇳'),
    Country(code: 'IN', name: 'India', dialCode: '+91', flag: '🇮🇳'),
    // Add more countries as needed
  ];

  static Country get defaultCountry => countries.firstWhere(
    (c) => c.code == 'YE',
    orElse: () => countries.first,
  );

  static Country countryForPhone(String? phone) {
    if (phone == null || phone.trim().isEmpty) return defaultCountry;
    final normalized = phone.trim();
    final sorted = List<Country>.from(countries)
      ..sort((a, b) => b.dialCode.length.compareTo(a.dialCode.length));
    for (final country in sorted) {
      if (normalized.startsWith(country.dialCode)) return country;
    }
    return defaultCountry;
  }

  static String stripDialCode(String phone, Country country) {
    final normalized = phone.trim();
    if (normalized.startsWith(country.dialCode)) {
      return normalized.substring(country.dialCode.length);
    }
    return normalized.replaceFirst('+', '');
  }
}
