import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import 'confirm_email_screen.dart';

class RegisterScreen extends StatefulWidget {
  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  /* ──────────────────────────────────────────────
     CONTROLLERS / STATE
  ────────────────────────────────────────────── */
  final firstNameController = TextEditingController();
  final lastNameController = TextEditingController();
  final emailController = TextEditingController();
  final passwordController = TextEditingController();
  final confirmPasswordController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;

  bool get isFormValid =>
      firstNameController.text.trim().isNotEmpty &&
      lastNameController.text.trim().isNotEmpty &&
      emailController.text.trim().isNotEmpty &&
      passwordController.text.isNotEmpty &&
      confirmPasswordController.text.isNotEmpty;

  bool _showPassword = false;
  bool _showConfirmPassword = false;

  /* ──────────────────────────────────────────────
     REGISTER
  ────────────────────────────────────────────── */
  Future<void> register() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
    });

    if (passwordController.text != confirmPasswordController.text) {
      setState(() {
        errorMessage = "Hasła nie są takie same.";
        isLoading = false;
      });
      return;
    }

    final dio = context.read<Dio>();

    try {
      final res = await dio.post(
        '/api/auth/register',
        data: {
          "email": emailController.text.trim(),
          "password": passwordController.text,
          "firstName": firstNameController.text,
          "lastName": lastNameController.text,
        },
        options: Options(validateStatus: (_) => true),
      );

      switch (res.statusCode) {
        case 200:
          Navigator.pushReplacement(
            context,
            MaterialPageRoute(builder: (_) => ConfirmEmailScreen(email: emailController.text.trim())),
          );
          break;

        case 409: // e-mail już istnieje
          setState(() => errorMessage = res.data is String ? res.data : jsonEncode(res.data));
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

  String _extractError(dynamic body) {
    try {
      if (body is List) return body.join('\n');
      if (body is Map && body['errors'] != null) {
        final errors = body['errors'] as Map<String, dynamic>;
        return errors.values.expand((v) => v).join('\n');
      }
      if (body is String) return body;
    } catch (_) {}
    return "Wystąpił nieoczekiwany błąd.";
  }

  /* ──────────────────────────────────────────────
     UI HELPERS
  ────────────────────────────────────────────── */
  Widget _buildTextField(
    TextEditingController controller,
    String hint, {
    TextInputType type = TextInputType.text,
    bool isObscure = false,
    VoidCallback? onToggleVisibility,
    bool? isTextVisible,
  }) {
    return TextField(
      controller: controller,
      keyboardType: type,
      obscureText: isObscure,
      onChanged: (_) => setState(() {}),
      decoration: InputDecoration(
        hintText: hint,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        filled: true,
        fillColor: Colors.white,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.grey),
          borderRadius: BorderRadius.circular(12),
        ),
        suffixIcon:
            onToggleVisibility != null
                ? IconButton(
                  icon: Icon(isTextVisible! ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                  onPressed: onToggleVisibility,
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
        leading: IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => Navigator.pop(context)),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              "Załóż konto",
              style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold, color: const Color(0xFFA69DF5)),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            _buildTextField(firstNameController, "Imię"),
            const SizedBox(height: 12),
            _buildTextField(lastNameController, "Nazwisko"),
            const SizedBox(height: 12),
            _buildTextField(emailController, "E-mail", type: TextInputType.emailAddress),
            const SizedBox(height: 12),
            _buildTextField(
              passwordController,
              "Hasło",
              type: TextInputType.visiblePassword,
              isObscure: !_showPassword,
              isTextVisible: _showPassword,
              onToggleVisibility: () => setState(() => _showPassword = !_showPassword),
            ),
            const SizedBox(height: 12),
            _buildTextField(
              confirmPasswordController,
              "Potwierdź hasło",
              type: TextInputType.visiblePassword,
              isObscure: !_showConfirmPassword,
              isTextVisible: _showConfirmPassword,
              onToggleVisibility: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
            ),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: !isFormValid || isLoading ? null : register,
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
                      : const Text("Zarejestruj się", style: TextStyle(color: Colors.white)),
            ),
            if (errorMessage != null) _buildErrorBox(errorMessage!),
          ],
        ),
      ),
    );
  }
}
