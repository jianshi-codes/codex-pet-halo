from __future__ import annotations

import re
import subprocess
import tempfile
import unittest
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
RELEASE_SCRIPTS = sorted((ROOT / "Scripts").glob("release-*.sh"))


class ReleaseReadinessTests(unittest.TestCase):
    def _commit_temp_repository(self, repository: Path, message: str) -> None:
        synthetic_author = "release-test" + "@" + "example.invalid"
        subprocess.run(["git", "-C", str(repository), "add", "."], check=True)
        subprocess.run(
            [
                "git",
                "-C",
                str(repository),
                "-c",
                "user.name=Release Test",
                "-c",
                f"user.email={synthetic_author}",
                "commit",
                "-m",
                message,
            ],
            check=True,
            stdout=subprocess.DEVNULL,
        )

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
        self.assertRegex(makefile, r"(?m)^public-exposure-audit:")

    def test_public_exposure_audit_scans_deleted_reachable_blobs(self) -> None:
        audit = ROOT / "Scripts/public-exposure-audit.py"
        with tempfile.TemporaryDirectory() as directory:
            repository = Path(directory)
            subprocess.run(["git", "init", "-q", str(repository)], check=True)
            secret = "gh" + "p_" + "A" * 24
            (repository / "old-secret.txt").write_text(secret, encoding="utf-8")
            self._commit_temp_repository(repository, "add old material")
            (repository / "old-secret.txt").unlink()
            self._commit_temp_repository(repository, "remove old material")
            result = subprocess.run(
                ["python3", str(audit), "--repository", str(repository)],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            self.assertEqual(result.returncode, 1)
            self.assertIn("access token in reachable blob", result.stderr)
            self.assertNotIn(secret, result.stderr)

    def test_public_exposure_audit_allows_only_exact_synthetic_fixture(self) -> None:
        audit = ROOT / "Scripts/public-exposure-audit.py"
        with tempfile.TemporaryDirectory() as directory:
            repository = Path(directory)
            subprocess.run(["git", "init", "-q", str(repository)], check=True)
            fixture = repository / "Tests/test_normalization.py"
            fixture.parent.mkdir(parents=True)
            fixture.write_text("person" + "@" + "example.com\n", encoding="utf-8")
            self._commit_temp_repository(repository, "add synthetic fixture")
            result = subprocess.run(
                ["python3", str(audit), "--repository", str(repository)],
                text=True,
                stdout=subprocess.PIPE,
                stderr=subprocess.PIPE,
            )
            self.assertEqual(result.returncode, 0, result.stderr)
            self.assertIn("Git-history audit passed", result.stdout)

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

    def test_signing_identity_is_bound_to_optional_release_keychain(self) -> None:
        signing = (ROOT / "Scripts/release-sign.sh").read_text(encoding="utf-8")
        workflow = (ROOT / ".github/workflows/release.yml").read_text(encoding="utf-8")
        self.assertIn('if [[ -n "${RELEASE_KEYCHAIN_PATH:-}" ]]', signing)
        self.assertEqual(signing.count("/usr/bin/codesign"), 3)
        self.assertEqual(signing.count('"${codesign_keychain_args[@]}"'), 3)
        self.assertIn("identity_fingerprint", workflow)
        self.assertIn('test "${#identity_fingerprints[@]}" -eq 1', workflow)
        self.assertIn("^[0-9A-Fa-f]{40}$", workflow)
        self.assertIn("DEVELOPER_ID_APPLICATION=$identity_fingerprint", workflow)
        self.assertIn("RELEASE_KEYCHAIN_PATH=$keychain", workflow)
        self.assertNotIn("DEVELOPER_ID_APPLICATION=$identity\n", workflow)

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
