"""Tests for the public career inventory validation contract."""

from __future__ import annotations

import importlib.util
import unittest
from copy import deepcopy
from pathlib import Path

import yaml

ROOT = Path(__file__).resolve().parents[1]
SPEC = importlib.util.spec_from_file_location("validate_career", ROOT / "scripts" / "validate-career.py")
assert SPEC and SPEC.loader
validate_career = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(validate_career)


class ValidateCareerTests(unittest.TestCase):
    def setUp(self) -> None:
        self.inventory = yaml.safe_load((ROOT / "data" / "career.yaml").read_text(encoding="utf-8"))

    def test_current_inventory_is_valid(self) -> None:
        validate_career.validate(self.inventory)

    def test_duplicate_record_ids_are_rejected(self) -> None:
        invalid_inventory = deepcopy(self.inventory)
        invalid_inventory["projects"][0]["id"] = invalid_inventory["experience"][0]["id"]

        with self.assertRaisesRegex(validate_career.CareerValidationError, "duplicate id"):
            validate_career.validate(invalid_inventory)

    def test_duplicate_achievement_ids_are_rejected(self) -> None:
        invalid_inventory = deepcopy(self.inventory)
        invalid_inventory["experience"][1]["achievements"][0]["id"] = (
            invalid_inventory["experience"][0]["achievements"][0]["id"]
        )

        with self.assertRaisesRegex(validate_career.CareerValidationError, "duplicate id"):
            validate_career.validate(invalid_inventory)

    def test_invalid_dates_are_rejected(self) -> None:
        invalid_inventory = deepcopy(self.inventory)
        invalid_inventory["education"][0]["start_date"] = "2023"

        with self.assertRaisesRegex(validate_career.CareerValidationError, "YYYY-MM"):
            validate_career.validate(invalid_inventory)

    def test_reversed_date_ranges_are_rejected(self) -> None:
        invalid_inventory = deepcopy(self.inventory)
        invalid_inventory["education"][0]["start_date"] = "2024-01"

        with self.assertRaisesRegex(validate_career.CareerValidationError, "start_date must not be after end_date"):
            validate_career.validate(invalid_inventory)

    def test_invalid_tags_are_rejected(self) -> None:
        invalid_inventory = deepcopy(self.inventory)
        invalid_inventory["projects"][0]["tags"] = [""]

        with self.assertRaisesRegex(validate_career.CareerValidationError, r"projects\[0\]\.tags\[0\]"):
            validate_career.validate(invalid_inventory)

    def test_missing_localized_facts_are_rejected(self) -> None:
        invalid_inventory = deepcopy(self.inventory)
        invalid_inventory["experience"][0].pop("role")

        with self.assertRaisesRegex(validate_career.CareerValidationError, "role"):
            validate_career.validate(invalid_inventory)

    def test_non_kebab_case_ids_are_rejected(self) -> None:
        invalid_inventory = deepcopy(self.inventory)
        invalid_inventory["projects"][0]["id"] = "Invalid_ID"

        with self.assertRaisesRegex(validate_career.CareerValidationError, "kebab-case"):
            validate_career.validate(invalid_inventory)

    def test_invalid_evidence_urls_and_missing_fields_are_rejected(self) -> None:
        invalid_inventory = deepcopy(self.inventory)
        invalid_inventory["projects"][0]["evidence"] = ["https://"]
        with self.assertRaisesRegex(validate_career.CareerValidationError, "https URL"):
            validate_career.validate(invalid_inventory)

        missing_tags = deepcopy(self.inventory)
        missing_tags["projects"][0].pop("tags")
        with self.assertRaisesRegex(validate_career.CareerValidationError, r"projects\[0\]\.tags"):
            validate_career.validate(missing_tags)

        empty_context = deepcopy(self.inventory)
        empty_context["projects"][0]["context"] = ""
        with self.assertRaisesRegex(validate_career.CareerValidationError, r"projects\[0\]\.context"):
            validate_career.validate(empty_context)

        latex_dash = deepcopy(self.inventory)
        latex_dash["certifications"][0]["name"] = "Cert --- Name"
        with self.assertRaisesRegex(validate_career.CareerValidationError, "LaTeX"):
            validate_career.validate(latex_dash)


if __name__ == "__main__":
    unittest.main()
