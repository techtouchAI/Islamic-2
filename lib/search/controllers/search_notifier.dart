import 'package:flutter/foundation.dart';
import 'search_controller.dart';
import '../models/search_models.dart';

class SearchNotifier extends ValueNotifier<SearchSnapshot> {
  final SearchController controller;

  SearchNotifier(this.controller) : super(_snapshot(controller)) {
    controller.addListener(_onChange);
  }

  static SearchSnapshot _snapshot(SearchController c) => SearchSnapshot(
        query: c.query,
        category: c.selectedCategory,
        isLoading: c.isLoading,
        items: c.paginatedFilteredItems,
        groups: c.groupedItems,
        pagination: c.pagination,
      );

  void _onChange() => value = _snapshot(controller);

  @override
  void dispose() {
    controller.removeListener(_onChange);
    controller.dispose();
    super.dispose();
  }
}

class SearchSnapshot {
  final String query;
  final String category;
  final bool isLoading;
  final List<ContentItem> items;
  final List<SectionGroup> groups;
  final PaginationMetadata pagination;

  const SearchSnapshot({
    required this.query,
    required this.category,
    required this.isLoading,
    required this.items,
    required this.groups,
    required this.pagination,
  });
}
