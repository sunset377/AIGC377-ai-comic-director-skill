import re
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
SKILL = ROOT / "skill" / "ai-comic-director"


class RepositoryTests(unittest.TestCase):
    def test_public_files_exist(self):
        for relative in ["README.md", "LICENSE", "VERSION", "docs/index.html", "docs/app.js", "skill/ai-comic-director/SKILL.md"]:
            self.assertTrue((ROOT / relative).is_file(), relative)

    def test_version_is_v2(self):
        self.assertRegex((ROOT / "VERSION").read_text(encoding="utf-8").strip(), r"^2\.\d+\.\d+$")

    def test_skill_frontmatter_and_name(self):
        text = (SKILL / "SKILL.md").read_text(encoding="utf-8")
        self.assertTrue(text.startswith("---\n"))
        self.assertRegex(text, r"(?m)^name: ai-comic-director$")
        self.assertRegex(text, r"(?m)^description: .+$")

    def test_skill_references_exist(self):
        text = (SKILL / "SKILL.md").read_text(encoding="utf-8")
        for relative in re.findall(r"\((references/[^)]+\.md)\)", text):
            self.assertTrue((SKILL / relative).is_file(), relative)

    def test_required_templates_exist(self):
        templates = SKILL / "assets" / "templates"
        self.assertEqual(len(list(templates.glob("*.md"))), 7)
        self.assertTrue((templates / "asset-manifest.csv").is_file())

    def test_demo_is_local_and_interactive(self):
        html = (ROOT / "docs" / "index.html").read_text(encoding="utf-8")
        js = (ROOT / "docs" / "app.js").read_text(encoding="utf-8")
        self.assertIn('type="file"', html)
        self.assertIn('id="storyboard-body"', html)
        self.assertIn("file.text()", js)
        self.assertNotIn("fetch(", js)

    def test_installer_targets_codex_skills(self):
        text = (ROOT / "installer" / "install.ps1").read_text(encoding="utf-8")
        self.assertIn(".codex\\skills", text)
        self.assertIn("CODEX_HOME", text)
        self.assertNotIn(".agents\\skills", text)

    def test_no_private_workspace_markers(self):
        blocked = ["C:" + "\\Users\\98017", "D:" + "\\C盘迁移", "MO" + "MOCO", "wx" + "id_"]
        for path in ROOT.rglob("*"):
            if not path.is_file() or ".git" in path.parts or "__pycache__" in path.parts:
                continue
            text = path.read_text(encoding="utf-8", errors="ignore")
            for marker in blocked:
                self.assertNotIn(marker, text, f"{marker} in {path}")


if __name__ == "__main__":
    unittest.main()
