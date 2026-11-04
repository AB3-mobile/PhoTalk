# PhoTalk 프로젝트 가이드 (구조 + "뭘 만들 때 어디에 추가하나")

설계 원칙(계층·의존 방향)은 [ARCHITECTURE.md](ARCHITECTURE.md)에 있다. 이 문서는 **폴더가 실제로 어떻게 생겼고, 새 기능을 만들 때 어느 파일을 어떻게 건드리는지**를 순서대로 적은 작업 안내서다.

---

## 1. 폴더 한눈에 보기

```
PhoTalk/
├─ README.md                 # 실행 방법 (Flutter 설치, 서버 실행)
├─ docs/
│   ├─ ARCHITECTURE.md       # 계층 구조·의존 방향 설계
│   └─ GUIDE.md              # (이 문서)
├─ app/                      # Flutter 앱
│   ├─ pubspec.yaml          # 패키지·asset 등록
│   ├─ assets/mock/*.json    # 서버 없이 쓰는 가짜 데이터
│   ├─ test/                 # 위젯/단위 테스트
│   └─ lib/
│       ├─ main.dart         # 앱 시작 + 어떤 구현을 쓸지 고르는 "조립" 파일
│       ├─ core/             # 테마, 공통 위젯 (아무 데도 의존 안 함)
│       ├─ domain/
│       │   ├─ models/       # 데이터 모양 (Chatroom, Person ...)
│       │   └─ repositories/ # "무엇을 가져올지" 약속(인터페이스)
│       ├─ data/
│       │   ├─ mock/         # 더미 JSON으로 동작하는 구현
│       │   └─ api/          # (예정) 서버와 HTTP로 통신하는 구현
│       └─ features/         # 화면. 기능마다 폴더 하나
└─ backend/                  # Flask 서버
    ├─ requirements.txt
    ├─ sample_data/          # 테스트용 가짜 대화 + 업로드 스크립트
    ├─ db/                   # DB 스키마
    ├─ parquet_template/     # GraphRAG 설정 템플릿(settings.j2, 프롬프트)
    └─ src/
        ├─ app.py            # 서버 진입점 + API 라우트(엔드포인트)
        ├─ parquet/.env      # 키·모델명 (직접 만든다, 커밋 금지)
        ├─ config/           # DB 연결 등 설정
        └─ util/             # 실제 일을 하는 코드
            ├─ message_parser.py     # 카톡 내보내기 텍스트 파싱
            ├─ graphrag*.py          # 인덱싱·질의 (GraphRAG)
            ├─ message_*.py, extract_statics.py   # 통계·키워드·요약·분위기
            ├─ avatar_generator.py   # 아바타 이미지 (OpenAI 이미지 API)
            ├─ jobs/                 # 오래 걸리는 작업(비동기 job)
            └─ database/             # DB 읽기/쓰기
```

---

## 2. 앱: 계층 규칙 (딱 이것만 지키면 된다)

```
features(화면) ──▶ domain ◀── data(구현)         core는 어디서나 사용 가능
```

- 화면(`features`)은 **`data`를 직접 import하지 않는다.** `domain`의 Repository 인터페이스만 쓴다.
- 서버 ↔ 더미 교체는 **`main.dart` 한 곳**에서만 한다.
- JSON 키 이름(snake_case)은 서버 응답 그대로 `fromJson`에서만 다룬다. 화면은 모델만 본다.

---

## 3. 레시피: UI(화면)를 만들고 싶다

예: "대화방 목록 화면" 추가.

1. **폴더 만들기** — `app/lib/features/chatroom_list/`
   ```
   features/chatroom_list/
     chatroom_list_screen.dart   # 화면(Widget)
     chatroom_list_view_model.dart  # 상태(ChangeNotifier)  ※ 간단하면 생략 가능
     widgets/                    # 이 화면에서만 쓰는 작은 위젯
   ```
2. **데이터는 Repository로 받는다** — 화면에서 `context.read<ChatroomRepository>()`로 꺼내 쓴다. (`data/`를 import하지 않는다.)
   ```dart
   class ChatroomListViewModel extends ChangeNotifier {
     ChatroomListViewModel(this._repo);
     final ChatroomRepository _repo;
     List<Chatroom> rooms = [];
     Future<void> load() async { rooms = await _repo.getChatrooms(); notifyListeners(); }
   }
   ```
3. **화면에서 연결** — `ChangeNotifierProvider(create: (c) => ChatroomListViewModel(c.read<ChatroomRepository>())..load(), child: ...)`
4. **어디서 띄울지 정하기** — `main.dart`의 `home:`(또는 라우트)에 새 화면을 연결한다.
5. 여러 화면에서 쓰는 위젯/색/글꼴이면 `core/`에 둔다. 한 화면에서만 쓰면 그 기능 폴더 `widgets/`에 둔다.

체크: `features/` 안에 `import '../../data/...'` 가 있으면 규칙 위반이다.

---

## 4. 레시피: 새 데이터를 화면에 보여주고 싶다 (모델 → 인터페이스 → 더미 → 연결)

예: "대화방의 하이라이트(highlights)"를 새로 보여주고 싶다.

| 순서 | 할 일 | 파일 |
|---|---|---|
| 1 | **모델** 만들기 + `fromJson` | `domain/models/highlight.dart` |
| 2 | **인터페이스**에 메서드 추가(또는 새 Repository 파일) | `domain/repositories/highlight_repository.dart` |
| 3 | **더미 JSON** 추가 | `assets/mock/highlights.json` (`pubspec.yaml`의 `assets: - assets/mock/` 가 폴더째 등록하므로 파일만 넣으면 됨) |
| 4 | **Mock 구현** | `data/mock/highlight_repository_mock.dart` (`loadMockJson('highlights')` 사용) |
| 5 | **조립** | `main.dart`의 `providers`에 `Provider<HighlightRepository>(create: (_) => HighlightRepositoryMock())` 추가 |
| 6 | 화면에서 사용 | `features/<기능>/` (3번 레시피) |

기존 Repository에 메서드를 추가하면, 그 인터페이스를 구현한 **Mock(과 나중에 Api) 모두**에 구현을 추가해야 컴파일된다.

---

## 5. 레시피: 더미 → 진짜 서버로 바꾸고 싶다

1. 서버 응답 모양을 확인한다 (예: `/messenger-chatrooms` → `{"data":{"chatrooms":[...]}}`). 더미 JSON이 이미 이 모양을 따른다.
2. `data/api/chatroom_repository_api.dart` 를 만들고 `implements ChatroomRepository` 로 HTTP 호출을 구현한다. (패키지 `http` 또는 `dio`를 `pubspec.yaml`에 추가)
3. `main.dart`에서 `ChatroomRepositoryMock()` 한 줄만 `ChatroomRepositoryApi()` 로 바꾼다. **화면 코드는 한 줄도 안 바뀐다.**
4. 서버 주소는 `core/`에 상수/설정으로 두고(에뮬레이터는 `10.0.2.2`), 코드에 키·비밀번호를 쓰지 않는다.

---

## 6. 레시피: 서버에 API(엔드포인트)를 추가하고 싶다

1. **라우트** — `backend/src/app.py` 에 `@app.route("/새-경로", methods=["POST"])` 함수를 추가한다. 요청 파싱·응답(JSON)만 하고 실제 일은 `util/`로 넘긴다.
2. **로직** — `backend/src/util/` 에 함수를 만든다(또는 기존 파일에 추가). DB를 읽고 쓰는 건 `util/database/`.
3. **오래 걸리는 작업**(LLM, 인덱싱)은 요청 안에서 끝내지 말고 `jobs/job_store.py` 의 job으로 돌리고, `/job-status/<id>` 로 상태를 확인하게 한다 (`/run-query-async`, `/message-upload` 가 예시).
4. **DB 컬럼/테이블이 필요하면** `backend/db/` 스키마와 `util/jobs/schema.sql`을 같이 갱신한다.
5. 응답 모양을 정했으면 앱 쪽 모델(`domain/models`)과 맞춘다. (API 계약 문서는 `docs/API.md`로 정리 예정)

---

## 7. 레시피: AI(OpenAI) 관련 수정은 어디서?

| 바꾸고 싶은 것 | 위치 |
|---|---|
| 모델 이름, API 키 | `backend/src/parquet/.env` (`RAG_CHAT_MODEL`, `INDEXING_CHAT_MODEL`, `SUB_TASK_CHAT_MODEL`, `*_EMBEDDING_MODEL`, `IMAGE_MODEL`, `LLM_API_KEY`) |
| GraphRAG 인덱싱·질의 설정 | `backend/parquet_template/src/prompts/settings.j2` |
| 인덱싱 프롬프트 | `backend/parquet_template/src/prompts/` |
| 질의 응답 로직 | `util/graphrag_query.py`, `util/graphrag_engine.py` |
| 키워드·통계·요약·분위기 | `util/extract_statics.py`, `message_statics.py`, `message_summary.py`, `message_mood.py` |
| 아바타 이미지 | `util/avatar_generator.py` (`generate_avatar_image_bytes`) |

주의
- API 키는 **서버 `.env`에만** 둔다. 앱·저장소에 넣지 않는다.
- `gpt-5` 계열은 `temperature`/`frequency_penalty`를 기본값 외로 못 쓰고, 출력 길이 제한은 `max_completion_tokens`를 쓴다.
- **임베딩 모델을 바꾸면 기존 인덱스와 안 맞는다.** 대화방을 처음부터 다시 인덱싱해야 한다.

---

## 8. 테스트·실행 빠른 참고

| 하고 싶은 것 | 명령 |
|---|---|
| 앱 테스트 | `cd app && flutter test` |
| 앱 정적 분석 | `cd app && flutter analyze` (경로에 한글/`[ ]`가 있으면 오류 → README 참고) |
| 서버 실행 | `cd backend && python src/app.py` |
| 샘플 대화로 서버 점검 | `python sample_data/upload_demo.py` (서버가 켜진 상태에서) |

---

## 9. 지키기로 한 것

- 브랜치: `<type>_<이슈번호>` (예: `feat_12`), 이슈 제목: `feat: …`, `refactor: …`, `docs: …`
- PR 본문에 `Closes #번호`, 리뷰어 지정, 머지 후 다음 브랜치 시작
- `.env`, 키, 개인 대화 파일, `backend/user_data/` 안의 실제 데이터는 올리지 않는다
- 더미 데이터는 전부 가짜 값만 쓴다
