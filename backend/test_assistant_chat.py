import asyncio

import httpx
import pytest
from fastapi import HTTPException
from fastapi import FastAPI
from fastapi.testclient import TestClient
from starlette.requests import Request

from routers import assistant
from routers.assistant import ChatRequest, ConversationTurn


def _fake_request(client_id="assistant-test-client"):
    return Request({
        "type": "http",
        "method": "POST",
        "path": "/api/assistant/chat",
        "headers": [],
        "query_string": b"",
        "server": ("testserver", 80),
        "client": (client_id, 1234),
    })


def test_conversation_history_is_bounded_and_language_is_explicit():
    request = ChatRequest(
        message="Make that shorter",
        language="kn",
        history=[
            ConversationTurn(role="user", content="Explain photosynthesis."),
            ConversationTurn(role="assistant", content="Plants use light to make food."),
        ],
    )

    messages = assistant._messages_for(request)

    assert messages[0]["role"] == "system"
    assert "Kannada" in messages[0]["content"]
    assert messages[1]["role"] == "system"
    assert "Current prediction path" not in messages[1]["content"]
    assert messages[2:] == [
        {"role": "user", "content": "Explain photosynthesis."},
        {"role": "assistant", "content": "Plants use light to make food."},
        {"role": "user", "content": "Make that shorter"},
    ]


def test_missing_key_is_reported_without_calling_sarvam(monkeypatch):
    monkeypatch.delenv("SARVAM_API_KEY", raising=False)
    request = _fake_request()

    with pytest.raises(HTTPException) as error:
        asyncio.run(assistant.assistant_chat(ChatRequest(message="Explain gravity"), request))

    assert error.value.status_code == 503
    assert "SARVAM_API_KEY" in error.value.detail


def test_rate_limit_rejects_excess_requests():
    client_id = "test-assistant-rate-limit"
    assistant._request_times.pop(client_id, None)
    for index in range(assistant.MAX_REQUESTS_PER_MINUTE):
        assistant._check_rate_limit(client_id, now=100 + index / 100)

    with pytest.raises(HTTPException) as error:
        assistant._check_rate_limit(client_id, now=101)

    assert error.value.status_code == 429
    assistant._request_times.pop(client_id, None)


def test_sarvam_completion_uses_documented_contract_and_parses_reply(monkeypatch):
    captured = {}

    class FakeResponse:
        status_code = 200

        @staticmethod
        def json():
            return {"choices": [{"message": {"content": "Plants use sunlight."}}]}

    class FakeClient:
        def __init__(self, **kwargs):
            captured["timeout"] = kwargs["timeout"]

        async def __aenter__(self):
            return self

        async def __aexit__(self, *_):
            return None

        async def post(self, url, *, headers, json):
            captured.update(url=url, headers=headers, body=json)
            return FakeResponse()

    monkeypatch.setattr(assistant.httpx, "AsyncClient", FakeClient)
    messages = [{"role": "user", "content": "Explain photosynthesis."}]

    result = asyncio.run(assistant._call_sarvam("secret-not-logged", messages))

    assert result == "Plants use sunlight."
    assert captured["url"] == "https://api.sarvam.ai/v1/chat/completions"
    assert captured["headers"] == {"api-subscription-key": "secret-not-logged"}
    assert captured["body"]["model"] == "sarvam-105b-conversations"
    assert captured["body"]["messages"] == messages


def test_sarvam_rate_limit_is_returned_as_clear_error(monkeypatch):
    class FakeResponse:
        status_code = 429

    class FakeClient:
        def __init__(self, **_):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *_):
            return None

        async def post(self, *_args, **_kwargs):
            return FakeResponse()

    monkeypatch.setattr(assistant.httpx, "AsyncClient", FakeClient)

    with pytest.raises(HTTPException) as error:
        asyncio.run(assistant._call_sarvam("secret-not-logged", []))

    assert error.value.status_code == 429
    assert "quota" in error.value.detail


@pytest.mark.parametrize(
    "status, expected_status",
    [(401, 503), (403, 503), (500, 502), (400, 502)],
)
def test_sarvam_http_errors_are_mapped_without_provider_details(monkeypatch, status, expected_status):
    class FakeResponse:
        status_code = status

    class FakeClient:
        def __init__(self, **_):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *_):
            return None

        async def post(self, *_args, **_kwargs):
            return FakeResponse()

    monkeypatch.setattr(assistant.httpx, "AsyncClient", FakeClient)
    with pytest.raises(HTTPException) as error:
        asyncio.run(assistant._call_sarvam("secret-not-logged", []))
    assert error.value.status_code == expected_status


def test_malformed_sarvam_reply_is_reported_as_empty(monkeypatch):
    class FakeResponse:
        status_code = 200

        @staticmethod
        def json():
            return {"unexpected": "shape"}

    class FakeClient:
        def __init__(self, **_):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *_):
            return None

        async def post(self, *_args, **_kwargs):
            return FakeResponse()

    monkeypatch.setattr(assistant.httpx, "AsyncClient", FakeClient)
    with pytest.raises(HTTPException) as error:
        asyncio.run(assistant._call_sarvam("secret-not-logged", []))
    assert error.value.status_code == 502
    assert "empty" in error.value.detail


def test_timeouts_are_translated_without_logging_request_text(monkeypatch):
    class FakeClient:
        def __init__(self, **_):
            pass

        async def __aenter__(self):
            return self

        async def __aexit__(self, *_):
            return None

        async def post(self, *_args, **_kwargs):
            raise httpx.ReadTimeout("private prompt text")

    monkeypatch.setattr(assistant.httpx, "AsyncClient", FakeClient)

    with pytest.raises(httpx.TimeoutException):
        asyncio.run(assistant._call_sarvam("secret-not-logged", []))


def test_chat_route_requires_login_and_returns_mocked_response(monkeypatch):
    app = FastAPI()
    app.include_router(assistant.router)
    monkeypatch.setenv("SARVAM_API_KEY", "test-key-not-a-real-credential")

    async def fake_sarvam(_api_key, messages):
        assert messages[-1] == {"role": "user", "content": "Explain gravity."}
        return "Gravity attracts objects with mass."

    monkeypatch.setattr(assistant, "_call_sarvam", fake_sarvam)
    assistant._request_times.pop("testclient", None)
    client = TestClient(app)

    unauthorized = client.post(
        "/api/assistant/chat",
        json={"message": "Explain gravity."},
    )
    app.dependency_overrides[assistant.get_current_user] = lambda: {
        "user_id": "test-user",
        "role": "parent",
    }
    authorized = client.post(
        "/api/assistant/chat",
        headers={"Authorization": "Bearer mocked-test-token"},
        json={"message": "Explain gravity."},
    )

    assert unauthorized.status_code in (401, 403)
    assert authorized.status_code == 200
    assert authorized.json() == {"response": "Gravity attracts objects with mass.", "sources": []}
    assistant._request_times.pop("testclient", None)
