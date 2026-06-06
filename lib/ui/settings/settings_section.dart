import 'package:flutter/material.dart';











import 'package:shared_preferences/shared_preferences.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:io';

import '../../data/data_manager.dart';









import 'package:provider/provider.dart';
import '../../providers/settings_provider.dart';
import '../../main.dart';
import 'package:path_provider/path_provider.dart';


class SettingsSection extends StatelessWidget {
  const SettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final settingsProvider = context.watch<SettingsProvider>();
    final comfortColors = [
      Colors.white,
      const Color(0xFFFDF5E6),
      const Color(0xFFF5F5DC),
      const Color(0xFFE0EEE0),
      const Color(0xFFE6E6FA),
      const Color(0xFF2C2C2C),
      Colors.black,
    ];
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _buildGroup(context, 'التقويم الهجري', [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'تعديل التاريخ الهجري:',
                  style: TextStyle(fontSize: 14),
                ),
                Row(
                  children: [
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () =>
                          settingsProvider.setHijriAdjustment(settingsProvider.hijriAdjustment - 1),
                    ),
                    Text(
                      '${settingsProvider.hijriAdjustment}',
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () =>
                          settingsProvider.setHijriAdjustment(settingsProvider.hijriAdjustment + 1),
                    ),
                  ],
                ),
              ],
            ),
          ]),
          _buildGroup(context, 'المظهر العام', [
            SwitchListTile(
              title: const Text('الوضع الليلي'),
              value: Theme.of(context).brightness == Brightness.dark,
              onChanged: (v) => settingsProvider.toggleTheme(),
              contentPadding: EdgeInsets.zero,
            ),
            const SizedBox(height: 10),
            const Text(
              'لون سمة التطبيق',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 12,
              children: [
                Colors.blue,
                Colors.red,
                Colors.black,
                Colors.cyan,
                const Color(0xFFD4AF37),
                Colors.blueGrey,
                Colors.teal,
                Colors.brown,
              ]
                  .map(
                    (c) => GestureDetector(
                      onTap: () => settingsProvider.setPrimaryColor(c),
                      child: CircleAvatar(
                        backgroundColor: c,
                        radius: 18,
                        child: settingsProvider.primaryColor.toARGB32() == c.toARGB32()
                            ? const Icon(
                                Icons.check,
                                color: Colors.white,
                                size: 16,
                              )
                            : null,
                      ),
                    ),
                  )
                  .toList(),
            ),
          ]),
          _buildGroup(context, 'تخصيص البطاقات', [
            const Text(
              'لون خلفية البطاقات (مريح للعين)',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              children: comfortColors
                  .map(
                    (c) => GestureDetector(
                      onTap: () => settingsProvider.setCardColor(c),
                      child: CircleAvatar(
                        backgroundColor: c,
                        radius: 18,
                        child: settingsProvider.cardColor.toARGB32() == c.toARGB32()
                            ? Icon(
                                Icons.check,
                                color: c.computeLuminance() > 0.5
                                    ? Colors.black
                                    : Colors.white,
                                size: 16,
                              )
                            : null,
                      ),
                    ),
                  )
                  .toList(),
            ),
            const SizedBox(height: 15),
            const Text(
              'مستوى الشفافية',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            Slider(
              value: settingsProvider.uiOpacity,
              min: 0.3,
              max: 1.0,
              onChanged: settingsProvider.setUiOpacity,
              activeColor: settingsProvider.primaryColor,
            ),
          ]),
          _buildGroup(context, 'الوسائط', [
            ListTile(
              title: const Text('اختيار خلفية مخصصة'),
              trailing: const Icon(Icons.image_search),
              contentPadding: EdgeInsets.zero,
              onTap: () async {
                final picker = ImagePicker();
                final img = await picker.pickImage(source: ImageSource.gallery);
                if (img != null) settingsProvider.setBackgroundImagePath(img.path);
              },
            ),
            const SizedBox(height: 10),
            const Text(
              'معرض الخلفيات المرفوعة',
              style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
            ),
            const SizedBox(height: 10),
            SizedBox(
              height: 100,
              child: _buildBgGallery(context, (img) {
                settingsProvider.setBase64Bg(img);
              }),
            ),
          ]),
          _buildGroup(context, 'إعدادات ظهور الصفحة الرئيسية', [
            _visToggle(context, 'inspiration', 'إلهام اليوم'),
            _visToggle(context, 'day_dua', 'دعاء اليوم'),
            ...DataManager.getSections().entries.map(
                  (e) => _visToggle(context, e.key, e.value['title'].toString()),
                ),
          ]),
        ],
      ),
    );
  }

  Widget _buildBgGallery(
    BuildContext context,
    ValueChanged<String> onSelected,
  ) {
    final settingsProvider = context.watch<SettingsProvider>();
    final gallery =
        (DataManager.getSettings()['bg_gallery'] as List<dynamic>? ?? []);
    if (gallery.isEmpty) {
      return const Center(
        child: Text('المعرض فارغ', style: TextStyle(fontSize: 12)),
      );
    }
    return ListView.builder(
      scrollDirection: Axis.horizontal,
      itemCount: gallery.length,
      itemBuilder: (context, index) {
        final img = gallery[index].toString();
        return GestureDetector(
          onTap: () async {
            // Create physical file instead of storing base64 string
            String? filePath;
            if (img.startsWith('data:image')) {
               try {
                  final bytes = Uri.parse(img).data!.contentAsBytes();
                  final dir = await getTemporaryDirectory();
                  final file = File('${dir.path}/custom_bg_${img.hashCode}.png');
                  await file.writeAsBytes(bytes);
                  filePath = file.path;
               } catch (e) {
                  debugPrint("Error saving base64 image: $e");
                  filePath = img; // Fallback
               }
            } else { filePath = img; }
            final prefs = await SharedPreferences.getInstance();
            await prefs.setString('custom_bg_base64_selected', filePath);
            await prefs.remove('backgroundImage');
            onSelected(filePath);
          },
          child: Container(
            margin: const EdgeInsets.only(left: 10),
            width: 80,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: settingsProvider.primaryColor, width: 1),
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(9),
              child: buildImage(img, fit: BoxFit.cover),
            ),
          ),
        );
      },
    );
  }

  Widget _buildGroup(
    BuildContext context,
    String title,
    List<Widget> children,
  ) {
    final settingsProvider = context.watch<SettingsProvider>();
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Container(
      width: double.infinity,
      margin: const EdgeInsets.only(bottom: 20),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: isDark ? Colors.black : Colors.white,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: settingsProvider.primaryColor, width: 2),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              color: settingsProvider.primaryColor,
              fontWeight: FontWeight.bold,
              fontSize: 15,
            ),
          ),
          const SizedBox(height: 15),
          ...children,
        ],
      ),
    );
  }

  Widget _visToggle(BuildContext context, String key, String title) {
    final settingsProvider = context.watch<SettingsProvider>();
    return SwitchListTile(
        title: Text(title, style: const TextStyle(fontSize: 14)),
        value: settingsProvider.homeVisibility[key] ?? true,
        onChanged: (v) => settingsProvider.setHomeVisibility(key, v),
        dense: true,
      );
  }
}
