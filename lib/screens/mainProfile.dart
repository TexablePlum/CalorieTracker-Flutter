import 'package:calorie_tracker_flutter_front/auth/token_storage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import 'welcome_screen.dart';
import 'profile_setup_screen.dart';
import 'reset_password_combined_screen.dart';

class mainProfile extends StatefulWidget {
  @override
  State<mainProfile> createState() => _mainProfileState();
}

class _mainProfileState extends State<mainProfile> {
  Map<String, dynamic>? profile;
  String? error;
  bool _isSendingReset = false;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  /* ──────────────────────────────────────────────
     PROFILE
  ────────────────────────────────────────────── */
  Future<void> loadProfile() async {
    final dio = context.read<Dio>();

    final res = await dio.get('/api/profile', options: Options(validateStatus: (_) => true));

    if (!mounted) return;

    if (res.statusCode == 200) {
      setState(() => profile = Map<String, dynamic>.from(res.data));
    } else if (res.statusCode == 204) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => ProfileSetupScreen()));
    } else {
      setState(() => error = "Błąd ładowania profilu (${res.statusCode})");
    }
  }

  /* ──────────────────────────────────────────────
     LOGOUT
  ────────────────────────────────────────────── */
  Future<void> logout() async {
    final storage = context.read<TokenStorage>();
    final dio = context.read<Dio>();

    final refresh = await storage.refresh;

    // Spróbuj wylogować się w backendzie (ignoruje wynik)
    await dio.post('/api/auth/logout', data: {"refreshToken": refresh}, options: Options(validateStatus: (_) => true));

    await storage.clear();

    if (!mounted) return;
    Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => WelcomeScreen()), (_) => false);
  }

  /* ──────────────────────────────────────────────
     RESET PASSWORD
  ────────────────────────────────────────────── */
  Future<void> _sendResetCodeAndNavigate() async {
    if (_isSendingReset) return;
    setState(() => _isSendingReset = true);

    final dio = context.read<Dio>();
    final email = profile?['email'] ?? '';

    final res = await dio.post(
      '/api/auth/forgot-password',
      data: {"email": email},
      options: Options(validateStatus: (_) => true),
    );

    if (!mounted) return;
    setState(() => _isSendingReset = false);

    if (res.statusCode == 200) {
      Navigator.push(context, MaterialPageRoute(builder: (_) => ResetPasswordScreen(email: email)));
    } else {
      String msg;
      try {
        final body = res.data;
        if (body is Map && body['errors'] != null) {
          msg = (body['errors'] as Map).values.expand((v) => v).join('\n');
        } else if (body is String) {
          msg = body;
        } else {
          msg = "Nieznany błąd.";
        }
      } catch (_) {
        msg = "Błąd serwera (${res.statusCode}).";
      }
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  /* ──────────────────────────────────────────────
     MAP HELPERS
  ────────────────────────────────────────────── */
  String _mapGender(String v) => switch (v) {
    "Male" => "Mężczyzna",
    "Female" => "Kobieta",
    _ => v,
  };

  String _mapGoal(String v) => switch (v) {
    "LoseWeight" => "Utrata masy ciała",
    "Maintain" => "Utrzymanie masy ciała",
    "GainWeight" => "Przyrost masy ciała",
    _ => v,
  };

  String _mapActivity(String v) => switch (v) {
    "Sedentary" => "Bardzo niski",
    "LightlyActive" => "Niski",
    "ModeratelyActive" => "Średni",
    "VeryActive" => "Wysoki",
    "ExtremelyActive" => "Bardzo wysoki",
    _ => v,
  };

  /* ──────────────────────────────────────────────
     UI HELPERS
  ────────────────────────────────────────────── */
  Widget _buildTile(String t, String v, IconData i) => Card(
    margin: const EdgeInsets.symmetric(vertical: 4),
    child: ListTile(
      leading: Icon(i, color: const Color(0xFFA69DF5)),
      title: Text(t, style: const TextStyle(fontWeight: FontWeight.bold)),
      subtitle: Text(v),
    ),
  );

  Widget _buildSection(String title, List<Widget> children) => Padding(
    padding: const EdgeInsets.only(top: 24),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(title.toUpperCase(), style: TextStyle(color: Colors.black, fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        ...children,
      ],
    ),
  );

  Widget _buildMealPlan(List<dynamic> plan) {
    final labels = ["Śniadanie", "II Śniadanie", "Lunch", "Obiad", "Przekąska", "Kolacja"];
    final sel = <String>[];
    for (var i = 0; i < plan.length; i++) {
      if (plan[i] == true) sel.add(labels[i]);
    }
    return Card(
      margin: const EdgeInsets.symmetric(vertical: 4),
      child: ListTile(
        leading: const Icon(Icons.restaurant_menu, color: const Color(0xFFA69DF5)),
        title: const Text("Plan posiłków", style: TextStyle(fontWeight: FontWeight.bold)),
        subtitle: Text(sel.isNotEmpty ? sel.join(", ") : "Brak"),
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
        foregroundColor: Colors.black,
        title: const Text("Profil użytkownika"),
        actions: [
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: logout,
            style: ButtonStyle(foregroundColor: WidgetStateProperty.all(Colors.red)),
          ),
        ],
      ),
      body:
          profile == null
              ? error != null
                  ? Center(child: Text(error!, style: const TextStyle(color: Colors.red)))
                  : const Center(child: CircularProgressIndicator())
              : SingleChildScrollView(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildSection("Informacje ogólne", [
                      _buildTile("E-mail", profile!["email"] ?? "", Icons.email),
                      _buildTile("Imię", profile!["firstName"] ?? "", Icons.person),
                      _buildTile("Nazwisko", profile!["lastName"] ?? "", Icons.person_outline),
                      _buildTile("Płeć", _mapGender(profile!["gender"] ?? ""), Icons.wc),
                    ]),
                    _buildSection("Wartości fizyczne", [
                      _buildTile("Wiek", "${profile!["age"] ?? "-"}", Icons.cake),
                      _buildTile("Wzrost", "${profile!["heightCm"]} cm", Icons.height),
                      _buildTile("Waga", "${profile!["weightKg"]} kg", Icons.monitor_weight),
                      _buildTile(
                        "Poziom aktywności",
                        _mapActivity(profile!["activityLevel"] ?? ""),
                        Icons.directions_walk,
                      ),
                    ]),
                    _buildSection("Twoje cele", [
                      _buildTile("Cel", _mapGoal(profile!["goal"] ?? ""), Icons.flag),
                      _buildTile(
                        "Tempo zmian (kg/tydz.)",
                        "${(profile!["weeklyGoalChangeKg"] ?? 0.0).toStringAsFixed(1)}",
                        Icons.trending_up,
                      ),
                      _buildTile("Waga docelowa", "${profile!["targetWeightKg"]} kg", Icons.fitness_center),
                      _buildMealPlan(profile!["mealPlan"] ?? []),
                    ]),
                    const SizedBox(height: 32),
                    ElevatedButton.icon(
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => ProfileSetupScreen())),
                      icon: const Icon(Icons.edit),
                      label: const Text("Edytuj dane"),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFFA69DF5),
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                    const SizedBox(height: 12),
                    OutlinedButton.icon(
                      onPressed: _isSendingReset ? null : _sendResetCodeAndNavigate,
                      icon: const Icon(Icons.lock_reset),
                      label: Text(_isSendingReset ? "Wysyłam kod..." : "Zmień/Resetuj hasło"),
                      style: OutlinedButton.styleFrom(
                        backgroundColor: Colors.transparent,
                        foregroundColor: Color(0xFFA69DF5),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                        minimumSize: const Size(double.infinity, 50),
                      ),
                    ),
                  ],
                ),
              ),
    );
  }
}
