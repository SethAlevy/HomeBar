import 'package:flutter/material.dart';

import '../models/ingredient.dart';

// ============================================================================
// IngredientTile
// ----------------------------------------------------------------------------
// One ingredient, styled to match RecipeCard (bold name header, sections
// separated by a Divider, tags as chips) - always fully shown, no
// expand/collapse. Shared by IngredientsScreen (a flat, searchable list)
// and CategoryBrowserScreen (ingredients nested inline under their
// category), so ingredient browsing looks the same wherever it shows up.
// ============================================================================
class IngredientTile extends StatelessWidget {
  final Ingredient ingredient;

  const IngredientTile({required this.ingredient, super.key});

  @override
  Widget build(BuildContext context) {
    final hasDetails = ingredient.producer.isNotEmpty ||
        ingredient.description.isNotEmpty ||
        ingredient.tags.isNotEmpty;
    final mutedColor = Theme.of(context).colorScheme.onSurfaceVariant;

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    ingredient.name,
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                  ),
                ),
                Text('${ingredient.bottlesCount} but.', style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
            if (hasDetails) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1),
              ),
              if (ingredient.producer.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(ingredient.producer, style: TextStyle(color: mutedColor)),
                ),
              if (ingredient.description.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Text(ingredient.description),
                ),
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
          ],
        ),
      ),
    );
  }
}
