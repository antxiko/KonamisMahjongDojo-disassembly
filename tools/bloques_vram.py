#!/usr/bin/env python3
"""Recorre los bloques con cabecera que sube 0x4956 y dice donde acaba cada uno.

Formato de cada bloque: dos bytes con la direccion de VRAM -el ALTO delante-,
un byte con cuantos van, y detras los datos. La rutina repite eso B veces.
Un tamano de 0 significa 256.

Uso: bloques_vram.py <rom> <org> <ini> <cuantos>
"""
import sys


def main():
    rom = open(sys.argv[1], 'rb').read()
    org = int(sys.argv[2], 16)
    i = int(sys.argv[3], 16) - org
    n = int(sys.argv[4])
    ini = org + i
    for k in range(n):
        a = org + i
        vram = ((rom[i] << 8) | rom[i + 1]) & 0x3FFF
        cuantos = rom[i + 2] or 256
        i += 3 + cuantos
        zona = ("nombres, fila %d col %d" % divmod(vram - 0x3800, 32)) if vram >= 0x3800 else \
               ("patrones de sprite, dibujo %d" % ((vram - 0x1800) // 8)) if 0x1800 <= vram < 0x2000 else \
               ("patrones, caracter 0x%02X" % (((vram - 0x2000) % 0x800) // 8)) if vram >= 0x2000 else \
               ("color, caracter 0x%02X" % ((vram % 0x800) // 8))
        print("  0x%04X  ->  VRAM 0x%04X  %4d B   %s" % (a, vram, cuantos, zona))
    print("  ---- 0x%04X-0x%04X, %d bytes en total" % (ini, org + i - 1, org + i - ini))


main()
