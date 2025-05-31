import 'package:flutter/material.dart';
import 'package:table_calendar/table_calendar.dart';
import 'package:percent_indicator/circular_percent_indicator.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  DateTime _focusedDay = DateTime.now();
  DateTime? _selectedDay;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SingleChildScrollView(
        padding: const EdgeInsets.symmetric(vertical: 50, horizontal: 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TableCalendar(
              firstDay: DateTime.utc(2010, 10, 16),
              lastDay: DateTime.utc(2030, 3, 14),
              focusedDay: _focusedDay,
              calendarFormat: CalendarFormat.week,
              headerStyle: const HeaderStyle(formatButtonVisible: false),
              selectedDayPredicate: (day) => isSameDay(_selectedDay, day),
              onDaySelected: (selectedDay, focusedDay) {
                if (!isSameDay(_selectedDay, selectedDay)) {
                  setState(() {
                    _selectedDay = selectedDay;
                    _focusedDay = focusedDay;
                  });
                }
              },
              onPageChanged: (focusedDay) {
                _focusedDay = focusedDay;
              },
            ),
            const SizedBox(height: 20),

            // Nutrition summary card
            Container(
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: const Color(0xFFA393F8),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.2), blurRadius: 8, offset: const Offset(0, 4))],
              ),
              width: double.infinity,
              height: 200,
              child: Row(
                children: [
                  Expanded(
                    flex: 2,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text('Hej imię!', style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 16),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Kalorie', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text('1500/2000'),
                              ],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [Text('Węgle', style: TextStyle(fontWeight: FontWeight.bold)), Text('170/250')],
                            ),
                          ],
                        ),
                        SizedBox(height: 12),
                        const Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [Text('Białko', style: TextStyle(fontWeight: FontWeight.bold)), Text('75/100')],
                            ),
                            Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('Tłuszcze', style: TextStyle(fontWeight: FontWeight.bold)),
                                Text('52/67'),
                              ],
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 20),
                  CircularPercentIndicator(
                    radius: 50.0,
                    lineWidth: 10.0,
                    percent: 1500 / 2000,
                    backgroundColor: Colors.white30,
                    progressColor: Colors.white,
                    center: const Text("1500/2000", style: TextStyle(color: Colors.white)),
                    circularStrokeCap: CircularStrokeCap.round,
                  ),
                ],
              ),
            ),

            const SizedBox(height: 20),

            // Meal cards
            Wrap(
              spacing: 16,
              runSpacing: 16,
              children: [
                mealCard("Śniadanie", 500, 100, 25, 16),
                mealCard("Obiad", 750, 50, 25, 6.7),
                mealCard("Kolacja", 250, 20, 25, 29.3),
                mealCard("Przekąska", 0, 0, 0, 0),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget mealCard(String title, double kalorie, double wegle, double bialko, double tluszcze) {
    double maxKal = 800;
    double maxWegle = 150;
    double maxBialko = 30;
    double maxTluszcz = 30;

    Widget nutrientRow(String label, double value, double max) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(fontWeight: FontWeight.bold)),
          Text(value.toString()),
          SizedBox(
            width: 50,
            child: LinearProgressIndicator(
              value: max == 0 ? 0 : (value / max).clamp(0, 1),
              backgroundColor: Colors.grey[300],
              valueColor: const AlwaysStoppedAnimation<Color>(Color(0xFFA393F8)),
              minHeight: 5,
            ),
          ),
        ],
      );
    }

    return Container(
      width: 170,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.05), blurRadius: 8, offset: const Offset(0, 4))],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Icon(Icons.add_circle, color: Color(0xFFA393F8)),
          const SizedBox(height: 8),
          Text(title, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [nutrientRow("Kalorie", kalorie, maxKal), nutrientRow("Węgle", wegle, maxWegle)],
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [nutrientRow("Białko", bialko, maxBialko), nutrientRow("Tłuszcze", tluszcze, maxTluszcz)],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 20),
            decoration: BoxDecoration(color: const Color(0xFFA393F8), borderRadius: BorderRadius.circular(20)),
            child: const Text("ROZWIŃ", style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }
}
