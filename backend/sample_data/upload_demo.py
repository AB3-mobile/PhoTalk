"""샘플 대화(demo_chat.txt)를 실행 중인 서버에 업로드하고 인덱싱이 끝날 때까지 기다린다.

사용: python sample_data/upload_demo.py   (서버: python src/app.py 가 켜져 있어야 함)
"""
import json
import sys
import time
import urllib.request
from pathlib import Path

BASE = "http://localhost"  # app.py가 80번 포트로 뜬다. 다르게 바꿨다면 여기를 수정
text = (Path(__file__).parent / "demo_chat.txt").read_text(encoding="utf-8")


def call(path, body=None):
    data = json.dumps(body).encode() if body is not None else None
    req = urllib.request.Request(BASE + path, data=data, headers={"Content-Type": "application/json"})
    with urllib.request.urlopen(req, timeout=60) as r:
        return json.loads(r.read())


res = call("/message-upload", {"content": text, "room_name": "데모 동아리방", "filename": "demo_chat.txt"})
print("업로드 시작:", res)
job = res["jobId"]
while True:
    st = call(f"/message-upload-status/{job}")
    print(st.get("status"), st.get("message"))
    if st.get("status") in ("done", "error"):
        print(json.dumps(st, ensure_ascii=False, indent=2)[:1500])
        sys.exit(0 if st.get("status") == "done" else 1)
    time.sleep(5)
