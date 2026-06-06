import 'dart:convert';
import 'package:flutter/material.dart';
import '../ui/reader/reader_page.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import '../services/favorites_service.dart';
import '../models/favorite_item.dart';
import '../main.dart' show ReaderPage;

class FavoritesSection extends StatefulWidget {
  final double fontSizeFactor;
  final double uiOpacity;

  const FavoritesSection({
    super.key,
    required this.fontSizeFactor,
    required this.uiOpacity,
  });

  @override
  State<FavoritesSection> createState() => _FavoritesSectionState();
}

class _FavoritesSectionState extends State<FavoritesSection> {
  
  // -----------------------------------------------------------------
  // التصدير صار ذكي وسطر واحد بس يستدعي السيرفس (بدون دوخة الصلاحيات)
  // -----------------------------------------------------------------
  Future<void> _exportFavorites() async {
    await FavoritesService.instance.exportFavorites();
  }

  Future<void> _importFavorites() async {
    try {
      FilePickerResult? result = await FilePicker.platform.pickFiles(
        type: FileType.custom,
        allowedExtensions: ['json'],
      );

      if (result != null && result.files.single.path != null) {
        final file = File(result.files.single.path!);
        final jsonString = await file.readAsString(encoding: utf8);

        final success = await FavoritesService.instance.importFavorites(jsonString);

        if (mounted) {
          if (success) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('تم استيراد المحفوظات بنجاح')),
            );
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('فشل استيراد المحفوظات')),
            );
          }
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('حدث خطأ أثناء الاستيراد: $e')),
        );
      }
    }
  }

  void _showAddNoteSheet([FavoriteItem? existingNote]) {
    final titleController = TextEditingController(text: existingNote?.title ?? '');
    final contentController = TextEditingController(text: existingNote?.content ?? '');

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      builder: (context) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
            left: 16,
            right: 16,
            top: 16,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                existingNote == null ? 'إضافة ملاحظة جديدة' : 'تعديل الملاحظة',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: titleController,
                decoration: const InputDecoration(
                  labelText: 'العنوان',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              TextField(
                controller: contentController,
                maxLines: 5,
                decoration: const InputDecoration(
                  labelText: 'المحتوى',
                  border: OutlineInputBorder(),
                ),
              ),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () {
                  final title = titleController.text.trim();
                  final content = contentController.text.trim();
                  if (title.isNotEmpty && content.isNotEmpty) {
                    if (existingNote == null) {
                      FavoritesService.instance.addCustomNote(title, content);
                    } else {
                      FavoritesService.instance.updateCustomNote(
                          existingNote.id, title, content);
                    }
                    Navigator.pop(context);
                  }
                },
                child: const Text('حفظ'),
              ),
              const SizedBox(height: 16),
            ],
          ),
        );
      },
    );
  }

  void _showFabMenu() {
    showModalBottomSheet(
      context: context,
      builder: (context) {
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.note_add),
              title: const Text('إضافة ملاحظة'),
              onTap: () {
                Navigator.pop(context);
                _showAddNoteSheet();
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_download),
              title: const Text('استيراد'),
              onTap: () {
                Navigator.pop(context);
                _importFavorites();
              },
            ),
            ListTile(
              leading: const Icon(Icons.file_upload),
              title: const Text('تصدير'),
              onTap: () {
                Navigator.pop(context);
                _exportFavorites();
              },
            ),
          ],
        );
      },
    );
  }

  Widget _buildReferentialList(List<FavoriteItem> items) {
    if (items.isEmpty) {
      return const Center(child: Text('لا يوجد محتوى متوفر حالياً'));
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      padding: const EdgeInsets.only(bottom: 80),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withValues(alpha: widget.uiOpacity * 0.8),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 1.0,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            trailing: IconButton(
              icon: const Icon(Icons.delete_outline),
              onPressed: () {
                FavoritesService.instance.toggleFavorite(item);
              },
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (c) => ReaderPage(
                    title: item.title,
                    content: item.content,
                    fontSizeFactor: widget.fontSizeFactor,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildCustomNotesList(List<FavoriteItem> items) {
    if (items.isEmpty) {
      return const Center(child: Text('لا يوجد محتوى متوفر حالياً'));
    }

    return ListView.builder(
      physics: const BouncingScrollPhysics(),
      itemCount: items.length,
      padding: const EdgeInsets.only(bottom: 80),
      itemBuilder: (context, index) {
        final item = items[index];
        return Container(
          margin: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 8.0),
          decoration: BoxDecoration(
            color: Theme.of(context).cardColor.withValues(alpha: widget.uiOpacity * 0.8),
            borderRadius: BorderRadius.circular(15),
            border: Border.all(
              color: Theme.of(context).colorScheme.primary,
              width: 1.0,
            ),
          ),
          child: ListTile(
            contentPadding: const EdgeInsets.all(16),
            title: Text(
              item.title,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                item.content,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(fontFamily: 'OmarNaskh', fontSize: 16),
              ),
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit),
                  onPressed: () => _showAddNoteSheet(item),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () {
                    FavoritesService.instance.removeFavorite(item.id);
                  },
                ),
              ],
            ),
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (c) => ReaderPage(
                    title: item.title,
                    content: item.content,
                    fontSizeFactor: widget.fontSizeFactor,
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          toolbarHeight: 0,
          bottom: const TabBar(
            tabs: [
              Tab(text: "المحفوظات"),
              Tab(text: "ملاحظاتي"),
            ],
          ),
        ),
        body: ValueListenableBuilder<List<FavoriteItem>>(
          valueListenable: FavoritesService.instance.favoritesNotifier,
          builder: (context, favorites, _) {
            final referential = favorites.where((item) => !item.isCustom).toList();
            final custom = favorites.where((item) => item.isCustom).toList();

            return TabBarView(
              children: [
                _buildReferentialList(referential),
                _buildCustomNotesList(custom),
              ],
            );
          },
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: _showFabMenu,
          child: const Icon(Icons.add),
        ),
      ),
    );
  }
}
