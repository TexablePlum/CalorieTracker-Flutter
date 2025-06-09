import 'package:calorie_tracker_flutter_front/nav_pages/profile_page.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

class ProfileSetupScreen extends StatefulWidget {
  @override
  State<ProfileSetupScreen> createState() => _ProfileSetupScreenState();
}

class _ProfileSetupScreenState extends State<ProfileSetupScreen> {
  /* ──────────────────────────────────────────────
     CONTROLLERS / STATE
  ────────────────────────────────────────────── */
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final ageController = TextEditingController();
  final heightController = TextEditingController();
  final weightController = TextEditingController();
  final targetWeightController = TextEditingController();

  String gender = "Male";
  String activityLevel = "Sedentary";
  String goal = "Maintain";

  double weeklyGoalChange = 0.0;
  List<bool> mealPlan = List.filled(6, false);

  bool isLoading = false;
  String? errorMessage;
  String? targetWeightError;

  /* ──────────────────────────────────────────────
     INIT / DISPOSE
  ────────────────────────────────────────────── */
  @override
  void initState() {
    super.initState();
    loadProfile();
    weightController.addListener(_syncWeightIfMaintainGoal);
  }

  void _syncWeightIfMaintainGoal() {
    if (goal == "Maintain") {
      targetWeightController.text = weightController.text;
    }
  }

  @override
  void dispose() {
    weightController.removeListener(_syncWeightIfMaintainGoal);
    firstNameController.dispose();
    lastNameController.dispose();
    ageController.dispose();
    heightController.dispose();
    weightController.dispose();
    targetWeightController.dispose();
    super.dispose();
  }

  /* ──────────────────────────────────────────────
     LOAD PROFILE
  ────────────────────────────────────────────── */
  Future<void> loadProfile() async {
    try {
      final dio = context.read<Dio>();
      
      debugPrint('📱 ProfileSetupScreen: Loading profile...');
      
      // NIE używamy Options(validateStatus: (_) => true)
      // Pozwalamy AuthInterceptor obsłużyć 401
      final res = await dio.get('/api/profile');
      
      debugPrint('📱 ProfileSetupScreen: Profile loaded successfully');
      
      // Jeśli dostaliśmy dane, wypełniamy formularz
      final data = Map<String, dynamic>.from(res.data);
      setState(() {
        firstNameController.text = data["firstName"] ?? "";
        lastNameController.text = data["lastName"] ?? "";
        ageController.text = data["age"]?.toString() ?? "";
        heightController.text = data["heightCm"]?.toString() ?? "";
        weightController.text = data["weightKg"]?.toString() ?? "";
        targetWeightController.text = data["targetWeightKg"]?.toString() ?? "";
        gender = data["gender"] ?? "Male";
        activityLevel = data["activityLevel"] ?? "Sedentary";
        goal = data["goal"] ?? "Maintain";
        weeklyGoalChange = (data["weeklyGoalChangeKg"] ?? 0.0).toDouble();
        mealPlan = List<bool>.from(data["mealPlan"] ?? List.filled(6, false));
      });
      
    } on DioException catch (e) {
      debugPrint('📱 ProfileSetupScreen: DioException loading profile: ${e.response?.statusCode}');
      
      // 204 oznacza brak profilu - to jest OK, zostajemy z pustym formularzem
      if (e.response?.statusCode == 204) {
        debugPrint('📱 ProfileSetupScreen: No profile found (204), using empty form');
        return;
      }
      
      // Inne błędy - AuthInterceptor powinien był je obsłużyć
      // Jeśli nadal mamy 401/403, znaczy że refresh się nie udał
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        debugPrint('📱 ProfileSetupScreen: Auth failed, user should be redirected to login');
        // AuthInterceptor powinien był już wyczyścić tokeny i przekierować
      }
      
      // Inne błędy sieciowe
      debugPrint('📱 ProfileSetupScreen: Error loading profile: $e');
    } catch (e) {
      debugPrint('📱 ProfileSetupScreen: Unexpected error loading profile: $e');
    }
  }

  /* ──────────────────────────────────────────────
     SUBMIT PROFILE
  ────────────────────────────────────────────── */
  Future<void> submitProfile() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      targetWeightError = null;
    });

    final dio = context.read<Dio>();

    final currentWeight = int.tryParse(weightController.text);
    final targetWeight = int.tryParse(targetWeightController.text);

    // Walidacja dla celów
    if (goal == "LoseWeight" && (targetWeight == null || targetWeight >= currentWeight!)) {
      setState(() {
        targetWeightError = "Docelowa masa ciała musi być mniejsza niż aktualna.";
        isLoading = false;
      });
      return;
    }

    if (goal == "GainWeight" && (targetWeight == null || targetWeight <= currentWeight!)) {
      setState(() {
        targetWeightError = "Docelowa masa ciała musi być większa niż aktualna.";
        isLoading = false;
      });
      return;
    }

    try {
      debugPrint('📱 ProfileSetupScreen: Submitting profile...');
      
      final res = await dio.put(
        '/api/profile',
        data: {
          "firstName": firstNameController.text.trim(),
          "lastName": lastNameController.text.trim(),
          "age": int.tryParse(ageController.text),
          "heightCm": int.tryParse(heightController.text),
          "weightKg": currentWeight,
          "targetWeightKg": targetWeight,
          "gender": gender,
          "activityLevel": activityLevel,
          "goal": goal,
          "weeklyGoalChangeKg": weeklyGoalChange,
          "mealPlan": mealPlan,
        },
      );

      debugPrint('📱 ProfileSetupScreen: Profile submitted successfully (${res.statusCode})');
      
      if (!mounted) return;
      
      // Sukces - sprawdź skąd przyszliśmy
      if (Navigator.of(context).canPop()) {
        // Jeśli można wrócić (edycja z ProfilePage), po prostu wróć
        Navigator.of(context).pop();
      } else {
        // Jeśli to pierwszy setup, przejdź do ProfilePage
        Navigator.pushAndRemoveUntil(
          context, 
          MaterialPageRoute(builder: (_) => ProfilePage()), 
          (_) => false
        );
      }
      
    } on DioException catch (e) {
      debugPrint('📱 ProfileSetupScreen: DioException submitting profile: ${e.response?.statusCode}');
      
      if (!mounted) return;
      
      // AuthInterceptor powinien był obsłużyć 401 i odświeżyć tokeny
      // Jeśli wciąż mamy błąd, to znaczy że coś poszło nie tak
      
      // Wyświetl błąd walidacji jeśli to 400/422
      if (e.response?.statusCode == 400 || e.response?.statusCode == 422) {
        setState(() {
          errorMessage = _extractErrors(e.response?.data, e.response?.statusCode);
          isLoading = false;
        });
      } else {
        // Inne błędy - pokaż ogólny komunikat
        setState(() {
          errorMessage = "Wystąpił błąd podczas zapisywania profilu. Spróbuj ponownie.";
          isLoading = false;
        });
      }
    } catch (e) {
      debugPrint('📱 ProfileSetupScreen: Unexpected error submitting profile: $e');
      
      if (!mounted) return;
      
      setState(() {
        errorMessage = "Wystąpił nieoczekiwany błąd.";
        isLoading = false;
      });
    }
  }

  String _extractErrors(dynamic body, int? code) {
    try {
      if (body is Map && body['errors'] != null) {
        return (body['errors'] as Map<String, dynamic>).values.expand((e) => e).join('\n');
      }
      if (body is String) return body;
    } catch (_) {}
    return "Błąd: ${code ?? 'unknown'}";
  }

  /* ──────────────────────────────────────────────
     WEEKLY GOAL
  ────────────────────────────────────────────── */
  void _changeWeeklyGoal(double delta) {
    final min = goal == "LoseWeight" ? -1.0 : goal == "GainWeight" ? 0.1 : 0.0;
    final max = goal == "LoseWeight" ? -0.1 : goal == "GainWeight" ? 1.0 : 0.0;

    final next = weeklyGoalChange + delta;
    if (next >= min && next <= max) {
      setState(() => weeklyGoalChange = double.parse(next.toStringAsFixed(1)));
    }
  }

  /* ──────────────────────────────────────────────
     UI HELPERS
  ────────────────────────────────────────────── */
  Widget _buildHeader() {
    return Container(
      width: double.infinity,
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
        borderRadius: const BorderRadius.only(
          bottomLeft: Radius.circular(24),
          bottomRight: Radius.circular(24),
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
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
          child: Row(
            children: [
              Container(
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: IconButton(
                  icon: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
                  onPressed: () => Navigator.pop(context),
                ),
              ),
              const Expanded(
                child: Text(
                  "Uzupełnij profil",
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(width: 48),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildTextField(TextEditingController controller, String hint, String label, {bool enabled = true, String? errorText, bool isNumeric = false}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w600,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 6),
          TextField(
            controller: controller,
            enabled: enabled,
            keyboardType: isNumeric ? TextInputType.number : TextInputType.text,
            inputFormatters: isNumeric ? [FilteringTextInputFormatter.digitsOnly] : null,
            style: const TextStyle(fontSize: 16),
            decoration: InputDecoration(
              hintText: hint,
              errorText: errorText,
              filled: true,
              fillColor: enabled ? Colors.white : Colors.grey[100],
              contentPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide.none,
              ),
              enabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey[200]!, width: 1),
              ),
              focusedBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Color(0xFFA69DF5), width: 2),
              ),
              errorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.red, width: 1),
              ),
              focusedErrorBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: const BorderSide(color: Colors.red, width: 2),
              ),
              disabledBorder: OutlineInputBorder(
                borderRadius: BorderRadius.circular(16),
                borderSide: BorderSide(color: Colors.grey[300]!, width: 1),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, Widget child) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            spreadRadius: 0,
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black87,
            ),
          ),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _buildGenderSegmentedControl() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: "Female", label: Text("Kobieta"), icon: Icon(Icons.woman)),
          ButtonSegment(value: "Male", label: Text("Mężczyzna"), icon: Icon(Icons.man)),
        ],
        selected: {gender},
        onSelectionChanged: (value) => setState(() => gender = value.first),
        style: ButtonStyle(
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? const Color(0xFFA69DF5) : Colors.grey[100],
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? Colors.white : Colors.black87,
          ),
          side: WidgetStateProperty.all(BorderSide.none),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
        ),
      ),
    );
  }

  Widget _buildGoalSelector() {
    final goals = [
      {"value": "LoseWeight", "label": "Utrata masy ciała", "icon": Icons.trending_down, "color": Colors.red},
      {"value": "Maintain", "label": "Utrzymanie masy ciała", "icon": Icons.balance, "color": Colors.blue},
      {"value": "GainWeight", "label": "Przyrost masy ciała", "icon": Icons.trending_up, "color": Colors.green},
    ];

    return Column(
      children: goals.map((goalData) {
        final isSelected = goal == goalData["value"];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () {
              setState(() {
                goal = goalData["value"] as String;
                if (goal == "Maintain") {
                  targetWeightController.text = weightController.text;
                }
                weeklyGoalChange = goal == "Maintain" ? 0.0 : weeklyGoalChange.clamp(
                  goal == "LoseWeight" ? -1.0 : 0.1,
                  goal == "LoseWeight" ? -0.1 : 1.0,
                );
              });
            },
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? (goalData["color"] as Color).withOpacity(0.1) : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? (goalData["color"] as Color) : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    goalData["icon"] as IconData,
                    color: isSelected ? (goalData["color"] as Color) : Colors.grey[600],
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      goalData["label"] as String,
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                        color: isSelected ? (goalData["color"] as Color) : Colors.black87,
                      ),
                    ),
                  ),
                  if (isSelected)
                    Icon(
                      Icons.check_circle,
                      color: goalData["color"] as Color,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildActivitySelector() {
    final activities = [
      {"value": "Sedentary", "label": "Bardzo niski", "desc": "Praca siedząca, brak ćwiczeń"},
      {"value": "LightlyActive", "label": "Niski", "desc": "Lekkie ćwiczenia 1-3 dni w tygodniu"},
      {"value": "ModeratelyActive", "label": "Średni", "desc": "Umiarkowane ćwiczenia 3-5 dni w tygodniu"},
      {"value": "VeryActive", "label": "Wysoki", "desc": "Intensywne ćwiczenia 6-7 dni w tygodniu"},
      {"value": "ExtremelyActive", "label": "Bardzo wysoki", "desc": "Bardzo intensywne ćwiczenia, praca fizyczna"},
    ];

    return Column(
      children: activities.map((activity) {
        final isSelected = activityLevel == activity["value"];
        return Container(
          margin: const EdgeInsets.only(bottom: 12),
          child: InkWell(
            onTap: () => setState(() => activityLevel = activity["value"] as String),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: isSelected ? const Color(0xFFA69DF5).withOpacity(0.1) : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isSelected ? const Color(0xFFA69DF5) : Colors.grey[300]!,
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          activity["label"] as String,
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                            color: isSelected ? const Color(0xFFA69DF5) : Colors.black87,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          activity["desc"] as String,
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.grey[600],
                          ),
                        ),
                      ],
                    ),
                  ),
                  if (isSelected)
                    const Icon(
                      Icons.check_circle,
                      color: Color(0xFFA69DF5),
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildWeeklyGoalControl() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFA69DF5).withOpacity(0.1),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFA69DF5).withOpacity(0.3)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFA69DF5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.remove, color: Colors.white, size: 18),
              onPressed: () => _changeWeeklyGoal(-0.1),
              padding: EdgeInsets.zero,
            ),
          ),
          const SizedBox(width: 20),
          Column(
            children: [
              Text(
                "${weeklyGoalChange >= 0 ? "+" : ""}${weeklyGoalChange.toStringAsFixed(1)} kg",
                style: const TextStyle(
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: Color(0xFFA69DF5),
                ),
              ),
              Text(
                "na tydzień",
                style: TextStyle(
                  fontSize: 12,
                  color: Colors.grey[600],
                ),
              ),
            ],
          ),
          const SizedBox(width: 20),
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              color: const Color(0xFFA69DF5),
              borderRadius: BorderRadius.circular(8),
            ),
            child: IconButton(
              icon: const Icon(Icons.add, color: Colors.white, size: 18),
              onPressed: () => _changeWeeklyGoal(0.1),
              padding: EdgeInsets.zero,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMealPlanSelector() {
    const labels = ["Śniadanie", "II Śniadanie", "Lunch", "Obiad", "Przekąska", "Kolacja"];
    const icons = [Icons.wb_sunny, Icons.coffee, Icons.lunch_dining, Icons.dinner_dining, Icons.cookie, Icons.nightlight_round];

    return Column(
      children: List.generate(mealPlan.length, (i) {
        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          child: InkWell(
            onTap: () => setState(() => mealPlan[i] = !mealPlan[i]),
            borderRadius: BorderRadius.circular(12),
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: mealPlan[i] ? Colors.orange.withOpacity(0.1) : Colors.grey[50],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: mealPlan[i] ? Colors.orange : Colors.grey[300]!,
                  width: mealPlan[i] ? 2 : 1,
                ),
              ),
              child: Row(
                children: [
                  Icon(
                    icons[i],
                    color: mealPlan[i] ? Colors.orange : Colors.grey[600],
                    size: 24,
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Text(
                      labels[i],
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: mealPlan[i] ? FontWeight.w600 : FontWeight.w500,
                        color: mealPlan[i] ? Colors.orange : Colors.black87,
                      ),
                    ),
                  ),
                  if (mealPlan[i])
                    const Icon(
                      Icons.check_circle,
                      color: Colors.orange,
                      size: 20,
                    ),
                ],
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildErrorMessage() {
    if (errorMessage == null) return const SizedBox.shrink();
    
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.red.shade200),
      ),
      child: Row(
        children: [
          const Icon(Icons.error_outline, color: Colors.red, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              errorMessage!,
              style: const TextStyle(color: Colors.red, fontSize: 14),
            ),
          ),
        ],
      ),
    );
  }

  /* ──────────────────────────────────────────────
     BUILD
  ────────────────────────────────────────────── */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: Column(
        children: [
          _buildHeader(),
          Expanded(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  const SizedBox(height: 8),
                  
                  _buildSection("Płeć", _buildGenderSegmentedControl()),
                  
                  _buildSection("Cel", _buildGoalSelector()),
                  
                  _buildSection("Dane osobowe", Column(
                    children: [
                      _buildTextField(firstNameController, "Wprowadź imię", "Imię", isNumeric: false),
                      _buildTextField(lastNameController, "Wprowadź nazwisko", "Nazwisko", isNumeric: false),
                      _buildTextField(ageController, "Wprowadź wiek", "Wiek", isNumeric: true),
                      _buildTextField(heightController, "Wprowadź wzrost w cm", "Wzrost (cm)", isNumeric: true),
                      _buildTextField(weightController, "Wprowadź wagę w kg", "Waga (kg)", isNumeric: true),
                      _buildTextField(
                        targetWeightController,
                        goal != "Maintain" ? "Wprowadź wagę docelową" : "Automatycznie ustawione",
                        "Waga docelowa (kg)",
                        enabled: goal != "Maintain",
                        errorText: targetWeightError,
                        isNumeric: true,
                      ),
                    ],
                  )),
                  
                  _buildSection("Poziom aktywności", _buildActivitySelector()),
                  
                  _buildSection("Tempo zmiany masy", _buildWeeklyGoalControl()),
                  
                  _buildSection("Plan posiłków", _buildMealPlanSelector()),
                  
                  _buildErrorMessage(),
                  
                  Container(
                    width: double.infinity,
                    height: 56,
                    margin: const EdgeInsets.only(top: 8, bottom: 32),
                    child: ElevatedButton(
                      onPressed: isLoading ? null : submitProfile,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA69DF5),
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                        shadowColor: const Color(0xFFA69DF5).withOpacity(0.3),
                      ),
                      child: isLoading
                          ? const SizedBox(
                              width: 24,
                              height: 24,
                              child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2),
                            )
                          : const Text(
                              "Zapisz profil",
                              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                            ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}