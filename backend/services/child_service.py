from db.mongodb import children_collection


async def search_children(search_query: str):

    search_query = search_query.strip()

    if not search_query:
        return []

    children = await children_collection.find(
        {
            "$or": [
                {
                    "childId": {
                        "$regex": search_query,
                        "$options": "i"
                    }
                },
                {
                    "childName": {
                        "$regex": search_query,
                        "$options": "i"
                    }
                }
            ]
        },
        {
            "_id": 0,
            "childId": 1,
            "childName": 1,
            "dob": 1
        }
    ).to_list(length=20)

    return children


async def get_child_by_id(child_id: str):

    child = await children_collection.find_one(
        {"childId": child_id},
        {
            "_id": 0,
            "childId": 1,
            "childName": 1,
            "dob": 1
        }
    )

    return child


async def get_child_profile(child_id: str):

    child = await children_collection.find_one(
        {"childId": child_id},
        {
            "_id": 0,
            "childId": 1,
            "childName": 1,
            "dob": 1
        }
    )

    return child