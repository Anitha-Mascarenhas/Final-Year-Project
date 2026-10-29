from datetime import datetime, timezone, timedelta
import os

os.environ.setdefault("MONGODB_URI", "mongodb://127.0.0.1:27017")

from services.nutrition_service import analyze_screening_history, build_nutrition_recommendation
from routers import nutrition as nutrition_router
from routers.nutrition import NutritionRequest, RegionInput
import asyncio
import pytest
from fastapi import HTTPException


def _record(day, prediction, weight, height=90, age=3, age_months=2, bmi=14):
    stamp = datetime(2026, 1, 1, tzinfo=timezone.utc) + timedelta(days=day)
    return {
        "createdAt": stamp,
        "screening_result": {"prediction": prediction, "risk": "Low Risk" if prediction == "healthy" else "High Risk"},
        "vitals": {"weight_kg": weight, "height_cm": height, "bmi": bmi,
                   "age_years": age, "age_months": age_months, "gender": "Girl", "muac_cm": None},
    }


def test_repeated_underweight_history_and_trends_change_plan():
    records = [_record(0, "underweight", 10), _record(30, "underweight", 10.8)]
    result = build_nutrition_recommendation("CHD006", records, {"country": "India", "state": "Karnataka"})
    summary = result["history_summary"]
    assert summary["screening_count"] == 2
    assert summary["weight_trend"] == "increasing"
    assert summary["repeated_underweight"] is True
    assert "underweight" in result["nutrition_plan"]["summary"].lower()
    assert any("ragi" in food["food"] for food in result["nutrition_plan"]["recommended_foods"])


def test_underweight_to_healthy_acknowledges_history():
    result = build_nutrition_recommendation("CHD006", [_record(0, "underweight", 10), _record(30, "healthy", 11)])
    assert result["history_summary"]["prediction_trend"] == "improved_to_healthy"
    assert "earlier" in result["nutrition_plan"]["summary"].lower()


def test_combined_risk_and_null_optional_vitals_are_safe():
    result = build_nutrition_recommendation("CHD006", [_record(0, "stunted and underweight", 10, bmi=None)])
    plan = result["nutrition_plan"]
    assert "professional" in plan["professional_follow_up"].lower()
    assert result["history_summary"]["muac_trend"] == "insufficient_data"


def test_regional_foods_respect_allergy_and_vegetarian_preference():
    result = build_nutrition_recommendation(
        "CHD006", [_record(0, "underweight", 10)],
        {"country": "India", "state": "Karnataka"},
        allergies=["peanut"], dietary_preferences=["vegetarian"],
    )
    foods = " ".join(item["food"].lower() for item in result["nutrition_plan"]["recommended_foods"])
    assert "groundnut" not in foods and "egg" not in foods and "nut or seed paste" not in foods


def test_missing_history_or_age_does_not_invent_child_data():
    empty = build_nutrition_recommendation("CHD006", [])
    assert empty["history_summary"]["screening_count"] == 0
    assert "no screening history" in empty["nutrition_plan"]["summary"].lower()
    missing_age = build_nutrition_recommendation("CHD006", [_record(0, "healthy", 10, age=None, age_months=None)])
    assert missing_age["nutrition_plan"]["age_limited"] is True
    assert "age is missing" in missing_age["personalized_using"][3]


def test_two_children_receive_history_specific_summaries():
    low = analyze_screening_history([_record(0, "underweight", 8)])
    healthy = analyze_screening_history([_record(0, "healthy", 12)])
    assert low["latest_prediction"] != healthy["latest_prediction"]


def test_latest_report_changes_nutrition_strategy_and_meal_options():
    reports = [
        [_record(0, "healthy", 12)],
        [_record(0, "underweight", 9)],
        [_record(0, "stunted and underweight", 9)],
    ]
    plans = [build_nutrition_recommendation(
        "CHD006", records, {"country": "India", "state": "Karnataka"}
    )["nutrition_plan"] for records in reports]
    assert [plan["support_strategy"] for plan in plans] == [
        "balanced_support", "underweight_support", "combined_support"
    ]
    options = [plan["meal_plan"][0]["food_options"][0] for plan in plans]
    assert len(set(options)) == 3
    assert all("Karnataka" not in option for option in options)


def test_recommendation_endpoint_uses_authenticated_child_history(monkeypatch):
    records = [_record(0, "underweight", 10), _record(30, "healthy", 11)]
    async def child(child_id):
        return {"childId": child_id}
    async def history(child_id):
        assert child_id == "CHD006"
        return records
    monkeypatch.setattr(nutrition_router, "get_child_by_id", child)
    monkeypatch.setattr(nutrition_router, "fetch_screening_history", history)
    response = asyncio.run(nutrition_router.personalized_nutrition(
        "CHD006", NutritionRequest(region=RegionInput(country="India", state="Karnataka")),
        {"role": "parent", "user_id": "CHD006"}))
    assert response["history_summary"]["screening_count"] == 2
    assert response["history_summary"]["latest_prediction"] == "healthy"
    assert response["region"]["state"] == "Karnataka"


def test_recommendation_endpoint_rejects_other_parent_child(monkeypatch):
    async def child(child_id):
        return {"childId": child_id}
    async def should_not_fetch(child_id):
        raise AssertionError("unauthorized request fetched history")
    monkeypatch.setattr(nutrition_router, "get_child_by_id", child)
    monkeypatch.setattr(nutrition_router, "fetch_screening_history", should_not_fetch)
    with pytest.raises(HTTPException) as error:
        asyncio.run(nutrition_router.personalized_nutrition(
            "CHD007", NutritionRequest(), {"role": "parent", "user_id": "CHD006"}))
    assert error.value.status_code == 403
