"""Every CV section must have the same structure in English, Spanish and Catalan."""

from __future__ import annotations

import re
import unittest
from collections import Counter
from pathlib import Path

CV_DIR = Path(__file__).resolve().parents[1] / "cv"
SUFFIXES = {"Spanish": "_es", "Catalan": "_ca"}
SECTIONS = sorted(p.stem for p in CV_DIR.glob("*.tex") if not p.stem.endswith(tuple(SUFFIXES.values())))


def structure(path: Path) -> Counter[str]:
    """Count the CV macros that are live (not commented out) in a section file."""
    text = re.sub(r"(?<!\\)%.*", "", path.read_text(encoding="utf-8"))
    return Counter(re.findall(r"\\(cvsection|cventry|cvhonor|cvskill|item)\b", text))


class SectionParityTests(unittest.TestCase):
    def test_sections_are_discovered(self) -> None:
        self.assertGreaterEqual(len(SECTIONS), 7)

    def test_sections_have_the_same_structure_in_every_language(self) -> None:
        for section in SECTIONS:
            english = structure(CV_DIR / f"{section}.tex")
            for language, suffix in SUFFIXES.items():
                with self.subTest(section=section, language=language):
                    self.assertEqual(structure(CV_DIR / f"{section}{suffix}.tex"), english)


if __name__ == "__main__":
    unittest.main()
