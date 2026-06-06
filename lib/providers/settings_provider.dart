import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../data/data_manager.dart';

class SettingsProvider extends ChangeNotifier {
  ThemeMode _themeMode = ThemeMode.light;
  double _fontSizeFactor = 1.0;
  Color _primaryColor = Colors.blue;
  double _uiOpacity = 1.0;
  String? _backgroundImagePath;
  String? _selectedBase64Bg;
  Color _cardColor = Colors.white;
  Map<String, bool> _homeVisibility = {};
  int _hijriAdjustment = 0;

  bool _isLoaded = false;
  bool get isLoaded => _isLoaded;

  ThemeMode get themeMode => _themeMode;
  double get fontSizeFactor => _fontSizeFactor;
  Color get primaryColor => _primaryColor;
  double get uiOpacity => _uiOpacity;
  String? get backgroundImagePath => _backgroundImagePath;
  String? get selectedBase64Bg => _selectedBase64Bg;
  Color get cardColor => _cardColor;
  Map<String, bool> get homeVisibility => _homeVisibility;
  int get hijriAdjustment => _hijriAdjustment;

  SettingsProvider() {
    loadSettings();
    DataManager.dbNotifier.addListener(loadSettings);
  }

  @override
  void dispose() {
    DataManager.dbNotifier.removeListener(loadSettings);
    super.dispose();
  }

  Future<void> loadSettings() async {
    final prefs = await SharedPreferences.getInstance();
    final dbSettings = DataManager.getSettings();

    int defaultPrimary =
        int.tryParse(dbSettings['primary_color'] ?? '0xFF2196F3') ?? 0xFF2196F3;
    int defaultCard =
        int.tryParse(dbSettings['card_color'] ?? '0xFFFFFFFF') ?? 0xFFFFFFFF;

    _themeMode = (prefs.getString('theme') ?? 'light') == 'light'
        ? ThemeMode.light
        : ThemeMode.dark;
    _fontSizeFactor = prefs.getDouble('fontSize') ?? 1.0;
    _primaryColor = Color(prefs.getInt('primaryColor') ?? defaultPrimary);
    _uiOpacity = prefs.getDouble('uiOpacity') ??
        (dbSettings['ui_opacity']?.toDouble() ?? 1.0);
    _backgroundImagePath = prefs.getString('backgroundImage');
    _selectedBase64Bg = prefs.getString('custom_bg_base64_selected');
    _cardColor = Color(prefs.getInt('cardColor') ?? defaultCard);
    _hijriAdjustment = prefs.getInt('hijri.date.correction.value') ?? 0;

    final sections = DataManager.getSections();
    final allSections = {
      ...sections,
      'hadith': {},
      'names_allah': {},
      'adhkar': {},
    };
    _homeVisibility = {};
    allSections.forEach((key, value) {
      _homeVisibility[key] =
          prefs.getBool('vis_$key') ?? (value['visible_home'] ?? true);
    });
    _homeVisibility['inspiration'] = prefs.getBool('vis_inspiration') ??
        (dbSettings['show_inspiration'] ?? true);
    _homeVisibility['day_dua'] = prefs.getBool('vis_day_dua') ?? true;

    _isLoaded = true;
    notifyListeners();
  }

  Future<void> _saveSetting(String key, dynamic value) async {
    final prefs = await SharedPreferences.getInstance();
    if (value is String) await prefs.setString(key, value);
    if (value is double) await prefs.setDouble(key, value);
    if (value is int) await prefs.setInt(key, value);
    if (value is bool) await prefs.setBool(key, value);
  }

  void toggleTheme() {
    _themeMode = _themeMode == ThemeMode.light ? ThemeMode.dark : ThemeMode.light;
    _saveSetting('theme', _themeMode == ThemeMode.light ? 'light' : 'dark');
    notifyListeners();
  }

  void setFontSizeFactor(double val) {
    _fontSizeFactor = val;
    _saveSetting('fontSize', val);
    notifyListeners();
  }

  void setPrimaryColor(Color c) {
    _primaryColor = c;
    _saveSetting('primaryColor', c.toARGB32());
    notifyListeners();
  }

  void setUiOpacity(double val) {
    _uiOpacity = val;
    _saveSetting('uiOpacity', val);
    notifyListeners();
  }

  void setBackgroundImagePath(String? path) async {
    _backgroundImagePath = path;
    final prefs = await SharedPreferences.getInstance();
    if (path != null) {
      _selectedBase64Bg = null;
      await prefs.remove('custom_bg_base64_selected');
      _saveSetting('backgroundImage', path);
    } else {
      await prefs.remove('backgroundImage');
    }
    notifyListeners();
  }

  void setBase64Bg(String? base64) {
    _selectedBase64Bg = base64;
    _backgroundImagePath = null;
    notifyListeners();
  }

  void setCardColor(Color c) {
    _cardColor = c;
    _saveSetting('cardColor', c.toARGB32());
    notifyListeners();
  }

  void setHomeVisibility(String key, bool val) {
    _homeVisibility[key] = val;
    _saveSetting('vis_$key', val);
    notifyListeners();
  }

  void setHijriAdjustment(int val) {
    _hijriAdjustment = val;
    _saveSetting('hijri.date.correction.value', val);
    notifyListeners();
  }
}
