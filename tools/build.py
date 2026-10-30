"""Pack the AReyeP mod (this repo) as a .pk3, and the Wolf3D TC it plugs into
(tools/tcpath.py: $WOLF3D_TC or ../Wolf3D-TC-3.0) as the .ipk3 IWAD under it.

usage: build.py [SUFFIX]   e.g. "-test" -> run/Wolf3D-TC-test.ipk3, run/AReyeP-test.pk3
                           (default: run/Wolf3D-TC.ipk3, run/AReyeP.pk3)
"""
import sys
import zipfile
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
from tcpath import ROOT, TC

SKIP_DIRS = {".git", "tools", "docs", "run", "__pycache__", ".vscode"}
SKIP_FILES = {"README.md", ".gitignore", ".gitattributes"}


def pack(src, out):
    count = 0
    with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
        for p in sorted(src.rglob("*")):
            rel = p.relative_to(src)
            if not p.is_file() or rel.parts[0] in SKIP_DIRS or rel.name in SKIP_FILES or "__pycache__" in rel.parts:
                continue
            z.write(p, rel.as_posix())
            count += 1
    print(f"{out} ({count} files)")


def main():
    suffix = sys.argv[1] if len(sys.argv) > 1 else ""
    if not (TC / "Scripts/Extensions/GameExtension.zs").is_file():
        sys.exit(f"No Wolf3D TC with the game-extension hooks at {TC} (set WOLF3D_TC)")

    run = ROOT / "run"
    run.mkdir(exist_ok=True)
    pack(TC, run / f"Wolf3D-TC{suffix}.ipk3")
    pack(ROOT, run / f"AReyeP{suffix}.pk3")


if __name__ == "__main__":
    main()
