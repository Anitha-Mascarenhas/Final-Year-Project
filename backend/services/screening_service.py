from datetime import datetime, timezone

from db.mongodb import screenings_collection


async def create_screening(
    child_id: str,
    prediction: str,
    confidence: float,
    probabilities: dict
):
    screening_document = {
        "childId": child_id,
        "prediction": prediction,
        "confidence": confidence,
        "probabilities": probabilities,
        "createdAt": datetime.now(timezone.utc)
    }

    result = await screenings_collection.insert_one(screening_document)

    return {
        "screeningId": str(result.inserted_id),
        "childId": child_id,
        "prediction": prediction,
        "confidence": confidence,
        "probabilities": probabilities,
        "createdAt": screening_document["createdAt"]
    }