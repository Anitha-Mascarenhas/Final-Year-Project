import asyncio

from db.mongodb import test_database_connection


async def main():
    await test_database_connection()


asyncio.run(main())