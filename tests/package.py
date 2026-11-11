"""Exercise actual BigWigs GA packaging and localhost uploads from the Git index."""

from email.parser import BytesParser
from email.policy import default
import hashlib
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
import io
import json
import os
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
    def command(self, *args):
        result = subprocess.run(args, cwd=self.repo, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout[-4000:] + result.stderr[-4000:])
        return result.stdout.strip()

    def setUp(self):
        self.assertTrue(PACKAGER, "Set PACKAGER_SCRIPT to the pinned BigWigs release.sh")
        temp = tempfile.TemporaryDirectory(prefix="questchain-package-")
        self.addCleanup(temp.cleanup)
        self.repo = Path(temp.name)
        tree = subprocess.check_output(["git", "write-tree"], cwd=ROOT, text=True).strip()
        data = subprocess.check_output(["git", "archive", tree], cwd=ROOT)
        with tarfile.open(fileobj=io.BytesIO(data)) as archive:
            archive.extractall(self.repo, filter="data")
        self.command("git", "init", "-q", "-b", "main")
        self.command("git", "config", "user.name", "Package test")
        self.command("git", "config", "user.email", "test@example.invalid")
        self.command("git", "remote", "add", "origin", "https://github.com/damoninc/wow-forever-questchain.git")
        self.command("git", "add", ".")
        self.command("git", "commit", "-qm", "Merged source fixture")
        self.tag = "v1.0.1"
        self.command("git", "tag", self.tag)

    def package(self, github_context=False):
        env = {"PATH": os.environ["PATH"], "HOME": str(self.repo)}
        if github_context:
            env.update(GITHUB_ACTIONS="true", GITHUB_EVENT_NAME="push",
                       GITHUB_REF=f"refs/tags/{self.tag}", GITHUB_REF_NAME=self.tag,
                       GITHUB_OUTPUT=str(self.repo / "outputs"))
        result = subprocess.run(["bash", PACKAGER, "-d", "-g", "forever", "-n", "QuestChain-{project-version}"],
                                cwd=self.repo, env=env, text=True, capture_output=True)
        self.assertEqual(result.returncode, 0, result.stdout[-4000:] + result.stderr[-4000:])
        archives = list((self.repo / ".release").glob("*.zip"))
        self.assertEqual(len(archives), 1, result.stdout)
        self.assert_package(archives[0])

    def assert_package(self, path):
        self.assertEqual(path.name, f"QuestChain-{self.tag}.zip")
        with zipfile.ZipFile(path) as archive:
            names = archive.namelist()
            self.assertEqual({name.split("/")[0] for name in names}, {"ForeverQuestChain"})
            toc = archive.read("ForeverQuestChain/ForeverQuestChain.toc").decode()
            self.assertIn(f"## Version: {self.tag}", toc)
            self.assertIn("## Interface: 16001", toc)
            self.assertIn("## Dependencies: QuestieDB", toc)
            self.assertNotIn("@project-version@", toc)
            for line in toc.splitlines():
                if line.strip() and not line.startswith("#"):
                    self.assertIn("ForeverQuestChain/" + line.strip(), names)
            for name in names:
                self.assertFalse(any(f"/{folder}/" in name for folder in (
                    "tests", "tools", "types", "docs", ".github", ".vscode", "ForeverQuestChain",
                )), name)
            self.assertTrue(any("CHANGELOG" in name for name in names))

    def test_stable_package_preserves_merged_source(self):
        toc = self.repo / "ForeverQuestChain/ForeverQuestChain.toc"
        source = toc.read_bytes()
        self.package()
        self.assertEqual(toc.read_bytes(), source)

    def test_generated_tag_context_on_main_push(self):
        self.package(github_context=True)

    def test_next_merge_uses_next_patch_without_version_commit(self):
        toc = self.repo / "ForeverQuestChain/ForeverQuestChain.toc"
        source = toc.read_bytes()
        readme = self.repo / "README.md"
        readme.write_text(readme.read_text() + "\nMerged change fixture\n")
        self.command("git", "commit", "-qam", "Next merge")
        merged = self.command("git", "rev-parse", "HEAD")
        self.tag = self.command("python3", "tools/release-version.py")
        self.assertEqual(self.tag, "v1.0.2")
        self.command("git", "tag", self.tag)
        self.package()
        self.assertEqual(self.command("git", "rev-parse", "HEAD"), merged)
        self.assertEqual(toc.read_bytes(), source)

    def upload(self, status):
        posts = []

        class Handler(BaseHTTPRequestHandler):
            def log_message(self, *_args):
                pass

            def do_GET(self):
                self.send_response(200)
                self.end_headers()
                self.wfile.write(b'[{"id":17053,"name":"1.60.1","gameVersionTypeID":88568}]')

            def do_POST(self):
                body = self.rfile.read(int(self.headers["Content-Length"]))
                message = BytesParser(policy=default).parsebytes(
                    f'Content-Type: {self.headers["Content-Type"]}\r\n\r\n'.encode() + body)
                parts = {part.get_param("name", header="content-disposition"): part.get_payload(decode=True)
                         for part in message.iter_parts()}
                posts.append((self.path, parts))
                self.send_response(status)
                self.end_headers()
                self.wfile.write(b'{"id":42}' if status == 200 else b'{"errorMessage":"Uncertain upload result"}')

        server = ThreadingHTTPServer(("127.0.0.1", 0), Handler)
        threading.Thread(target=server.serve_forever, daemon=True).start()
        self.addCleanup(server.server_close)
        self.addCleanup(server.shutdown)
        script = self.repo / "publisher.sh"
        script.write_text(Path(PACKAGER).read_text())
        self.command("python3", "tools/prepare-publisher.py", str(script))
        script.write_text(script.read_text().replace("https://wow.curseforge.com", f"http://127.0.0.1:{server.server_port}"))
        result = subprocess.run(["bash", str(script), "-g", "forever", "-n", "QuestChain-{project-version}"],
                                cwd=self.repo, text=True, capture_output=True, timeout=20,
                                env={"PATH": os.environ["PATH"], "HOME": str(self.repo), "CF_API_TOKEN": "localhost-test"})
        self.assertEqual(len(posts), 1, result.stdout + result.stderr)
        self.assertEqual(posts[0][0], "/api/projects/1792071/upload-file")
        return result, posts[0][1]

    def test_failed_upload_is_not_retried(self):
        result, _parts = self.upload(503)
        self.assertNotEqual(result.returncode, 0)
        self.assertFalse((self.repo / ".release/curseforge-upload.json").exists())

    def test_successful_upload_records_exact_bytes(self):
        result, parts = self.upload(200)
        self.assertEqual(result.returncode, 0, result.stdout + result.stderr)
        receipt_path = self.repo / ".release/curseforge-upload.json"
        self.assertTrue(receipt_path.is_file(), "Successful CurseForge upload receipt is missing")
        receipt = json.loads(receipt_path.read_text())
        self.assertEqual(receipt["id"], 42)
        self.assertEqual(receipt["sha256"], hashlib.sha256(parts["file"]).hexdigest())
        self.assertEqual(receipt["version"], self.tag)
        self.assertEqual(receipt["sourceCommit"], self.command("git", "rev-parse", "HEAD"))
        metadata = json.loads(parts["metadata"])
        self.assertEqual(metadata["releaseType"], "release")
        self.assertEqual(metadata["gameVersions"], [17053])
        self.assertIn({"slug": "questiedb", "type": "requiredDependency"}, metadata["relations"]["projects"])


if __name__ == "__main__":
    unittest.main()
