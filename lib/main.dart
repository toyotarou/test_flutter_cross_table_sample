import 'package:flutter/material.dart';
import 'screens/home_screen.dart';

void main() => runApp(const MyApp());

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Cross Calendar in Dialog',
      theme: ThemeData(useMaterial3: false),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatelessWidget {
  const HomePage({super.key});

  ///
  @override
  Widget build(BuildContext context) {
    final List<String> years = _generateYearsSpan(10);

    final List<String> monthDays = _generateFullMonthDays();

    final Map<String, Map<String, String>> data = _generateDemoData(years, monthDays);

    return Scaffold(
      appBar: AppBar(title: const Text('Home')),
      body: Center(
        child: ElevatedButton.icon(
          icon: const Icon(Icons.table_view),
          label: const Text('カレンダーを開く（10年分＆ダミー多め）'),
          onPressed: () => _openCalendarDialog(context, years, data),
        ),
      ),
    );
  }

  ///
  Future<void> _openCalendarDialog(
    BuildContext context,
    List<String> years,
    Map<String, Map<String, String>> data,
  ) async {
    await showDialog<void>(
      context: context,
      builder: (_) => HomeScreen(years: years, data: data),
    );
  }
}

///
List<String> _generateYearsSpan(int spanYears) {
  final int now = DateTime.now().year;

  final int start = now - (spanYears ~/ 2);

  return List<String>.generate(spanYears, (int i) => (start + i).toString());
}

///
List<String> _generateFullMonthDays() {
  final DateTime base = DateTime(2024);

  final DateTime end = DateTime(2024, 12, 31);

  final List<String> out = <String>[];

  for (DateTime d = base; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
    out.add('${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
  }

  return out;
}

///
Map<String, Map<String, String>> _generateDemoData(List<String> years, List<String> monthDays) {
  final DateTime now = DateTime.now();

  final String todayMd = '${now.month.toString().padLeft(2, '0')}-${now.day.toString().padLeft(2, '0')}';

  int lastDayOfMonth(int year, int month) {
    final DateTime nextMonth = month == 12 ? DateTime(year + 1) : DateTime(year, month + 1);

    return nextMonth.subtract(const Duration(days: 1)).day;
  }

  const List<String> tags = <String>['会議', '出張', '休暇', '締切', 'リリース', 'レビュー', 'MTG', 'メモ'];

  final Map<String, Map<String, String>> map = <String, Map<String, String>>{};

  for (final String yStr in years) {
    final int y = int.parse(yStr);

    final Map<String, String> ym = <String, String>{};

    for (int m = 1; m <= 12; m++) {
      final String mm = m.toString().padLeft(2, '0');

      final String last = lastDayOfMonth(y, m).toString().padLeft(2, '0');

      ym['$mm-01'] = '$y年$m月1日（始）';

      ym['$mm-15'] = '$y年$m月15日（中間）';

      ym['$mm-$last'] = '$y年$m月$last日（締）';

      final int baseSeed = (y * 37 + m * 101) % 10000;

      final int addCount = 3 + (baseSeed % 3);

      final int dayCursor = 2 + (baseSeed % 5);

      for (int k = 0; k < addCount; k++) {
        final String tag = tags[(baseSeed + k * 7) % tags.length];

        final int d = ((dayCursor + k * 5) % lastDayOfMonth(y, m)).clamp(1, lastDayOfMonth(y, m));

        final String dd = d.toString().padLeft(2, '0');

        final String md = '$mm-$dd';

        ym[md] = '$y年$m月$d日（$tag）';
      }
    }

    if (y == now.year) {
      ym[todayMd] = '$y年${now.month}月${now.day}日（今日）';
    }

    ym['10-23'] = '$y年10月23日（記念日）';

    map[yStr] = ym;
  }

  return map;
}
