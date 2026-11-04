# sample_data

테스트용 **가짜** 카카오톡 대화 내보내기 파일이다. 실제 사람/대화와 무관하다.

- `demo_chat.txt`: 3명(민지/준호/서연)이 스터디·프로젝트 일정을 이야기하는 14일치 대화.
- `upload_demo.py`: 위 대화를 실행 중인 서버에 올리는 스크립트.

## 사용법

서버(`python src/app.py`)가 켜진 상태에서 `backend` 폴더에서 실행한다.

```
python sample_data/upload_demo.py
```

업로드는 바로 끝나지만, 인덱싱(그래프·요약·관계·아바타 생성)은 서버에서 몇 분 더 돈다. 서버 터미널에 `[JOB][pipeline] SUCCESS` 가 뜨면 끝난 것이다.

## 결과 확인

대화방 목록 (`indexed: true`, 참여자 3명이면 성공):
```
curl -s -X POST http://localhost/messenger-chatrooms -H "Content-Type: application/json" -d "{}"
```

질문 검색은 Git Bash의 curl은 한글 본문이 깨질 수 있어 파이썬으로 보낸다. `rid` 에는 위 목록의 `chatroom_id` 를 넣는다.
```
python - <<'EOF'
import json, time, urllib.request
B = "http://localhost"
def post(p, b):
    r = urllib.request.Request(B + p, json.dumps(b).encode("utf-8"), {"Content-Type": "application/json"})
    return json.loads(urllib.request.urlopen(r).read())
rid = "여기에_chatroom_id"
job = post("/run-query-async", {"message": "스터디는 언제 어디서 하기로 했어?", "user_id": rid, "domain": "messenger", "resMethod": "local", "resType": "text"})["jobId"]
while True:
    s = json.loads(urllib.request.urlopen(B + "/job-status/" + job).read())
    if s["status"] in ("done", "error"):
        print(s["status"]); print(s["result"]); break
    time.sleep(2)
EOF
```

생성된 아바타 이미지는 `user_data/messenger/<chatroom_id>/graphrag/parquet/output/statics/chatroom_avatars/` 에 있다.

## 주의

- 실제 개인 대화 파일은 이 폴더나 저장소에 올리지 않는다.
- 같은 대화방을 다시 올리면 기존 인덱스를 덮어쓴다.
