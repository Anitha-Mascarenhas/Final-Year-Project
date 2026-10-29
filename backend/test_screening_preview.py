import asyncio
from io import BytesIO

import pytest
from fastapi import HTTPException, UploadFile

from routers import screening


def test_preview_requires_parent_ownership(monkeypatch, tmp_path):
    async def child(_child_id):
        return {"childId": "child-a", "age": 2}

    monkeypatch.setattr(screening, "get_child_by_id", child)
    monkeypatch.setattr(screening, "UPLOAD_DIR", tmp_path)

    with pytest.raises(HTTPException) as error:
        asyncio.run(screening.preview_for_child(
            "child-a",
            UploadFile(filename="child.jpg", file=BytesIO(b"image")),
            current_user={"user_id": "child-b", "role": "parent"},
        ))

    assert error.value.status_code == 403
    assert list(tmp_path.iterdir()) == []


def test_preview_uses_random_temp_file_and_deletes_it(monkeypatch, tmp_path):
    async def child(_child_id):
        return {"childId": "child-a", "age": 2, "gender": "female"}

    def predict(image, anthropometrics):
        assert image == b"image-bytes"
        assert anthropometrics["height_cm"] == 90.0
        assert anthropometrics["gender_male"] == 0.0
        assert len(list(tmp_path.iterdir())) == 1
        assert all(path.name != "private-child-name.jpg" for path in tmp_path.iterdir())
        return {"prediction": "healthy"}

    monkeypatch.setattr(screening, "get_child_by_id", child)
    monkeypatch.setattr(screening, "run_hybrid_prediction", predict)
    monkeypatch.setattr(screening, "UPLOAD_DIR", tmp_path)
    result = asyncio.run(screening.preview_for_child(
        "child-a",
        UploadFile(filename="private-child-name.jpg", file=BytesIO(b"image-bytes")),
        current_user={"user_id": "child-a", "role": "parent"},
        age_years=None,
        age_months=None,
        gender=None,
        height_cm=90.0,
    ))

    assert result == {"prediction": "healthy"}
    assert list(tmp_path.iterdir()) == []
