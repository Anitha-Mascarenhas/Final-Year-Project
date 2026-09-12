from fastapi import APIRouter, Depends, HTTPException, Query

from security.dependencies import require_health_worker

from services.child_service import (
    search_children,
    get_child_by_id,
    get_child_profile
)


router = APIRouter(
    prefix="/api/health-worker",
    tags=["Health Worker"]
)


@router.get("/children/search")
async def search_child(
    q: str = Query(..., min_length=1),
    current_user: dict = Depends(require_health_worker)
):
    children = await search_children(q)

    if not children:
        raise HTTPException(
            status_code=404,
            detail="No children found"
        )

    return children


@router.get("/children/{child_id}/profile")
async def get_profile(
    child_id: str,
    current_user: dict = Depends(require_health_worker)
):
    child = await get_child_profile(child_id)

    if not child:
        raise HTTPException(
            status_code=404,
            detail="Child not found"
        )

    return child


@router.get("/children/{child_id}")
async def get_child(
    child_id: str,
    current_user: dict = Depends(require_health_worker)
):
    child = await get_child_by_id(child_id)

    if not child:
        raise HTTPException(
            status_code=404,
            detail="Child not found"
        )

    return child