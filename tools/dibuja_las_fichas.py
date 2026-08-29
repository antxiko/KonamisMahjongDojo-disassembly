#!/usr/bin/env python3
"""Dibuja las 34 fichas del mahjong TAL COMO SE VERIAN con los tiles que hay
cargados en un volcado de VRAM concreto.

PARA QUE: el modo attract (paso 6) tiene que pintar ejemplos de piezas, y solo
puede usar las fichas cuyos seis tiles esten de verdad en la VRAM en ese
momento. La tabla 0x4735 dice que tiles forman cada ficha, pero NO dice si esos
tiles siguen ahi: en la pantalla del final, por ejemplo, el alfabeto latino del
parche (tiles 0x30-0x4D) esta pisando justo el sitio de los honores. Contar
tiles "no vacios" no sirve, porque una letra tampoco esta vacia: hay que
DIBUJARLO y mirarlo.

Cada ficha son seis tiles, dos de ancho por tres de alto, seguidos desde el
primero (0x6F72), y van POR FILAS: 0 1 / 2 3 / 4 5.

Uso:
  dibuja_las_fichas.py <volcado.vram> [--png salida.png] [--escala N]
"""
import sys

# La tabla 0x4735 del cartucho: codigo de ficha -> primer tile del dibujo.
TABLA = [
    ("MAN", [0xF4, 0xEE, 0xE8, 0xE2, 0xDC, 0xD6, 0xD0, 0xCA, 0xC4]),
    ("PIN", [0x88, 0x82, 0x7C, 0x76, 0x70, 0x6A, 0x64, 0x5E, 0x58]),
    ("SOU", [0xBE, 0xB8, 0xB2, 0xAC, 0xA6, 0xA0, 0x9A, 0x94, 0x8E]),
    ("HON", [0x52, 0x4C, 0x46, 0x40, 0x3A, 0x34, 0x2E]),
]
EXTRA = [("dorso", 0x28), ("hueco", 0xFA)]

PALETA = [
    (0, 0, 0), (0, 0, 0), (33, 200, 66), (94, 220, 120),
    (84, 85, 237), (125, 118, 252), (212, 82, 77), (66, 235, 245),
    (252, 85, 84), (255, 121, 120), (212, 193, 84), (230, 206, 128),
    (33, 176, 59), (201, 91, 186), (204, 204, 204), (255, 255, 255),
]


def dibuja_tile(px, ox, oy, pat, col, t):
    for y in range(8):
        b = pat[t * 8 + y]
        c = col[t * 8 + y]
        tinta, fondo = PALETA[c >> 4], PALETA[c & 15]
        for x in range(8):
            px[ox + x, oy + y] = tinta if (b >> (7 - x)) & 1 else fondo


def main(argv):
    if not argv:
        print(__doc__)
        return 1
    vram = open(argv[0], "rb").read()
    png = "fichas.png"
    escala = 3
    if "--png" in argv:
        png = argv[argv.index("--png") + 1]
    if "--escala" in argv:
        escala = int(argv[argv.index("--escala") + 1])

    # Los tres tercios pueden tener patrones distintos; se dibuja el tercio 0.
    pat = vram[0x2000:0x2800]
    col = vram[0x0000:0x0800]

    from PIL import Image, ImageDraw
    # cuatro filas de fichas, la mas larga de nueve, mas una de extras
    ancho = 9 * (16 + 6) + 40
    alto = (len(TABLA) + 1) * (24 + 14) + 10
    im = Image.new("RGB", (ancho, alto), (40, 40, 40))
    px = im.load()
    d = ImageDraw.Draw(im)

    y = 6
    for palo, tiles in TABLA:
        d.text((2, y + 8), palo, fill=(255, 255, 0))
        for i, t in enumerate(tiles):
            x = 40 + i * 22
            for k in range(6):
                dibuja_tile(px, x + (k % 2) * 8, y + (k // 2) * 8, pat, col, t + k)
            d.text((x + 4, y + 25), str(i + 1), fill=(180, 180, 180))
        y += 24 + 14
    d.text((2, y + 8), "otros", fill=(255, 255, 0))
    for i, (nombre, t) in enumerate(EXTRA):
        x = 40 + i * 22
        for k in range(6):
            dibuja_tile(px, x + (k % 2) * 8, y + (k // 2) * 8, pat, col, t + k)
        d.text((x, y + 25), nombre[:5], fill=(180, 180, 180))

    if escala != 1:
        im = im.resize((ancho * escala, alto * escala), Image.NEAREST)
    im.save(png)
    print("escrito %s" % png)
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv[1:]))
