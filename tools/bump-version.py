"""Choose a release version and update only the source TOC's Version field."""

import argparse
from pathlib import Path
import re


NUMBER = r"(0|[1-9][0-9]*)"
VERSION = re.compile(rf"{NUMBER}\.{NUMBER}\.{NUMBER}(?:-beta\.{NUMBER})?")
TOC_VERSION = re.compile(rb"(?m)^(## Version:[ \t]*)([^\r\n]+)")


def parse_version(value):
    match = VERSION.fullmatch(value)
    if not match:
        raise ValueError("Use major.minor.patch or major.minor.patch-beta.N, without a v prefix")
    major, minor, patch, beta = match.groups()
    return int(major), int(minor), int(patch), int(beta is None), int(beta or 0)


def next_version(current, kind, exact=None):
    previous = parse_version(current)
    if kind == "exact":
        if not exact:
            raise ValueError("An exact version is required when bump is exact")
        candidate = exact
    else:
        if exact:
            raise ValueError("An exact version can only be supplied with bump=exact")
        if not previous[3]:
            raise ValueError("Use an exact version to advance or promote a beta")
        major, minor, patch = previous[:3]
        if kind == "patch":
            candidate = f"{major}.{minor}.{patch + 1}"
        elif kind == "minor":
            candidate = f"{major}.{minor + 1}.0"
        else:
            raise ValueError("Choose patch, minor, or exact")
    if parse_version(candidate) <= previous:
        raise ValueError(f"Release version must be greater than {current}")
    return candidate


def update_toc(source, kind, exact=None):
    matches = list(TOC_VERSION.finditer(source))
    if len(matches) != 1:
        raise ValueError("The source TOC must have exactly one Version field")
    match = matches[0]
    version = next_version(match[2].decode("ascii"), kind, exact)
    return source[:match.start(2)] + version.encode("ascii") + source[match.end(2):], version


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("kind", choices=("patch", "minor", "exact"))
    parser.add_argument("--version")
    parser.add_argument("--toc", type=Path, default=Path("ForeverQuestChain/ForeverQuestChain.toc"))
    args = parser.parse_args()
    try:
        data, version = update_toc(args.toc.read_bytes(), args.kind, args.version or None)
        args.toc.write_bytes(data)
        print(version)
    except (ValueError, OSError) as error:
        parser.error(str(error))
