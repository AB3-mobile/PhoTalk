import os

# 프로젝트 루트
BASE_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))

# 해당 도메인의 GraphRAG settings.yaml 경로를 만들어 반환한다
def GRAPHRAG_SETTINGS_DIR(domain):
    return os.path.join(BASE_DIR, "parquet_template", "rendered", domain, "settings.yaml")

# 해당 도메인의 GraphRAG 프롬프트 디렉터리 경로를 만들어 반환한다
def GRAPHRAG_PROMPTS_DIR(domain):
    return os.path.join(BASE_DIR, "parquet_template", "rendered", domain, "prompts")

# 메일 블록 구분자
MAIL_BLOCK_SEP = "============================================================"

# RAG 엔진은 GraphRAG만 사용한다 (LightRAG 제거)
RAG_ENGINE = "graphrag"


