# jobs — 백그라운드 job 저장소 + 인덱싱 파이프라인

업로드·인덱싱·업데이트처럼 오래 걸리는 작업을 백그라운드 스레드로 돌리고, 그 진행 상태를 메모리에 보관하는 계층이다.
`app.py`는 `job_run_graphrag`를 import 해서 인덱싱 파이프라인을 호출한다.

## 구성

| 파일 | 역할 |
|------|------|
| `job_store.py` | 메모리 기반 job 딕셔너리 (`create_job` / `update_job` / `append_job_log`). 서버 재시작 시 소멸 — 영속성 없음 |
| `job_run_graphrag.py` | GraphRAG 인덱싱/업데이트 파이프라인. GraphRAG CLI subprocess 실행, parquet 진행률 감시, 통계·요약·DB 저장까지 |

## 엔진 간 계약

두 `job_run_*.py`는 **함수 시그니처를 동일하게** 맞춰 `app.py`가 import 경로만 바꿔 재사용할 수 있게 한다:

- `start_graph_pipeline_background`
- `start_graph_update_pipeline_background`
- `build_*_update`
- `build_graph_json`


## 관련

- 상위: [`src/util/`](../README.md)
- 저장 대상: [`../database/`](../database/README.md)

---

# jobs — background job store + indexing pipelines

This layer runs long tasks (upload, indexing, update) on background threads and keeps their progress in memory.
`app.py` imports `job_run_graphrag` and calls the indexing pipeline.

## Layout

| File | Role |
|------|------|
| `job_store.py` | In-memory job dict (`create_job` / `update_job` / `append_job_log`). Lost on server restart — no persistence |
| `job_run_graphrag.py` | GraphRAG indexing/update pipeline — runs the GraphRAG CLI subprocess, watches parquet progress, does stats/summary/DB writes |

## Cross-engine contract

Both `job_run_*.py` files keep **identical function signatures** so `app.py` only has to swap the import path:

- `start_graph_pipeline_background`
- `start_graph_update_pipeline_background`
- `build_*_update`
- `build_graph_json`


## Related

- Parent: [`src/util/`](../README.md)
- Write targets: [`../database/`](../database/README.md)
