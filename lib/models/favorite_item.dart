import 'package:hive/hive.dart';

class FavoriteItem extends HiveObject {
  final String id;
  final String title;
  final String content;
  final String? sourceSection;
  final DateTime timestamp;
  final bool isCustom;

  FavoriteItem({
    required this.id,
    required this.title,
    required this.content,
    this.sourceSection,
    required this.timestamp,
    required this.isCustom,
  });

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'title': title,
      'content': content,
      'sourceSection': sourceSection,
      'timestamp': timestamp.toIso8601String(),
      'isCustom': isCustom,
    };
  }

  factory FavoriteItem.fromJson(Map<String, dynamic> json) {
    return FavoriteItem(
      id: json['id'] as String,
      title: json['title'] as String,
      content: json['content'] as String,
      sourceSection: json['sourceSection'] as String?,
      timestamp: DateTime.parse(json['timestamp'] as String),
      isCustom: json['isCustom'] as bool,
    );
  }
}

class FavoriteItemAdapter extends TypeAdapter<FavoriteItem> {
  @override
  final int typeId = 0; // Choose a unique typeId for your adapter

  @override
  FavoriteItem read(BinaryReader reader) {
    final numOfFields = reader.readByte();
    final fields = <int, dynamic>{
      for (int i = 0; i < numOfFields; i++) reader.readByte(): reader.read(),
    };
    return FavoriteItem(
      id: fields[0] as String,
      title: fields[1] as String,
      content: fields[2] as String,
      sourceSection: fields[3] as String?,
      timestamp: fields[4] as DateTime,
      isCustom: fields[5] as bool,
    );
  }

  @override
  void write(BinaryWriter writer, FavoriteItem obj) {
    writer
      ..writeByte(6)
      ..writeByte(0)
      ..write(obj.id)
      ..writeByte(1)
      ..write(obj.title)
      ..writeByte(2)
      ..write(obj.content)
      ..writeByte(3)
      ..write(obj.sourceSection)
      ..writeByte(4)
      ..write(obj.timestamp)
      ..writeByte(5)
      ..write(obj.isCustom);
  }

  @override
  int get hashCode => typeId.hashCode;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is FavoriteItemAdapter &&
          runtimeType == other.runtimeType &&
          typeId == other.typeId;
}
