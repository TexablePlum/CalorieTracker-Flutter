/// Model dla formularza tworzenia/edycji przepisu
class RecipeFormData {
  String name;
  String instructions;
  int servingsCount;
  double totalWeightGrams;
  int preparationTimeMinutes;
  List<RecipeIngredientForm> ingredients;

  RecipeFormData({
    this.name = '',
    this.instructions = '',
    this.servingsCount = 1,
    this.totalWeightGrams = 0.0,
    this.preparationTimeMinutes = 0,
    List<RecipeIngredientForm>? ingredients,
  }) : ingredients = ingredients ?? [];

  /// sprawdza czy formularz jest poprawnie wypełniony
  bool get isValid {
    return name.trim().isNotEmpty &&
           servingsCount > 0 &&
           totalWeightGrams >= 0 &&
           preparationTimeMinutes >= 0 &&
           ingredients.isNotEmpty &&
           ingredients.every((i) => i.isValid);
  }

  Map<String, dynamic> toJson() {
    return {
      'name': name.trim(),
      'instructions': instructions.trim().isNotEmpty ? instructions.trim() : null,
      'servingsCount': servingsCount,
      'totalWeightGrams': totalWeightGrams,
      'preparationTimeMinutes': preparationTimeMinutes,
      'ingredients': ingredients.map((i) => i.toJson()).toList(),
    };
  }
}

/// Model składnika w formularzu
class RecipeIngredientForm {
  String productId;
  String productName;
  String quantity;

  RecipeIngredientForm({
    this.productId = '',
    this.productName = '',
    this.quantity = '',
  });

  bool get isValid {
    return productId.isNotEmpty && 
           productName.isNotEmpty &&
           _parsedQuantity != null && 
           _parsedQuantity! > 0;
  }

  double? get _parsedQuantity => double.tryParse(quantity);

  Map<String, dynamic> toJson() {
    return {
      'productId': productId,
      'quantity': _parsedQuantity ?? 0.0,
    };
  }
}