import 'dart:async';

import 'package:calorie_tracker_flutter_front/auth/token_storage.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import 'login_screen.dart';

class ResetPasswordScreen extends StatefulWidget {
  final String email;
  const ResetPasswordScreen({super.key, required this.email});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  /* ──────────────────────────────────────────────
     CONTROLLERS / STATE
  ────────────────────────────────────────────── */
  final List<TextEditingController> _codeControllers = List.generate(6, (_) => TextEditingController());
  final _newPasswordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String? _errorMessage;
  String? _infoMessage;
  int _secondsLeft = 0;
  Timer? _timer;

  bool _showPassword = false;
  bool _showConfirmPassword = false;

  String get code => _codeControllers.map((c) => c.text).join();
  bool get isFormValid =>
      code.length == 6 && _newPasswordController.text.isNotEmpty && _confirmPasswordController.text.isNotEmpty;

  /* ──────────────────────────────────────────────
     INIT / DISPOSE
  ────────────────────────────────────────────── */
  @override
  void initState() {
    super.initState();
    _startCooldown();
    _newPasswordController.addListener(() => setState(() {}));
    _confirmPasswordController.addListener(() => setState(() {}));
  }

  @override
  void dispose() {
    _timer?.cancel();
    for (var c in _codeControllers) {
      c.dispose();
    }
    _newPasswordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  /* ──────────────────────────────────────────────
     COOLDOWN
  ────────────────────────────────────────────── */
  void _startCooldown() {
    setState(() => _secondsLeft = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  /* ──────────────────────────────────────────────
     RESEND CODE
  ────────────────────────────────────────────── */
  Future<void> _resendCode() async {
    final dio = context.read<Dio>();

    final res = await dio.post(
      '/api/auth/forgot-password',
      data: {"email": widget.email},
      options: Options(validateStatus: (_) => true),
    );

    setState(() {
      if (res.statusCode == 200) {
        _infoMessage = "Nowy kod został wysłany.";
        _errorMessage = null;
        _startCooldown();
      } else {
        _errorMessage = _parseError(res.data);
        _infoMessage = null;
      }
    });
  }

  /* ──────────────────────────────────────────────
     SUBMIT
  ────────────────────────────────────────────── */
  Future<void> _submit() async {
    setState(() {
      _errorMessage = null;
      _infoMessage = null;
    });

    if (_newPasswordController.text != _confirmPasswordController.text) {
      setState(() => _errorMessage = "Hasła nie są takie same.");
      return;
    }

    final dio = context.read<Dio>();
    final storage = context.read<TokenStorage>();

    final res = await dio.post(
      '/api/auth/reset-password',
      data: {"email": widget.email, "code": code, "newPassword": _newPasswordController.text},
      options: Options(validateStatus: (_) => true),
    );

    if (res.statusCode == 200) {
      await storage.clear();

      if (!mounted) return;
      Navigator.pushAndRemoveUntil(context, MaterialPageRoute(builder: (_) => LoginScreen()), (_) => false);
    } else {
      setState(() => _errorMessage = _parseError(res.data));
    }
  }

  /* ──────────────────────────────────────────────
     ERROR PARSER
  ────────────────────────────────────────────── */
  String _parseError(dynamic body) {
    try {
      if (body is List) {
        return body.join('\n');
      } else if (body is Map && body['errors'] != null) {
        return (body['errors'] as Map<String, dynamic>).values.expand((v) => v).join('\n');
      } else if (body is String) {
        return body;
      }
    } catch (_) {}
    return "Wystąpił nieoczekiwany błąd.";
  }

  /* ──────────────────────────────────────────────
     CODE INPUT
  ────────────────────────────────────────────── */
  void _handleCodeInput(String value, int index) {
    if (value.length == 1 && index < 5) {
      FocusScope.of(context).nextFocus();
    } else if (value.isEmpty && index > 0) {
      FocusScope.of(context).previousFocus();
    }
    setState(() {});
  }

  Widget _buildCodeFields() {
    return Row(
      children: List.generate(6, (i) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: TextField(
              controller: _codeControllers[i],
              maxLength: 1,
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              decoration: InputDecoration(
                counterText: '',
                filled: true,
                fillColor: Colors.white,
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
              ),
              onChanged: (v) => _handleCodeInput(v, i),
            ),
          ),
        );
      }),
    );
  }

  /* ──────────────────────────────────────────────
     MESSAGE BOX
  ────────────────────────────────────────────── */
  Widget _buildMessageBox(String text, Color color, IconData icon) {
    final lines = text.split('\n').where((e) => e.trim().isNotEmpty);
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.05),
        border: Border.all(color: color.withOpacity(0.4)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            lines.map((line) {
              return Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(icon, color: color, size: 18),
                    const SizedBox(width: 8),
                    Expanded(child: Text(line, style: TextStyle(color: color))),
                  ],
                ),
              );
            }).toList(),
      ),
    );
  }

  /* ──────────────────────────────────────────────
     BUILD
  ────────────────────────────────────────────── */
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    final isKeyboardOpen = bottomInset > 0;

    return Scaffold(
      resizeToAvoidBottomInset: false,
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: Color(0xFFA69DF5)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              physics: isKeyboardOpen ? const ClampingScrollPhysics() : const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.fromLTRB(24, 0, 24, bottomInset + 32),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - bottomInset),
                child: Column(
                  mainAxisAlignment: isKeyboardOpen ? MainAxisAlignment.start : MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.lock_reset, size: 64, color: Color(0xFFA69DF5)),
                    const SizedBox(height: 16),
                    const Text("Zresetuj hasło", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Text(
                      "Wpisz kod wysłany na:\n${widget.email}",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 24),
                    _buildCodeFields(),
                    const SizedBox(height: 24),
                    TextField(
                      controller: _newPasswordController,
                      obscureText: !_showPassword,
                      decoration: InputDecoration(
                        hintText: "Nowe hasło",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        suffixIcon: IconButton(
                          icon: Icon(_showPassword ? Icons.visibility_off : Icons.visibility, color: Colors.grey),
                          onPressed: () => setState(() => _showPassword = !_showPassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _confirmPasswordController,
                      obscureText: !_showConfirmPassword,
                      decoration: InputDecoration(
                        hintText: "Potwierdź hasło",
                        filled: true,
                        fillColor: Colors.white,
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _showConfirmPassword ? Icons.visibility_off : Icons.visibility,
                            color: Colors.grey,
                          ),
                          onPressed: () => setState(() => _showConfirmPassword = !_showConfirmPassword),
                        ),
                      ),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: isFormValid ? _submit : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFA69DF5),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text("Zmień hasło", style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _secondsLeft > 0 ? null : _resendCode,
                      child: Text(
                        _secondsLeft > 0 ? "Wyślij ponownie za $_secondsLeft s" : "Wyślij kod ponownie",
                        style: TextStyle(color: Color(0xFFA69DF5)),
                      ),
                    ),
                    if (_infoMessage != null)
                      _buildMessageBox(_infoMessage!, Color(0xFFA69DF5), Icons.check_circle_outline),
                    if (_errorMessage != null)
                      _buildMessageBox(_errorMessage!, Colors.red, Icons.warning_amber_rounded),
                  ],
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
