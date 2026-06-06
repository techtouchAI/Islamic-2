import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart' as intl;
import '../utils/string_extensions.dart';

class TasbihSection extends StatefulWidget {
  const TasbihSection({super.key});

  @override
  State<TasbihSection> createState() => _TasbihSectionState();
}

class _TasbihSectionState extends State<TasbihSection> {
  int _counter = 0;
  int _lifetimeCounter = 0;
  String _currentDhikr = 'سبحان الله';

  @override
  void initState() {
    super.initState();
    _loadLifetimeCounter();
  }

  Future<void> _loadLifetimeCounter() async {
    final prefs = await SharedPreferences.getInstance();
    setState(() {
      _lifetimeCounter = prefs.getInt('lifetime_tasbih_$_currentDhikr') ?? 0;
    });
  }

  Future<void> _incrementLifetimeCounter() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('lifetime_tasbih_$_currentDhikr', _lifetimeCounter);
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(
                context,
              ).colorScheme.primary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(15),
            ),
            child: Column(
              children: [
                Text(
                  _currentDhikr,
                  style: TextStyle(fontFamily: 'OmarNaskh',
                    fontSize: 35,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 20),
                GestureDetector(
                  onTap: () {
                    setState(() {
                      _counter++;
                      _lifetimeCounter++;
                    });
                    _incrementLifetimeCounter();
                  },
                  child: Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(100),
                      onTap: () {
                        HapticFeedback.lightImpact();
                        setState(() {
                          _counter++;
                          _lifetimeCounter++;
                        });
                        _incrementLifetimeCounter();
                      },
                      child: Container(
                        width: 200,
                        height: 200,
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: RadialGradient(
                            colors: [
                              Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.2),
                              Theme.of(
                                context,
                              ).colorScheme.primary.withValues(alpha: 0.05),
                            ],
                          ),
                          border: Border.all(
                            color: Theme.of(
                              context,
                            ).colorScheme.primary.withValues(alpha: 0.5),
                            width: 2,
                          ),
                        ),
                        child: Center(
                          child: Text(
                            '$_counter'.toEasternArabic(),
                            style: TextStyle(
                              fontSize: 70,
                              fontWeight: FontWeight.bold,
                              color: Theme.of(context).colorScheme.primary,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Text(
                  'المجموع الكلي: ${intl.NumberFormat.decimalPattern().format(_lifetimeCounter).toEasternArabic()}',
                  style: TextStyle(fontFamily: 'OmarNaskh',
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 50),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                icon: const Icon(Icons.refresh, size: 30),
                onPressed: () {
                  setState(() {
                    _counter = 0;
                  });
                },
                color: Theme.of(context).colorScheme.primary,
                tooltip: 'تصفير',
              ),
              const SizedBox(width: 30),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(15),
                  border: Border.all(
                    color: Theme.of(
                      context,
                    ).colorScheme.primary.withValues(alpha: 0.5),
                  ),
                ),
                child: DropdownButton<String>(
                  value: _currentDhikr,
                  underline: const SizedBox(),
                  icon: Icon(
                    Icons.arrow_drop_down,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  onChanged: (String? newValue) {
                    if (newValue != null) {
                      setState(() {
                        _currentDhikr = newValue;
                        _counter = 0;
                      });
                      _loadLifetimeCounter();
                    }
                  },
                  items: <String>[
                    'سبحان الله',
                    'الحمد لله',
                    'لا إله إلا الله',
                    'الله أكبر',
                    'أستغفر الله',
                    'اللهم صل على محمد وآل محمد',
                  ].map<DropdownMenuItem<String>>((String value) {
                    return DropdownMenuItem<String>(
                      value: value,
                      child: Text(
                        value,
                        style: const TextStyle(fontSize: 14),
                      ),
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}
