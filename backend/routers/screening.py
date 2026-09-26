from pathlib import Path
import shutil
import uuid

from fastapi import APIRouter, Depends, File, HTTPException, UploadFile

from hybrid_predict import run_hybrid_prediction, extract_anthropometrics

from security.dependencies import get_current_user

from services.child_service import get_child_by_id

from services.screening_service import (
    create_screening,
    get_screening_history
)


router = APIRouter(
    prefix="/api/screenings",
    tags=["Screenings"]
)


BASE_DIR = Path(__file__).resolve().parent.parent
UPLOAD_DIR = BASE_DIR / "uploads"
UPLOAD_DIR.mkdir(exist_ok=True)


@router.post("/predict/{child_id}")
async def predict_for_child(
    child_id: str,
    file: UploadFile = File(...),
    current_user: dict = Depends(get_current_user)
):
    # 1. Verify that the child exists
    child = await get_child_by_id(child_id)

    if not child:
        raise HTTPException(
            status_code=404,
            detail="Child not found"
        )

    # 2. Parent can only screen their own child
    if current_user["role"] == "parent":
        if current_user["user_id"] != child_id:
            raise HTTPException(
                status_code=403,
                detail="Parents can only screen their own child"
            )

    # 3. Health worker can screen selected children
    elif current_user["role"] == "health_worker":
        pass

    else:
        raise HTTPException(
            status_code=403,
            detail="Invalid user role"
        )

    # 4. Generate unique filename
    file_extension = Path(file.filename).suffix
    unique_filename = f"{uuid.uuid4()}{file_extension}"

    image_path = UPLOAD_DIR / unique_filename

    # 5. Save uploaded image temporarily
    with image_path.open("wb") as buffer:
        shutil.copyfileobj(file.file, buffer)

    try:
        # 6. Run the PRODUCTION hybrid ML prediction (168-feature fusion + SVM)
        prediction_result = run_hybrid_prediction(
            image_path.read_bytes(),
            extract_anthropometrics({
                "gender": child.get("gender"),
                "age_years": child.get("age"),
                "height_cm": child.get("height"),
                "weight_kg": child.get("weight"),
            }),
        )

        # 7. Save prediction to MongoDB
        screening = await create_screening(
            child_id=child_id,
            prediction=prediction_result["prediction"],
            confidence=prediction_result["confidence"],
            probabilities=prediction_result["probabilities"]
        )

        # 8. Return result
        return screening

    finally:
        # 9. Delete temporary image
        if image_path.exists():
            image_path.unlink()


@router.get("/history/{child_id}")
async def screening_history(
    child_id: str,
    current_user: dict = Depends(get_current_user)
):
    # 1. Verify that the child exists
    child = await get_child_by_id(child_id)

    if not child:
        raise HTTPException(
            status_code=404,
            detail="Child not found"
        )

    # 2. Parent can only access their own child's history
    if current_user["role"] == "parent":
        if current_user["user_id"] != child_id:
            raise HTTPException(
                status_code=403,
                detail="Parents can only access their own child's history"
            )

    # 3. Health workers can access selected children
    elif current_user["role"] == "health_worker":
        pass

    else:
        raise HTTPException(
            status_code=403,
            detail="Invalid user role"
        )

    # 4. Get screening history
    history = await get_screening_history(child_id)

    return history