"""Small, deterministic topic retrieval over reviewed project/WHO notes."""
from dataclasses import dataclass
from pathlib import Path
import re


KNOWLEDGE_DIR = Path(__file__).resolve().parent


@dataclass(frozen=True)
class KnowledgeSource:
    title: str
    url: str


PROJECT_SOURCE = KnowledgeSource("PoshanEye repository facts", "")
WHO_SOURCES = [
    KnowledgeSource("WHO Child Growth Standards", "https://www.who.int/tools/child-growth-standards"),
    KnowledgeSource("WHO Child Growth Standards Q&A", "https://www.who.int/news-room/questions-and-answers/item/child-growth-standards"),
    KnowledgeSource("WHO child malnutrition indicators", "https://www.who.int/data/nutrition/nlis/info/malnutrition-in-children/"),
    KnowledgeSource("WHO AnthroPlus", "https://www.who.int/tools/growth-reference-data-for-5to19-years/application-tools"),
    KnowledgeSource("WHO BMI-for-age, 5–19 years", "https://www.who.int/tools/growth-reference-data-for-5to19-years/indicators/bmi-for-age"),
]

_TOPICS = {
    "who": ("who growth", "who standard", "who reference", "who anthroplus", "who definition", "growth standard", "growth reference", "z-score", "z score", "stunting", "stunted", "wasting", "underweight", "anthroplus", "bmi-for-age", "weight-for-age", "height-for-age"),
    "pipeline": ("scan", "screen", "camera", "image", "photo", "workflow", "preprocess", "preprocess", "upload", "mobilenet", "mediapipe", "deeplab", "segment", "feature", "classifier", "svm", "offline", "backend"),
    "metrics": ("accuracy", "metric", "reliable", "performance", "recall", "precision", "f1", "auc", "confusion", "test set", "dataset"),
    "nutrition": ("nutrition", "meal", "food", "plan", "recommend", "allergy", "vegetarian", "portion", "calorie"),
    "privacy": ("privacy", "private", "stored", "storage", "image sent", "data", "child record", "history", "offline"),
}


def retrieve_knowledge(question: str) -> tuple[str, list[KnowledgeSource]]:
    text = question.casefold()
    words = set(re.findall(r"[a-z0-9]+", text))

    def matches(term: str) -> bool:
        term_words = re.findall(r"[a-z0-9]+", term.casefold())
        return term in text if len(term_words) > 1 else bool(term_words and term_words[0] in words)

    selected = {
        name for name, terms in _TOPICS.items()
        if any(matches(term) for term in terms)
    }
    if not selected:
        selected = {"project"}
    project_path = KNOWLEDGE_DIR / "project.md"
    try:
        project_sections = project_path.read_text(encoding="utf-8").split("\n## ")
        project_available = True
    except OSError:
        project_sections = []
        project_available = False
    relevant_headings = set()
    if "pipeline" in selected:
        relevant_headings.update({"PoshanEye project facts (verified from repository)", "Current prediction path", "Quality and limitations"})
    if "project" in selected:
        relevant_headings.add("PoshanEye project facts (verified from repository)")
    if "metrics" in selected:
        relevant_headings.update({"PoshanEye project facts (verified from repository)", "Verified production evaluation", "Quality and limitations"})
    if "nutrition" in selected:
        relevant_headings.update({"PoshanEye project facts (verified from repository)", "Nutrition plan implementation"})
    if "privacy" in selected:
        relevant_headings.update({"PoshanEye project facts (verified from repository)", "Privacy and scope"})
    if "who" in selected:
        relevant_headings.update({"PoshanEye project facts (verified from repository)", "Current prediction path"})
    if not relevant_headings:
        relevant_headings.add("PoshanEye project facts (verified from repository)")
    docs: list[str] = [
        section if section.startswith("# ") else "## " + section
        for section in project_sections
        if section.splitlines()[0].removeprefix("# ") in relevant_headings
    ]
    sources = [PROJECT_SOURCE] if project_available else []
    if not project_available:
        docs.append("No reviewed PoshanEye project knowledge is currently available. Say that the repository notes could not be loaded and do not guess project-specific facts.")
    if "who" in selected:
        try:
            docs.append((KNOWLEDGE_DIR / "who_growth.md").read_text(encoding="utf-8"))
            sources.extend(WHO_SOURCES)
        except OSError:
            docs.append("No reviewed WHO reference notes are currently available. Do not state clinical thresholds from memory; say the source notes could not be loaded.")
    return "\n\n".join(docs), sources
