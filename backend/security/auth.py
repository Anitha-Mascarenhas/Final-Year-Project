import os
from datetime import datetime, timedelta, timezone

import jwt
from dotenv import load_dotenv
from pwdlib import PasswordHash


load_dotenv()


# -----------------------------
# Password hashing
# -----------------------------

password_hash = PasswordHash.recommended()


def hash_password(password: str) -> str:
    return password_hash.hash(password)


def verify_password(
    plain_password: str,
    hashed_password: str
) -> bool:
    return password_hash.verify(
        plain_password,
        hashed_password
    )


# -----------------------------
# JWT configuration
# -----------------------------

JWT_SECRET = os.getenv("JWT_SECRET")

JWT_ALGORITHM = os.getenv(
    "JWT_ALGORITHM",
    "HS256"
)

JWT_EXPIRE_MINUTES = int(
    os.getenv(
        "JWT_EXPIRE_MINUTES",
        "60"
    )
)


if not JWT_SECRET:
    raise RuntimeError(
        "JWT_SECRET is not configured"
    )


# -----------------------------
# Create JWT
# -----------------------------

def create_access_token(
    user_id: str,
    role: str
) -> str:

    expire = datetime.now(
        timezone.utc
    ) + timedelta(
        minutes=JWT_EXPIRE_MINUTES
    )

    payload = {
        "sub": user_id,
        "role": role,
        "exp": expire
    }

    token = jwt.encode(
        payload,
        JWT_SECRET,
        algorithm=JWT_ALGORITHM
    )

    return token


# -----------------------------
# Verify JWT
# -----------------------------

def verify_access_token(
    token: str
) -> dict:

    try:

        payload = jwt.decode(
            token,
            JWT_SECRET,
            algorithms=[JWT_ALGORITHM]
        )

        return payload

    except jwt.ExpiredSignatureError:

        raise ValueError(
            "Token has expired"
        )

    except jwt.InvalidTokenError:

        raise ValueError(
            "Invalid token"
        )


# -----------------------------
# Read user information
# -----------------------------

def get_token_user(
    token: str
) -> dict:

    payload = verify_access_token(token)

    user_id = payload.get("sub")
    role = payload.get("role")

    if not user_id or not role:
        raise ValueError(
            "Invalid token payload"
        )

    return {
        "user_id": user_id,
        "role": role
    }