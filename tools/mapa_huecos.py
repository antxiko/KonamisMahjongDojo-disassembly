#!/usr/bin/env python3
"""Para CADA hueco sin explicar, quien lo apunta desde el codigo trazado.

Es refs.py aplicado en tanda a todos los huecos del presupuesto, para no ir
hueco por hueco a mano. Recorre SOLO inicios de instruccion del trazado: leer
desde mitad de una instruccion inventa punteros (ya paso en este proyecto, con
un barrido a lo bruto que dio 28 aciertos y los 28 eran ruido).

Uso: mapa_huecos.py <rom> <trace.json> <notes>
"""
import json
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from refs import busca                                # noqa: E402

ORG = 0x4000
TAM = 0x8000


def huecos(trace, notes):
    marca = bytearray(TAM)
    for k, a, b in trace["blocks"]:
        if k == "c":
            for i in range(a - ORG, b - ORG):
                marca[i] = 1
    for ln in open(notes, encoding="utf-8"):
        m = re.match(r"^D\s+(0x[0-9A-Fa-f]+)\s+(0x[0-9A-Fa-f]+)", ln)
        if m:
            for i in range(int(m.group(1), 16) - ORG, int(m.group(2), 16) - ORG):
                if 0 <= i < TAM:
                    marca[i] = 2
    out, ini = [], None
    for i in range(TAM):
        if marca[i] == 0 and ini is None:
            ini = i
        elif marca[i] and ini is not None:
            out.append((ORG + ini, ORG + i))
            ini = None
    if ini is not None:
        out.append((ORG + ini, ORG + TAM))
    return out


def main():
    rom = open(sys.argv[1], "rb").read()
    trace = json.load(open(sys.argv[2]))
    hs = huecos(trace, sys.argv[3])
    print("huecos: %d, %d bytes" % (len(hs), sum(b - a for a, b in hs)))
    for a, b in hs:
        r = busca(rom, trace, a, b)
        print("\n0x%04X..0x%04X  (%d bytes)" % (a, b - 1, b - a))
        if not r:
            print("     nadie lo apunta con un inmediato")
        for p, nm, v in r[:14]:
            print("     %04X  %-9s -> %04X" % (p, nm, v))
        if len(r) > 14:
            print("     ... y %d mas" % (len(r) - 14))
    return 0


if __name__ == "__main__":
    sys.exit(main())
