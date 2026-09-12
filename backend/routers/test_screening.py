from fastapi import APIRouter, Depends

from security.dependencies import get_current_user
from services.screening_service import create_screening


router = APIRouter(
    prefix="/api/test-screening",
    tags=["Screening Testing"]
)


@router.post("/")
async def test_create_screening(
    current_user: dict = Depends(get_current_user)
):
    result = await create_screening(
        child_id="CHD001",
        prediction="healthy",
        confidence=0.58,
        probabilities={
            "healthy": 0.58,
            "stunted": 0.08,
            "stunted and underweight": 0.16,
            "underweight": 0.16
        }
    )

    return result