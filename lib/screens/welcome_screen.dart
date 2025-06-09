import 'package:flutter/material.dart';
import 'login_screen.dart';
import 'register_screen.dart';

class WelcomeScreen extends StatelessWidget {
  const WelcomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      // Ustawienie koloru tła
      backgroundColor: Colors.white, // jasna zieleń
      body: Padding(
        // Zewnętrzne odstępy po bokach
        padding: const EdgeInsets.symmetric(horizontal: 32),
        // Column
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const SizedBox(height: 20),
            // Nagłówek z nazwą aplikacji
            const Text(
              "CalorieTracker",
              style: TextStyle(fontSize: 36, fontWeight: FontWeight.bold, color: Colors.black87),
            ),
            const SizedBox(height: 80),

            // Przycisk przejścia do ekranu rejestracji
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Nawigator przesuwa na stos nowy ekran rejestracji
                  Navigator.push(context, MaterialPageRoute(builder: (_) => RegisterScreen()));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: const Color(0xFFA69DF5),
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                ),
                child: const Text("Zarejestruj się", style: TextStyle(fontSize: 16)),
              ),
            ),

            const SizedBox(height: 16),

            // Przycisk przejścia do ekranu logowania
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
                  // Nawigator przesuwa na stos ekran logowania
                  Navigator.push(context, MaterialPageRoute(builder: (_) => LoginScreen()));
                },
                style: OutlinedButton.styleFrom(
                  side: BorderSide(color: const Color(0xFFA69DF5)),
                  foregroundColor: const Color(0xFFA69DF5),
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(50)),
                ),
                child: const Text("Zaloguj się", style: TextStyle(fontSize: 16)),
              ),
            ),

            const SizedBox(height: 40),

            // Linki do Polityki prywatności i Regulaminu
            TextButton(
              onPressed: () {
                // TODO: tutaj wywołać funkcję otwierającą URL z API lub lokalny asset
              },
              child: const Text("Polityka prywatności", style: TextStyle(color: Colors.black54)),
            ),
            TextButton(
              onPressed: () {
                // TODO: tutaj wywołać funkcję otwierającą URL z API lub lokalny asset
              },
              child: const Text("Regulamin", style: TextStyle(color: Colors.black54)),
            ),
          ],
        ),
      ),
    );
  }
}
