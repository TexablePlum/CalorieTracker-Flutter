import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with TickerProviderStateMixin {
  DateTime _focusedDay = DateTime.now();
  DateTime _selectedDay = DateTime.now();
  bool _isLoading = true;
  String? _userName;
  
  Map<String, dynamic>? _userProfile;

  // Mock data - do zastąpienia przez prawdziwe API calls
  Map<String, dynamic> _dailyData = {};
  
  late AnimationController _animationController;
  late Animation<double> _slideAnimation;
  late Animation<double> _fadeAnimation;

  static const List<Map<String, dynamic>> _allMeals = [
    {
      'name': 'Śniadanie',
      'icon': Icons.wb_sunny,
      'color': Colors.orange,
    },
    {
      'name': 'II Śniadanie',
      'icon': Icons.coffee,
      'color': Colors.brown,
    },
    {
      'name': 'Lunch',
      'icon': Icons.lunch_dining,
      'color': Colors.blue,
    },
    {
      'name': 'Obiad',
      'icon': Icons.dinner_dining,
      'color': Colors.red,
    },
    {
      'name': 'Przekąska',
      'icon': Icons.cookie,
      'color': Colors.purple,
    },
    {
      'name': 'Kolacja',
      'icon': Icons.nightlight_round,
      'color': Colors.indigo,
    },
  ];

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
    _loadDailyData(_selectedDay);
    
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _slideAnimation = Tween<double>(
      begin: 30.0,
      end: 0.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOutCubic,
    ));
    
    _fadeAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(
      parent: _animationController,
      curve: Curves.easeOut,
    ));
    
    _animationController.forward();
  }

  @override
  void dispose() {
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _loadUserProfile() async {
    try {
      final dio = context.read<Dio>();
      final response = await dio.get('/api/profile');
      
      if (mounted && response.statusCode == 200) {
        setState(() {
          _userProfile = Map<String, dynamic>.from(response.data);
          _userName = _userProfile!['firstName'] ?? 'Użytkowniku';
        });
        
        debugPrint('📱 HomePage: Profile loaded: ${_userProfile!['mealPlan']}');
      }
    } catch (e) {
      debugPrint('Error loading profile: $e');
      setState(() {
        _userName = 'Użytkowniku'; // Fallback
      });
    }
  }

  Future<void> _loadDailyData(DateTime date) async {
    setState(() => _isLoading = true);
    
    // Symulacja API call
    await Future.delayed(const Duration(milliseconds: 500));
    
    // Mock data - generuje dane tylko dla wybranych posiłków
    final daysSinceEpoch = date.difference(DateTime(2024, 1, 1)).inDays;
    final random = daysSinceEpoch % 10;
    
    final selectedMeals = _selectedMeals;
    final mealsWithData = <Map<String, dynamic>>[];
    
    // Generuje dane dla każdego wybranego posiłku
    for (int i = 0; i < selectedMeals.length; i++) {
      final meal = Map<String, dynamic>.from(selectedMeals[i]);
      
      // Symuluje czy posiłek został już zjedzony (na podstawie losowości i indeksu)
      final hasData = (random + i) % 3 != 0; // Około 2/3 posiłków ma dane
      
      meal['calories'] = hasData ? 200 + (random * 50) + (i * 100) : 0;
      meal['time'] = hasData ? '${8 + (i * 2)}:${(random * 6).toString().padLeft(2, '0')}' : null;
      
      mealsWithData.add(meal);
    }
    
    setState(() {
      _dailyData = {
        'calories': {
          'consumed': 1500 + (random * 100),
          'target': 2000,
        },
        'water': {
          'consumed': 1200 + (random * 200),
          'target': 2500,
        },
        'macros': {
          'protein': {
            'consumed': 75 + random * 5, 
            'min': 80, 
            'max': 133,
            'unit': 'g'
          },
          'carbs': {
            'consumed': 170 + random * 20, 
            'min': 200, 
            'max': 300,
            'unit': 'g'
          },
          'fat': {
            'consumed': 52 + random * 8, 
            'min': 44, 
            'max': 78,
            'unit': 'g'
          },
        },
        'meals': mealsWithData,
      };
      _isLoading = false;
    });
  }

  /// Zwraca listę posiłków które użytkownik wybrał w swoim planie
  List<Map<String, dynamic>> get _selectedMeals {
    if (_userProfile == null || _userProfile!['mealPlan'] == null) {
      // Fallback - pokaż wszystkie posiłki jeśli nie ma danych profilu
      debugPrint('📱 HomePage: No meal plan data, showing all meals');
      return _allMeals;
    }

    final mealPlan = _userProfile!['mealPlan'] as List;
    final selectedMeals = <Map<String, dynamic>>[];

    for (int i = 0; i < mealPlan.length && i < _allMeals.length; i++) {
      if (mealPlan[i] == true) {
        selectedMeals.add(Map<String, dynamic>.from(_allMeals[i]));
      }
    }

    debugPrint('📱 HomePage: Selected meals count: ${selectedMeals.length}');
    return selectedMeals;
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour >= 5 && hour < 12) {
      return 'Dzień dobry';
    } else if (hour >= 12 && hour < 18) {
      return 'Cześć';
    } else {
      return 'Dobry wieczór';
    }
  }

  bool _isToday(DateTime date) {
    final now = DateTime.now();
    return date.year == now.year && 
           date.month == now.month && 
           date.day == now.day;
  }

  String _formatDate(DateTime date) {
    if (_isToday(date)) return 'Dzisiaj';
    
    final now = DateTime.now();
    final yesterday = now.subtract(const Duration(days: 1));
    if (date.year == yesterday.year && 
        date.month == yesterday.month && 
        date.day == yesterday.day) {
      return 'Wczoraj';
    }
    
    const months = [
      'stycznia', 'lutego', 'marca', 'kwietnia', 'maja', 'czerwca',
      'lipca', 'sierpnia', 'września', 'października', 'listopada', 'grudnia'
    ];
    
    return '${date.day} ${months[date.month - 1]}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: AnimatedBuilder(
        animation: _animationController,
        builder: (context, child) {
          return Transform.translate(
            offset: Offset(0, _slideAnimation.value),
            child: Opacity(
              opacity: _fadeAnimation.value,
              child: CustomScrollView(
                slivers: [
                  // Sticky Header z kalendarzem
                  SliverAppBar(
                    expandedHeight: 200,
                    floating: false,
                    pinned: true,
                    snap: false,
                    stretch: true, // Pozwala na sticky behavior
                    backgroundColor: Colors.transparent,
                    elevation: 0,
                    collapsedHeight: 120,
                    flexibleSpace: LayoutBuilder(
                      builder: (context, constraints) {
                        final isCollapsed = constraints.maxHeight <= 120 + MediaQuery.of(context).padding.top;
                        
                        return Container(
                          decoration: BoxDecoration(
                            gradient: LinearGradient(
                              begin: Alignment.topLeft,
                              end: Alignment.bottomRight,
                              colors: [
                                const Color(0xFFA69DF5),
                                const Color(0xFF8B7CF6),
                                const Color(0xFF7C3AED),
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
                            titlePadding: EdgeInsets.zero,
                            title: isCollapsed 
                              ? Container(
                                  height: 120,
                                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                                  child: Column(
                                    children: [
                                      // Data na górze
                                      Text(
                                        _formatDate(_selectedDay),
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontSize: 18,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                      
                                      const SizedBox(height: 12),
                                      
                                      // Nazwy dni
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                                        children: ['Pon', 'Wt', 'Śr', 'Czw', 'Pt', 'Sob', 'Ndz'].map((day) => 
                                          Text(
                                            day,
                                            style: const TextStyle(
                                              color: Colors.white70,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ).toList(),
                                      ),
                                      
                                      const SizedBox(height: 4),
                                      
                                      // Mini kalendarz
                                      SizedBox(
                                        height: 40,
                                        child: TableCalendar<dynamic>(
                                          firstDay: DateTime.utc(2020, 1, 1),
                                          lastDay: DateTime.utc(2030, 12, 31),
                                          focusedDay: _focusedDay,
                                          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                                          calendarFormat: CalendarFormat.week,
                                          startingDayOfWeek: StartingDayOfWeek.monday,
                                          headerVisible: false,
                                          daysOfWeekVisible: false,
                                          rowHeight: 40,
                                          calendarStyle: CalendarStyle(
                                            outsideDaysVisible: false,
                                            weekendTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
                                            defaultTextStyle: const TextStyle(color: Colors.white, fontSize: 14),
                                            selectedTextStyle: const TextStyle(
                                              color: Color(0xFFA69DF5),
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                            todayTextStyle: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                              fontSize: 14,
                                            ),
                                            selectedDecoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.2),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            todayDecoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.3),
                                              shape: BoxShape.circle,
                                            ),
                                            defaultDecoration: const BoxDecoration(),
                                            weekendDecoration: const BoxDecoration(),
                                          ),
                                          onDaySelected: (selectedDay, focusedDay) {
                                            if (!isSameDay(_selectedDay, selectedDay)) {
                                              setState(() {
                                                _selectedDay = selectedDay;
                                                _focusedDay = focusedDay;
                                              });
                                              _loadDailyData(selectedDay);
                                            }
                                          },
                                          onPageChanged: (focusedDay) {
                                            setState(() {
                                              _focusedDay = focusedDay;
                                            });
                                          },
                                        ),
                                      ),
                                    ],
                                  ),
                                )
                              : null,
                            background: SafeArea(
                              child: AnimatedOpacity(
                                opacity: isCollapsed ? 0.0 : 1.0,
                                duration: const Duration(milliseconds: 200),
                                child: Padding(
                                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Powitanie
                                      FittedBox(
                                        fit: BoxFit.scaleDown,
                                        child: Text(
                                          '${_getGreeting()}, ${_userName ?? 'Ładowanie...'}! 👋',
                                          style: const TextStyle(
                                            color: Colors.white,
                                            fontSize: 24,
                                            fontWeight: FontWeight.bold,
                                          ),
                                          maxLines: 1,
                                        ),
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatDate(_selectedDay),
                                        style: TextStyle(
                                          color: Colors.white.withOpacity(0.9),
                                          fontSize: 16,
                                        ),
                                      ),
                                      const SizedBox(height: 20),
                                      
                                      // Mini kalendarz
                                      Expanded(
                                        child: TableCalendar<dynamic>(
                                          firstDay: DateTime.utc(2020, 1, 1),
                                          lastDay: DateTime.utc(2030, 12, 31),
                                          focusedDay: _focusedDay,
                                          selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
                                          calendarFormat: CalendarFormat.week,
                                          startingDayOfWeek: StartingDayOfWeek.monday,
                                          headerVisible: false,
                                          daysOfWeekHeight: 30,
                                          daysOfWeekStyle: const DaysOfWeekStyle(
                                            weekdayStyle: TextStyle(
                                              color: Colors.white70,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                            weekendStyle: TextStyle(
                                              color: Colors.white70,
                                              fontWeight: FontWeight.w600,
                                              fontSize: 12,
                                            ),
                                          ),
                                          calendarStyle: CalendarStyle(
                                            outsideDaysVisible: false,
                                            weekendTextStyle: const TextStyle(color: Colors.white),
                                            defaultTextStyle: const TextStyle(color: Colors.white),
                                            selectedTextStyle: const TextStyle(
                                              color: Color(0xFFA69DF5),
                                              fontWeight: FontWeight.bold,
                                            ),
                                            todayTextStyle: const TextStyle(
                                              color: Colors.white,
                                              fontWeight: FontWeight.bold,
                                            ),
                                            selectedDecoration: BoxDecoration(
                                              color: Colors.white,
                                              shape: BoxShape.circle,
                                              boxShadow: [
                                                BoxShadow(
                                                  color: Colors.black.withOpacity(0.2),
                                                  blurRadius: 4,
                                                  offset: const Offset(0, 2),
                                                ),
                                              ],
                                            ),
                                            todayDecoration: BoxDecoration(
                                              color: Colors.white.withOpacity(0.3),
                                              shape: BoxShape.circle,
                                            ),
                                            defaultDecoration: const BoxDecoration(),
                                            weekendDecoration: const BoxDecoration(),
                                          ),
                                          onDaySelected: (selectedDay, focusedDay) {
                                            if (!isSameDay(_selectedDay, selectedDay)) {
                                              setState(() {
                                                _selectedDay = selectedDay;
                                                _focusedDay = focusedDay;
                                              });
                                              _loadDailyData(selectedDay);
                                            }
                                          },
                                          onPageChanged: (focusedDay) {
                                            setState(() {
                                              _focusedDay = focusedDay;
                                            });
                                          },
                                        ),
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
                  ),
                  
                  // Główna zawartość
                  SliverToBoxAdapter(
                    child: _isLoading 
                        ? _buildLoadingState() 
                        : _buildMainContent(),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildNoMealsMessage() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: Colors.orange.withOpacity(0.1),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.orange.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(
            Icons.restaurant_menu_outlined,
            size: 48,
            color: Colors.orange[600],
          ),
          const SizedBox(height: 16),
          Text(
            'Nie wybrano żadnych posiłków',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.orange[700],
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Przejdź do ustawień profilu, aby wybrać posiłki które chcesz jeść.',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              color: Colors.orange[600],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 400,
      child: const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFA69DF5),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    final calories = _dailyData['calories'];
    final water = _dailyData['water'];
    final macros = _dailyData['macros'];
    final meals = _dailyData['meals'] as List;

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        children: [
          // Podsumowanie kaloryczne
          _buildCaloriesSummary(calories),
          
          const SizedBox(height: 16),
          
          // Makroskładniki i woda
          _buildMacrosCard(macros),
          
          const SizedBox(height: 16),
          
          _buildWaterCard(water),
          
          const SizedBox(height: 24),
          
          // Sekcja posiłków - pokazuje tylko wybrane przez użytkownika
          if (meals.isNotEmpty) _buildMealsSection(meals),
          
          // Komunikat jeśli użytkownik nie wybrał żadnych posiłków
          if (meals.isEmpty) _buildNoMealsMessage(),
          
          const SizedBox(height: 100),
        ],
      ),
    );
  }

  Widget _buildCaloriesSummary(Map<String, dynamic> calories) {
    final consumed = calories['consumed'] as int;
    final target = calories['target'] as int;
    final percentage = (consumed / target).clamp(0.0, 1.0);
    final remaining = target - consumed;

    return Container(
      padding: const EdgeInsets.all(24),
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
      child: Row(
        children: [
          // Circular progress
          CircularPercentIndicator(
            radius: 60,
            lineWidth: 12,
            percent: percentage,
            backgroundColor: Colors.grey[200]!,
            progressColor: const Color(0xFFA69DF5),
            center: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text(
                  '$consumed',
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                    color: Color(0xFFA69DF5),
                  ),
                ),
                Text(
                  'z $target',
                  style: TextStyle(
                    fontSize: 12,
                    color: Colors.grey[600],
                  ),
                ),
              ],
            ),
            circularStrokeCap: CircularStrokeCap.round,
          ),
          
          const SizedBox(width: 24),
          
          // Info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Kalorie',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  remaining > 0 
                      ? 'Pozostało: $remaining kcal'
                      : 'Przekroczono o ${-remaining} kcal',
                  style: TextStyle(
                    fontSize: 14,
                    color: remaining > 0 ? Colors.green[600] : Colors.red[600],
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 12),
                LinearProgressIndicator(
                  value: percentage,
                  backgroundColor: Colors.grey[200],
                  valueColor: AlwaysStoppedAnimation<Color>(
                    remaining > 0 ? const Color(0xFFA69DF5) : Colors.red,
                  ),
                  minHeight: 6,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWaterCard(Map<String, dynamic> water) {
    final consumed = water['consumed'] as int;
    final target = water['target'] as int;
    final percentage = (consumed / target).clamp(0.0, 1.0);

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.blue.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.water_drop,
                  color: Colors.blue,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Woda',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            '${consumed}ml',
            style: const TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.bold,
              color: Colors.blue,
            ),
          ),
          Text(
            'z ${target}ml',
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
            ),
          ),
          const SizedBox(height: 12),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: Colors.grey[200],
            valueColor: const AlwaysStoppedAnimation<Color>(Colors.blue),
            minHeight: 4,
          ),
        ],
      ),
    );
  }

  Widget _buildMacrosCard(Map<String, dynamic> macros) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.pie_chart,
                  color: Colors.orange,
                  size: 20,
                ),
              ),
              const SizedBox(width: 12),
              const Text(
                'Makro',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          
          _buildMacroRow('Białko', macros['protein'], Colors.red),
          const SizedBox(height: 8),
          _buildMacroRow('Węgle', macros['carbs'], Colors.green),
          const SizedBox(height: 8),
          _buildMacroRow('Tłuszcze', macros['fat'], Colors.yellow[700]!),
        ],
      ),
    );
  }

  Widget _buildMacroRow(String name, Map<String, dynamic> data, Color color) {
    final consumed = data['consumed'] as int;
    final min = data['min'] as int;
    final max = data['max'] as int;
    final unit = data['unit'] as String;
    
    // Oblicza progress względem przedziału
    final targetMid = (min + max) / 2;
    final percentage = (consumed / targetMid).clamp(0.0, 1.5); // Pozwala przekroczyć 150%
    
    // Określa status i kolor
    Color statusColor = color;
    String status = '';
    
    if (consumed < min) {
      statusColor = Colors.orange;
      status = 'Za mało';
    } else if (consumed > max) {
      statusColor = Colors.red;
      status = 'Za dużo';
    } else {
      statusColor = Colors.green;
      status = 'Idealnie';
    }

    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    name,
                    style: const TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  Text(
                    '$min-$max$unit',
                    style: TextStyle(
                      fontSize: 11,
                      color: Colors.grey[500],
                    ),
                  ),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  '$consumed$unit',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.bold,
                    color: statusColor,
                  ),
                ),
                Text(
                  status,
                  style: TextStyle(
                    fontSize: 10,
                    color: statusColor,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 6),
        Stack(
          children: [
            // Tło paska
            Container(
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey[200],
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            
            // Idealny przedział (zielony)
            Container(
              height: 4,
              width: double.infinity,
              child: FractionallySizedBox(
                alignment: Alignment.centerLeft,
                widthFactor: (max / targetMid / 1.5).clamp(0.0, 1.0),
                child: Container(
                  margin: EdgeInsets.only(
                    left: (min / targetMid / 1.5 * MediaQuery.of(context).size.width * 0.25).clamp(0.0, double.infinity),
                  ),
                  decoration: BoxDecoration(
                    color: Colors.green.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
            ),
            
            // Aktualny progress
            FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: (percentage / 1.5).clamp(0.0, 1.0),
              child: Container(
                height: 4,
                decoration: BoxDecoration(
                  color: statusColor,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildMealsSection(List meals) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Posiłki',
          style: TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.bold,
            color: Colors.black87,
          ),
        ),
        const SizedBox(height: 16),
        
        ...meals.map((meal) => _buildMealCard(meal)).toList(),
      ],
    );
  }

  Widget _buildMealCard(Map<String, dynamic> meal) {
    final hasData = meal['calories'] > 0;
    final color = meal['color'] as Color;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: () {
            // TODO: Nawigacja do ekranu szczegółów posiłku
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Otwieranie ${meal['name']}...'),
                backgroundColor: const Color(0xFFA69DF5),
              ),
            );
          },
          borderRadius: BorderRadius.circular(16),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(16),
              border: hasData ? Border.all(
                color: color.withOpacity(0.3),
                width: 1,
              ) : null,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.06),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: hasData ? color.withOpacity(0.15) : Colors.grey[100],
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    meal['icon'] as IconData,
                    color: hasData ? color : Colors.grey[400],
                    size: 24,
                  ),
                ),
                
                const SizedBox(width: 16),
                
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal['name'],
                        style: const TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: Colors.black87,
                        ),
                      ),
                      const SizedBox(height: 4),
                      if (hasData) ...[
                        Text(
                          '${meal['calories']} kcal • ${meal['time']}',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[600],
                          ),
                        ),
                      ] else ...[
                        Text(
                          'Nie dodano jeszcze posiłku',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.grey[500],
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                
                Icon(
                  hasData ? Icons.edit : Icons.add,
                  color: hasData ? color : const Color(0xFFA69DF5),
                  size: 20,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}