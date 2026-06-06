import 'package:flutter/material.dart';
import '../../services/mafatih_service.dart';
import '../../models/mafatih_category.dart';
import '../../models/mafatih_article.dart';
import '../reader/reader_page.dart';
import '../widgets/app_drawer.dart'; // For CountBadge
import '../../services/favorites_service.dart'; // For Favorites
import '../../models/favorite_item.dart';
import '../widgets/app_standard_card.dart';
import '../../theme/app_card_theme.dart';

class MafatihSection extends StatefulWidget {
  final double fontSizeFactor;
  final double uiOpacity;

  const MafatihSection({
    super.key,
    required this.fontSizeFactor,
    required this.uiOpacity,
  });

  @override
  State<MafatihSection> createState() => _MafatihSectionState();
}

class _MafatihSectionState extends State<MafatihSection> {
  Future<List<MafatihCategory>>? _categoriesFuture;

  @override
  void initState() {
    super.initState();
    _categoriesFuture = MafatihService.getCategories();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<MafatihCategory>>(
      future: _categoriesFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Text(
              'حدث خطأ أثناء تحميل البيانات: ${snapshot.error}',
              style: const TextStyle(color: Colors.red),
            ),
          );
        }
        if (!snapshot.hasData || snapshot.data!.isEmpty) {
          return const Center(child: Text('لا توجد أقسام متوفرة'));
        }

        final categories = snapshot.data!;
        final isDark = Theme.of(context).brightness == Brightness.dark;

        return DefaultTabController(
          length: categories.length,
          child: Column(
            children: [
              Container(
                width: double.infinity,
                decoration: BoxDecoration(
                  color: isDark
                      ? Colors.black.withValues(alpha: 0.5)
                      : const Color(0xFFFDFBF7),
                  border: Border(
                    bottom: BorderSide(
                      color: Theme.of(context)
                          .colorScheme
                          .primary
                          .withValues(alpha: 0.2),
                    ),
                  ),
                ),
                child: TabBar(
                  isScrollable: true,
                  tabAlignment: TabAlignment.center,
                  indicatorColor: Theme.of(context).colorScheme.primary,
                  labelColor: Theme.of(context).colorScheme.primary,
                  unselectedLabelColor: isDark ? Colors.white70 : Colors.black54,
                  tabs: categories.map((cat) {
                    return Tab(
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(cat.title),
                          const SizedBox(width: 12),
                          FutureBuilder<int>(
                            future: MafatihService.getCategoryArticlesCount(cat.id),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) return const SizedBox();
                              return CountBadge(count: snapshot.data!);
                            },
                          ),
                        ],
                      ),
                    );
                  }).toList(),
                ),
              ),
              Expanded(
                child: TabBarView(
                  children: categories.map((cat) {
                    return _MafatihCategoryList(
                      categoryId: cat.id,
                      fontSizeFactor: widget.fontSizeFactor,
                      uiOpacity: widget.uiOpacity,
                    );
                  }).toList(),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _MafatihCategoryList extends StatefulWidget {
  final int categoryId;
  final double fontSizeFactor;
  final double uiOpacity;

  const _MafatihCategoryList({
    required this.categoryId,
    required this.fontSizeFactor,
    required this.uiOpacity,
  });

  @override
  State<_MafatihCategoryList> createState() => _MafatihCategoryListState();
}

class _MafatihCategoryListState extends State<_MafatihCategoryList> {
  Future<List<MafatihCategory>>? _subCategoriesFuture;
  Future<List<MafatihArticle>>? _articlesFuture;
  bool _hasSubCategories = false;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  void _loadData() async {
    _subCategoriesFuture = MafatihService.getSubCategories(widget.categoryId);
    final subCats = await _subCategoriesFuture;
    if (mounted) {
      if (subCats != null && subCats.isNotEmpty) {
        setState(() {
          _hasSubCategories = true;
        });
      } else {
        setState(() {
          _hasSubCategories = false;
          _articlesFuture = MafatihService.getArticles(widget.categoryId);
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_subCategoriesFuture == null) {
       return const Center(child: CircularProgressIndicator());
    }

    return FutureBuilder<List<MafatihCategory>>(
      future: _subCategoriesFuture,
      builder: (context, subCatSnapshot) {
        if (subCatSnapshot.connectionState == ConnectionState.waiting) {
          return const Center(child: CircularProgressIndicator());
        }

        if (_hasSubCategories) {
           final subCategories = subCatSnapshot.data!;
           return ListView.builder(
              physics: const BouncingScrollPhysics(),
              itemCount: subCategories.length,
              padding: const EdgeInsets.only(bottom: 20),
              itemBuilder: (context, index) {
                final subCat = subCategories[index];
                return AppStandardCard(
                  uiOpacity: widget.uiOpacity,
                  customPadding: EdgeInsets.zero,
                  child: ListTile(
                    contentPadding: AppCardTheme.padding,
                    title: Text(
                      subCat.title,
                      style: TextStyle(
                        fontSize: 18 * widget.fontSizeFactor,
                        fontWeight: FontWeight.bold,
                        fontFamily: AppCardTheme.fontFamily,
                        color: Theme.of(context).cardColor.contrastTextColor,
                      ),
                    ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          FutureBuilder<int>(
                            future: MafatihService.getCategoryArticlesCount(subCat.id),
                            builder: (context, snapshot) {
                              if (!snapshot.hasData) return const SizedBox();
                              return CountBadge(count: snapshot.data!);
                            },
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.folder_open,
                            size: 20,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                    ),
                    onTap: () {
                      Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => MafatihSubCategoryScreen(
                            categoryId: subCat.id,
                            categoryTitle: subCat.title,
                            fontSizeFactor: widget.fontSizeFactor,
                            uiOpacity: widget.uiOpacity,
                          ),
                        ),
                      );
                    },
                  ),
                );
              },
           );
        } else {
           if (_articlesFuture == null) {
              return const Center(child: CircularProgressIndicator());
           }
           return FutureBuilder<List<MafatihArticle>>(
            future: _articlesFuture,
            builder: (context, articleSnapshot) {
              if (articleSnapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (articleSnapshot.hasError) {
                return Center(
                  child: Text('خطأ: ${articleSnapshot.error}'),
                );
              }
              if (!articleSnapshot.hasData || articleSnapshot.data!.isEmpty) {
                return const Center(child: Text('لا توجد نصوص في هذا القسم'));
              }

              final articles = articleSnapshot.data!;
              return ListView.builder(
                physics: const BouncingScrollPhysics(),
                itemCount: articles.length,
                padding: const EdgeInsets.only(bottom: 20),
                itemBuilder: (context, index) {
                  final article = articles[index];
                  final title = article.title;
                  final text = article.text;

                  return AppStandardCard(
                    uiOpacity: widget.uiOpacity,
                    customPadding: EdgeInsets.zero,
                    child: ListTile(
                      contentPadding: AppCardTheme.padding,
                      title: Text(
                        title,
                        style: TextStyle(
                          fontSize: 18 * widget.fontSizeFactor,
                          fontWeight: FontWeight.bold,
                          fontFamily: AppCardTheme.fontFamily,
                          color: Theme.of(context).cardColor.contrastTextColor,
                        ),
                      ),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Builder(builder: (context) {
                            final itemId = article.id.toString();
                            return ValueListenableBuilder<List<FavoriteItem>>(
                              valueListenable:
                                  FavoritesService.instance.favoritesNotifier,
                              builder: (context, favorites, _) {
                                final isFav = FavoritesService.instance
                                    .isFavorite(itemId);
                                return IconButton(
                                  icon: Icon(
                                    isFav
                                        ? Icons.favorite
                                        : Icons.favorite_border,
                                    color: isFav
                                        ? Colors.red
                                        : Theme.of(context)
                                            .colorScheme
                                            .primary,
                                  ),
                                  onPressed: () {
                                    final item = FavoriteItem(
                                      id: itemId,
                                      title: title,
                                      content: text,
                                      sourceSection: 'mafatih',
                                      timestamp: DateTime.now(),
                                      isCustom: false,
                                    );
                                    FavoritesService.instance
                                        .toggleFavorite(item);
                                  },
                                );
                              },
                            );
                          }),
                          Icon(
                            Icons.arrow_forward_ios,
                            size: 16,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ],
                      ),
                      onTap: () {
                        Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (context) => ReaderPage(
                              title: title,
                              content: text,
                              fontSizeFactor: widget.fontSizeFactor,
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
              );
            },
          );
        }
      },
    );
  }
}

class MafatihSubCategoryScreen extends StatelessWidget {
  final int categoryId;
  final String categoryTitle;
  final double fontSizeFactor;
  final double uiOpacity;

  const MafatihSubCategoryScreen({
    super.key,
    required this.categoryId,
    required this.categoryTitle,
    required this.fontSizeFactor,
    required this.uiOpacity,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          categoryTitle,
          style: const TextStyle(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
         child: _MafatihCategoryList(
            categoryId: categoryId,
            fontSizeFactor: fontSizeFactor,
            uiOpacity: uiOpacity,
         ),
      ),
    );
  }
}
