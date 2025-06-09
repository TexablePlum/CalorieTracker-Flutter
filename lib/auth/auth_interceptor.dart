import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter/foundation.dart';
import '../api_config.dart';
import 'token_storage.dart';

class AuthInterceptor extends Interceptor {
  AuthInterceptor(this._dio, this._storage);

  final Dio _dio;
  final TokenStorage _storage;

  /// Flaga + completer trzymające w kupie równoległe 401-ki
  bool _refreshing = false;
  Completer<bool>? _refCompleter;
  
  /// Timestamp ostatniego refresha (żeby uniknąć zbyt częstych prób)
  DateTime? _lastRefreshAttempt;

  @override
  void onRequest(RequestOptions options, RequestInterceptorHandler handler) async {
    if (kDebugMode) {
      debugPrint('🔵 Request: ${options.method} ${options.path}');
    }
    
    try {
      final access = await _storage.access;
      
      if (access != null && access.isNotEmpty) {
        options.headers['Authorization'] = 'Bearer $access';
      }
    } catch (e) {
      debugPrint('🔴 Error getting access token: $e');
    }
    
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    final statusCode = err.response?.statusCode;
    final path = err.requestOptions.path;
    
    if (kDebugMode) {
      debugPrint('🔴 AUTH_INTERCEPTOR: onError called!');
      debugPrint('🔴 AUTH_INTERCEPTOR: Status=$statusCode, Path=$path');
      debugPrint('🔴 AUTH_INTERCEPTOR: Response data: ${err.response?.data}');
    }
    
    // Jeśli to nie 401, przepuszcza dalej
    if (statusCode != 401) {
      if (kDebugMode) {
        debugPrint('🔴 AUTH_INTERCEPTOR: Not 401, passing through');
      }
      return handler.next(err);
    }
    
    // Jeśli to endpoint autoryzacyjny, nie robi refresh (żeby uniknąć pętli)
    if (_isAuthEndpoint(path)) {
      if (kDebugMode) {
        debugPrint('🔴 AUTH_INTERCEPTOR: Auth endpoint, not retrying');
      }
      return handler.next(err);
    }
    
    // Sprawdza czy refresh token istnieje
    try {
      final refresh = await _storage.refresh;
      if (refresh == null || refresh.isEmpty) {
        if (kDebugMode) {
          debugPrint('🔴 AUTH_INTERCEPTOR: No refresh token, clearing storage');
        }
        await _storage.clear();
        return handler.next(err);
      }
    } catch (e) {
      debugPrint('🔴 AUTH_INTERCEPTOR: Error checking refresh token: $e');
      return handler.next(err);
    }
    
    // Sprawdza czy nie próbowano zbyt niedawno (tylko jeśli poprzednia próba się udała)
    if (_lastRefreshAttempt != null && 
        DateTime.now().difference(_lastRefreshAttempt!).inSeconds < 5) {
      // Sprawdź czy mamy aktualny access token - jeśli tak, poprzedni refresh się udał
      final currentAccess = await _storage.access;
      if (currentAccess != null && currentAccess.isNotEmpty) {
        if (kDebugMode) {
          debugPrint('🔴 AUTH_INTERCEPTOR: Recent refresh succeeded, retrying request');
        }
        // Reset timer po udanym refresh
        _lastRefreshAttempt = null;
      } else {
        if (kDebugMode) {
          debugPrint('🔴 AUTH_INTERCEPTOR: Recent refresh failed, clearing storage and not retrying');
        }
        // Poprzedni refresh się nie udał, wyczyść storage
        await _storage.clear();
        return handler.next(err);
      }
    }
    
    try {
      bool refreshSuccess = false;
      
      // 1 Jeżeli już odświeża – czeka
      if (_refreshing && _refCompleter != null) {
        if (kDebugMode) {
          debugPrint('🟡 AUTH_INTERCEPTOR: Waiting for ongoing refresh...');
        }
        refreshSuccess = await _refCompleter!.future;
      } else {
        // 2 Startuje własny refresh
        if (kDebugMode) {
          debugPrint('🟡 AUTH_INTERCEPTOR: Starting token refresh...');
        }
        _refreshing = true;
        _refCompleter = Completer<bool>();
        _lastRefreshAttempt = DateTime.now();
        
        try {
          refreshSuccess = await _refreshToken();
          _refCompleter!.complete(refreshSuccess);
        } catch (e) {
          debugPrint('🔴 AUTH_INTERCEPTOR: Exception during refresh: $e');
          _refCompleter!.complete(false);
          refreshSuccess = false;
        } finally {
          _refreshing = false;
        }
      }
      
      if (!refreshSuccess) {
        if (kDebugMode) {
          debugPrint('🔴 AUTH_INTERCEPTOR: Token refresh failed, clearing storage');
        }
        // Wyczyść storage po nieudanym refresh
        await _storage.clear();
        return handler.next(err);
      }
      
      // Reset timestamp po udanym refresh
      _lastRefreshAttempt = null;
      
      // 3️ Powtarza ORYGINALNE żądanie z nowym access-tokenem
      final newAccess = await _storage.access;
      
      if (newAccess == null || newAccess.isEmpty) {
        debugPrint('🔴 AUTH_INTERCEPTOR: No new access token after refresh');
        await _storage.clear();
        return handler.next(err);
      }
      
      // Klonuje request options
      final clonedOptions = err.requestOptions.copyWith(
        headers: Map<String, dynamic>.from(err.requestOptions.headers)
          ..['Authorization'] = 'Bearer $newAccess',
      );
      
      if (kDebugMode) {
        debugPrint('🟢 AUTH_INTERCEPTOR: Retrying request with new token');
      }
      
      try {
        final response = await _dio.fetch(clonedOptions);
        return handler.resolve(response);
      } catch (retryError) {
        if (kDebugMode) {
          debugPrint('🔴 AUTH_INTERCEPTOR: Retry failed: $retryError');
        }
        if (retryError is DioException) {
          return handler.next(retryError);
        }
        return handler.next(err);
      }
    } catch (e) {
      debugPrint('🔴 AUTH_INTERCEPTOR: Unexpected error in error handler: $e');
      return handler.next(err);
    }
  }

  /// Sprawdza czy endpoint to endpoint autoryzacyjny (bez wymagania tokena)
  bool _isAuthEndpoint(String path) {
    // Tylko endpointy które nie wymagają autoryzacji
    return path.contains('/api/auth/register') ||
           path.contains('/api/auth/login') ||
           path.contains('/api/auth/confirm') ||
           path.contains('/api/auth/resend-code') ||
           path.contains('/api/auth/refresh') ||
           path.contains('/api/auth/forgot-password') ||
           path.contains('/api/auth/reset-password');
  }

  /// Odświeża tokeny
  Future<bool> _refreshToken() async {
    try {
      final currentAccess = await _storage.access;
      final currentRefresh = await _storage.refresh;
      
      if (currentRefresh == null || currentRefresh.isEmpty) {
        if (kDebugMode) {
          debugPrint('🔴 AUTH_INTERCEPTOR: No refresh token available');
        }
        return false;
      }

      if (kDebugMode) {
        debugPrint('🟡 AUTH_INTERCEPTOR: Making refresh request...');
      }

      // Używa OSOBNEGO Dio bez interceptorów
      final bareDio = Dio(BaseOptions(
        baseUrl: ApiConfig.baseUrl,
        connectTimeout: const Duration(seconds: 10),
        receiveTimeout: const Duration(seconds: 20),
        validateStatus: (status) => true, // Akceptuje wszystkie statusy
      ));

      final response = await bareDio.post(
        '/api/auth/refresh',
        data: {
          'accessToken': currentAccess ?? '',
          'refreshToken': currentRefresh,
        },
        options: Options(
          headers: {
            'Content-Type': 'application/json',
          },
        ),
      );

      if (kDebugMode) {
        debugPrint('🟡 AUTH_INTERCEPTOR: Refresh response: ${response.statusCode}');
        debugPrint('🟡 AUTH_INTERCEPTOR: Refresh data: ${response.data}');
      }

      if (response.statusCode == 200 && response.data != null) {
        final newAccess = response.data['accessToken'] as String?;
        final newRefresh = response.data['refreshToken'] as String?;
        
        if (newAccess == null || newAccess.isEmpty) {
          debugPrint('🔴 AUTH_INTERCEPTOR: No access token in refresh response');
          return false;
        }
        
        await _storage.save(
          newAccess,
          newRefresh ?? currentRefresh, // Użyje starego refresh tokena jeśli nowy nie przyszedł
        );
        
        if (kDebugMode) {
          debugPrint('🟢 AUTH_INTERCEPTOR: Tokens refreshed successfully');
        }
        return true;
      } else {
        if (kDebugMode) {
          debugPrint('🔴 AUTH_INTERCEPTOR: Refresh failed with status: ${response.statusCode}');
        }
        
        // Jeśli refresh token jest nieważny, wyczyść storage
        if (response.statusCode == 401 || response.statusCode == 403) {
          if (kDebugMode) {
            debugPrint('🔴 AUTH_INTERCEPTOR: Refresh token invalid, clearing storage');
          }
          await _storage.clear();
        }
        
        return false;
      }
    } catch (e) {
      if (kDebugMode) {
        debugPrint('🔴 AUTH_INTERCEPTOR: Exception during refresh: $e');
      }
      
      // W przypadku błędu sieciowego nie czyści tokenów
      // bo mogą być nadal ważne gdy połączenie wróci
      return false;
    }
  }
}

// Extension do kopiowania RequestOptions
extension RequestOptionsCopyWith on RequestOptions {
  RequestOptions copyWith({
    String? method,
    String? path,
    Map<String, dynamic>? queryParameters,
    dynamic data,
    Map<String, dynamic>? headers,
    ResponseType? responseType,
    String? contentType,
    ValidateStatus? validateStatus,
    bool? receiveDataWhenStatusError,
    Map<String, dynamic>? extra,
    bool? followRedirects,
    int? maxRedirects,
    Duration? connectTimeout,
    Duration? receiveTimeout,
    Duration? sendTimeout,
    RequestEncoder? requestEncoder,
    ResponseDecoder? responseDecoder,
    ListFormat? listFormat,
  }) {
    return RequestOptions(
      method: method ?? this.method,
      path: path ?? this.path,
      queryParameters: queryParameters ?? this.queryParameters,
      data: data ?? this.data,
      headers: headers ?? this.headers,
      responseType: responseType ?? this.responseType,
      contentType: contentType ?? this.contentType,
      validateStatus: validateStatus ?? this.validateStatus,
      receiveDataWhenStatusError: receiveDataWhenStatusError ?? this.receiveDataWhenStatusError,
      extra: extra ?? this.extra,
      followRedirects: followRedirects ?? this.followRedirects,
      maxRedirects: maxRedirects ?? this.maxRedirects,
      connectTimeout: connectTimeout ?? this.connectTimeout,
      receiveTimeout: receiveTimeout ?? this.receiveTimeout,
      sendTimeout: sendTimeout ?? this.sendTimeout,
      requestEncoder: requestEncoder ?? this.requestEncoder,
      responseDecoder: responseDecoder ?? this.responseDecoder,
      listFormat: listFormat ?? this.listFormat,
      baseUrl: this.baseUrl,
    );
  }
}