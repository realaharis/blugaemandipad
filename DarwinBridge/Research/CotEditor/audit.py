#!/usr/bin/env python3
"""Read-only official CotEditor DMG Mach-O inventory. No binaries in output."""
import argparse
import hashlib
import json
import os
import plistlib
import subprocess
import tempfile
import urllib.request
from pathlib import Path

URL = "https://github.com/coteditor/CotEditor/releases/download/7.1.1/CotEditor_7.1.1.dmg"
EXPECTED_SIZE = 26594816

def run(*args):
    p = subprocess.run(args, text=True, stdout=subprocess.PIPE, stderr=subprocess.PIPE)
    if p.returncode:
        raise RuntimeError(f"{' '.join(args)}: {p.stderr[-3000:]}")
    return p.stdout

def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--output", type=Path, required=True)
    args = ap.parse_args()
    report = {"target": "CotEditor", "version": "7.1.1", "url": URL,
              "status": "INCOMPLETE", "ipad_execution": "NOT_TESTED"}
    try:
        with tempfile.TemporaryDirectory() as temp:
            base = Path(temp)
            dmg = base / "CotEditor.dmg"
            urllib.request.urlretrieve(URL, dmg)
            data = dmg.read_bytes()
            report["dmg_size"] = len(data)
            report["dmg_sha256"] = hashlib.sha256(data).hexdigest()
            if len(data) != EXPECTED_SIZE:
                raise RuntimeError("Official DMG size differs from pinned release metadata")
            mount = base / "mounted"
            mount.mkdir()
            attached = False
            try:
                run("hdiutil", "attach", "-readonly", "-nobrowse", "-mountpoint", str(mount), str(dmg))
                attached = True
                apps = sorted(mount.rglob("CotEditor.app"))
                if len(apps) != 1:
                    raise RuntimeError(f"Expected one CotEditor.app; found {len(apps)}")
                app = apps[0]
                info = plistlib.loads((app / "Contents/Info.plist").read_bytes())
                name = info.get("CFBundleExecutable")
                if not name:
                    raise RuntimeError("Missing CFBundleExecutable")
                binary = app / "Contents/MacOS" / name
                if not binary.is_file():
                    raise RuntimeError("Executable missing")
                report["bundle"] = {
                    "identifier": info.get("CFBundleIdentifier"),
                    "version": info.get("CFBundleShortVersionString"),
                    "executable": name,
                    "min_system_version": info.get("LSMinimumSystemVersion")
                }
                report["executable_sha256"] = hashlib.sha256(binary.read_bytes()).hexdigest()
                report["file"] = run("file", str(binary))
                report["architectures"] = run("lipo", "-archs", str(binary)).strip()
                report["load_commands"] = run("otool", "-l", str(binary))
                report["linked_libraries"] = run("otool", "-L", str(binary))
                report["undefined_symbols"] = run("nm", "-u", str(binary)) if os.environ.get("AUDIT_SYMBOLS") == "1" else "omitted (set AUDIT_SYMBOLS=1)"
                report["status"] = "STATIC_AUDIT_COMPLETE"
            finally:
                if attached:
                    run("hdiutil", "detach", str(mount))
    except Exception as e:
        report["error"] = str(e)
        report["status"] = "FAILED"
    args.output.parent.mkdir(parents=True, exist_ok=True)
    args.output.write_text(json.dumps(report, indent=2) + "\n")
    print(json.dumps({k:v for k,v in report.items() if k not in ("load_commands","linked_libraries","file")}, indent=2))
    if report["status"] != "STATIC_AUDIT_COMPLETE":
        raise SystemExit(1)

if __name__ == "__main__":
    main()
