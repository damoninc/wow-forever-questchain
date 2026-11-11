"""Check version decisions and source TOC updates for the release action."""

import importlib.util
from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


def load_tool(name):
    path = ROOT / "tools" / f"{name}.py"
    if not path.is_file():
        raise AssertionError(f"Release helper is missing: {path.name}")
    spec = importlib.util.spec_from_file_location(name, path)
    module = importlib.util.module_from_spec(spec)
    spec.loader.exec_module(module)
    return module


class VersionTests(unittest.TestCase):
    def test_patch_minor_and_explicit_versions(self):
        next_version = load_tool("bump-version").next_version
        self.assertEqual(next_version("0.1.0", "patch"), "0.1.1")
        self.assertEqual(next_version("0.1.9", "minor"), "0.2.0")
        self.assertEqual(next_version("0.1.0", "exact", "1.0.0"), "1.0.0")

    def test_beta_progression_and_promotion(self):
        next_version = load_tool("bump-version").next_version
        self.assertEqual(next_version("0.1.0", "exact", "0.2.0-beta.1"), "0.2.0-beta.1")
        self.assertEqual(next_version("0.2.0-beta.1", "exact", "0.2.0-beta.2"), "0.2.0-beta.2")
        self.assertEqual(next_version("0.2.0-beta.2", "exact", "0.2.0"), "0.2.0")
        with self.assertRaises(ValueError):
            next_version("0.2.0-beta.1", "patch")

    def test_invalid_or_nonincreasing_versions_fail(self):
        next_version = load_tool("bump-version").next_version
        for version in ("", "v0.2.0", "01.0.0", "0.1", "0.1.0", "0.0.9", "0.1.0-beta.1", "0.2.0-rc.1", "0.2.0-beta.01"):
            with self.subTest(version=version), self.assertRaises(ValueError):
                next_version("0.1.0", "exact", version)
        with self.assertRaises(ValueError):
            next_version("0.1.0", "patch", "0.2.0")

    def test_toc_update_preserves_every_other_byte(self):
        bump = load_tool("bump-version").update_toc
        for newline in (b"\n", b"\r\n"):
            before = newline.join([b"## Title: QuestChain", b"## Version: 0.1.0", b"## SavedVariables: Settings", b"", b"Core.lua", b""])
            after, version = bump(before, "patch")
            self.assertEqual(version, "0.1.1")
            self.assertEqual(after, before.replace(b"## Version: 0.1.0", b"## Version: 0.1.1"))
        with self.assertRaises(ValueError):
            bump(b"## Version: 0.1.0\n## Version: 0.1.0\n", "patch")


if __name__ == "__main__":
    unittest.main()
