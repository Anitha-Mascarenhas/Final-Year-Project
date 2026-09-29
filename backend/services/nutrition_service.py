from __future__ import annotations

from datetime import datetime, timezone
from typing import Any

from db.mongodb import screenings_collection


_STATE_FOODS = {
    "karnataka": ["ragi", "rice", "dal", "sambar", "curd", "eggs", "banana", "seasonal vegetables", "groundnuts"],
    "tamil nadu": ["ragi", "rice", "sambar", "dal", "curd", "eggs", "banana", "seasonal vegetables", "groundnuts"],
    "kerala": ["rice", "green gram", "curd", "eggs", "banana", "seasonal vegetables", "coconut in modest amounts"],
    "andhra pradesh": ["rice", "toor dal", "curd", "eggs", "banana", "seasonal vegetables", "groundnuts"],
    "telangana": ["rice", "millets", "dal", "curd", "eggs", "banana", "seasonal vegetables", "groundnuts"],
    "maharashtra": ["jowar", "rice", "dal", "curd", "eggs", "banana", "seasonal vegetables", "groundnuts"],
    "gujarat": ["bajra", "wheat", "dal", "curd", "eggs", "banana", "seasonal vegetables", "groundnuts"],
    "rajasthan": ["bajra", "wheat", "moong dal", "curd", "eggs", "seasonal vegetables", "groundnuts"],
    "punjab": ["wheat", "rice", "dal", "curd", "eggs", "seasonal vegetables", "seasonal fruit"],
    "west bengal": ["rice", "lentils", "fish where suitable", "eggs", "curd", "banana", "seasonal vegetables"],
    "odisha": ["rice", "ragi", "dal", "eggs", "curd", "banana", "seasonal vegetables"],
    "uttar pradesh": ["wheat", "rice", "dal", "curd", "eggs", "banana", "seasonal vegetables", "groundnuts"],
    "generic": ["locally available grains or millets", "beans or lentils", "eggs or another suitable protein", "milk or curd if tolerated", "seasonal fruit", "seasonal vegetables", "nut or seed paste where age-safe"],
}


def _result(row: dict[str, Any]) -> dict[str, Any]:
    nested = row.get("screening_result")
    return {**row, **nested} if isinstance(nested, dict) else row


def _trend(rows: list[dict[str, Any]], field: str, tolerance: float = 0.05) -> str:
    points = []
    for row in rows:
        value = (row.get("vitals") or {}).get(field)
        if isinstance(value, (int, float)):
            points.append(float(value))
    if len(points) < 2:
        return "insufficient_data"
    delta = points[-1] - points[0]
    if abs(delta) <= tolerance:
        return "stable"
    return "increasing" if delta > 0 else "decreasing"


def analyze_screening_history(records: list[dict[str, Any]]) -> dict[str, Any]:
    def date_key(row: dict[str, Any]) -> datetime:
        value = row.get("screened_at") or row.get("createdAt")
        if isinstance(value, str):
            try:
                value = datetime.fromisoformat(value.replace("Z", "+00:00"))
            except ValueError:
                value = None
        if not isinstance(value, datetime):
            return datetime.min.replace(tzinfo=timezone.utc)
        return value.replace(tzinfo=timezone.utc) if value.tzinfo is None else value

    ordered = sorted(records, key=date_key)
    result_rows = [row for row in ordered if _result(row).get("prediction")]
    predictions = [_normalize_prediction(_result(row)["prediction"]) for row in result_rows]
    latest = _result(result_rows[-1]) if result_rows else {}
    vitals_rows = [row for row in ordered if any(value is not None for value in (row.get("vitals") or {}).values())]
    latest_vitals = (vitals_rows[-1].get("vitals") or {}) if vitals_rows else {}
    normalized = predictions
    recent = normalized[-3:]
    bmi = _trend(ordered, "bmi")
    dates = [date_key(row) for row in ordered]
    gaps = []
    for before, after in zip(dates, dates[1:]):
        if isinstance(before, datetime) and isinstance(after, datetime):
            gaps.append((after - before).days)
    summary = {
        "screening_count": len(ordered),
        "latest_prediction": normalized[-1] if normalized else None,
        "previous_predictions": list(reversed(normalized[:-1])),
        "prediction_trend": "no_history" if len(normalized) < 2 else ("improved_to_healthy" if normalized[-1] == "healthy" and any(p != "healthy" for p in normalized[:-1]) else "changed" if normalized[-1] != normalized[-2] else "unchanged"),
        "weight_trend": _trend(ordered, "weight_kg"),
        "height_trend": _trend(ordered, "height_cm"),
        "bmi_trend": bmi,
        "muac_trend": _trend(ordered, "muac_cm"),
        "historical_underweight": any("underweight" in p for p in normalized[:-1]),
        "historical_stunting": any("stunted" in p for p in normalized[:-1]),
        "repeated_underweight": sum("underweight" in p for p in recent) >= 2,
        "repeated_stunting": sum("stunted" in p for p in recent) >= 2,
        "latest_risk": latest.get("risk"),
        "latest_status": latest.get("status"),
        "latest_recommendation": latest.get("recommendation"),
        "latest_confidence": latest.get("confidence"),
        "latest_probabilities": latest.get("probabilities") or {},
        "latest_report": {
            key: latest.get(key) for key in
            ("prediction", "status", "risk", "recommendation", "confidence", "probabilities")
            if latest.get(key) is not None
        },
        "screening_dates": dates,
        "days_between_screenings": gaps,
        "latest_age_years": latest_vitals.get("age_years"),
        "latest_age_months": latest_vitals.get("age_months"),
        "latest_gender": latest_vitals.get("gender"),
        "latest_vitals": latest_vitals,
    }
    return summary


def _foods_for_region(region: dict[str, str]) -> list[str]:
    state = (region.get("state") or "").strip().lower()
    for known, foods in _STATE_FOODS.items():
        if known != "generic" and known in state:
            return foods
    return _STATE_FOODS["generic"]


def build_nutrition_recommendation(
    child_id: str,
    records: list[dict[str, Any]],
    region: dict[str, str] | None = None,
    allergies: list[str] | None = None,
    dietary_preferences: list[str] | None = None,
) -> dict[str, Any]:
    summary = analyze_screening_history(records)
    region = {k: str(v).strip() for k, v in (region or {}).items() if v and str(v).strip()}
    allergies = [item.strip().lower() for item in (allergies or [])]
    preferences = [item.strip().lower() for item in (dietary_preferences or [])]
    prediction = summary["latest_prediction"]
    age_years, age_months = summary["latest_age_years"], summary["latest_age_months"]
    age_missing = age_years is None and age_months is None
    age_incomplete = age_years == 0 and age_months is None
    age_limited = age_missing or age_incomplete

    if not records:
        summary_text = "No screening history is available yet. Complete a screening to get child-specific nutrition guidance."
        focus = ["Record the child's age and current measurements during a screening."]
        follow_up = "Use routine child health visits for growth monitoring."
    elif age_limited:
        summary_text = "Screening history is available, but age is missing from the latest saved vitals. Add the child's age in a screening to tailor food texture and meal suggestions safely."
        focus = ["Age-specific meal guidance is limited until the child's age is recorded."]
        follow_up = "Confirm the child's age with a caregiver or health worker before applying age-specific feeding guidance."
    else:
        summary_text, focus, follow_up = _focus_for_history(prediction, summary)

    # First choose the support strategy from the latest saved screening. Region
    # only supplies practical foods for that strategy.
    strategy = _strategy_for_report(prediction)
    food_names = _foods_for_region(region)
    if any("vegetarian" in pref for pref in preferences):
        food_names = [food for food in food_names if not any(word in food.lower() for word in ("eggs", "fish", "chicken", "meat"))]
    aliases = {
        "peanut": ("groundnut", "nut or seed paste"),
        "groundnut": ("peanut", "nut or seed paste"),
        "nut": ("groundnut", "nut or seed paste"),
        "nuts": ("groundnut", "nut or seed paste"),
        "tree nut": ("groundnut", "nut or seed paste"),
        "almond": ("nut or seed paste",),
        "cashew": ("nut or seed paste",),
        "milk": ("curd", "dairy"),
        "dairy": ("curd", "milk"),
        "egg": ("eggs",),
        "fish": ("fish",),
        "wheat": ("wheat",),
        "gluten": ("wheat",),
    }
    blocked = set(allergies)
    for allergy in allergies:
        blocked.update(aliases.get(allergy, ()))
    food_names = [food for food in food_names if not any(allergy in food.lower() for allergy in blocked)]
    if not food_names:
        food_names = ["Foods selected with the caregiver that avoid listed allergies and restrictions"]

    reasons = _food_reasons(prediction, summary)
    recommended_foods = [{
        "food": food,
        "reason": reasons,
        "meal_examples": [f"Offer {food} as part of a varied, age-appropriate meal.", "Pair a grain or staple with a pulse, protein, fruit, or vegetable as available."],
    } for food in food_names]
    age_month_total = (age_years or 0) * 12 + (age_months or 0)
    staple = food_names[0]
    protein = next((food for food in food_names if any(token in food.lower() for token in ("dal", "lentil", "gram", "bean", "egg", "fish", "protein"))), food_names[min(1, len(food_names) - 1)])
    produce = next((food for food in food_names if any(token in food.lower() for token in ("fruit", "banana", "vegetable"))), food_names[-1])
    dairy = next((food for food in food_names if any(token in food.lower() for token in ("curd", "milk"))), None)
    if age_limited:
        texture_note = "Confirm the child's age before using age-specific textures or portions."
    elif age_month_total < 6:
        texture_note = "Follow the child's clinician's feeding advice; this plan does not suggest solid foods under 6 months."
    elif age_month_total < 24:
        texture_note = "Serve soft, safe-texture foods in small age-appropriate portions; avoid choking hazards."
    else:
        texture_note = "Serve familiar family foods in child-safe textures and portions."
    meal_plan = [
        {"meal": "Breakfast", "time": "8:00 AM", "suggestions": [
            f"Soft {staple} porridge or another familiar breakfast preparation.",
            f"Add {produce} when available; {('serve with ' + dairy + ' if tolerated.') if dairy else 'offer water alongside the meal.'}",
        ]},
        {"meal": "Lunch", "time": "12:30 PM", "suggestions": [
            f"Serve {staple} with {protein} and cooked seasonal vegetables.",
            "Use a safe, age-appropriate texture and include a little oil or ghee if normally used by the family.",
        ]},
        {"meal": "Afternoon snack", "time": "3:30 PM", "suggestions": [
            f"Offer {produce} as a child-safe snack.",
            f"Pair with {dairy} if tolerated and available." if dairy else f"A small portion of {protein} can add variety.",
        ]},
        {"meal": "Dinner", "time": "7:00 PM", "suggestions": [
            f"Prepare a soft family meal using {staple} and {protein}.",
            f"Include cooked {produce} when suitable and available.",
        ]},
    ]
    if age_limited:
        meal_options = [["Confirm age-appropriate foods and textures with the caregiver or health worker."] for _ in meal_plan]
    elif age_month_total < 6:
        meal_options = [["Follow the child's clinician's feeding guidance; solid foods are not suggested under 6 months."] for _ in meal_plan]
    elif strategy == "underweight_support":
        meal_options = [
            [f"Energy-containing {staple} porridge with {produce}", f"{staple} with {dairy}" if dairy else f"Soft {staple} with {protein}"],
            [f"{staple} with {protein}, cooked vegetables, and a little family-used oil", f"Soft {protein} khichdi with {staple}"],
            [f"{produce} with {dairy}" if dairy else f"{produce} with {protein}", f"Small age-safe {staple} snack with {protein}"],
            [f"{staple} and {protein} family meal with cooked {produce}", f"Soft {protein} and {staple} meal"],
        ]
    elif strategy == "stunting_support":
        meal_options = [
            [f"{staple} with {protein} and {produce}", f"Soft {staple} porridge with {dairy}" if dairy else f"Soft {staple} with {protein}"],
            [f"{staple} with {protein} and cooked seasonal vegetables", f"{protein} and {staple} with a vitamin-rich vegetable"],
            [f"{produce} with {protein}", f"{produce} with {dairy}" if dairy else f"A small serving of {protein}"],
            [f"Varied family meal with {staple}, {protein}, and cooked {produce}", f"Soft {protein} meal with a different seasonal vegetable"],
        ]
    elif strategy == "combined_support":
        meal_options = [
            [f"Energy-containing {staple} porridge with {protein} and {produce}", f"{staple} with {dairy}" if dairy else f"Soft {staple} with {protein}"],
            [f"{staple} with {protein}, cooked vegetables, and a little family-used oil", f"Soft {protein} khichdi with {staple} and vegetables"],
            [f"{produce} with {dairy}" if dairy else f"{produce} with {protein}", f"Small age-safe {staple} snack with {protein}"],
            [f"Varied {staple} and {protein} meal with cooked {produce}", f"Soft family meal with {protein} and seasonal vegetables"],
        ]
    else:
        breakfast_options = [f"Soft {staple} porridge with {produce}", f"{staple} with {dairy}" if dairy else f"Soft {staple} with {protein}"]
        lunch_options = [f"{staple} with {protein} and cooked {produce}", f"Soft {protein} khichdi with {staple}"]
        snack_options = [f"{produce} with {dairy}" if dairy else f"Soft {produce}", f"A small age-safe serving of {staple}"]
        dinner_options = [f"{staple} with {protein} and cooked {produce}", f"Soft {staple} and {protein} family meal"]
        meal_options = [breakfast_options, lunch_options, snack_options, dinner_options]
    if meal_options is not None:
        for meal, options in zip(meal_plan, meal_options):
            meal["food_options"] = options
    for meal in meal_plan:
        meal["suggestions"].append(texture_note)
    if not age_limited and (prediction in ("underweight", "stunted and underweight") or summary["repeated_underweight"]):
        meal_plan[0]["suggestions"].insert(0, "Keep regular meals and snacks with an energy-containing staple and a suitable protein source.")
    if not age_limited and summary["weight_trend"] == "decreasing":
        meal_plan[-1]["suggestions"].append("Use these ideas as support while arranging professional growth assessment because recorded weight is decreasing.")
    if allergies:
        for meal in meal_plan:
            meal["suggestions"].append("Avoid listed allergens and check ingredients and preparation surfaces.")
    monitoring = [f"Compare the next recorded weight trend with the current history ({summary['weight_trend']}).", "Continue routine growth checks and record measurements at follow-up."]
    if summary["weight_trend"] == "decreasing":
        monitoring.insert(0, "Recent recorded weight is decreasing; arrange a professional growth assessment.")
    if summary["repeated_underweight"]:
        monitoring.append("Underweight has appeared repeatedly in recent screenings; review progress with a health worker.")
    if summary["repeated_stunting"]:
        monitoring.append("Stunting has appeared repeatedly; continue growth monitoring and professional follow-up.")

    plan = {
        "support_strategy": strategy,
        "screening_basis": "The latest child screening determines the nutrition-support focus; previous screenings and trends inform follow-up. Region only personalizes practical food choices.",
        "summary": summary_text,
        "focus_areas": focus,
        "recommended_foods": recommended_foods,
        "meal_plan": meal_plan,
        "monitoring": monitoring,
        "professional_follow_up": follow_up,
        "age_limited": age_limited,
        "disclaimer": "Supportive nutrition information only; it is not a diagnosis or treatment and does not replace advice from a qualified health professional.",
    }
    return {
        "child_id": child_id,
        "region": region,
        "history_summary": summary,
        "nutrition_plan": plan,
        "screening_context": {
            **summary.get("latest_report", {}),
            "age_years": age_years,
            "age_months": age_months,
            "gender": (summary.get("latest_vitals") or {}).get("gender"),
            "height_cm": (summary.get("latest_vitals") or {}).get("height_cm"),
            "weight_kg": (summary.get("latest_vitals") or {}).get("weight_kg"),
            "bmi": (summary.get("latest_vitals") or {}).get("bmi"),
            "muac_cm": (summary.get("latest_vitals") or {}).get("muac_cm"),
            "weight_trend": summary.get("weight_trend"),
            "height_trend": summary.get("height_trend"),
            "bmi_trend": summary.get("bmi_trend"),
            "muac_trend": summary.get("muac_trend"),
        },
        "personalized_using": ["latest screening", "previous screening history", "recorded growth trends", "child age" if not age_limited else "age is missing or incomplete; guidance is limited", "regional food context" if region else "general food context"],
        "generated_at": datetime.now(timezone.utc),
    }


def _focus_for_history(prediction: str | None, history: dict[str, Any]) -> tuple[str, list[str], str]:
    if prediction == "stunted and underweight":
        return ("The latest screening indicates both stunting and underweight. Suggestions emphasize varied, energy- and nutrient-containing foods while the previous screening pattern remains part of the plan.", ["Age-appropriate meal frequency and energy density", "Varied protein and micronutrient-containing foods", "Growth monitoring using the full screening history"], "Please arrange follow-up with a qualified health worker or pediatric clinician for a full growth assessment.")
    if prediction == "underweight":
        detail = "Recent screenings also show repeated underweight." if history["repeated_underweight"] else ""
        if history["weight_trend"] == "decreasing":
            detail += " Recorded weight is decreasing, so professional assessment is recommended."
        return (f"The latest screening indicates underweight. {detail}".strip(), ["Sustained energy and protein support using age-appropriate meals", "Regular meals and snacks suited to the child's age and appetite", "Monitor the weight trend over follow-up screenings"], "Discuss repeated or declining measurements with a qualified health worker or pediatric clinician.")
    if prediction == "stunted":
        return ("The latest screening indicates stunting. Earlier screening results are included when planning ongoing dietary diversity and growth follow-up.", ["Dietary variety with protein and micronutrient-containing foods", "Continue height and weight monitoring", "Professional growth assessment and follow-up"], "Please arrange a growth assessment with a qualified health worker or pediatric clinician.")
    if prediction == "healthy":
        prior = "The history includes earlier nutrition-risk classifications; maintain follow-up despite the latest improvement." if history["historical_underweight"] or history["historical_stunting"] else ""
        return (f"The latest screening is healthy. {prior}".strip(), ["Balanced age-appropriate meal variety", "Include protein sources, fruits, and vegetables as available", "Continue routine growth monitoring"], "Continue routine child health and growth visits.")
    return ("The latest screening class is unavailable; guidance is limited to general supportive food variety.", ["Use varied foods appropriate to the child's age", "Record a screening result for more specific guidance"], "Consult a qualified health professional for individual advice.")


def _strategy_for_report(prediction: str | None) -> str:
    if prediction == "stunted and underweight":
        return "combined_support"
    if prediction == "underweight":
        return "underweight_support"
    if prediction == "stunted":
        return "stunting_support"
    if prediction == "healthy":
        return "balanced_support"
    return "general_support"


def _normalize_prediction(value: Any) -> str:
    normalized = str(value).strip().lower().replace("_", " ").replace("&", " and ").replace("+", " and ")
    return " ".join(normalized.split())


def _food_reasons(prediction: str | None, history: dict[str, Any]) -> str:
    if prediction in ("underweight", "stunted and underweight") or history["repeated_underweight"]:
        return "A locally available option that can contribute energy or protein as part of a varied, age-appropriate diet. It is not a treatment."
    if prediction == "stunted":
        return "A locally available option that can contribute dietary variety and nutrients as part of a balanced diet. It is not a treatment."
    return "A locally available option to support dietary variety as part of age-appropriate meals."


async def fetch_screening_history(child_id: str) -> list[dict[str, Any]]:
    return await screenings_collection.find(
        {"$or": [{"childId": child_id}, {"child_id": child_id}]}
    ).sort("createdAt", 1).to_list(length=None)
