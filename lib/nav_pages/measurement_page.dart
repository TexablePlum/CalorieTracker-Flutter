import 'package:flutter/material.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:intl/intl.dart';
import 'dart:math';

void main() {
  runApp(const MaterialApp(home: MeasurementsScreen(), debugShowCheckedModeBanner: false));
}

class MeasurementsScreen extends StatefulWidget {
  const MeasurementsScreen({super.key});

  @override
  State<MeasurementsScreen> createState() => _MeasurementsScreenState();
}

class _MeasurementsScreenState extends State<MeasurementsScreen> {
  final Color violet = const Color(0xFFB9A9F2);
  final TextEditingController weightController = TextEditingController();
  final FocusNode _focusNode = FocusNode();
  DateTime selectedDate = DateTime.now();

  // Lista pomiarów: (data, waga)
  List<MapEntry<DateTime, double>> measurements = [];

  // Konwersja na dane wykresu
  List<FlSpot> get chartData {
    if (measurements.isEmpty) return [];
    final DateTime start = measurements.first.key;
    return measurements.map((entry) {
      final daysSinceStart = entry.key.difference(start).inDays.toDouble();
      return FlSpot(daysSinceStart, entry.value);
    }).toList();
  }

  // Formatowanie osi X
  Widget bottomTitleWidgets(double value, TitleMeta meta) {
    if (measurements.isEmpty) return const Text('');
    final DateTime start = measurements.first.key;
    final DateTime date = start.add(Duration(days: value.toInt()));
    return SideTitleWidget(
      axisSide: meta.axisSide,
      child: Text(DateFormat('d.M').format(date), style: const TextStyle(fontSize: 10)),
    );
  }

  void _addMeasurement() {
    final weight = double.tryParse(weightController.text.replaceAll(",", "."));
    if (weight == null) return;

    setState(() {
      measurements.add(MapEntry(selectedDate, weight));
      measurements.sort((a, b) => a.key.compareTo(b.key));
      weightController.clear();
    });

    FocusScope.of(context).unfocus(); // zamknij klawiaturę
  }

  Future<void> _pickDate() async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime(2030),
    );
    if (picked != null) {
      setState(() => selectedDate = picked);
    }
  }

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(), // tap poza polem zamyka klawiaturę
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: violet,
          title: const Text('Pomiary ciała', style: TextStyle(color: Colors.black)),
          centerTitle: true,
        ),
        body: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              // Data
              GestureDetector(
                onTap: _pickDate,
                child: Container(
                  padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  decoration: BoxDecoration(color: violet, borderRadius: BorderRadius.circular(12)),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      const Text("Data:", style: TextStyle(color: Colors.white)),
                      Text(DateFormat('yyyy-MM-dd').format(selectedDate), style: const TextStyle(color: Colors.white)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Masa ciała
              TextField(
                controller: weightController,
                focusNode: _focusNode,
                keyboardType: TextInputType.number,
                textInputAction: TextInputAction.done,
                onSubmitted: (_) => FocusScope.of(context).unfocus(),
                decoration: InputDecoration(
                  labelText: "Masa ciała (kg)",
                  labelStyle: const TextStyle(color: Colors.black),
                  filled: true,
                  fillColor: Colors.white,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                ),
              ),
              const SizedBox(height: 16),

              // Przycisk Dodaj
              ElevatedButton(
                onPressed: _addMeasurement,
                style: ElevatedButton.styleFrom(
                  backgroundColor: violet,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                child: const Text("Dodaj", style: TextStyle(fontSize: 16)),
              ),
              const SizedBox(height: 20),

              // Wykres
              SizedBox(
                height: 200,
                child: LineChart(
                  LineChartData(
                    minX: chartData.isNotEmpty ? chartData.first.x : 0,
                    maxX: chartData.isNotEmpty ? chartData.last.x : 1,
                    lineBarsData: [
                      LineChartBarData(
                        spots: chartData,
                        isCurved: true,
                        barWidth: 3,
                        color: violet,
                        dotData: FlDotData(show: true),
                      ),
                    ],
                    titlesData: FlTitlesData(
                      bottomTitles: AxisTitles(
                        sideTitles: SideTitles(
                          showTitles: true,
                          reservedSize: 30,
                          interval: 1,
                          getTitlesWidget: bottomTitleWidgets,
                        ),
                      ),
                      leftTitles: AxisTitles(sideTitles: SideTitles(showTitles: true, reservedSize: 35)),
                      topTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                      rightTitles: AxisTitles(sideTitles: SideTitles(showTitles: false)),
                    ),
                    borderData: FlBorderData(show: true),
                    gridData: FlGridData(show: true),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
