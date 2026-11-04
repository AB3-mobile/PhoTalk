# PhoTalk
PhoTalk: 지식그래프를 이용한 메신저와 사진 시각화 모바일 앱 (3-1 고급 모바일 프로그래밍)

## 구성

```
PhoTalk/
  app/       Flutter 앱
  backend/   Flask 서버 (GraphRAG 기반 메신저 분석)
  docs/      ARCHITECTURE.md (계층 · 의존 방향), GUIDE.md (폴더 구조 · 기능 추가 방법), INTEGRATION.md (앱↔서버 연결)
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

4. 레포를 받고 의존 패키지를 설치한다
   ```
   cd app
   flutter pub get
   ```

5. 실행한다 (가장 쉬운 방법은 Chrome)
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
