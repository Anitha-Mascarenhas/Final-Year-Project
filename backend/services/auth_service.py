from datetime import datetime, timezone

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
        "email": data.email,
        "createdAt": datetime.now(timezone.utc)
    }

    await children_collection.insert_one(child_document)

    await parents_collection.insert_one(parent_document)

    return {
        "childId": child_id,
        "message": "Account created successfully"
    }

#This is the function to create a health worker account. It takes in the data from the HealthWorkerSignupRequest schema, checks if the passwords match, generates a unique worker ID, hashes the password, and inserts the new health worker document into the health_workers_collection in MongoDB. Finally, it returns a success message along with the generated worker ID.

async def create_health_worker_account(data):

    if data.password != data.confirmPassword:
        raise ValueError("Passwords do not match")

    worker_id = await generate_worker_id()

    worker_document = {
        "workerId": worker_id,
        "name": data.name,
        "passwordHash": hash_password(data.password),
        "email": data.email,
        "createdAt": datetime.now(timezone.utc)
    }

    await health_workers_collection.insert_one(worker_document)

    return {
        "workerId": worker_id,
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

    return {
        "access_token": access_token,
        "token_type": "bearer"
    }