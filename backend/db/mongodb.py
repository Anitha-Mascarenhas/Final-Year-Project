import os

from dotenv import load_dotenv
from pymongo import AsyncMongoClient
from pymongo.server_api import ServerApi

load_dotenv()

MONGODB_URI = os.getenv("MONGODB_URI")
MONGODB_DB_NAME = os.getenv("MONGODB_DB_NAME", "poshaneye")

if not MONGODB_URI:
    raise RuntimeError("MONGODB_URI is not configured")

client = AsyncMongoClient(
    MONGODB_URI,
    server_api=ServerApi(
        version="1",
        strict=True,
        deprecation_errors=True
    )
)

db = client[MONGODB_DB_NAME]

children_collection = db["children"]
parents_collection = db["parents"]
health_workers_collection = db["health_workers"]
counters_collection = db["counters"]
screenings_collection = db["screenings"]

# Test the database connection
async def test_database_connection():
    await client.admin.command("ping")
    print("MongoDB Atlas connection successful!")