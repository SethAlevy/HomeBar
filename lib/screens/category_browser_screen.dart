import 'package:flutter/material.dart';

import '../models/category.dart';
import '../services/file_handler.dart';
import 'ingredients_screen.dart';

class CategoryBrowserScreen extends StatefulWidget {
  const CategoryBrowserScreen({super.key});

  @override
  State<CategoryBrowserScreen> createState() => _CategoryBrowserScreenState();
}

class _CategoryBrowserScreenState extends State<CategoryBrowserScreen> {
  List<Category> _categories = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadCategories();
  }

  Future<void> _loadCategories() async {
    final categories = await FileHandler.loadCategories();

    if (!mounted) return;

    setState(() {
      _categories = categories;
      _isLoading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Składniki',           
          style: TextStyle(fontWeight: FontWeight.bold,),
        ),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              children: _categories
                  .map(
                    (category) => CategoryTreeItem(
                      category: category,
                      allCategories: _categories,
                    ),
                  )
                  .toList(),
            ),
    );
  }
}

class CategoryTreeItem extends StatefulWidget {
  final Category category;
  final List<Category> allCategories;

  const CategoryTreeItem({
    super.key,
    required this.category,
    required this.allCategories,
  });

  @override
  State<CategoryTreeItem> createState() => _CategoryTreeItemState();
}

class _CategoryTreeItemState extends State<CategoryTreeItem> {
  bool _isExpanded = false;

  @override
  Widget build(BuildContext context) {
    final hasSubcategories = widget.category.subcategories.isNotEmpty;

    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 4,
          ),
          child: Card(
            clipBehavior: Clip.antiAlias,
            color: Theme.of(context).colorScheme.secondaryContainer,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
            child: ListTile(
              contentPadding: const EdgeInsets.symmetric(
                horizontal: 20,
                vertical: 10,
              ),
              leading: Icon(
                hasSubcategories
                    ? Icons.folder_outlined
                    : Icons.liquor_outlined,
                color: Theme.of(context).colorScheme.onSecondaryContainer,
              ),
              title: Text(
                widget.category.name,
                style: TextStyle(
                  fontWeight: FontWeight.w600,
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
              subtitle: Text(
                '${widget.category.allIngredients.length} produktów',
                style: TextStyle(
                  color: Theme.of(context).colorScheme.onSecondaryContainer,
                ),
              ),
              onTap: () {
                Navigator.push(
                  context,
                  MaterialPageRoute(
                    builder: (context) => IngredientsScreen(
                      ingredients: widget.category.allIngredients,
                      title: widget.category.name,
                      allCategories: widget.allCategories,
                      sourceCategoryName: widget.category.name,
                    ),
                  ),
                );
              },
              trailing: hasSubcategories
                  ? IconButton(
                      icon: Icon(
                        _isExpanded
                            ? Icons.expand_less
                            : Icons.expand_more,
                      ),
                      color: Theme.of(context).colorScheme.onSecondaryContainer,
                      onPressed: () {
                        setState(() {
                          _isExpanded = !_isExpanded;
                        });
                      },
                    )
                  : null,
            ),
          ),
        ),

        if (_isExpanded)
          Padding(
            padding: const EdgeInsets.only(left: 24),
            child: Column(
              children: widget.category.subcategories
                  .map(
                    (subcategory) => CategoryTreeItem(
                      category: subcategory,
                      allCategories: widget.allCategories,
                    ),
                  )
                  .toList(),
            ),
          ),
      ],
    );
  }
}
