"""Check that the TOC ships each runtime file and loads templates before use."""

from pathlib import Path
import re
import unittest
from xml.etree import ElementTree


ADDON = Path(__file__).resolve().parents[1] / "ForeverQuestChain"
UI = "{http://www.blizzard.com/wow/ui/}"
OWN_TEMPLATE = re.compile(r"\bForeverQuestChain\w+Template\b")
OWN_MIXIN = re.compile(r"\bForeverQuestChain\w+Mixin\b")
MIXIN_DEFINITION = re.compile(r"^(ForeverQuestChain\w+Mixin)\s*=", re.MULTILINE)


class RuntimeTests(unittest.TestCase):
    def test_each_view_has_its_own_template_and_mixin(self):
        manifest = self.manifest()
        for component in (
            "Window", "QuestList", "TimelinePage", "QuestDetails",
            "RewardPage", "LocationPage", "ActiveChainsPage", "MapPin", "Minimap",
        ):
            with self.subTest(component=component):
                templates = [path for path in manifest if Path(path).name == f"{component}.xml"]
                self.assertEqual(len(templates), 1)
                template = templates[0]
                mixin = Path(template).with_name(f"{component}Mixin.lua").as_posix()
                self.assertIn(mixin, manifest)
                self.assertLess(manifest.index(mixin), manifest.index(template))
                root = ElementTree.parse(ADDON / template).getroot()
                name = f"ForeverQuestChain{component}Template"
                frame = root.find(f"*[@name='{name}']")
                self.assertIsNotNone(frame)
                self.assertEqual(frame.get("mixin"), f"ForeverQuestChain{component}Mixin")

    def test_manifest_loads_each_runtime_file_once(self):
        paths = self.manifest()
        files = {
            path.relative_to(ADDON).as_posix()
            for path in ADDON.rglob("*")
            if path.suffix in (".lua", ".xml")
        }
        self.assertCountEqual(paths, files)

    def test_addon_templates_and_mixins_load_in_dependency_order(self):
        manifest = self.manifest()
        templates = set()
        mixins = set()
        for path in manifest:
            with self.subTest(path=path):
                source = (ADDON / path).read_text(encoding="utf-8")
                if path.endswith(".lua"):
                    mixins.update(MIXIN_DEFINITION.findall(source))
                    available = templates
                    if path.endswith("Mixin.lua"):
                        companion = path.removesuffix("Mixin.lua") + ".xml"
                        if companion in manifest:
                            # Methods can instantiate their own templates after file loading.
                            root = ElementTree.parse(ADDON / companion).getroot()
                            available = templates | {element.get("name") for element in root}
                    self.assertLessEqual(set(OWN_TEMPLATE.findall(source)), available)
                    continue

                root = ElementTree.fromstring(source)
                self.assertEqual(root.tag, UI + "Ui")
                for element in root.iter():
                    self.assertLessEqual(set(OWN_TEMPLATE.findall(element.get("inherits", ""))), templates)
                    self.assertLessEqual(set(OWN_MIXIN.findall(element.get("mixin", ""))), mixins)
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
