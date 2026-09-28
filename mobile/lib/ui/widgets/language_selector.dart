import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:lellama_mobile/core/constants.dart';
import 'package:lellama_mobile/providers/marine_provider.dart';

/// Instant tactile language switch bar: Sinhala / Tamil / English.
class LanguageSelector extends StatelessWidget {
  const LanguageSelector({super.key});

  @override
  Widget build(BuildContext context) {
    final provider = context.watch<MarineProvider>();
    final currentLang = provider.selectedLanguage;

    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: Colors.black, width: 2),
      ),
      child: Row(
        children: [
          _buildLangButton(context, label: 'සිංහල', code: 'si', isSelected: currentLang == 'si'),
          _buildLangButton(context, label: 'தமிழ்', code: 'ta', isSelected: currentLang == 'ta'),
          _buildLangButton(context, label: 'English', code: 'en', isSelected: currentLang == 'en'),
        ],
      ),
    );
  }

  Widget _buildLangButton(
    BuildContext context, {
    required String label,
    required String code,
    required bool isSelected,
  }) {
    return Expanded(
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => context.read<MarineProvider>().setLanguage(code),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 10),
          decoration: BoxDecoration(
            color: isSelected ? MarineColors.oceanNavy : Colors.transparent,
            borderRadius: BorderRadius.circular(8),
          ),
          alignment: Alignment.center,
          child: Text(
            label,
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w900,
              color: isSelected ? MarineColors.safetyYellow : Colors.black87,
            ),
          ),
        ),
      ),
    );
  }
}
