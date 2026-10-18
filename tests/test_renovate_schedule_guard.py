"""Unit tests for scripts/renovate-schedule-guard.sh."""

import shutil
import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = (
    Path(__file__).resolve().parents[1] / "scripts" / "renovate-schedule-guard.sh"
)


class RenovateScheduleGuardTest(unittest.TestCase):
    def run_guard(self, name, text):
        repo = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, repo, ignore_errors=True)
        (repo / name).parent.mkdir(parents=True, exist_ok=True)
        (repo / name).write_text(text)
        return subprocess.run(["bash", str(SCRIPT)], cwd=repo, capture_output=True, text=True)

    def test_preset_only_config_passes(self):
        result = self.run_guard("renovate.json", '{"extends": ["local>dryvist/.github"]}\n')
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_comment_mentioning_schedule_passes(self):
        text = '{\n  // no schedule: here\n  extends: ["local>dryvist/.github"],\n}\n'
        self.assertEqual(self.run_guard("renovate.json5", text).returncode, 0)

    def test_each_forbidden_key_fails(self):
        for body in (
            '{"schedule": ["after 5am"]}',
            '{"timezone": "UTC"}',
            '{"packageRules": [{"automergeSchedule": ["* 0-3 * * *"]}]}',
            '{"vulnerabilityAlerts": {"schedule": ["at any time"]}}',
        ):
            with self.subTest(body=body):
                result = self.run_guard(".github/renovate.json", body + "\n")
                self.assertEqual(result.returncode, 1)
                self.assertIn("::error file=.github/renovate.json,line=1", result.stdout)


if __name__ == "__main__":
    unittest.main()
