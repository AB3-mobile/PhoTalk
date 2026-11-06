# 사용자 ID 발급, 인덱싱 비용 집계, 질의 기록을 user DB에 저장한다.

# Utility functions for user ID lookup, indexing cost stats, and query logging in the user database.

import os
import json
import uuid
import datetime
from config.db import get_db_connection

# user 테이블의 user_id를 조회하고, 없으면 새 UUID를 발급해 저장한 뒤 반환한다
def get_or_create_user_id(user_mail_account_id: str) -> str:
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT user_id FROM user LIMIT 1")
        row = cursor.fetchone()
        if row:
            return row[0]

        new_user_id = str(uuid.uuid4())
        cursor.execute("INSERT INTO user (user_id) VALUES (%s)", (new_user_id,))
        conn.commit()
        return new_user_id
    finally:
        cursor.close()
        conn.close()


_MODEL_COST_PER_1M = {
    "gpt-4o-mini": {"input": 0.150, "output": 0.600},
    "gpt-4o": {"input": 2.50,  "output": 10.00},
    "gpt-5.4-mini": {"input": 0.75,  "output": 4.50},
}

_EMBED_COST_PER_1M = {
    "text-embedding-3-small": 0.02,
    "text-embedding-3-large": 0.13,
    "text-embedding-ada-002": 0.10,
}

# 채팅 모델의 입출력 토큰 수로 USD 비용을 계산한다
def _calc_cost_usd(model_name: str, input_tokens: int, output_tokens: int) -> float:
    costs = _MODEL_COST_PER_1M.get(model_name, {"input": 0.0, "output": 0.0})
    return (input_tokens * costs["input"] + output_tokens * costs["output"]) / 1_000_000

# 임베딩 모델의 토큰 수로 USD 비용을 계산한다
def _calc_embed_cost_usd(model_name: str, total_tokens: int) -> float:
    cost = _EMBED_COST_PER_1M.get(model_name, 0.0)
    return (total_tokens * cost) / 1_000_000


# GraphRAG 캐시 폴더를 읽어 인덱싱에 쓴 LLM/임베딩 호출 수·토큰·비용을 집계한 dict를 반환한다
def collect_indexing_stats(paths) -> dict:
    LLM_FOLDERS = ["community_reporting", "extract_graph", "summarize_descriptions"]
    EMBED_FOLDER = "text_embedding"

    cache_dir = os.path.join(paths.GRAPHRAG_ROOT, "cache")

    llm_calls = 0
    input_tokens = 0
    output_tokens = 0
    # 인덱싱 온오프 스위치(INDEXING_COMPLETION_MODEL_ID)가 실제로 가리키는 모델을 그대로 라벨링.
    # "indexing_chat_model"이면 로컬(INDEXING_CHAT_MODEL), 아니면("default_chat_model") OpenAI(RAG_CHAT_MODEL).
    if os.getenv("INDEXING_COMPLETION_MODEL_ID") == "indexing_chat_model":
        llm_model = os.getenv("INDEXING_CHAT_MODEL", "")
    else:
        llm_model = os.getenv("RAG_CHAT_MODEL", "")

    embed_calls = 0
    embed_tokens = 0
    if os.getenv("INDEXING_EMBEDDING_MODEL_ID") == "indexing_embedding_model":
        embed_model = os.getenv("INDEXING_EMBEDDING_MODEL", "")
    else:
        embed_model = os.getenv("RAG_EMBEDDING_MODEL", "")

    for folder in LLM_FOLDERS:
        folder_path = os.path.join(cache_dir, folder)
        if not os.path.exists(folder_path):
            continue
        for fname in os.listdir(folder_path):
            fpath = os.path.join(folder_path, fname)
            try:
                with open(fpath, "r", encoding="utf-8") as f:
                    data = json.load(f)
                response = data.get("result", {}).get("response", {})  # v3 캐시 구조: result.response 아래에에 usage/model
                usage = response.get("usage", {})
                llm_calls += 1
                input_tokens += usage.get("prompt_tokens", 0)
                output_tokens += usage.get("completion_tokens", 0)
            except Exception as e:
                print(f"[WARN] LLM 캐시 읽기 실패 {fpath}: {e}")

    embed_path = os.path.join(cache_dir, EMBED_FOLDER)
    if os.path.exists(embed_path):
        for fname in os.listdir(embed_path):
            fpath = os.path.join(embed_path, fname)
            try:
                with open(fpath, "r", encoding="utf-8") as f:
                    data = json.load(f)
                response = data.get("result", {}).get("response", {})  # v3 캐시 구조: result.response 아래에 usage/model
                usage = response.get("usage", {})
                embed_calls += 1
                embed_tokens += usage.get("total_tokens", 0)
            except Exception as e:
                print(f"[WARN] 임베딩 캐시 읽기 실패 {fpath}: {e}")

    cost_usd = (
        _calc_cost_usd(llm_model, input_tokens, output_tokens)
        + _calc_embed_cost_usd(embed_model, embed_tokens)
    )

    print(
        f"[STATS] llm={llm_calls}calls in={input_tokens} out={output_tokens} model={llm_model} | "
        f"embed={embed_calls}calls tokens={embed_tokens} model={embed_model} | cost=${cost_usd:.6f}"
    )
    return {
        "llm_calls": llm_calls,
        "input_tokens": input_tokens,
        "output_tokens": output_tokens,
        "llm_model": llm_model,
        "embed_calls": embed_calls,
        "embed_tokens": embed_tokens,
        "embed_model": embed_model,
        "cost_usd": cost_usd,
    }


# 질의 1건(질문·응답 시간·스코프·토큰·비용·답변·근거)을 query 테이블에 저장한다
def save_query_to_db(
    user_mail_account_id: str,
    context: str,
    response_time: float,
    scope: str = "",
    model_name: str = None,
    input_tokens: int = None,
    output_tokens: int = None,
    answer: str = None,
    refer_kg: str = None,
):
    user_id = get_or_create_user_id(user_mail_account_id)

    cost_usd = None
    if model_name and input_tokens is not None and output_tokens is not None:
        cost_usd = _calc_cost_usd(model_name, input_tokens, output_tokens)

    normalized_scope = scope if scope in ("local", "global") else "other"

    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            INSERT INTO query
                (query_id, user_id, context, response_time, scope, response_date,
                 model_name, input_tokens, output_tokens, cost_usd, answer, refer_kg)
            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
            """,
            (
                str(uuid.uuid4()),
                user_id,
                context,
                round(response_time, 5),
                normalized_scope,
                datetime.datetime.now(),
                model_name,
                input_tokens,
                output_tokens,
                cost_usd,
                answer,
                refer_kg,
            )
        )
        conn.commit()
        print(f"[DB] query 저장 완료: {user_mail_account_id} / {response_time:.2f}s / {normalized_scope} / {model_name} / in={input_tokens} out={output_tokens} cost=${cost_usd} / refer_kg={refer_kg}")
    except Exception as e:
        conn.rollback()
        print(f"[ERROR] save_query_to_db 실패: {e}")
    finally:
        cursor.close()
        conn.close()
