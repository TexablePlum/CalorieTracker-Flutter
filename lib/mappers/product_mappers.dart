/// Mappery dla enumów produktów z backendu na polskie nazwy
class ProductMappers {
  
  /// Mapuje jednostki miary z enum na polskie nazwy
  static String mapUnit(String? unit) {
    if (unit == null || unit.isEmpty) return 'Nieznana';
    
    switch (unit.toLowerCase()) {
      case 'gram':
        return 'g';
      case 'milliliter':
        return 'ml';
      case 'piece':
        return 'szt.';
      default:
        return unit; // Fallback - zwraca oryginalną wartość
    }
  }

  /// Mapuje jednostki miary z polskiego na enum (dla API calls)
  static String mapUnitToEnum(String polishUnit) {
    switch (polishUnit.toLowerCase()) {
      case 'g':
      case 'gram':
      case 'gramy':
        return 'Gram';
      case 'ml':
      case 'milliliter':
      case 'mililitry':
        return 'Milliliter';
      case 'szt.':
      case 'szt':
      case 'sztuka':
      case 'sztuki':
      case 'piece':
        return 'Piece';
      default:
        return 'Gram'; // Domyślnie gramy
    }
  }

  /// Mapuje kategorie z enum na polskie nazwy
  static String mapCategory(String? category) {
    if (category == null || category.isEmpty) return 'Inne';
    
    switch (category.toLowerCase()) {
      case 'fruits':
        return 'Owoce';
      case 'vegetables':
        return 'Warzywa';
      case 'meatandpoultry':
        return 'Mięso i drób';
      case 'fishandseafood':
        return 'Ryby i owoce morza';
      case 'dairy':
        return 'Nabiał';
      case 'grainsandcereals':
        return 'Zboża i produkty zbożowe';
      case 'nutsanddriedfruits':
        return 'Bakalie i orzechy';
      case 'sweets':
        return 'Słodycze';
      case 'beverages':
        return 'Napoje';
      case 'oilsandfats':
        return 'Oleje i tłuszcze';
      case 'spicesandherbs':
        return 'Przyprawy i zioła';
      case 'readymeals':
        return 'Gotowe posiłki';
      case 'other':
        return 'Inne';
      default:
        return category; // Fallback - zwraca oryginalną wartość
    }
  }

  /// Mapuje kategorie z polskiego na enum (dla API calls)
  static String mapCategoryToEnum(String polishCategory) {
    switch (polishCategory.toLowerCase()) {
      case 'owoce':
        return 'Fruits';
      case 'warzywa':
        return 'Vegetables';
      case 'mięso i drób':
      case 'mięso':
      case 'drób':
        return 'MeatAndPoultry';
      case 'ryby i owoce morza':
      case 'ryby':
      case 'owoce morza':
        return 'FishAndSeafood';
      case 'nabiał':
        return 'Dairy';
      case 'zboża i produkty zbożowe':
      case 'zboża':
      case 'produkty zbożowe':
        return 'GrainsAndCereals';
      case 'bakalie i orzechy':
      case 'bakalie':
      case 'orzechy':
        return 'NutsAndDriedFruits';
      case 'słodycze':
        return 'Sweets';
      case 'napoje':
        return 'Beverages';
      case 'oleje i tłuszcze':
      case 'oleje':
      case 'tłuszcze':
        return 'OilsAndFats';
      case 'przyprawy i zioła':
      case 'przyprawy':
      case 'zioła':
        return 'SpicesAndHerbs';
      case 'gotowe posiłki':
      case 'gotowe':
        return 'ReadyMeals';
      case 'inne':
      default:
        return 'Other';
    }
  }

  /// Zwraca listę wszystkich dostępnych jednostek (dla dropdown'ów)
  static List<String> getAllUnits() {
    return ['g', 'ml', 'szt.'];
  }

  /// Zwraca listę wszystkich dostępnych kategorii (dla dropdown'ów)
  static List<String> getAllCategories() {
    return [
      'Owoce',
      'Warzywa',
      'Mięso i drób',
      'Ryby i owoce morza',
      'Nabiał',
      'Zboża i produkty zbożowe',
      'Bakalie i orzechy',
      'Słodycze',
      'Napoje',
      'Oleje i tłuszcze',
      'Przyprawy i zioła',
      'Gotowe posiłki',
      'Inne',
    ];
  }

  /// Zwraca enum jednostek z ikonami
  static List<Map<String, dynamic>> getUnitsWithIcons() {
    return [
      {'value': 'g', 'label': 'Gramy (g)', 'icon': '⚖️'},
      {'value': 'ml', 'label': 'Mililitry (ml)', 'icon': '🥤'},
      {'value': 'szt.', 'label': 'Sztuki (szt.)', 'icon': '🔢'},
    ];
  }

  /// Zwraca kategorie z ikonami
  static List<Map<String, dynamic>> getCategoriesWithIcons() {
    return [
      {'value': 'Owoce', 'icon': '🍎'},
      {'value': 'Warzywa', 'icon': '🥕'},
      {'value': 'Mięso i drób', 'icon': '🥩'},
      {'value': 'Ryby i owoce morza', 'icon': '🐟'},
      {'value': 'Nabiał', 'icon': '🥛'},
      {'value': 'Zboża i produkty zbożowe', 'icon': '🌾'},
      {'value': 'Bakalie i orzechy', 'icon': '🥜'},
      {'value': 'Słodycze', 'icon': '🍬'},
      {'value': 'Napoje', 'icon': '🥤'},
      {'value': 'Oleje i tłuszcze', 'icon': '🫒'},
      {'value': 'Przyprawy i zioła', 'icon': '🌿'},
      {'value': 'Gotowe posiłki', 'icon': '🍱'},
      {'value': 'Inne', 'icon': '📦'},
    ];
  }

  /// Helper do formatowania wartości odżywczych z jednostkami
  static String formatNutritionValue(dynamic value, String unit) {
    if (value == null) return '0 $unit';
    
    // Konwertuje na double jeśli to możliwe
    double? numValue;
    if (value is num) {
      numValue = value.toDouble();
    } else if (value is String) {
      numValue = double.tryParse(value);
    }
    
    if (numValue == null) return '0 $unit';
    
    // Format bez zbędnych zer po przecinku
    if (numValue == numValue.roundToDouble()) {
      return '${numValue.round()} $unit';
    } else {
      return '${numValue.toStringAsFixed(1)} $unit';
    }
  }

  /// Helper do bezpiecznego pobierania wartości numerycznych
  static double safeGetDouble(dynamic value, {double defaultValue = 0.0}) {
    if (value == null) return defaultValue;
    
    if (value is num) {
      return value.toDouble();
    } else if (value is String) {
      return double.tryParse(value) ?? defaultValue;
    }
    
    return defaultValue;
  }

  /// Helper do bezpiecznego pobierania wartości string
  static String safeGetString(dynamic value, {String defaultValue = ''}) {
    if (value == null) return defaultValue;
    return value.toString().trim();
  }
}