"""Tests for scripts/build-local.sh using a fake docker, so no Docker or TeX is needed."""

from __future__ import annotations

import os
import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parents[1] / "scripts" / "build-local.sh"
LANGUAGES = ("english", "spanish", "catalan")
PRESETS = ("standard", "technical", "complete", "concise")
PHOTOS = ("photo", "no-photo")

# Stands in for `docker run ... bash -s -- <parallelism> <source stem bits photo>...`:
# records its argv and "builds" an empty PDF for every job's output stem.
FAKE_DOCKER = r"""#!/usr/bin/env bash
printf '%s\n' "$@" > "$FAKE_DOCKER_LOG"
cat > /dev/null
while (($#)); do
    case $1 in
        -v) root=${2%:/workdir}; shift ;;
        --) shift; break ;;
    esac
    shift
done
shift # parallelism
while (($#)); do : > "$root/build/$2.pdf"; shift 4; done
"""


class BuildLocalTests(unittest.TestCase):
    def setUp(self) -> None:
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.root = Path(tmp.name)
        # The script resolves the repo root from its own location, so a copy keeps the real build/ and dist/ untouched.
        (self.root / "scripts").mkdir()
        shutil.copy(SCRIPT, self.root / "scripts" / SCRIPT.name)
        (self.root / "bin").mkdir()
        docker = self.root / "bin" / "docker"
        docker.write_text(FAKE_DOCKER, encoding="utf-8")
        docker.chmod(0o755)
        self.log = self.root / "docker.log"
        self.env = {
            **os.environ,
            "PATH": f"{self.root / 'bin'}{os.pathsep}{os.environ['PATH']}",
            "FAKE_DOCKER_LOG": str(self.log),
        }

    def build(self, *args: str) -> subprocess.CompletedProcess[str]:
        script = self.root / "scripts" / SCRIPT.name
        return subprocess.run(["bash", str(script), *args], env=self.env, capture_output=True, text=True)

    def built(self) -> set[str]:
        return {path.name for path in (self.root / "dist").glob("*.pdf")}

    def jobs(self) -> list[list[str]]:
        """The [source, stem, bits, photo] jobs the script handed to the container."""
        args = self.log.read_text(encoding="utf-8").splitlines()
        rest = args[args.index("--") + 2 :]  # skip "--" and the parallelism value
        return [rest[i : i + 4] for i in range(0, len(rest), 4)]

    def test_default_builds_the_standard_photo_cv_for_every_language(self) -> None:
        self.assertEqual(self.build().returncode, 0)
        expected = {f"cv_{lang}{suffix}.pdf" for lang in LANGUAGES for suffix in ("", "_standard_photo")}
        self.assertEqual(self.built(), expected)  # the bare name is the back-compat alias
        self.assertEqual(self.jobs()[0], ["cv_english", "cv_english_standard_photo", "0111", "1"])

    def test_preset_and_photo_mode_choose_the_toggles(self) -> None:
        self.assertEqual(self.build("english", "--preset", "technical", "--photo-mode", "no-photo").returncode, 0)
        self.assertEqual(self.built(), {"cv_english_technical_no-photo.pdf"})
        self.assertEqual(self.jobs(), [["cv_english", "cv_english_technical_no-photo", "0011", "0"]])

    def test_all_curated_with_ats_builds_every_public_variant(self) -> None:
        self.assertEqual(self.build("--all-curated", "--include-ats").returncode, 0)
        expected = {f"cv_{lang}_{preset}_{photo}.pdf" for lang in LANGUAGES for preset in PRESETS for photo in PHOTOS}
        expected |= {f"cv_{lang}.pdf" for lang in LANGUAGES}
        expected |= {f"ats_{lang}_standard.pdf" for lang in LANGUAGES}
        self.assertEqual(self.built(), expected)
        self.assertIn(["cv_english", "cv_english_complete_photo", "1111", "1"], self.jobs())
        self.assertIn(["ats_english", "ats_english_standard", "0111", "0"], self.jobs())

    def test_only_preset_limits_a_curated_build(self) -> None:
        self.assertEqual(self.build("spanish", "--all-curated", "--only-preset", "concise").returncode, 0)
        self.assertEqual(self.built(), {"cv_spanish_concise_photo.pdf", "cv_spanish_concise_no-photo.pdf"})
        self.assertEqual(
            self.jobs(),
            [
                ["cv_spanish", "cv_spanish_concise_photo", "0001", "1"],
                ["cv_spanish", "cv_spanish_concise_no-photo", "0001", "0"],
            ],
        )

    def test_ats_style_builds_the_photo_free_variant(self) -> None:
        self.assertEqual(self.build("catalan", "--style", "ats", "--photo-mode", "no-photo").returncode, 0)
        self.assertEqual(self.built(), {"ats_catalan_standard.pdf"})
        self.assertEqual(self.jobs(), [["ats_catalan", "ats_catalan_standard", "0111", "0"]])

    def test_invalid_arguments_fail_before_docker_runs(self) -> None:
        invalid = (
            ("--preset", "bogus"),
            ("--parallelism", "99"),
            ("--style", "ats"),  # ATS is photo-free and the default photo mode is "photo"
            ("--all-curated", "--style", "ats", "--photo-mode", "no-photo"),
            ("--nope",),
        )
        for args in invalid:
            with self.subTest(args=args):
                result = self.build(*args)
                self.assertEqual(result.returncode, 1)
                self.assertIn("error:", result.stderr)
                self.assertFalse(self.log.exists())


if __name__ == "__main__":
    unittest.main()
