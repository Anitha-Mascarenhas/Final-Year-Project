from db.mongodb import hospitals_collection


async def get_hospital_by_id(hospital_id: str):
    hospital_id = hospital_id.strip().upper()

    hospital = await hospitals_collection.find_one(
        {
            "hospitalId": hospital_id,
            "isActive": True
        },
        {
            "_id": 0,
            "hospitalId": 1,
            "hospitalName": 1,
            "city": 1,
            "state": 1,
            "isActive": 1
        }
    )

    return hospital