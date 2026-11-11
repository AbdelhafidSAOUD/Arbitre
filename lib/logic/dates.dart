/// Dates au format AAAA-MM-JJ, dans le fuseau de l'appareil.
String isoDay(DateTime d) {
  String two(int v) => v < 10 ? '0$v' : '$v';
  return '${d.year}-${two(d.month)}-${two(d.day)}';
}

String todayIso([DateTime? now]) => isoDay(now ?? DateTime.now());

String addDaysIso(int days, [DateTime? now]) {
  final n = now ?? DateTime.now();
  return isoDay(DateTime(n.year, n.month, n.day + days));
}

DateTime? parseDay(String s) => DateTime.tryParse(s);

const _months = ['janv.', 'févr.', 'mars', 'avr.', 'mai', 'juin', 'juil.', 'août', 'sept.', 'oct.', 'nov.', 'déc.'];

/// « 11 nov. »
String shortDate(String iso) {
  final d = parseDay(iso);
  if (d == null) return iso;
  return '${d.day} ${_months[d.month - 1]}';
}

String frNumber(double v, {int decimals = 1}) {
  final s = v.toStringAsFixed(decimals).replaceAll('.', ',');
  return s.endsWith(',0') ? s.substring(0, s.length - 2) : s;
}
