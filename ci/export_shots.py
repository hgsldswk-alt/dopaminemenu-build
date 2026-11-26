"""Export canonical filenames from xcresult attachment metadata."""
import json
from pathlib import Path
import re
import shutil
import subprocess
import sys
import tempfile

LANGUAGES = ("en", "zh-Hans", "zh-Hant")
SCENES = ("01-home", "02-timer", "03-editor", "04-widgets", "05-share")
EXPECTED = {f"store-{lang}-{scene}" for lang in LANGUAGES for scene in SCENES} | {"paid-01-paywall"}
NAME = re.compile(r"(store-(?:en|zh-Hans|zh-Hant)-\d{2}-[a-z]+|paid-01-paywall)(?=[_.\s-]|$)")


def copy_shots(source, dest):
    manifest = json.loads((source / "manifest.json").read_text(encoding="utf-8"))
    seen = {}
    for test in manifest:
        for attachment in test["attachments"]:
            name = attachment["suggestedHumanReadableName"]
            match = NAME.search(name)
            if match is None:
                continue
            key = match.group(1)
            original = source / Path(attachment["exportedFileName"]).name
            if key not in EXPECTED or not original.is_file():
                continue
            if original.read_bytes()[:8] != b"\x89PNG\r\n\x1a\n":
                continue
            seen[key] = original
    missing = EXPECTED - seen.keys()
    if missing:
        raise ValueError("Missing screenshot attachments: " + ", ".join(sorted(missing)))
    dest.mkdir(parents=True, exist_ok=True)
    for key, source_file in seen.items():
        shutil.copy2(source_file, dest / f"{key}.png")


def main():
    xcresult, build_folder = map(Path, sys.argv[1:3])
    build_folder.mkdir(parents=True, exist_ok=True)
    with tempfile.TemporaryDirectory(prefix="attachments-", dir=build_folder) as extracted:
        subprocess.run(["xcrun", "xcresulttool", "export", "attachments", "--path", str(xcresult),
                        "--output-path", extracted], check=True)
        copy_shots(Path(extracted), build_folder)
    print(f"Exported {len(EXPECTED)} screenshots to {build_folder}")


if __name__ == "__main__":
    main()
