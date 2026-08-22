#!/usr/bin/env python3
"""Descomprime un bloque de formato B a un fichero, o lo pinta como patrones.

Sin esto no se pueden leer los rotulos japoneses: los nombres de las jugadas
van en numeros de tile de una fuente que solo existe COMPRIMIDA en la ROM, asi
que hay que descomprimirla y dibujarla para saber que dice cada uno.

Uso: descomprime.py <rom> <direccion> [--patrones N] [--salida fichero]
"""
import sys

ORG = 0x4000


def desc(d, a):
    """Devuelve (destino_vram, bytes) del primer tramo del bloque."""
    p = a - ORG
    de = d[p] | (d[p + 1] << 8)
    p += 2
    out = bytearray()
    while True:
        n = d[p]
        p += 1
        if n == 0x00:
            return de, bytes(out), ORG + p
        if n == 0x80:
            return de, bytes(out), ORG + p          # solo el primer destino
        if n & 0x80:
            k = n & 0x7F
            out += d[p:p + k]
            p += k
        else:
            out += bytes([d[p]]) * n
            p += 1


def main():
    d = open(sys.argv[1], "rb").read()
    a = int(sys.argv[2], 0)
    de, bs, fin = desc(d, a)
    sys.stderr.write("destino VRAM 0x%04X, %d bytes, el bloque sigue en 0x%04X\n"
                     % (de, len(bs), fin))
    if "--salida" in sys.argv:
        open(sys.argv[sys.argv.index("--salida") + 1], "wb").write(bs)
    return 0


if __name__ == "__main__":
    sys.exit(main())
