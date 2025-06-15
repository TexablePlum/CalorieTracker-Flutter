import 'package:flutter/material.dart';

/// Model pomiaru masy ciała
class WeightMeasurement {
  final String id;
  final String userId;
  final DateTime measurementDate;
  final double weightKg;
  final double? bmi;
  final double? weightChangeKg;
  final double? progressToGoal;
  final DateTime createdAt;
  final DateTime updatedAt;

  WeightMeasurement({
    required this.id,
    required this.userId,
    required this.measurementDate,
    required this.weightKg,
    this.bmi,
    this.weightChangeKg,
    this.progressToGoal,
    required this.createdAt,
    required this.updatedAt,
  });

  factory WeightMeasurement.fromJson(Map<String, dynamic> json) {
    return WeightMeasurement(
      id: json['id'] ?? '',
      userId: json['userId'] ?? '',
      measurementDate: DateTime.tryParse(json['measurementDate'] ?? '') ?? DateTime.now(),
      weightKg: (json['weightKg'] ?? 0.0).toDouble(),
      bmi: json['bmi']?.toDouble(),
      weightChangeKg: json['weightChangeKg']?.toDouble(),
      progressToGoal: json['progressToGoal']?.toDouble(),
      createdAt: DateTime.tryParse(json['createdAt'] ?? '') ?? DateTime.now(),
      updatedAt: DateTime.tryParse(json['updatedAt'] ?? '') ?? DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'userId': userId,
      'measurementDate': measurementDate.toIso8601String(),
      'weightKg': weightKg,
      'bmi': bmi,
      'weightChangeKg': weightChangeKg,
      'progressToGoal': progressToGoal,
      'createdAt': createdAt.toIso8601String(),
      'updatedAt': updatedAt.toIso8601String(),
    };
  }

  /// Formatuje wagę do wyświetlenia (np. 75.5 kg)
  String get formattedWeight {
    return '${weightKg.toStringAsFixed(1)} kg';
  }

  /// Formatuje BMI do wyświetlenia (np. 24.2)
  String get formattedBmi {
    if (bmi == null) return 'Brak danych';
    return bmi!.toStringAsFixed(1);
  }

  /// Formatuje zmianę wagi (np. +1.2 kg, -0.5 kg)
  String get formattedWeightChange {
    if (weightChangeKg == null) return 'Brak danych';
    final change = weightChangeKg!;
    final sign = change >= 0 ? '+' : '';
    return '$sign${change.toStringAsFixed(1)} kg';
  }

  /// Formatuje datę pomiaru do wyświetlenia (np. 15 sty 2024)
  String get formattedDate {
    const months = [
      'sty', 'lut', 'mar', 'kwi', 'maj', 'cze',
      'lip', 'sie', 'wrz', 'paź', 'lis', 'gru'
    ];
    
    return '${measurementDate.day} ${months[measurementDate.month - 1]} ${measurementDate.year}';
  }

  /// Zwraca kolor dla zmiany wagi (czerwony dla wzrostu, zielony dla spadku, szary dla braku zmiany)
  Color get weightChangeColor {
    if (weightChangeKg == null) return Colors.grey;
    if (weightChangeKg! > 0) return Colors.red;
    if (weightChangeKg! < 0) return Colors.green;
    return Colors.grey;
  }

  /// Sprawdza czy to dzisiejszy pomiar
  bool get isToday {
    final now = DateTime.now();
    return measurementDate.year == now.year &&
           measurementDate.month == now.month &&
           measurementDate.day == now.day;
  }
}

/// Response dla listy pomiarów
class WeightMeasurementsResponse {
  final List<WeightMeasurement> measurements;
  final int totalCount;
  final bool hasMore;

  WeightMeasurementsResponse({
    required this.measurements,
    required this.totalCount,
    required this.hasMore,
  });

  factory WeightMeasurementsResponse.fromJson(Map<String, dynamic> json) {
    return WeightMeasurementsResponse(
      measurements: (json['measurements'] as List<dynamic>? ?? [])
          .map((m) => WeightMeasurement.fromJson(m))
          .toList(),
      totalCount: json['totalCount'] ?? 0,
      hasMore: json['hasMore'] ?? false,
    );
  }
}

/// Request do tworzenia nowego pomiaru
class CreateWeightMeasurementRequest {
  final DateTime measurementDate;
  final double weightKg;

  CreateWeightMeasurementRequest({
    required this.measurementDate,
    required this.weightKg,
  });

  Map<String, dynamic> toJson() {
    return {
      'measurementDate': measurementDate.toIso8601String().split('T')[0], // Tylko data bez czasu
      'weightKg': weightKg,
    };
  }
}

/// Request do aktualizacji pomiaru
class UpdateWeightMeasurementRequest {
  final DateTime measurementDate;
  final double weightKg;

  UpdateWeightMeasurementRequest({
    required this.measurementDate,
    required this.weightKg,
  });

  Map<String, dynamic> toJson() {
    return {
      'measurementDate': measurementDate.toIso8601String().split('T')[0], // Tylko data bez czasu
      'weightKg': weightKg,
    };
  }
}