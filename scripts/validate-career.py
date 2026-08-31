"""Validate the public, fact-only career inventory used for CV tailoring."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import Any

import yaml

INVENTORY_PATH = Path(__file__).resolve().parents[1] / "data" / "career.yaml"
DATE_PATTERN = re.compile(r"^\d{4}-(0[1-9]|1[0-2])$")
REQUIRED_COLLECTIONS = ("experience", "education", "projects", "skills", "certifications")


class CareerValidationError(ValueError):
    """Raised when career.yaml does not satisfy the tailoring-data contract."""


def require_mapping(value: Any, context: str) -> dict[str, Any]:
    if not isinstance(value, dict):
        raise CareerValidationError(f"{context} must be a mapping")
    return value


def require_string(value: Any, context: str) -> str:
    if not isinstance(value, str) or not value.strip():
        raise CareerValidationError(f"{context} must be a non-empty string")
    return value


def require_list(value: Any, context: str) -> list[Any]:
    if not isinstance(value, list):
        raise CareerValidationError(f"{context} must be a list")
    return value


def validate_date(value: Any, context: str, *, allow_present: bool = False) -> None:
    if allow_present and value == "present":
        return
    if not isinstance(value, str) or not DATE_PATTERN.fullmatch(value):
        raise CareerValidationError(f"{context} must use YYYY-MM" + (" or present" if allow_present else ""))


def validate_tagged_record(record: Any, context: str, *, requires_publication: bool = True) -> str:
    data = require_mapping(record, context)
    record_id = require_string(data.get("id"), f"{context}.id")
    require_list(data.get("tags", []), f"{context}.tags")
    if requires_publication:
        if not isinstance(data.get("publishable"), bool):
            raise CareerValidationError(f"{context}.publishable must be boolean")
        evidence = require_list(data.get("evidence", []), f"{context}.evidence")
        for index, url in enumerate(evidence):
            if not isinstance(url, str) or not url.startswith("https://"):
                raise CareerValidationError(f"{context}.evidence[{index}] must be an https URL")
    return record_id


def validate(document: Any) -> None:
    data = require_mapping(document, "career inventory")
    if data.get("schema_version") != 1:
        raise CareerValidationError("schema_version must be 1")

    person = require_mapping(data.get("person"), "person")
    require_string(person.get("id"), "person.id")
    require_string(person.get("name"), "person.name")
    require_string(person.get("location"), "person.location")
    for index, language in enumerate(require_list(person.get("languages"), "person.languages")):
        language_data = require_mapping(language, f"person.languages[{index}]")
        require_string(language_data.get("id"), f"person.languages[{index}].id")
        require_string(language_data.get("language"), f"person.languages[{index}].language")
        require_string(language_data.get("proficiency"), f"person.languages[{index}].proficiency")

    seen_ids: set[str] = set()
    for collection in REQUIRED_COLLECTIONS:
        for index, record in enumerate(require_list(data.get(collection), collection)):
            context = f"{collection}[{index}]"
            record_id = validate_tagged_record(record, context, requires_publication=collection != "skills")
            if record_id in seen_ids:
                raise CareerValidationError(f"duplicate id: {record_id}")
            seen_ids.add(record_id)

            record_data = require_mapping(record, context)
            if collection == "experience":
                for field in ("organization", "role", "location"):
                    require_string(record_data.get(field), f"{context}.{field}")
                validate_date(record_data.get("start_date"), f"{context}.start_date")
                validate_date(record_data.get("end_date"), f"{context}.end_date", allow_present=True)
                for achievement_index, achievement in enumerate(require_list(record_data.get("achievements"), f"{context}.achievements")):
                    achievement_data = require_mapping(achievement, f"{context}.achievements[{achievement_index}]")
                    require_string(achievement_data.get("id"), f"{context}.achievements[{achievement_index}].id")
                    require_string(achievement_data.get("text"), f"{context}.achievements[{achievement_index}].text")
                    require_mapping(achievement_data.get("metrics"), f"{context}.achievements[{achievement_index}].metrics")
            elif collection == "education":
                for field in ("institution", "qualification", "location"):
                    require_string(record_data.get(field), f"{context}.{field}")
                validate_date(record_data.get("start_date"), f"{context}.start_date")
                validate_date(record_data.get("end_date"), f"{context}.end_date")
            elif collection == "projects":
                require_string(record_data.get("name"), f"{context}.name")
                require_string(record_data.get("summary"), f"{context}.summary")
            elif collection == "skills":
                require_string(record_data.get("category"), f"{context}.category")
                for item_index, item in enumerate(require_list(record_data.get("items"), f"{context}.items")):
                    require_string(item, f"{context}.items[{item_index}]")
            elif collection == "certifications":
                require_string(record_data.get("name"), f"{context}.name")
                validate_date(record_data.get("issued_at"), f"{context}.issued_at")


def load_and_validate(path: Path = INVENTORY_PATH) -> None:
    with path.open(encoding="utf-8") as inventory_file:
        validate(yaml.safe_load(inventory_file))


if __name__ == "__main__":
    try:
        load_and_validate()
    except (CareerValidationError, OSError, yaml.YAMLError) as error:
        print(f"Career inventory validation failed: {error}", file=sys.stderr)
        raise SystemExit(1) from error
    print(f"Career inventory is valid: {INVENTORY_PATH}")
