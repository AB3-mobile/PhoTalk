# PhoTalk 앱 (Flutter)

화면은 `lib/features/`, 데이터는 `lib/domain`(약속)과 `lib/data`(구현)에 있다. 구조는 [../docs/ARCHITECTURE.md](../docs/ARCHITECTURE.md), 서버 연결은 [../docs/INTEGRATION.md](../docs/INTEGRATION.md)를 본다.

## 실행하기

Flutter SDK 설치는 루트 [README](../README.md)의 "개발 환경"을 먼저 한다.

```
cd app
flutter pub get
flutter run -d chrome
```

- 처음에는 빌드에 몇 분 걸린다. 터미널에서 `r`은 핫 리로드, `q`는 종료.
- 경로에 한글/`[ ]`가 있으면 `flutter analyze`가 죽을 수 있다. 영문 경로로 복사해서 실행한다.
- 연결된 기기 확인: `flutter devices`, 기기 지정 실행: `flutter run -d <기기id>`

## 서버와 같이 보기 (참여자 아바타 화면)

지금 첫 화면은 서버의 첫 번째 대화방 참여자를 아바타 이미지와 이름으로 보여준다. 서버에 데이터가 있어야 한다.

1. 서버를 켠다 (`backend`에서 `python src/app.py`).
2. 샘플 대화를 올려 인덱싱한다 (`python sample_data/upload_demo.py`, 몇 분 걸림). 끝나면 아바타 이미지도 만들어진다.
3. 앱을 실행한다 (`flutter run -d chrome`).

서버 주소는 실행 환경에 따라 자동으로 고른다. 직접 정하려면 이렇게 한다.
```
flutter run -d chrome --dart-define=API_BASE_URL=http://localhost
```

| 실행 환경 | 서버 주소 |
|---|---|
| Chrome(웹), Windows | `http://localhost` (기본) |
| 안드로이드 에뮬레이터 | `http://10.0.2.2` (기본) |
| 실제 폰 | PC의 IP, 예: `--dart-define=API_BASE_URL=http://192.168.0.5` (같은 와이파이, 방화벽 허용) |

"불러오지 못했어요"가 뜨면: 서버가 켜져 있는지, 인덱싱이 끝났는지(`curl -X POST http://localhost/messenger-chatrooms -H "Content-Type: application/json" -d "{}"`에서 `indexed: true`), 주소가 맞는지 확인한다.

## 서버 없이 보기 (더미 데이터)

`lib/main.dart`의 `PhoTalkApp` 기본값은 서버(Api)다. 더미로 보려면 `main()`에서 이렇게 바꾼다.
```dart
runApp(PhoTalkApp(chatroomRepository: ChatroomRepositoryMock()));
```
(`import 'data/mock/chatroom_repository_mock.dart';` 추가). 더미 데이터는 `assets/mock/*.json`이다.

## 테스트

```
flutter test
```
