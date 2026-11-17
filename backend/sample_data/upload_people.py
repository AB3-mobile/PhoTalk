"""샘플 인물 사진(people/)을 이름과 함께 실행 중인 서버에 올리고, 얼굴이 저장됐는지 확인한다.

사용: python sample_data/upload_people.py   (서버: python src/app.py 가 켜져 있어야 함)
자세한 설명은 sample_data/people/README.md
"""
import os
import sys
from pathlib import Path

import requests

# app.py가 80번 포트로 뜬다. 다르게 바꿨다면 환경변수 PHOTALK_BASE=http://localhost:5000 처럼 지정
BASE = os.environ.get("PHOTALK_BASE", "http://localhost").rstrip("/")
PEOPLE_DIR = Path(__file__).parent / "people"

# 파일 이름 → 인물 이름 (demo_chat.txt 참여자 이름과 같아야 그래프 노드와 연결된다)
PEOPLE = {
    "minji.png": "민지",
    "seoyeon.png": "서연",
    "junho.png": "준호",
}

try:
    requests.get(BASE, timeout=5)
except requests.ConnectionError:
    sys.exit(f"서버({BASE})에 연결할 수 없습니다. backend 폴더에서 python src/app.py 로 서버를 먼저 켜 주세요.")

ok = True
for filename, name in PEOPLE.items():
    path = PEOPLE_DIR / filename
    with path.open("rb") as f:
        res = requests.post(
            f"{BASE}/photo-upload",
            files={"file": (filename, f, "image/png")},
            data={"name": name},
            timeout=120,
        )
    body = res.json()
    if res.status_code != 200 or not body.get("ok"):
        ok = False
        print(f"[실패] {name} ({filename}): {res.status_code} {body.get('error')}")
        continue
    faces = [f"{x['match_status']}:{x['name']}" for x in body["faces"]]
    note = " (이미 올린 사진 → 이름만 갱신)" if body["duplicate"] else ""
    print(f"[업로드] {name} ({filename}) 얼굴 {body['face_count']}개 {faces}{note}")
    if body["face_count"] == 0:
        ok = False

print()
for name in PEOPLE.values():
    res = requests.get(f"{BASE}/person-face", params={"name": name}, timeout=60)
    good = res.status_code == 200
    ok = ok and good
    print(f"[얼굴 확인] {name}: {'OK' if good else '없음'} ({res.status_code}, {len(res.content)} bytes)")

sys.exit(0 if ok else 1)
