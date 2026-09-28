import asyncio
import json
import os
import websockets
from dotenv import load_dotenv

load_dotenv()
API_KEY = os.getenv("GEMINI_API_KEY", "").strip()

models_to_test = [
    "gemini-2.0-flash-exp",
    "gemini-2.5-flash",
    "gemini-2.0-flash-thinking-exp",
    "gemini-flash-latest",
]

URI = f"wss://generativelanguage.googleapis.com/ws/google.ai.generativelanguage.v1alpha.GenerativeService.BidiGenerateContent?key={API_KEY}"

async def test_model(model_name):
    print(f"\n--- Testing model: {model_name} ---")
    try:
        async with websockets.connect(URI) as ws:
            print("Connected to WebSocket successfully!")
            setup_msg = {
                "setup": {
                    "model": f"models/{model_name}",
                    "generationConfig": {
                        "responseModalities": ["AUDIO", "TEXT"],
                        "speechConfig": {
                            "voiceConfig": {
                                "prebuiltVoiceConfig": {
                                    "voiceName": "Puck"
                                }
                            }
                        }
                    }
                }
            }
            print(f"Sending setup message for {model_name}...")
            await ws.send(json.dumps(setup_msg))
            print("Setup message sent. Waiting for response...")
            try:
                msg = await asyncio.wait_for(ws.recv(), timeout=5.0)
                print(f"Received from server: {msg[:300]}")
            except asyncio.TimeoutError:
                print("Timeout waiting for response (socket might be open)")
    except websockets.exceptions.ConnectionClosed as e:
        print(f"ConnectionClosed! Code: {e.code}, Reason: {e.reason}")
    except Exception as e:
        print(f"Exception: {type(e).__name__}: {e}")

async def main():
    for m in models_to_test:
        await test_model(m)

if __name__ == "__main__":
    asyncio.run(main())
