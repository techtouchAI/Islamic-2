import 'package:flutter/material.dart';
import 'dart:math';
import 'package:share_plus/share_plus.dart';
import 'package:flutter/services.dart';
import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart' as p;
import '../../data/data_manager.dart';
import '../../services/quran_service.dart';

enum IstikharaStep { dua, action, result }

class IstikharaScreen extends StatefulWidget {
  const IstikharaScreen({super.key});

  @override
  State<IstikharaScreen> createState() => _IstikharaScreenState();
}

class _IstikharaScreenState extends State<IstikharaScreen>
    with SingleTickerProviderStateMixin {
  final ValueNotifier<IstikharaStep> _stepNotifier = ValueNotifier(
    IstikharaStep.dua,
  );
  late AnimationController _animationController;
  late Animation<double> _flipAnimation;

  Map<String, dynamic>? _selectedIstikharaItem;
  int? _extractedPageNumber;
  String _resultText = '';
  String _descriptionText = '';
  List<Map<String, dynamic>> _verses = [];
  bool _isLoadingVerses = false;
  String? _errorMessage;

  Color _cardBgColor = const Color(0xFFFFFDF6);
  double _fontSizeOffset = 0.0;

  @override
  void initState() {
    super.initState();
    _animationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    // Animate from pi to 0 so the result is visible at the end of the animation.
    _flipAnimation = Tween<double>(begin: pi, end: 0).animate(
      CurvedAnimation(parent: _animationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _stepNotifier.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<List<Map<String, dynamic>>> _fetchVersesFromDb(int pageNumber) async {
    try {
      return await QuranService.getVersesByPage(pageNumber);
    } catch (e) {
      debugPrint("Error fetching verses: $e");
      return [];
    }
  }

  Future<void> _fetchIstikharaData() async {
    setState(() {
      _errorMessage = null;
      _isLoadingVerses = true;
    });

    try {
      final items = DataManager.getItems('istikhara');
      if (items.isEmpty) {
        if (mounted) {
          setState(() {
            _errorMessage = 'لا توجد بيانات متاحة للخيرة.';
            _isLoadingVerses = false;
          });
        }
        return;
      }

      final random = Random();
      final randomIndex = random.nextInt(items.length);
      _selectedIstikharaItem = items[randomIndex] as Map<String, dynamic>?;

      if (_selectedIstikharaItem == null) {
        if (mounted) {
          setState(() {
            _errorMessage = 'حدث خطأ في تحميل البيانات.';
            _isLoadingVerses = false;
          });
        }
        return;
      }

      final title = _selectedIstikharaItem!['title'].toString();
      final RegExp regExp = RegExp(r'\d+');
      final match = regExp.firstMatch(title);
      if (match != null) {
        _extractedPageNumber = int.tryParse(match.group(0)!);
      }

      final content = _selectedIstikharaItem!['content'].toString();
      final parts = content.split('\n');
      for (var part in parts) {
        if (part.startsWith('النتيجة:')) {
          _resultText = part.replaceFirst('النتيجة:', '').trim();
        } else if (part.startsWith('التفصيل:')) {
          _descriptionText = part.replaceFirst('التفصيل:', '').trim();
        }
      }

      if (_extractedPageNumber != null) {
        _verses = await _fetchVersesFromDb(_extractedPageNumber!);
      }

      if (mounted) {
        setState(() {
          _isLoadingVerses = false;
        });
      }
    } catch (e) {
      debugPrint("Error in _fetchIstikharaData: $e");
      if (mounted) {
        setState(() {
          _errorMessage = 'حدث خطأ أثناء تحميل البيانات. يرجى المحاولة مرة أخرى.';
          _isLoadingVerses = false;
        });
      }
    }
  }

  void _triggerIstikhara() async {
    await _fetchIstikharaData();
    if (_errorMessage == null) {
      _stepNotifier.value = IstikharaStep.result;
      _animationController.forward(from: 0);
    }
  }

  void _resetIstikhara() {
    _animationController.reset();
    _stepNotifier.value = IstikharaStep.dua;
    _selectedIstikharaItem = null;
    _extractedPageNumber = null;
    _resultText = '';
    _descriptionText = '';
    _verses = [];
    _errorMessage = null;
  }

  void _copyResult() {
    final textToCopy = 'نتيجة الخيرة:\n$_resultText\n\n$_descriptionText';
    Clipboard.setData(ClipboardData(text: textToCopy)).then((_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('تم النسخ إلى الحافظة')),
        );
      }
    }).catchError((error) {
      debugPrint("Error copying: $error");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء النسخ')),
        );
      }
    });
  }

  void _shareResult() async {
    try {
      final textToShare =
          'نتيجة الخيرة:\n$_resultText\n\n$_descriptionText\n\nتطبيق الذاكرين';
      await Share.share(textToShare);
    } catch (e) {
      debugPrint("Error sharing: $e");
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('حدث خطأ أثناء المشاركة')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('خيرة القرآن الكريم'),
        centerTitle: true,
        // ✅ استخدام ValueListenableBuilder لتحديث الـ actions ديناميكياً
        actions: [
          ValueListenableBuilder<IstikharaStep>(
            valueListenable: _stepNotifier,
            builder: (context, step, child) {
              if (step != IstikharaStep.result) return const SizedBox.shrink();
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    icon: const Icon(Icons.copy),
                    tooltip: 'نسخ النتيجة',
                    onPressed: _copyResult,
                  ),
                  IconButton(
                    icon: const Icon(Icons.share),
                    tooltip: 'مشاركة النتيجة',
                    onPressed: _shareResult,
                  ),
                  IconButton(
                    icon: const Icon(Icons.refresh),
                    tooltip: 'ابدأ من جديد',
                    onPressed: _resetIstikhara,
                  ),
                ],
              );
            },
          ),
        ],
      ),
      body: ValueListenableBuilder<IstikharaStep>(
        valueListenable: _stepNotifier,
        builder: (context, step, child) {
          switch (step) {
            case IstikharaStep.dua:
              return _buildDuaStep();
            case IstikharaStep.action:
              return _buildActionStep();
            case IstikharaStep.result:
              return _buildResultStep();
          }
        },
      ),
    );
  }

  Widget _buildDuaStep() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Image.asset(
                'assets/images/quran_icon_dummy.png',
                width: 250,
                height: 250,
              ),
              const SizedBox(height: 32),
              const Text(
                'دعاء الاستخارة',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFD4AF37),
                ),
              ),
              const SizedBox(height: 24),
              const Text(
                '«اللَّهُمَّ إِنِّي تَفَأَّلْتُ بِكِتَابِكَ، وَتَوَكَّلْتُ عَلَيْكَ، فَأَرِنِي مِنْ كِتَابِكَ مَا هُوَ مَكْتُومٌ مِنْ سِرِّكَ الْمَكْنُونِ فِي غَيْبِكَ»',
                textAlign: TextAlign.center,
                style: TextStyle(fontSize: 20, height: 1.8),
              ),
              const SizedBox(height: 48),
              ElevatedButton(
                onPressed: () {
                  _stepNotifier.value = IstikharaStep.action;
                },
                style: ElevatedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.white,
                ),
                child: const Text(
                  'الاستمرار',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildActionStep() {
    return Center(
      child: SingleChildScrollView(
        physics: const BouncingScrollPhysics(),
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'اعقد النية وتوكل على الله',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              const Text(
                'اضغط على المصحف لفتح الخيرة',
                style: TextStyle(fontSize: 16, color: Colors.grey),
              ),
              const SizedBox(height: 48),
              GestureDetector(
                onTap: _triggerIstikhara,
                child: Container(
                  padding: const EdgeInsets.all(40),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: Theme.of(context).colorScheme.surface,
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFD4AF37).withValues(alpha: 0.3),
                        blurRadius: 20,
                        spreadRadius: 5,
                      ),
                    ],
                    border: Border.all(
                      color: const Color(0xFFE0C9A6),
                      width: 2,
                    ),
                  ),
                  child: Image.asset(
                    'assets/images/quran_icon.png',
                    width: 250,
                    height: 250,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildResultStep() {
    if (_isLoadingVerses) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 16),
            Text('جاري تحميل البيانات...'),
          ],
        ),
      );
    }

    // ✅ عرض رسالة الخطأ إذا وجدت
    if (_errorMessage != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.error_outline,
                color: Colors.red,
                size: 64,
              ),
              const SizedBox(height: 16),
              Text(
                _errorMessage!,
                textAlign: TextAlign.center,
                style: const TextStyle(
                  fontSize: 18,
                  color: Colors.red,
                ),
              ),
              const SizedBox(height: 24),
              ElevatedButton.icon(
                onPressed: _resetIstikhara,
                icon: const Icon(Icons.refresh),
                label: const Text('إعادة المحاولة'),
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFD4AF37),
                  foregroundColor: Colors.white,
                ),
              ),
            ],
          ),
        ),
      );
    }

    if (_selectedIstikharaItem == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text(
              'عذراً، لم نتمكن من تحميل بيانات الخيرة.',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 18),
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _resetIstikhara,
              icon: const Icon(Icons.refresh),
              label: const Text('إعادة المحاولة'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFD4AF37),
                foregroundColor: Colors.white,
              ),
            ),
          ],
        ),
      );
    }

    final isDarkCard = _cardBgColor == const Color(0xFF2C2C2C);
    final textColor = isDarkCard ? Colors.white : Colors.black87;
    const primaryColor = Color(0xFFD4AF37);

    // ✅ حساب الآيات مرة واحدة فقط عند تغير البيانات
    String formattedVerses = '';
    if (_verses.isNotEmpty) {
      formattedVerses = _verses
          .map((v) {
            final text = v['ar_text'].toString().trim();
            final num = v['anum'];
            return '$text ﴿$num﴾';
          })
          .join(' ');
    }

    return Column(
      children: [
        Expanded(
          child: AnimatedBuilder(
            animation: _animationController,
            builder: (context, child) {
              final angle = _flipAnimation.value;

              final matrix = Matrix4.identity()
                ..setEntry(3, 2, 0.001) // perspective
                ..rotateY(-angle); // rotate negatively for RTL flip

              return Center(
                child: Transform(
                  transform: matrix,
                  alignment: Alignment.centerRight,
                  child: angle > pi / 2
                      ? _buildPageBack()
                      : SingleChildScrollView(
                          padding: const EdgeInsets.all(24.0),
                          child: Container(
                            padding: const EdgeInsets.all(24.0),
                            decoration: BoxDecoration(
                              color: _cardBgColor,
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(
                                color: const Color(0xFFE0C9A6),
                                width: 1.5,
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: Colors.black.withValues(alpha: 0.05),
                                  blurRadius: 10,
                                  offset: const Offset(0, 5),
                                ),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                if (_extractedPageNumber != null)
                                  Center(
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        shape: BoxShape.circle,
                                        border: Border.all(
                                          color: primaryColor,
                                          width: 2,
                                        ),
                                      ),
                                      child: Text(
                                        '$_extractedPageNumber',
                                        style: TextStyle(
                                          fontSize: 18 + _fontSizeOffset,
                                          fontWeight: FontWeight.bold,
                                          color: primaryColor,
                                        ),
                                      ),
                                    ),
                                  ),
                                const SizedBox(height: 16),
                                Text(
                                  _resultText,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 28 + _fontSizeOffset,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor,
                                  ),
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  _descriptionText,
                                  textAlign: TextAlign.center,
                                  style: TextStyle(
                                    fontSize: 18 + _fontSizeOffset,
                                    color: textColor,
                                    height: 1.6,
                                  ),
                                ),
                                const Padding(
                                  padding: EdgeInsets.symmetric(vertical: 24.0),
                                  child: Divider(color: Color(0xFFE0C9A6)),
                                ),
                                if (_verses.isNotEmpty) ...[
                                  Text(
                                    'سورة ${_verses.first['surah_name']} - الآيات',
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 16 + _fontSizeOffset,
                                      fontWeight: FontWeight.bold,
                                      color: primaryColor,
                                    ),
                                  ),
                                  const SizedBox(height: 16),
                                  Text(
                                    formattedVerses,
                                    textAlign: TextAlign.center,
                                    style: TextStyle(
                                      fontSize: 20 + _fontSizeOffset,
                                      height: 1.9,
                                      color: textColor,
                                      fontFamily: 'me_quran',
                                      inherit: false,
                                      decoration: TextDecoration.none,
                                    ),
                                  ),
                                ],
                                const SizedBox(height: 32),
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: List.generate(
                                    5,
                                    (index) => const Padding(
                                      padding: EdgeInsets.symmetric(
                                        horizontal: 4.0,
                                      ),
                                      child: Icon(
                                        Icons.star,
                                        color: Color(0xFFEED09D),
                                        size: 16,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                ),
              );
            },
          ),
        ),
        _buildBottomControlPanel(),
      ],
    );
  }

  Widget _buildPageBack() {
    return Transform(
      transform: Matrix4.rotationY(pi),
      alignment: Alignment.center,
      child: Container(
        margin: const EdgeInsets.all(24.0),
        decoration: BoxDecoration(
          color: _cardBgColor,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: const Color(0xFFE0C9A6), width: 1.5),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.05),
              blurRadius: 10,
              offset: const Offset(0, 5),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildBottomControlPanel() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 12.0),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.surfaceContainerHighest,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 10,
            offset: const Offset(0, -2),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Row(
              children: [
                _buildColorButton(const Color(0xFFFFFDF6)), // Cream
                _buildColorButton(const Color(0xFF2C2C2C)), // Dark
                _buildColorButton(const Color(0xFFE8EAF6)), // Pastel Blue
                _buildColorButton(const Color(0xFFE8F5E9)), // Mint Green
              ],
            ),
            Row(
              children: [
                IconButton(
                  icon: const Icon(Icons.remove),
                  tooltip: 'تصغير الخط',
                  onPressed: () {
                    setState(() {
                      _fontSizeOffset = max(-10.0, _fontSizeOffset - 2.0);
                    });
                  },
                ),
                const Text(
                  'Aa',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                ),
                IconButton(
                  icon: const Icon(Icons.add),
                  tooltip: 'تكبير الخط',
                  onPressed: () {
                    setState(() {
                      _fontSizeOffset = min(20.0, _fontSizeOffset + 2.0);
                    });
                  },
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildColorButton(Color color) {
    final isSelected = _cardBgColor == color;
    return GestureDetector(
      onTap: () {
        setState(() {
          _cardBgColor = color;
        });
      },
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 4.0),
        width: 32,
        height: 32,
        decoration: BoxDecoration(
          color: color,
          shape: BoxShape.circle,
          border: Border.all(
            color: isSelected
                ? Theme.of(context).colorScheme.primary
                : Colors.grey.withValues(alpha: 0.5),
            width: isSelected ? 2.0 : 1.0,
          ),
        ),
        child: isSelected
            ? Icon(
                Icons.check,
                size: 16,
                color: color == const Color(0xFF2C2C2C)
                    ? Colors.white
                    : Colors.black,
              )
            : null,
      ),
    );
  }
}
