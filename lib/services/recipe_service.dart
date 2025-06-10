import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/recipe.dart';
import '../models/recipe_form.dart';

/// Podstawowy serwis do obsługi API przepisów
class RecipeService {
  final Dio _dio;

  RecipeService(this._dio);

  /// Pobiera listę wszystkich przepisów
  Future<List<Recipe>> getAllRecipes({int skip = 0, int take = 20}) async {
    try {
      debugPrint('🍽️ RecipeService: Getting recipes (skip: $skip, take: $take)');
      
      final response = await _dio.get(
        '/api/Recipes',
        queryParameters: {
          'skip': skip,
          'take': take,
        },
      );

      final recipes = (response.data as List<dynamic>? ?? [])
          .map((r) => Recipe.fromJson(r))
          .toList();

      debugPrint('🍽️ RecipeService: Got ${recipes.length} recipes');
      
      return recipes;
    } catch (e) {
      debugPrint('❌ RecipeService: Error getting recipes: $e');
      rethrow;
    }
  }

  /// Pobiera szczegóły przepisu po ID
  Future<Recipe> getRecipeById(String id) async {
    try {
      debugPrint('📋 RecipeService: Getting recipe details for ID: $id');
      
      final response = await _dio.get('/api/Recipes/$id');
      
      return Recipe.fromJson(response.data);
    } catch (e) {
      debugPrint('❌ RecipeService: Error getting recipe details: $e');
      rethrow;
    }
  }

  /// Tworzy nowy przepis
  Future<Recipe> createRecipe(RecipeFormData formData) async {
    try {
      debugPrint('➕ RecipeService: Creating recipe "${formData.name}"');
      
      final response = await _dio.post(
        '/api/Recipes',
        data: formData.toJson(),
      );

      final recipeId = response.data['id'] ?? response.data;
      debugPrint('➕ RecipeService: Recipe created with ID: $recipeId');
      
      // Pobiera pełne dane utworzonego przepisu
      return await getRecipeById(recipeId);
    } catch (e) {
      debugPrint('❌ RecipeService: Error creating recipe: $e');
      rethrow;
    }
  }

  /// Pobiera aktualnie zalogowanego użytkownika
  Future<Map<String, dynamic>> getCurrentUser() async {
    try {
      final response = await _dio.get('/api/auth/me');
      return Map<String, dynamic>.from(response.data);
    } catch (e) {
      debugPrint('❌ RecipeService: Error getting current user: $e');
      rethrow;
    }
  }
}