from datetime import datetime, timezone
from pymongo.errors import DuplicateKeyError
from services.hospital_service import get_hospital_by_id

from db.mongodb import (
    children_collection,
    parents_collection,
    health_workers_collection
)

from security.auth import (
    hash_password,
    verify_password,
    create_access_token
)

from services.id_service import (
    generate_child_id,
    generate_worker_id
)


async def create_parent_account(data):

    if data.password != data.confirmPassword:
        raise ValueError("Passwords do not match")

    email = data.email.strip().casefold() if data.email else None
    request_id = getattr(data, "registrationRequestId", None)

    if request_id:
        existing = await parents_collection.find_one(
            {"registrationRequestId": request_id}
        )
        if existing:
            child = await children_collection.find_one(
                {"childId": existing["childId"]}
            )
            same_request = (
                child is not None
                and child.get("childName") == data.childName
                and child.get("dob") == data.dob.isoformat()
                and existing.get("email") == email
                and verify_password(data.password, existing["passwordHash"])
            )
            if not same_request:
                raise ValueError("This registration request was already used")
            return {
                "childId": existing["childId"],
                "message": "Account created successfully",
            }

    if email and await parents_collection.find_one({"email": email}):
        raise ValueError("An account with this email already exists")

    child_id = await generate_child_id()

    child_document = {
        "childId": child_id,
        "childName": data.childName,
        "dob": data.dob.isoformat(),
        "createdAt": datetime.now(timezone.utc)
    }

    parent_document = {
        "childId": child_id,
        "passwordHash": hash_password(data.password),
        "email": email,
        "createdAt": datetime.now(timezone.utc)
    }
    if request_id:
        parent_document["registrationRequestId"] = request_id

    child_insert = await children_collection.insert_one(child_document)
    try:
        await parents_collection.insert_one(parent_document)
    except DuplicateKeyError:
        await children_collection.delete_one({"_id": child_insert.inserted_id})
        if request_id:
            existing = await parents_collection.find_one(
                {"registrationRequestId": request_id}
            )
            if existing:
                child = await children_collection.find_one(
                    {"childId": existing["childId"]}
                )
                if (
                    child is not None
                    and child.get("childName") == data.childName
                    and child.get("dob") == data.dob.isoformat()
                    and existing.get("email") == email
                    and verify_password(data.password, existing["passwordHash"])
                ):
                    return {
                        "childId": existing["childId"],
                        "message": "Account created successfully",
                    }
        raise ValueError("An account with this email already exists")
    except Exception:
        await children_collection.delete_one({"_id": child_insert.inserted_id})
        raise

    return {
        "childId": child_id,
        "message": "Account created successfully"
    }


async def ensure_parent_registration_index():
    """Make registration retries idempotent even when requests arrive concurrently."""
    await parents_collection.create_index(
        "registrationRequestId", unique=True, sparse=True
    )

#This is the function to create a health worker account. It takes in the data from the HealthWorkerSignupRequest schema, checks if the passwords match, generates a unique worker ID, hashes the password, and inserts the new health worker document into the health_workers_collection in MongoDB. Finally, it returns a success message along with the generated worker ID.

async def create_health_worker_account(data):
    if data.password != data.confirmPassword:
        raise ValueError("Passwords do not match")

    hospital = await get_hospital_by_id(data.hospitalId)

    if not hospital:
        raise ValueError("Invalid or unregistered hospital ID")

    worker_id = await generate_worker_id()

    worker_document = {
        "workerId": worker_id,
        "name": data.name,
        "hospitalId": hospital["hospitalId"],
        "passwordHash": hash_password(data.password),
        "email": data.email,
        "createdAt": datetime.now(timezone.utc)
    }

    await health_workers_collection.insert_one(worker_document)

    return {
        "workerId": worker_id,
        "hospitalId": hospital["hospitalId"],
        "hospitalName": hospital["hospitalName"],
        "message": "Health worker account created successfully"
    }

#This is the function to log in a parent. It takes in the data from the ParentLoginRequest schema, retrieves the parent document from the parents_collection in MongoDB using the provided childId, verifies the password, and generates an access token if the credentials are valid. Finally, it returns the access token and token type.
async def login_health_worker(data):

    worker = await health_workers_collection.find_one(
        {"workerId": data.workerId}
    )

    if not worker:
        raise ValueError("Invalid worker ID or password")

    password_correct = verify_password(
        data.password,
        worker["passwordHash"]
    )

    if not password_correct:
        raise ValueError("Invalid worker ID or password")

    access_token = create_access_token(
        user_id=worker["workerId"],
        role="health_worker"
    )

    return {
        "access_token": access_token,
        "token_type": "bearer"
    }

#This is the function to log in a parent. It takes in the data from the ParentLoginRequest schema, retrieves the parent document from the parents_collection in MongoDB using the provided childId, verifies the password, and generates an access token if the credentials are valid. Finally, it returns the access token and token type.
async def login_parent(data):

    parent = await parents_collection.find_one(
        {"childId": data.childId}
    )

    if not parent:
        raise ValueError("Invalid child ID or password")

    password_correct = verify_password(
        data.password,
        parent["passwordHash"]
    )

    if not password_correct:
        raise ValueError("Invalid child ID or password")

    access_token = create_access_token(
        user_id=parent["childId"],
        role="parent"
    )

    from services.child_service import get_child_by_id
    child = await get_child_by_id(parent["childId"])

    return {
        "access_token": access_token,
        "token_type": "bearer",
        "childId": parent["childId"],
        "childName": child.get("childName", "Child") if child else "Child",
        "dateOfBirth": child.get("dob") if child else None,
    }
