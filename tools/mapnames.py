"""Print a mapset's map names, spaces as underscores (areyep_startmap form).

usage: mapnames.py MAPHEAD GAMEMAPS
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import wolfdata

for m in wolfdata.read_maps(wolfdata.read(sys.argv[1]), wolfdata.read(sys.argv[2])):
    print(m.name.replace(" ", "_"))
