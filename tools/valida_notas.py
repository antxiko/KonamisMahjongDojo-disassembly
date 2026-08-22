#!/usr/bin/env python3
"""Caza los tres fallos que se pierden en SILENCIO al anotar un listado.

Un comentario `C` mal anclado -a media instruccion, o a una direccion que el
trazado dio por datos- no da error: simplemente no sale en el listado. Y un `C`
repetido para la misma direccion tampoco: gana uno y el otro se evapora. En las
dos formas de perderlo, el trabajo esta hecho y no se ve.

Y un tercero, que muerde por dos sitios: una etiqueta `L` con un caracter que no
sea ASCII. Pasmo no la ensambla -"Unexpected character"- y, mas callado todavia,
densidad.py deja de reconocerla como bloque y CUENTA UNA RUTINA MENOS. Una sola
eñe se llevo por delante el reensamblado y una entrada del recuento a la vez.

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

    raras = []
    for n, ln in enumerate(open(notes, encoding="utf-8"), 1):
        if ln.startswith("L 0x") and not ln.isascii():
            raras.append((n, ln.rstrip()))

    for a in huerfanos:
        print("  HUERFANO  0x%04X  (notes:%d) no cae en ninguna instruccion"
              % (a, en_notas[a]))
    for a, p, s in repes:
        print("  REPETIDO  0x%04X  (notes:%d y notes:%d)" % (a, p, s))
    for n, ln in raras:
        print("  NO ASCII  notes:%d  %s" % (n, ln))
        print("            pasmo no lo ensambla y densidad.py no lo cuenta")

    print("  ---- %d comentarios, %d huerfanos, %d repetidos, %d etiquetas no ASCII"
          % (len(en_notas) + len(repes), len(huerfanos), len(repes), len(raras)))
    sys.exit(1 if huerfanos or repes or raras else 0)


main()
