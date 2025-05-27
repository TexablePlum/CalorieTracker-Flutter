import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import 'login_screen.dart';

class ConfirmEmailScreen extends StatefulWidget {
  final String email;
  const ConfirmEmailScreen({super.key, required this.email});

  @override
  State<ConfirmEmailScreen> createState() => _ConfirmEmailScreenState();
}

class _ConfirmEmailScreenState extends State<ConfirmEmailScreen> {
  /* ──────────────────────────────────────────
     CONTROLLERS / STATE
  ────────────────────────────────────────── */
  final List<TextEditingController> _controllers = List.generate(6, (_) => TextEditingController());

  String? _error;
  String? _resendMessage;
  int _secondsLeft = 0;
  Timer? _resendTimer;

  /* ──────────────────────────────────────────
     LIFECYCLE
  ────────────────────────────────────────── */
  @override
  void dispose() {
    _resendTimer?.cancel();
    for (var c in _controllers) {
      c.dispose();
    }
    super.dispose();
  }

  /* ──────────────────────────────────────────
     HELPERS
  ────────────────────────────────────────── */
  String get code => _controllers.map((c) => c.text).join();

  /* ──────────────────────────────────────────
     NETWORK ACTIONS
  ────────────────────────────────────────── */
  Future<void> confirmEmail() async {
    setState(() => _error = null);

    final dio = context.read<Dio>();
    final resp = await dio.post(
      '/api/auth/confirm',
      data: {'email': widget.email, 'code': code},
      options: Options(validateStatus: (_) => true),
    );

    if (resp.statusCode == 200) {
      if (!mounted) return;
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => LoginScreen()));
    } else {
      setState(() {
        _resendMessage = null;
        _error = jsonEncode(resp.data);
      });
    }
  }

  Future<void> resendCode() async {
    final dio = context.read<Dio>();
    final resp = await dio.post(
      '/api/auth/resend-code',
      data: {'email': widget.email},
      options: Options(validateStatus: (_) => true),
    );

    setState(() {
      if (resp.statusCode == 200) {
        _resendMessage = "Kod został wysłany ponownie.";
        _error = null;
        _startResendCooldown();
      } else {
        _resendMessage = null;
        _error = jsonEncode(resp.data);
      }
    });
  }

  /* ──────────────────────────────────────────
     COOLDOWN TIMER
  ────────────────────────────────────────── */
  void _startResendCooldown() {
    setState(() => _secondsLeft = 60);
    _resendTimer?.cancel();
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (_secondsLeft <= 1) {
        t.cancel();
        setState(() => _secondsLeft = 0);
      } else {
        setState(() => _secondsLeft--);
      }
    });
  }

  /* ──────────────────────────────────────────
     INPUT HANDLING
  ────────────────────────────────────────── */
  void _handleInput(String v, int i) {
    if (v.length == 1 && i < 5) {
      FocusScope.of(context).nextFocus();
    } else if (v.isEmpty && i > 0) {
      FocusScope.of(context).previousFocus();
    }
    setState(() {}); // odświeża przycisk
  }

  /* ──────────────────────────────────────────
     UI BUILDING HELPERS
  ────────────────────────────────────────── */
  Widget _buildMessageBox(String msg, Color col, IconData ico) {
    final lines = msg.split('\n').where((l) => l.trim().isNotEmpty);
    return Container(
      margin: const EdgeInsets.only(top: 24),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: col.withOpacity(0.05),
        border: Border.all(color: col.withOpacity(0.3)),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children:
            lines
                .map(
                  (l) => Padding(
                    padding: const EdgeInsets.symmetric(vertical: 4),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(ico, color: col, size: 18),
                        const SizedBox(width: 8),
                        Expanded(child: Text(l, style: TextStyle(color: col))),
                      ],
                    ),
                  ),
                )
                .toList(),
      ),
    );
  }

  Widget _buildCodeInput() {
    return Row(
      children: List.generate(6, (i) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            child: TextField(
              controller: _controllers[i],
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
              onChanged: (v) => _handleInput(v, i),
            ),
          ),
        );
      }),
    );
  }

  /* ──────────────────────────────────────────
     BUILD
  ────────────────────────────────────────── */
  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.of(context).viewInsets.bottom;
    return Scaffold(
      resizeToAvoidBottomInset: true,
      backgroundColor: Colors.white,
      appBar: AppBar(backgroundColor: Colors.transparent, elevation: 0, foregroundColor: Color(0xFFA69DF5)),
      body: SafeArea(
        child: LayoutBuilder(
          builder: (context, constraints) {
            return SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(24, 32, 24, bottomInset + 16),
              child: ConstrainedBox(
                constraints: BoxConstraints(minHeight: constraints.maxHeight - (bottomInset + 16)),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.mark_email_read_outlined, size: 64, color: Color(0xFFA69DF5)),
                    const SizedBox(height: 16),
                    const Text("Potwierdź adres e-mail", style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600)),
                    const SizedBox(height: 12),
                    Text(
                      "Wpisz kod wysłany na adres: ${widget.email}",
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[700]),
                    ),
                    const SizedBox(height: 24),
                    _buildCodeInput(),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      onPressed: code.length == 6 ? confirmEmail : null,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Color(0xFFA69DF5),
                        minimumSize: const Size(double.infinity, 48),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                      ),
                      child: const Text("Potwierdź", style: TextStyle(color: Colors.white)),
                    ),
                    const SizedBox(height: 16),
                    TextButton(
                      onPressed: _secondsLeft > 0 ? null : resendCode,
                      child: Text(
                        _secondsLeft > 0 ? "Wyślij ponownie za $_secondsLeft s" : "Wyślij kod ponownie",
                        style: TextStyle(color: Color(0xFFA69DF5)),
                      ),
                    ),
                    if (_resendMessage != null)
                      _buildMessageBox(_resendMessage!, Color(0xFFA69DF5), Icons.check_circle_outline),
                    if (_error != null) _buildMessageBox(_error!, Colors.red, Icons.warning_amber_rounded),
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
