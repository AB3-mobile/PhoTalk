import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../core/api_config.dart';

// 서버에 JSON을 POST로 보내고 한글이 깨지지 않게 해석한 응답을 돌려준다
Future<dynamic> apiPost(String path, Map<String, dynamic> body) async {
  final res = await http.post(
    Uri.parse('$apiBaseUrl$path'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode(body),
  );
  if (res.statusCode != 200) throw Exception('$path 요청 실패 (${res.statusCode})');
  return jsonDecode(utf8.decode(res.bodyBytes));
}

// 날짜를 서버가 받는 "2026-03-01" 글자로 바꾼다
String apiDate(DateTime d) =>
    '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';
