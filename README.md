# PhoTalk
PhoTalk: 지식그래프를 이용한 메신저와 사진 시각화 모바일 앱 (3-1 고급 모바일 프로그래밍)

## 구성

```
PhoTalk/
├─ app/                          Flutter 앱
│  ├─ pubspec.yaml               사용하는 패키지 목록 (flutter pub get 으로 설치)
│  ├─ assets/mock/               서버 없이 쓰는 더미 JSON
│  ├─ test/                      위젯 테스트
│  ├─ android/ ios/ web/ ...     플랫폼별 폴더 (대부분 자동 생성)
│  └─ lib/
│     ├─ main.dart               앱 시작점, Provider(의존성 주입) 설정
│     ├─ core/                   공통 설정 (서버 주소 api_config, 색 app_colors, 글자 app_text, 테마)
│     ├─ domain/                 앱이 쓰는 데이터 모양
│     │  ├─ models/              Chatroom, Person, Relationship, ChatPreview, UploadStatus ...
│     │  └─ repositories/        데이터를 가져오는 약속(인터페이스)
│     ├─ data/                   데이터를 실제로 가져오는 구현
│     │  ├─ api/                 서버(Flask)와 통신 (대화방·참여자, 키워드·통계, 관계, 지식 그래프)
│     │  └─ mock/                더미 JSON으로 동작
│     └─ features/               화면
│        ├─ start/               시작 화면
│        ├─ menu/                햄버거 메뉴 (app_menu_drawer.dart)
│        ├─ graph/               대기능 3: 지식 그래프 보기 (knowledge_graph_screen, force_graph_view, force_simulation)
│        ├─ collect/             대기능 1·2: 데이터 수집 → 수집 확인 → 그래프 구축
│        │  ├─ collect_screen.dart        데이터 수집 (대화방·사진 추가)
│        │  ├─ add_chat_screen.dart       대화방 추가·수정·삭제
│        │  ├─ photo_select_screen.dart   사진 선택
│        │  ├─ name_input_screen.dart     인물 이름 입력
│        │  ├─ confirm_screen.dart        수집 확인
│        │  ├─ graph_building_screen.dart 그래프 만드는 중
│        │  ├─ graph_done_screen.dart     그래프 완성
│        │  ├─ collect_controller.dart    위 화면들이 함께 쓰는 상태
│        │  └─ widgets/                   이 화면들 전용 작은 위젯
│        └─ people/              참여자 목록 (초기 예제 화면)
├─ backend/                      Flask 서버 (GraphRAG 기반 메신저 분석)
│  ├─ src/
│  │  ├─ app.py                  서버 시작점, API 라우트
│  │  ├─ util/                   파서·인덱싱 작업·DB 등 서버 로직
│  │  ├─ config/                 설정
│  │  └─ parquet/.env            API 키·DB 정보 (직접 만든다, git 제외)
│  ├─ parquet_template/          GraphRAG 설정·프롬프트 템플릿
│  ├─ db/schema.sql              MySQL 테이블
│  ├─ sample_data/               테스트용 가짜 대화와 업로드 스크립트
│  ├─ user_data/                 서버가 만드는 사용자 데이터 (git 제외)
│  ├─ PhoTalk_venv/              Python 가상환경 (직접 만든다, git 제외)
│  └─ requirements.txt           Python 패키지 목록
└─ docs/                         ARCHITECTURE.md (계층 · 의존 방향), GUIDE.md (폴더 구조 · 기능 추가 방법), INTEGRATION.md (앱↔서버 연결)
```

무엇을 만들 때 어느 폴더에 어떻게 추가하는지는 [docs/GUIDE.md](docs/GUIDE.md) 참고.

## 문서 목록

| 문서 | 내용 |
|---|---|
| [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) | 앱·서버 계층 구조와 의존 방향 |
| [docs/GUIDE.md](docs/GUIDE.md) | 폴더 구조, 화면·데이터·API를 추가하는 방법 |
| [docs/INTEGRATION.md](docs/INTEGRATION.md) | 더미(Mock) → 실제 서버 연결 방법, API 대응표 |
| [backend/sample_data/README.md](backend/sample_data/README.md) | 테스트용 가짜 대화와 업로드 스크립트 |
| [backend/user_data/README.md](backend/user_data/README.md) | 서버가 만드는 사용자 데이터 폴더 (git 제외) |
| [backend/parquet_template/README.md](backend/parquet_template/README.md) | GraphRAG 설정·프롬프트 템플릿 |
| [backend/src/util/README.md](backend/src/util/README.md) | 서버 로직(util) 파일별 역할 (일부 옛 내용 정리 필요) |
| [backend/src/util/database/README.md](backend/src/util/database/README.md) | DB 읽기/쓰기 모듈 |
| [backend/src/util/jobs/README.md](backend/src/util/jobs/README.md) | 비동기 작업(인덱싱 등) 모듈 |

## 직접 설치할 것 한눈에 보기

처음 한 번만 하면 되는 것들이다. 자세한 명령은 아래 "개발 환경"에 있다.

| 항목 | 용도 | 비고 |
|---|---|---|
| Git | 코드 받기 | |
| Flutter SDK | 앱 실행 | `C:\src\flutter`, Path 등록 |
| Chrome | 앱 실행·확인 | `flutter run -d chrome` |
| Windows 개발자 모드 | 플러그인 빌드(심볼릭 링크) | `start ms-settings:developers` 에서 켠다 |
| Python 3.11 | 서버 실행 | |
| MySQL | 서버 DB | `db/schema.sql` 적용 |
| OpenAI API 키 | 인덱싱(그래프 생성) | `backend/src/parquet/.env`의 `LLM_API_KEY` |

Flutter 패키지(`provider`, `http`, `google_fonts`, `file_picker`, `desktop_drop`)는 `app` 폴더에서 `flutter pub get` 한 번이면 설치된다. 따로 `pub add` 할 필요 없다. 서버 패키지는 가상환경을 켠 뒤 `pip install -r requirements.txt` 로 설치한다.

## 실행 방법

터미널 두 개를 쓴다. 대화방 추가(미리보기)와 그래프 구축은 서버가 필요하다.

**터미널 A: 서버** (`backend` 폴더)
```
cd backend
source PhoTalk_venv/Scripts/activate      # PowerShell: PhoTalk_venv\Scripts\activate
python src/app.py
```
프롬프트 앞에 `(PhoTalk_venv)`가 보여야 한다. 가상환경을 켜지 않고 실행하면 GraphRAG 버전이 달라 인덱싱이 실패한다. 터미널을 새로 열 때마다 다시 활성화한다.

**터미널 B: 앱** (`app` 폴더)
```
cd app
flutter pub get          # 처음이나 pubspec.yaml이 바뀐 뒤에만
flutter run -d chrome
```

- 모바일 화면처럼 보려면 Chrome에서 `F12` → `Ctrl+Shift+M` 으로 기기 모드를 켜고 402×874 로 맞춘다.
- 실행 중 `r`은 hot reload, `R`은 hot restart, `q`는 종료다. 패키지를 추가하거나 상태 구조를 바꾼 뒤에는 끄고 다시 실행한다. `Ctrl+C` 후 "일괄 작업을 끝내시겠습니까 (Y/N)?"가 나오면 `Y`를 입력한다.
- 서버 없이 화면만 볼 때는 `app/lib/main.dart`의 `ChatroomRepositoryApi()`를 `ChatroomRepositoryMock()`으로 바꾼다 (확인 후 되돌린다). 지식 그래프 보기는 서버의 `/graph-data`를 쓰므로 서버가 켜져 있어야 한다.
- 안드로이드 에뮬레이터는 `flutter run -d emulator-5554` 로 실행하고 서버 주소는 `10.0.2.2`로 자동 설정된다. 파일 선택에는 에뮬레이터에 대화 파일이 있어야 하므로 파일을 에뮬레이터 창에 끌어다 놓아 Downloads에 넣는다.

**앱 사용 순서**: 시작하기 → 데이터 수집(`+ 대화방 추가`로 카카오톡 `.txt` 선택, 또는 파일을 창에 끌어다 놓기) → 다음 → 수집 확인 → 그래프 만들기. 사진은 선택 사항이다. "그래프 만들기"를 눌러야 서버에 업로드되고 인덱싱이 시작된다. 인덱싱은 몇 분 걸리고 OpenAI 호출 비용이 든다.

## 데모 한 번에 돌리기

서버에 샘플 대화를 올려 인덱싱하고, 앱에서 참여자와 아바타를 보는 순서다. 처음 한 번은 아래 "개발 환경"의 Flutter 설치와 서버 준비(패키지, MySQL, `.env`)를 끝내 둔다.

1. 서버를 켠다 (터미널 A, `backend` 폴더, 가상환경 활성화 상태)
   ```
   python src/app.py
   ```
2. 샘플 대화를 올린다 (터미널 B, `backend` 폴더). 인덱싱에 몇 분 걸리고 OpenAI 호출 비용이 조금 든다(샘플 기준 약 $0.2).
   ```
   python sample_data/upload_demo.py
   ```
   서버 터미널에 `[JOB][pipeline] SUCCESS` 가 뜰 때까지 기다린다.
3. 앱을 실행한다 (터미널 C, `app` 폴더)
   ```
   flutter run -d chrome
   ```
   "데모 동아리방"과 참여자 3명의 아바타가 보이면 성공이다.

질문 검색 등 서버만 따로 확인하는 방법은 [backend/sample_data/README.md](backend/sample_data/README.md), 앱 쪽 자세한 설명은 [app/README.md](app/README.md) 를 본다.

## 개발 환경

### Flutter (app/)

Windows 기준이다. Git이 설치돼 있어야 한다.

**2번(환경 변수 설정)은 반드시 PowerShell에서** 실행해야 한다 (Git Bash에서는 동작하지 않는다). 나머지는 PowerShell/Git Bash 어느 쪽이든 되지만 명령 문법이 다르니 각 단계에 적힌 표기를 따른다.

1. Flutter SDK 설치 (한글·공백 없는 경로 `C:\src\flutter`에 받는다. `--depth 1`은 최신 버전만 받아 훨씬 빠르다)

   PowerShell 또는 Git Bash 중 쓰는 쪽 하나만 실행한다. PowerShell에서는:
   ```
   git clone https://github.com/flutter/flutter.git -b stable --depth 1 C:\src\flutter
   ```
   Git Bash에서는 경로를 `/c/src/flutter`로 쓴다:
   ```
   git clone https://github.com/flutter/flutter.git -b stable --depth 1 /c/src/flutter
   ```
   받다가 중단했다면 폴더를 지우고 다시 받는다. (PowerShell: `Remove-Item -Recurse -Force C:\src\flutter`, Git Bash: `rm -rf /c/src/flutter`)

2. 환경 변수 Path에 Flutter를 추가한다 (**PowerShell 전용**)
   ```
   $p = [Environment]::GetEnvironmentVariable("Path", "User")
   [Environment]::SetEnvironmentVariable("Path", "$p;C:\src\flutter\bin", "User")
   ```
   **VS Code(또는 터미널)를 완전히 종료했다가 다시 켠다.**

3. 설치 확인 (처음에는 Dart SDK를 받느라 몇 분 걸린다)
   ```
   flutter doctor
   ```
   `Flutter` 항목이 ✓면 된다. Android·Visual Studio 항목의 ✗는 실행 방법에 따라 필요할 때만 해결한다.

4. Windows 개발자 모드를 켠다 (플러그인 패키지 빌드에 필요하다. 안 켜면 `Building with plugins requires symlink support` 오류가 난다)
   ```
   start ms-settings:developers
   ```
   열린 설정 창에서 개발자 모드를 켠다 (PowerShell에서 실행).

5. 레포를 받고 의존 패키지를 설치한다
   ```
   cd app
   flutter pub get
   ```

6. 실행한다 (가장 쉬운 방법은 Chrome)
   ```
   flutter run -d chrome
   ```
   폰이나 에뮬레이터로 실행하려면 Android Studio를 설치해 에뮬레이터를 만들거나, 폰을 USB로 연결한 뒤 `flutter devices`로 기기를 확인하고 `flutter run`을 실행한다.

처음부터 새로 만들 때만 아래 명령을 쓴다 (`app/`에 이미 `android/`, `ios/`가 있으면 필요 없다).
```
cd app
flutter create --project-name photalk --org com.ab3 .
```

### 서버 (backend/)

1. Python 3.11 가상환경(`PhoTalk_venv`)을 만들고 패키지를 설치한다.
   ```
   cd backend
   python -m venv PhoTalk_venv
   PhoTalk_venv\Scripts\activate        # Git Bash: source PhoTalk_venv/Scripts/activate
   pip install -r requirements.txt
   ```
2. MySQL을 실행하고 스키마를 만든다.
   ```
   mysql -u root -p < db/schema.sql
   ```
   `mysql: command not found` 가 나오면 PATH에 없는 것이니 전체 경로로 실행한다 (버전 폴더는 설치된 것에 맞춘다).
   ```
   "/c/Program Files/MySQL/MySQL Server 8.0/bin/mysql.exe" -u root -p < db/schema.sql
   ```
3. `src/parquet/.env.example`을 `src/parquet/.env`로 복사한다. DB 정보와 **`LLM_API_KEY=` 뒤에 본인 OpenAI API 키**를 넣는다. 모델명(`gpt-5.4-mini` 등)은 예시 값이 이미 들어 있다.
4. `backend` 폴더에서 서버를 실행한다.
   ```
   python src/app.py
   ```
5. 샘플 대화로 동작을 확인한다 (서버가 켜진 상태에서 다른 터미널로).
   ```
   python sample_data/upload_demo.py
   ```
   `backend/sample_data/demo_chat.txt`(가짜 대화)를 업로드해 인덱싱까지 진행한다. 임베딩 모델을 바꾼 뒤에는 대화방을 다시 인덱싱해야 한다.

`.env`와 `user_data/` 안의 대화 데이터는 키·개인정보가 들어가므로 git에 올리지 않는다(`.gitignore`에 포함).
