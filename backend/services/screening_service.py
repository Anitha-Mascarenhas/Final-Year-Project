from datetime import datetime, timezone

from db.mongodb import screenings_collection


async def create_screening(
    child_id: str,
    prediction: str,
    confidence: float,
    probabilities: dict,
    vitals: dict | None = None,
):
    screening_document = {
        "childId": child_id,
        "prediction": prediction,
        "confidence": confidence,
        "probabilities": probabilities,
        "createdAt": datetime.now(timezone.utc),
        # Every newly-created screening has the same nested data shape. Older
        # MongoDB documents without this field remain valid and are left alone.
        "vitals": vitals or {},
    }

    result = await screenings_collection.insert_one(screening_document)

    response = {
        "screeningId": str(result.inserted_id),
        "childId": child_id,
        "prediction": prediction,
        "confidence": confidence,
        "probabilities": probabilities,
        "createdAt": screening_document["createdAt"]
    }
    response["vitals"] = screening_document["vitals"]
    return response


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
        {"childId": child_id},
        {
            "_id": 1,
            "childId": 1,
            "prediction": 1,
            "confidence": 1,
            "probabilities": 1,
            "createdAt": 1,
            "vitals": 1
        }
    ).sort("createdAt", -1).to_list(length=100)

    history = []

    for screening in screenings:
        history.append({
            "screeningId": str(screening["_id"]),
            "childId": screening["childId"],
            "prediction": screening.get("prediction"),
            "confidence": screening.get("confidence"),
            "probabilities": screening.get("probabilities"),
            "createdAt": screening.get("createdAt")
        })
        if "vitals" in screening:
            history[-1]["vitals"] = screening["vitals"]

    return history
