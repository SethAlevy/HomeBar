import 'package:flutter/material.dart';

import '../models/recipe.dart';

// ============================================================================
// RecipeCard
// ----------------------------------------------------------------------------
// A detail card for one recipe: name, its ingredient list, preparation
// steps, an optional comment, and tags - each section separated by a
// Divider. Shared between RecipesScreen (a list of these) and
// RecipePickerScreen (a single randomly-picked one), so the recipe layout
// only has to be defined once.
// ============================================================================
class RecipeCard extends StatelessWidget {
  final Recipe recipe;

  const RecipeCard({super.key, required this.recipe});

  @override
  Widget build(BuildContext context) {
    // Every field below is optional except the name, so the sections below
    // are collected into a list first and separated with Dividers only
    // between whichever of them actually ended up present.
    final sections = <Widget>[];

    if (recipe.ingredients.isNotEmpty) {
      sections.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: recipe.ingredients
              .map((i) => Padding(
                    padding: const EdgeInsets.only(bottom: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(child: Text(i.name)),
                        Text(i.amount, style: Theme.of(context).textTheme.bodyMedium),
                      ],
                    ),
                  ))
              .toList(),
        ),
      );
    }

    if (recipe.instructionSteps.isNotEmpty) {
      sections.add(
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (var i = 0; i < recipe.instructionSteps.length; i++)
              Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Text('${i + 1}. ${recipe.instructionSteps[i]}'),
              ),
          ],
        ),
      );
    }

    if (recipe.comments.isNotEmpty) {
      sections.add(
        Text(
          recipe.comments,
          style: Theme.of(context).textTheme.bodyMedium?.copyWith(fontStyle: FontStyle.italic),
        ),
      );
    }

    if (recipe.tags.isNotEmpty) {
      sections.add(
        Wrap(
          spacing: 4.0,
          children: recipe.tags
              .map((tag) => Chip(
                    label: Text(tag),
                    materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ))
              .toList(),
        ),
      );
    }

    return Card(
      margin: const EdgeInsets.all(8.0),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              recipe.name,
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
            ),
            for (final section in sections) ...[
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 10),
                child: Divider(height: 1),
              ),
              section,
            ],
          ],
        ),
      ),
    );
  }
}
