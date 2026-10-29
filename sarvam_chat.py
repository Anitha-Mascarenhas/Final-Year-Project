import os
from pathlib import Path

from sarvamai import SarvamAI


for line in Path(__file__).with_name(".env").read_text(encoding="utf-8").splitlines():
    key, separator, value = line.partition("=")
    if separator and key.strip() == "SARVAM_API_KEY":
        os.environ["SARVAM_API_KEY"] = value.strip().strip("\"'")
        break

api_key = os.environ.get("SARVAM_API_KEY", "").strip()
if not api_key:
    raise SystemExit("Add your SARVAM_API_KEY to the project .env file, then run this script again.")

try:
    client = SarvamAI(api_subscription_key=api_key)
    response = client.chat.completions(
        model="sarvam-105b-conversations",
        messages=[{"role": "user", "content": "Say hello in one short sentence."}],
        max_tokens=80,
        reasoning_effort=None,
    )
    print(response.choices[0].message.content)
except Exception as error:
    raise SystemExit(f"Sarvam request failed ({type(error).__name__}).") from None
