import 'package:calorie_tracker_flutter_front/auth/token_storage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import '../screens/welcome_screen.dart';
import '../screens/profile_setup_screen.dart';
import '../screens/reset_password_combined_screen.dart';

class ProfilePage extends StatefulWidget {
  @override
  State<ProfilePage> createState() => _mainProfileState();
}

class _mainProfileState extends State<ProfilePage> {
  Map<String, dynamic>? profile;
  String? error;
  bool _isSendingReset = false;
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    loadProfile();
  }

  /* ──────────────────────────────────────────────
     PROFILE LOADING Z RETRY MECHANIZMEM
  ────────────────────────────────────────────── */
  Future<void> loadProfile({bool showLoading = false}) async {
    if (showLoading) {
      setState(() => _isLoading = true);
    }
    
    setState(() => error = null);

    try {
      final dio = context.read<Dio>();
      
      debugPrint('📱 ProfilePage: Loading profile...');
      final res = await dio.get('/api/profile');

      if (!mounted) return;

      debugPrint('📱 ProfilePage: Profile loaded successfully (${res.statusCode})');
      setState(() {
        profile = Map<String, dynamic>.from(res.data);
        error = null;
        _isLoading = false;
      });
    } on DioException catch (e) {
      debugPrint('📱 ProfilePage: DioException: ${e.type} - ${e.response?.statusCode}');
      
      if (!mounted) return;

      // Jeśli to 204 (brak profilu), przekieruje do setup
      if (e.response?.statusCode == 204) {
        Navigator.pushReplacement(
          context, 
          MaterialPageRoute(builder: (_) => ProfileSetupScreen())
        );
        return;
      }
      
      // Jeśli to błąd autoryzacji to AuthInterceptor powinien był obsłużyć
      // Jeśli nadal dostaje 401/403 to znaczy że refresh się nie udał
      if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
        debugPrint('📱 ProfilePage: Auth error, redirecting to welcome');
        await _handleForceLogout();
        return;
      }

      setState(() {
        error = "Błąd ładowania profilu. Sprawdź połączenie internetowe.";
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('📱 ProfilePage: Unexpected error: $e');
      
      if (!mounted) return;
      
      setState(() {
        error = "Wystąpił nieoczekiwany błąd.";
        _isLoading = false;
      });
    }
  }

  /* ──────────────────────────────────────────────
     FORCE LOGOUT (gdy auth się kompletnie nie udał)
  ────────────────────────────────────────────── */
  Future<void> _handleForceLogout() async {
    final storage = context.read<TokenStorage>();
    await storage.clear();

    if (!mounted) return;
    
    // Pokazuje komunikat o wylogowaniu
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text('Sesja wygasła. Zaloguj się ponownie.'),
        backgroundColor: Colors.orange,
      ),
    );

    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      (_) => false,
    );
  }

  /* ──────────────────────────────────────────────
     LOGOUT (normalny)
  ────────────────────────────────────────────── */
  Future<void> logout() async {
    try {
      final storage = context.read<TokenStorage>();
      final dio = context.read<Dio>();

      final refresh = await storage.refresh;

      // Spróbuje wylogować się w backendzie (ignoruje wynik)
      if (refresh != null) {
        await dio.post(
          '/api/auth/logout', 
          data: {"refreshToken": refresh},
          options: Options(validateStatus: (_) => true)
        );
      }

      await storage.clear();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context, 
        MaterialPageRoute(builder: (_) => const WelcomeScreen()), 
        (_) => false
      );
    } catch (e) {
      debugPrint('📱 ProfilePage: Logout error: $e');
      // Nawet w przypadku błędu, wykonuje lokalne wylogowanie
      final storage = context.read<TokenStorage>();
      await storage.clear();
      
      if (!mounted) return;
      Navigator.pushAndRemoveUntil(
        context, 
        MaterialPageRoute(builder: (_) => const WelcomeScreen()), 
        (_) => false
      );
    }
  }

  /* ──────────────────────────────────────────────
     RESET PASSWORD
  ────────────────────────────────────────────── */
  Future<void> _sendResetCodeAndNavigate() async {
    if (_isSendingReset) return;
    setState(() => _isSendingReset = true);

    try {
      final dio = context.read<Dio>();
      final email = profile?['email'] ?? '';

      final res = await dio.post(
        '/api/auth/forgot-password',
        data: {"email": email},
      );

      if (!mounted) return;
      setState(() => _isSendingReset = false);

      if (res.statusCode == 200) {
        Navigator.push(
          context, 
          MaterialPageRoute(builder: (_) => ResetPasswordScreen(email: email))
        );
      }
    } on DioException catch (e) {
      if (!mounted) return;
      setState(() => _isSendingReset = false);

      String msg;
      try {
        final body = e.response?.data;
        if (body is Map && body['errors'] != null) {
          msg = (body['errors'] as Map).values.expand((v) => v).join('\n');
        } else if (body is String) {
          msg = body;
        } else {
          msg = "Błąd wysyłania kodu resetującego.";
        }
      } catch (_) {
        msg = "Błąd serwera (${e.response?.statusCode}).";
      }
      
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg))
      );
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSendingReset = false);
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text("Wystąpił nieoczekiwany błąd."))
      );
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
  Widget _buildProfileHeader() {
    final firstName = profile?["firstName"] ?? "";
    final lastName = profile?["lastName"] ?? "";
    final email = profile?["email"] ?? "";
    final gender = profile?["gender"] ?? "Male";
    
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
          bottomLeft: Radius.circular(32),
          bottomRight: Radius.circular(32),
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFA69DF5).withOpacity(0.3),
            spreadRadius: 0,
            blurRadius: 20,
            offset: const Offset(0, 10),
          ),
        ],
      ),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    "Profil",
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Container(
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: IconButton(
                      icon: const Icon(Icons.logout, color: Colors.white, size: 20),
                      onPressed: logout,
                      tooltip: "Wyloguj się",
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 24),
              Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.3), width: 3),
                ),
                child: Icon(
                  gender == "Female" ? Icons.woman : Icons.man,
                  size: 50,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 16),
              Text(
                "$firstName $lastName",
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 24,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                email,
                style: TextStyle(
                  color: Colors.white.withOpacity(0.9),
                  fontSize: 16,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInfoTile(String title, String value, IconData icon, {Color? iconColor}) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(18),
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
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: (iconColor ?? const Color(0xFFA69DF5)).withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              icon, 
              color: iconColor ?? const Color(0xFFA69DF5), 
              size: 22
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 15,
                    color: Colors.black87,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  value,
                  style: TextStyle(
                    color: Colors.grey[600],
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, List<Widget> children) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: Text(
              title,
              style: const TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 8),
          ...children,
        ],
      ),
    );
  }

  Widget _buildMealPlanSection() {
    final plan = profile!["mealPlan"] ?? [];
    final labels = ["Śniadanie", "II Śniadanie", "Lunch", "Obiad", "Przekąska", "Kolacja"];
    final selectedMeals = <String>[];
    
    for (var i = 0; i < plan.length && i < labels.length; i++) {
      if (plan[i] == true) selectedMeals.add(labels[i]);
    }

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
            child: const Text(
              "Plan posiłków",
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          const SizedBox(height: 8),
          Container(
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
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: Colors.orange.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(Icons.restaurant_menu, color: Colors.orange, size: 22),
                    ),
                    const SizedBox(width: 16),
                    const Text(
                      "Wybrane posiłki",
                      style: TextStyle(
                        fontWeight: FontWeight.w600,
                        fontSize: 15,
                        color: Colors.black87,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),
                if (selectedMeals.isNotEmpty)
                  Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: selectedMeals.map((meal) {
                      return Container(
                        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(25),
                          border: Border.all(
                            color: const Color(0xFFA69DF5),
                            width: 2,
                          ),
                          boxShadow: [
                            BoxShadow(
                              color: const Color(0xFFA69DF5).withOpacity(0.15),
                              spreadRadius: 0,
                              blurRadius: 6,
                              offset: const Offset(0, 3),
                            ),
                          ],
                        ),
                        child: Text(
                          meal,
                          style: const TextStyle(
                            color: Color(0xFFA69DF5),
                            fontWeight: FontWeight.w600,
                            fontSize: 13,
                          ),
                        ),
                      );
                    }).toList(),
                  )
                else
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        Icon(Icons.info_outline, color: Colors.grey[500], size: 18),
                        const SizedBox(width: 8),
                        Text(
                          "Brak wybranych posiłków",
                          style: TextStyle(
                            color: Colors.grey[600],
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionButton({
    required String label,
    required IconData icon,
    required VoidCallback onPressed,
    bool isLoading = false,
    bool isPrimary = true,
  }) {
    return Container(
      width: double.infinity,
      height: 56,
      margin: const EdgeInsets.only(bottom: 12),
      child: ElevatedButton.icon(
        onPressed: isLoading ? null : onPressed,
        icon: isLoading 
          ? SizedBox(
              width: 20,
              height: 20,
              child: CircularProgressIndicator(
                strokeWidth: 2,
                color: isPrimary ? Colors.white : const Color(0xFFA69DF5),
              ),
            )
          : Icon(icon),
        label: Text(
          isLoading ? "Ładowanie..." : label,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
        ),
        style: ElevatedButton.styleFrom(
          backgroundColor: isPrimary ? const Color(0xFFA69DF5) : Colors.white,
          foregroundColor: isPrimary ? Colors.white : const Color(0xFFA69DF5),
          elevation: isPrimary ? 0 : 0,
          side: isPrimary ? null : const BorderSide(color: Color(0xFFA69DF5), width: 2),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          shadowColor: isPrimary ? const Color(0xFFA69DF5).withOpacity(0.3) : null,
        ),
      ),
    );
  }

  Widget _buildErrorWidget() {
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
              child: Icon(
                Icons.error_outline,
                size: 64,
                color: Colors.red[400],
              ),
            ),
            const SizedBox(height: 24),
            Text(
              error!,
              style: const TextStyle(
                color: Colors.red,
                fontSize: 16,
                fontWeight: FontWeight.w500,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildActionButton(
              label: "Spróbuj ponownie",
              icon: Icons.refresh,
              onPressed: () => loadProfile(showLoading: true),
            ),
          ],
        ),
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
      body: _isLoading
          ? const Center(child: CircularProgressIndicator(color: Color(0xFFA69DF5)))
          : error != null
              ? _buildErrorWidget()
              : profile == null
                  ? const Center(child: Text("Brak danych profilu"))
                  : RefreshIndicator(
                      onRefresh: () => loadProfile(),
                      color: const Color(0xFFA69DF5),
                      child: SingleChildScrollView(
                        physics: const AlwaysScrollableScrollPhysics(),
                        child: Column(
                          children: [
                            _buildProfileHeader(),
                            const SizedBox(height: 24),
                            
                            _buildSection("Dane podstawowe", [
                              _buildInfoTile("Wiek", "${profile!["age"] ?? "-"} lat", Icons.cake, iconColor: Colors.orange),
                              _buildInfoTile("Wzrost", "${profile!["heightCm"]} cm", Icons.height, iconColor: Colors.blue),
                              _buildInfoTile("Waga", "${profile!["weightKg"]} kg", Icons.monitor_weight, iconColor: Colors.green),
                              _buildInfoTile("Płeć", _mapGender(profile!["gender"] ?? ""), Icons.wc, iconColor: Colors.purple),
                            ]),
                            
                            const SizedBox(height: 24),
                            
                            _buildSection("Aktywność i cele", [
                              _buildInfoTile("Poziom aktywności", _mapActivity(profile!["activityLevel"] ?? ""), Icons.directions_walk, iconColor: Colors.teal),
                              _buildInfoTile("Główny cel", _mapGoal(profile!["goal"] ?? ""), Icons.flag, iconColor: Colors.red),
                              _buildInfoTile("Waga docelowa", "${profile!["targetWeightKg"]} kg", Icons.fitness_center, iconColor: Colors.indigo),
                              _buildInfoTile("Tempo zmian", "${(profile!["weeklyGoalChangeKg"] ?? 0.0).toStringAsFixed(1)} kg/tydzień", Icons.trending_up, iconColor: Colors.amber),
                            ]),
                            
                            const SizedBox(height: 24),
                            
                            _buildMealPlanSection(),
                            
                            const SizedBox(height: 32),
                            
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Column(
                                children: [
                                  _buildActionButton(
                                    label: "Edytuj profil",
                                    icon: Icons.edit,
                                    onPressed: () => Navigator.push(
                                      context, 
                                      MaterialPageRoute(builder: (_) => ProfileSetupScreen())
                                    ),
                                  ),
                                  _buildActionButton(
                                    label: "Zmień hasło",
                                    icon: Icons.lock_reset,
                                    onPressed: _sendResetCodeAndNavigate,
                                    isLoading: _isSendingReset,
                                    isPrimary: false,
                                  ),
                                ],
                              ),
                            ),
                            const SizedBox(height: 32),
                          ],
                        ),
                      ),
                    ),
    );
  }
}