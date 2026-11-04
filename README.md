# PhoTalk
PhoTalk: 지식그래프를 이용한 메신저와 사진 시각화 모바일 앱 (3-1 고급 모바일 프로그래밍)

## 구성

```
PhoTalk/
  app/       Flutter 앱
  backend/   Flask 서버 (GraphRAG 기반 메신저 분석)
  docs/      ARCHITECTURE.md (계층 · 의존 방향)
```

## 개발 환경

### Flutter (app/)

Windows 기준이다. Git이 설치돼 있어야 한다. **2번(환경 변수 설정)은 반드시 PowerShell에서** 실행한다 (Git Bash에서는 동작하지 않는다). 나머지는 PowerShell/Git Bash 어느 쪽이든 되지만 명령 문법이 다르니 위 표기를 따른다.

1. Flutter SDK 설치 (한글·공백 없는 경로 `C:\src\flutter`에 받는다. `--depth 1`은 최신 버전만 받아 훨씬 빠르다)

   PowerShell에서:
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

1. Python 3.11 가상환경을 만들고 패키지를 설치한다.
   ```
   cd backend
   pip install -r requirements.txt
   ```
2. MySQL을 실행하고 스키마를 만든다.
   ```
   mysql -u root -p < db/schema.sql
   ```
3. `src/parquet/.env.example`을 `src/parquet/.env`로 복사해 DB 정보와 AI 설정을 입력한다.
4. `backend` 폴더에서 서버를 실행한다.
   ```
   python src/app.py
   ```

`.env`와 `user_data/` 안의 대화 데이터는 키·개인정보가 들어가므로 git에 올리지 않는다(`.gitignore`에 포함).
