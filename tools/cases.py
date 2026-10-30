"""Print the handlers of a DOS switch statement, one case per block.

Given an unpacked image (tools/unlzexe.py), the code segment base and the
jump table offset, disassembles each case target up to the next jump to the
switch's exit (or a return) with objdump, so pickup logic can be read off.

usage: cases.py IMAGE CSBASE TABLEOFF COUNT EXIT [FIRSTCASE]
   e.g. cases.py sr-edit.bin 0x11cf0 0xafa 31 0x127d8 2   (SR GetBonus)
"""
import struct
import subprocess
import sys


def disasm(image, start, stop):
    out = subprocess.run(["objdump", "-D", "-b", "binary", "-m", "i8086",
                          "--start-address=%#x" % start, "--stop-address=%#x" % stop, image],
                         capture_output=True, text=True).stdout
    for line in out.splitlines():
        parts = line.split("\t")
        if len(parts) >= 3 and parts[0].strip().endswith(":"):
            yield int(parts[0].strip()[:-1], 16), " ".join(parts[2].split())


def main():
    image, base, table, count, exit_ = sys.argv[1], *(int(a, 0) for a in sys.argv[2:6])
    first = int(sys.argv[6], 0) if len(sys.argv) > 6 else 0
    data = open(image, "rb").read()
    targets = [base + struct.unpack_from("<H", data, base + table + 2 * i)[0] for i in range(count)]
    for i, t in enumerate(targets):
        body = []
        for addr, ins in disasm(image, t, t + 0x80):
            body.append(ins)
            if ins in ("lret", "ret") or ins == "jmp %#x" % exit_:
                break
        print(f"case {i + first} @{t:#x}: " + "; ".join(body))


if __name__ == "__main__":
    main()
