import 'package:flutter/material.dart';

import 'components/cross_calendar_alert.dart';
import 'utility/functions.dart';

///
class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key, required this.years, required this.data});

  final List<String> years;

  final Map<String, Map<String, String>> data;

  @override
  Widget build(BuildContext context) {
    final Size screen = MediaQuery.of(context).size;
    final num dialogWidth = (screen.width * 0.95).clamp(320, 1200);
    final num dialogHeight = (screen.height * 0.85).clamp(420, 900);

    final List<String> monthDays = generateFullMonthDays();

    final List<double> rowHeights = List<double>.generate(years.length + 1, (int i) => i == 0 ? 48 : 72);
    final List<double> colWidths = List<double>.generate(monthDays.length + 1, (int i) => i == 0 ? 96 : 120);

    return Dialog(
      insetPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 24),
      child: SizedBox(
        width: dialogWidth.toDouble(),
        height: dialogHeight.toDouble(),
        child: Column(
          children: <Widget>[
            Container(
              height: 56,
              padding: const EdgeInsets.symmetric(horizontal: 16),
              alignment: Alignment.centerLeft,
              decoration: const BoxDecoration(
                border: Border(bottom: BorderSide(color: Color(0xFFE0E0E0))),
              ),
              child: Row(
                children: <Widget>[
                  const Expanded(
                    child: Text('クロステーブル（ダイアログ内）', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                  ),
                  IconButton(
                    tooltip: '閉じる',
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(context).maybePop(),
                  ),
                ],
              ),
            ),

            Expanded(
              child: CrossCalendar(
                years: years,
                monthDays: monthDays,
                headerHeight: rowHeights[0],
                leftColWidth: colWidths[0],
                rowHeights: rowHeights,
                colWidths: colWidths,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
