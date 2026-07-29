// Represents one item we keep in the home bar inventory.
class Ingredient {
  // Display name (e.g., "Bacardi", "Orange Juice").
  final String name;

  // Brand or producer of the ingredient.
  final String producer;

  // Free-form notes shown in the UI.
  final String description;

  // Mutable count because users can update stock over time.
  int bottlesCount;

  // Labels used for searching/filtering (e.g., "fresh", "bourbon").
  final List<String> tags;

  Ingredient({
    required this.name,
    required this.producer,
    required this.description,
    required this.bottlesCount,
    required this.tags,
  });

  // Converts this object into a plain map that can be serialized.
  // The keys are the data format used in our YAML file.
  Map<String, dynamic> toYaml() => {
        'name': name,
        'producer': producer,
        'description': description,
        'bottles_count': bottlesCount,
        'tags': tags,
      };

  // Creates an Ingredient from parsed YAML data.
  // Fallback defaults keep the app stable when a field is missing.
  factory Ingredient.fromYaml(Map<String, dynamic> yaml) => Ingredient(
        name: yaml['name'] ?? '',
        producer: yaml['producer'] ?? '',
        description: yaml['description'] ?? '',
        bottlesCount: yaml['bottles_count'] ?? 0,
        tags: List<String>.from(yaml['tags'] ?? []),
      );

}
