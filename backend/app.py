from fastapi import FastAPI, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from pathlib import Path
import shutil

from predict import run_prediction
from routers.auth import router as auth_router
from routers.health_worker import router as health_worker_router
#This is for testing
from routers.test_protected import router as protected_router
from routers.test_screening import router as test_screening_router

app = FastAPI(title="PoshanEye Backend")
app.include_router(auth_router)
app.include_router(health_worker_router)
#this is for testing
app.include_router(protected_router)
app.include_router(test_screening_router)


# ── CORS Configuration ──────────────────────────────────────────────
# Allow any localhost/127.0.0.1 origin on any port.
# Flutter Web assigns a random development port each run,
# so we use a regex instead of a fixed list.
app.add_middleware(
    CORSMiddleware,
    allow_origin_regex=r"^https?://(localhost|127\.0\.0\.1)(:\d+)?$",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

BASE_DIR = Path(__file__).resolve().parent
UPLOAD_DIR = BASE_DIR / "uploads"

UPLOAD_DIR.mkdir(exist_ok=True)


@app.get("/")
def root():
    return {
        "message": "PoshanEye backend is running"
    }


@app.get("/health")
def health():
    return {
        "status": "ok"
    }


@app.post("/predict")
async def predict(file: UploadFile = File(...)):

    image_path = UPLOAD_DIR / file.filename

    with image_path.open("wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    result = run_prediction(str(image_path))

    return result