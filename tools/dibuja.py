#!/usr/bin/env python3
"""Dibuja un tramo de la ROM como patrones de 8x8, en el terminal.

En esta serie, mirar los bytes no basta: en Super Cobra, renderizar un bloque
destapo que los "tiles del menu" eran en realidad los sprites. Esto es lo mismo
pero sin salir de la consola: cada 8 bytes son una fila de 8 pixeles, y se
pintan N patrones por linea, uno al lado del otro.

Uso: dibuja.py <rom> <ini_hex> <n_patrones> [por_fila=8]
"""
import sys

ORG = 0x4000


def main():
    rom = open(sys.argv[1], "rb").read()
    ini = int(sys.argv[2], 0)
    n = int(sys.argv[3], 0)
    ancho = int(sys.argv[4], 0) if len(sys.argv) > 4 else 8

    for base in range(0, n, ancho):
        grupo = range(base, min(base + ancho, n))
        print("  " + "  ".join("%04X    " % (ini + 8 * i) for i in grupo))
        for fila in range(8):
            linea = []
            for i in grupo:
                b = rom[ini - ORG + 8 * i + fila]
                linea.append("".join("#" if b & (0x80 >> k) else "." for k in range(8)))
            print("  " + "  ".join(linea))
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
