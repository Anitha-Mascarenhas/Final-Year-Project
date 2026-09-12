from fastapi import APIRouter, HTTPException

from schemas.auth import (
    ParentSignupRequest,
    HealthWorkerSignupRequest,
    ParentLoginRequest,
    HealthWorkerLoginRequest
)

from services.auth_service import (
    create_parent_account,
    create_health_worker_account,
    login_health_worker,
    login_parent
)


router = APIRouter(
    prefix="/api/auth",
    tags=["Authentication"]
)


@router.post("/parent/signup")
async def parent_signup(data: ParentSignupRequest):

    try:
        result = await create_parent_account(data)

        return result

    except ValueError as e:
        raise HTTPException(
            status_code=400,
            detail=str(e)
        )

#This is the endpoint for health worker signup. It takes in a HealthWorkerSignupRequest object, which contains the necessary information for creating a health worker account. The endpoint calls the create_health_worker_account function from the auth_service module to handle the account creation logic. If the account is created successfully, it returns the result. If there is a ValueError (e.g., passwords do not match), it raises an HTTPException with a 400 status code and the error message.
@router.post("/health-worker/signup")
async def health_worker_signup(data: HealthWorkerSignupRequest):

    try:
        result = await create_health_worker_account(data)

        return result

    except ValueError as e:
        raise HTTPException(
            status_code=400,
            detail=str(e)
        )

#This is the endpoint for health worker login. It takes in a HealthWorkerLoginRequest object, which contains the necessary information for logging in a health worker account. The endpoint calls the login_health_worker function from the auth_service module to handle the login logic. If the login is successful, it returns the result. If there is a ValueError (e.g., invalid credentials), it raises an HTTPException with a 401 status code and the error message.
@router.post("/health-worker/login")
async def health_worker_login(
    data: HealthWorkerLoginRequest
):
    try:

        result = await login_health_worker(data)

        return result

    except ValueError as e:

        raise HTTPException(
            status_code=401,
            detail=str(e)
        )

#This is the endpoint for parent login. It takes in a ParentLoginRequest object, which contains the necessary information for logging in a parent account. The endpoint calls the login_parent function from the auth_service module to handle the login logic. If the login is successful, it returns the result. If there is a ValueError (e.g., invalid credentials), it raises an HTTPException with a 401 status code and the error message.
@router.post("/parent/login")
async def parent_login(
    data: ParentLoginRequest
):
    try:

        result = await login_parent(data)

        return result

    except ValueError as e:

        raise HTTPException(
            status_code=401,
            detail=str(e)
        )