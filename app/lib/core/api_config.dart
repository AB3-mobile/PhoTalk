import 'package:flutter/foundation.dart' show kIsWeb;

// 서버 주소. 실행할 때 바꾸려면: flutter run --dart-define=API_BASE_URL=http://192.168.0.5
const String _override = String.fromEnvironment('API_BASE_URL');

// 웹은 localhost, 안드로이드 에뮬레이터는 PC를 가리키는 10.0.2.2 (실제 폰·iOS 시뮬레이터는 위 --dart-define으로 PC IP 지정)
String get apiBaseUrl {
  if (_override.isNotEmpty) return _override;
  return kIsWeb ? 'http://localhost' : 'http://10.0.2.2';
}
