import os
import asyncio
from datetime import datetime, timezone

# Router imports initialize the configured Mongo client, but these tests never
# issue database requests or insert records.
os.environ.setdefault("MONGODB_URI", "mongodb://127.0.0.1:27017")

import pytest
from bson import ObjectId
from fastapi.encoders import jsonable_encoder
from pydantic import ValidationError

from routers import screening
from routers.screening import VitalsInput, calculate_bmi
from services import screening_service


def test_age_only_and_optional_measurements():
    data = VitalsInput(age_years=2, age_months=3)
    assert data.age_years == 2 and data.age_months == 3
    assert data.height_cm is None and data.weight_kg is None
    assert calculate_bmi(data.height_cm, data.weight_kg) is None


@pytest.mark.parametrize("values", [
    {"age_months": 3}, {"age_years": 2},
    {"age_years": 2, "age_months": 12},
    {"age_years": -1, "age_months": 0},
    {"age_years": 0, "age_months": -1},
])
def test_invalid_age_is_rejected(values):
    with pytest.raises(ValidationError):
        VitalsInput(**values)


def test_height_only_and_weight_only_are_valid():
    assert VitalsInput(age_years=2, age_months=3, height_cm=90).height_cm == 90
    assert VitalsInput(age_years=2, age_months=3, weight_kg=12).weight_kg == 12


def test_bmi_is_computed_only_when_both_measures_exist():
    assert calculate_bmi(92.5, 14.2) == 16.59
    assert calculate_bmi(92.5, None) is None
    assert calculate_bmi(None, 14.2) is None


def test_vitals_endpoint_authorizes_parent_and_returns_saved_record(monkeypatch):
    inserted = []

    async def child(child_id):
        return {"childId": child_id, "childName": "Test child"}

    async def save(child_id, vitals):
        inserted.append((child_id, vitals))
        return {"screeningId": "new-record", "childId": child_id, "vitals": vitals}

    monkeypatch.setattr(screening, "get_child_by_id", child)
    monkeypatch.setattr(screening, "create_vitals_screening", save)
    payload = VitalsInput(age_years=2, age_months=3, height_cm=92.5, weight_kg=14.2)
    result = asyncio.run(screening.log_vitals("child-a", payload, {"role": "parent", "user_id": "child-a"}))
    assert result["screeningId"] == "new-record"
    assert inserted[0][0] == "child-a"
    assert inserted[0][1]["bmi"] == 16.59
    assert inserted[0][1]["recorded_at"] is not None


def test_vitals_endpoint_rejects_parent_for_another_child(monkeypatch):
    async def child(child_id):
        return {"childId": child_id}

    async def should_not_save(*args):
        raise AssertionError("unauthorized request reached persistence")

    monkeypatch.setattr(screening, "get_child_by_id", child)
    monkeypatch.setattr(screening, "create_vitals_screening", should_not_save)
    with pytest.raises(screening.HTTPException) as error:
        asyncio.run(screening.log_vitals("child-b", VitalsInput(age_years=2, age_months=3), {"role": "parent", "user_id": "child-a"}))
    assert error.value.status_code == 403


def test_saved_vitals_response_does_not_leak_mongo_object_id(monkeypatch):
    class FakeCollection:
        def __init__(self):
            self.documents = {}

        async def insert_one(self, document):
            document["_id"] = ObjectId()
            self.documents[document["_id"]] = dict(document)
            return type("InsertResult", (), {"inserted_id": document["_id"]})()

        async def find_one(self, query):
            return self.documents.get(query["_id"])

    monkeypatch.setattr(screening_service, "screenings_collection", FakeCollection())
    vitals = {"age_years": 3, "age_months": 2, "recorded_at": datetime.now(timezone.utc)}
    result = asyncio.run(screening_service.create_vitals_screening("CHD006", vitals))
    assert result["screeningId"]
    assert "_id" not in result
    assert jsonable_encoder(result)["vitals"]["age_years"] == 3


def test_vitals_write_inserts_nested_document_in_screenings(monkeypatch):
    class FakeCollection:
        def __init__(self):
            self.inserted = None

        async def insert_one(self, document):
            self.inserted = dict(document, _id=ObjectId())
            return type("InsertResult", (), {"inserted_id": self.inserted["_id"]})()

        async def find_one(self, query):
            assert query["_id"] == self.inserted["_id"]
            return self.inserted

    collection = FakeCollection()
    monkeypatch.setattr(screening_service, "screenings_collection", collection)
    vitals = {
        "age_years": 2,
        "age_months": 3,
        "height_cm": 105.0,
        "weight_kg": 18.0,
        "head_circumference_cm": None,
        "waist_cm": None,
        "muac_cm": None,
        "bmi": 16.33,
        "gender": None,
        "recorded_at": datetime.now(timezone.utc),
    }

    result = asyncio.run(screening_service.create_vitals_screening("CHD001", vitals))

    assert collection.inserted["childId"] == "CHD001"
    assert collection.inserted["vitals"] == vitals
    assert result["vitals"]["height_cm"] == 105.0
    assert result["vitals"]["weight_kg"] == 18.0
    assert result["vitals"]["bmi"] == 16.33


def test_new_prediction_screening_includes_vitals_field(monkeypatch):
    class FakeCollection:
        async def insert_one(self, document):
            assert document["vitals"] == {}
            document["_id"] = ObjectId()
            return type("InsertResult", (), {"inserted_id": document["_id"]})()

    monkeypatch.setattr(screening_service, "screenings_collection", FakeCollection())
    result = asyncio.run(screening_service.create_screening("CHD001", "healthy", 0.58, {}))
    assert result["vitals"] == {}


@pytest.mark.parametrize("field", ["height_cm", "weight_kg", "muac_cm", "head_circumference_cm", "waist_cm"])
def test_optional_measurements_reject_non_positive_values(field):
    with pytest.raises(ValidationError):
        VitalsInput(age_years=2, age_months=3, **{field: 0})
