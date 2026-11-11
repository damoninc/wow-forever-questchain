"""Exercise real BigWigs packages from the Git index, without uploading anything.

Run with PACKAGER_SCRIPT pointing to the pinned BigWigs release.sh.
"""

import io
import json
import os
import re
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
import subprocess
import tarfile
import tempfile
import threading
import unittest
import zipfile


ROOT = Path(__file__).resolve().parents[1]
PACKAGER = os.environ.get("PACKAGER_SCRIPT")


class PackageTests(unittest.TestCase):
    def run_command(self, *args, check=True):
        result = subprocess.run(args, cwd=self.repo, text=True, capture_output=True)
        if check and result.returncode:
            self.fail(result.stdout[-6000:] + result.stderr[-6000:])
        return result

    def setUp(self):
        self.assertTrue(PACKAGER, "Set PACKAGER_SCRIPT to BigWigs release.sh")
        self.temp = tempfile.TemporaryDirectory(prefix="questchain-package-")
        self.addCleanup(self.temp.cleanup)
        self.repo = Path(self.temp.name)
        tree = subprocess.check_output(["git", "write-tree"], cwd=ROOT, text=True).strip()
        archive = subprocess.check_output(["git", "archive", tree], cwd=ROOT)
        with tarfile.open(fileobj=io.BytesIO(archive)) as source:
            source.extractall(self.repo, filter="data")
        self.toc_path = self.repo / "ForeverQuestChain/ForeverQuestChain.toc"
        self.version = re.search(r"^## Version: (.+)$", self.toc_path.read_text(), re.M)[1]
        self.run_command("git", "init", "-q", "-b", "main")
        self.run_command("git", "config", "user.name", "Package test")
        self.run_command("git", "config", "user.email", "test@example.invalid")
        self.run_command("git", "remote", "add", "origin", "https://github.com/damoninc/wow-forever-questchain.git")
        self.run_command("git", "add", ".")
        self.run_command("git", "commit", "-qm", "Release fixture")
        self.run_command("git", "tag", "v" + self.version)

    def prepare(self, ref_type, ref_name, check=True):
        script = self.repo / "tools/prepare-release.sh"
        self.assertTrue(script.is_file(), "Release version preparation is missing")
        return self.run_command("bash", str(script), ref_type, ref_name, check=check)

    def package(self):
        args = ["bash", PACKAGER, "-d", "-g", "forever", "-n", "QuestChain-{project-version}"]
        # Publication credentials must never enter these integration tests.
        env = {k: v for k, v in os.environ.items() if k not in (
            "CF_API_TOKEN", "GH_API_TOKEN", "GITHUB_TOKEN", "WAGO_API_TOKEN", "WOWI_API_TOKEN",
            "GITHUB_ACTIONS", "GITHUB_REF", "GITHUB_REF_NAME",
        )}
        result = subprocess.run(args, cwd=self.repo, text=True, capture_output=True, env=env)
        self.assertEqual(result.returncode, 0, result.stdout[-6000:] + result.stderr[-6000:])
        archives = list((self.repo / ".release").glob("*.zip"))
        self.assertEqual(len(archives), 1, archives)
        return archives[0]

    def assert_package(self, archive, version):
        self.assertEqual(archive.name, f"QuestChain-{version}.zip")
        with zipfile.ZipFile(archive) as package:
            names = package.namelist()
            self.assertEqual({name.split("/")[0] for name in names}, {"ForeverQuestChain"})
            toc = package.read("ForeverQuestChain/ForeverQuestChain.toc").decode()
            self.assertIn(f"## Version: {version}", toc)
            self.assertIn("## Interface: 16001", toc)
            self.assertIn("## X-Curse-Project-ID: 1792071", toc)
            self.assertIn("## Dependencies: QuestieDB", toc)
            self.assertIn("## OptionalDeps: TomTom", toc)
            self.assertNotIn("@project-version@", toc)
            for line in toc.splitlines():
                if line.strip() and not line.startswith("#"):
                    self.assertIn("ForeverQuestChain/" + line.strip(), names)
            for name in names:
                self.assertNotIn("/ForeverQuestChain/", name)
                self.assertFalse(any(f"/{folder}/" in name for folder in (
                    "tests", "tools", "types", "docs", ".github", ".vscode",
                )), name)
            self.assertTrue(any("CHANGELOG" in name for name in names))

    def test_stable_package(self):
        self.prepare("tag", "v" + self.version)
        self.assert_package(self.package(), "v" + self.version)

    def test_beta_package(self):
        self.run_command("git", "tag", "-d", "v" + self.version)
        beta = "0.2.0-beta.1"
        self.toc_path.write_text(re.sub(r"^## Version: .+$", "## Version: " + beta, self.toc_path.read_text(), flags=re.M))
        self.run_command("git", "commit", "--allow-empty", "-qam", "Beta fixture")
        self.run_command("git", "tag", "v" + beta)
        self.prepare("tag", "v" + beta)
        self.assert_package(self.package(), "v" + beta)

    def test_bumped_release_candidate_uses_new_source_version(self):
        args = ["python3", str(self.repo / "tools/bump-version.py")]
        if "-beta." in self.version:
            args += ["exact", "--version", self.version.split("-beta.")[0]]
        else:
            args.append("patch")
        version = self.run_command(*args).stdout.strip()
        self.assertNotEqual(version, self.version)
        self.run_command("git", "add", "ForeverQuestChain/ForeverQuestChain.toc")
        self.run_command("git", "commit", "-qm", f"chore(release): v{version}")
        self.run_command("git", "tag", "-a", "v" + version, "-m", "Release candidate")
        self.prepare("tag", "v" + version)
        self.assert_package(self.package(), "v" + version)
        committed_toc = self.run_command("git", "show", "HEAD:ForeverQuestChain/ForeverQuestChain.toc").stdout
        self.assertIn(f"## Version: {version}", committed_toc)
        self.assertNotIn("@project-version@", committed_toc)

    def test_development_before_first_release(self):
        self.run_command("git", "tag", "-d", "v" + self.version)
        self.prepare("branch", "main")
        archive = self.package()
        commit = self.run_command("git", "rev-parse", "--short=7", "HEAD").stdout.strip()
        self.assert_package(archive, commit)

    def test_development_package_identifies_its_commit(self):
        toc_path = self.repo / "ForeverQuestChain/ForeverQuestChain.toc"
        toc_path.write_text(toc_path.read_text() + "\n# Development fixture\n")
        self.run_command("git", "commit", "-qam", "Development build")
        commit = self.run_command("git", "rev-parse", "--short=7", "HEAD").stdout.strip()
        self.prepare("branch", "main")
        self.assert_package(self.package(), f"v{self.version}-1-g{commit}")

    def test_mismatched_tag_fails_without_modifying_source(self):
        toc = self.repo / "ForeverQuestChain/ForeverQuestChain.toc"
        before = toc.read_bytes()
        result = self.prepare("tag", "v9999.0.0", check=False)
        self.assertNotEqual(result.returncode, 0)
        self.assertIn("must match", result.stderr)
        self.assertEqual(toc.read_bytes(), before)

    def test_failed_upload_is_not_retried(self):
        helper = self.repo / "tools/prepare-publisher.py"
        self.assertTrue(helper.is_file(), "Single-attempt publisher preparation is missing")
        requests = []

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_args):
                pass

            def do_GET(self):
                self.send_response(200)
                self.end_headers()
                self.wfile.write(json.dumps([{
                    "id": 17053, "name": "1.60.1", "gameVersionTypeID": 88568,
                }]).encode())

            def do_POST(self):
                requests.append(self.path)
                self.rfile.read(int(self.headers["Content-Length"]))
                self.send_response(503)
                self.end_headers()
                self.wfile.write(b'{"errorMessage":"Uncertain upload result"}')

        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        thread = threading.Thread(target=server.serve_forever, daemon=True)
        thread.start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        script = self.repo / "publisher.sh"
        script.write_text(Path(PACKAGER).read_text())
        self.run_command("python3", str(helper), str(script))
        # Redirect only this temporary test copy; dummy credentials never leave localhost.
        script.write_text(script.read_text().replace(
            "https://wow.curseforge.com", f"http://127.0.0.1:{server.server_port}",
        ))
        self.prepare("tag", "v" + self.version)
        result = subprocess.run(
            ["bash", str(script), "-g", "forever", "-n", "QuestChain-{project-version}"],
            cwd=self.repo, text=True, capture_output=True, timeout=20,
            env={"PATH": os.environ["PATH"], "HOME": str(self.repo), "CF_API_TOKEN": "test-token"},
        )
        self.assertNotEqual(result.returncode, 0, result.stdout + result.stderr)
        self.assertEqual(requests, ["/api/projects/1792071/upload-file"])


if __name__ == "__main__":
    unittest.main()
