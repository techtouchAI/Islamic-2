class ContentItem {
  final String id;
  final String title;
  final String subtitle;
  final String content;
  final String sectionId;      // e.g., 'quran', 'dua', 'ziyarat'
  final String sectionName;    // e.g., 'القرآن الكريم', 'الأدعية'
  final String? category;

  // Extra fields added to support ReaderPage navigation from existing SearchDocument
  final int? surahNumber;
  final int? ayahNumber;
  final String? type;

  const ContentItem({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.content,
    required this.sectionId,
    required this.sectionName,
    this.category,
    this.surahNumber,
    this.ayahNumber,
    this.type,
  });

  bool matchesQuery(String query) {
    if (query.isEmpty) return true;
    final lowerQuery = query.toLowerCase();
    return title.toLowerCase().contains(lowerQuery) ||
           subtitle.toLowerCase().contains(lowerQuery) ||
           content.toLowerCase().contains(lowerQuery);
  }
}

class SectionGroup {
  final String sectionId;
  final String sectionName;
  final List<ContentItem> items;

  const SectionGroup({
    required this.sectionId,
    required this.sectionName,
    required this.items,
  });
}

class PaginationMetadata {
  final int currentPage;
  final int totalPages;
  final int totalItems;
  final int itemsPerPage;

  const PaginationMetadata({
    required this.currentPage,
    required this.totalPages,
    required this.totalItems,
    required this.itemsPerPage,
  });

  bool get hasPrevious => currentPage > 1;
  bool get hasNext => currentPage < totalPages;
}
