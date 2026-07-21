from __future__ import annotations

import re
import subprocess
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RELEASE_SCRIPTS = sorted((ROOT / "Scripts").glob("release-*.sh"))


class ReleaseReadinessTests(unittest.TestCase):
    def test_release_scripts_are_valid_shell_and_have_no_embedded_credentials(self) -> None:
        self.assertGreaterEqual(len(RELEASE_SCRIPTS), 8)
        prohibited = (
            "BEGIN PRIVATE KEY",
            "BEGIN CERTIFICATE",
            "apple-id=",
            "issuer-id=",
            "key-id=",
        )
        for path in RELEASE_SCRIPTS:
            subprocess.run(["bash", "-n", str(path)], check=True)
            source = path.read_text(encoding="utf-8")
            for marker in prohibited:
                self.assertNotIn(marker, source, path.name)

    def test_make_exposes_complete_release_surface(self) -> None:
        makefile = (ROOT / "Makefile").read_text(encoding="utf-8")
        for target in (
            "release-build",
            "release-archive",
            "release-checksum",
            "release-sign",
            "release-notarize",
            "release-verify",
            "release-launch-smoke",
        ):
            self.assertRegex(makefile, rf"(?m)^{re.escape(target)}:")

    def test_release_workflow_is_manual_pinned_and_prerelease_only(self) -> None:
        workflow = (ROOT / ".github/workflows/release.yml").read_text(encoding="utf-8")
        trigger = workflow.split("permissions:", maxsplit=1)[0]
        self.assertIn("workflow_dispatch:", trigger)
        self.assertNotRegex(trigger, r"(?m)^\s+(push|pull_request):")
        self.assertIn("inputs.publish && github.ref == 'refs/heads/main'", workflow)
        self.assertIn("environment: public-beta", workflow)
        self.assertIn("--prerelease", workflow)
        all_workflows = "\n".join(
            path.read_text(encoding="utf-8")
            for path in sorted((ROOT / ".github/workflows").glob("*.yml"))
        )
        action_refs = re.findall(r"uses:\s+[^@\s]+@([^\s#]+)", all_workflows)
        self.assertTrue(action_refs)
        self.assertTrue(all(re.fullmatch(r"[0-9a-f]{40}", ref) for ref in action_refs))

    def test_issue_forms_request_only_sanitized_compatibility_fields(self) -> None:
        form = (ROOT / ".github/ISSUE_TEMPLATE/compatibility_report.yml").read_text(
            encoding="utf-8"
        )
        for required in (
            "macOS version",
            "Architecture",
            "Pet Halo version",
            "Codex CLI version",
            "Codex Desktop version",
            "Pet state",
            "Safe application state",
        ):
            self.assertIn(required, form)
        warning = form.lower()
        for forbidden in (
            "raw protocol payloads",
            "tokens",
            "account identity",
            "conversation content",
            "private screenshots",
        ):
            self.assertIn(forbidden, warning)

    def test_release_metadata_is_numeric_and_beta_is_tag_only(self) -> None:
        project = (ROOT / "project.yml").read_text(encoding="utf-8")
        info = (ROOT / "Config/Info.plist").read_text(encoding="utf-8")
        common = (ROOT / "Scripts/release-common.sh").read_text(encoding="utf-8")
        self.assertIn("MARKETING_VERSION: 0.1.0", project)
        self.assertIn("CURRENT_PROJECT_VERSION: 1", project)
        self.assertNotIn("beta", info.lower())
        self.assertIn("v0.1.0-beta.1", common)


if __name__ == "__main__":
    unittest.main()
