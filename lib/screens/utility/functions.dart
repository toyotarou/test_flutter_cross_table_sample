///
List<String> generateFullMonthDays() {
  final DateTime base = DateTime(2024);

  final DateTime end = DateTime(2024, 12, 31);

  final List<String> out = <String>[];

  for (DateTime d = base; !d.isAfter(end); d = d.add(const Duration(days: 1))) {
    out.add('${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}');
  }

  return out;
}
