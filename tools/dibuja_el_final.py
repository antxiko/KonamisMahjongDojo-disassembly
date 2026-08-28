#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Dibuja el rotulo del FINAL de la partida sin pasar por el emulador.

PARA QUE: esa pantalla solo sale al terminar una partida entera de cuatro
manos, asi que el demo no llega nunca y no hay forma barata de capturarla. Esto
descomprime los tiles y sus colores de la ROM y monta el rotulo tal como lo
escribe DATA_logotipo_de_tres_filas, que es lo que se vera.

Uso: dibuja_el_final.py [rom]      (por defecto work/mahjong_en.rom)
"""
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import formato_b  # noqa: E402
from PIL import Image  # noqa: E402

PALETA = [(0, 0, 0), (0, 0, 0), (33, 200, 66), (94, 220, 120),
          (84, 85, 237), (125, 118, 252), (212, 82, 77), (66, 235, 245),
          (252, 85, 84), (255, 121, 120), (212, 193, 84), (230, 206, 128),
          (33, 176, 59), (201, 91, 186), (204, 204, 204), (255, 255, 255)]
ROTULO = 0x8598                # DATA_logotipo_de_tres_filas, formato A
ESCALA = 6


def lee_formato_a(rom, addr, org=0x4000):
    """Las tiras del rotulo tal como estan en la ROM: [(destino, tiles), ...].
    Se leen de ahi y no de una copia escrita a mano, para que el dibujo sea el
    que se va a ver y no el que uno se cree."""
    p = addr - org
    tiras, de, tiles = [], rom[p] | (rom[p + 1] << 8), []
    p += 2
    while True:
        b = rom[p]
        p += 1
        if b in (0xFE, 0xFF):
            tiras.append((de, tiles))
            if b == 0xFF:
                return tiras
            de, tiles = rom[p] | (rom[p + 1] << 8), []
            p += 2
        else:
            tiles.append(b)


def main():
    ruta = sys.argv[1] if len(sys.argv) > 1 else "work/mahjong_en.rom"
    rom = open(ruta, "rb").read()
    (dp, pat), = formato_b.descomprime(rom, 0x86D6, org=0x4000)[0][:1] or [(0, b"")]
    (dc, col), = formato_b.descomprime(rom, 0x8799, org=0x4000)[0][:1] or [(0, b"")]
    t0 = (dp % 0x800) // 8
    tiras = lee_formato_a(rom, ROTULO)
    ancho = max(len(t) for _, t in tiras)
    im = Image.new("RGB", (ancho * 8 * ESCALA, len(tiras) * 8 * ESCALA), PALETA[1])
    px = im.load()
    for f, (_, fila) in enumerate(tiras):
        for c, t in enumerate(fila):
            if t == 0x01:
                continue
            o = (t - t0) * 8
            for y in range(8):
                tinta, fondo = col[o + y] >> 4, col[o + y] & 0x0F
                for x in range(8):
                    v = PALETA[tinta if (pat[o + y] >> (7 - x)) & 1 else fondo]
                    for dy in range(ESCALA):
                        for dx in range(ESCALA):
                            px[(c * 8 + x) * ESCALA + dx, (f * 8 + y) * ESCALA + dy] = v
    im.save("work/final_end.png")
    print("work/final_end.png: %d filas de %d celdas, desde %s"
          % (len(tiras), ancho, ruta))


if __name__ == "__main__":
    main()
