import 'dart:math';

import 'package:flutter/material.dart';

import '../models/recipe.dart';
import '../services/template_service.dart';
import '../widgets/app_drawer.dart';
import '../widgets/recipe_card.dart';
import '../widgets/top_nav_tiles.dart';

// ============================================================================
// RecipePickerScreen
// ----------------------------------------------------------------------------
// The "Pomóż mi wybrać" destination: rather than browsing the full recipe
// list (RecipesScreen), the user just taps a button and gets a single,
// randomly-picked cocktail from the currently active recipe template,
// rendered with the same RecipeCard used there.
// ============================================================================
class RecipePickerScreen extends StatefulWidget {
  const RecipePickerScreen({super.key});

  @override
  State<RecipePickerScreen> createState() => _RecipePickerScreenState();
}

class _RecipePickerScreenState extends State<RecipePickerScreen> {
  final _random = Random();

  // Only the recipes that can currently be prepared (see Recipe.isAvailable)
  // - unlike RecipesScreen, this screen has no toggle to show the rest,
  // since the whole point is "what can I actually make right now".
  List<Recipe> _availableRecipes = [];
  bool _isLoading = true;
  Recipe? _picked;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final template = await TemplateService.resolveActiveRecipeTemplate();
    final recipes = await TemplateService.loadRecipes(template);
    final availableMatchKeys = await TemplateService.loadAvailableMatchKeys();

    if (!mounted) return;

    setState(() {
      _availableRecipes = recipes.where((r) => r.isAvailable(availableMatchKeys)).toList();
      _isLoading = false;
    });
  }

  void _pickRandom() {
    setState(() => _picked = _availableRecipes[_random.nextInt(_availableRecipes.length)]);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Pomóż mi wybrać')),
      drawer: const AppDrawer(),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _availableRecipes.isEmpty
              ? const Center(child: Text('Brak dostępnych przepisów.'))
              : Column(
                  children: [
                    const TopNavTiles(),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
                      child: FilledButton.icon(
                        onPressed: _pickRandom,
                        icon: const Icon(Icons.casino_outlined),
                        label: const Text('Wylosuj mi drinka'),
                      ),
                    ),
                    Expanded(
                      child: _picked == null
                          ? const Center(child: Text('Kliknij przycisk, aby wylosować drinka.'))
                          : ListView(
                              children: [RecipeCard(recipe: _picked!)],
                            ),
                    ),
                  ],
                ),
    );
  }
}
