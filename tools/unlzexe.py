"""Decompress the load image of an LZEXE 0.91 packed DOS executable.

Only the code/data image is recovered (no relocations or new header), which
is enough to search the original program's data tables.

usage: unlzexe.py EXE-SOURCE OUT.bin
"""
import struct
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).parent))
import wolfdata


class Bits:
    def __init__(self, data, pos):
        self.data, self.pos = data, pos
        self.load()

    def load(self):
        self.buf = struct.unpack_from("<H", self.data, self.pos)[0]
        self.pos += 2
        self.count = 16

    def bit(self):
        b = self.buf & 1
        self.buf >>= 1
        self.count -= 1
        if self.count == 0:
            self.load()
        return b

    def byte(self):
        b = self.data[self.pos]
        self.pos += 1
        return b


def unpack(exe):
    if exe[0x1C:0x20] != b"LZ91":
        raise ValueError("not an LZEXE 0.91 executable")
    header_paras = struct.unpack_from("<H", exe, 8)[0]
    image = exe[header_paras * 16:]
    bits = Bits(image, 0)
    out = bytearray()
    while True:
        if bits.bit():
            out.append(bits.byte())
            continue
        if not bits.bit():
            length = bits.bit() * 2 + bits.bit() + 2
            span = bits.byte() - 0x100
        else:
            lo, hi = bits.byte(), bits.byte()
            span = lo | ((hi & 0xF8) << 5) | 0xE000
            span -= 0x10000
            length = hi & 7
            if length:
                length += 2
            else:
                length = bits.byte()
                if length == 0:
                    break
                if length == 1:
                    continue  # segment boundary marker
                length += 1
        for _ in range(length):
            out.append(out[len(out) + span])
    return bytes(out)


if __name__ == "__main__":
    data = unpack(wolfdata.read(sys.argv[1]))
    Path(sys.argv[2]).write_bytes(data)
    print(f"{len(data)} bytes")
