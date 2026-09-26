"""Unit tests for scripts/check-renovate-annotations.sh.

Covers the git-refs requirements.yml gap this script exists to close: a
`type: git` collection entry's annotation sits above `- name:`/`type: git`
carrier lines, not immediately above the `version:` SHA line those managers
in most other file classes require. Asserts:
  - an annotated git-refs pin in requirements.yml passes despite the carrier
    lines (the actual bug this suite guards against regressing)
  - an unannotated git-refs pin in requirements.yml still fails
  - the stricter comment-only gap is unchanged for a role-defaults pin (the
    requirements.yml relaxation must not leak into other file classes)
  - zero covered files is reported as an instrument error (exit 2), never a
    silent pass
"""

import subprocess
import tempfile
import unittest
from pathlib import Path

SCRIPT = (
    Path(__file__).resolve().parents[1] / "scripts" / "check-renovate-annotations.sh"
)

SHA = "c5e139cb7ccb286016020dd85c2f1d9c3b5a376f"


class CheckRenovateAnnotationsTest(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(
            subprocess.run, ["rm", "-rf", str(self.tmp)], check=False
        )

    def _run(self):
        return subprocess.run(
            ["bash", str(SCRIPT), str(self.tmp)],
            capture_output=True,
            text=True,
        )

    def test_annotated_git_ref_pin_with_carrier_lines_passes(self):
        (self.tmp / "requirements.yml").write_text(
            "---\n"
            "collections:\n"
            "  # renovate: datasource=git-refs depName=https://github.com/dryvist/homelab-contracts.git currentValue=main\n"
            "  - name: https://github.com/dryvist/homelab-contracts.git#/ansible/\n"
            "    type: git\n"
            f"    version: {SHA}\n"
        )
        result = self._run()
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertIn("0 unannotated", result.stderr)

    def test_unannotated_git_ref_pin_fails(self):
        (self.tmp / "requirements.yml").write_text(
            "---\n"
            "collections:\n"
            "  - name: https://github.com/dryvist/homelab-contracts.git#/ansible/\n"
            "    type: git\n"
            f"    version: {SHA}\n"
        )
        result = self._run()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("unannotated version pin", result.stderr)

    def test_role_defaults_pin_keeps_comment_only_gap(self):
        # The requirements.yml relaxation must not leak into role defaults:
        # a real (non-comment) line between the annotation and the pin still
        # fails here, mirroring that customManager's comment-only regex gap.
        role_dir = self.tmp / "roles" / "example" / "defaults"
        role_dir.mkdir(parents=True)
        (role_dir / "main.yml").write_text(
            "---\n"
            "# renovate: datasource=github-releases depName=example/example\n"
            "unrelated_key: some_value\n"
            'traefik_version: "3.1.0"\n'
        )
        result = self._run()
        self.assertEqual(result.returncode, 1, result.stderr)
        self.assertIn("unannotated version pin", result.stderr)

    def test_zero_covered_files_is_instrument_error(self):
        (self.tmp / "README.md").write_text("nothing covered here\n")
        result = self._run()
        self.assertEqual(result.returncode, 2, result.stderr)


if __name__ == "__main__":
    unittest.main()
