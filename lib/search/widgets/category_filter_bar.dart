import 'package:flutter/material.dart';

class CategoryFilterBar extends StatelessWidget {
  final List<String> categories;
  final String selectedCategory;
  final ValueChanged<String> onCategorySelected;

  // Map section IDs to Arabic display names
  final Map<String, String> _displayNames = const {
    'all': 'الكل',
    'quran': 'القرآن الكريم',
    'dua': 'الأدعية',
    'ziyarat': 'الزيارات',
    'amal': 'الأعمال',
    'fatawa': 'الاستفتاءات',
    'imam_ali': 'الإمام علي (ع)',
    'dreams': 'تفسير الأحلام',
    'prophets_stories': 'قصص الأنبياء',
  };

  const CategoryFilterBar({
    super.key,
    required this.categories,
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 56,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: ListView.builder(
        scrollDirection: Axis.horizontal,
        itemCount: categories.length,
        itemBuilder: (context, index) {
          final category = categories[index];
          final isSelected = category == selectedCategory;
          return Padding(
            padding: const EdgeInsetsDirectional.only(end: 8),
            child: ChoiceChip(
              label: Text(
                _displayNames[category] ?? category,
                style: TextStyle(
                  fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                  color: isSelected ? Colors.white : Colors.grey[800],
                ),
              ),
              selected: isSelected,
              selectedColor: Theme.of(context).primaryColor,
              backgroundColor: Colors.grey[200],
              padding: const EdgeInsets.symmetric(horizontal: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
              showCheckmark: false,
              onSelected: (_) => onCategorySelected(category),
            ),
          );
        },
      ),
    );
  }
}
