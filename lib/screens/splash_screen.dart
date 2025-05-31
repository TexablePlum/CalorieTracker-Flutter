import 'package:calorie_tracker_flutter_front/auth/token_storage.dart';
import 'package:calorie_tracker_flutter_front/nav_pages/main_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import 'welcome_screen.dart';
import 'profile_setup_screen.dart';

class SplashScreen extends StatefulWidget {
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkAuth();
  }

  Future<void> _checkAuth() async {
    debugPrint('🚀 SplashScreen: Starting auth check...');
    
    final storage = context.read<TokenStorage>();
    final dio = context.read<Dio>();

    // Krótka pauza dla efektu wizualnego
    await Future.delayed(const Duration(milliseconds: 500));

    try {
      // Sprawdza tokeny
      final access = await storage.access;
      final refresh = await storage.refresh;

      // Brak tokenów -> Welcome Screen
      if (access == null || access.isEmpty || refresh == null || refresh.isEmpty) {
        debugPrint('🚀 No tokens found, navigating to WelcomeScreen');
        _navigateTo(const WelcomeScreen());
        return;
      }

      debugPrint('🚀 Tokens found, checking profile...');
      
      // Próba pobrania profilu
      try {
        final resp = await dio.get('/api/profile');

        if (!mounted) return;

        switch (resp.statusCode) {
          case 200:
            // Profil istnieje - sprawdza kompletność
            final complete = resp.data is Map && resp.data['isComplete'] == true;
            debugPrint('🚀 Profile complete: $complete');
            _navigateTo(complete ? const MainPage() : ProfileSetupScreen());
            break;

          case 204:
            // Brak profilu - kieruje do setup
            debugPrint('🚀 No profile found, navigating to ProfileSetup');
            _navigateTo(ProfileSetupScreen());
            break;

          default:
            // Nieoczekiwany status
            debugPrint('🚀 Unexpected status: ${resp.statusCode}');
            await _handleLogout();
        }
      } on DioException catch (e) {
        debugPrint('🚀 Profile check failed: ${e.response?.statusCode}');
        
        // Jeśli to 401/403, AuthInterceptor powinien był spróbować refresh
        if (e.response?.statusCode == 401 || e.response?.statusCode == 403) {
          debugPrint('🚀 Auth failed after refresh attempt, logging out');
          await _handleLogout();
        } else {
          // Inny błąd sieciowy - sprawdza czy mamy tokeny
          final hasTokens = await storage.isLoggedIn;
          if (hasTokens) {
            debugPrint('🚀 Network error but has tokens, navigating to MainPage');
            _navigateTo(const MainPage());
          } else {
            debugPrint('🚀 Network error and no tokens, navigating to WelcomeScreen');
            _navigateTo(const WelcomeScreen());
          }
        }
      }
    } catch (e) {
      debugPrint('🚀 Unexpected error: $e');
      
      // W przypadku błędu sprawdza czy mamy tokeny
      final hasTokens = await storage.isLoggedIn;
      if (hasTokens) {
        debugPrint('🚀 Error but has tokens, navigating to MainPage');
        _navigateTo(const MainPage());
      } else {
        debugPrint('🚀 Error and no tokens, navigating to WelcomeScreen');
        _navigateTo(const WelcomeScreen());
      }
    }
  }

  Future<void> _handleLogout() async {
    debugPrint('🚀 Handling logout...');
    final storage = context.read<TokenStorage>();
    await storage.clear();
    _navigateTo(const WelcomeScreen());
  }

  void _navigateTo(Widget page) {
    if (!mounted) return;
    
    debugPrint('🚀 Navigating to: ${page.runtimeType}');
    
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(builder: (_) => page),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: const [
            CircularProgressIndicator(
              color: Color(0xFFA69DF5),
            ),
            SizedBox(height: 16),
            Text(
              'CalorieTracker',
              style: TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.bold,
                color: Color(0xFFA69DF5),
              ),
            ),
          ],
        ),
      ),
    );
  }
}