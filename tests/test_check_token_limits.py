#!/usr/bin/env python3
"""Tests scripts/check-token-limits.py scopes its scan to the PR's own diff.

Builds a real two-parent merge commit (the shape `refs/pull/N/merge`
checkouts produce) with an oversized file the PR did NOT touch plus one it
did, and asserts only the touched file is reported. Also checks the
push-checkout fallback (single-parent HEAD) still scans the whole tree.
"""
import shutil
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

REPO_ROOT = Path(__file__).resolve().parent.parent
SCRIPT = REPO_ROOT / "scripts" / "check-token-limits.py"


def run_git(cwd, *args):
    subprocess.run(["git", *args], cwd=cwd, check=True, capture_output=True, text=True)


def run_script(cwd):
    return subprocess.run(
        [sys.executable, str(SCRIPT)], cwd=cwd, capture_output=True, text=True
    )


class TokenLimitsScanScope(unittest.TestCase):
    def setUp(self):
        self.tmp = Path(tempfile.mkdtemp())
        self.addCleanup(shutil.rmtree, self.tmp, ignore_errors=True)
        run_git(self.tmp, "init", "-q")
        run_git(self.tmp, "config", "user.email", "test@example.com")
        run_git(self.tmp, "config", "user.name", "test")
        (self.tmp / ".token-limits.yaml").write_text(
            "limits:\n  '*.txt': 3\n"
        )
        # Pre-existing oversized file, already on the base branch.
        (self.tmp / "already-big.txt").write_text("one two three four five\n")
        run_git(self.tmp, "add", "-A")
        run_git(self.tmp, "commit", "-q", "-m", "base")
        run_git(self.tmp, "branch", "-m", "base")

    def _merge_pr_branch(self):
        run_git(self.tmp, "checkout", "-q", "-b", "pr")
        (self.tmp / "touched-big.txt").write_text("six seven eight nine ten\n")
        run_git(self.tmp, "add", "-A")
        run_git(self.tmp, "commit", "-q", "-m", "pr change")
        run_git(self.tmp, "checkout", "-q", "base")
        run_git(self.tmp, "merge", "-q", "--no-ff", "-m", "merge", "pr")

    def test_pr_merge_commit_scans_only_the_pr_diff(self):
        self._merge_pr_branch()
        result = run_script(self.tmp)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("touched-big.txt", result.stdout)
        self.assertNotIn("already-big.txt", result.stdout)

    def test_push_checkout_falls_back_to_full_scan(self):
        # Single-parent HEAD (no merge) — same as a push to develop/main.
        result = run_script(self.tmp)
        self.assertEqual(result.returncode, 1, result.stdout + result.stderr)
        self.assertIn("already-big.txt", result.stdout)


if __name__ == "__main__":
    unittest.main()
