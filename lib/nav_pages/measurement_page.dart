import 'package:calorie_tracker_flutter_front/dialogs/add_measurement_dialog.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:dio/dio.dart';
import 'package:fl_chart/fl_chart.dart';
import '../services/weight_measurement_service.dart';
import '../models/weight_measurement.dart';

class MeasurementPage extends StatefulWidget {
  @override
  State<MeasurementPage> createState() => _MeasurementPageState();
}

class _MeasurementPageState extends State<MeasurementPage> {
  late WeightMeasurementService _weightService;
  
  DateFilterPeriod _selectedPeriod = DateFilterPeriod.all;
  ChartType _selectedChartType = ChartType.weight;
  bool _isLoading = true;
  String? _error;
  List<WeightMeasurement> _allMeasurements = [];
  List<WeightMeasurement> _filteredMeasurements = [];
  
  @override
  void initState() {
    super.initState();
    _weightService = WeightMeasurementService(context.read<Dio>());
    _loadAllData();
  }

  /// Ładuje wszystkie pomiary raz i cacheuje je
  Future<void> _loadAllData() async {
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final allMeasurements = await _weightService.getAllWeightMeasurements();
      
      if (mounted) {
        setState(() {
          _allMeasurements = allMeasurements;
          _isLoading = false;
        });
        
        _applyFilter();
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Błąd ładowania pomiarów';
          _isLoading = false;
        });
      }
    }
  }

  /// Aplikuje filtr lokalnie na cacheowanych danych
  void _applyFilter() {
    DateTime? startDate;
    final endDate = DateTime.now();

    switch (_selectedPeriod) {
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

    setState(() {
      _filteredMeasurements = _allMeasurements.where((measurement) {
        if (startDate != null && measurement.measurementDate.isBefore(startDate)) {
          return false;
        }
        if (measurement.measurementDate.isAfter(endDate)) {
          return false;
        }
        return true;
      }).toList();
    });
  }

  /// Zmienia filtr bez przeładowania danych
  void _onPeriodChanged(DateFilterPeriod period) {
    setState(() {
      _selectedPeriod = period;
    });
    _applyFilter();
  }

  /// Przygotowuje dane do wykresu
  List<FlSpot> _prepareChartData() {
    if (_filteredMeasurements.isEmpty) return [];
    
    final sortedMeasurements = List<WeightMeasurement>.from(_filteredMeasurements)
      ..sort((a, b) => a.measurementDate.compareTo(b.measurementDate));
    
    // Dla pojedynczego punktu umieszcza go na środku
    if (sortedMeasurements.length == 1) {
      final measurement = sortedMeasurements.first;
      final value = _selectedChartType == ChartType.weight 
          ? measurement.weightKg 
          : measurement.bmi ?? 0.0;
      
      return [FlSpot(0.5, value)]; // Środek wykresu
    }
    
    return sortedMeasurements.asMap().entries.map((entry) {
      final index = entry.key.toDouble();
      final measurement = entry.value;
      
      final value = _selectedChartType == ChartType.weight 
          ? measurement.weightKg 
          : measurement.bmi ?? 0.0;
      
      return FlSpot(index, value);
    }).toList();
  }

  /// Zwraca kolor linii wykresu na podstawie trendu
  Color _getChartLineColor() {
    if (_filteredMeasurements.length < 2) return const Color(0xFFA69DF5);
    
    final first = _filteredMeasurements.last; // Najstarszy
    final last = _filteredMeasurements.first; // Najnowszy
    
    final value1 = _selectedChartType == ChartType.weight ? first.weightKg : (first.bmi ?? 0.0);
    final value2 = _selectedChartType == ChartType.weight ? last.weightKg : (last.bmi ?? 0.0);
    
    if (value2 > value1) return Colors.red.shade400;    // Wzrost
    if (value2 < value1) return Colors.green.shade400;  // Spadek
    return const Color(0xFFA69DF5);                     // Bez zmian
  }

  /// Formatuje etykiety osi X (daty)
  String _formatXAxisLabel(double value) {
    final index = value.toInt();
    if (index < 0 || index >= _filteredMeasurements.length) return '';
    
    final sortedMeasurements = List<WeightMeasurement>.from(_filteredMeasurements)
      ..sort((a, b) => a.measurementDate.compareTo(b.measurementDate));
    
    final measurement = sortedMeasurements[index];
    final date = measurement.measurementDate;
    
    // Format zależny od okresu
    switch (_selectedPeriod) {
      case DateFilterPeriod.oneMonth:
        return '${date.day}';
      case DateFilterPeriod.threeMonths:
      case DateFilterPeriod.sixMonths:
        return '${date.day}/${date.month}';
      default:
        return '${date.month}/${date.year.toString().substring(2)}';
    }
  }

  /// Formatuje etykiety osi Y
  String _formatYAxisLabel(double value) {
    if (_selectedChartType == ChartType.weight) {
      return '${value.toInt()}kg';
    } else {
      return value.toStringAsFixed(1);
    }
  }

  /// Oblicza wagę docelową na podstawie najnowszego pomiaru
  double? _calculateTargetWeight() {
    if (_filteredMeasurements.isEmpty) return null;
    
    final latest = _filteredMeasurements.first; // Najnowszy pomiar
    if (latest.progressToGoal == null) return null;
    
    return latest.weightKg - latest.progressToGoal!;
  }

  /// Oblicza przedział osi Y
  (double min, double max) _getYAxisRange() {
    if (_filteredMeasurements.isEmpty) return (0, 100);
    
    final values = _filteredMeasurements.map((m) {
      return _selectedChartType == ChartType.weight ? m.weightKg : (m.bmi ?? 0.0);
    }).toList();
    
    // Dodaj wagę docelową do zakresu (tylko dla wykresu wagi)
    if (_selectedChartType == ChartType.weight) {
      final targetWeight = _calculateTargetWeight();
      if (targetWeight != null) {
        values.add(targetWeight);
      }
    }
    
    final dataMin = values.reduce((a, b) => a < b ? a : b);
    final dataMax = values.reduce((a, b) => a > b ? a : b);
    
    if (dataMin == dataMax) {
      // Jeśli jeden pomiar to centruje go
      final center = dataMin;
      final padding = _selectedChartType == ChartType.weight ? 10.0 : 2.0;
      return (center - padding, center + padding);
    }
    
    // Oblicza interwał
    final range = dataMax - dataMin;
    double interval;
    
    if (_selectedChartType == ChartType.weight) {
      if (range <= 10) interval = 2.0;
      else if (range <= 20) interval = 5.0;
      else if (range <= 50) interval = 10.0;
      else interval = 20.0;
    } else {
      if (range <= 2) interval = 0.5;
      else if (range <= 5) interval = 1.0;
      else if (range <= 10) interval = 2.0;
      else interval = 5.0;
    }
    
    // Rozszerz zakres z marginesem wyrównanym do interwałów
    final minWithMargin = dataMin - interval;
    final maxWithMargin = dataMax + interval;
    
    // Wyrównuje do interwałów osi
    final alignedMin = (minWithMargin / interval).floor() * interval;
    final alignedMax = (maxWithMargin / interval).ceil() * interval;
    
    return (alignedMin, alignedMax);
  }

  /// Przygotowuje dane dla linii celu (tylko dla wykresu wagi)
  List<FlSpot> _prepareGoalLineData() {
    if (_selectedChartType != ChartType.weight) return [];
    
    final targetWeight = _calculateTargetWeight();
    if (targetWeight == null || _filteredMeasurements.length < 2) return [];
    
    // Linia celu przez cały wykres
    return [
      FlSpot(0, targetWeight),
      FlSpot((_filteredMeasurements.length - 1).toDouble(), targetWeight),
    ];
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF8F9FA),
      body: CustomScrollView(
        slivers: [
          _buildHeader(),
          
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                children: [
                  // Wybór typu wykresu
                  _buildChartTypeSelector(),
                  
                  const SizedBox(height: 20),
                  
                  if (_isLoading)
                    _buildLoadingState()
                  else if (_error != null)
                    _buildErrorState()
                  else if (_filteredMeasurements.isEmpty)
                    _buildEmptyState()
                  else ...[
                    // Wykres
                    _buildChartSection(),
                    
                    const SizedBox(height: 16),
                    
                    // Filtry dat
                    _buildDateFilters(),
                    
                    const SizedBox(height: 20),
                    
                    // Header dla statystyk
                    const Align(
                      alignment: Alignment.centerLeft,
                      child: Padding(
                        padding: EdgeInsets.only(left: 4, bottom: 12),
                        child: Text(
                          'Podsumowanie',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black87,
                          ),
                        ),
                      ),
                    ),
                    
                    // Statystyki
                    _buildStatsSection(),
                    
                    const SizedBox(height: 20),
                    
                    // Tabela pomiarów
                    _buildMeasurementsTable(),
                  ],
                  
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _showAddMeasurementDialog,
        backgroundColor: const Color(0xFFA69DF5),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Dodaj pomiar'),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      floatingActionButtonLocation: FloatingActionButtonLocation.centerFloat,
    );
  }

  Widget _buildChartTypeSelector() {
    return Container(
      height: 40,
      decoration: BoxDecoration(
        color: Colors.grey.shade100,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Row(
        children: [
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedChartType = ChartType.weight),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: _selectedChartType == ChartType.weight 
                      ? const Color(0xFFA69DF5) 
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    'Masa ciała',
                    style: TextStyle(
                      color: _selectedChartType == ChartType.weight 
                          ? Colors.white 
                          : Colors.black54,
                      fontWeight: _selectedChartType == ChartType.weight 
                          ? FontWeight.bold 
                          : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Expanded(
            child: GestureDetector(
              onTap: () => setState(() => _selectedChartType = ChartType.bmi),
              child: Container(
                margin: const EdgeInsets.all(2),
                decoration: BoxDecoration(
                  color: _selectedChartType == ChartType.bmi 
                      ? const Color(0xFFA69DF5) 
                      : Colors.transparent,
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Center(
                  child: Text(
                    'BMI',
                    style: TextStyle(
                      color: _selectedChartType == ChartType.bmi 
                          ? Colors.white 
                          : Colors.black54,
                      fontWeight: _selectedChartType == ChartType.bmi 
                          ? FontWeight.bold 
                          : FontWeight.w500,
                      fontSize: 14,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildChartSection() {
    final chartTitle = _selectedChartType == ChartType.weight 
        ? 'Wykres masy ciała' 
        : 'Wykres BMI';
    
    final chartData = _prepareChartData();
    final (minY, maxY) = _getYAxisRange();
    final lineColor = _getChartLineColor();
    
    return Container(
      height: 300,
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                chartTitle,
                style: const TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: Colors.black87,
                ),
              ),
              // Ikona trendu
              if (_filteredMeasurements.length >= 2)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: lineColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        lineColor == Colors.red.shade400 
                            ? Icons.trending_up 
                            : lineColor == Colors.green.shade400 
                                ? Icons.trending_down 
                                : Icons.trending_flat,
                        color: lineColor,
                        size: 16,
                      ),
                      const SizedBox(width: 4),
                      Text(
                        lineColor == Colors.red.shade400 
                            ? 'Wzrost' 
                            : lineColor == Colors.green.shade400 
                                ? 'Spadek' 
                                : 'Stabilnie',
                        style: TextStyle(
                          color: lineColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          // Legenda dla linii celu
          if (_selectedChartType == ChartType.weight && _calculateTargetWeight() != null)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Container(
                    width: 16,
                    height: 2,
                    decoration: BoxDecoration(
                      color: Colors.orange.withOpacity(0.8),
                      borderRadius: BorderRadius.circular(1),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'Cel: ${_calculateTargetWeight()!.toStringAsFixed(1)} kg',
                    style: const TextStyle(
                      fontSize: 12,
                      color: Colors.orange,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
              ),
            ),
          const SizedBox(height: 20),
          // informacja dla pojedynczego pomiaru
          if (_filteredMeasurements.length == 1)
            Container(
              padding: const EdgeInsets.all(12),
              margin: const EdgeInsets.only(bottom: 16),
              decoration: BoxDecoration(
                color: Colors.blue.withOpacity(0.1),
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.blue.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: Colors.blue[700], size: 16),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Dodaj więcej pomiarów aby zobaczyć trend zmian',
                      style: TextStyle(
                        color: Colors.blue[700],
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: chartData.isEmpty 
                ? Center(
                    child: Text(
                      'Brak danych do wyświetlenia',
                      style: TextStyle(
                        color: Colors.grey[600],
                        fontSize: 14,
                      ),
                    ),
                  )
                : LineChart(
                    LineChartData(
                      gridData: FlGridData(
                        show: true,
                        drawVerticalLine: _filteredMeasurements.length > 3,
                        horizontalInterval: _calculateYAxisInterval(),
                        verticalInterval: _filteredMeasurements.length <= 5 ? 1 : null,
                        getDrawingHorizontalLine: (value) {
                          return FlLine(
                            color: Colors.grey.shade200,
                            strokeWidth: 1,
                          );
                        },
                        getDrawingVerticalLine: (value) {
                          return FlLine(
                            color: Colors.grey.shade100,
                            strokeWidth: 0.5,
                          );
                        },
                      ),
                      titlesData: FlTitlesData(
                        show: true,
                        rightTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        topTitles: const AxisTitles(
                          sideTitles: SideTitles(showTitles: false),
                        ),
                        bottomTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: _filteredMeasurements.length > 1,
                            reservedSize: 30,
                            interval: _filteredMeasurements.length == 1 
                                ? 1
                                : chartData.length > 10 
                                    ? chartData.length / 6 
                                    : 1,
                            getTitlesWidget: (value, meta) {
                              // Dla pojedynczego punktu nie pokazuje osi X
                              if (_filteredMeasurements.length == 1) {
                                return const SizedBox.shrink();
                              }
                              
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text(
                                  _formatXAxisLabel(value),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                        leftTitles: AxisTitles(
                          sideTitles: SideTitles(
                            showTitles: true,
                            reservedSize: 45,
                            interval: _calculateYAxisInterval(),
                            getTitlesWidget: (value, meta) {
                              return SideTitleWidget(
                                axisSide: meta.axisSide,
                                child: Text(
                                  _formatYAxisLabel(value),
                                  style: TextStyle(
                                    color: Colors.grey[600],
                                    fontSize: 10,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
                      ),
                      borderData: FlBorderData(
                        show: true,
                        border: Border(
                          bottom: BorderSide(color: Colors.grey.shade300),
                          left: BorderSide(color: Colors.grey.shade300),
                        ),
                      ),
                      minX: 0,
                      maxX: chartData.length > 1 ? chartData.length - 1 : 1,
                      minY: minY,
                      maxY: maxY,
                      lineBarsData: [
                        // Główna linia danych
                        LineChartBarData(
                          spots: chartData,
                          isCurved: _filteredMeasurements.length > 1,
                          curveSmoothness: 0.3,
                          color: _filteredMeasurements.length == 1 ? Colors.transparent : lineColor,
                          barWidth: _filteredMeasurements.length == 1 ? 0 : 3,
                          isStrokeCapRound: true,
                          dotData: FlDotData(
                            show: true,
                            getDotPainter: (spot, percent, barData, index) {
                              final radius = _filteredMeasurements.length == 1 ? 8.0 : 4.0;
                              final strokeWidth = _filteredMeasurements.length == 1 ? 3.0 : 2.0;
                              return FlDotCirclePainter(
                                radius: radius,
                                color: lineColor,
                                strokeWidth: strokeWidth,
                                strokeColor: Colors.white,
                              );
                            },
                          ),
                          belowBarData: BarAreaData(show: false),
                          aboveBarData: BarAreaData(show: false),
                        ),
                        // Linia celu (tylko dla wagi)
                        if (_selectedChartType == ChartType.weight && _prepareGoalLineData().isNotEmpty)
                          LineChartBarData(
                            spots: _prepareGoalLineData(),
                            isCurved: false,
                            color: Colors.orange.withOpacity(0.8),
                            barWidth: 2,
                            isStrokeCapRound: false,
                            dashArray: [5, 5], // Przerywana
                            dotData: const FlDotData(show: false),
                            belowBarData: BarAreaData(show: false),
                            aboveBarData: BarAreaData(show: false),
                          ),
                      ],
                      lineTouchData: LineTouchData(
                        touchTooltipData: LineTouchTooltipData(
                          tooltipBgColor: Colors.black87,
                          tooltipRoundedRadius: 8,
                          getTooltipItems: (touchedSpots) {
                            return touchedSpots.map((touchedSpot) {
                              // Pokazuje tooltip
                              if (touchedSpot.barIndex != 0) return null;
                              
                              // obsługs dla pojedynczego pomiaru
                              if (_filteredMeasurements.length == 1) {
                                final measurement = _filteredMeasurements.first;
                                final value = _selectedChartType == ChartType.weight 
                                    ? '${measurement.weightKg.toStringAsFixed(1)} kg'
                                    : '${measurement.bmi?.toStringAsFixed(1) ?? 'N/A'}';
                                
                                return LineTooltipItem(
                                  '${measurement.formattedDate}\n$value',
                                  const TextStyle(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 12,
                                  ),
                                );
                              }
                              
                              final index = touchedSpot.x.toInt();
                              if (index < 0 || index >= _filteredMeasurements.length) {
                                return null;
                              }
                              
                              final sortedMeasurements = List<WeightMeasurement>.from(_filteredMeasurements)
                                ..sort((a, b) => a.measurementDate.compareTo(b.measurementDate));
                              
                              final measurement = sortedMeasurements[index];
                              final value = _selectedChartType == ChartType.weight 
                                  ? '${measurement.weightKg.toStringAsFixed(1)} kg'
                                  : '${measurement.bmi?.toStringAsFixed(1) ?? 'N/A'}';
                              
                              return LineTooltipItem(
                                '${measurement.formattedDate}\n$value',
                                const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              );
                            }).toList();
                          },
                        ),
                        handleBuiltInTouches: true,
                        getTouchLineStart: (data, index) => 0,
                        getTouchLineEnd: (data, index) => double.infinity,
                        touchSpotThreshold: 10,
                        getTouchedSpotIndicator: (LineChartBarData barData, List<int> spotIndexes) {
                          return spotIndexes.map((spotIndex) {
                            // Sprawdza czy to linia celu
                            final isGoalLine = barData.color == Colors.orange.withOpacity(0.8);
                            
                            if (isGoalLine) {
                              // Ukrywa wskaźniki dla linii celu
                              return TouchedSpotIndicatorData(
                                FlLine(color: Colors.transparent, strokeWidth: 0),
                                FlDotData(show: false),
                              );
                            } else {
                              // Pokazuje wskaźniki dla głównej linii
                              return TouchedSpotIndicatorData(
                                FlLine(color: Colors.grey.withOpacity(0.8), strokeWidth: 1),
                                FlDotData(show: true),
                              );
                            }
                          }).toList();
                        },
                      ),
                    ),
                    duration: Duration.zero,
                  ),
          ),
        ],
      ),
    );
  }

  /// Oblicza odpowiedni interwał dla osi Y aby uniknąć duplikatów
  double _calculateYAxisInterval() {
    if (_filteredMeasurements.isEmpty) return 1.0;
    
    final (minY, maxY) = _getYAxisRange();
    final range = maxY - minY;
    
    if (_selectedChartType == ChartType.weight) {
      // dostosowuje interwał w zależności od zakresu dla wagi
      if (range <= 10) return 2.0;
      if (range <= 20) return 5.0;
      if (range <= 50) return 10.0;
      return 20.0;
    } else {
      // precyzyjne interwały dla BMI
      if (range <= 2) return 0.5;
      if (range <= 5) return 1.0;
      if (range <= 10) return 2.0;
      return 5.0;
    }
  }

  Widget _buildDateFilters() {
    return Column(
      children: [
        // Pierwszy rząd
        Row(
          children: [
            Expanded(child: _buildFilterChip(DateFilterPeriod.all)),
            const SizedBox(width: 8),
            Expanded(child: _buildFilterChip(DateFilterPeriod.oneYear)),
          ],
        ),
        const SizedBox(height: 8),
        // Drugi rząd
        Row(
          children: [
            Expanded(child: _buildFilterChip(DateFilterPeriod.sixMonths)),
            const SizedBox(width: 8),
            Expanded(child: _buildFilterChip(DateFilterPeriod.threeMonths)),
            const SizedBox(width: 8),
            Expanded(child: _buildFilterChip(DateFilterPeriod.oneMonth)),
          ],
        ),
      ],
    );
  }

  Widget _buildFilterChip(DateFilterPeriod period) {
    final isSelected = period == _selectedPeriod;
    
    return GestureDetector(
      onTap: () => _onPeriodChanged(period),
      child: Container(
        height: 44,
        decoration: BoxDecoration(
          color: isSelected 
              ? const Color(0xFFA69DF5) 
              : Colors.white,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected 
                ? const Color(0xFFA69DF5) 
                : Colors.grey.shade200,
            width: 1.5,
          ),
          boxShadow: isSelected ? [
            BoxShadow(
              color: const Color(0xFFA69DF5).withOpacity(0.25),
              blurRadius: 8,
              offset: const Offset(0, 4),
            ),
          ] : [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Center(
          child: Text(
            period.label,
            style: TextStyle(
              color: isSelected ? Colors.white : Colors.black87,
              fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
              fontSize: 13,
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingState() {
    return Container(
      height: 200,
      child: const Center(
        child: CircularProgressIndicator(
          color: Color(0xFFA69DF5),
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Container(
      height: 200,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: Colors.red.shade400,
            ),
            const SizedBox(height: 16),
            Text(
              _error!,
              style: TextStyle(
                fontSize: 16,
                color: Colors.red.shade600,
              ),
            ),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: _loadAllData,
              child: const Text('Spróbuj ponownie'),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Container(
      height: 300,
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFA69DF5).withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: const Icon(
                Icons.scale_outlined,
                size: 64,
                color: Color(0xFFA69DF5),
              ),
            ),
            const SizedBox(height: 24),
            const Text(
              'Brak pomiarów',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'Dodaj swój pierwszy pomiar masy ciała\naby śledzić postępy',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 16,
                color: Colors.grey[600],
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatsSection() {
    if (_filteredMeasurements.isEmpty) return const SizedBox();
    
    final latest = _filteredMeasurements.first;
    final oldest = _filteredMeasurements.last;
    final totalChange = latest.weightKg - oldest.weightKg;
    
    return Column(
      children: [
        // Pierwszy rząd (waga i zmiana)
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'Aktualna waga',
                latest.formattedWeight,
                Icons.monitor_weight,
                const Color(0xFFA69DF5),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Zmiana ogółem',
                '${totalChange >= 0 ? '+' : ''}${totalChange.toStringAsFixed(1)} kg',
                totalChange >= 0 ? Icons.trending_up : Icons.trending_down,
                totalChange >= 0 ? Colors.red : Colors.green,
              ),
            ),
          ],
        ),
        
        const SizedBox(height: 12),
        
        // Drugi rząd (BMI i ile zostało do celu)
        Row(
          children: [
            Expanded(
              child: _buildStatCard(
                'BMI',
                latest.formattedBmi,
                Icons.calculate,
                _getBmiColor(latest.bmi),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: _buildStatCard(
                'Do celu zostało',
                _formatProgressToGoal(latest.progressToGoal),
                Icons.flag,
                _getProgressColor(latest.progressToGoal),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Color _getBmiColor(double? bmi) {
    if (bmi == null) return Colors.grey;
    
    if (bmi < 18.5) return Colors.blue;      // Niedowaga
    if (bmi < 25.0) return Colors.green;     // Prawidłowa
    if (bmi < 30.0) return Colors.orange;    // Nadwaga
    return Colors.red;                       // Otyłość
  }

  Color _getProgressColor(double? progress) {
    return Colors.blue;
  }

  String _formatProgressToGoal(double? progress) {
    if (progress == null) return 'Brak celu';
    
    if (progress.abs() < 0.1) return 'Osiągnięty';
    
    final formatted = progress.abs().toStringAsFixed(1);
    if (progress > 0) {
      return '-${formatted} kg';
    } else {
      return '+${formatted} kg';
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 24),
          const SizedBox(height: 8),
          Text(
            title,
            style: TextStyle(
              fontSize: 12,
              color: Colors.grey[600],
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMeasurementsTable() {
    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.06),
            blurRadius: 8,
            offset: const Offset(0, 3),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Padding(
            padding: EdgeInsets.all(20),
            child: Text(
              'Historia pomiarów',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: Colors.black87,
              ),
            ),
          ),
          // Header tabeli
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey.shade50,
              border: Border(
                top: BorderSide(color: Colors.grey.shade200),
                bottom: BorderSide(color: Colors.grey.shade200),
              ),
            ),
            child: const Row(
              children: [
                Expanded(
                  flex: 3,
                  child: Text(
                    'Data',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Pomiar (kg)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                Expanded(
                  flex: 2,
                  child: Text(
                    'Zmiana (kg)',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
                SizedBox(
                  width: 60,
                  child: Text(
                    'Akcje',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: Colors.black87,
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Wiersze tabeli
          ...List.generate(_filteredMeasurements.length, (index) {
            final measurement = _filteredMeasurements[index];
            return Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                    color: index == _filteredMeasurements.length - 1 
                        ? Colors.transparent 
                        : Colors.grey.shade200,
                    width: 1,
                  ),
                ),
              ),
              child: Row(
                children: [
                  Expanded(
                    flex: 3,
                    child: Text(
                      measurement.formattedDate,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        color: Colors.black87,
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      measurement.formattedWeight,
                      textAlign: TextAlign.center,
                      style: const TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFFA69DF5),
                      ),
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: Text(
                      measurement.formattedWeightChange,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                        color: measurement.weightChangeColor,
                      ),
                    ),
                  ),
                  // kolumna akcji
                  SizedBox(
                    width: 60,
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _showAddMeasurementDialog(measurement),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.edit,
                                size: 16,
                                color: Colors.blue.shade600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 4),
                        Material(
                          color: Colors.transparent,
                          child: InkWell(
                            onTap: () => _deleteMeasurement(measurement),
                            borderRadius: BorderRadius.circular(16),
                            child: Container(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                Icons.delete,
                                size: 16,
                                color: Colors.red.shade600,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  /// Pokazuje dialog do dodawania nowego pomiaru
  Future<void> _showAddMeasurementDialog([WeightMeasurement? existingMeasurement]) async {
    await AddMeasurementDialog.show(
      context,
      weightService: _weightService,
      allMeasurements: _allMeasurements,
      onSuccess: _loadAllData,
      existingMeasurement: existingMeasurement,
    );
  }

  /// Usuwa pomiar po potwierdzeniu
  Future<void> _deleteMeasurement(WeightMeasurement measurement) async {
    final shouldDelete = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Usuń pomiar'),
        content: Text('Czy na pewno chcesz usunąć pomiar z dnia ${measurement.formattedDate}? (${measurement.formattedWeight})'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Anuluj'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            child: const Text('Usuń', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (shouldDelete == true) {
      try {
        await _weightService.deleteWeightMeasurement(measurement.id);
        
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Pomiar został usunięty'),
            backgroundColor: Color(0xFFA69DF5),
            behavior: SnackBarBehavior.floating,
          ),
        );
        
        _loadAllData(); // Odświeża dane
      } catch (e) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Błąd podczas usuwania pomiaru'),
            backgroundColor: Colors.red,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Widget _buildHeader() {
    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      snap: false,
      stretch: true,
      backgroundColor: Colors.transparent,
      elevation: 0,
      collapsedHeight: 100,
      automaticallyImplyLeading: false,
      flexibleSpace: LayoutBuilder(
        builder: (context, constraints) {
          final isCollapsed = constraints.maxHeight <= 100 + MediaQuery.of(context).padding.top;
          
          return Container(
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFA69DF5),
                  Color(0xFF8B7CF6),
                  Color(0xFF7C3AED),
                ],
              ),
              borderRadius: const BorderRadius.only(
                bottomLeft: Radius.circular(24),
                bottomRight: Radius.circular(24),
              ),
              boxShadow: [
                BoxShadow(
                  color: const Color(0xFFA69DF5).withOpacity(0.3),
                  spreadRadius: 0,
                  blurRadius: 15,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: FlexibleSpaceBar(
              centerTitle: false,
              titlePadding: EdgeInsets.zero,
              title: isCollapsed 
                ? Container(
                    height: 100,
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    child: const Center(
                      child: Text(
                        'Pomiary',
                        style: TextStyle(
                          color: Colors.white,
                          fontSize: 20,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  )
                : null,
              background: SafeArea(
                child: AnimatedOpacity(
                  opacity: isCollapsed ? 0.0 : 1.0,
                  duration: const Duration(milliseconds: 200),
                  child: const Padding(
                    padding: EdgeInsets.fromLTRB(20, 20, 20, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Pomiary 📊',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 28,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        SizedBox(height: 4),
                        Text(
                          'Śledź swoje postępy',
                          style: TextStyle(
                            color: Colors.white70,
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

/// Enum dla typu wykresu
enum ChartType {
  weight('Masa ciała'),
  bmi('BMI');

  const ChartType(this.label);
  final String label;
}