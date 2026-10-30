"""Where the Wolf3D TC this mod plugs into is checked out.

$WOLF3D_TC, else Wolf3D-TC-3.0 next to this repo (a clone of
github.com/AFADoomer/Wolf3D-TC-3.0).
"""
import os
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
TC = Path(os.environ.get("WOLF3D_TC", ROOT.parent / "Wolf3D-TC-3.0")).resolve()
