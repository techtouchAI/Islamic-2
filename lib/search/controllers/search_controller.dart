import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/search_models.dart';
import '../../services/search_engine.dart'; // To use fuzzyMatch if needed

class SearchController extends ChangeNotifier {
  // ─── Dependencies ───
  final List<ContentItem> _allItems;
  final List<String> _availableSections;

  // ─── State ───
  String _query = '';
  String _selectedCategory = 'all'; // 'all' = الكل
  int _currentPage = 1;
  static const int _itemsPerPage = 10;
  bool _isLoading = false;

  Timer? _debounceTimer;

  // ─── Cached Results ───
  List<ContentItem> _filteredItems = [];
  List<SectionGroup> _groupedItems = [];
  PaginationMetadata _pagination = const PaginationMetadata(
    currentPage: 1,
    totalPages: 0,
    totalItems: 0,
    itemsPerPage: _itemsPerPage,
  );

  // ─── Public Getters ───
  String get query => _query;
  String get selectedCategory => _selectedCategory;
  int get currentPage => _currentPage;
  bool get isLoading => _isLoading;
  List<ContentItem> get filteredItems => List.unmodifiable(_filteredItems);
  List<SectionGroup> get groupedItems => List.unmodifiable(_groupedItems);
  PaginationMetadata get pagination => _pagination;
  List<String> get availableSections => ['all', ..._availableSections];

  bool get isAllCategory => _selectedCategory == 'all';

  SearchController({
    required List<ContentItem> allItems,
    required List<String> availableSections,
  })  : _allItems = allItems,
        _availableSections = availableSections {
    SearchEngine.instance.isIndexingNotifier.addListener(_onIndexingStateChanged);
    _isLoading = SearchEngine.instance.isIndexingNotifier.value;
    _computeResults();
  }

  void _onIndexingStateChanged() {
    _isLoading = SearchEngine.instance.isIndexingNotifier.value;
    notifyListeners();
  }

  @override
  void dispose() {
    SearchEngine.instance.isIndexingNotifier.removeListener(_onIndexingStateChanged);
    _debounceTimer?.cancel();
    super.dispose();
  }

  // ─── Actions ───

  void updateQuery(String value) {
    final normalized = value.trim();
    if (_query == normalized) return;
    _query = normalized;
    _currentPage = 1; // Reset pagination on query change

    _isLoading = true;
    notifyListeners();

    _debounceTimer?.cancel();
    _debounceTimer = Timer(const Duration(milliseconds: 400), () {
      _computeResults();
    });
  }

  void selectCategory(String category) {
    if (_selectedCategory == category) return;
    _selectedCategory = category;
    _currentPage = 1; // Reset pagination on category change

    _isLoading = true;
    notifyListeners();

    _computeResults();
  }

  void goToPage(int page) {
    if (page < 1 || page > _pagination.totalPages || page == _currentPage) return;
    _currentPage = page;
    _computePagination(); // Only re-slice, no need to re-filter
    notifyListeners();
  }

  void nextPage() => goToPage(_currentPage + 1);
  void previousPage() => goToPage(_currentPage - 1);

  // ─── Core Logic ───

  Future<void> _computeResults() async {
    _isLoading = true;
    notifyListeners();

    // 1. Filter by category
    List<ContentItem> categoryFiltered;
    if (_selectedCategory == 'all') {
      categoryFiltered = _allItems;
    } else {
      categoryFiltered = _allItems.where((i) => i.sectionId == _selectedCategory).toList();
    }

    // 2. Filter by search query in background
    if (_query.isEmpty) {
      _filteredItems = [];
    } else {
      // Offload search logic to background isolate
      try {
        final currentQuery = _query;
        final results = await compute(_performSearch, {
          'items': categoryFiltered,
          'query': currentQuery,
        });

        // Prevent race condition: only apply if query hasn't changed
        if (_query == currentQuery) {
          _filteredItems = results;
        } else {
          return;
        }
      } catch (e) {
        debugPrint("Compute search error: $e");
        _filteredItems = [];
      }
    }

    // 3. Group if "All" category
    if (isAllCategory) {
      _groupedItems = _buildSectionGroups(_filteredItems);
    } else {
      _groupedItems = [];
    }

    // 4. Compute pagination
    _computePagination();

    _isLoading = false;
    notifyListeners();
  }

  static List<ContentItem> _performSearch(Map<String, dynamic> params) {
    final List<ContentItem> categoryFiltered = params['items'];
    final String query = params['query'];

    final normalizedQuery = SearchEngine.normalizeArabic(query);
    final queryWords = normalizedQuery.split(' ').where((w) => w.isNotEmpty).toList();

    if (queryWords.isEmpty) {
      return categoryFiltered;
    }

    List<Map<String, dynamic>> scoredItems = [];

    // Using a simple split ' ' since normalizeArabic collapses whitespace.
    // This avoids heavy Regex parsing for millions of words.
    for (var item in categoryFiltered) {
      bool allWordsMatched = true;
      int docScore = 0;

      final normalizedTitle = SearchEngine.normalizeArabic(item.title);
      final normalizedContent = SearchEngine.normalizeArabic(item.content);
      final normalizedCategory = SearchEngine.normalizeArabic(item.category ?? '');

      // Tokenize strings once per document
      final titleWords = normalizedTitle.split(' ').toSet();
      final contentWords = normalizedContent.split(' ').toSet();
      final categoryWords = normalizedCategory.split(' ').toSet();

      for (var word in queryWords) {
        bool wordMatched = false;
        int wordScore = 0;

        // Title Matching
        if (normalizedTitle == word) {
            wordMatched = true;
            wordScore += 20; // Exact match bonus
        } else if (titleWords.contains(word)) {
            wordMatched = true;
            wordScore += 10;
        }

        // Category Matching
        if (normalizedCategory == word || categoryWords.contains(word)) {
          wordMatched = true;
          wordScore += 4;
        }

        // Content Matching
        if (normalizedContent == word) {
             wordMatched = true;
             wordScore += 5;
        } else if (contentWords.contains(word)) {
          wordMatched = true;
          wordScore += 2;
        }

        if (!wordMatched) {
          allWordsMatched = false;
          break;
        }

        docScore += wordScore;
      }

      // Allow full exact phrase matches even if individual words failed (e.g. phrases with stop words)
      if (!allWordsMatched) {
          if (normalizedTitle.contains(normalizedQuery)) {
              allWordsMatched = true;
              docScore += 30;
          } else if (normalizedContent.contains(normalizedQuery)) {
              allWordsMatched = true;
              docScore += 5;
          }
      }

      if (allWordsMatched && docScore > 0) {
        scoredItems.add({'item': item, 'score': docScore});
      }
    }

    scoredItems.sort((a, b) {
      int scoreCompare = (b['score'] as int).compareTo(a['score'] as int);
      if (scoreCompare != 0) return scoreCompare;
      return (a['item'] as ContentItem).title.compareTo((b['item'] as ContentItem).title);
    });

    return scoredItems.map((e) => e['item'] as ContentItem).toList();
  }

  List<SectionGroup> _buildSectionGroups(List<ContentItem> items) {
    final Map<String, List<ContentItem>> map = {};
    for (final item in items) {
      map.putIfAbsent(item.sectionId, () => []).add(item);
    }
    return map.entries.map((e) {
      final sectionName = _allItems
          .firstWhere((i) => i.sectionId == e.key, orElse: () => items.first)
          .sectionName;
      return SectionGroup(
        sectionId: e.key,
        sectionName: sectionName,
        items: e.value,
      );
    }).toList();
  }

  void _computePagination() {
    final totalItems = _filteredItems.length;
    final totalPages = (totalItems / _itemsPerPage).ceil();
    final safeTotalPages = totalPages == 0 ? 1 : totalPages;

    // Clamp current page
    if (_currentPage > safeTotalPages) {
      _currentPage = safeTotalPages;
    }

    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, totalItems);

    // Slice the flattened list for current page
    final paginatedItems = _filteredItems.sublist(startIndex, endIndex);

    // Rebuild groups from paginated items if in "All" mode
    if (isAllCategory) {
      _groupedItems = _buildSectionGroups(paginatedItems);
    }

    // Let's safely handle this by updating the pagination logic
    _pagination = PaginationMetadata(
      currentPage: _currentPage,
      totalPages: safeTotalPages,
      totalItems: totalItems,
      itemsPerPage: _itemsPerPage,
    );
  }

  // Expose paginated items safely without destroying the filtered cache
  List<ContentItem> get paginatedFilteredItems {
    final startIndex = (_currentPage - 1) * _itemsPerPage;
    final endIndex = (startIndex + _itemsPerPage).clamp(0, _filteredItems.length);
    return _filteredItems.sublist(startIndex, endIndex);
  }
}
