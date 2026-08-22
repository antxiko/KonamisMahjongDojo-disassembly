#!/usr/bin/env python3
"""Empareja cada `ld hl,NNNN` con el interprete de listas que lo consume.

Recorre el listado ya generado y, para cada llamada a 0x4099/0x409D (formato A)
o 0x468F (formato B), busca hacia atras el ultimo `ld hl,NNNN` que la alimenta.
Asi cada bloque de datos queda emparejado con SU interprete, que es lo que dice
donde acaba.

Uso: quien_pinta.py <listado.asm>
"""
import re
import sys

RE_LD = re.compile(r"^\s*ld hl,0([0-9a-f]{4})h\s*;([0-9a-f]{4})")
RE_LDL = re.compile(r"^\s*ld hl,L_([0-9A-F]{4})\s*;([0-9a-f]{4})")
RE_CALL = re.compile(r"^\s*(?:call|jp)(?: [a-z]+,)?\s*L_(4099|409D|468F)\s*;([0-9a-f]{4})")


def main():
    ult = None
    out = []
    for ln in open(sys.argv[1], encoding="utf-8"):
        m = RE_LD.match(ln) or RE_LDL.match(ln)
        if m:
            ult = (int(m.group(1), 16), int(m.group(2), 16))
            continue
        m = RE_CALL.match(ln)
        if m and ult:
            out.append((ult[0], "A" if m.group(1) != "468F" else "B",
                        int(m.group(2), 16), ult[1]))
    vistos = {}
    for base, fmt, pc, ldpc in sorted(out):
        vistos.setdefault((base, fmt), []).append((pc, ldpc))
    for (base, fmt), usos in sorted(vistos.items()):
        print("0x%04X  formato %s   desde %s"
              % (base, fmt, ", ".join("0x%04X" % p for p, _ in usos)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
