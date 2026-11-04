import 'package:flutter/material.dart';

// 앱 공통 테마 (색·글꼴은 디자인 확정 후 채운다)
ThemeData buildAppTheme() {
  return ThemeData(
    useMaterial3: true,
    colorSchemeSeed: Colors.indigo,
  );
}
