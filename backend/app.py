from fastapi import FastAPI, Form, UploadFile, File
from fastapi.middleware.cors import CORSMiddleware
from pathlib import Path
import shutil

from hybrid_predict import (
    extract_anthropometrics,
    run_hybrid_prediction,
    warm_up as hybrid_warm_up,
)
from routers.auth import router as auth_router
from routers.health_worker import router as health_worker_router
from routers.screening import router as screening_router
#This is for testing
from routers.test_protected import router as protected_router
from routers.test_screening import router as test_screening_router

app = FastAPI(title="PoshanEye Backend")
app.include_router(auth_router)
app.include_router(health_worker_router)
app.include_router(screening_router)
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
async def predict(
    file: UploadFile = File(...),
    age_months: str = Form(None),
    age_years: str = Form(None),
    gender: str = Form(None),
    height_cm: str = Form(None),
    weight_kg: str = Form(None),
    head_circumference_cm: str = Form(None),
    waist_cm: str = Form(None),
    muac_cm: str = Form(None),
):
    """Run the PRODUCTION hybrid pipeline (168-feature fusion + portable SVM).

    The image is required; all anthropometric fields are optional form fields.
    Missing/invalid values follow the exact training convention (median imputation
    with training-split statistics). The response JSON contract is unchanged:
    prediction / confidence / probabilities (+ status / risk / recommendation),
    so the existing Flutter result UI keeps working as-is.
    """
    image_path = UPLOAD_DIR / file.filename

    with image_path.open("wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    anthropometrics = extract_anthropometrics(
        {
            "age_months": age_months,
            "age_years": age_years,
            "gender": gender,
            "height_cm": height_cm,
            "weight_kg": weight_kg,
            "head_circumference_cm": head_circumference_cm,
            "waist_cm": waist_cm,
            "muac_cm": muac_cm,
        }
    )

    image_bytes = image_path.read_bytes()

    # Temporary data-flow trace (remove after verification)
    print(f"[BACKEND] image_bytes={len(image_bytes)} height_cm={height_cm!r} "
          f"weight_kg={weight_kg!r} age_years={age_years!r} age_months={age_months!r} "
          f"gender={gender!r}", flush=True)

    result = run_hybrid_prediction(image_bytes, anthropometrics)

    return result


@app.on_event("startup")
def _load_hybrid_models():
    # Eagerly load the frozen production artifacts so the first scan doesn't
    # pay the model-loading cost (and load errors surface in server logs).
    hybrid_warm_up()
