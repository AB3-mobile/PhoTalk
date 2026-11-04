# 메일 블록 텍스트를 병합·분할·재정렬하고, mail_latest.txt를 CSV로 변환하거나 parquet에서 메일 본문을 조회하는 등 메일 데이터를 관리한다.

# Manages mail block text — merging attachments in, splitting/renumbering blocks, converting mail_latest.txt to CSV, and looking up mail bodies from parquet.

import re
import datetime
import os
import csv

from config.settings import *

# 메일/메시지 블록에서 ID 값을 추출한다 (없으면 None)
def _extract_mail_id_from_block(block: str) -> str | None:
    m = re.search(r"^\s*(?:\[ID\]|ID:)\s*(.+?)\s*$", block, re.MULTILINE)
    return m.group(1).strip() if m else None


# 전체 텍스트를 구분자로 잘라 메일 블록 문자열 리스트로 반환한다 (앞뒤 구분자 보정)
def _split_mail_blocks(text):
    parts = text.split(MAIL_BLOCK_SEP)
    blocks = []

    for p in parts:
        p = p.strip()
        if not p:
            continue
        block = MAIL_BLOCK_SEP + "\n" + p
        if not block.endswith(MAIL_BLOCK_SEP):
            block += "\n" + MAIL_BLOCK_SEP
        blocks.append(block)

    return blocks

# 각 블록의 "[메일 N]" 번호를 1부터 순서대로 다시 매긴다
def _renumber_mail_blocks(text: str) -> str:
    blocks = _split_mail_blocks(text)
    result = []
    for i, block in enumerate(blocks, start=1):
        renumbered = re.sub(r'\[메일 \d+\]', f'[메일 {i}]', block)
        result.append(renumbered)
    return "\n".join(result) + "\n"

# 텍스트에 있는 모든 메일/메시지 ID를 집합으로 추출한다
def _extract_message_ids(text):
    return set(re.findall(r"^\s*(?:\[ID\]|ID:)\s*(.+?)\s*$", text, flags=re.MULTILINE))

# 블록의 날짜 줄을 파싱해 정렬 키로 쓸 datetime을 반환한다 (실패 시 datetime.min)
def _extract_block_for_sort(block):
    for line in block.splitlines():
        if line.startswith("[날짜]") or line.startswith("날짜:"):
            raw = re.sub(r"^(\[날짜\]|날짜:)", "", line).strip()
            for fmt in ("%Y-%m-%d %H:%M:%S", "%Y-%m-%d"):  # 메일: 시간 포함 / 메신저: 날짜만
                try:
                    return datetime.datetime.strptime(raw, fmt)
                except ValueError:
                    continue
            return datetime.datetime.min
    return datetime.datetime.min

# mail_latest.txt 전체를 문자열로 읽어 반환한다 (없으면 빈 문자열)
def _read_latest_text(paths):
    if not os.path.exists(paths.MAIL_LATEST_PATH):
        return ""
    with open(paths.MAIL_LATEST_PATH, "r", encoding="utf-8") as f:
        return f.read()

# mail_latest.txt를 파싱해 id/text 컬럼 CSV로 저장한다 (rewrite=전체, append=새 메일만) 후 경로 반환
def _build_mail_csv(paths, mode="rewrite", new_ids=None) -> str | None:
    # 1) mail_latest.txt 파싱 → {mail_id: block_text}
    mail_text = _read_latest_text(paths)
    mail_blocks: dict[str, str] = {}

    for block in _split_mail_blocks(mail_text):
        mail_id = _extract_mail_id_from_block(block)
        if mail_id:
            mail_blocks[mail_id] = block.strip()

    # 2) CSV row 생성
    rows = []
    for mail_id, block_text in mail_blocks.items():
        clean_text = block_text.replace(MAIL_BLOCK_SEP, "").strip()
        rows.append({"id": mail_id, "text": clean_text})

    # 3) mode에 따라 저장 대상 결정
    if mode == "append" and new_ids:
        # append + 새 메일 있음: 새 메일만 필터링해서 증분 CSV 생성
        rows = [r for r in rows if r["id"] in new_ids]
        csv_name = f"inc_{datetime.datetime.now().strftime('%Y-%m-%d_%H%M%S')}.csv"

    elif mode == "append" and not new_ids:
        # CSV 생성 불필요 
        print("[CSV] append 모드이나 new_ids 없음 → CSV 생성 생략")
        return None

    else:
        # rewrite: 전체를 latest.csv로 저장
        csv_name = "latest.csv"

    csv_path = os.path.join(paths.MAIL_DIR, csv_name)
    with open(csv_path, "w", encoding="utf-8", newline="") as f:
        writer = csv.DictWriter(f, fieldnames=["id", "text"])
        writer.writeheader()
        writer.writerows(rows)

    print(f"[CSV] 생성 완료 → {csv_path} ({len(rows)}개 메일)")
    return csv_path


_MAIL_SUBJECT_RE  = re.compile(r"^\[제목\]\s*(.*)$", re.MULTILINE)
_MAIL_DATE_RE     = re.compile(r"^\[날짜\]\s*(.*)$", re.MULTILINE)
_MAIL_SENDER_RE   = re.compile(r"^\[발신인\]\s*(.*)$", re.MULTILINE)
_MAIL_RECEIVER_RE = re.compile(r"^\[수신인\]\s*(.*)$", re.MULTILINE)
_MAIL_BODY_RE = re.compile(r"\[메일 본문\]\s*\n(.*?)(?:\n\[첨부파일 정보\]|\Z)", re.DOTALL)

