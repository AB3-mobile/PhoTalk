# people (테스트용 인물 사진)

사진 업로드 → 얼굴 벡터 저장 → 그래프 노드에 얼굴 표시 기능을 시험할 때 쓰는 **테스트 전용** 인물 사진이다.
인물 이름은 `../demo_chat.txt` 참여자(민지/서연/준호)와 같다. **이름이 같아야** 그래프의 인물 노드와 얼굴이 연결된다.

| 파일 | 인물 |
|---|---|
| `minji.png` | 민지 |
| `seoyeon.png` | 서연 |
| `junho.png` | 준호 |

## 준비

`backend` 폴더에서 의존성을 설치하고 서버를 켠다.

```
pip install -r requirements.txt
python src/app.py
```

- 얼굴 인식 모델(약 37MB)은 처음 얼굴을 처리할 때 `backend/models/face/` 로 자동으로 받는다. 미리 받으려면 `src` 폴더에서 `python -m util.face_embedder --download`.
- DB(`PhoTalk_db`)에 `db/schema.sql` 이 적용돼 있어야 한다 (`photo`, `photo_data`, `photo_face`, `known_person` 테이블).

## 1. 앱에서 시험하기

1. 데이터 수집 화면에서 `../demo_chat.txt` 를 대화방으로 추가한다.
2. **사진 선택하기** → 첫 칸 **사진 추가** → 이 폴더의 사진 3장을 고른다.
3. 이름 입력 화면에서 사진마다 이름을 넣는다. 아래 자동완성(대화 참여자)에서 고르면 철자가 정확히 맞는다.
4. **그래프 만들기**. '사진 매칭' 단계에서 사진이 서버로 올라가며 얼굴 벡터가 저장된다.
5. 확인
   - **그래프 완성** 화면: 인물 노드에 마우스를 올리거나 탭하면 커지며 얼굴이 보인다. '가장 많이 이어진 사람' 카드에도 얼굴이 보인다.
   - **그래프 보기**(지식 그래프): 인물 노드에 마우스를 올리거나 탭하면 커지며 얼굴이 보인다.

## 2. 앱 없이 시험하기

서버가 켜진 상태에서 `backend` 폴더에서 실행한다. 3장을 이름과 함께 올리고, 이름별 얼굴 이미지가 나오는지 확인한다.

```
python sample_data/upload_people.py
```

성공하면 이렇게 나온다.

```
[업로드] 민지 (minji.png) 얼굴 1개 ['confirmed:민지']
[업로드] 서연 (seoyeon.png) 얼굴 1개 ['confirmed:서연']
[업로드] 준호 (junho.png) 얼굴 1개 ['confirmed:준호']

[얼굴 확인] 민지: OK (200, ... bytes)
...
```

### API 직접 호출 (curl)

```
# 사진 + 이름 저장 (얼굴 벡터 추출, 가장 큰 얼굴을 그 이름으로 확정)
curl -F "file=@sample_data/people/minji.png" -F "name=민지" http://localhost/photo-upload

# 저장 없이 매칭만: 이미 아는 얼굴과 비교해 이름과 유사도를 돌려준다
curl -F "file=@sample_data/people/minji.png" http://localhost/photo-match

# 이름으로 얼굴 크롭(256px JPEG) 받기 → 브라우저로 열어도 된다
curl -o face.jpg "http://localhost/person-face?name=%EB%AF%BC%EC%A7%80"
```

- Git Bash의 curl은 `-F "name=민지"` 의 한글이 깨질 수 있다. 그럴 땐 `upload_people.py` 를 쓴다.
- `/person-face` 의 이름은 URL 인코딩해야 한다 (`민지` = `%EB%AF%BC%EC%A7%80`). 브라우저 주소창에는 `http://localhost/person-face?name=민지` 를 그대로 넣어도 된다.
- 매칭 기준은 코사인 유사도 0.363 이상이다(OpenCV SFace 권장값). 같은 사람이면 보통 0.6 이상, 다른 사람이면 0.2 이하가 나온다.

## DB에서 확인

```sql
USE PhoTalk_db;
SELECT k.display_name, p.mime_type, f.match_status, f.similarity,
       LENGTH(f.embedding) AS embedding_bytes, f.bbox_w, f.bbox_h
FROM photo p
JOIN photo_face f USING (photo_id)
LEFT JOIN known_person k USING (person_id);
```

`embedding_bytes` 가 512(= float32 128차원)이고 `match_status` 가 `confirmed` 면 정상이다.

## 테스트 데이터 지우기

사진을 지우면 `photo_data`, `photo_face` 는 함께 지워진다(ON DELETE CASCADE). 이름(`known_person`)은 따로 지운다.

```sql
DELETE FROM photo;
DELETE FROM known_person WHERE display_name IN ('민지', '서연', '준호');
```

## 주의

- 실제 사람(본인·지인 포함) 사진은 이 폴더나 저장소에 올리지 않는다.
- 같은 파일을 다시 올리면 사진은 중복 저장되지 않고, 얼굴과 이름만 다시 계산해 갱신된다.
- 지원 형식: JPEG, PNG, WebP, BMP, HEIC/HEIF (장당 최대 20MB). GIF·TIFF 등은 400 오류.
