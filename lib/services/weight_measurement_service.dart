import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import '../models/weight_measurement.dart';

/// Serwis do obsługi API pomiarów masy ciała
class WeightMeasurementService {
  final Dio _dio;

  WeightMeasurementService(this._dio);

  /// Pobiera listę pomiarów użytkownika z paginacją
  Future<WeightMeasurementsResponse> getWeightMeasurements({
    int skip = 0,
    int take = 50,
  }) async {
    try {
      debugPrint('📊 WeightMeasurementService: Getting measurements (skip: $skip, take: $take)');
      
      final response = await _dio.get(
        '/api/WeightMeasurements',
        queryParameters: {
          'skip': skip,
          'take': take,
        },
      );

      debugPrint('📊 WeightMeasurementService: Got ${response.data['measurements']?.length ?? 0} measurements');
      
      return WeightMeasurementsResponse.fromJson(response.data);
    } catch (e) {
      debugPrint('❌ WeightMeasurementService: Error getting measurements: $e');
      rethrow;
    }
  }

  /// Pobiera wszystkie pomiary użytkownika (bez paginacji)
  Future<List<WeightMeasurement>> getAllWeightMeasurements() async {
    try {
      debugPrint('📊 WeightMeasurementService: Getting all measurements');
      
      final List<WeightMeasurement> allMeasurements = [];
      int skip = 0;
      const int take = 100;
      bool hasMore = true;

      while (hasMore) {
        final response = await getWeightMeasurements(skip: skip, take: take);
        allMeasurements.addAll(response.measurements);
        hasMore = response.hasMore;
        skip += take;
      }

      debugPrint('📊 WeightMeasurementService: Got ${allMeasurements.length} total measurements');
      
      return allMeasurements;
    } catch (e) {
      debugPrint('❌ WeightMeasurementService: Error getting all measurements: $e');
      rethrow;
    }
  }

  /// Pobiera najnowszy pomiar użytkownika
  Future<WeightMeasurement?> getLatestWeightMeasurement() async {
    try {
      debugPrint('📊 WeightMeasurementService: Getting latest measurement');
      
      final response = await _dio.get('/api/WeightMeasurements/latest');
      
      return WeightMeasurement.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        debugPrint('📊 WeightMeasurementService: No measurements found');
        return null;
      }
      debugPrint('❌ WeightMeasurementService: Error getting latest measurement: $e');
      rethrow;
    } catch (e) {
      debugPrint('❌ WeightMeasurementService: Unexpected error getting latest measurement: $e');
      rethrow;
    }
  }

  /// Pobiera szczegóły konkretnego pomiaru
  Future<WeightMeasurement?> getWeightMeasurementById(String id) async {
    try {
      debugPrint('📊 WeightMeasurementService: Getting measurement details for ID: $id');
      
      final response = await _dio.get('/api/WeightMeasurements/$id');
      
      return WeightMeasurement.fromJson(response.data);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) {
        debugPrint('📊 WeightMeasurementService: Measurement not found: $id');
        return null;
      }
      debugPrint('❌ WeightMeasurementService: Error getting measurement details: $e');
      rethrow;
    } catch (e) {
      debugPrint('❌ WeightMeasurementService: Unexpected error getting measurement details: $e');
      rethrow;
    }
  }

  /// Tworzy nowy pomiar masy ciała
  Future<String> createWeightMeasurement(CreateWeightMeasurementRequest request) async {
    try {
      debugPrint('📊 WeightMeasurementService: Creating measurement: ${request.weightKg}kg on ${request.measurementDate}');
      
      final response = await _dio.post(
        '/api/WeightMeasurements',
        data: request.toJson(),
      );

      final measurementId = response.data['id']?.toString() ?? '';
      debugPrint('📊 WeightMeasurementService: Measurement created with ID: $measurementId');
      
      return measurementId;
    } catch (e) {
      debugPrint('❌ WeightMeasurementService: Error creating measurement: $e');
      rethrow;
    }
  }

  /// Aktualizuje istniejący pomiar masy ciała
  Future<void> updateWeightMeasurement(String id, UpdateWeightMeasurementRequest request) async {
    try {
      debugPrint('📊 WeightMeasurementService: Updating measurement $id: ${request.weightKg}kg on ${request.measurementDate}');
      
      await _dio.put(
        '/api/WeightMeasurements/$id',
        data: request.toJson(),
      );

      debugPrint('📊 WeightMeasurementService: Measurement updated successfully');
    } catch (e) {
      debugPrint('❌ WeightMeasurementService: Error updating measurement: $e');
      rethrow;
    }
  }

  /// Usuwa pomiar masy ciała
  Future<void> deleteWeightMeasurement(String id) async {
    try {
      debugPrint('📊 WeightMeasurementService: Deleting measurement: $id');
      
      await _dio.delete('/api/WeightMeasurements/$id');

      debugPrint('📊 WeightMeasurementService: Measurement deleted successfully');
    } catch (e) {
      debugPrint('❌ WeightMeasurementService: Error deleting measurement: $e');
      rethrow;
    }
  }

  /// Pobiera pomiary w określonym zakresie dat
  Future<List<WeightMeasurement>> getWeightMeasurementsInDateRange({
    DateTime? startDate,
    DateTime? endDate,
  }) async {
    try {
      // Pobiera wszystkie pomiary i przefiltrowuje lokalnie
      final allMeasurements = await getAllWeightMeasurements();
      
      return allMeasurements.where((measurement) {
        if (startDate != null && measurement.measurementDate.isBefore(startDate)) {
          return false;
        }
        if (endDate != null && measurement.measurementDate.isAfter(endDate)) {
          return false;
        }
        return true;
      }).toList();
    } catch (e) {
      debugPrint('❌ WeightMeasurementService: Error getting measurements in date range: $e');
      rethrow;
    }
  }

  /// Pobiera pomiary dla określonego okresu
  Future<List<WeightMeasurement>> getWeightMeasurementsForPeriod(DateFilterPeriod period) async {
    DateTime? startDate;
    final endDate = DateTime.now();

    switch (period) {
      case DateFilterPeriod.all:
        startDate = null;
        break;
      case DateFilterPeriod.oneYear:
        startDate = DateTime.now().subtract(const Duration(days: 365));
        break;
      case DateFilterPeriod.sixMonths:
        startDate = DateTime.now().subtract(const Duration(days: 183));
        break;
      case DateFilterPeriod.threeMonths:
        startDate = DateTime.now().subtract(const Duration(days: 90));
        break;
      case DateFilterPeriod.oneMonth:
        startDate = DateTime.now().subtract(const Duration(days: 30));
        break;
    }

    return getWeightMeasurementsInDateRange(
      startDate: startDate,
      endDate: endDate,
    );
  }
}

/// Enum dla okresów filtrowania dat
enum DateFilterPeriod {
  all('Od początku'),
  oneYear('1 rok'),
  sixMonths('6 miesięcy'),
  threeMonths('3 miesiące'),
  oneMonth('1 miesiąc');

  const DateFilterPeriod(this.label);
  final String label;
}