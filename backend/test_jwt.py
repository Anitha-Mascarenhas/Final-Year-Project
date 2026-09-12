# from security.auth import (
#     create_access_token,
#     verify_access_token,
#     get_token_user
# )


# token = create_access_token(
#     user_id="CHD001",
#     role="parent"
# )

# print("TOKEN:")
# print(token)

# print("\nPAYLOAD:")
# print(verify_access_token(token))

# print("\nUSER:")
# print(get_token_user(token))

#=====================================

# from security.auth import (
#     create_access_token,
#     verify_access_token,
#     get_token_user
# )


# token = create_access_token(
#     user_id="HW001",
#     role="health_worker"
# )

# print("TOKEN:")
# print(token)

# print("\nPAYLOAD:")
# print(verify_access_token(token))

# print("\nUSER:")
# print(get_token_user(token))


# # Test invalid token
# print("\nINVALID TOKEN TEST:")

# try:
#     verify_access_token(token + "abc")
#     print("ERROR: Invalid token was accepted!")

# except ValueError as e:
#     print("PASS:", e)


#================================

from datetime import datetime, timedelta, timezone

import jwt

from security.auth import (
    JWT_SECRET,
    JWT_ALGORITHM,
    verify_access_token
)


expired_payload = {
    "sub": "HW001",
    "role": "health_worker",
    "exp": datetime.now(timezone.utc) - timedelta(minutes=1)
}

expired_token = jwt.encode(
    expired_payload,
    JWT_SECRET,
    algorithm=JWT_ALGORITHM
)

print("\nEXPIRED TOKEN TEST:")

try:
    verify_access_token(expired_token)
    print("ERROR: Expired token was accepted!")

except ValueError as e:
    print("PASS:", e)