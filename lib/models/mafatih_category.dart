class MafatihCategory {
  final int id;
  final String title;
  final int parentId;

  MafatihCategory({
    required this.id,
    required this.title,
    required this.parentId,
  });

  factory MafatihCategory.fromMap(Map<String, dynamic> map) {
    return MafatihCategory(
      id: map['id'] as int,
      title: map['title'] as String? ?? 'بدون عنوان',
      parentId: map['parent_id'] as int? ?? 0,
    );
  }
}
