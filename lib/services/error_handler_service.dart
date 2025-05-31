import 'package:flutter/material.dart';
import 'package:dio/dio.dart';

class ErrorHandlerService {
  static final ErrorHandlerService _instance = ErrorHandlerService._internal();
  factory ErrorHandlerService() => _instance;
  ErrorHandlerService._internal();

  /// Globalny context dla pokazywania błędów
  BuildContext? _context;
  
  void setContext(BuildContext context) {
    _context = context;
  }

  /// Obsługuje błędy Dio i pokazuje odpowiednie komunikaty
  void handleDioError(DioException error, {bool showSnackBar = true}) {
    // Sprawdza czy request ma flagę skipErrorHandler
    if (error.requestOptions.extra['skipErrorHandler'] == true) {
      debugPrint('ErrorHandler: Skipping error handling for ${error.requestOptions.path}');
      return; // Nie pokazuj błędu
    }

    String message;
    
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
        message = 'Połączenie z serwerem zostało przerwane. Sprawdź internetem.';
        break;
        
      case DioExceptionType.connectionError:
        message = 'Brak połączenia z internetem.';
        break;
        
      case DioExceptionType.badResponse:
        message = _handleBadResponse(error.response);
        break;
        
      case DioExceptionType.cancel:
        return; // Nie pokazuje błędu dla anulowanych requestów
        
      default:
        message = 'Wystąpił nieoczekiwany błąd.';
    }

    debugPrint('ErrorHandler: ${error.type} - $message');
    
    if (showSnackBar && _context != null) {
      _showSnackBar(message);
    }
  }

  String _handleBadResponse(Response? response) {
    if (response == null) return 'Serwer nie odpowiada.';
    
    switch (response.statusCode) {
      case 400:
        return _extractErrorMessage(response.data) ?? 'Nieprawidłowe dane.';
      case 401:
        return 'Sesja wygasła. Zaloguj się ponownie.';
      case 403:
        return 'Brak uprawnień do tej operacji.';
      case 404:
        return 'Nie znaleziono zasobu.';
      case 409:
        return _extractErrorMessage(response.data) ?? 'Konflikt danych.';
      case 422:
        return _extractErrorMessage(response.data) ?? 'Nieprawidłowe dane.';
      case 500:
        return 'Błąd serwera. Spróbuj ponownie później.';
      case 502:
      case 503:
        return 'Serwer jest tymczasowo niedostępny.';
      default:
        return 'Wystąpił błąd (${response.statusCode}).';
    }
  }

  String? _extractErrorMessage(dynamic data) {
    try {
      if (data is String) return data;
      
      if (data is Map) {
        // Sprawdza czy jest to JSON z błędami
        if (data['errors'] != null) {
          final errors = data['errors'] as Map<String, dynamic>;
          return errors.values
              .expand((v) => v is List ? v : [v])
              .join('\n');
        }
        
        // Sprawdza czy jest to pojedynczy komunikat
        if (data['message'] != null) {
          return data['message'].toString();
        }
      }
      
      if (data is List) {
        return data.join('\n');
      }
    } catch (e) {
      debugPrint('Error extracting error message: $e');
    }
    
    return null;
  }

  void _showSnackBar(String message) {
    if (_context == null) return;
    
    ScaffoldMessenger.of(_context!).hideCurrentSnackBar();
    ScaffoldMessenger.of(_context!).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.red[600],
        behavior: SnackBarBehavior.floating,
        action: SnackBarAction(
          label: 'OK',
          textColor: Colors.white,
          onPressed: () => ScaffoldMessenger.of(_context!).hideCurrentSnackBar(),
        ),
      ),
    );
  }

  /// Pokazuje success message
  void showSuccess(String message) {
    if (_context == null) return;
    
    ScaffoldMessenger.of(_context!).hideCurrentSnackBar();
    ScaffoldMessenger.of(_context!).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: const Color(0xFFA69DF5),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  /// Pokazuje info message
  void showInfo(String message) {
    if (_context == null) return;
    
    ScaffoldMessenger.of(_context!).hideCurrentSnackBar();
    ScaffoldMessenger.of(_context!).showSnackBar(
      SnackBar(
        content: Text(message),
        backgroundColor: Colors.blue[600],
        behavior: SnackBarBehavior.floating,
      ),
    );
  }
}