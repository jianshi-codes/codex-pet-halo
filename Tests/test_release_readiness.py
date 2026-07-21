from __future__ import annotations

import os
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

    def test_release_launch_smoke_has_safe_typed_missing_child_diagnostics(self) -> None:
        source = (ROOT / "Scripts/release-launch-smoke.sh").read_text(encoding="utf-8")
        for diagnostic in (
            "Codex executable unavailable",
            "Codex CLI version blocked",
            "Codex CLI runtime incompatible",
            "generic child-start timeout",
        ):
            self.assertIn(diagnostic, source)
        for unsafe in ("$PATH", "raw logs", "payload"):
            self.assertNotIn(unsafe, source)

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
            "release-unsigned-preview",
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

    def test_future_release_identity_is_explicit_and_collision_safe(self) -> None:
        workflow = (ROOT / ".github/workflows/release.yml").read_text(encoding="utf-8")
        trigger = workflow.split("permissions:", maxsplit=1)[0]
        for input_name in ("build_number", "release_tag"):
            input_block = trigger.split(f"{input_name}:", maxsplit=1)[1]
            input_block = input_block.split("type:", maxsplit=1)[0]
            self.assertIn("required: true", input_block)
            self.assertNotIn("default:", input_block)
        self.assertIn("default: false", trigger)
        self.assertNotIn("default: v0.1.0-beta.1", trigger)
        self.assertNotIn('default: "1"', trigger)
        self.assertEqual(workflow.count("Reject an existing release identity"), 2)
        self.assertEqual(workflow.count("git ls-remote --exit-code --refs"), 2)
        self.assertEqual(workflow.count("gh api --include"), 2)
        self.assertEqual(workflow.count("GitHub Release already exists"), 2)
        self.assertEqual(workflow.count("Unable to prove release tag is unused"), 2)
        publish_job = workflow.split("  publish:", maxsplit=1)[1]
        self.assertLess(
            publish_job.index("Reject an existing release identity"),
            publish_job.index("Import signing and notarization credentials"),
        )

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
        self.assertIn("CURRENT_PROJECT_VERSION: 2", project)
        self.assertNotIn("beta", info.lower())
        self.assertIn('BUILD_NUMBER:-2', common)
        self.assertIn("v0.1.0-beta.2", common)

    def test_public_preview_screenshots_are_metadata_free_png_files(self) -> None:
        signature = b"\x89PNG\r\n\x1a\n"
        for filename in (
            "pet-halo-activity-above.png",
            "pet-halo-activity-below.png",
        ):
            path = ROOT / "docs/assets/screenshots" / filename
            payload = path.read_bytes()
            self.assertTrue(payload.startswith(signature), filename)
            chunk_types: list[bytes] = []
            offset = len(signature)
            while offset < len(payload):
                length = int.from_bytes(payload[offset : offset + 4], "big")
                chunk_type = payload[offset + 4 : offset + 8]
                chunk_types.append(chunk_type)
                offset += 12 + length
            self.assertEqual(offset, len(payload), filename)
            self.assertEqual(chunk_types[0], b"IHDR", filename)
            self.assertEqual(chunk_types[-1], b"IEND", filename)
            self.assertTrue(set(chunk_types) <= {b"IHDR", b"IDAT", b"IEND"}, filename)

    def test_readme_documents_both_screenshots_and_unsigned_warning(self) -> None:
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        self.assertIn("# Pet Halo for Codex", readme)
        self.assertIn("docs/assets/screenshots/pet-halo-activity-above.png", readme)
        self.assertIn("docs/assets/screenshots/pet-halo-activity-below.png", readme)
        self.assertIn("## Download", readme)
        self.assertIn("unsigned and not notarized", readme)
        self.assertIn("Only override Gatekeeper after independently verifying", readme)
        self.assertIn("jianshi-codes/codex-pet-halo", readme)

    def test_readme_release_link_metric_meanings_and_thresholds_are_explicit(self) -> None:
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        release_url = (
            "https://github.com/jianshi-codes/codex-pet-halo/releases/tag/"
            "v0.1.0-beta.1"
        )
        self.assertIn(release_url, readme)
        self.assertLess(
            readme.index("## What the rings mean"),
            readme.index("### System requirements"),
        )
        for metric in (
            "Outer ring — Weekly remaining",
            "Middle ring — optional 5h remaining",
            "Inner ring — Today versus historical peak",
        ):
            self.assertIn(metric, readme)
        for threshold in (
            "healthy: `>= 50%`",
            "warning: `20%` through `49%`",
            "critical: `< 20%`",
            "healthy: `<= 50%`",
            "warning: `> 50%` through `80%`",
            "critical: `> 80%`",
        ):
            self.assertIn(threshold, readme)
        self.assertIn("Status color does not identify the metric", readme)
        self.assertIn("Today is not a quota", readme)
        self.assertIn(
            "`T 10%` means today’s usage is 10% of the historical peak day, "
            "not 90% remaining",
            readme,
        )
        self.assertIn("codex --version", readme)
        self.assertIn("The reviewed baseline remains the strongest evidence", readme)
        self.assertIn("Session-only acceptance after required runtime capability validation", readme)

    def test_beta_one_is_released_and_current_docs_have_no_prepublication_state(self) -> None:
        changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
        beta_one = changelog.split("## [0.1.0-beta.1]", maxsplit=1)[1]
        self.assertTrue(beta_one.lstrip().startswith("- 2026-07-21"))
        self.assertNotIn("Unreleased", beta_one)

        current_documents = "\n".join(
            (ROOT / path).read_text(encoding="utf-8")
            for path in (
                "docs/CURRENT_STATE.md",
                "docs/PROJECT_PLAN.md",
                "docs/milestones/m9-public-beta-readiness.md",
            )
        )
        for stale in (
            "Publication: prohibited",
            "PR #8 remains Draft",
            "PR #9 remains open",
            "In progress — authorized",
            "No public tag",
            "before repository visibility changes",
            "does not publish a tag",
        ):
            self.assertNotIn(stale, current_documents)
        for merged_pr in ("PR #8", "PR #9", "PR #10", "PR #11"):
            self.assertIn(merged_pr, current_documents)
        self.assertIn(
            "PARTIAL — SOURCE RELEASE READY, SIGNED BINARY BLOCKED",
            current_documents,
        )
        self.assertIn("no normalized Pet anchor exists", current_documents)

    def test_versioning_documents_unsigned_and_signed_artifact_names(self) -> None:
        versioning = (ROOT / "docs/VERSIONING.md").read_text(encoding="utf-8")
        self.assertIn("Pet-Halo-<version>-unsigned-universal.zip", versioning)
        self.assertIn("Pet-Halo-<version>-universal.zip", versioning)

    def test_issue_form_labels_are_documented_by_configuration_audit(self) -> None:
        settings = (ROOT / "docs/GITHUB_SETTINGS.md").read_text(encoding="utf-8")
        form_labels: set[str] = set()
        for path in sorted((ROOT / ".github/ISSUE_TEMPLATE").glob("*.yml")):
            source = path.read_text(encoding="utf-8")
            match = re.search(r"(?m)^labels:\s*\[([^]]+)\]", source)
            if match:
                form_labels.update(
                    label.strip() for label in match.group(1).split(",") if label.strip()
                )
        self.assertEqual(form_labels, {"bug", "compatibility"})
        for label in form_labels:
            self.assertIn(f"`{label}`", settings)

    def test_dependabot_checks_github_actions_monthly(self) -> None:
        dependabot = (ROOT / ".github/dependabot.yml").read_text(encoding="utf-8")
        self.assertIn("package-ecosystem: github-actions", dependabot)
        self.assertIn("interval: monthly", dependabot)

    def test_release_notes_warn_that_preview_is_unsigned(self) -> None:
        notes = (ROOT / "docs/release-notes/v0.1.0-beta.1.md").read_text(
            encoding="utf-8"
        )
        self.assertIn(
            "Pet Halo 0.1.0 Beta 1 — Unsigned Developer Preview",
            notes,
        )
        self.assertIn("artifact is unsigned", notes)
        self.assertIn("not notarized by Apple", notes)
        self.assertIn("Do not treat this artifact as a signed or notarized release", notes)
        self.assertIn("will use a new Beta version", notes)

    def test_beta_two_uses_publication_neutral_release_notes(self) -> None:
        readme = (ROOT / "README.md").read_text(encoding="utf-8")
        notes = (ROOT / "docs/release-notes/v0.1.0-beta.2.md").read_text(
            encoding="utf-8"
        )
        changelog = (ROOT / "CHANGELOG.md").read_text(encoding="utf-8")
        self.assertIn("CURRENT_PROJECT_VERSION: 2", (ROOT / "project.yml").read_text())
        self.assertIn("W 39% · Jul 27", readme)
        self.assertIn("v0.1.0-beta.1", readme)
        self.assertIn("Pet-Halo-0.1.0-beta.2-unsigned-universal.zip", notes)
        self.assertIn("The downloadable artifact is unsigned", notes)
        self.assertIn("This is Beta software", notes)
        self.assertIn("not signed with a Developer ID certificate", notes)
        self.assertNotIn("not published", notes)
        self.assertIn("No Usage semantics", notes)
        self.assertIn("exact reviewed registry remains unchanged", notes)
        self.assertIn("Weekly Ring capsules display", changelog)

    def test_unsigned_preview_artifact_name_and_make_path_are_explicit(self) -> None:
        environment = os.environ.copy()
        environment["RELEASE_ARTIFACT_QUALIFIER"] = "unsigned"
        result = subprocess.run(
            [
                "bash",
                "-c",
                'source Scripts/release-common.sh; printf "%s\\n" "$release_archive"',
            ],
            cwd=ROOT,
            env=environment,
            check=True,
            text=True,
            stdout=subprocess.PIPE,
        )
        self.assertEqual(
            Path(result.stdout.strip()).name,
            "Pet-Halo-0.1.0-beta.2-unsigned-universal.zip",
        )
        environment.pop("RELEASE_ARTIFACT_QUALIFIER")
        default_result = subprocess.run(
            [
                "bash",
                "-c",
                'source Scripts/release-common.sh; printf "%s\\n" "$release_archive"',
            ],
            cwd=ROOT,
            env=environment,
            check=True,
            text=True,
            stdout=subprocess.PIPE,
        )
        self.assertEqual(
            Path(default_result.stdout.strip()).name,
            "Pet-Halo-0.1.0-beta.2-universal.zip",
        )
        makefile = (ROOT / "Makefile").read_text(encoding="utf-8")
        target = makefile.split("release-unsigned-preview:", maxsplit=1)[1]
        target = target.split("\n\n", maxsplit=1)[0]
        self.assertEqual(target.count("RELEASE_ARTIFACT_QUALIFIER=unsigned"), 5)
        self.assertIn("release-build", target)
        self.assertIn("release-archive", target)
        self.assertIn("release-checksum", target)
        self.assertIn("release-verify", target)
        self.assertIn("RELEASE_MODE=unsigned", target)
        self.assertIn("release-launch-smoke", target)

    def test_signed_and_notarized_workflow_remains_credential_gated(self) -> None:
        signing = (ROOT / "Scripts/release-sign.sh").read_text(encoding="utf-8")
        notarization = (ROOT / "Scripts/release-notarize.sh").read_text(encoding="utf-8")
        workflow = (ROOT / ".github/workflows/release.yml").read_text(encoding="utf-8")
        self.assertIn('[[ -n "${DEVELOPER_ID_APPLICATION:-}" ]]', signing)
        self.assertIn("--timestamp", signing)
        self.assertIn('if [[ -n "${NOTARYTOOL_PROFILE:-}" ]]', notarization)
        for variable in (
            "APPLE_NOTARY_KEY_PATH",
            "APPLE_NOTARY_KEY_ID",
            "APPLE_NOTARY_ISSUER_ID",
        ):
            self.assertIn(variable, notarization)
        self.assertIn('== "Accepted"', notarization)
        self.assertIn("stapler staple", notarization)
        self.assertIn("environment: public-beta", workflow)
        self.assertIn("make release-sign", workflow)
        self.assertIn("make release-notarize", workflow)
        self.assertIn("RELEASE_MODE=notarized make release-verify", workflow)

    def test_checksums_include_only_public_preview_assets(self) -> None:
        checksum = (ROOT / "Scripts/release-checksum.sh").read_text(encoding="utf-8")
        assets = checksum.split("readonly public_release_assets=(", maxsplit=1)[1]
        assets = assets.split("\n    )", maxsplit=1)[0]
        self.assertEqual(
            re.findall(r"\$release_[a-z]+", assets),
            ["$release_archive", "$release_manifest", "$release_notes"],
        )
        self.assertIn('shasum -a 256 "${public_release_assets[@]}"', checksum)

    def test_user_facing_security_link_uses_current_repository(self) -> None:
        config = (ROOT / ".github/ISSUE_TEMPLATE/config.yml").read_text(encoding="utf-8")
        self.assertIn("jianshi-codes/codex-pet-halo", config)
        self.assertNotIn("jianshi-codes/pet-halo", config)


if __name__ == "__main__":
    unittest.main()
