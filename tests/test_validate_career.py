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

    def test_missing_localized_facts_are_rejected(self) -> None:
        invalid_inventory = deepcopy(self.inventory)
        invalid_inventory["experience"][0].pop("role")

        with self.assertRaisesRegex(validate_career.CareerValidationError, "role"):
            validate_career.validate(invalid_inventory)


if __name__ == "__main__":
    unittest.main()
