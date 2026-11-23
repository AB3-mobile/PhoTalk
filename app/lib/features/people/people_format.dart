// 멤버 화면에서 쓰는 숫자·날짜·시간 글자 만들기

String _two(int n) => n.toString().padLeft(2, '0');

// 1382 → "1,382"
String formatNumber(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write(',');
    b.write(s[i]);
  }
  return b.toString();
}

// 1382 → "1,382건"
String formatCount(int n) => '${formatNumber(n)}건';

// 2022-03-01 → "2022.03.01"
String formatDot(DateTime d) => '${d.year}.${_two(d.month)}.${_two(d.day)}';

// 2022-05-19 → "2022-05-19" (날짜 글자끼리 크기를 비교할 때 쓴다)
String isoDate(DateTime d) => '${d.year.toString().padLeft(4, '0')}-${_two(d.month)}-${_two(d.day)}';

// 2022-03 → "2022.03"
String formatYm(DateTime d) => '${d.year}.${_two(d.month)}';

// (2022, 5) → "2022-05" (서버가 쓰는 월 글자)
String monthKey(int year, int month) => '$year-${_two(month)}';

// "15:02" → "오후 3:02"
String formatClock(String hhmm) {
  final p = hhmm.split(':');
  if (p.length < 2) return hhmm;
  final h = int.tryParse(p[0]);
  if (h == null) return hhmm;
  final ampm = h < 12 ? '오전' : '오후';
  final h12 = h % 12 == 0 ? 12 : h % 12;
  return '$ampm $h12:${p[1]}';
}
