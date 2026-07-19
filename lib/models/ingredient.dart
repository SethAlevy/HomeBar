class Ingredient {
  final String name;
  final String producer;
  final String description;
  int bottlesCount;
  final List<String> tags;

  Ingredient({
    required this.name,
    required this.producer,
    required this.description,
    required this.bottlesCount,
    required this.tags,
  });

  // Convert to YAML-compatible map
  Map<String, dynamic> toYaml() => {
        'name': name,
        'producer': producer,
        'description': description,
        'bottles_count': bottlesCount,
        'tags': tags,
      };

  // Create from YAML map
  factory Ingredient.fromYaml(Map<String, dynamic> yaml) => Ingredient(
        name: yaml['name'] ?? '',
        producer: yaml['producer'] ?? '',
        description: yaml['description'] ?? '',
        bottlesCount: yaml['bottles_count'] ?? 0,
        tags: List<String>.from(yaml['tags'] ?? []),
      );

  // Copy with updated fields
  Ingredient copyWith({
    String? name,
    String? producer,
    String? description,
    int? bottlesCount,
    List<String>? tags,
  }) =>
      Ingredient(
        name: name ?? this.name,
        producer: producer ?? this.producer,
        description: description ?? this.description,
        bottlesCount: bottlesCount ?? this.bottlesCount,
        tags: tags ?? this.tags,
      );
}
