#!/usr/bin/env python3
"""Recorre una lista de rotulos con el formato que lee 0x462C y dice donde acaba.

El formato: la direccion de VRAM en dos bytes con el ALTO delante, luego los
caracteres tal cual; 0x1F es "repetir" y detras van cuantos y cual; 0x0F cierra
el trozo y detras viene la direccion del siguiente, y dos 0x0F seguidos cierran
la lista.

Asi las fronteras de los bloques de rotulos salen medidas, no a ojo.

Uso: rotulos.py <rom> <org> <ini> [<ini> ...]
"""
import sys


def una(rom, org, ini):
    i = ini - org
    trozos = []
    while True:
        vram = (rom[i] << 8) | rom[i + 1]
        i += 2
        n, rep = 0, 0
        while True:
            b = rom[i]
            if b == 0x1F:
                rep += rom[i + 1]
                i += 3
                continue
            if b == 0x0F:
                i += 1
                break
            n += 1
            i += 1
        trozos.append((vram, n, rep))
        if rom[i] == 0x0F:
            i += 1
            break
    return trozos, org + i


def main():
    rom = open(sys.argv[1], 'rb').read()
    org = int(sys.argv[2], 16)
    for arg in sys.argv[3:]:
        ini = int(arg, 16)
        trozos, fin = una(rom, org, ini)
        print("0x%04X-0x%04X  (%d B, %d trozos)" % (ini, fin - 1, fin - ini, len(trozos)))
        for vram, n, rep in trozos:
            nom = vram & 0x3FFF
            fila, col = divmod(nom - 0x3800, 32) if nom >= 0x3800 else (-1, -1)
            print("    VRAM 0x%04X  fila %2d col %2d   %d sueltos + %d repetidos"
                  % (nom, fila, col, n, rep))


main()
