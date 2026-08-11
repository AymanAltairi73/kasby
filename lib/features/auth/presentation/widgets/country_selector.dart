import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:kasby/core/theme/app_colors.dart';
import 'package:kasby/core/utils/country_data.dart';
import 'package:kasby/features/auth/domain/models/country_model.dart';

class CountrySelector extends StatelessWidget {
  final Country selectedCountry;
  final Function(Country) onSelect;
  final bool showBackground;

  const CountrySelector({
    super.key,
    required this.selectedCountry,
    required this.onSelect,
    this.showBackground = true,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => _showCountryPicker(context),
      child: Container(
        padding: EdgeInsets.symmetric(
          horizontal: 12,
          vertical: showBackground ? 12 : 0,
        ),
        decoration: BoxDecoration(
          color: showBackground ? AppColors.surface : Colors.transparent,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Colors.transparent),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(selectedCountry.flag, style: const TextStyle(fontSize: 24)),
            const SizedBox(width: 8),
            Text(
              selectedCountry.dialCode,
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w600,
                fontSize: 16,
              ),
              textDirection: TextDirection.ltr,
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              color: AppColors.textSecondary,
              size: 20,
            ),
          ],
        ),
      ),
    );
  }

  void _showCountryPicker(BuildContext context) {
    Get.bottomSheet(
      Container(
        height: Get.height * 0.7,
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 16),
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.textSecondary.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: 16),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24),
              child: Text(
                'select_country'.tr,
                style: Theme.of(
                  context,
                ).textTheme.titleLarge?.copyWith(color: Colors.white),
              ),
            ),
            const SizedBox(height: 16),
            Expanded(
              child: _CountrySearchList(
                onSelect: (country) {
                  onSelect(country);
                  Get.back();
                },
              ),
            ),
          ],
        ),
      ),
      isScrollControlled: true,
    );
  }
}

class _CountrySearchList extends StatefulWidget {
  final Function(Country) onSelect;

  const _CountrySearchList({required this.onSelect});

  @override
  State<_CountrySearchList> createState() => _CountrySearchListState();
}

class _CountrySearchListState extends State<_CountrySearchList> {
  final TextEditingController _searchController = TextEditingController();
  List<Country> _filteredCountries = CountryData.countries;

  void _filterCountries(String query) {
    setState(() {
      if (query.isEmpty) {
        _filteredCountries = CountryData.countries;
      } else {
        _filteredCountries = CountryData.countries.where((country) {
          final nameMatches = country.name.toLowerCase().contains(
            query.toLowerCase(),
          );
          final codeMatches =
              country.dialCode.contains(query) ||
              country.code.toLowerCase().contains(query.toLowerCase());
          return nameMatches || codeMatches;
        }).toList();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
          child: TextField(
            controller: _searchController,
            onChanged: _filterCountries,
            style: const TextStyle(color: Colors.white),
            decoration: InputDecoration(
              hintText: 'search_country'.tr,
              hintStyle: TextStyle(color: AppColors.textSecondary),
              prefixIcon: Icon(Icons.search, color: AppColors.darkGold),
              filled: true,
              fillColor: AppColors.surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
        ),
        Expanded(
          child: ListView.separated(
            padding: const EdgeInsets.all(24),
            itemCount: _filteredCountries.length,
            separatorBuilder: (_, __) => const SizedBox(height: 16),
            itemBuilder: (context, index) {
              final country = _filteredCountries[index];
              return Material(
                color: Colors.transparent,
                child: ListTile(
                  onTap: () => widget.onSelect(country),
                  contentPadding: EdgeInsets.zero,
                  leading: Text(
                    country.flag,
                    style: const TextStyle(fontSize: 28),
                  ),
                  title: Text(
                    country.name,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                  trailing: Text(
                    country.dialCode,
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                    textDirection: TextDirection.ltr,
                  ),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}
