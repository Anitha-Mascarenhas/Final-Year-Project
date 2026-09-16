import asyncio

from db.mongodb import hospitals_collection


HOSPITALS = [
    {
        "hospitalId": "HOSP001",
        "hospitalName": "Mangaluru Community Hospital",
        "city": "Mangaluru",
        "state": "Karnataka",
        "isActive": True
    },
    {
        "hospitalId": "HOSP002",
        "hospitalName": "Coastal Care Hospital",
        "city": "Mangaluru",
        "state": "Karnataka",
        "isActive": True
    },
    {
        "hospitalId": "HOSP003",
        "hospitalName": "St. Mary's Community Hospital",
        "city": "Mangaluru",
        "state": "Karnataka",
        "isActive": True
    },
    {
        "hospitalId": "HOSP004",
        "hospitalName": "Kaveri General Hospital",
        "city": "Mysuru",
        "state": "Karnataka",
        "isActive": True
    },
    {
        "hospitalId": "HOSP005",
        "hospitalName": "Mysuru Care Hospital",
        "city": "Mysuru",
        "state": "Karnataka",
        "isActive": True
    },
    {
        "hospitalId": "HOSP006",
        "hospitalName": "Bengaluru Community Hospital",
        "city": "Bengaluru",
        "state": "Karnataka",
        "isActive": True
    },
    {
        "hospitalId": "HOSP007",
        "hospitalName": "Bengaluru General Hospital",
        "city": "Bengaluru",
        "state": "Karnataka",
        "isActive": True
    },
    {
        "hospitalId": "HOSP008",
        "hospitalName": "Udupi Community Hospital",
        "city": "Udupi",
        "state": "Karnataka",
        "isActive": True
    },
    {
        "hospitalId": "HOSP009",
        "hospitalName": "Coastal District Hospital",
        "city": "Udupi",
        "state": "Karnataka",
        "isActive": True
    },
    {
        "hospitalId": "HOSP010",
        "hospitalName": "Kundapura General Hospital",
        "city": "Kundapura",
        "state": "Karnataka",
        "isActive": True
    },
    {
        "hospitalId": "HOSP011",
        "hospitalName": "Hubballi Community Hospital",
        "city": "Hubballi",
        "state": "Karnataka",
        "isActive": True
    },
    {
        "hospitalId": "HOSP012",
        "hospitalName": "Dharwad General Hospital",
        "city": "Dharwad",
        "state": "Karnataka",
        "isActive": True
    },
    {
        "hospitalId": "HOSP013",
        "hospitalName": "Belagavi Community Hospital",
        "city": "Belagavi",
        "state": "Karnataka",
        "isActive": True
    },
    {
        "hospitalId": "HOSP014",
        "hospitalName": "Shivamogga General Hospital",
        "city": "Shivamogga",
        "state": "Karnataka",
        "isActive": True
    },
    {
        "hospitalId": "HOSP015",
        "hospitalName": "Tumakuru Community Hospital",
        "city": "Tumakuru",
        "state": "Karnataka",
        "isActive": True
    },
    {
        "hospitalId": "HOSP016",
        "hospitalName": "Mysuru District Hospital",
        "city": "Mysuru",
        "state": "Karnataka",
        "isActive": True
    },
    {
        "hospitalId": "HOSP017",
        "hospitalName": "Mangaluru District Hospital",
        "city": "Mangaluru",
        "state": "Karnataka",
        "isActive": True
    },
    {
        "hospitalId": "HOSP018",
        "hospitalName": "Coastal District Medical Centre",
        "city": "Mangaluru",
        "state": "Karnataka",
        "isActive": True
    },
    {
        "hospitalId": "HOSP019",
        "hospitalName": "Udupi General Hospital",
        "city": "Udupi",
        "state": "Karnataka",
        "isActive": True
    },
    {
        "hospitalId": "HOSP020",
        "hospitalName": "Karnataka Community Medical Centre",
        "city": "Bengaluru",
        "state": "Karnataka",
        "isActive": True
    }
]


async def seed_hospitals():
    for hospital in HOSPITALS:
        await hospitals_collection.update_one(
            {"hospitalId": hospital["hospitalId"]},
            {"$set": hospital},
            upsert=True
        )

    print("Hospital seed completed successfully.")


if __name__ == "__main__":
    asyncio.run(seed_hospitals())