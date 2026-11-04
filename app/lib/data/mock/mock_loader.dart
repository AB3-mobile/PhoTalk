import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

// assets/mock/<name>.json 을 읽어 디코딩한다
Future<dynamic> loadMockJson(String name) async {
  final text = await rootBundle.loadString('assets/mock/$name.json');
  return jsonDecode(text);
}
