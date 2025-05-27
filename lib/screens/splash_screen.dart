import 'package:calorie_tracker_flutter_front/auth/token_storage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import 'welcome_screen.dart';
import 'mainProfile.dart';
import 'profile_setup_screen.dart';
import 'login_screen.dart';

class SplashScreen extends StatefulWidget {
  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  /* ──────────────────────────────────────────
     INIT
  ────────────────────────────────────────── */
  @override
  void initState() {
    super.initState();
    _checkAuth(); // start-up
  }

  /* ──────────────────────────────────────────
     AUTH LOGIC
  ────────────────────────────────────────── */
  Future<void> _checkAuth() async {
    final storage = context.read<TokenStorage>();
    final dio = context.read<Dio>();

    // krótkie „pauza-logo” żeby spinner mignął, można pominąć
    await Future.delayed(const Duration(milliseconds: 300));

    final access = await storage.access;

    // brak accessToken → Welcome
    if (access == null || access.isEmpty) {
      _go(const WelcomeScreen());
      return;
    }

    // access istnieje → pytamy backend o profil
    final resp = await dio.get('/api/profile', options: Options(validateStatus: (_) => true));

    if (!mounted) return;

    switch (resp.statusCode) {
      case 200:
        final complete = resp.data is Map && resp.data['isComplete'] == true;
        _go(complete ? mainProfile() : ProfileSetupScreen());
        break;

      case 204: // brak profilu
        _go(ProfileSetupScreen());
        break;

      case 401 || 403:
      default:
        // token nieważny → czyścimy, kierujemy na Login
        await storage.clear();
        _go(LoginScreen());
    }
  }

  void _go(Widget page) {
    Navigator.of(context).pushAndRemoveUntil(MaterialPageRoute(builder: (_) => page), (_) => false);
  }

  /* ──────────────────────────────────────────
     BUILD
  ────────────────────────────────────────── */
  @override
  Widget build(BuildContext context) {
    return const Scaffold(body: Center(child: CircularProgressIndicator()));
  }
}
