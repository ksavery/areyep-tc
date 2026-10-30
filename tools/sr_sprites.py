"""Spear Resurrection VSWAP sprite layout -> sprite names the TC draws them into.

SR keeps Spear of Destiny's sprite positions for everything it inherited (so
those pages are drawn onto the TC's standard Spear names and the stock actor
classes show SR art), renames the dog slot to the suicide clone, and appends
its own objects. Identified from contact sheets (tools/sheet.py) against
AReyeP's MapEdit names (their OBJDATA file, kept locally in docs/reference/) and eod4sdl's sprite
enum, which EoD inherited from SR.
"""

# VSWAP ranges that sit at the same position as in Spear (Data/GraphicMaps/SD1.txt)
POSITIONAL = [
    (0, 102),    # demo/deathcam, statics 23-74, guard
    (142, 306),  # SS, clone (mutant slot), officer, rockets/smoke
    (326, 376),  # Grau Adler, Hiroshima Hyoto, Superclone, Baron von Schmitt
    (385, 420),  # Angel of Death slot, player knife/pistol/MG/Mk3
]

# Spear's dog slot holds the suicide clone: same frame layout, new sprite name
RENAMED = [
    (103, 141, "WDOG", "SCLN"),
]

# SR-only sprites: name -> VSWAP indices for frames A, B, C...
EXTRA = {
    "SRMK": [421, 422, 423, 424, 425],  # Mk4 ready + attack
    "SRM4": [426],        # Mk4 pickup
    "SRKB": [427],        # blood key
    "SRKE": [428],        # elevator key
    "SRLM": [429],        # landmine
    "SRCD": [430],        # broken column (dead)
    "SRA2": [431],        # ammo 2 clip
    "SRSC": [432],        # stone column
    "SRBT": [433],        # chopping table
    "SRBD": [434],        # black diamond
    "SRR1": [435],        # small rocks 1
    "SRR2": [436],        # small rocks 2
    "SRBS": [437],        # bloody skeleton
    "SRGR": [438, 439],   # Grim Reaper
    "SRBL": [440, 441],   # blue blinking light
    "SRGH": [442, 443],   # yellow ghost
    "SRHP": [444],        # hanging plant
    "SRHS": [445],        # Hitler pedestal
    "SRXB": [446, 447, 448, 449, 450],  # exploding drum, explosion, remains
    "SRTO": [451, 452, 453, 454],       # outdoor torch
    "SRAG": [455, 456, 457],            # angel ghost
    "SRTI": [458, 459, 460, 461],       # indoor torch
    "SRC2": [462],        # ammo 2 crate
    "SRCB": [463, 464, 465, 466],       # breakable column
    "SRG1": [473, 474],   # ghost 01 (Hans)
    "SRG2": [475, 476],   # ghost 02 (Gretel)
    "SRG3": [471, 472],   # ghost 03 (Schabbs)
    "SRG4": [467, 468],   # ghost 04 (Fatface)
    "SRG5": [469, 470],   # ghost 05 (Wilhelm)
    "SRG6": [477, 478],   # ghost 06 (Trans)
    "SRPD": [479, 480],   # plain pedestal, pedestal with pot
    "SRDK": [481],        # desk with typewriter
    "SRBN": [482],        # swastika banner
    "SRDT": [483],        # dead tree
    "SRWL": [484, 503],   # well full, well empty
    "SRRS": [485],        # small rocks/skulls
    "SRB3": [486],        # outdoor bones 3
    "SRSK": [487, 488],   # white skull, pink skull
    "SRSL": [489],        # green slime
    "SRTP": [490],        # teleport artefact / fake teleport
    "SRPB": [491, 492, 493, 494, 495, 496],  # boss pedestals Hans..Trans
    "SRPE": [497, 498, 378, 377, 380, 379],  # empty pedestals Hans..Trans
    "SRB1": [499, 500],   # outdoor bones 1, 2
    "SRRD": [504],        # rusty old drum
    "SRBX": [505],        # boxes on floor
    "SRPU": [506],        # black puddle
    "SRPI": [509],        # pistol pickup
    "SRBB": [381, 382],   # berry bush good (+10), bad (-16)
    "SRGM": [383],        # God Mode artefact
    "SROA": [384],        # outdoor ammo clip
}

# Per-sprite GraphicMap flags (player weapon frames must not get the shadow mask)
EXTRA_FLAGS = {
    "SRMK": ["NoShadowMask"],
}
