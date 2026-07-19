import 'package:flutter/material.dart';
import '../models/ingredient.dart';
import '../models/category.dart';
import 'edit_ingredient_screen.dart';

class IngredientsScreen extends StatefulWidget {
  final List<Ingredient> ingredients;
  final String title;
  final List<Category> allCategories;

  const IngredientsScreen({
    super.key,
    required this.ingredients,
    required this.title,
    required this.allCategories,
  });

  @override
  State<IngredientsScreen> createState() => _IngredientsScreenState();
}

class _IngredientsScreenState extends State<IngredientsScreen> {
  List<Ingredient> _filteredIngredients = [];
  String _searchQuery = '';
  String _selectedTag = '';

  @override
  void initState() {
    super.initState();
    _filteredIngredients = widget.ingredients;
  }

  void _filterIngredients() {
    setState(() {
      _filteredIngredients = widget.ingredients.where((ingredient) {
        final matchesSearch = _searchQuery.isEmpty ||
            ingredient.name.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            ingredient.producer.toLowerCase().contains(_searchQuery.toLowerCase()) ||
            ingredient.description.toLowerCase().contains(_searchQuery.toLowerCase());
        final matchesTag = _selectedTag.isEmpty ||
            ingredient.tags.contains(_selectedTag);
        return matchesSearch && matchesTag;
      }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          IconButton(
            icon: const Icon(Icons.search),
            onPressed: () => _showSearchDialog(context),
          ),
          IconButton(
            icon: const Icon(Icons.filter_list),
            onPressed: () => _showTagFilterDialog(context),
          ),
        ],
      ),
      body: ListView.builder(
        itemCount: _filteredIngredients.length,
        itemBuilder: (context, index) {
          final ingredient = _filteredIngredients[index];
          return Card(
            margin: const EdgeInsets.all(8.0),
            child: ListTile(
              title: Text(ingredient.name),
              subtitle: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ingredient.producer),
                  Text(ingredient.description),
                  if (ingredient.tags.isNotEmpty)
                    Wrap(
                      spacing: 4.0,
                      children: ingredient.tags
                          .map((tag) => Chip(
                                label: Text(tag),
                                materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                              ))
                          .toList(),
                    ),
                ],
              ),
              trailing: Text('${ingredient.bottlesCount} bottles'),
            ),
          );
        },
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: () => Navigator.push(
          context,
          MaterialPageRoute(
            builder: (context) => EditIngredientScreen(
              ingredient: null,
              allCategories: widget.allCategories,
            ),
          ),
        ),
        child: const Icon(Icons.add),
      ),
    );
  }

  void _showSearchDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Search'),
        content: TextField(
          decoration: const InputDecoration(hintText: 'Search by name, producer, or description'),
          onChanged: (value) {
            _searchQuery = value;
            _filterIngredients();
          },
        ),
        actions: [
          TextButton(
            onPressed: () {
              _searchQuery = '';
              _filterIngredients();
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  void _showTagFilterDialog(BuildContext context) {
    // Collect all unique tags from all ingredients
    final allTags = <String>{};
    for (final category in widget.allCategories) {
      for (final ingredient in category.allIngredients) {
        allTags.addAll(ingredient.tags);
      }
    }

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Filter by Tag'),
        content: SizedBox(
          width: double.maxFinite,
          child: ListView.builder(
            shrinkWrap: true,
            itemCount: allTags.length,
            itemBuilder: (context, index) {
              final tag = allTags.elementAt(index);
              return ListTile(
                title: Text(tag),
                onTap: () {
                  _selectedTag = tag;
                  _filterIngredients();
                  Navigator.pop(context);
                },
              );
            },
          ),
        ),
        actions: [
          TextButton(
            onPressed: () {
              _selectedTag = '';
              _filterIngredients();
              Navigator.pop(context);
            },
            child: const Text('Clear'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }
}
