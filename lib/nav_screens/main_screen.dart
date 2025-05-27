import 'package:calorie_tracker_flutter_front/nav_screens/cameraScreen.dart';
import 'package:calorie_tracker_flutter_front/nav_screens/find.dart';
import 'package:calorie_tracker_flutter_front/nav_screens/homepage.dart';
import 'package:calorie_tracker_flutter_front/nav_screens/recipeScreen.dart';
import 'package:calorie_tracker_flutter_front/screens/mainProfile.dart';
import 'package:calorie_tracker_flutter_front/screens/profile_setup_screen.dart';
import 'package:flutter/material.dart';

class MainScreen extends StatefulWidget {
  const MainScreen({super.key});

  @override
  State<MainScreen> createState() => _MainScreenState();
}

class _MainScreenState extends State<MainScreen> {
  int _pageIndex = 0;
  final List<Widget> _pages = [HomePage(), FindScreen(), CameraScreen(), recipeScreen(), mainProfile()];
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: BottomNavigationBar(
        selectedItemColor: Colors.purple,
        unselectedItemColor: Colors.grey,
        currentIndex: _pageIndex,
        onTap: (value) {
          setState(() {
            _pageIndex = value;
          });
        },
        type: BottomNavigationBarType.fixed,
        items: [
          BottomNavigationBarItem(icon: Icon(Icons.home), label: "home"),
          BottomNavigationBarItem(icon: Icon(Icons.search), label: "find"),
          BottomNavigationBarItem(icon: Icon(Icons.camera), label: "camera"),
          BottomNavigationBarItem(icon: Icon(Icons.restaurant_menu), label: "recipe"),
          BottomNavigationBarItem(icon: Icon(Icons.person), label: "profile"),
        ],
      ),
      body: _pages[_pageIndex],
    );
  }
}
