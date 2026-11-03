# user_data — 대화방별 데이터 (git 미추적)

대화방별 수집 원본, 인덱싱 산출물, 캐시가 쌓이는 곳이다. 서버가 실행되면 자동으로 채워진다.
**개인정보라 git에 커밋하지 않는다** — [`.gitignore`](../.gitignore)에서 `.gitkeep`과 이 README만 남기고 전부 무시한다.

## 구조

```
user_data/
└─ messenger/
   └─ <대화방 dir_name>/
      └─ graphrag/
         └─ parquet/      GraphRAG 작업 디렉터리 (input · output · settings.yaml)
```

- 경로 규칙은 [`src/util/user_path.py`](../src/util/user_path.py)의 `UserPaths` · `list_accounts()`가 담당한다.
