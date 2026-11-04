# 앱 ↔ 서버 연결 가이드 (더미 → 실제)

## 한 줄 요약

화면은 데이터가 **가짜 JSON**에서 오는지 **진짜 서버**에서 오는지 모른다. 가져오는 담당을 `main.dart`에서 한 줄로 고르고, 화면 코드는 바꾸지 않는다.

```
화면(features) ──"대화방 줘"──▶ ChatroomRepository   ← 약속(인터페이스, domain/)
                                  ├─ ChatroomRepositoryMock : assets/mock/*.json 에서 가져옴
                                  └─ ChatroomRepositoryApi  : 서버(Flask)에 HTTP로 물어봐서 가져옴
```

| 담당 | 위치 | 언제 |
|---|---|---|
| Mock | `app/lib/data/mock/` | 서버 없이 UI를 만들 때 |
| Api | `app/lib/data/api/` | 서버와 연결해서 볼 때 |

## 이미 연결된 것 (예시로 보기)

지금은 **대화방 목록과 참여자**만 서버에 연결돼 있다. 나머지는 아직 Mock이다.

| 데이터 | 상태 |
|---|---|
| 대화방, 참여자 (`ChatroomRepository`) | 서버(Api) 연결됨 |
| 관계, 통계, 검색 | Mock |

서버에 연결된 부분을 보려면 이 파일 두 개를 열어본다.

- `app/lib/data/api/chatroom_repository_api.dart` : 서버에 요청을 보내고 결과를 모델로 바꾼다.
- `app/lib/main.dart` : `ChatroomRepositoryApi()` 를 골라서 앱에 넣는다. (Mock으로 바꾸려면 `ChatroomRepositoryMock()`)

참여자 화면(`features/people/people_screen.dart`)은 어느 담당이 쓰이는지 모른 채 `repo.getPeople()` 만 부른다.

## 다른 데이터도 서버에 연결하려면 (4단계)

예: "관계" 데이터를 Mock에서 서버로 바꾸기.

1. **서버가 주는 데이터 확인** — 아래 "API 대응표"에서 `/chatroom-relationships` 를 찾는다.
2. **Api 파일 만들기** — `data/api/relationship_repository_api.dart` 를 만들고, `chatroom_repository_api.dart` 를 복사해서 주소와 변환 부분만 바꾼다.
3. **main.dart 에서 교체** — `RelationshipRepositoryMock()` → `RelationshipRepositoryApi()`
4. **실행해서 확인** — 서버를 켜고 `flutter run -d chrome`. 화면이 그대로 나오면 끝이다.

데이터 모양이 안 맞으면 고치는 곳은 **모델의 `fromJson`** (`domain/models/`) 이다. 화면은 고치지 않는다.

## 서버 주소

서버는 PC에서 `python src/app.py` 로 켜고 80번 포트를 쓴다. 앱을 어디서 실행하느냐에 따라 주소가 다르다. 기본값은 `core/api_config.dart` 가 자동으로 고른다.

| 실행 환경 | 서버 주소 |
|---|---|
| Chrome(웹), Windows | `http://localhost` |
| 안드로이드 에뮬레이터 | `http://10.0.2.2` (에뮬레이터에서 PC를 가리키는 고정 주소) |
| 실제 폰 | PC의 IP (같은 와이파이), 예: `--dart-define=API_BASE_URL=http://192.168.0.5` |

## API 대응표 (참고용)

앱의 어떤 메서드가 서버의 어떤 주소를 부르는지 정리한 표다. 모두 `POST` + JSON, 날짜는 `YYYY-MM-DD`.

| 앱 메서드 | 서버 주소 | 보내는 값 | 돌려받는 값 |
|---|---|---|---|
| `getChatrooms()` | `/messenger-chatrooms` | `{}` | `data.chatrooms[]` |
| `getPeople(id)` | `/chatroom-people` | `{chatroom_id}` | `data.people[]` (이름, 아바타 주소 등) |
| 관계 | `/chatroom-relationships` | `{chatroom_id, start_date, end_date}` | `{source, target, relation_label, description}[]` |
| 키워드 | `/chatroom-keywords-by-person` | `{chatroom_id, participant_id, start_date, end_date}` | `[{word, count}]` |
| 월별 메시지 수 | `/chatroom-person-monthly-stats` | `{chatroom_id, participant_id}` | `{monthly:[{month,count}], total}` |
| 검색 | `/run-query-async` → `/job-status/<jobId>` | `{message, user_id: 대화방id, domain: "messenger", resMethod: "local"}` | `{status, result, source_ids}` |
| 근거 원문 | `/messenger-body-by-ids` | `{account: 대화방id, mail_id: 블록id}` | `{messages:[{time,sender,text}]}` |
| 아바타 이미지 | `GET /chatroom-person-avatar-image/<방id>/<파일명>` | — | 이미지 (`avatar_url` 앞에 서버 주소를 붙여서 `Image.network`) |

- 응답의 정확한 모양은 `backend/src/app.py` 의 각 라우트와 `assets/mock/*.json` 을 본다. 더미 JSON은 실제 응답과 같은 키 이름으로 만들어져 있다.
- **검색은 두 번 물어본다.** `/run-query-async` 가 `jobId` 를 주면, `/job-status/<jobId>` 를 1~2초마다 불러서 `status` 가 `done` 이 될 때까지 기다린다. 이 기다리는 부분은 `SearchRepositoryApi` 안에서 처리하고, 화면에는 완성된 결과만 준다.

## 자주 나는 문제

| 증상 | 원인 / 해결 |
|---|---|
| "불러오지 못했어요" | 서버가 꺼져 있거나 인덱싱이 안 끝났다. `/messenger-chatrooms` 에서 `indexed: true` 인지 확인 |
| 에뮬레이터에서 연결 거부 | `localhost` 가 아니라 `10.0.2.2` 를 쓴다 |
| 한글이 깨짐 | `jsonDecode(utf8.decode(res.bodyBytes))` 로 읽는다 |
| 안드로이드에서 http 차단 | 개발 중에는 `AndroidManifest.xml` 에 `android:usesCleartextTraffic="true"` |
| 웹에서 CORS 오류 | 서버가 `flask-cors` 를 쓰고 있어 보통 없다. 나면 서버 CORS 설정을 확인 |
