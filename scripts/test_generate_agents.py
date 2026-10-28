"""Run with Python 3.11+: python3 scripts/test_generate_agents.py."""

from pathlib import Path
import shutil
import subprocess
import tempfile
import tomllib
import unittest


ROOT = Path(__file__).resolve().parent.parent


class GenerateAgentsTests(unittest.TestCase):
    def generate(self, platform, output, root=ROOT):
        return subprocess.run(
            ["bash", str(root / "scripts/generate-agents.sh"),
             "--platform", platform, "--output", str(output)],
            check=True, capture_output=True, text=True,
        )

    def test_platform_outputs(self):
        for platform, suffix in (
            ("codex", ".toml"), ("opencode", ".md"), ("copilot", ".agent.md"),
        ):
            with self.subTest(platform=platform), tempfile.TemporaryDirectory() as tmp:
                output = Path(tmp) / "agents with spaces"
                self.generate(platform, output)
                self.assertEqual(len(list(output.iterdir())), 3)
                for source in (ROOT / "agents").glob("*.md"):
                    body = source.read_text().split("---", 2)[2].lstrip("\n")
                    generated = (output / (source.stem + suffix)).read_text()
                    if platform == "codex":
                        agent = tomllib.loads(generated)
                        self.assertEqual(set(agent), {
                            "name", "description", "developer_instructions",
                        })
                        self.assertEqual(agent["name"], source.stem)
                        if source.stem == "teacher":
                            template = (ROOT / "agents/references/teaching-template.md").read_text()
                            self.assertIn(template.strip(), agent["developer_instructions"])
                            self.assertNotIn("reference/teaching-template.md", agent["developer_instructions"])
                        else:
                            self.assertEqual(agent["developer_instructions"], body)
                    else:
                        self.assertEqual(generated.split("---", 2)[2].lstrip("\n"), body + "\n")
                before = {p.name: p.read_bytes() for p in output.iterdir()}
                (output / "unrelated.txt").write_text("keep")
                self.generate(platform, output)
                self.assertEqual((output / "unrelated.txt").read_text(), "keep")
                for name, content in before.items():
                    self.assertEqual((output / name).read_bytes(), content)

    def test_codex_escaping(self):
        with tempfile.TemporaryDirectory() as tmp:
            root = Path(tmp)
            (root / "scripts").mkdir()
            (root / "agents").mkdir()
            shutil.copy(ROOT / "scripts/generate-agents.sh", root / "scripts")
            description = 'Handles "quotes" and \\paths'
            body = 'Keep \\n literal, Unicode: areté, and triple quotes: """\n'
            (root / "agents/fixture.md").write_text(
                f"---\nname: fixture\ndescription: {description}\n---\n\n{body}"
            )
            self.generate("codex", root / "output", root)
            agent = tomllib.loads((root / "output/fixture.toml").read_text())
            self.assertEqual(agent["description"], description)
            self.assertEqual(agent["developer_instructions"], body)

    def test_invalid_arguments(self):
        for args in (["--platform"], ["--output"], ["--platform", "invalid", "--output", "unused"]):
            with self.subTest(args=args):
                result = subprocess.run(
                    ["bash", str(ROOT / "scripts/generate-agents.sh"), *args],
                    capture_output=True, timeout=5,
                )
                self.assertNotEqual(result.returncode, 0)


if __name__ == "__main__":
    unittest.main()
