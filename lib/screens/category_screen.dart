import 'package:flutter/material.dart';
import '../models/category.dart';
import '../models/ingredient.dart';
import 'ingredients_screen.dart';

class CategoryScreen extends StatelessWidget {
  final Category category;
  final List<Category> allCategories;

  const CategoryScreen({
    super.key,
    required this.category,
    required this.allCategories,
  });

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(category.name),
      ),
      body: Column(
        children: [
          // Show ingredients in this category (if any)
          if (category.ingredients.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Ingredients in this category:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: category.ingredients.length,
                itemBuilder: (context, index) {
                  final ingredient = category.ingredients[index];
                  return ListTile(
                    title: Text(ingredient.name),
                    subtitle: Text(ingredient.producer),
                    trailing: Text('${ingredient.bottlesCount} bottles'),
                    onTap: () => Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (context) => IngredientsScreen(
                          ingredients: [ingredient],
                          title: ingredient.name,
                          allCategories: allCategories,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          // Show subcategories
          if (category.subcategories.isNotEmpty) ...[
            const Padding(
              padding: EdgeInsets.all(8.0),
              child: Text(
                'Subcategories:',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
            Expanded(
              child: ListView.builder(
                shrinkWrap: true,
                itemCount: category.subcategories.length,
                itemBuilder: (context, index) {
                  final subcategory = category.subcategories[index];
                  return Card(
                    margin: const EdgeInsets.all(8.0),
                    child: ListTile(
                      title: Text(subcategory.name),
                      subtitle: Text(
                        '${subcategory.allIngredients.length} ingredients',
                      ),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (context) => CategoryScreen(
                            category: subcategory,
                            allCategories: allCategories,
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ],
      ),
    );
  }
}
