#!/usr/bin/env python3
"""One-off recovery verification; no signing key, app code execution or rebuild."""
import hashlib
import json
import os
from pathlib import Path
import re
import subprocess
import sys
import zipfile

from ci_debug_delivery import REPO, REF, gh_json, hashes, private_repo, require, run

SOURCE_SHA = "5ee550e977e905c55e053f2c4fb288f515e33fc1"
SOURCE_APK_SHA = "3c34795f6a36af877a3e5ffe8365e15991d5731b16cc7ed0815d78d202fb0f5d"
TABLET_CERT = "38ecfe0234e465924812ba3ee84ef838557a1d03d53713bd7a6d76478663bd6d"


def same_payload(original, candidate):
    with zipfile.ZipFile(original) as first, zipfile.ZipFile(candidate) as second:
        names = first.namelist()
        require(len(names) == len(set(names)), "Duplicate original ZIP entry")
        require(second.namelist() == names, "Candidate ZIP entries differ")
        for archive in (first, second):
            require(archive.testzip() is None, "ZIP CRC failure")
        for name in names:
            with first.open(name) as a, second.open(name) as b:
                require(hashlib.file_digest(a, "sha256").digest() ==
                        hashlib.file_digest(b, "sha256").digest(), "Application payload changed")
    return len(names)


def download(asset, target):
    require(asset["state"] == "uploaded" and 0 < asset["size"] < 350 * 1024 * 1024, "Invalid asset")
    with target.open("xb") as output:
        result = subprocess.run(["gh", "api", f"repos/{REPO}/releases/assets/{asset['id']}",
                                 "-H", "Accept: application/octet-stream"],
                                stdout=output, stderr=subprocess.PIPE)
    require(result.returncode == 0, "Asset download failed")
    digest = hashes(target)
    require(target.stat().st_size == asset["size"] and asset.get("digest") == "sha256:" + digest,
            "Downloaded asset size/SHA mismatch")
    return digest


def main():
    require(os.environ.get("GITHUB_ACTIONS") == "true" and
            os.environ.get("RUNNER_ENVIRONMENT") == "github-hosted" and
            os.environ.get("GITHUB_EVENT_NAME") == "workflow_dispatch" and
            os.environ.get("GITHUB_REPOSITORY") == REPO and os.environ.get("GITHUB_REF") == REF,
            "Only manual private-WIP hosted CI may verify")
    release_id = os.environ.get("BILGA_CANDIDATE_RELEASE", "")
    require(re.fullmatch(r"[1-9][0-9]{0,15}", release_id), "Invalid candidate release ID")
    private_repo()
    release = gh_json(f"repos/{REPO}/releases/{release_id}")
    require(release["draft"] is True and release["published_at"] is None and
            release["target_commitish"] == SOURCE_SHA and
            release["tag_name"] == "wip-tablet-debug-39926382854-1", "Wrong/unpublished candidate required")
    require([a["name"] for a in release["assets"]] == ["tablet-debug.apk"], "Candidate must contain only APK")
    source_run = gh_json(f"repos/{REPO}/actions/runs/39926382854")
    require(source_run["conclusion"] == "success" and source_run["head_sha"] == SOURCE_SHA and
            source_run["event"] == "workflow_dispatch" and source_run["head_branch"] == REF.removeprefix("refs/heads/"),
            "Original build evidence mismatch")
    source_asset = gh_json(f"repos/{REPO}/releases/assets/668549689")
    require(source_asset.get("digest") == "sha256:" + SOURCE_APK_SHA, "Original asset changed")
    directory = Path(os.environ["RUNNER_TEMP"]) / "bilga-tablet-verify"
    directory.mkdir(mode=0o700, exist_ok=False)
    original, candidate = directory / "original.apk", directory / "tablet-debug.apk"
    require(download(source_asset, original) == SOURCE_APK_SHA, "Wrong CI original")
    digest = download(release["assets"][0], candidate)
    signer = str(Path(os.environ["ANDROID_HOME"]) / "build-tools/36.0.0/apksigner")
    run(signer, "verify", "--verbose", str(original))
    certificate = run(signer, "verify", "--verbose", "--print-certs", str(candidate))
    require(re.findall(r"Signer #\d+ certificate SHA-256 digest: ([0-9a-f]{64})", certificate) == [TABLET_CERT],
            "Candidate does not match installed tablet signer")
    entries = same_payload(original, candidate)
    run("unzip", "-tq", str(candidate))
    require(hashes(candidate) == digest and hashes(original) == SOURCE_APK_SHA, "Files changed during verification")
    metadata = dict(app_source_commit=SOURCE_SHA, verification_commit=os.environ["GITHUB_SHA"],
                    verification_run_id=os.environ["GITHUB_RUN_ID"], original_apk_sha256=SOURCE_APK_SHA,
                    apk_sha256=digest, apk_bytes=candidate.stat().st_size, signer_sha256=TABLET_CERT,
                    zip_crc="PASS", payload_entries_equal=entries, signature="PASS (v2)",
                    hash_agreement="PASS (Python, sha256sum, GitHub server)",
                    signing="Existing LOCAL debug key; private key never uploaded to GitHub")
    (directory / "VERIFIED_TABLET_METADATA.json").write_text(json.dumps(metadata, indent=2) + "\n")
    (directory / "SHA256SUMS").write_text(f"{digest}  tablet-debug.apk\n")
    private_repo()
    run("gh", "release", "upload", release["tag_name"], str(directory / "VERIFIED_TABLET_METADATA.json"),
        str(directory / "SHA256SUMS"), "--repo", REPO)
    stored = gh_json(f"repos/{REPO}/releases/{release_id}")
    require(stored["draft"] is True and stored["published_at"] is None, "Draft status changed")
    assets = {a["name"]: a for a in stored["assets"]}
    require(set(assets) == {"tablet-debug.apk", "SHA256SUMS", "VERIFIED_TABLET_METADATA.json"}, "Unexpected asset")
    for name in ("SHA256SUMS", "VERIFIED_TABLET_METADATA.json"):
        require(assets[name].get("digest") == "sha256:" + hashes(directory / name), "Metadata upload differs")
    require(assets["tablet-debug.apk"]["digest"] == "sha256:" + digest, "Candidate asset changed")
    print(json.dumps(metadata, indent=2))
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as summary:
        summary.write(f"\n[PRIVATE unpublished tablet debug APK]({stored['html_url']})\n\n"
                      f"SHA-256 `{digest}`; signer `{TABLET_CERT}`.\n\n"
                      f"All {entries} application ZIP entries match CI original `{SOURCE_SHA}`.\n\n"
                      "Signature verification only; no rebuild, key upload or device install.\n")


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, ValueError, zipfile.BadZipFile) as error:
        print(f"Candidate verification STOP: {error}", file=sys.stderr)
        sys.exit(1)
