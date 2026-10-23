#!/usr/bin/env python3
"""Allowlisted debug delivery; never signs, reads keys, or publishes a release."""
import hashlib
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import sys
import zipfile

REPO = "abdulAziz-Al-ILM/Bilga-Lokal"
REF = "refs/heads/wip/todo-widget-recovery"
FILES = ("app-debug.apk", "SHA256SUMS", "SOURCE.txt", "BUILD_METADATA.json")


def require(condition, message):
    if not condition:
        raise RuntimeError(message)


def run(*args, data=None):
    result = subprocess.run(args, input=data, capture_output=True, text=True)
    # Do not echo subprocess stderr: authenticated URLs/headers are not logs.
    require(result.returncode == 0, f"{args[0]} failed (exit {result.returncode})")
    return result.stdout


def hashes(path):
    before = path.stat()
    with path.open("rb") as stream:
        python_sha = hashlib.file_digest(stream, "sha256").hexdigest()
    native_sha = run("sha256sum", str(path)).split()[0]
    after = path.stat()
    require((before.st_ino, before.st_size, before.st_mtime_ns, before.st_ctime_ns) ==
            (after.st_ino, after.st_size, after.st_mtime_ns, after.st_ctime_ns),
            "File changed during hashing; STOP")
    require(python_sha == native_sha, "Python/native SHA-256 mismatch; STOP")
    return python_sha


def gh_json(endpoint, payload=None):
    args = ["gh", "api", endpoint]
    if payload is not None:
        args += ["--method", "POST", "--input", "-"]
    return json.loads(run(*args, data=json.dumps(payload) if payload else None))


def prepare(directory):
    directory.mkdir(mode=0o700, exist_ok=False)
    source = Path("build/app/outputs/flutter-apk/app-debug.apk")
    source_sha = hashes(source)
    apk = directory / "app-debug.apk"
    shutil.copyfile(source, apk)
    apk.chmod(0o400)
    require(hashes(apk) == source_sha, "APK copy differs; STOP")
    with zipfile.ZipFile(apk) as archive:
        require(archive.testzip() is None, "Python ZIP CRC failure")
    run("unzip", "-tq", str(apk))
    signer = Path(os.environ["ANDROID_HOME"]) / "build-tools/36.0.0/apksigner"
    certificate = run(str(signer), "verify", "--verbose", "--print-certs", str(apk))
    fingerprints = re.findall(r"Signer #\d+ certificate SHA-256 digest: ([0-9a-f]{64})", certificate)
    require(len(fingerprints) == 1, "Expected one verified debug signer")
    metadata = dict(source_commit=os.environ["GITHUB_SHA"], run_id=os.environ["GITHUB_RUN_ID"],
                    run_attempt=os.environ["GITHUB_RUN_ATTEMPT"], apk_sha256=source_sha,
                    apk_bytes=apk.stat().st_size, signer_sha256=fingerprints[0],
                    zip_crc="PASS (Python and unzip)", signature="PASS (apksigner)",
                    hash_agreement="PASS (Python and sha256sum)",
                    signing="Disposable runner debug key; NOT a tablet update authorization")
    (directory / "BUILD_METADATA.json").write_text(json.dumps(metadata, indent=2) + "\n")
    (directory / "SHA256SUMS").write_text(f"{source_sha}  app-debug.apk\n")
    (directory / "SOURCE.txt").write_text(f"Source commit: {os.environ['GITHUB_SHA']}\n")
    print(json.dumps(metadata, indent=2))
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as summary:
        summary.write(f"\nAPK SHA-256: `{source_sha}`\n\nSigner SHA-256: `{fingerprints[0]}`\n\n")


def private_repo():
    repo = gh_json(f"repos/{REPO}")
    require(repo["private"] is True and repo["full_name"] == REPO, "Not the expected PRIVATE repository")


def publish(directory):
    private_repo()
    metadata = json.loads((directory / "BUILD_METADATA.json").read_text())
    require(metadata["source_commit"] == os.environ["GITHUB_SHA"], "Wrong source commit")
    require(hashes(directory / "app-debug.apk") == metadata["apk_sha256"], "APK changed before delivery")
    tag = f"wip-debug-{os.environ['GITHUB_RUN_ID']}-{os.environ['GITHUB_RUN_ATTEMPT']}"
    release = gh_json(f"repos/{REPO}/releases", dict(
        tag_name=tag, target_commitish=os.environ["GITHUB_SHA"], draft=True,
        prerelease=True, make_latest="false", name=f"WIP debug (UNPUBLISHED) {tag}",
        body=f"Temporary private debug delivery; no production release.\n\n"
             f"Source: {metadata['source_commit']}\nSHA-256: {metadata['apk_sha256']}\n"
             f"Signer: {metadata['signer_sha256']}\n\n"
             "Do not install unless local/tablet hashes AND installed signer match.\n"
             "Uses a disposable debug key; existing tablet signing key was NOT uploaded."))
    require(release["draft"] is True and release["published_at"] is None, "Release is not an unpublished draft")
    run("gh", "release", "upload", tag, *(str(directory / name) for name in FILES), "--repo", REPO)
    private_repo()
    stored = gh_json(f"repos/{REPO}/releases/{release['id']}")
    require(stored["draft"] is True and stored["published_at"] is None, "Draft status changed")
    assets = {asset["name"]: asset for asset in stored["assets"]}
    require(set(assets) == set(FILES), "Unexpected/missing release asset")
    for name in FILES:
        asset = assets[name]
        require(asset["state"] == "uploaded" and asset["size"] == (directory / name).stat().st_size,
                f"Upload incomplete: {name}")
        require(asset.get("digest") == "sha256:" + hashes(directory / name),
                f"GitHub asset digest mismatch: {name}")
    print(f"PRIVATE unpublished draft verified: {stored['html_url']}")
    print(f"APK asset ID: {assets['app-debug.apk']['id']}")
    with open(os.environ["GITHUB_STEP_SUMMARY"], "a") as summary:
        summary.write(f"\n[Private unpublished debug draft]({stored['html_url']})\n\n"
                      f"Release `{stored['id']}`; APK asset `{assets['app-debug.apk']['id']}`. "
                      "All four server asset digests match the runner. Never publish this draft.\n")


def main():
    require(os.environ.get("GITHUB_ACTIONS") == "true" and
            os.environ.get("RUNNER_ENVIRONMENT") == "github-hosted" and
            os.environ.get("GITHUB_EVENT_NAME") == "workflow_dispatch" and
            os.environ.get("GITHUB_REPOSITORY") == REPO and os.environ.get("GITHUB_REF") == REF,
            "Delivery allowed only on manual private-WIP hosted CI")
    require(re.fullmatch(r"[0-9a-f]{40}", os.environ.get("GITHUB_SHA", "")), "Invalid commit")
    for name in ("GITHUB_RUN_ID", "GITHUB_RUN_ATTEMPT"):
        require(os.environ.get(name, "").isdigit(), "Invalid run identity")
    directory = Path(os.environ["RUNNER_TEMP"]) / "bilga-debug-artifact"
    require(len(sys.argv) == 2 and sys.argv[1] in ("prepare", "publish"), "Use prepare or publish")
    (prepare if sys.argv[1] == "prepare" else publish)(directory)


if __name__ == "__main__":
    try:
        main()
    except (RuntimeError, OSError, ValueError, zipfile.BadZipFile) as error:
        print(f"Delivery STOP: {error}", file=sys.stderr)
        sys.exit(1)
