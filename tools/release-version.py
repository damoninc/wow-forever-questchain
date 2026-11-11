"""Allocate a stable patch tag for a main commit; retries keep its existing tag."""

import re
import subprocess


STABLE = re.compile(r"v(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)\.(0|[1-9][0-9]*)")


def stable_version(tag):
    match = STABLE.fullmatch(tag)
    return tuple(map(int, match.groups())) if match else None


def release_tag(tags, head_tags):
    existing = [tag for tag in head_tags if stable_version(tag) is not None]
    if len(existing) > 1:
        raise ValueError("This source commit has multiple stable versions; refusing ambiguous publication")
    if existing:
        return existing[0]
    versions = [stable_version(tag) for tag in tags]
    versions = [version for version in versions if version is not None]
    if not versions:
        return "v1.0.0"
    major, minor, patch = max(versions)
    return f"v{major}.{minor}.{patch + 1}"


def allocate_release(repo="."):
    def git_tags(*args):
        return subprocess.check_output(["git", "-C", str(repo), "tag", *args], text=True).splitlines()
    tags, head_tags = git_tags(), git_tags("--points-at", "HEAD")
    chosen = release_tag(tags, head_tags)
    if chosen not in head_tags:
        stable_tags = [tag for tag in tags if stable_version(tag) is not None]
        if stable_tags:
            latest = max(stable_tags, key=stable_version)
            result = subprocess.run(["git", "-C", str(repo), "merge-base", "--is-ancestor", latest, "HEAD"])
            if result.returncode == 1:
                raise ValueError(f"Refusing to release older or unrelated source than {latest}; use the latest main deployment")
            result.check_returncode()
    return chosen


if __name__ == "__main__":
    print(allocate_release())
