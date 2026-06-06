import 'package:flutter/material.dart';
import '../../data/data_manager.dart';
import '../../services/mafatih_service.dart';
import '../../ui/calendar/hijri_calendar_screen.dart';
import '../../ui/qibla/qibla_screen.dart';
import '../../presentation/screens/istikhara_screen.dart';
import '../../main.dart'; // For buildImage and getMaterialIcon

class AppDrawer extends StatelessWidget {
  final String currentSection;
  final ValueChanged<String> onNavigate;
  const AppDrawer({
    super.key,
    required this.currentSection,
    required this.onNavigate,
  });

  @override
  Widget build(BuildContext context) {
    final about = DataManager.getAbout();
    final settings = DataManager.getSettings();
    final sections = DataManager.getSections();
    return Drawer(
      child: Column(
        children: [
          DrawerHeader(
            padding: EdgeInsets.zero,
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topRight,
                end: Alignment.bottomLeft,
                colors: [
                  Theme.of(context).colorScheme.primary,
                  Theme.of(context).colorScheme.primary.withValues(alpha: 0.8),
                ],
              ),
            ),
            child: Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  buildImage(
                    settings['custom_logo_base64']?.toString() ??
                        settings['logo_image']?.toString(),
                    height: 60,
                  ),
                  const SizedBox(height: 10),
                  const Text(
                    'تطبيق الذاكرين',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 24,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(
                    about['developer_name']?.toString() ?? '',
                    style: const TextStyle(color: Colors.white70, fontSize: 14),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: ListView(
              padding: EdgeInsets.zero,
              children: [
                _buildItem(context, 'home', 'الرئيسية', Icons.home),
                _buildItem(
                  context,
                  'prayer_times',
                  'أوقات الصلاة',
                  Icons.access_time,
                ),
                _buildItem(
                  context,
                  'tasbih',
                  'المسبحة الإلكترونية',
                  Icons.vibration,
                ),
                ...sections.entries.where((e) => e.key != 'istikhara').map(
                      (e) => _buildItem(
                        context,
                        e.key,
                        e.value['title'],
                        getMaterialIcon(e.value['icon']),
                      ),
                    ),
                const Divider(),
                ListTile(
                  leading: const Icon(Icons.calendar_today),
                  title: const Text('التقويم الهجري',
                      style: TextStyle(fontSize: 16)),
                  onTap: () {
                    Navigator.pop(context); // close drawer
                    Navigator.push(
                        context,
                        MaterialPageRoute(
                            builder: (_) => HijriCalendarScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.explore),
                  title: const Text('اتجاه القبلة',
                      style: TextStyle(fontSize: 16)),
                  onTap: () {
                    Navigator.pop(context); // close drawer
                    Navigator.push(context,
                        MaterialPageRoute(builder: (_) => QiblaScreen()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.book),
                  title: const Text('خيرة القرآن الكريم',
                      style: TextStyle(fontSize: 16)),
                  onTap: () {
                    Navigator.pop(context); // close drawer
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (c) => const IstikharaScreen(),
                      ),
                    );
                  },
                ),
                const Divider(),
                _buildItem(context, 'favorites', 'المحفوظات', Icons.favorite),
                _buildItem(context, 'about', 'حول المطور', Icons.person),
                _buildItem(context, 'settings', 'الإعدادات', Icons.settings),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildItem(
    BuildContext context,
    String id,
    String title,
    IconData icon,
  ) {
    final bool active = currentSection == id;
    int count = 0;
    Widget? trailingWidget;

    if (id != 'mafatih') {
      if (id == 'fatawa' || id == 'imam_ali' || id == 'dreams') {
        final cats = DataManager.getItems(id);
        for (var cat in cats) {
          count += DataManager.getItems(
            '${id}_cat_${cat["id"]?.toString()}',
          ).length;
        }
      } else {
        count = DataManager.getItems(id).length;
      }
      trailingWidget = count > 0 ? CountBadge(count: count) : null;
    } else {
      trailingWidget = FutureBuilder<int>(
        future: MafatihService.getTotalArticlesCount(),
        builder: (context, snapshot) {
          if (snapshot.hasData && snapshot.data! > 0) {
            return CountBadge(count: snapshot.data!);
          }
          return const SizedBox();
        },
      );
    }

    return ListTile(
      leading: Icon(
        icon,
        color: active ? Theme.of(context).colorScheme.primary : null,
      ),
      title: Text(
        title,
        style: TextStyle(
          fontWeight: active ? FontWeight.bold : FontWeight.normal,
          fontSize: 16,
        ),
      ),
      trailing: trailingWidget,
      selected: active,
      selectedTileColor: Theme.of(
        context,
      ).colorScheme.primary.withValues(alpha: 0.1),
      onTap: () => onNavigate(id),
    );
  }
}

class CountBadge extends StatelessWidget {
  final int count;
  const CountBadge({required this.count});
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.primary.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$count',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.bold,
          color: Theme.of(context).colorScheme.primary,
        ),
      ),
    );
  }
}
