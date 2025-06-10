import 'package:calorie_tracker_flutter_front/screens/add_recipe_screen.dart';
import 'package:calorie_tracker_flutter_front/screens/recipe_details_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import '../models/recipe.dart';
import '../services/recipe_service.dart';

class RecipePage extends StatefulWidget {
  const RecipePage({super.key});

  @override
  State<RecipePage> createState() => _RecipePageState();
}

class _RecipePageState extends State<RecipePage> with SingleTickerProviderStateMixin {
  late RecipeService _recipeService;
  late TabController _tabController;
  
  // Stan dla zakładki "Wyszukaj"
  List<Recipe>? _allRecipes;
  bool _isSearchLoading = false;
  String? _searchError;
  final TextEditingController _searchController = TextEditingController();

  // Stan dla zakładki "Moje Przepisy"
  List<Recipe>? _myRecipes;
  bool _isMyLoading = true;
  String? _myError;

  // Cache dla pełnych danych przepisów
  final Map<String, Recipe> _recipeCache = {};

  @override
  void initState() {
    super.initState();
    _recipeService = RecipeService(context.read<Dio>());
    _tabController = TabController(length: 2, vsync: this);
    _loadMyRecipes();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  /// Wyszukuje wszystkie przepisy w zakładce "Wyszukaj"
  Future<void> _searchAllRecipes(String searchTerm) async {
    if (searchTerm.trim().isEmpty) {
      setState(() {
        _allRecipes = null;
        _isSearchLoading = false;
        _searchError = null;
      });
      return;
    }

    setState(() {
      _isSearchLoading = true;
      _searchError = null;
    });

    try {
      final recipes = await _recipeService.getAllRecipes(take: 100);
      
      final filteredRecipes = recipes.where((recipe) =>
        recipe.name.toLowerCase().contains(searchTerm.toLowerCase())
      ).toList();

      if (mounted) {
        setState(() {
          _allRecipes = filteredRecipes;
          _isSearchLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _searchError = 'Błąd wyszukiwania przepisów';
          _isSearchLoading = false;
        });
      }
    }
  }

  /// Ładuje przepisy użytkownika w zakładce "Moje Przepisy"
  Future<void> _loadMyRecipes() async {
    setState(() {
      _isMyLoading = true;
      _myError = null;
    });

    try {
      final currentUser = await _recipeService.getCurrentUser();
      final currentUserId = currentUser['id']?.toString();
      final allRecipes = await _recipeService.getAllRecipes(take: 100);
      
      final myRecipes = allRecipes.where((recipe) =>
        recipe.isOwnedBy(currentUserId)
      ).toList();

      if (mounted) {
        setState(() {
          _myRecipes = myRecipes;
          _isMyLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _myError = 'Błąd ładowania przepisów';
          _isMyLoading = false;
        });
      }
    }
  }

  /// Nawiguje do szczegółów przepisu - pobiera pełne dane
  Future<void> _openRecipeDetails(Recipe recipe) async {
    if (_recipeCache.containsKey(recipe.id)) {
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecipeDetailsScreen(recipe: _recipeCache[recipe.id]!),
        ),
      );
      return;
    }

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => const Center(
        child: CircularProgressIndicator(color: Color(0xFFA69DF5)),
      ),
    );

    try {
      final fullRecipe = await _recipeService.getRecipeById(recipe.id);
      _recipeCache[recipe.id] = fullRecipe;
      
      if (!mounted) return;
      Navigator.of(context).pop();

      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (_) => RecipeDetailsScreen(recipe: fullRecipe),
        ),
      );

    } catch (e) {
      if (!mounted) return;
      Navigator.of(context).pop();
      
      String errorMessage = 'Nie udało się pobrać danych przepisu';
      if (e is DioException) {
        switch (e.response?.statusCode) {
          case 404:
            errorMessage = 'Przepis nie został znaleziony';
            break;
          case 403:
            errorMessage = 'Brak uprawnień do tego przepisu';
            break;
        }
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(errorMessage),
          backgroundColor: Colors.red,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverAppBar(
            expandedHeight: 140,
            floating: false,
            pinned: true,
            snap: false,
            backgroundColor: Colors.transparent,
            elevation: 0,
            flexibleSpace: LayoutBuilder(
              builder: (context, constraints) {
                final isCollapsed = constraints.maxHeight <= 100 + MediaQuery.of(context).padding.top;
                
                return Container(
                  decoration: BoxDecoration(
                    gradient: const LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        Color(0xFFA69DF5),
                        Color(0xFF8B7CF6),
                        Color(0xFF7C3AED),
                      ],
                    ),
                    borderRadius: BorderRadius.only(
                      bottomLeft: Radius.circular(isCollapsed ? 0 : 24),
                      bottomRight: Radius.circular(isCollapsed ? 0 : 24),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: const Color(0xFFA69DF5).withOpacity(0.3),
                        spreadRadius: 0,
                        blurRadius: 15,
                        offset: const Offset(0, 8),
                      ),
                    ],
                  ),
                  child: FlexibleSpaceBar(
                    centerTitle: false,
                    titlePadding: const EdgeInsets.only(left: 20, bottom: 16),
                    title: AnimatedOpacity(
                      opacity: isCollapsed ? 1.0 : 0.0,
                      duration: const Duration(milliseconds: 200),
                      child: const Text(
                        'Przepisy',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    background: SafeArea(
                      child: AnimatedOpacity(
                        opacity: isCollapsed ? 0.0 : 1.0,
                        duration: const Duration(milliseconds: 200),
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Expanded(
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          'Przepisy 👨‍🍳',
                                          style: TextStyle(
                                            color: Colors.white,
                                            fontSize: 28,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        SizedBox(height: 4),
                                        Text(
                                          'Odkryj i zarządzaj przepisami',
                                          style: TextStyle(
                                            color: Colors.white70,
                                            fontSize: 14,
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                );
              },
            ),
            bottom: PreferredSize(
              preferredSize: const Size.fromHeight(48),
              child: Container(
                decoration: const BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [
                      Color(0xFFA69DF5),
                      Color(0xFF8B7CF6),
                      Color(0xFF7C3AED),
                    ],
                  ),
                ),
                child: TabBar(
                  controller: _tabController,
                  labelColor: Colors.white,
                  unselectedLabelColor: Colors.white.withOpacity(0.7),
                  indicatorColor: Colors.white,
                  indicatorWeight: 3,
                  labelStyle: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 16,
                  ),
                  tabs: const [
                    Tab(text: 'Wyszukaj'),
                    Tab(text: 'Moje Przepisy'),
                  ],
                ),
              ),
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _buildSearchTab(),
            _buildMyRecipesTab(),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final result = await Navigator.push<Recipe>(
            context,
            MaterialPageRoute(
              builder: (_) => const AddRecipeScreen(),
            ),
          );
          
          if (result != null) {
            _loadMyRecipes();
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Row(
                  children: [
                    const Icon(Icons.check_circle, color: Colors.white),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Przepis "${result.name}" został dodany!'),
                    ),
                  ],
                ),
                backgroundColor: Colors.green,
                behavior: SnackBarBehavior.floating,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
              ),
            );
          }
        },
        backgroundColor: const Color(0xFFA69DF5),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nowy przepis'),
        elevation: 8,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildSearchTab() {
    return RefreshIndicator(
      onRefresh: () async {
        if (_searchController.text.isNotEmpty) {
          await _searchAllRecipes(_searchController.text);
        }
      },
      color: const Color(0xFFA69DF5),
      child: CustomScrollView(
        slivers: [
          // Search bar
          SliverToBoxAdapter(
            child: Container(
              padding: const EdgeInsets.all(16),
              color: const Color(0xFFF8F9FA),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.05),
                      blurRadius: 10,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: TextField(
                  controller: _searchController,
                  decoration: InputDecoration(
                    hintText: 'Wyszukaj przepisy...',
                    hintStyle: TextStyle(color: Colors.grey[500]),
                    prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
                    suffixIcon: _searchController.text.isNotEmpty
                        ? IconButton(
                            icon: Icon(Icons.clear, color: Colors.grey[500]),
                            onPressed: () {
                              _searchController.clear();
                              setState(() {
                                _allRecipes = null;
                                _searchError = null;
                              });
                            },
                          )
                        : null,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(16),
                      borderSide: BorderSide.none,
                    ),
                    filled: true,
                    fillColor: Colors.white,
                    contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  ),
                  onSubmitted: _searchAllRecipes,
                  onChanged: (value) {
                    if (value.isEmpty) {
                      setState(() {
                        _allRecipes = null;
                        _searchError = null;
                      });
                    }
                  },
                ),
              ),
            ),
          ),
          
          // Content
          if (_isSearchLoading)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFA69DF5)),
                    SizedBox(height: 16),
                    Text(
                      'Wyszukiwanie przepisów...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_searchError != null)
            SliverFillRemaining(
              child: _buildErrorWidget(_searchError!, () => _searchAllRecipes(_searchController.text)),
            )
          else if (_allRecipes == null)
            SliverFillRemaining(
              child: _buildEmptySearchState(),
            )
          else if (_allRecipes!.isEmpty)
            SliverFillRemaining(
              child: _buildNoResultsState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildRecipeCard(_allRecipes![index]),
                  childCount: _allRecipes!.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMyRecipesTab() {
    return RefreshIndicator(
      onRefresh: _loadMyRecipes,
      color: const Color(0xFFA69DF5),
      child: CustomScrollView(
        slivers: [
          if (_isMyLoading)
            const SliverFillRemaining(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CircularProgressIndicator(color: Color(0xFFA69DF5)),
                    SizedBox(height: 16),
                    Text(
                      'Ładowanie Twoich przepisów...',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.grey,
                      ),
                    ),
                  ],
                ),
              ),
            )
          else if (_myError != null)
            SliverFillRemaining(
              child: _buildErrorWidget(_myError!, _loadMyRecipes),
            )
          else if ((_myRecipes ?? []).isEmpty)
            SliverFillRemaining(
              child: _buildEmptyMyRecipesState(),
            )
          else
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
              sliver: SliverList(
                delegate: SliverChildBuilderDelegate(
                  (context, index) => _buildRecipeCard(_myRecipes![index], showOwnerBadge: false),
                  childCount: _myRecipes!.length,
                ),
              ),
            ),
        ],
      ),
    );
  }

  // Możemy usunąć tę metodę bo nie jest już używana
  // Widget _buildRecipesList(List<Recipe> recipes, {bool showOwnerBadge = true}) {
  //   return ListView.builder(
  //     padding: const EdgeInsets.fromLTRB(16, 8, 16, 100),
  //     itemCount: recipes.length,
  //     itemBuilder: (context, index) {
  //       final recipe = recipes[index];
  //       return _buildRecipeCard(recipe, showOwnerBadge: showOwnerBadge);
  //     },
  //   );
  // }

  Widget _buildRecipeCard(Recipe recipe, {bool showOwnerBadge = true}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () => _openRecipeDetails(recipe),
          borderRadius: BorderRadius.circular(20),
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.08),
                  blurRadius: 16,
                  offset: const Offset(0, 4),
                ),
              ],
            ),
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Header z tytułem i badge
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          recipe.name,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: const Color(0xFFA69DF5).withOpacity(0.1),
                          borderRadius: BorderRadius.circular(20),
                          border: Border.all(
                            color: const Color(0xFFA69DF5).withOpacity(0.3),
                          ),
                        ),
                        child: const Icon(
                          Icons.arrow_forward_ios,
                          size: 14,
                          color: Color(0xFFA69DF5),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 16),
                  
                  // Info chips
                  Wrap(
                    spacing: 12,
                    runSpacing: 8,
                    children: [
                      _buildInfoChip(
                        Icons.people_outline,
                        '${recipe.servingsCount} porcji',
                        Colors.blue,
                      ),
                      _buildInfoChip(
                        Icons.timer_outlined,
                        recipe.formattedPreparationTime,
                        Colors.green,
                      ),
                      _buildInfoChip(
                        Icons.restaurant_outlined,
                        '${recipe.ingredients.length} składników',
                        Colors.orange,
                      ),
                    ],
                  ),
                  
                  // Instrukcje preview
                  if (recipe.instructions != null && recipe.instructions!.isNotEmpty) ...[
                    const SizedBox(height: 16),
                    Text(
                      recipe.instructions!,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                        height: 1.4,
                      ),
                    ),
                  ],
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildInfoChip(IconData icon, String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: color.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withOpacity(0.3)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 16, color: color),
          const SizedBox(width: 6),
          Text(
            text,
            style: TextStyle(
              fontSize: 12,
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptySearchState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: const Color(0xFFA69DF5).withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search,
              size: 64,
              color: Color(0xFFA69DF5),
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Wyszukaj przepisy',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Wprowadź nazwę przepisu w pole wyszukiwania\naby znaleźć to czego szukasz',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.search_off,
              size: 64,
              color: Colors.orange,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Nie znaleziono przepisów',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Spróbuj wyszukać coś innego\nlub dodaj swój pierwszy przepis',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyMyRecipesState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(24),
            decoration: BoxDecoration(
              color: Colors.green.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.restaurant_menu_outlined,
              size: 64,
              color: Colors.green,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Brak własnych przepisów',
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Dodaj swój pierwszy przepis\ni zacznij gotować!',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 16,
              color: Colors.grey[600],
              height: 1.4,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () async {
              final result = await Navigator.push<Recipe>(
                context,
                MaterialPageRoute(
                  builder: (_) => const AddRecipeScreen(),
                ),
              );
              
              if (result != null) {
                _loadMyRecipes();
              }
            },
            icon: const Icon(Icons.add),
            label: const Text('Dodaj przepis'),
            style: ElevatedButton.styleFrom(
              backgroundColor: const Color(0xFFA69DF5),
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorWidget(String error, VoidCallback onRetry) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.red.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red,
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Wystąpił błąd',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              error,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('Spróbuj ponownie'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA69DF5),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}