import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import 'mainProfile.dart';

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
    super.dispose();
  }

  /* ──────────────────────────────────────────────
     LOAD PROFILE
  ────────────────────────────────────────────── */
  Future<void> loadProfile() async {
    final dio = context.read<Dio>();

    final res = await dio.get('/api/profile', options: Options(validateStatus: (_) => true));

    if (res.statusCode == 200) {
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

    final res = await dio.put(
      '/api/profile',
      data: {
        "firstName": firstNameController.text,
        "lastName": lastNameController.text,
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
      options: Options(validateStatus: (_) => true),
    );

    if (!mounted) return;

    if (res.statusCode == 204) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => mainProfile()), (_) => false);
    } else {
      setState(() => errorMessage = _extractErrors(res.data, res.statusCode));
    }

    setState(() => isLoading = false);
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
     WEEKLY GOAL ±
  ────────────────────────────────────────────── */
  void _changeWeeklyGoal(double delta) {
    final min =
        goal == "LoseWeight"
            ? -1.0
            : goal == "GainWeight"
            ? 0.1
            : 0.0;
    final max =
        goal == "LoseWeight"
            ? -0.1
            : goal == "GainWeight"
            ? 1.0
            : 0.0;

    final next = weeklyGoalChange + delta;
    if (next >= min && next <= max) {
      setState(() => weeklyGoalChange = double.parse(next.toStringAsFixed(1)));
    }
  }

  /* ──────────────────────────────────────────────
     UI HELPERS
  ────────────────────────────────────────────── */
  Widget _buildTextField(TextEditingController controller, String hint, {bool enabled = true, String? errorText}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: TextField(
        controller: controller,
        enabled: enabled,
        keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly],
        decoration: InputDecoration(
          hintText: hint,
          errorText: errorText,
          filled: true,
          fillColor: Colors.white,
          contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
    );
  }

  Widget _buildRadioGroup(List<String> values, List<String> labels, String selected, void Function(String) onChanged) {
    return Column(
      children: List.generate(values.length, (i) {
        return RadioListTile(
          title: Text(labels[i]),
          value: values[i],
          groupValue: selected,
          onChanged: (val) => onChanged(val!),
        );
      }),
    );
  }

  Widget _buildGenderSegmentedControl() {
    return SizedBox(
      width: double.infinity,
      child: SegmentedButton<String>(
        segments: const [
          ButtonSegment(value: "Female", label: Text("Kobieta")),
          ButtonSegment(value: "Male", label: Text("Mężczyzna")),
        ],
        selected: {gender},
        onSelectionChanged: (value) => setState(() => gender = value.first),
        style: ButtonStyle(
          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
          backgroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? Color(0xFFA69DF5) : Colors.white,
          ),
          foregroundColor: WidgetStateProperty.resolveWith(
            (states) => states.contains(WidgetState.selected) ? Colors.white : Colors.black,
          ),
          side: WidgetStateProperty.all(const BorderSide(color: Colors.grey)),
          shape: WidgetStateProperty.all(RoundedRectangleBorder(borderRadius: BorderRadius.circular(8))),
        ),
      ),
    );
  }

  Widget _buildWeeklyGoalControl() {
    return Center(
      child: Container(
        margin: const EdgeInsets.only(top: 16),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        decoration: BoxDecoration(
          color: Color(0xFFA69DF5).withOpacity(0.05),
          border: Border.all(color: Color(0xFFA69DF5)),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            IconButton(icon: const Icon(Icons.remove), onPressed: () => _changeWeeklyGoal(-0.1)),
            Text(
              "${weeklyGoalChange >= 0 ? "+" : ""}${weeklyGoalChange.toStringAsFixed(1)} kg",
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            IconButton(icon: const Icon(Icons.add), onPressed: () => _changeWeeklyGoal(0.1)),
          ],
        ),
      ),
    );
  }

  Widget _buildMessageBox(String message) {
    final lines = message.split('\n').where((e) => e.trim().isNotEmpty);
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red.shade200),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            lines
                .map(
                  (msg) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      children: [
                        const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(msg, style: TextStyle(color: Colors.red.shade700))),
                      ],
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }

  /* ──────────────────────────────────────────────
     BUILD
  ────────────────────────────────────────────── */
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: Color(0xFFA69DF5),
        title: const Text("Uzupełnij profil"),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text("Płeć", style: TextStyle(fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            _buildGenderSegmentedControl(),
            const SizedBox(height: 16),

            /* ---------- CEL ---------- */
            const Text("Cel", style: TextStyle(fontWeight: FontWeight.bold)),
            _buildRadioGroup(
              ["LoseWeight", "Maintain", "GainWeight"],
              ["Utrata masy ciała", "Utrzymanie masy ciała", "Przyrost masy ciała"],
              goal,
              (val) {
                setState(() {
                  goal = val;
                  if (goal == "Maintain") {
                    targetWeightController.text = weightController.text;
                  }
                  weeklyGoalChange =
                      goal == "Maintain"
                          ? 0.0
                          : weeklyGoalChange.clamp(
                            goal == "LoseWeight" ? -1.0 : 0.1,
                            goal == "LoseWeight" ? -0.1 : 1.0,
                          );
                });
              },
            ),

            /* ---------- DANE OSOBOWE ---------- */
            const Text("Dane osobowe", style: TextStyle(fontWeight: FontWeight.bold)),
            _buildTextField(firstNameController, "Imię"),
            _buildTextField(lastNameController, "Nazwisko"),
            _buildTextField(ageController, "Wiek"),
            _buildTextField(heightController, "Wzrost (cm)"),
            _buildTextField(weightController, "Waga (kg)"),
            _buildTextField(
              targetWeightController,
              "Waga docelowa (kg)",
              enabled: goal != "Maintain",
              errorText: targetWeightError,
            ),
            const SizedBox(height: 16),

            /* ---------- AKTYWNOŚĆ ---------- */
            const Text("Poziom aktywności", style: TextStyle(fontWeight: FontWeight.bold)),
            _buildRadioGroup(
              ["Sedentary", "LightlyActive", "ModeratelyActive", "VeryActive", "ExtremelyActive"],
              ["Bardzo niski", "Niski", "Średni", "Wysoki", "Bardzo wysoki"],
              activityLevel,
              (val) => setState(() => activityLevel = val),
            ),

            /* ---------- TEMPO ---------- */
            const Text("Tempo zmiany masy (kg/tydzień):", style: TextStyle(fontWeight: FontWeight.bold)),
            _buildWeeklyGoalControl(),
            const SizedBox(height: 16),

            /* ---------- POSIŁKI ---------- */
            const Text("Układ posiłków", style: TextStyle(fontWeight: FontWeight.bold)),
            ...List.generate(mealPlan.length, (i) {
              const labels = ["Śniadanie", "II Śniadanie", "Lunch", "Obiad", "Przekąska", "Kolacja"];
              return CheckboxListTile(
                title: Text(labels[i]),
                value: mealPlan[i],
                onChanged: (val) => setState(() => mealPlan[i] = val!),
              );
            }),

            if (errorMessage != null) _buildMessageBox(errorMessage!),
            const SizedBox(height: 16),

            /* ---------- ZAPISZ ---------- */
            ElevatedButton(
              onPressed: isLoading ? null : submitProfile,
              style: ElevatedButton.styleFrom(
                backgroundColor: Color(0xFFA69DF5),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child:
                  isLoading
                      ? const CircularProgressIndicator(color: Colors.white)
                      : const Text("Zapisz profil", style: TextStyle(color: Colors.white)),
            ),
          ],
        ),
      ),
    );
  }
}
