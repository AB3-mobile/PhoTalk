# 업로드한 사진을 photo / photo_data / photo_face 테이블에 저장하고, 입력한 이름을 known_person과 연결한다.
# 얼굴 벡터끼리 코사인 유사도로 비교해 이미 아는 사람과 자동 매칭하는 함수도 여기 있다.

import hashlib
import io
import uuid

import numpy as np

from config.db import get_db_connection
from util.database.db_writer import get_or_create_user_id
from util.face_embedder import (
    EMBED_MODEL,
    bytes_to_embedding,
    embedding_to_bytes,
    extract_faces,
    make_thumbnail,
    open_image,
    read_taken_at,
)

# SFace 코사인 유사도 기준 (OpenCV 권장값). 이 값 이상이면 같은 사람으로 본다.
MATCH_THRESHOLD = 0.363
_NAME_MAXLEN = 255


# known_person에서 이름으로 사람을 찾고, 없으면 새로 만들어 person_id를 반환한다
def get_or_create_person(cursor, user_id: str, name: str) -> str:
    cursor.execute(
        "SELECT person_id FROM known_person WHERE user_id = %s AND display_name = %s",
        (user_id, name),
    )
    row = cursor.fetchone()
    if row:
        return row[0]
    person_id = str(uuid.uuid4())
    cursor.execute(
        "INSERT INTO known_person (person_id, user_id, display_name) VALUES (%s, %s, %s)",
        (person_id, user_id, name),
    )
    return person_id


# 후보 이름 목록을 정리한다 (공백 제거, 빈 값·중복 제외). None이면 제한 없음.
def clean_candidates(names):
    if names is None:
        return None
    out = []
    for n in names:
        n = (n or "").strip()[:_NAME_MAXLEN]
        if n and n not in out:
            out.append(n)
    return out


# 이 사용자가 이름을 아는 얼굴들(confirmed/auto)과 비교해 가장 닮은 사람을 반환한다
# - candidate_names가 있으면 그 이름의 사람들하고만 비교한다 (빈 목록이면 매칭하지 않음)
# - exclude_person_ids에 있는 사람은 건너뛴다 (한 사진에 같은 사람이 두 번 붙지 않게)
# 반환: {person_id, name, similarity} 또는 None (기준 미달)
def match_face(cursor, user_id: str, embedding: np.ndarray, threshold: float = MATCH_THRESHOLD,
               exclude_photo_id: str = None, candidate_names=None, exclude_person_ids=()):
    if candidate_names is not None and not candidate_names:
        return None
    sql = """
        SELECT f.embedding, f.person_id, k.display_name
        FROM photo_face f
        JOIN photo p ON p.photo_id = f.photo_id
        JOIN known_person k ON k.person_id = f.person_id
        WHERE p.user_id = %s
          AND f.embed_model = %s
          AND f.match_status IN ('confirmed', 'auto')
          AND (%s IS NULL OR f.photo_id <> %s)
    """
    params = [user_id, EMBED_MODEL, exclude_photo_id, exclude_photo_id]
    if candidate_names:
        sql += " AND k.display_name IN (" + ", ".join(["%s"] * len(candidate_names)) + ")"
        params.extend(candidate_names)
    cursor.execute(sql, tuple(params))
    rows = [r for r in cursor.fetchall() if r[1] not in exclude_person_ids]
    if not rows:
        return None

    known = np.stack([bytes_to_embedding(r[0]) for r in rows])
    sims = known @ np.asarray(embedding, dtype=np.float32)  # 둘 다 L2 정규화돼 있어 내적 = 코사인 유사도
    best = int(np.argmax(sims))
    if float(sims[best]) < threshold:
        return None
    return {"person_id": rows[best][1], "name": rows[best][2], "similarity": round(float(sims[best]), 4)}


def _face_json(face, person=None, status="unknown"):
    return {
        "bbox": list(face["bbox"]),
        "match_status": status,
        "person_id": person["person_id"] if person else None,
        "name": person["name"] if person else None,
        "similarity": person.get("similarity") if person else None,
    }


# 사진 한 장을 저장하고 얼굴 벡터를 뽑아 이름과 연결한다
# - 같은 파일(SHA-256)이 이미 있으면 사진은 다시 저장하지 않고 얼굴·이름만 다시 정리한다
# - 이름이 있으면 가장 큰 얼굴을 그 사람으로 확정(confirmed)하고, 나머지 얼굴은 아는 사람과 자동 매칭(auto)을 시도한다
# 반환: {photo_id, duplicate, face_count, person_id, faces:[...]}. 이미지가 아니면 UnsupportedImageError.
# - candidate_names가 있으면 나머지 얼굴의 자동 매칭을 그 이름들로만 제한한다 (예: 고른 대화방 참여자)
def save_photo(data: bytes, name: str = None, candidate_names=None) -> dict:
    rgb, mime, raw_img = open_image(data)
    name = (name or "").strip()[:_NAME_MAXLEN] or None
    candidate_names = clean_candidates(candidate_names)
    file_hash = hashlib.sha256(data).hexdigest()

    # 얼굴 벡터는 DB 연결 전에 먼저 계산한다 (트랜잭션을 짧게)
    faces = extract_faces(rgb)

    user_id = get_or_create_user_id("")
    conn = get_db_connection()
    cursor = conn.cursor()
    photo_id = None
    try:
        cursor.execute(
            "SELECT photo_id FROM photo WHERE user_id = %s AND file_hash = %s",
            (user_id, file_hash),
        )
        row = cursor.fetchone()
        duplicate = row is not None

        if duplicate:
            photo_id = row[0]
            # 다시 올린 사진은 얼굴을 새로 계산한 값으로 바꾼다 (이름이 바뀌었을 수 있으므로)
            cursor.execute("DELETE FROM photo_face WHERE photo_id = %s", (photo_id,))
        else:
            photo_id = str(uuid.uuid4())
            cursor.execute(
                """
                INSERT INTO photo (photo_id, user_id, mime_type, file_size, file_hash, taken_at, status)
                VALUES (%s, %s, %s, %s, %s, %s, 'pending')
                """,
                (photo_id, user_id, mime, len(data), file_hash, read_taken_at(raw_img)),
            )
            cursor.execute(
                "INSERT INTO photo_data (photo_id, original, thumbnail) VALUES (%s, %s, %s)",
                (photo_id, data, make_thumbnail(rgb)),
            )

        person_id = get_or_create_person(cursor, user_id, name) if name else None

        result_faces = []
        assigned = set()  # 이 사진에서 이미 배정한 사람 (한 사진에 같은 사람은 한 번)
        for i, face in enumerate(faces):
            if i == 0 and person_id:
                person = {"person_id": person_id, "name": name, "similarity": None}
                status, sim = "confirmed", None
            else:
                person = match_face(
                    cursor, user_id, face["embedding"], exclude_photo_id=photo_id,
                    candidate_names=candidate_names, exclude_person_ids=assigned,
                )
                status = "auto" if person else "unknown"
                sim = person["similarity"] if person else None
            if person:
                assigned.add(person["person_id"])

            x, y, w, h = face["bbox"]
            cursor.execute(
                """
                INSERT INTO photo_face
                  (face_id, photo_id, bbox_x, bbox_y, bbox_w, bbox_h, embedding, embed_model, person_id, match_status, similarity)
                VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s, %s, %s)
                """,
                (
                    str(uuid.uuid4()), photo_id, x, y, w, h,
                    embedding_to_bytes(face["embedding"]), EMBED_MODEL,
                    person["person_id"] if person else None, status, sim,
                ),
            )
            result_faces.append(_face_json(face, person, status))

        cursor.execute("UPDATE photo SET status = 'processed' WHERE photo_id = %s", (photo_id,))
        conn.commit()
        return {
            "photo_id": photo_id,
            "duplicate": duplicate,
            "face_count": len(faces),
            "person_id": person_id if faces else None,
            "faces": result_faces,
        }
    except Exception:
        conn.rollback()
        raise
    finally:
        cursor.close()
        conn.close()


# 저장하지 않고 사진 속 얼굴마다 아는 사람과 매칭한 결과만 반환한다 (큰 얼굴 순)
# - candidate_names가 있으면 그 이름의 사람들하고만 비교한다
def match_photo(data: bytes, candidate_names=None) -> dict:
    rgb, _, _ = open_image(data)
    faces = extract_faces(rgb)
    candidate_names = clean_candidates(candidate_names)
    user_id = get_or_create_user_id("")
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        out = []
        assigned = set()  # 한 사진에 같은 사람은 한 번 (큰 얼굴이 먼저 가져간다)
        for face in faces:
            person = match_face(
                cursor, user_id, face["embedding"],
                candidate_names=candidate_names, exclude_person_ids=assigned,
            )
            if person:
                assigned.add(person["person_id"])
            out.append(_face_json(face, person, "auto" if person else "unknown"))
        return {"face_count": len(faces), "faces": out}
    finally:
        cursor.close()
        conn.close()


# 썸네일 바이트를 반환한다 (없으면 None)
def get_photo_thumbnail(photo_id: str):
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute("SELECT thumbnail FROM photo_data WHERE photo_id = %s", (photo_id,))
        row = cursor.fetchone()
        return bytes(row[0]) if row and row[0] is not None else None
    finally:
        cursor.close()
        conn.close()


# 얼굴 크롭 크기 (정사각형 한 변, px)와 얼굴 둘레 여백 비율
_FACE_CROP_SIZE = 256
_FACE_CROP_MARGIN = 0.35


# 이름이 같은 사람의 얼굴 중 가장 믿을 만한 것(확정 > 자동 매칭 유사도 높은 순 > 큰 얼굴)을 정사각형 JPEG으로 잘라 반환한다 (없으면 None)
def get_person_face_crop(name: str):
    name = (name or "").strip()
    if not name:
        return None
    user_id = get_or_create_user_id("")
    conn = get_db_connection()
    cursor = conn.cursor()
    try:
        cursor.execute(
            """
            SELECT d.original, f.bbox_x, f.bbox_y, f.bbox_w, f.bbox_h
            FROM known_person k
            JOIN photo_face f ON f.person_id = k.person_id
            JOIN photo_data d ON d.photo_id = f.photo_id
            WHERE k.user_id = %s AND k.display_name = %s
              AND f.match_status IN ('confirmed', 'auto')
              AND f.bbox_w IS NOT NULL
            ORDER BY f.match_status = 'confirmed' DESC, f.similarity DESC, f.bbox_w * f.bbox_h DESC
            LIMIT 1
            """,
            (user_id, name),
        )
        row = cursor.fetchone()
    finally:
        cursor.close()
        conn.close()
    if not row:
        return None

    original, x, y, w, h = row
    # bbox는 회전 보정한 이미지 기준 좌표이므로 같은 방식으로 연다
    rgb, _, _ = open_image(bytes(original))
    cx, cy = x + w / 2, y + h / 2
    half = max(w, h) * (1 + _FACE_CROP_MARGIN) / 2
    # 사진 밖으로 나가지 않게 정사각형을 안쪽으로 밀어 넣는다
    half = min(half, rgb.width / 2, rgb.height / 2)
    left = min(max(cx - half, 0), rgb.width - 2 * half)
    top = min(max(cy - half, 0), rgb.height - 2 * half)
    crop = rgb.crop((round(left), round(top), round(left + 2 * half), round(top + 2 * half)))
    crop = crop.resize((_FACE_CROP_SIZE, _FACE_CROP_SIZE))

    buf = io.BytesIO()
    crop.save(buf, format="JPEG", quality=88)
    return buf.getvalue()
