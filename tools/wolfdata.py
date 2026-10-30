"""Readers for Wolf3D/Spear-engine data files (MAPHEAD/GAMEMAPS, VSWAP).

Sources are plain paths or "archive.zip::member" references so the AReyeP
downloads can be read without unpacking them.
"""
import struct
import zipfile


def read(src):
    if "::" in src:
        archive, member = src.split("::", 1)
        with zipfile.ZipFile(archive) as z:
            names = {n.upper(): n for n in z.namelist()}
            return z.read(names[member.upper()])
    with open(src, "rb") as f:
        return f.read()


def carmack_expand(src, length):
    out = []
    i = 0
    words = length // 2
    while len(out) < words:
        ch = struct.unpack_from("<H", src, i)[0]
        i += 2
        hi = ch >> 8
        count = ch & 0xFF
        if hi == 0xA7:  # near pointer
            if count == 0:
                out.append((ch & 0xFF00) | src[i]); i += 1
            else:
                off = src[i]; i += 1
                base = len(out) - off
                for k in range(count):
                    out.append(out[base + k])
        elif hi == 0xA8:  # far pointer
            if count == 0:
                out.append((ch & 0xFF00) | src[i]); i += 1
            else:
                off = struct.unpack_from("<H", src, i)[0]; i += 2
                for k in range(count):
                    out.append(out[off + k])
        else:
            out.append(ch)
    return out


def rlew_expand(words, rlewtag):
    out = []
    i = 1  # first word is the expanded byte length
    while i < len(words):
        w = words[i]
        if w == rlewtag:
            count, value = words[i + 1], words[i + 2]
            out.extend([value] * count)
            i += 3
        else:
            out.append(w)
            i += 1
    return out


class Map:
    def __init__(self, index, name, width, height, planes):
        self.index, self.name, self.width, self.height, self.planes = index, name, width, height, planes


def read_maps(maphead, gamemaps, carmack=True):
    rlew = struct.unpack_from("<H", maphead, 0)[0]
    count = (len(maphead) - 2) // 4
    offsets = struct.unpack_from("<%dI" % count, maphead, 2)
    maps = []
    for idx, off in enumerate(offsets):
        if off in (0, 0xFFFFFFFF) or off + 38 > len(gamemaps):
            continue
        pofs = struct.unpack_from("<3I", gamemaps, off)
        plen = struct.unpack_from("<3H", gamemaps, off + 12)
        w, h = struct.unpack_from("<2H", gamemaps, off + 18)
        name = gamemaps[off + 22:off + 38].split(b"\0")[0].decode("latin1").strip()
        planes = []
        for p in range(3):
            if not plen[p]:
                planes.append([]); continue
            raw = gamemaps[pofs[p]:pofs[p] + plen[p]]
            # Editors like MapEdit write RLEW-only planes: the first word is then
            # already the final byte size instead of the Carmack length.
            if carmack and struct.unpack_from("<H", raw, 0)[0] != w * h * 2:
                exp_len = struct.unpack_from("<H", raw, 0)[0]
                words = carmack_expand(raw[2:], exp_len)
            else:
                words = list(struct.unpack_from("<%dH" % (len(raw) // 2), raw))
            planes.append(rlew_expand(words, rlew)[: w * h])
        maps.append(Map(idx, name, w, h, planes))
    return maps


class VSwap:
    def __init__(self, data):
        self.data = data
        self.chunks, self.sprite_start, self.sound_start = struct.unpack_from("<3H", data, 0)
        self.offsets = struct.unpack_from("<%dI" % self.chunks, data, 6)
        self.lengths = struct.unpack_from("<%dH" % self.chunks, data, 6 + 4 * self.chunks)

    def chunk(self, i):
        return self.data[self.offsets[i]:self.offsets[i] + self.lengths[i]]

    def wall(self, i):
        """64x64 column-major palette indices."""
        return self.chunk(i)

    def sprite(self, i):
        """Return 64x64 list of palette indices or None for transparent."""
        c = self.chunk(self.sprite_start + i)
        if not c:
            return None
        px = [[None] * 64 for _ in range(64)]
        left, right = struct.unpack_from("<2H", c, 0)
        cmds = struct.unpack_from("<%dH" % (right - left + 1), c, 4)
        for col, cmd in zip(range(left, right + 1), cmds):
            p = cmd
            while True:
                end = struct.unpack_from("<H", c, p)[0]
                if end == 0:
                    break
                src = struct.unpack_from("<h", c, p + 2)[0]
                start = struct.unpack_from("<H", c, p + 4)[0]
                for y in range(start // 2, end // 2):
                    px[y][col] = c[src + y]
                p += 6
        return px
