"""Check automatic GA version allocation from immutable Git tags."""

import importlib.util
from pathlib import Path
import subprocess
import tempfile
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
    def test_first_release_is_stable(self):
        self.assertEqual(load_tool("release-version").release_tag([], []), "v1.0.0")

    def test_each_new_commit_gets_next_stable_patch(self):
        allocate = load_tool("release-version").release_tag
        self.assertEqual(allocate(["v0.1.0", "v1.0.0"], []), "v1.0.1")
        self.assertEqual(allocate(["v1.2.9", "v1.2.10", "v2.0.0-beta.1", "notes"], []), "v1.2.11")

    def test_retry_reuses_exact_source_version(self):
        allocate = load_tool("release-version").release_tag
        self.assertEqual(allocate(["v1.0.1", "v1.0.2"], ["v1.0.1"]), "v1.0.1")

    def test_ambiguous_versions_on_one_commit_fail(self):
        with self.assertRaises(ValueError):
            load_tool("release-version").release_tag(["v1.0.1", "v1.0.2"], ["v1.0.1", "v1.0.2"])


class SourceOrderTests(unittest.TestCase):
    def setUp(self):
        temp = tempfile.TemporaryDirectory(prefix="questchain-release-order-")
        self.addCleanup(temp.cleanup)
        self.repo = Path(temp.name)
        self.git("init", "-q", "-b", "main")
        self.git("config", "user.name", "Release test")
        self.git("config", "user.email", "test@example.invalid")
        self.commit("Base")
        self.git("tag", "v1.0.0")
        self.commit("Older merge")
        self.older = self.git("rev-parse", "HEAD")
        self.commit("Newer merge")
        self.git("tag", "v1.0.1")

    def git(self, *args):
        return subprocess.check_output(["git", "-C", str(self.repo), *args], text=True, stderr=subprocess.DEVNULL).strip()

    def commit(self, value):
        (self.repo / "source.txt").write_text(value)
        self.git("add", ".")
        self.git("commit", "-qm", value)

    def test_older_unreleased_source_cannot_replace_newer_release(self):
        tool = load_tool("release-version")
        self.assertTrue(hasattr(tool, "allocate_release"), "Source ancestry validation is missing")
        self.git("checkout", "-q", "--detach", self.older)
        with self.assertRaisesRegex(ValueError, "older"):
            tool.allocate_release(self.repo)

    def test_descendant_merge_gets_new_version(self):
        tool = load_tool("release-version")
        self.assertTrue(hasattr(tool, "allocate_release"), "Source ancestry validation is missing")
        self.commit("Next merge")
        self.assertEqual(tool.allocate_release(self.repo), "v1.0.2")


if __name__ == "__main__":
    unittest.main()
