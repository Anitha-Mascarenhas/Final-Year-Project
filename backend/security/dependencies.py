from fastapi import Depends, HTTPException, status
from fastapi.security import HTTPBearer, HTTPAuthorizationCredentials

from security.auth import get_token_user


# Tells FastAPI to expect:
# Authorization: Bearer <token>
security = HTTPBearer()


async def get_current_user(
    credentials: HTTPAuthorizationCredentials = Depends(security)
):
    """
    Extracts the JWT token from the Authorization header,
    verifies it, and returns the user's identity.
    """

    token = credentials.credentials

    try:
        user = get_token_user(token)

        return user

    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail=str(e)
        )


async def require_parent(
    current_user: dict = Depends(get_current_user)
):
    """
    Allows access only to authenticated parents.
    """

    if current_user["role"] != "parent":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Parent access required"
        )

    return current_user


async def require_health_worker(
    current_user: dict = Depends(get_current_user)
):
    """
    Allows access only to authenticated health workers.
    """

    if current_user["role"] != "health_worker":
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="Health worker access required"
        )

    return current_user