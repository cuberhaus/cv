"""Validate the public, fact-only career inventory used for CV tailoring."""

from __future__ import annotations

import re
import sys
from pathlib import Path
from typing import Any

import yaml

INVENTORY_PATH = Path(__file__).resolve().parents[1] / "data" / "career.yaml"
DATE_PATTERN = re.compile(r"^\d{4}-(0[1-9]|1[0-2])$")
ID_PATTERN = re.compile(r"^[a-z0-9]+(?:-[a-z0-9]+)*$")
HTTPS_URL_PATTERN = re.compile(r"^https://\S+$")
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
    if "---" in value:
        raise CareerValidationError(f"{context} must not contain raw LaTeX '---' markup")
    return value


def require_list(value: Any, context: str) -> list[Any]:
    if not isinstance(value, list):
        raise CareerValidationError(f"{context} must be a list")
    return value


def register_unique_id(value: Any, context: str, seen_ids: set[str]) -> str:
    record_id = require_string(value, context)
    if not ID_PATTERN.fullmatch(record_id):
        raise CareerValidationError(f"{context} must be lowercase kebab-case")
    if record_id in seen_ids:
        raise CareerValidationError(f"duplicate id: {record_id}")
    seen_ids.add(record_id)
    return record_id


def validate_date(value: Any, context: str, *, allow_present: bool = False) -> None:
    if allow_present and value == "present":
        return
    if not isinstance(value, str) or not DATE_PATTERN.fullmatch(value):
        raise CareerValidationError(f"{context} must use YYYY-MM" + (" or present" if allow_present else ""))


def validate_date_range(start_date: Any, end_date: Any, context: str, *, allow_present: bool = False) -> None:
    validate_date(start_date, f"{context}.start_date")
    validate_date(end_date, f"{context}.end_date", allow_present=allow_present)
    if end_date != "present" and start_date > end_date:
        raise CareerValidationError(f"{context}.start_date must not be after end_date")


def validate_tagged_record(
    record: Any, context: str, seen_ids: set[str], *, requires_publication: bool = True
) -> dict[str, Any]:
    data = require_mapping(record, context)
    register_unique_id(data.get("id"), f"{context}.id", seen_ids)
    tags_raw = data.get("tags") if requires_publication else data.get("tags", [])
    tags = require_list(tags_raw, f"{context}.tags")
    if requires_publication and not tags:
        raise CareerValidationError(f"{context}.tags must not be empty")
    for index, tag in enumerate(tags):
        require_string(tag, f"{context}.tags[{index}]")
    if requires_publication:
        if not isinstance(data.get("publishable"), bool):
            raise CareerValidationError(f"{context}.publishable must be boolean")
        for index, url in enumerate(require_list(data.get("evidence"), f"{context}.evidence")):
            if not isinstance(url, str) or not HTTPS_URL_PATTERN.fullmatch(url):
                raise CareerValidationError(f"{context}.evidence[{index}] must be an https URL")
    return data


def validate(document: Any) -> None:
    data = require_mapping(document, "career inventory")
    if data.get("schema_version") != 1:
        raise CareerValidationError("schema_version must be 1")

    seen_ids: set[str] = set()
    person = require_mapping(data.get("person"), "person")
    register_unique_id(person.get("id"), "person.id", seen_ids)
    require_string(person.get("name"), "person.name")
    require_string(person.get("location"), "person.location")
    for index, language in enumerate(require_list(person.get("languages"), "person.languages")):
        language_data = require_mapping(language, f"person.languages[{index}]")
        register_unique_id(language_data.get("id"), f"person.languages[{index}].id", seen_ids)
        require_string(language_data.get("language"), f"person.languages[{index}].language")
        require_string(language_data.get("proficiency"), f"person.languages[{index}].proficiency")

    for collection in REQUIRED_COLLECTIONS:
        for index, record in enumerate(require_list(data.get(collection), collection)):
            context = f"{collection}[{index}]"
            record_data = validate_tagged_record(
                record, context, seen_ids, requires_publication=collection != "skills"
            )
            if collection == "experience":
                for field in ("organization", "role", "location"):
                    require_string(record_data.get(field), f"{context}.{field}")
                validate_date_range(record_data.get("start_date"), record_data.get("end_date"), context, allow_present=True)
                achievements = require_list(record_data.get("achievements"), f"{context}.achievements")
                if not achievements:
                    raise CareerValidationError(f"{context}.achievements must not be empty")
                for achievement_index, achievement in enumerate(achievements):
                    achievement_data = require_mapping(achievement, f"{context}.achievements[{achievement_index}]")
                    register_unique_id(
                        achievement_data.get("id"),
                        f"{context}.achievements[{achievement_index}].id",
                        seen_ids,
                    )
                    require_string(achievement_data.get("text"), f"{context}.achievements[{achievement_index}].text")
                    require_mapping(achievement_data.get("metrics"), f"{context}.achievements[{achievement_index}].metrics")
            elif collection == "education":
                for field in ("institution", "qualification", "location"):
                    require_string(record_data.get(field), f"{context}.{field}")
                validate_date_range(record_data.get("start_date"), record_data.get("end_date"), context)
            elif collection == "projects":
                require_string(record_data.get("name"), f"{context}.name")
                require_string(record_data.get("summary"), f"{context}.summary")
                if "context" in record_data:
                    require_string(record_data.get("context"), f"{context}.context")
            elif collection == "skills":
                require_string(record_data.get("category"), f"{context}.category")
                items = require_list(record_data.get("items"), f"{context}.items")
                if not items:
                    raise CareerValidationError(f"{context}.items must not be empty")
                for item_index, item in enumerate(items):
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
