# PhoTalk 백엔드 Flask 서버. 채팅/질의 잡, 카카오톡 업로드와 인덱싱 파이프라인 실행, SSE 진행 스트림, 통계·관계·요약·아바타 조회 등 앱이 쓰는 REST 엔드포인트.

import datetime
import os
import re
import subprocess
import time
import sys
import json
import threading
import uuid
import openai  
import base64
import requests
import shutil
import zlib
import traceback
import urllib.parse
from dotenv import load_dotenv
from flask import (
    Flask,
    request,
    jsonify,
    send_from_directory,
    Response,
    stream_with_context
)
from flask_cors import CORS
from docx import Document
import olefile
import csv
from pptx import Presentation
from openpyxl import load_workbook

# Job 이용 공통함수 import
from util.jobs.job_store import *
from config.settings import *

# 인덱싱 파이프라인 진입점 (GraphRAG)
from util.jobs.job_run_graphrag import (
    start_graph_pipeline_background,
    start_graph_update_pipeline_background
)

# 날짜 범위 질의(예: "어제 대화 보여줘") 처리 함수
from util.graphrag_date_query import run_date_range_query

from util.user_path import UserPaths, list_accounts, list_indexed_user_ids, set_account_room_name
from util.file_manager import (
    _sanitize_filename
)
from util.attachment_manager import (
    _save_attachment_from_base64,
    _extract_text_from_pdf,
    _extract_text_from_docx,
    _extract_text_from_hwp,
    _extract_text_from_txt,
    _extract_text_from_pptx,
    _extract_text_from_xlsx,
    _extract_text_from_csv,
)
from util.jobs.job_run_graphrag import (
    _summarize_attachment_text,
    _merge_summarized_attachments,
    render_all_prompts,
)
from util.database.db_writer import (
    save_query_to_db,
    filter_unprocessed_attachments,
    mark_attachments_as_processed,
)
from util.database.chatroom_reader import (
    list_indexed_chatrooms,
    get_messenger_date_range,
    get_chatroom_sync_stats,
    get_chatroom_name,
    get_chatroom_people,
    get_chatroom_people_stats,
    get_chatroom_relationships,
    get_chatroom_relationship_stats,
    get_chatroom_person_detail,
    get_chatroom_mood,
    get_chatroom_keywords_by_person,
    get_chatroom_keyword_stats,
    get_chatroom_monthly_message_stats,
    get_chatroom_keyword_monthly_stats,
    get_chatroom_keyword_daily_stats,
    get_chatroom_keyword_mentioners,
    get_chatroom_person_monthly_stats,
    get_chatroom_person_daily_stats,
    get_chatroom_day_messages,
    get_chatroom_summaries,
)
from util.extract_statics import start_statics_pipeline_background
from util.avatar_generator import (
    get_cached_chatroom_people_avatars,
)
from util.sse_broadcaster import (
    subscribe,
    unsubscribe,
    broadcast
)
from config.db import get_db_connection
from util.graphrag import (
    _run_graphrag,
    _is_index_ready
)
from util.graphrag_query import _classify_query_method

# 이 계정의 인덱싱 완료 여부를 반환한다
def _index_ready(paths) -> bool:
    return _is_index_ready(paths)
from util.mail_data_manager import (
    _read_latest_text,
    _extract_message_ids,
    _split_mail_blocks,
    _extract_mail_id_from_block,
    _renumber_mail_blocks,
    _extract_block_for_sort,
    _build_mail_csv
)
from util.file_manager import _delete_incremental_files
from util.message_parser import (
    parse_message_export,
    build_message_blocks,
    guess_room_name,
    build_room_id,
)
# 환경변수 로드
load_dotenv("src/parquet/.env")

# 서버 시작 시 터미널에서 사용할 RAG_ENGINE 출력.
print("=" * 60)
print(f"[RAG_ENGINE] 서버가 사용할 RAG 엔진: {RAG_ENGINE.upper()}")
print("=" * 60)

# Flask 앱 초기화
app = Flask(__name__)
CORS(app)

# 한글 출력 시 깨지거나 에러 나는 것 방지
if hasattr(sys.stdout, "reconfigure"):
    sys.stdout.reconfigure(encoding="utf-8", errors="replace")
if hasattr(sys.stderr, "reconfigure"):
    sys.stderr.reconfigure(encoding="utf-8", errors="replace")

# 질의를 백그라운드 잡으로 등록하고 jobId를 즉시 반환한다 (날짜 범위 → 연합 RAG 검색 순으로 시도)
@app.route('/run-query-async', methods=['POST'])
def run_query_async():
    data = request.json or {}

    print("[DEBUG] content_type =", request.content_type)
    print("[DEBUG] raw body =", request.data)
    print("[DEBUG] parsed data =", data)

    if data is None:
        return jsonify({'error': 'JSON 본문을 읽지 못했습니다.'}), 400

    message = request.json.get('message', '')
    resMethod = request.json.get('resMethod', 'local')
    resType = request.json.get('resType', 'text')
    user_id = data.get('user_id', '').strip()
    domain = (data.get('domain') or 'mail').strip().lower()

    if not str(message).strip():
        return jsonify({'error': 'message가 비어있습니다.'}), 400

    if not user_id:
        return jsonify({'error': 'user_id가 비어있습니다.'}), 400

    print("[DEBUG] message =", repr(message))
    print("[DEBUG] user_id =", repr(user_id))

    job_id = str(uuid.uuid4())[:8]
    create_job(job_id, job_type="query")
    update_job(job_id, status="pending", result=None, resType=resType)

    # 백그라운드 스레드에서 실제 질의를 수행하고 job 상태를 갱신한다
    def _worker():
        try:
            env = os.environ.copy()
            env["USER_ID"] = user_id

            # local/global, 날짜 범위 쿼리 모두 해당 도메인에서 인덱싱된 계정(또는 카카오 대화방) 전체를 대상으로 함(연합 검색).
            accounts_paths = [UserPaths(BASE_DIR, uid, domain) for uid in list_indexed_user_ids(BASE_DIR, domain)]

            # 인덱싱된 계정/방이 하나도 없을 때 프론트가 보낸 user_id로 폴백 경로를 만든다.
            if not accounts_paths:
                accounts_paths = [UserPaths(BASE_DIR, user_id, domain)]

            fallback_paths = accounts_paths[0]

            # accounts_paths 전체(인덱싱된 계정 전부)를 대상으로 연합해서 필터링한다.
            answer = run_date_range_query(message, accounts_paths) if domain == "mail" else None # 이게 None이면 GraphRAG로
            source_ids = []  # 초기화
            if answer is None:
                full_message = message + " 영어 말고 한국어로 답변해줘."

                if True:  # GraphRAG
                    from util.graphrag_query import run_graphrag_query, run_federated_local_search, run_federated_global_search
                    resMethod = _classify_query_method(message)
                    print(f"[QUERY] RAG_ENGINE=graphrag mode={resMethod}")

                    if len(accounts_paths) == 1:
                        # 계정(또는 방)이 하나뿐이면 단일 엔진으로 검색한다.
                        try:
                            answer, source_ids = run_graphrag_query(full_message, message, fallback_paths, method=resMethod)
                        except Exception as e2:
                            print(f"[ENGINE] API 실패, CLI fallback: {e2}")
                            answer = _run_graphrag(full_message, resMethod, message, fallback_paths, resType)
                    elif resMethod == "local":
                        try:
                            answer, source_ids = run_federated_local_search(full_message, message, accounts_paths, primary_user_id=user_id)
                        except Exception as e:
                            print(f"[ENGINE] 연합 검색 실패, 선택된 계정으로 폴백: {e}")
                            try:
                                answer, source_ids = run_graphrag_query(full_message, message, fallback_paths, method=resMethod)
                            except Exception as e2:
                                print(f"[ENGINE] API 실패, CLI fallback: {e2}")
                                answer = _run_graphrag(full_message, resMethod, message, fallback_paths, resType)
                    else:
                        try:
                            answer, source_ids = run_federated_global_search(full_message, message, accounts_paths, primary_user_id=user_id)
                        except Exception as e:
                            print(f"[ENGINE] 연합 글로벌 검색 실패, 선택된 계정으로 폴백: {e}")
                            try: # 엔진 객체 직접 호출 방식
                                answer, source_ids = run_graphrag_query(full_message, message, fallback_paths, method=resMethod)
                            except Exception as e2:
                                # API 방식 실패 시 기존 CLI 방식으로 자동 fallback
                                print(f"[ENGINE] API 실패, CLI fallback: {e2}")
                                answer = _run_graphrag(full_message, resMethod, message, fallback_paths, resType)
                                # source_ids = _extract_source_mail_ids(answer)

            result = answer
            update_job(job_id, status="done", result=result, source_ids=source_ids)

        except Exception as e:
            update_job(job_id, status="error", result=str(e))

    threading.Thread(target=_worker, daemon=True).start()
    return jsonify({"jobId": job_id})

# job_id로 잡의 상태·진행률·결과(text 또는 calendar JSON)·근거 메일 ID를 반환한다
@app.route('/job-status/<job_id>', methods=['GET'])
def job_status(job_id):
    job = get_job(job_id)
    if not job:
        return jsonify({"status": "not_found"}), 404

    if job["status"] == "done" and job["resType"].lower() == "calendar":
        try:
            return jsonify({"status": "done", "data": json.loads(job["result"])})
        except Exception:
            return jsonify({"status": "done", "data": {"events": []}})

    # text 타입: result 필드에 문자열 그대로 반환
    return jsonify({
        "status": job["status"],
        "progress": job.get("progress", 0),
        "message": job.get("message", ""),
        "result": job["result"] or "",
        "source_ids": job.get("source_ids") or [],
    })

# 인덱싱 progress/완료/실패 이벤트를 SSE로 실시간 push한다 (15초마다 keepalive)
@app.route("/indexing-stream", methods=["GET"])
def indexing_stream():
    q = subscribe()

    # 구독 큐에서 이벤트를 꺼내 SSE 형식으로 스트리밍한다
    @stream_with_context
    def generate():
        try:
            while True:
                try:
                    data = q.get(timeout=15)
                    yield f"data: {json.dumps(data, ensure_ascii=False)}\n\n"
                except Exception:
                    yield ": keepalive\n\n"
        finally:
            unsubscribe(q)

    return Response(generate(), content_type="text/event-stream",
                    headers={
                        "Cache-Control": "no-cache",
                        "X-Accel-Buffering": "no",
                        "Connection": "keep-alive",
                        "ngrok-skip-browser-warning": "true",
                    })

# 최근 job 상태 목록(최대 20개, 최신순)을 반환한다 (페이지 로드 시 이전 상태 복원용)
@app.route("/indexing-history", methods=["GET"])
def indexing_history():
    all_jobs = get_all_jobs()
    # 최신순 정렬, 최대 20개
    sorted_jobs = sorted(all_jobs.values(), key=lambda j: j.get("created_at", 0), reverse=True)[:20]
    events = []
    for job in sorted_jobs:
        events.append({
            "type": job.get("status", "idle"),
            "job_id": job.get("job_id"),
            "progress": job.get("progress", 0),
            "message": job.get("message", ""),
        })
    return jsonify(events)

# 질의를 동기로 처리해 답변을 바로 반환한다 (단일 계정, 연합/날짜 검색 없음)
@app.route('/run-query', methods=['POST'])
def run_query():
    data = request.json or {}
    message = data.get('message', '')
    resMethod = data.get('resMethod', 'local')
    resType = data.get('resType', 'text')
    user_id = (data.get('user_id') or '').strip().lower()

    print(f'message: {message}')
    print(f'resMethod: {resMethod}')
    print(f'resType: {resType}')

    if not str(message).strip():
        return jsonify({'error': 'message가 비어있습니다.'}), 400
    if not user_id:
        return jsonify({'error': 'user_id가 비어있습니다.'}), 400

    paths = UserPaths(BASE_DIR, user_id, "mail")
    message += " 영어 말고 한국어로 답변해줘."

    try:
        print(f"[QUERY] GraphRAG mode={resMethod}")
        answer = _run_graphrag(message, resMethod, message, paths, resType)
    except Exception as e:
        return jsonify({'error': str(e)}), 500

    return jsonify({'result': answer})

# 미처리 첨부파일의 텍스트를 추출·요약해 mail_latest.txt에 병합하고 처리 완료로 기록한다 (인덱싱 시작 전에 실행)
def _extract_and_merge_attachments(paths, attachments, user_id):
    unprocessed = filter_unprocessed_attachments(user_id, attachments)
    if not unprocessed:
        return

    # 프롬프트의 최신 상태 유지
    render_all_prompts()

    attachment_texts_by_mail: dict[str, list[dict]] = {}
    for file_info in unprocessed:
        f_name = file_info.get("name") or "attachment.bin"
        mail_id = str(file_info.get("mail_id") or "").strip()
        try:
            saved_path, original_name = _save_attachment_from_base64(file_info, paths.ATTACHMENT_DIR)
            ext = os.path.splitext(original_name)[-1].lower()
            mime = (file_info.get("mime") or "").lower()
            file_text = ""
            if ext == ".pdf" or "pdf" in mime:      file_text = _extract_text_from_pdf(saved_path)
            elif ext == ".docx":                     file_text = _extract_text_from_docx(saved_path)
            elif ext == ".hwp":                      file_text = _extract_text_from_hwp(saved_path)
            elif ext == ".txt" or "plain" in mime:   file_text = _extract_text_from_txt(saved_path)
            elif ext == ".pptx":                     file_text = _extract_text_from_pptx(saved_path)
            elif ext == ".xlsx":                     file_text = _extract_text_from_xlsx(saved_path)
            elif ext == ".csv":                      file_text = _extract_text_from_csv(saved_path)

            if file_text and file_text.strip():
                summary = _summarize_attachment_text(file_text.strip(), paths, original_name)
                attachment_texts_by_mail.setdefault(mail_id, []).append({"name": original_name, "text": summary})
        except Exception as e:
            print(f"[UPLOAD] 첨부파일 추출 실패 {f_name}: {e}")

    if attachment_texts_by_mail:
        _merge_summarized_attachments(paths.MAIL_LATEST_PATH, attachment_texts_by_mail)
        print(f"[UPLOAD] 첨부파일 {len(attachment_texts_by_mail)}건 본문에 병합 완료")

    mark_attachments_as_processed(user_id, unprocessed)

# 메일/대화 텍스트를 받아 mail_latest.txt에 누적(rewrite/append, mail_id 중복 체크)하고 인덱싱 파이프라인을 시작한다
@app.route("/upload", methods=["POST"])
def upload():
    # 1) 데이터 수신
    data = request.json or {}
    filename = data.get("filename") or f"mail_{int(time.time())}.txt"
    mail_platform = (data.get("mail_platform") or "gmail").strip().lower()
    content = data.get("content") or ""
    attachments = data.get("attachment") or []
    requested_mode = data.get("syncmode", "append")
    user_id = (data.get("user_id") or "").strip().lower()
    domain = (data.get("domain") or "mail").strip().lower()
    # 메일은 최신 메일이 위로 오는 "받은편지함" 순서를, 카카오는 대화를 처음부터 읽어내려가는
    # "대화 기록" 순서(오래된 게 위)를 기대하므로 도메인별로 정렬 방향을 다르게 함.
    sort_newest_first = domain != "messenger"

    paths = UserPaths(BASE_DIR, user_id, domain)

    if not str(content).strip():
        return jsonify({"ok": False, "error": "content가 비어있습니다."}), 400
    if not user_id:
        return jsonify({"ok": False, "error": "user_id가 비어있습니다."}), 400

    print("user_id =", user_id)

    # append인데 기존 인덱스가 없으면 rewrite로 전환
    fallback_to_rewrite = False
    sync_mode = requested_mode

    if requested_mode == "append" and not _index_ready(paths):
        print("[UPLOAD] index not ready -> fallback to rewrite")
        sync_mode = "rewrite"
        fallback_to_rewrite = True

    # 2) 저장 디렉토리 준비
    os.makedirs(paths.MAIL_DIR, exist_ok=True)

    if sync_mode == "rewrite":
        # rewrite: input 폴더 내 기존 메일 파일 전체 초기화
        # mail_latest.txt, mail_latest.csv, inc_*.txt 등 전부 삭제
        # 이전 데이터가 남아있으면 중복 체크에 걸려 새 메일이 스킵되는 버그 방지
        if os.path.exists(paths.MAIL_DIR):
            for fname in os.listdir(paths.MAIL_DIR):
                fpath = os.path.join(paths.MAIL_DIR, fname)
                try:
                    if os.path.isfile(fpath):  # 파일만 삭제, 폴더는 건너뜀
                        os.remove(fpath)
                except Exception as e:
                    print(f"[CLEAN] 파일 삭제 실패 (무시): {fpath} / {e}")

            print(f"[CLEAN] input 폴더 초기화 완료: {paths.MAIL_DIR}")
        if os.path.exists(paths.ATTACHMENT_DIR):
            shutil.rmtree(paths.ATTACHMENT_DIR)
            print(f"[CLEAN] attachment 폴더 초기화 완료: {paths.ATTACHMENT_DIR}")

        # lancedb 벡터 인덱스 삭제 
        if RAG_ENGINE == "graphrag":
            lancedb_dir = os.path.join(paths.GRAPHRAG_ROOT, "output", "lancedb")
            if os.path.exists(lancedb_dir):
                shutil.rmtree(lancedb_dir)
                print(f"[CLEAN] lancedb 벡터 인덱스 초기화 완료: {lancedb_dir}")

        # rewrite 완료 전에 첨부파일이 먼저 처리되는 문제 방지. RAG_ENGINE에 맞는 인덱스 준비 여부 판단 기준 파일을 지운다.
        ready_marker_path = os.path.join(paths.GRAPHRAG_ROOT, "output", "stats.json")
        if os.path.exists(ready_marker_path):
            try:
                os.remove(ready_marker_path)
                print(f"[CLEAN] 인덱스 준비 마커 삭제 완료 (rewrite 시작): {ready_marker_path}")
            except Exception as e:
                print(f"[CLEAN] 인덱스 준비 마커 삭제 실패 (무시): {e}")

        try:
            from util.database.db_writer import get_latest_mail_account
            latest_account = get_latest_mail_account(user_id)
            if latest_account:
                conn = get_db_connection()
                cursor = conn.cursor()
                cursor.execute(
                    "DELETE FROM processed_attachments WHERE user_mail_account_id = %s AND index_date = %s",
                    (latest_account["user_mail_account_id"], latest_account["index_date"])
                )
                conn.commit()
                cursor.close()
                conn.close()
            print(f"[CLEAN] processed_attachments DB 초기화 완료 (user_id={user_id})")
        except Exception as e:
            print(f"[CLEAN] processed_attachments DB 초기화 실패 (무시): {e}")

    # 3) 원본 메일 텍스트 저장 (append 모드만 — rewrite는 mail_latest.txt에 바로 씀)
    if sync_mode != "rewrite":
        file_path = os.path.join(paths.MAIL_DIR, filename)
        with open(file_path, "w", encoding="utf-8") as f:
            f.write(content)

    extracted_count = 0
    failed_attachments = []
    valid_attachments = []

    # 4) 첨부파일 메타데이터 카운트
    for file_info in attachments:
        f_name = file_info.get("name") or "attachment.bin"
        mail_id = str(file_info.get("mail_id") or "").strip()
        if f_name and mail_id:
            extracted_count += 1
            valid_attachments.append(file_info)

    # 5) 로그
    print(f"[UPLOAD] Received filename: {filename}")
    print(f"[UPLOAD] Content length: {len(content)}")
    print(f"[UPLOAD] Attachment count received: {len(attachments)}")
    print(f"[UPLOAD] Attachment extracted count: {extracted_count}")
    print(f"[UPLOAD] Requested mode: {requested_mode}")
    print(f"[UPLOAD] Actual mode: {sync_mode}")
    print("[UPLOAD] cwd:", os.getcwd())

    added_count  = 0
    skipped_count = 0
    saved_mail_path = ""

    # 메일 텍스트 누적 로직
    # rewrite: mail_latest.txt를 새로 씀 (기존 내용 무시)
    # append: 기존 mail_latest.txt를 읽어서 합친 후 재저장
    # 공통: mail_id 기반 중복 체크
    if sync_mode == "rewrite":
        existing_text = ""
        existing_ids  = set()
    else:
        existing_text = _read_latest_text(paths)
        existing_ids  = _extract_message_ids(existing_text)

    # 최근 날짜의 블록 스킵하지 않고 최신 내용으로 덮어쓴다
    # 그 외 과거 날짜는 정상 스킵한다
    overwrite_ids = set()
    if domain == "messenger" and existing_ids:
        dated_ids = [i for i in existing_ids if re.match(r"^\d{4}-\d{2}-\d{2}", i)]
        if dated_ids:
            latest_date = max(i[:10] for i in dated_ids)
            overwrite_ids = {i for i in dated_ids if i.startswith(latest_date)}

    new_blocks    = _split_mail_blocks(content)
    append_blocks = []

    for block in new_blocks:
        msg_id = _extract_mail_id_from_block(block)
        if not msg_id:
            skipped_count += 1
            continue
        if msg_id in existing_ids and msg_id not in overwrite_ids:
            skipped_count += 1
            continue
        append_blocks.append(block.strip())
        existing_ids.add(msg_id)

    # overwrite_ids 중 실제로 새 블록이 들어온 것만 "교체 확정"으로 남긴다
    if overwrite_ids:
        replaced_ids = {_extract_mail_id_from_block(b) for b in append_blocks}
        overwrite_ids &= replaced_ids

    added_count = len(append_blocks)

    if sync_mode == "rewrite":
        _delete_incremental_files(paths)

    if append_blocks:
        append_blocks.sort(key=_extract_block_for_sort, reverse=sort_newest_first)
        inc_content = "\n\n".join(append_blocks).strip() + "\n"
        if sync_mode == "rewrite":
            with open(paths.MAIL_LATEST_PATH, "w", encoding="utf-8") as f:
                f.write(_renumber_mail_blocks(inc_content))
        else:
            # append: 기존 내용 앞에 새 메일 추가 후 mail_latest.txt 저장
            existing_lines = existing_text.splitlines()
            existing_clean = "\n".join(existing_lines).lstrip("\n")
            if overwrite_ids:
                # 덮어쓰기 대상(카카오 최신 날짜) 블록은 기존 내용에서 먼저 제거
                kept_blocks = [
                    b for b in _split_mail_blocks(existing_clean)
                    if _extract_mail_id_from_block(b) not in overwrite_ids
                ]
                existing_clean = "\n\n".join(b.strip() for b in kept_blocks).strip()
            updated_content = inc_content + "\n" + existing_clean
            with open(paths.MAIL_LATEST_PATH, "w", encoding="utf-8") as f:
                f.write(_renumber_mail_blocks(updated_content.strip()))

        saved_mail_path = paths.MAIL_LATEST_PATH

        # 새로 추가된 메일 ID 수집
        new_ids = set()
        for block in append_blocks:
            mid = _extract_mail_id_from_block(block)
            if mid:
                new_ids.add(mid)

        # 이메일 전용 statics 파이프라인
        if domain == "mail":
            statics_job_id = str(uuid.uuid4())[:8]
            create_job(statics_job_id, job_type="statics")

            if sync_mode == "rewrite":
                final_text = _read_latest_text(paths)
                statics_blocks = _split_mail_blocks(final_text)
                statics_blocks = [b for b in statics_blocks if _extract_mail_id_from_block(b)]
            else:
                statics_blocks = append_blocks

            start_statics_pipeline_background(
                statics_job_id, paths,
                mode="rewrite" if sync_mode == "rewrite" else "append"
            )

    else:
        saved_mail_path = ""
        new_ids = set()

    print("[UPLOAD] added:", added_count)
    print("[UPLOAD] skipped:", skipped_count)
    if saved_mail_path:
        print("[UPLOAD] saved mail path:", os.path.abspath(saved_mail_path))

    # GraphRAG 파이프라인 실행
    graph_job_id = str(uuid.uuid4())[:8]

    if sync_mode == "rewrite":
        create_job(graph_job_id, job_type="index")
        update_job(graph_job_id, message="업로드 완료, 그래프 파이프라인 시작")
    else:
        create_job(graph_job_id, job_type="update")
        update_job(graph_job_id, message="업로드 완료, 그래프 업데이트 파이프라인 시작")

    env = os.environ.copy()
    env["PYTHONUNBUFFERED"] = "1"

    # 첨부파일은 CSV 빌드 전에 텍스트 추출/요약해서 mail_latest.txt에 미리 병합해둔다 
    if valid_attachments:
        _extract_and_merge_attachments(paths, valid_attachments, user_id)

    if sync_mode == "rewrite":
        update_dir = os.path.join(paths.GRAPHRAG_ROOT, "update_output")
        if os.path.exists(update_dir):
            shutil.rmtree(update_dir)
            print(f"[CLEAN] update_output 삭제 완료: {update_dir}")

        # _build_mail_csv는 동기 실행 후 GraphRAG 스레드 시작
        # CSV 파일이 완전히 쓰인 뒤 GraphRAG가 읽도록 순서 보장
        _build_mail_csv(paths)
        final_text = _read_latest_text(paths)
        total_mail_count = len([b for b in _split_mail_blocks(final_text) if _extract_mail_id_from_block(b)])
        print(f"[INDEX] RAG_ENGINE={RAG_ENGINE} 로 전체 인덱싱(rewrite) 시작 job_id={graph_job_id}")
        start_graph_pipeline_background(graph_job_id, paths, env, added_count=total_mail_count, mail_platform=mail_platform)

    else:  # append
        if new_ids:
            # _build_mail_csv 반환값 None 체크 추가
            # new_ids 없을 때 None 반환하도록 수정했으므로 None이면 update 생략
            csv_path = _build_mail_csv(paths, mode="append", new_ids=new_ids)
            if csv_path:
                print(f"[INDEX] RAG_ENGINE={RAG_ENGINE} 로 증분 업데이트 시작 job_id={graph_job_id}")
                start_graph_update_pipeline_background(graph_job_id, paths, env)
            else:
                update_job(graph_job_id, status="done", message="CSV 없음, 업데이트 생략")
                print("[UPLOAD] CSV 생성 실패 → graphrag update 생략")
        else:
            # 증분 대상(new_ids)이 없으면 rewrite 파이프라인으로 전환한다
            print("[UPLOAD] new_ids 없음 → 증분할 새 메일 없음, 전체 재인덱싱으로 전환")
            update_job(graph_job_id, message="증분 대상 없음 → 전체 재인덱싱으로 전환")

            _build_mail_csv(paths)
            final_text = _read_latest_text(paths)
            total_mail_count = len([b for b in _split_mail_blocks(final_text) if _extract_mail_id_from_block(b)])
            print(f"[INDEX] RAG_ENGINE={RAG_ENGINE} 로 전체 인덱싱(rewrite, 증분 폴백) 시작 job_id={graph_job_id}")
            start_graph_pipeline_background(graph_job_id, paths, env, added_count=total_mail_count, mail_platform=mail_platform)
            sync_mode = "rewrite"  # 응답 필드(actual_mode)에도 실제로 rewrite로 처리됐음을 반영
            fallback_to_rewrite = True  # index-not-ready 폴백과 같은 필드로 프론트에 "요청과 다르게 처리됨"을 알림

    return jsonify({
        "ok": True,
        "requested_mode": requested_mode,
        "job_id": graph_job_id,
        "actual_mode": sync_mode,
        "fallback_to_rewrite": fallback_to_rewrite,
        "latest_path": os.path.abspath(paths.MAIL_LATEST_PATH),
        "saved_mail_path": os.path.abspath(saved_mail_path) if saved_mail_path else "",
        "attachment_dir": os.path.abspath(paths.ATTACHMENT_DIR),
        "content_length": len(content),
        "added_count": added_count,
        "skipped_count": skipped_count,
        "attachment_received_count": len(attachments),
        "attachment_extracted_count": extracted_count,
        "failed_attachments": failed_attachments,
    })

# 이 계정의 그래프 시각화용 JSON(nodes/edges)을 반환한다 (엔진별 경로에서 읽고 없으면 빈 그래프)
@app.route("/graph-data", methods=["GET", "OPTIONS"])
def graph_data():
    if request.method == "OPTIONS":
        return "", 200

    user_id = (request.args.get("user_id") or "").strip().lower()
    domain = (request.args.get("domain") or "mail").strip().lower()

    if not user_id:
        return jsonify({"ok": False, "error": "user_id가 비어있습니다."}), 400

    paths = UserPaths(BASE_DIR, user_id, domain)

    graph_json_path = paths.GRAPH_JSON_PATH

    if not os.path.exists(graph_json_path):
        return jsonify({"nodes": [], "edges": [], "error": "graph json not found"}), 200

    try:
        with open(graph_json_path, "rb") as f:
            raw = f.read().rstrip(b'\x00')  # null 바이트 제거 (비정상 종료 방어)
        data = json.loads(raw.decode("utf-8"))
        print(f"[GRAPH-DATA] 반환: {len(data.get('nodes', []))} 노드")
        return jsonify(data)
    except Exception as e:
        print(f"[GRAPH-DATA] 에러: {e}")
        return jsonify({"nodes": [], "edges": [], "error": str(e)}), 500


# 채팅방 참여자 아바타 이미지 파일을 서빙한다
@app.route("/chatroom-person-avatar-image/<chatroom_id>/<filename>")
def chatroom_person_avatar_image(chatroom_id, filename):
    paths = UserPaths(BASE_DIR, chatroom_id, "messenger")
    return send_from_directory(paths.MESSAGE_AVATAR_IMAGES_DIR, filename)


# 메신저 기간 요약 삽화 이미지 파일을 서빙한다
@app.route("/message-summary-image/<chatroom_id>/<filename>")
def message_summary_image(chatroom_id, filename):
    paths = UserPaths(BASE_DIR, chatroom_id, "messenger")
    return send_from_directory(paths.MESSAGE_SUMMARY_IMAGES_DIR, filename)


# 단톡방 목록(이름·메시지 수·참여자)을 반환한다 (기간 지정 시 그 기간 집계)
@app.route("/messenger-chatrooms", methods=["POST"])
def send_messenger_chatrooms():
    data = request.json or {}
    start_date = (data.get("start_date") or "").strip() or None
    end_date   = (data.get("end_date") or "").strip() or None
    chatrooms = list_indexed_chatrooms(BASE_DIR, start_date, end_date)
    return jsonify({"data": {"chatrooms": chatrooms}})

# 인덱싱된 모든 단톡방을 통틀어 가장 이른/늦은 메시지 날짜를 반환한다
@app.route("/messenger-date-range", methods=["POST"])
def send_messenger_date_range():
    return jsonify({"data": get_messenger_date_range(BASE_DIR)})

# 채팅방의 가장 최근 인덱싱 메시지 수·소요 시간·날짜를 반환한다
@app.route("/chatroom-sync-stats", methods=["POST"])
def send_chatroom_sync_stats():
    data = request.json or {}
    chatroom_id = data.get("chatroom_id", "").strip()

    if not chatroom_id:
        return jsonify({"error": "chatroom_id is required"}), 400

    return jsonify({
        "chatroom_id": chatroom_id,
        "data": get_chatroom_sync_stats(chatroom_id),
    })

# chatroom_id로 방 이름을 반환한다
@app.route("/chatroom-name", methods=["POST"])
def send_chatroom_name():
    data = request.json or {}
    chatroom_id = data.get("chatroom_id", "").strip()
    if not chatroom_id:
        return jsonify({"error": "chatroom_id is required"}), 400

    chatroom_name = get_chatroom_name(chatroom_id)
    if chatroom_name is None:
        return jsonify({"error": "chatroom not found"}), 404

    return jsonify({
        "chatroom_id": chatroom_id,
        "data": {"chatroom_name": chatroom_name},
    })

# 채팅방 참여자 목록(이름·메시지 수·설명·아바타)을 반환한다
@app.route("/chatroom-people", methods=["POST"])
def send_chatroom_people():
    data = request.json or {}
    chatroom_id = data.get("chatroom_id", "").strip()

    if not chatroom_id:
        return jsonify({"error": "chatroom_id is required"}), 400

    people = get_chatroom_people(chatroom_id)
    if people is None:
        return jsonify({"error": "chatroom not found"}), 404

    paths = UserPaths(BASE_DIR, chatroom_id, "messenger")
    avatar_map = get_cached_chatroom_people_avatars(paths)
    for p in people:
        p["avatar_url"] = avatar_map.get(p["participant_id"])

    return jsonify({
        "chatroom_id": chatroom_id,
        "data": {"people": people},
    })

# 채팅방에 실제 저장된 사람-사람 관계를 relation_label별 개수·순위로 반환한다
@app.route("/chatroom-relationship-stats", methods=["POST"])
def send_chatroom_relationship_stats():
    data = request.json or {}
    chatroom_id = data.get("chatroom_id", "").strip()

    if not chatroom_id:
        return jsonify({"error": "chatroom_id is required"}), 400

    stats = get_chatroom_relationship_stats(chatroom_id)
    if stats is None:
        return jsonify({"error": "chatroom not found"}), 404

    return jsonify({
        "chatroom_id": chatroom_id,
        "data": stats,
    })

# 지정 기간에 활동한 참여자들 사이의 사람-사람 관계 목록을 반환한다
@app.route("/chatroom-relationships", methods=["POST"])
def send_chatroom_relationships():
    data = request.json or {}
    chatroom_id = data.get("chatroom_id", "").strip()
    start_date  = data.get("start_date", "").strip()
    end_date    = data.get("end_date", "").strip()

    if not chatroom_id:
        return jsonify({"error": "chatroom_id is required"}), 400
    if not start_date or not end_date:
        return jsonify({"error": "start_date and end_date are required"}), 400

    # 필터링 기준으로 쓸 활동 참여자 이름 집합이 필요
    people = get_chatroom_people_stats(chatroom_id, start_date, end_date)
    if people is None:
        return jsonify({"error": "chatroom not found"}), 404

    paths = UserPaths(BASE_DIR, chatroom_id, "messenger")
    active_names = {p["name"] for p in people}
    relationships = get_chatroom_relationships(paths, active_names)

    return jsonify({
        "chatroom_id": chatroom_id,
        "start_date":  start_date,
        "end_date":    end_date,
        "data": {
            "relationships": relationships,
        },
    })

# 채팅방 참여자 명단의 프로필 설명과 지정 기간 메시지 수·아바타를 반환한다
@app.route("/chatroom-person-detail", methods=["POST"])
def send_chatroom_person_detail():
    data = request.json or {}
    chatroom_id    = data.get("chatroom_id", "").strip()
    participant_id = data.get("participant_id", "").strip() or None
    start_date     = data.get("start_date", "").strip()
    end_date       = data.get("end_date", "").strip()

    if not chatroom_id:
        return jsonify({"error": "chatroom_id is required"}), 400
    if not start_date or not end_date:
        return jsonify({"error": "start_date and end_date are required"}), 400

    people = get_chatroom_person_detail(chatroom_id, start_date, end_date, participant_id)
    if people is None:
        if participant_id:
            return jsonify({"error": "person not found"}), 404
        return jsonify({"error": "chatroom not found"}), 404

    paths = UserPaths(BASE_DIR, chatroom_id, "messenger")
    avatar_map = get_cached_chatroom_people_avatars(paths)
    for p in people:
        p["avatar_url"] = avatar_map.get(p["participant_id"])

    return jsonify({
        "chatroom_id":    chatroom_id,
        "participant_id": participant_id,
        "start_date":     start_date,
        "end_date":       end_date,
        "data": {
            "people": people,
        },
    })

# 채팅방의 지정 기간 월별/연별 분위기 점수·설명을 반환한다
@app.route("/chatroom-mood", methods=["POST"])
def send_chatroom_mood():
    data = request.json or {}
    chatroom_id = data.get("chatroom_id", "").strip()
    start_date  = data.get("start_date", "").strip()
    end_date    = data.get("end_date", "").strip()

    if not chatroom_id:
        return jsonify({"error": "chatroom_id is required"}), 400
    if not start_date or not end_date:
        return jsonify({"error": "start_date and end_date are required"}), 400

    mood = get_chatroom_mood(chatroom_id, start_date, end_date)
    if mood is None:
        return jsonify({"error": "chatroom not found"}), 404

    return jsonify({
        "chatroom_id": chatroom_id,
        "start_date":  start_date,
        "end_date":    end_date,
        "data": mood,
    })

# 특정 참여자가 지정 기간에 사용한 키워드별 언급 횟수를 반환한다
@app.route("/chatroom-keywords-by-person", methods=["POST"])
def send_chatroom_keywords_by_person():
    data = request.json or {}
    chatroom_id    = data.get("chatroom_id", "").strip()
    participant_id = data.get("participant_id", "").strip()
    start_date     = data.get("start_date", "").strip()
    end_date       = data.get("end_date", "").strip()

    if not chatroom_id:
        return jsonify({"error": "chatroom_id is required"}), 400
    if not participant_id:
        return jsonify({"error": "participant_id is required"}), 400
    if not start_date or not end_date:
        return jsonify({"error": "start_date and end_date are required"}), 400

    keywords = get_chatroom_keywords_by_person(chatroom_id, start_date, end_date, participant_id)
    if keywords is None:
        return jsonify({"error": "chatroom not found"}), 404
    if keywords is False:
        return jsonify({"error": "person not found"}), 404

    return jsonify({
        "chatroom_id":    chatroom_id,
        "participant_id": participant_id,
        "start_date":     start_date,
        "end_date":       end_date,
        "data": {
            "keywords": keywords,
        },
    })

# 채팅방 전체(모든 참여자·전체 기간 합산)의 키워드별 총 언급 수를 순위(내림차순)로 반환한다
@app.route("/chatroom-keyword-stats", methods=["POST"])
def send_chatroom_keyword_stats():
    data = request.json or {}
    chatroom_id = data.get("chatroom_id", "").strip()

    if not chatroom_id:
        return jsonify({"error": "chatroom_id is required"}), 400

    stats = get_chatroom_keyword_stats(chatroom_id)
    if stats is None:
        return jsonify({"error": "chatroom not found"}), 404

    return jsonify({
        "chatroom_id": chatroom_id,
        "data": stats,
    })

# 채팅방 전체의 월별 메시지 수(송수신 횟수)를 반환한다
@app.route("/chatroom-monthly-message-stats", methods=["POST"])
def send_chatroom_monthly_message_stats():
    data = request.json or {}
    chatroom_id = data.get("chatroom_id", "").strip()

    if not chatroom_id:
        return jsonify({"error": "chatroom_id is required"}), 400

    stats = get_chatroom_monthly_message_stats(chatroom_id)
    if stats is None:
        return jsonify({"error": "chatroom not found"}), 404

    return jsonify({
        "chatroom_id": chatroom_id,
        "data": {"monthly": stats},
    })

# 채팅방 전체(모든 참여자 합산)의 월별 키워드 목록·언급 수를 반환한다
@app.route("/chatroom-keyword-monthly-stats", methods=["POST"])
def send_chatroom_keyword_monthly_stats():
    data = request.json or {}
    chatroom_id = data.get("chatroom_id", "").strip()
    start_date  = (data.get("start_date") or "").strip() or None
    end_date    = (data.get("end_date") or "").strip() or None

    if not chatroom_id:
        return jsonify({"error": "chatroom_id is required"}), 400

    stats = get_chatroom_keyword_monthly_stats(chatroom_id, start_date, end_date)
    if stats is None:
        return jsonify({"error": "chatroom not found"}), 404

    return jsonify({
        "chatroom_id": chatroom_id,
        "data": stats,
    })

# 채팅방 전체가 특정 월에 날짜별로 언급한 키워드 목록·횟수를 반환한다
@app.route("/chatroom-keyword-daily-stats", methods=["POST"])
def send_chatroom_keyword_daily_stats():
    data = request.json or {}
    chatroom_id = data.get("chatroom_id", "").strip()
    month       = data.get("month", "").strip()

    if not chatroom_id:
        return jsonify({"error": "chatroom_id is required"}), 400
    if not month:
        return jsonify({"error": "month is required"}), 400

    stats = get_chatroom_keyword_daily_stats(chatroom_id, month)
    if stats is None:
        return jsonify({"error": "chatroom not found"}), 404

    return jsonify({
        "chatroom_id": chatroom_id,
        "month":       month,
        "data": stats,
    })

# 특정 날짜에 특정 키워드를 언급한 참여자 목록(이름·횟수·아바타)을 반환한다
@app.route("/chatroom-keyword-mentioners", methods=["POST"])
def send_chatroom_keyword_mentioners():
    data = request.json or {}
    chatroom_id = data.get("chatroom_id", "").strip()
    date        = data.get("date", "").strip()
    keyword     = data.get("keyword", "").strip()

    if not chatroom_id:
        return jsonify({"error": "chatroom_id is required"}), 400
    if not date:
        return jsonify({"error": "date is required"}), 400
    if not keyword:
        return jsonify({"error": "keyword is required"}), 400

    mentioners = get_chatroom_keyword_mentioners(chatroom_id, date, keyword)
    if mentioners is None:
        return jsonify({"error": "chatroom not found"}), 404

    paths = UserPaths(BASE_DIR, chatroom_id, "messenger")
    avatar_map = get_cached_chatroom_people_avatars(paths)
    for m in mentioners:
        m["avatar_url"] = avatar_map.get(m["participant_id"])

    return jsonify({
        "chatroom_id": chatroom_id,
        "date":        date,
        "keyword":     keyword,
        "data": mentioners,
    })

# 특정 참여자가 월별로 보낸 메시지 수를 반환한다
@app.route("/chatroom-person-monthly-stats", methods=["POST"])
def send_chatroom_person_monthly_stats():
    data = request.json or {}
    chatroom_id    = data.get("chatroom_id", "").strip()
    participant_id = data.get("participant_id", "").strip()
    start_date     = (data.get("start_date") or "").strip() or None
    end_date       = (data.get("end_date") or "").strip() or None

    if not chatroom_id:
        return jsonify({"error": "chatroom_id is required"}), 400
    if not participant_id:
        return jsonify({"error": "participant_id is required"}), 400

    stats = get_chatroom_person_monthly_stats(chatroom_id, participant_id, start_date, end_date)
    if stats is None:
        return jsonify({"error": "chatroom not found"}), 404
    if stats is False:
        return jsonify({"error": "person not found"}), 404

    return jsonify({
        "chatroom_id":    chatroom_id,
        "participant_id": participant_id,
        "data": stats,
    })

# 특정 참여자가 특정 월에 날짜별로 보낸 메시지 수를 반환한다
@app.route("/chatroom-person-daily-stats", methods=["POST"])
def send_chatroom_person_daily_stats():
    data = request.json or {}
    chatroom_id    = data.get("chatroom_id", "").strip()
    participant_id = data.get("participant_id", "").strip()
    month          = data.get("month", "").strip()

    if not chatroom_id:
        return jsonify({"error": "chatroom_id is required"}), 400
    if not participant_id:
        return jsonify({"error": "participant_id is required"}), 400
    if not month:
        return jsonify({"error": "month is required"}), 400

    stats = get_chatroom_person_daily_stats(chatroom_id, participant_id, month)
    if stats is None:
        return jsonify({"error": "chatroom not found"}), 404
    if stats is False:
        return jsonify({"error": "person not found"}), 404

    return jsonify({
        "chatroom_id":    chatroom_id,
        "participant_id": participant_id,
        "month":          month,
        "data": stats,
    })

# 채팅방의 특정 날짜 하루치 대화 원문 메시지를 시간순으로 반환한다
@app.route("/chatroom-day-messages", methods=["POST"])
def send_chatroom_day_messages():
    data = request.json or {}
    chatroom_id = data.get("chatroom_id", "").strip()
    date        = data.get("date", "").strip()

    if not chatroom_id:
        return jsonify({"error": "chatroom_id is required"}), 400
    if not date:
        return jsonify({"error": "date is required"}), 400

    messages = get_chatroom_day_messages(BASE_DIR, chatroom_id, date)
    if messages is None:
        return jsonify({"error": "chatroom not found"}), 404

    return jsonify({
        "chatroom_id": chatroom_id,
        "date":        date,
        "data": {"messages": messages},
    })

# 채팅방의 월별/연별 LLM 요약을 주요 연락처(설명 포함)와 함께 반환한다
@app.route("/chatroom-summaries", methods=["POST"])
def send_chatroom_summaries():
    data = request.json or {}
    chatroom_id    = data.get("chatroom_id", "").strip()
    summarize_unit = data.get("summarize_unit", "").strip()

    if not chatroom_id:
        return jsonify({"error": "chatroom_id is required"}), 400
    if summarize_unit not in ("monthly", "yearly"):
        return jsonify({"error": "summarize_unit must be 'monthly' or 'yearly'"}), 400

    summaries = get_chatroom_summaries(chatroom_id, summarize_unit)
    if summaries is None:
        return jsonify({"error": "chatroom not found"}), 404

    people = get_chatroom_people(chatroom_id) or []
    people_map = {p["name"]: p for p in people}

    for s in summaries:
        s["contacts"] = [
            {
                "person_name": name,
                "description": people_map.get(name, {}).get("description"),
                "short_bio":    people_map.get(name, {}).get("short_bio"),
            }
            for name in s["contacts"]
        ]

    return jsonify({
        "chatroom_id":    chatroom_id,
        "summarize_unit": summarize_unit,
        "data": {
            "summaries": summaries,
        },
    })


# 메신저 federated_local_search 근거메신저 보기용 — 블록 ID("2022-08-21_01" 형태)로
# 그 대화 블록 원문을 반환한다. (mail-body-by-ids의 메신저 버전)
# get_chatroom_day_messages/get_chatroom_name(통계 DB, extract_statics 파이프라인 결과물)를
# 처음엔 재사용했으나, graphrag로만 인덱싱되고 통계 DB엔 없는 계정(예: 이 테스트 계정들)에서
# "채팅방을 찾을 수 없습니다"로 항상 실패했다 — 인덱싱과 통계 추출은 서로 다른 파이프라인이라
# 통계 DB에 없을 수 있음. 대신 graphrag가 실제로 읽은 원본 documents.parquet을 직접 파싱하는
# _parse_message_blocks_from_parquet()를 써서 DB 의존을 아예 없앴다 — 이러면 하루 전체가 아니라
# 인용된 그 블록(ID)만 정확히 보여줄 수 있다는 부수 이점도 있음.
@app.route("/messenger-body-by-ids", methods=["POST"])
def send_messenger_body_by_ids():
    from util.message_statics import _parse_message_blocks_from_parquet

    data = request.json or {}
    # .get(key, "")는 키가 아예 없을 때만 기본값을 쓰고, 값이 명시적으로 null(None)이면
    # 그대로 None을 반환한다 — account 역매칭 실패 시 프론트가 account: null을 보내는
    # 경우가 있어 (or "")로 한 번 더 방어한다.
    account = (data.get("account") or "").strip()
    mail_id = (data.get("mail_id") or "").strip()  # 메신저 블록 ID, 예: "2022-08-21_01"

    if not account:
        return jsonify({"error": "account is required"}), 400
    if not mail_id:
        return jsonify({"error": "mail_id is required"}), 400

    paths = UserPaths(BASE_DIR, account, "messenger")
    blocks = _parse_message_blocks_from_parquet(paths)
    block = next((b for b in blocks if b.get("block_id") == mail_id), None)
    if block is None:
        return jsonify({"error": "대화를 찾을 수 없습니다."}), 404

    return jsonify({
        "id": mail_id,
        "account": account,
        "room_name": block.get("chatroom_name") or account,
        "date": block.get("block_date") or "",
        "messages": block.get("messages") or [],
    })


# 카카오톡 대화 내보내기(.txt)를 파싱해 messenger 도메인으로 업로드/인덱싱하는 백그라운드 잡을 시작한다
@app.route("/message-upload", methods=["POST"])
def message_upload():
    data = request.json or {}
    raw_text = data.get("content") or ""
    room_name_input = (data.get("room_name") or "").strip()
    sync_mode = data.get("sync_mode") or "append"
    filename_hint = (data.get("filename") or "").strip()

    if not raw_text.strip():
        return jsonify({"ok": False, "error": "대화 내용이 비어있습니다."}), 400

    room_name = room_name_input or guess_room_name(raw_text, filename_hint or "카카오톡 대화")
    room_id = build_room_id(room_name)

    # 인덱싱이 끝나기 전에 account.json에 미리 저장
    try:
        set_account_room_name(UserPaths(BASE_DIR, room_id, "messenger"), room_name)
    except Exception as e:
        print(f"[WARN] set_account_room_name 실패(치명적이지 않음): {e}")

    job_id = str(uuid.uuid4())[:8]
    create_job(job_id, job_type="message_upload")

    # 백그라운드에서 대화를 파싱해 블록으로 만들고 /upload로 인덱싱까지 위임한다
    def _worker():
        update_job(job_id, status="running", message="카카오톡 대화 파싱 중")
        broadcast({"type": "progress", "job_id": job_id, "message": "카카오톡 대화 파싱 중"})

        try:
            messages = parse_message_export(raw_text)
            blocks = build_message_blocks(messages, room_name)
        except Exception as e:
            traceback.print_exc()
            update_job(job_id, status="error", message="실패", error=f"파싱 중 오류: {e}")
            broadcast({"type": "failed", "job_id": job_id, "message": f"파싱 중 오류: {e}"})
            return

        if not blocks:
            result = {"ok": True, "added_count": 0, "skipped_count": 0, "message": "파싱된 대화가 없습니다.", "room_id": room_id}
            update_job(job_id, status="done", message="완료", result=result)
            broadcast({"type": "done", "job_id": job_id, "message": "완료", "result": result})
            return

        content = "\n\n".join(blocks).strip() + "\n"
        filename = f"message_{datetime.datetime.now().strftime('%Y-%m-%d_%H%M%S')}.txt"

        update_job(job_id, message="파싱한 대화 저장/인덱싱 준비 중")
        broadcast({"type": "progress", "job_id": job_id, "message": "파싱한 대화 저장/인덱싱 준비 중"})

        try:
            with app.test_request_context(
                "/upload", method="POST",
                json={
                    "filename": filename,
                    "content": content,
                    "attachment": [],
                    "syncmode": sync_mode,
                    "user_id": room_id,
                    "mail_platform": "message",
                    "domain": "messenger",
                },
                content_type="application/json",
            ):
                result = upload()
        except Exception as e:
            traceback.print_exc()
            update_job(job_id, status="error", message="실패", error=f"업로드 처리 중 오류: {e}")
            broadcast({"type": "failed", "job_id": job_id, "message": f"업로드 처리 중 오류: {e}"})
            return

        body, status_code = result if isinstance(result, tuple) else (result, 200)
        try:
            body_data = body.get_json()
        except Exception:
            body_data = None

        if status_code >= 400 or not body_data:
            error_msg = (body_data or {}).get("error", "업로드 처리 실패")
            update_job(job_id, status="error", message="실패", error=error_msg)
            broadcast({"type": "failed", "job_id": job_id, "message": error_msg})
            return

        body_data["room_id"] = room_id
        body_data["room_name"] = room_name
        update_job(job_id, status="done", message="완료", result=body_data)
        broadcast({"type": "done", "job_id": job_id, "message": "완료", "result": body_data})

    threading.Thread(target=_worker, daemon=True).start()
    return jsonify({"ok": True, "jobId": job_id, "room_id": room_id, "room_name": room_name})

# 메신저 업로드 잡의 상태·메시지·결과·에러를 반환한다
@app.route('/message-upload-status/<job_id>', methods=['GET'])
def message_upload_status(job_id):
    job = get_job(job_id)
    if not job:
        return jsonify({"status": "not_found"}), 404

    return jsonify({
        "status": job["status"],
        "message": job.get("message", ""),
        "result": job.get("result"),
        "error": job.get("error"),
    })

# 해당 도메인의 계정(또는 대화방) 목록을 반환한다
@app.route("/accounts", methods=["GET"])
def accounts_route():
    domain = (request.args.get("domain") or "mail").strip().lower()
    return jsonify({"accounts": list_accounts(BASE_DIR, domain)})


if __name__ == '__main__':
    app.run(host='0.0.0.0', port=80, debug=False)