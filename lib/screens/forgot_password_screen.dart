import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import 'package:calorie_tracker_flutter_front/screens/reset_password_combined_screen.dart';

class ForgotPasswordScreen extends StatefulWidget {
  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  /* ──────────────────────────────────────────────
     CONTROLLERS / STATE
  ────────────────────────────────────────────── */
  final emailController = TextEditingController();

  bool isLoading = false;
  String? errorMessage;
  String? successMessage;
  bool isFormValid = false;

  /* ──────────────────────────────────────────────
     INIT / DISPOSE
  ────────────────────────────────────────────── */
  @override
  void initState() {
    super.initState();
    emailController.addListener(_updateFormState);
  }

  @override
  void dispose() {
    emailController.dispose();
    super.dispose();
  }

  /* ──────────────────────────────────────────────
     FORM VALIDATION
  ────────────────────────────────────────────── */
  void _updateFormState() {
    setState(() {
      isFormValid = emailController.text.trim().isNotEmpty;
    });
  }

  /* ──────────────────────────────────────────────
     SUBMIT
  ────────────────────────────────────────────── */
  Future<void> submit() async {
    setState(() {
      isLoading = true;
      errorMessage = null;
      successMessage = null;
    });

    final dio = context.read<Dio>();
    final res = await dio.post(
      '/api/auth/forgot-password',
      data: {"email": emailController.text.trim()},
      options: Options(validateStatus: (_) => true),
    );

    setState(() {
      isLoading = false;

      if (res.statusCode == 200) {
        // Zostawia ekran ForgotPassword w historii żeby back-arrow w ResetPassword wracał właśnie tutaj
        Navigator.push(
          context,
          MaterialPageRoute(builder: (_) => ResetPasswordScreen(email: emailController.text.trim())),
        );
      } else {
        try {
          final body = res.data;
          if (body is Map && body['errors'] != null) {
            final errors = body['errors'] as Map<String, dynamic>;
            errorMessage = errors.values.expand((v) => v).join('\n');
          } else if (body is String) {
            errorMessage = body;
          } else {
            errorMessage = "Wystąpił nieoczekiwany błąd.";
          }
        } catch (_) {
          errorMessage = "Błąd połączenia z serwerem.";
        }
      }
    });
  }

  /* ──────────────────────────────────────────────
     UI HELPERS
  ────────────────────────────────────────────── */
  Widget _buildMessageBox(String text, Color color, Icon icon) {
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [icon, const SizedBox(width: 8), Expanded(child: Text(text, style: TextStyle(color: color)))],
      ),
    );
  }

  Widget _buildTextField() {
    return TextField(
      controller: emailController,
      keyboardType: TextInputType.emailAddress,
      decoration: InputDecoration(
        hintText: "E-mail",
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
        enabledBorder: OutlineInputBorder(
          borderSide: const BorderSide(color: Colors.grey),
          borderRadius: BorderRadius.circular(12),
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
      backgroundColor: Colors.white,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        foregroundColor: const Color(0xFFA69DF5),
        leading: const BackButton(),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(24),
        child: Column(
          children: [
            const Icon(Icons.lock_outline, size: 64, color: const Color(0xFFA69DF5)),
            const SizedBox(height: 16),
            Text(
              "Zapomniałeś hasła?",
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: const Color(0xFFA69DF5)),
            ),
            const SizedBox(height: 8),
            const Text("Podaj adres e-mail powiązany z kontem.", textAlign: TextAlign.center),
            const SizedBox(height: 24),
            _buildTextField(),
            const SizedBox(height: 24),
            ElevatedButton(
              onPressed: !isFormValid || isLoading ? null : submit,
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
                      : const Text("Wyślij kod", style: TextStyle(color: Colors.white)),
            ),
            if (errorMessage != null)
              _buildMessageBox(
                errorMessage!,
                Colors.red,
                const Icon(Icons.warning_amber_rounded, color: Colors.red, size: 18),
              ),
            if (successMessage != null)
              _buildMessageBox(
                successMessage!,
                const Color(0xFFA69DF5),
                const Icon(Icons.check_circle_outline, color: const Color(0xFFA69DF5), size: 18),
              ),
          ],
        ),
      ),
    );
  }
}
