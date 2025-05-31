import 'package:calorie_tracker_flutter_front/nav_pages/profile_page.dart';
import 'package:calorie_tracker_flutter_front/nav_pages/camera_page.dart';
import 'package:calorie_tracker_flutter_front/nav_pages/find_page.dart';
import 'package:calorie_tracker_flutter_front/nav_pages/home_page.dart';
import 'package:calorie_tracker_flutter_front/nav_pages/recipe_page.dart';
import 'package:flutter/material.dart';

class MainPage extends StatefulWidget {
  const MainPage({super.key});

  @override
  State<MainPage> createState() => MainPageState();
}

class MainPageState extends State<MainPage> {
  int _pageIndex = 0;
  int _previousPageIndex = 0; // Przechowuje poprzednią kartę
  final List<Widget> _pages = [
    const HomePage(), 
    const FindPage(), 
    const CameraPage(), 
    const RecipePage(), 
    ProfilePage()
  ];

  /// Publiczna metoda do przełączania kart z zewnątrz
  void switchToTab(int index) {
    if (index >= 0 && index < _pages.length) {
      setState(() {
        _pageIndex = index;
      });
    }
  }

  /// Wraca do poprzedniej karty (używane przez CameraPage)
  void goToPreviousTab() {
    setState(() {
      // Sprawdza czy poprzednia karta to nie kamera
      if (_previousPageIndex == 2) {
        // Jeśli poprzednia to kamera, idź na stronę główną
        _pageIndex = 0;
      } else {
        _pageIndex = _previousPageIndex;
      }
    });
  }

  /// Pobiera indeks poprzedniej karty
  int get previousTabIndex => _previousPageIndex;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: const Color(0xFFA69DF5),
        unselectedItemColor: Colors.grey,
        currentIndex: _pageIndex,
        onTap: (value) {
          setState(() {
            // Zawsze zapisuje poprzednią kartę przed przejściem na nową
            _previousPageIndex = _pageIndex;
            _pageIndex = value;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "Start"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "Znajdź"),
          BottomNavigationBarItem(icon: Icon(Icons.camera), label: "Skaner"),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: "Przepisy"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "Profil"),
        ],
      ),
      body: _pages[_pageIndex], // Używa bezpośredniego dostępu (zamiast IndexedStack)
    );
  }
}