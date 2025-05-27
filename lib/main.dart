import 'package:calorie_tracker_flutter_front/screens/welcome_screen.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';

import 'api_config.dart';
import 'auth/token_storage.dart';
import 'auth/auth_interceptor.dart';
import 'screens/splash_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 1. trwałe tokeny
  final storage = TokenStorage();

  // 2. Dio z interceptorami
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 10),
      receiveTimeout: const Duration(seconds: 20),
      contentType: Headers.jsonContentType,
    ),
  );

  dio.interceptors.addAll([
    AuthInterceptor(dio, storage), // automatyczny refresh tokenów
    // TODO: usuń w release
    LogInterceptor(requestBody: true, responseBody: true),
  ]);

  runApp(
    MultiProvider(
      providers: [Provider<TokenStorage>.value(value: storage), Provider<Dio>.value(value: dio)],
      child: const CalorieTrackerApp(),
    ),
  );
}

/// Główny widget aplikacji.
class CalorieTrackerApp extends StatelessWidget {
  const CalorieTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'CalorieTracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(primarySwatch: Colors.green),
      home: WelcomeScreen(), // pierwszy ekran
    );
  }
}
