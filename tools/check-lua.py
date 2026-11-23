"""Run the Lua fixtures and syntax-check all runtime Lua under Lua 5.1."""

import argparse
from pathlib import Path
import shutil
import subprocess


ROOT = Path(__file__).resolve().parents[1]


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--lua", default=shutil.which("lua5.1") or "lua",
                        help="path to a Lua 5.1 interpreter")
    args = parser.parse_args()
    if not shutil.which(args.lua):
        parser.error(f"Lua executable not found: {args.lua}")

    def run(*arguments, **options):
        subprocess.run([args.lua, *arguments], cwd=ROOT, check=True, **options)

    try:
        run("-e", 'assert(_VERSION == "Lua 5.1", "QuestChain checks require Lua 5.1")')
        sources = sorted((ROOT / "ForeverQuestChain").rglob("*.lua"))
        run("-", *(str(source.relative_to(ROOT)) for source in sources),
            input="for _, path in ipairs(arg) do assert(loadfile(path)) end", text=True)
        for fixture in sorted((ROOT / "tests").glob("*.lua")):
            print(f"Testing {fixture.relative_to(ROOT)}", flush=True)
            run(str(fixture))
    except subprocess.CalledProcessError as error:
        return error.returncode
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
