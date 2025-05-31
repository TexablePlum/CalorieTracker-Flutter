import 'package:calorie_tracker_flutter_front/auth/token_storage.dart';
import 'package:calorie_tracker_flutter_front/nav_pages/main_page.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import 'confirm_email_screen.dart';
import 'profile_setup_screen.dart';
import 'register_screen.dart';
import 'forgot_password_screen.dart';
import 'welcome_screen.dart';

class LoginScreen extends StatefulWidget {
  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final emailController = TextEditingController();
  final passwordController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;
  bool _showPassword = false;

  bool get isFormValid => emailController.text.trim().isNotEmpty && passwordController.text.isNotEmpty;

  /* ──────────────────────────────────────────────
     LOGIN
  ────────────────────────────────────────────── */
  Future<void> login() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    final dio = context.read<Dio>();
    final storage = context.read<TokenStorage>();

    try {
      final res = await dio.post(
        '/api/auth/login',
        data: {"email": emailController.text.trim(), "password": passwordController.text},
        options: Options(validateStatus: (_) => true),
      );

      switch (res.statusCode) {
        case 200:
          // zapisz tokeny
          await storage.save(res.data['accessToken'], res.data['refreshToken']);
          await checkProfileAndRedirect();
          break;

        case 403: // e-mail niepotwierdzony
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => ConfirmEmailScreen(email: emailController.text.trim())),
          );
          break;

        case 401: // złe hasło / e-mail
          setState(() => errorMessage = "Nieprawidłowy e-mail lub hasło.");
          break;

        default:
          setState(() => errorMessage = _extractError(res.data));
      }
    } catch (_) {
      setState(() => errorMessage = "Błąd połączenia z serwerem.");
    } finally {
      if (mounted) setState(() => isLoading = false);
    }
  }

  /* ──────────────────────────────────────────────
     PROFILE → REDIRECT
  ────────────────────────────────────────────── */
  Future<void> checkProfileAndRedirect() async {
    final dio = context.read<Dio>();

    final res = await dio.get('/api/profile', options: Options(validateStatus: (_) => true));

    if (!mounted) return;

    if (res.statusCode == 204) {
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => ProfileSetupScreen()), (_) => false);
    } else if (res.statusCode == 200) {
      final data = res.data;
      final isComplete = data is Map && data["isComplete"] == true;

      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(builder: (_) => isComplete ? MainPage() : ProfileSetupScreen()),
        (_) => false,
      );
    } else {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text("Nie udało się pobrać profilu użytkownika.")));
    }
  }

  /* ──────────────────────────────────────────────
     ERROR PARSER
  ────────────────────────────────────────────── */
  String _extractError(dynamic body) {
    try {
      if (body is List) {
        return body.join('\n');
      } else if (body is Map && body['errors'] != null) {
        final errors = body['errors'] as Map<String, dynamic>;
        return errors.values.expand((v) => v).join('\n');
      } else if (body is String) {
        return body;
      }
    } catch (_) {}
    return "Wystąpił nieoczekiwany błąd.";
  }

  /* ──────────────────────────────────────────────
     WIDGET HELPERS
  ────────────────────────────────────────────── */
  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    bool isPassword = false,
    bool visible = false,
    VoidCallback? onToggle,
  }) {
    return TextField(
      controller: controller,
      onChanged: (_) => setState(() {}),
      obscureText: isPassword && !visible,
      keyboardType: isPassword ? TextInputType.visiblePassword : TextInputType.emailAddress,
      decoration: InputDecoration(
        hintText: hint,
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.grey),
          borderRadius: BorderRadius.circular(12),
        ),
        suffixIcon:
            isPassword
                ? IconButton(
                  icon: Icon(visible ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                  onPressed: onToggle,
                )
                : null,
      ),
    );
  }

  Widget _buildErrorBox(String error) {
    final lines = error.split('\n').where((e) => e.trim().isNotEmpty);
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
                      crossAxisAlignment: CrossAxisAlignment.start,
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
        foregroundColor: const Color(0xFFA69DF5),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            Navigator.pushAndRemoveUntil(
              context,
              MaterialPageRoute(builder: (_) => const WelcomeScreen()),
              (_) => false,
            );
          },
        ),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Logowanie",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFFA69DF5)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildTextField(emailController, "E-mail"),
            const SizedBox(height: 12),
            _buildTextField(
              passwordController,
              "Hasło",
              isPassword: true,
              visible: _showPassword,
              onToggle: () => setState(() => _showPassword = !_showPassword),
            ),
            const SizedBox(height: 12),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => ForgotPasswordScreen()));
                },
                child: const Text("Zapomniałeś hasła?", style: TextStyle(color: Colors.grey)),
              ),
            ),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: !isFormValid || isLoading ? null : login,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFA69DF5),
                minimumSize: const Size(double.infinity, 50),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
              ),
              child:
                  isLoading
                      ? const SizedBox(
                        height: 24,
                        width: 24,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                      : const Text("Zaloguj się", style: TextStyle(color: Colors.white)),
            ),
            if (errorMessage != null) _buildErrorBox(errorMessage!),
            const SizedBox(height: 16),
            Center(
              child: TextButton(
                onPressed: () {
                  Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterScreen()));
                },
                child: const Text("Nie masz konta? Zarejestruj się"),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
