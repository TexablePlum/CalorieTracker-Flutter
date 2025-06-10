/// Podstawowy model przepisu na podstawie API
class Recipe {
  final String id;
  final String name;
  final String? instructions;
  final int servingsCount;
  final double totalWeightGrams;
  final int preparationTimeMinutes;
  final List<RecipeIngredient> ingredients;
  final String? createdByUserId;
  final DateTime createdAt;
  final Map<String, dynamic>? totalNutrition;

  Recipe({
    required this.id,
    required this.name,
    this.instructions,
    required this.servingsCount,
    required this.totalWeightGrams,
    required this.preparationTimeMinutes,
    required this.ingredients,
    this.createdByUserId,
    required this.createdAt,
    this.totalNutrition,
  });

  factory Recipe.fromJson(Map<String, dynamic> json) {
    return Recipe(
      id: json['id'] ?? '',
      name: json['name'] ?? '',
      instructions: json['instructions'],
      servingsCount: json['servingsCount'] ?? 1,
      totalWeightGrams: (json['totalWeightGrams'] ?? 0.0).toDouble(),
      preparationTimeMinutes: json['preparationTimeMinutes'] ?? 0,
      ingredients: (json['ingredients'] as List<dynamic>? ?? [])
          .map((i) => RecipeIngredient.fromJson(i))
          .toList(),
      createdByUserId: json['createdByUserId'],
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      totalNutrition: json['totalNutrition'],
    );
  }

  /// Czy aktualny użytkownik jest właścicielem przepisu
  bool isOwnedBy(String? currentUserId) {
    return currentUserId != null && 
           createdByUserId != null && 
           currentUserId == createdByUserId;
  }

  /// Czas przygotowania
  String get formattedPreparationTime {
    if (preparationTimeMinutes < 60) {
      return '${preparationTimeMinutes} min';
    } else {
      final hours = preparationTimeMinutes ~/ 60;
      final minutes = preparationTimeMinutes % 60;
      return minutes > 0 ? '${hours}h ${minutes}min' : '${hours}h';
    }
  }
}

class RecipeIngredient {
  final String productId;
  final String? productName;
  final double quantity;
  final String? unit;

  RecipeIngredient({
    required this.productId,
    this.productName,
    required this.quantity,
    this.unit,
  });

  factory RecipeIngredient.fromJson(Map<String, dynamic> json) {
    return RecipeIngredient(
      productId: json['productId'] ?? '',
      productName: json['productName'],
      quantity: (json['quantity'] ?? 0.0).toDouble(),
      unit: json['unit'],
    );
  }

  /// Formatowana ilość z jednostką
  String get formattedQuantity {
    final formattedNum = quantity == quantity.roundToDouble() 
        ? quantity.round().toString()
        : quantity.toStringAsFixed(1);
    
    return unit != null ? '$formattedNum $unit' : formattedNum;
  }
}