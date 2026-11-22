"""Check that the TOC ships each runtime file and loads templates before use."""

from pathlib import Path
import re
import unittest
from xml.etree import ElementTree


ADDON = Path(__file__).resolve().parents[1] / "ForeverQuestChain"
UI = "{http://www.blizzard.com/wow/ui/}"
OWN_TEMPLATE = re.compile(r"\bForeverQuestChain\w+Template\b")


class RuntimeTests(unittest.TestCase):
    def test_manifest_loads_each_runtime_file_once(self):
        paths = self.manifest()
        files = {
            path.relative_to(ADDON).as_posix()
            for path in ADDON.rglob("*")
            if path.suffix in (".lua", ".xml")
        }
        self.assertCountEqual(paths, files)

    def test_addon_templates_exist_before_their_consumers(self):
        templates = set()
        for path in self.manifest():
            with self.subTest(path=path):
                source = (ADDON / path).read_text(encoding="utf-8")
                if path.endswith(".lua"):
                    self.assertLessEqual(set(OWN_TEMPLATE.findall(source)), templates)
                    continue

                root = ElementTree.fromstring(source)
                self.assertEqual(root.tag, UI + "Ui")
                for element in root.iter():
                    self.assertLessEqual(set(OWN_TEMPLATE.findall(element.get("inherits", ""))), templates)
                    name = element.get("name", "")
                    if OWN_TEMPLATE.fullmatch(name):
                        self.assertEqual(element.get("virtual"), "true")
                        self.assertNotIn(name, templates)
                        templates.add(name)

    @staticmethod
    def manifest():
        toc = (ADDON / "ForeverQuestChain.toc").read_text(encoding="utf-8")
        return [
            line.strip().replace("\\", "/")
            for line in toc.splitlines()
            if line.strip() and not line.startswith("#")
        ]


if __name__ == "__main__":
    unittest.main()
