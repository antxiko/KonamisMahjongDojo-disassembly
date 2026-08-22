#!/usr/bin/env python3
"""Caza los dos fallos que se pierden en SILENCIO al anotar un listado.

Un comentario `C` mal anclado -a media instruccion, o a una direccion que el
trazado dio por datos- no da error: simplemente no sale en el listado. Y un `C`
repetido para la misma direccion tampoco: gana uno y el otro se evapora. En las
dos formas de perderlo, el trabajo esta hecho y no se ve.

Uso: valida_notas.py <notes> <asm>
Sale con 1 si encuentra algo.
"""
import re
import sys


def main():
    notes, asm = sys.argv[1], sys.argv[2]

    en_notas, repes = {}, []
    for n, ln in enumerate(open(notes, encoding="utf-8"), 1):
        m = re.match(r"^C (0x[0-9A-Fa-f]{4})\s", ln)
        if not m:
            continue
        a = int(m.group(1), 16)
        if a in en_notas:
            repes.append((a, en_notas[a], n))
        else:
            en_notas[a] = n

    en_asm = set()
    for ln in open(asm, encoding="utf-8"):
        m = re.match(r"^\t.*;([0-9a-f]{4})", ln)
        if m:
            en_asm.add(int(m.group(1), 16))

    huerfanos = sorted(set(en_notas) - en_asm)

    for a in huerfanos:
        print("  HUERFANO  0x%04X  (notes:%d) no cae en ninguna instruccion"
              % (a, en_notas[a]))
    for a, p, s in repes:
        print("  REPETIDO  0x%04X  (notes:%d y notes:%d)" % (a, p, s))

    print("  ---- %d comentarios, %d huerfanos, %d repetidos"
          % (len(en_notas) + len(repes), len(huerfanos), len(repes)))
    sys.exit(1 if huerfanos or repes else 0)


main()
