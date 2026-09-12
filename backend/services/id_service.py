from pymongo import ReturnDocument

from db.mongodb import counters_collection


async def generate_child_id() -> str:

    result = await counters_collection.find_one_and_update(
        {"_id": "childId"},
        {"$inc": {"sequence": 1}},
        upsert=True,
        return_document=ReturnDocument.AFTER
    )

    sequence = result["sequence"]

    return f"CHD{sequence:03d}"

async def generate_worker_id() -> str:
    result = await counters_collection.find_one_and_update(
        {"_id": "workerId"},
        {"$inc": {"sequence": 1}},
        upsert=True,
        return_document=ReturnDocument.AFTER
    )

    sequence = result["sequence"]

    return f"HW{sequence:03d}"