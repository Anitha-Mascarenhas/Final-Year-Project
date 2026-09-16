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


async def get_screening_history(child_id: str):
    screenings = await screenings_collection.find(
        {"childId": child_id},
        {
            "_id": 1,
            "childId": 1,
            "prediction": 1,
            "confidence": 1,
            "probabilities": 1,
            "createdAt": 1
        }
    ).sort("createdAt", -1).to_list(length=100)

    history = []

    for screening in screenings:
        history.append({
            "screeningId": str(screening["_id"]),
            "childId": screening["childId"],
            "prediction": screening["prediction"],
            "confidence": screening["confidence"],
            "probabilities": screening["probabilities"],
            "createdAt": screening["createdAt"]
        })

    return history