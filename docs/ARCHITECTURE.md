# PhoTalk 구조 설계 (계층 · 의존 방향)

## 1. 전체 그림

```
[ Flutter 앱 ]  --HTTP/JSON-->  [ Flask 서버 ]  -->  MySQL / GraphRAG 산출물 / OpenAI
   app/                           backend/
```

앱과 서버는 **HTTP API 계약**으로만 연결한다. 서로의 코드를 import하지 않는다.
API 계약(요청·응답 모양)은 `docs/API.md`에 적고, 둘 다 이 문서를 기준으로 맞춘다.

## 2. 앱(Flutter) 계층

```
features  (화면 + 상태)   ──▶  domain  ◀──  data  (서버/더미 구현)
                          (모델 + 인터페이스)
                          
core (공통 위젯·테마)  : 어디서나 쓸 수 있고, 아무것도 import하지 않는다
```

| 계층 | 들어가는 것 | import 가능한 것 | import 금지 |
|---|---|---|---|
| `domain/` | 모델(Member, Relation …), Repository **인터페이스** | Dart 기본 라이브러리만 | Flutter, http, data, features |
| `data/` | 인터페이스 구현 (`api/`, `mock/`), JSON 변환 | domain | features |
| `features/` | 화면, 상태(Provider/ViewModel), 위젯 | domain, core | data (직접 import 금지) |
| `core/` | 테마, 공통 위젯 | Flutter | domain 이하 전부 |
| `main.dart` | **조립**: 어떤 구현을 쓸지 고르고 주입 | 전부 | — |

규칙 한 줄: **화살표는 domain 쪽으로만 향한다.** `features`는 `data`를 모르고, `domain`은 아무도 모른다.
구현 교체(더미 → 서버)는 `main.dart` 한 곳에서만 일어난다.

### 폴더

```
app/lib/
  main.dart
  core/
  domain/
    models/
    repositories/      # 기능별 Repository 인터페이스
  data/
    api/               # api_client.dart + *_repository_api.dart
    mock/              # *_repository_mock.dart + assets/mock/*.json
  features/
    <기능명>/          # 화면 + 상태 + 위젯 (기능 하나 = 폴더 하나)
```

`features/` 폴더 하나 = 기능 하나. **한 기능을 고칠 때 한 폴더만 열면 된다(응집도).**
기능 폴더끼리는 서로 import하지 않는다(필요하면 domain으로 올린다).
기능 폴더 이름과 화면 배정은 담당자가 정하고, 화면 ID는 화면 설계서를 따른다.

## 3. 서버(Flask) 계층

```
routes (HTTP)  ──▶  services (기능 흐름)  ──▶  repositories (MySQL 읽기/쓰기)
                         │
                         └──▶  ports (LLM · 임베딩 인터페이스)  ◀──  OpenAI 구현
```

| 계층 | 역할 | 비고 |
|---|---|---|
| routes | 요청 검증, JSON 반환만 | 지금 `app.py` 한 파일 → 기능별 Blueprint(members, stats, search, upload)로 분리 |
| services | 기능 로직 | 현재 `util/` 일부가 해당 |
| repositories | DB 접근 | 현재 `util/database/` |
| ports | LLM·임베딩 호출 **인터페이스** | OpenAI 구현은 한 모듈에만 둔다 |

규칙: routes는 repositories를 직접 부르지 않는다. DB·OpenAI는 services 아래에서만 만난다.

