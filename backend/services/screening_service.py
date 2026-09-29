from datetime import datetime, timezone

from db.mongodb import screenings_collection


async def create_screening(
    child_id: str,
    prediction: str,
    confidence: float,
    probabilities: dict,
    vitals: dict | None = None,
    screening_result: dict | None = None,
):
    result = screening_result or {
        "prediction": prediction,
        "confidence": confidence,
        "probabilities": probabilities,
    }
    screened_at = (vitals or {}).get("recorded_at") or datetime.now(timezone.utc)
    screening_document = {
        "childId": child_id,
        "child_id": child_id,
        "prediction": prediction,
        "confidence": confidence,
        "probabilities": probabilities,
        "screening_result": result,
        "createdAt": screened_at,
        "screened_at": screened_at,
        # Every newly-created screening has the same nested data shape. Older
        # MongoDB documents without this field remain valid and are left alone.
        "vitals": vitals or {},
    }

    result = await screenings_collection.insert_one(screening_document)
    saved = await screenings_collection.find_one({"_id": result.inserted_id})
    if saved is None:
        raise RuntimeError("MongoDB did not return the newly saved screening")
    return _screening_json(saved)


def _screening_json(screening: dict) -> dict:
    result = screening.get("screening_result") or {
        key: screening.get(key)
        for key in ("prediction", "label_index", "confidence", "probabilities",
                    "class_scores_raw", "status", "risk", "recommendation", "model",
                    "feature_vector_dim")
        if key in screening
    }
    return {
        "screeningId": str(screening.get("_id", screening.get("screeningId", ""))),
        "childId": screening.get("childId", screening.get("child_id")),
        "child_id": screening.get("child_id", screening.get("childId")),
        "vitals": screening.get("vitals") or {},
        "screening_result": result,
        # Keep the established flat response fields for existing clients.
        **result,
        "createdAt": screening.get("createdAt", screening.get("screened_at")),
        "screened_at": screening.get("screened_at", screening.get("createdAt")),
    }


async def create_vitals_screening(child_id: str, vitals: dict):
    """Insert a vitals-only screening while preserving prior screening records."""
    screening_document = {
        "childId": child_id,
        "vitals": vitals,
        "createdAt": vitals["recorded_at"],
    }
    result = await screenings_collection.insert_one(screening_document)
    saved_document = await screenings_collection.find_one({"_id": result.inserted_id})
    if saved_document is None:
        raise RuntimeError("MongoDB did not return the newly saved vitals screening")
    return {
        "screeningId": str(saved_document["_id"]),
        "childId": saved_document["childId"],
        "vitals": saved_document.get("vitals", {}),
        "createdAt": saved_document.get("createdAt"),
    }


async def get_screening_history(child_id: str):
    screenings = await screenings_collection.find(
        {"$or": [{"childId": child_id}, {"child_id": child_id}]},
        {
            "_id": 1,
            "childId": 1,
            "prediction": 1,
            "confidence": 1,
            "probabilities": 1,
            "createdAt": 1,
            "screened_at": 1,
            "child_id": 1,
            "screening_result": 1,
            "vitals": 1
        }
    ).sort("createdAt", -1).to_list(length=100)

    history = []

    for screening in screenings:
        history.append(_screening_json(screening))

    return history
