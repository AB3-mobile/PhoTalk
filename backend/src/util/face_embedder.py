# 사진에서 얼굴을 찾고(OpenCV YuNet) 얼굴마다 128차원 벡터를 뽑는다(OpenCV SFace). 이미지 판별·썸네일·촬영일 읽기도 여기서 한다.
#
# 모델 파일은 Git에 올리지 않는다. 처음 쓸 때 backend/models/face/ 에 없으면 OpenCV Zoo에서 자동으로 받는다.
# 미리 받아 두려면 (backend/src 에서): python -m util.face_embedder --download

import datetime
import hashlib
import io
import os
import sys
import threading
import urllib.request

import cv2
import numpy as np
from PIL import Image, ImageOps, UnidentifiedImageError

try:
    import pillow_heif

    pillow_heif.register_heif_opener()  # 아이폰 HEIC/HEIF 사진을 Pillow로 열 수 있게 한다
except ImportError:  # pillow-heif가 없으면 HEIC만 못 연다
    pillow_heif = None

# backend/ 폴더 (src/util/ 의 두 단계 위)
_BACKEND_DIR = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MODEL_DIR = os.path.join(_BACKEND_DIR, "models", "face")

# 파일 이름 → (다운로드 주소, SHA-256)
_MODELS = {
    "face_detection_yunet_2023mar.onnx": (
        "https://github.com/opencv/opencv_zoo/raw/main/models/face_detection_yunet/face_detection_yunet_2023mar.onnx",
        "8f2383e4dd3cfbb4553ea8718107fc0423210dc964f9f4280604804ed2552fa4",
    ),
    "face_recognition_sface_2021dec.onnx": (
        "https://github.com/opencv/opencv_zoo/raw/main/models/face_recognition_sface/face_recognition_sface_2021dec.onnx",
        "0ba9fbfa01b5270c96627c4ef784da859931e02f04419c829e83484087c34e79",
    ),
}
_DETECTOR_FILE = "face_detection_yunet_2023mar.onnx"
_RECOGNIZER_FILE = "face_recognition_sface_2021dec.onnx"

# photo_face.embed_model 에 적는 이름 (모델을 바꾸면 예전 벡터와 비교하면 안 되므로 구분용)
EMBED_MODEL = "opencv-sface-2021dec"
EMBED_DIM = 128

# 업로드를 받는 이미지 형식 (Pillow가 판별한 format → MIME)
ALLOWED_FORMATS = {
    "JPEG": "image/jpeg",
    "PNG": "image/png",
    "WEBP": "image/webp",
    "BMP": "image/bmp",
    "HEIF": "image/heic",
}
MAX_IMAGE_BYTES = 20 * 1024 * 1024

# 얼굴 검출 기준 (낮추면 더 많이 찾지만 오검출이 늘어난다)
_SCORE_THRESHOLD = 0.8
# 검출할 때 이미지 긴 변 최대 크기 (너무 크면 느리다)
_DETECT_MAX_SIDE = 1280
# 썸네일 긴 변 크기
_THUMB_MAX_SIDE = 320


class UnsupportedImageError(ValueError):
    """이미지가 아니거나 지원하지 않는 형식일 때"""


# ---------------------------------------------------------------------
# 모델 준비
# ---------------------------------------------------------------------

def _sha256_file(path: str) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        for chunk in iter(lambda: f.read(1 << 20), b""):
            h.update(chunk)
    return h.hexdigest()


# 모델 파일이 없거나 깨졌으면 OpenCV Zoo에서 받아 해시를 확인한 뒤 경로를 반환한다
def ensure_model(filename: str) -> str:
    url, expected = _MODELS[filename]
    path = os.path.join(MODEL_DIR, filename)
    if os.path.exists(path) and _sha256_file(path) == expected:
        return path

    os.makedirs(MODEL_DIR, exist_ok=True)
    tmp = path + ".part"
    print(f"[face] 모델 다운로드: {filename}")
    urllib.request.urlretrieve(url, tmp)
    actual = _sha256_file(tmp)
    if actual != expected:
        os.remove(tmp)
        raise RuntimeError(f"모델 파일 해시가 다릅니다: {filename} ({actual})")
    os.replace(tmp, path)
    return path


_lock = threading.Lock()
_detector = None
_recognizer = None


# 모델을 한 번만 불러 (검출기, 인식기)를 반환한다. 검출기는 입력 크기를 바꿔 쓰므로 호출하는 쪽에서 _lock을 잡는다.
def _models():
    global _detector, _recognizer
    if _detector is None:
        det_path = ensure_model(_DETECTOR_FILE)
        rec_path = ensure_model(_RECOGNIZER_FILE)
        _detector = cv2.FaceDetectorYN.create(det_path, "", (320, 320), _SCORE_THRESHOLD, 0.3, 5000)
        _recognizer = cv2.FaceRecognizerSF.create(rec_path, "")
    return _detector, _recognizer


# ---------------------------------------------------------------------
# 이미지 읽기
# ---------------------------------------------------------------------

# 바이트를 열어 (회전 보정한 RGB 이미지, MIME, 원본 Pillow 이미지)를 반환한다. 지원하지 않으면 UnsupportedImageError.
def open_image(data: bytes):
    if not data:
        raise UnsupportedImageError("빈 파일입니다.")
    if len(data) > MAX_IMAGE_BYTES:
        raise UnsupportedImageError(f"파일이 너무 큽니다 (최대 {MAX_IMAGE_BYTES // (1024 * 1024)}MB).")
    try:
        img = Image.open(io.BytesIO(data))
        img.load()
    except (UnidentifiedImageError, OSError) as e:
        raise UnsupportedImageError("이미지 파일이 아니거나 읽을 수 없습니다.") from e

    fmt = (img.format or "").upper()
    if fmt not in ALLOWED_FORMATS:
        raise UnsupportedImageError(f"지원하지 않는 형식입니다: {fmt or '알 수 없음'} (JPEG, PNG, WebP, BMP, HEIC만 가능)")

    rgb = ImageOps.exif_transpose(img).convert("RGB")
    return rgb, ALLOWED_FORMATS[fmt], img


# EXIF 촬영일(DateTimeOriginal → DateTime)을 datetime으로 반환한다 (없으면 None)
def read_taken_at(img: Image.Image):
    try:
        exif = img.getexif()
        raw = exif.get_ifd(0x8769).get(0x9003) or exif.get(0x0132)  # DateTimeOriginal, DateTime
        if not raw:
            return None
        return datetime.datetime.strptime(str(raw).strip("\x00 "), "%Y:%m:%d %H:%M:%S")
    except Exception:
        return None


# 긴 변 320px JPEG 썸네일 바이트를 만든다
def make_thumbnail(rgb: Image.Image) -> bytes:
    thumb = rgb.copy()
    thumb.thumbnail((_THUMB_MAX_SIDE, _THUMB_MAX_SIDE))
    buf = io.BytesIO()
    thumb.save(buf, format="JPEG", quality=85)
    return buf.getvalue()


# ---------------------------------------------------------------------
# 얼굴 → 벡터
# ---------------------------------------------------------------------

# 회전 보정한 RGB 이미지에서 얼굴들을 찾아 [{bbox:(x,y,w,h), score, embedding(128, L2 정규화)}]를 큰 얼굴 순으로 반환한다
def extract_faces(rgb: Image.Image) -> list:
    bgr = cv2.cvtColor(np.asarray(rgb), cv2.COLOR_RGB2BGR)
    h, w = bgr.shape[:2]
    scale = min(1.0, _DETECT_MAX_SIDE / max(h, w))
    small = cv2.resize(bgr, (round(w * scale), round(h * scale))) if scale < 1.0 else bgr

    with _lock:
        detector, recognizer = _models()
        detector.setInputSize((small.shape[1], small.shape[0]))
        _, dets = detector.detect(small)
        if dets is None:
            return []

        faces = []
        for det in dets:
            # alignCrop은 검출한 이미지(small) 좌표의 det을 그대로 쓴다
            aligned = recognizer.alignCrop(small, det)
            vec = recognizer.feature(aligned).flatten().astype(np.float32)
            norm = float(np.linalg.norm(vec))
            if norm == 0:
                continue
            x, y, bw, bh = (det[:4] / scale).tolist()  # 원본 좌표로 되돌림
            faces.append({
                "bbox": (max(0, round(x)), max(0, round(y)), round(bw), round(bh)),
                "score": float(det[-1]),
                "embedding": vec / norm,
            })

    faces.sort(key=lambda f: f["bbox"][2] * f["bbox"][3], reverse=True)
    return faces


# 벡터 ↔ DB 바이트 (float32 리틀엔디언, 128차원 = 512바이트)
def embedding_to_bytes(vec: np.ndarray) -> bytes:
    return np.asarray(vec, dtype="<f4").tobytes()


def bytes_to_embedding(raw: bytes) -> np.ndarray:
    return np.frombuffer(raw, dtype="<f4")


if __name__ == "__main__":
    if "--download" in sys.argv:
        for name in _MODELS:
            print(ensure_model(name))
    else:
        print("사용법: python -m util.face_embedder --download")
