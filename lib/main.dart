import 'package:calorie_tracker_flutter_front/screens/splash_screen.dart';
import 'package:calorie_tracker_flutter_front/services/error_handler_service.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';

import 'api_config.dart';
import 'auth/token_storage.dart';
import 'auth/auth_interceptor.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Global error handling
  FlutterError.onError = (FlutterErrorDetails details) {
    if (kDebugMode) {
      FlutterError.dumpErrorToConsole(details);
    }
  };

  // 1. Trwałe tokeny
  final storage = TokenStorage();

  // 2. Error handler service
  final errorHandler = ErrorHandlerService();

  // 3. Dio z interceptorami
  final dio = Dio(
    BaseOptions(
      baseUrl: ApiConfig.baseUrl,
      connectTimeout: const Duration(seconds: 15),
      receiveTimeout: const Duration(seconds: 30),
      sendTimeout: const Duration(seconds: 15),
      contentType: Headers.jsonContentType,
      headers: {
        'Accept': 'application/json',
      },
    ),
  );

  dio.interceptors.addAll([
    // Auth interceptor
    AuthInterceptor(dio, storage),
    
    // Obsługa błędów
    InterceptorsWrapper(
      onError: (error, handler) {
        // Nie pokazuje snackbarów dla auth endpointów
        final isAuthEndpoint = error.requestOptions.path.contains('/api/auth/');
        errorHandler.handleDioError(error, showSnackBar: !isAuthEndpoint);
        handler.next(error);
      },
    ),
    
    // Debug interceptor tylko w debug mode
    if (kDebugMode)
      LogInterceptor(
        requestBody: true,
        responseBody: true,
        requestHeader: false,
        responseHeader: false,
        error: true,
        logPrint: (obj) => debugPrint(obj.toString()),
      ),
  ]);

  runApp(
    MultiProvider(
      providers: [
        Provider<TokenStorage>.value(value: storage),
        Provider<Dio>.value(value: dio),
        Provider<ErrorHandlerService>.value(value: errorHandler),
      ],
      child: const CalorieTrackerApp(),
    ),
  );
}

/// Główny widget aplikacji.
class CalorieTrackerApp extends StatelessWidget {
  const CalorieTrackerApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Ustawia context dla error handlera
    final errorHandler = context.read<ErrorHandlerService>();
    
    return MaterialApp(
      title: 'CalorieTracker',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        primarySwatch: Colors.purple,
        visualDensity: VisualDensity.adaptivePlatformDensity,
        appBarTheme: const AppBarTheme(
          backgroundColor: Colors.transparent,
          elevation: 0,
          iconTheme: IconThemeData(color: Color(0xFFA69DF5)),
          titleTextStyle: TextStyle(
            color: Colors.black,
            fontSize: 18,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      home: Builder(
        builder: (context) {
          // Ustawia context dla error handlera
          WidgetsBinding.instance.addPostFrameCallback((_) {
            errorHandler.setContext(context);
          });
          return SplashScreen();
        },
      ),
    );
  }
}