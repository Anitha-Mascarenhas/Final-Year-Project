from typing import Optional

from fastapi import APIRouter, Depends, HTTPException
from pydantic import BaseModel, Field

from security.dependencies import get_current_user
from services.child_service import get_child_by_id
from services.nutrition_service import build_nutrition_recommendation, fetch_screening_history


router = APIRouter(prefix="/api/nutrition", tags=["Nutrition"])


class RegionInput(BaseModel):
    country: Optional[str] = Field(default=None, max_length=100)
    state: Optional[str] = Field(default=None, max_length=100)
    district: Optional[str] = Field(default=None, max_length=100)


class NutritionRequest(BaseModel):
    region: RegionInput = Field(default_factory=RegionInput)
    allergies: list[str] = Field(default_factory=list, max_length=30)
    dietary_preferences: list[str] = Field(default_factory=list, max_length=30)


@router.post("/recommendation/{child_id}")
async def personalized_nutrition(
    child_id: str,
    payload: NutritionRequest,
    current_user: dict = Depends(get_current_user),
):
    child = await get_child_by_id(child_id)
    if child is None:
        raise HTTPException(status_code=404, detail="Child not found")
    role = current_user.get("role")
    if role == "parent":
        if current_user.get("user_id") != child_id:
            raise HTTPException(status_code=403, detail="Parents can only access their own child's nutrition plan")
    elif role != "health_worker":
        raise HTTPException(status_code=403, detail="Invalid user role")

    history = await fetch_screening_history(child_id)
    region = payload.region.model_dump(exclude_none=True)
    return build_nutrition_recommendation(
        child_id=child_id,
        records=history,
        region=region,
        allergies=payload.allergies,
        dietary_preferences=payload.dietary_preferences,
    )
