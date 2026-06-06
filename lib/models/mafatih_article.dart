class MafatihArticle {
  final int id;
  final String groupId;
  final String title;
  final String text;
  final String? sound;

  MafatihArticle({
    required this.id,
    required this.groupId,
    required this.title,
    required this.text,
    this.sound,
  });

  factory MafatihArticle.fromMap(Map<String, dynamic> map) {
    return MafatihArticle(
      id: map['id'] as int,
      groupId: map['group_id'] as String? ?? '',
      title: map['title'] as String? ?? 'بدون عنوان',
      text: map['text'] as String? ?? '',
      sound: map['sound'] as String?,
    );
  }
}
