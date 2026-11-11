"""Disable ambiguous upload retries in the pinned BigWigs v2.7.0 script.

Only the temporary publisher copy is changed. Packaging and metadata generation
remain upstream; a failed CurseForge POST requires inspection before recovery.
"""

from pathlib import Path
import sys


def prepare(source):
    start = source.index("\nupload_curseforge() {")
    end = source.index("\nupload_wowinterface() {", start)
    upload = source[start:end]
    curl = "curl -sS --retry 3 --retry-delay 10"
    wrapper = "if ! retry upload_curseforge; then"
    if upload.count(curl) != 1 or source.count(wrapper) != 1:
        raise ValueError("Unexpected BigWigs uploader; review the pinned version before publishing")
    upload = upload.replace(curl, "curl -sS --max-time 120")
    return (source[:start] + upload + source[end:]).replace(wrapper, "if ! upload_curseforge; then")


if __name__ == "__main__":
    path = Path(sys.argv[1])
    path.write_text(prepare(path.read_text()))
