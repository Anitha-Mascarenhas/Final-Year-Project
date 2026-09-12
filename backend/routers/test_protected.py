from fastapi import APIRouter, Depends

from security.dependencies import (
    get_current_user,
    require_parent,
    require_health_worker
)

router = APIRouter(
    prefix="/api/test",
    tags=["Protected API Testing"]
)


@router.get("/protected")
async def protected_endpoint(
    current_user: dict = Depends(get_current_user)
):
    return {
        "message": "You are authenticated!",
        "user": current_user
    }


@router.get("/parent-only")
async def parent_only_endpoint(
    current_user: dict = Depends(require_parent)
):
    return {
        "message": "Parent access granted!",
        "user": current_user
    }


@router.get("/health-worker-only")
async def health_worker_only_endpoint(
    current_user: dict = Depends(require_health_worker)
):
    return {
        "message": "Health worker access granted!",
        "user": current_user
    }