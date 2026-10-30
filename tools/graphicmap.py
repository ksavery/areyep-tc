"""Read the Sprites/Textures lists of a TC GraphicMaps file.

Each list entry is either a bare name ("POL1A0";) or a numbered block holding
one or more names, each optionally followed by a { Flag; } block. Entries are
positional: the Nth entry is VSWAP sprite N.

usage: graphicmap.py FILE [Sprites|Textures] [first last]   (prints index: names)
"""
import re
import sys


def tokens(text):
    text = re.sub(r"//[^\n]*", "", text)
    return re.findall(r'"[^"]*"|[{};=]|[^\s{};="]+', text)


def read_list(path, section="Sprites"):
    """Return [[(name, [flags]), ...], ...] indexed by VSWAP sprite/wall number."""
    toks = tokens(open(path).read())
    i = toks.index(section) + 2  # skip section name and "{"
    entries = []
    while toks[i] != "}":
        t = toks[i]
        if t.startswith('"'):
            entries.append([(t.strip('"'), [])])
            i += 2  # name ;
        else:  # numbered block
            i += 2  # number {
            names = []
            while toks[i] != "}":
                name, flags = toks[i].strip('"'), []
                i += 1
                if toks[i] == "{":
                    i += 1
                    while toks[i] != "}":
                        if toks[i] != ";":
                            flags.append(toks[i])
                        i += 1
                    i += 1
                elif toks[i] == ";":
                    i += 1
                names.append((name, flags))
            entries.append(names)
            i += 1
    return entries


if __name__ == "__main__":
    path = sys.argv[1]
    section = sys.argv[2] if len(sys.argv) > 2 else "Sprites"
    entries = read_list(path, section)
    first = int(sys.argv[3]) if len(sys.argv) > 3 else 0
    last = int(sys.argv[4]) if len(sys.argv) > 4 else len(entries) - 1
    for n in range(first, min(last, len(entries) - 1) + 1):
        print(n, " ".join(name + ("{%s}" % ",".join(f) if f else "") for name, f in entries[n]))
