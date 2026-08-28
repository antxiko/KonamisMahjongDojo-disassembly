#!/usr/bin/env python3
"""Aplica una tanda de notas: sustituye lineas D por su version nueva y
concatena el fichero de la tanda. Verifica el conteo antes y despues, y no
escribe si algo no cuadra.

Uso: aplica.py <notes> <tanda> [<sustituciones.txt>]

El fichero de sustituciones lleva pares de lineas: la vieja y la nueva,
separadas por una linea con solo ###.
"""
import sys


def main():
    notes, tanda = sys.argv[1], sys.argv[2]
    subs = sys.argv[3] if len(sys.argv) > 3 else None

    with open(notes, encoding="utf-8") as f:
        s = f.read()
    d_antes = s.count("\nD 0x") + (1 if s.startswith("D 0x") else 0)
    n_antes = len(s.splitlines())

    if subs:
        with open(subs, encoding="utf-8") as f:
            trozos = f.read().split("\n###\n")
        for t in trozos:
            if not t.strip():
                continue
            viejo, nuevo = t.split("\n@@@\n")
            viejo, nuevo = viejo.strip("\n"), nuevo.strip("\n")
            if s.count(viejo) != 1:
                sys.exit("ABORTA: la linea vieja aparece %d veces, no 1:\n  %s"
                         % (s.count(viejo), viejo[:90]))
            s = s.replace(viejo, nuevo)

    with open(tanda, encoding="utf-8") as f:
        extra = f.read()
    if not s.endswith("\n"):
        s += "\n"
    s += extra

    d_desp = s.count("\nD 0x") + (1 if s.startswith("D 0x") else 0)
    if d_desp < d_antes:
        sys.exit("ABORTA: se perderian directivas D (%d -> %d)" % (d_antes, d_desp))

    with open(notes, "w", encoding="utf-8", newline="\n") as f:
        f.write(s)

    with open(notes, encoding="utf-8") as f:
        v = f.read()
    if v != s:
        sys.exit("ABORTA: lo escrito no coincide con lo que se queria escribir")
    print("OK  lineas %d -> %d   D %d -> %d   C %d"
          % (n_antes, len(v.splitlines()), d_antes, d_desp,
             sum(1 for l in v.splitlines() if l.startswith("C 0x"))))


main()
