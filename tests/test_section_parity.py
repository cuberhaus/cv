"""Every CV section must have the same structure in English, Spanish and Catalan."""

from __future__ import annotations

import re
import unittest
from collections import Counter
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
CV_DIR = ROOT / "cv"
SUFFIXES = {"Spanish": "_es", "Catalan": "_ca"}
LANGUAGES = ("english", "spanish", "catalan")
SECTIONS = sorted(p.stem for p in CV_DIR.glob("*.tex") if not p.stem.endswith(tuple(SUFFIXES.values())))


def strip_comments(text: str) -> str:
    """Remove LaTeX comments while preserving escaped percent signs and line breaks (\\\\)."""
    return re.sub(r"\\.|%.*", lambda m: "" if m.group(0)[0] == "%" else m.group(0), text)


def structure(path: Path) -> Counter[str]:
    """Count the CV macros that are live (not commented out) in a section file."""
    text = strip_comments(path.read_text(encoding="utf-8"))
    return Counter(re.findall(r"\\(?:cvsection|cventry|cvhonor|cvskill|item|textbf)\b|\\\\", text))


class SectionParityTests(unittest.TestCase):
    def test_sections_are_discovered(self) -> None:
        self.assertGreaterEqual(len(SECTIONS), 7)
        expected_files = {f"{s}{sfx}.tex" for s in SECTIONS for sfx in ("", *SUFFIXES.values())}
        self.assertEqual({p.name for p in CV_DIR.glob("*.tex")}, expected_files)

    def test_sections_have_the_same_structure_in_every_language(self) -> None:
        for section in SECTIONS:
            english = structure(CV_DIR / f"{section}.tex")
            for language, suffix in SUFFIXES.items():
                with self.subTest(section=section, language=language):
                    self.assertEqual(structure(CV_DIR / f"{section}{suffix}.tex"), english)

    def test_entry_points_define_required_macros_in_every_language(self) -> None:
        for lang in LANGUAGES:
            cv_text = strip_comments((ROOT / f"cv_{lang}.tex").read_text(encoding="utf-8"))
            for macro in (r"\def\cvsfx", r"\def\cvposition", r"\def\cvextrainfo", r"\input{cv-common}"):
                self.assertIn(macro, cv_text)
            ats_text = strip_comments((ROOT / f"ats_{lang}.tex").read_text(encoding="utf-8"))
            for macro in (
                r"\def\cvsfx",
                r"\def\atsposition",
                r"\def\atslocation",
                r"\def\atslanguages",
                r"\input{ats-common}",
            ):
                self.assertIn(macro, ats_text)

    def test_strip_comments_handles_escaped_backslashes_and_percents(self) -> None:
        self.assertEqual(strip_comments(r"line\\% \item hidden"), r"line\\")
        self.assertEqual(strip_comments(r"100\% % \item hidden"), r"100\% ")


if __name__ == "__main__":
    unittest.main()
