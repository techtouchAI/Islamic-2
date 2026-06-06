import 'package:flutter/material.dart';
import 'package:hijri/hijri_calendar.dart';
import 'package:intl/date_symbol_data_local.dart';

import '../data/data_manager.dart';
import '../services/quran_service.dart';
import '../services/mafatih_service.dart';
import '../main.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _fadeController;

  @override
  void initState() {
    super.initState();
    // إعداد تأثير النبض/التلاشي لعبارة الصلاة على محمد وآل محمد
    _fadeController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _initializeApp();
  }

  @override
  void dispose() {
    _fadeController.dispose();
    super.dispose();
  }

  Future<void> _initializeApp() async {
    try {
      await initializeDateFormatting('ar_SA', null);
      HijriCalendar.setLocal('ar');

      // Load local content first
      await DataManager.loadContent();

      await QuranService.initDB();
      await MafatihService.initDB();

      if (!mounted) return;
      _navigateToHome();
    } catch (e) {
      debugPrint("Initialization Error in Splash: $e");
      if (mounted) _navigateToHome();
    }
  }

  void _navigateToHome() {
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(builder: (context) => const MainScaffold()),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Image.asset('assets/images/logo.png', height: 100),
            const SizedBox(height: 20),
            Text(
              DataManager.getMainScreenDua(),
              style: const TextStyle(fontFamily: 'me_quran', fontSize: 24),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 30),
            // النص المتحرك بديلاً عن الدائرة
            FadeTransition(
              opacity: _fadeController,
              child: Text(
                'اللهم صل على محمد وال محمد',
                style: TextStyle(
                  fontFamily: 'me_quran',
                  fontSize: 22,
                  color: Theme.of(context).primaryColor,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
