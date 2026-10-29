import asyncio
from datetime import date
from types import SimpleNamespace

from services import auth_service, child_service


class MemoryCollection:
    def __init__(self):
        self.documents = []

    async def insert_one(self, document):
        stored = dict(document)
        stored.setdefault("_id", len(self.documents) + 1)
        self.documents.append(stored)
        return SimpleNamespace(inserted_id=stored["_id"])

    async def delete_one(self, query):
        self.documents = [
            doc for doc in self.documents
            if not all(doc.get(key) == value for key, value in query.items())
        ]

    async def find_one(self, query, _projection=None):
        return next(
            (doc for doc in self.documents
             if all(doc.get(key) == value for key, value in query.items())),
            None,
        )


def test_registration_persists_real_id_and_login_returns_same_id(monkeypatch):
    child_id = "CHD841"
    children = MemoryCollection()
    parents = MemoryCollection()

    async def assigned_id():
        return child_id

    monkeypatch.setattr(auth_service, "children_collection", children)
    monkeypatch.setattr(auth_service, "parents_collection", parents)
    monkeypatch.setattr(auth_service, "generate_child_id", assigned_id)
    monkeypatch.setattr(auth_service, "hash_password", lambda password: f"hash:{password}")
    monkeypatch.setattr(auth_service, "verify_password", lambda *_: True)
    monkeypatch.setattr(auth_service, "create_access_token", lambda **_: "test-token")
    monkeypatch.setattr(child_service, "children_collection", children)

    signup_data = SimpleNamespace(
        password="pass1234",
        confirmPassword="pass1234",
        childName="Test Child",
        dob=date(2022, 4, 5),
        email="parent@example.test",
        registrationRequestId="a1b2c3d4e5f607182930a1b2c3d4e5f6",
    )
    signup = asyncio.run(auth_service.create_parent_account(signup_data))
    retried_signup = asyncio.run(auth_service.create_parent_account(signup_data))

    assert signup["childId"] == child_id
    assert retried_signup["childId"] == child_id
    assert len(children.documents) == 1
    assert len(parents.documents) == 1
    assert children.documents[0]["childId"] == child_id
    assert parents.documents[0]["childId"] == child_id

    login = asyncio.run(auth_service.login_parent(
        SimpleNamespace(childId=child_id, password="pass1234")
    ))
    assert login["childId"] == signup["childId"]
    assert login["childName"] == "Test Child"
    assert login["access_token"] == "test-token"


def test_registration_rejects_reused_request_id_for_different_details(monkeypatch):
    children = MemoryCollection()
    parents = MemoryCollection()
    monkeypatch.setattr(auth_service, "children_collection", children)
    monkeypatch.setattr(auth_service, "parents_collection", parents)
    monkeypatch.setattr(auth_service, "hash_password", lambda password: f"hash:{password}")
    monkeypatch.setattr(auth_service, "verify_password", lambda password, hashed: f"hash:{password}" == hashed)

    def request(child_name):
        return SimpleNamespace(
            password="pass1234",
            confirmPassword="pass1234",
            childName=child_name,
            dob=date(2022, 4, 5),
            email="parent@example.test",
            registrationRequestId="a1b2c3d4e5f607182930a1b2c3d4e5f6",
        )

    monkeypatch.setattr(auth_service, "generate_child_id", _assigned_id("CHD001"))
    asyncio.run(auth_service.create_parent_account(request("Test Child")))
    try:
        asyncio.run(auth_service.create_parent_account(request("Different Child")))
        assert False, "expected reused request ID to be rejected"
    except ValueError as error:
        assert "already used" in str(error)
    assert len(children.documents) == 1
    assert len(parents.documents) == 1


def test_duplicate_email_does_not_create_another_child(monkeypatch):
    children = MemoryCollection()
    parents = MemoryCollection()
    parents.documents.append({"childId": "CHD001", "email": "parent@example.test"})
    monkeypatch.setattr(auth_service, "children_collection", children)
    monkeypatch.setattr(auth_service, "parents_collection", parents)

    async def unexpected_id_generation():
        raise AssertionError("a duplicate email must be rejected before ID allocation")

    monkeypatch.setattr(auth_service, "generate_child_id", unexpected_id_generation)
    signup_data = SimpleNamespace(
        password="pass1234",
        confirmPassword="pass1234",
        childName="Test Child",
        dob=date(2022, 4, 5),
        email="parent@example.test",
        registrationRequestId="a1b2c3d4e5f607182930a1b2c3d4e5f6",
    )

    try:
        asyncio.run(auth_service.create_parent_account(signup_data))
        assert False, "expected duplicate email to be rejected"
    except ValueError as error:
        assert "already exists" in str(error)

    assert children.documents == []
    assert len(parents.documents) == 1


def _assigned_id(child_id):
    async def assigned():
        return child_id
    return assigned
