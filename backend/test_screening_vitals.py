import os
import asyncio
import io
from datetime import datetime, timezone

# Router imports initialize the configured Mongo client, but these tests never
# issue database requests or insert records.
os.environ.setdefault("MONGODB_URI", "mongodb://127.0.0.1:27017")

import pytest
from bson import ObjectId
from fastapi.encoders import jsonable_encoder
from starlette.datastructures import UploadFile
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


def test_predict_route_persists_confirmed_vitals_with_model_result(monkeypatch, tmp_path):
    captured = {}
    async def child(child_id):
        return {"childId": child_id, "dob": "2023-01-15T00:00:00+00:00"}
    def predict(image, anthropometrics):
        captured["anthropometrics"] = anthropometrics
        return {"prediction": "underweight", "label_index": 1, "confidence": .7,
                "probabilities": {"underweight": .7}, "class_scores_raw": {"underweight": .4},
                "status": "Underweight", "risk": "High Risk", "recommendation": "follow up",
                "model": "hybrid_production_v1", "feature_vector_dim": 168}
    async def save(**kwargs):
        captured["save"] = kwargs
        return {"screeningId": "persisted", "childId": kwargs["child_id"],
                "vitals": kwargs["vitals"], "screening_result": kwargs["screening_result"]}
    monkeypatch.setattr(screening, "UPLOAD_DIR", tmp_path)
    monkeypatch.setattr(screening, "get_child_by_id", child)
    monkeypatch.setattr(screening, "run_hybrid_prediction", predict)
    monkeypatch.setattr(screening, "create_screening", save)
    upload = UploadFile(filename="scan.jpg", file=io.BytesIO(b"image-bytes"))

    result = asyncio.run(screening.predict_for_child(
        "CHD006", upload, age_years=2, age_months=3, gender="Boy",
        height_cm=40, weight_kg=2, head_circumference_cm=None,
        waist_cm=None, muac_cm=None,
        current_user={"role": "health_worker", "user_id": "worker-a"}))

    assert result["screeningId"] == "persisted"
    assert captured["save"]["child_id"] == "CHD006"
    assert captured["save"]["vitals"]["height_cm"] == 40
    assert captured["save"]["vitals"]["weight_kg"] == 2
    assert captured["save"]["vitals"]["bmi"] == 12.5
    assert captured["save"]["screening_result"]["confidence"] == .7
    assert captured["anthropometrics"]["height_cm"] == 40
    assert captured["anthropometrics"]["weight_kg"] == 2


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
        document = None
        async def insert_one(self, document):
            document["_id"] = ObjectId()
            self.document = document
            return type("InsertResult", (), {"inserted_id": document["_id"]})()
        async def find_one(self, query):
            return self.document

    collection = FakeCollection()
    monkeypatch.setattr(screening_service, "screenings_collection", collection)
    vitals = {"height_cm": 40.0, "weight_kg": 2.0, "bmi": 12.5}
    model = {"prediction": "healthy", "label_index": 0, "confidence": .8,
             "probabilities": {"healthy": .8}, "status": "Healthy", "risk": "Low Risk",
             "recommendation": "follow up", "model": "hybrid_production_v1",
             "feature_vector_dim": 168}
    result = asyncio.run(screening_service.create_screening(
        "CHD001", "healthy", .8, model["probabilities"], vitals, model))
    assert collection.document["childId"] == "CHD001"
    assert collection.document["vitals"] == vitals
    assert collection.document["screening_result"] == model
    assert result["screeningId"]
    assert result["screening_result"]["confidence"] == .8
    assert result["vitals"]["height_cm"] == 40.0


def test_history_includes_result_vitals_and_orders_latest_first(monkeypatch):
    class Cursor:
        def sort(self, key, direction):
            assert key == "createdAt" and direction == -1
            return self
        async def to_list(self, length):
            return [{"_id": ObjectId(), "childId": "CHD006", "child_id": "CHD006",
                     "createdAt": datetime.now(timezone.utc),
                     "vitals": {"height_cm": 120.0},
                     "screening_result": {"prediction": "underweight", "confidence": .7,
                         "probabilities": {"underweight": .7}, "status": "Underweight",
                         "risk": "High Risk", "recommendation": "review"}}]
    class Collection:
        def find(self, query, projection):
            assert query == {"childId": "CHD006"}
            return Cursor()
    monkeypatch.setattr(screening_service, "screenings_collection", Collection())
    rows = asyncio.run(screening_service.get_screening_history("CHD006"))
    assert rows[0]["child_id"] == "CHD006"
    assert rows[0]["vitals"]["height_cm"] == 120.0
    assert rows[0]["confidence"] == .7
    assert rows[0]["risk"] == "High Risk"


def test_two_screenings_insert_two_distinct_records(monkeypatch):
    class Collection:
        def __init__(self):
            self.documents = {}
        async def insert_one(self, document):
            object_id = ObjectId()
            self.documents[object_id] = dict(document, _id=object_id)
            return type("InsertResult", (), {"inserted_id": object_id})()
        async def find_one(self, query):
            return self.documents[query["_id"]]
    collection = Collection()
    monkeypatch.setattr(screening_service, "screenings_collection", collection)
    first, second = asyncio.run(_save_two(collection))
    assert first["screeningId"] != second["screeningId"]
    assert len(collection.documents) == 2
    assert collection.documents[ObjectId(first["screeningId"])]["vitals"]["height_cm"] == 40
    assert collection.documents[ObjectId(second["screeningId"])]["vitals"]["height_cm"] == 120


async def _save_two(collection):
    one = await screening_service.create_screening(
        "CHD006", "healthy", .8, {"healthy": .8}, {"height_cm": 40})
    two = await screening_service.create_screening(
        "CHD006", "underweight", .7, {"underweight": .7}, {"height_cm": 120})
    return one, two


@pytest.mark.parametrize("field", ["height_cm", "weight_kg", "muac_cm", "head_circumference_cm", "waist_cm"])
def test_optional_measurements_reject_non_positive_values(field):
    with pytest.raises(ValidationError):
        VitalsInput(age_years=2, age_months=3, **{field: 0})
