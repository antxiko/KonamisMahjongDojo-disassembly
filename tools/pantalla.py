#!/usr/bin/env python3
"""Dibuja una pantalla del MSX a partir de un volcado de VRAM, y dice que
tile hay en cada celda.

PARA QUE: el parche de traduccion tiene que saber que numero de tile forma
cada rotulo de cada pantalla y en que tercio vive su dibujo. Un PNG del
emulador no lo dice; la tabla de nombres si. Esto lee el volcado que deja
tools/omsx_vuelca_vram.tcl y saca:

  - el PNG de la pantalla (modo GRAPHIC 2, con los sprites encima), y
  - el mapa de tiles: 24 filas de 32 numeros en hexadecimal.

Con --hoja dibuja la HOJA DE TILES de un tercio: los 256 patrones con sus
colores, 16 por fila, para saber que glifo es cada numero.

Uso:
  pantalla.py <volcado.vram> [--png salida.png] [--mapa salida.txt]
              [--hoja 0|1|2 --png hoja.png] [--escala N] [--sin-sprites]
              [--recorte f0,c0,f1,c1 --png trozo.png]

Las bases de las tablas se leen del .vdp que va al lado del .vram si existe;
si no, las de este cartucho (nombres 0x3800, patrones 0x2000, colores 0x0000,
sprites 0x1800 y atributos 0x1B00).
"""
import os
import sys

PALETA = [(0, 0, 0), (0, 0, 0), (33, 200, 66), (94, 220, 120),
          (84, 85, 237), (125, 118, 252), (212, 82, 77), (66, 235, 245),
          (252, 85, 84), (255, 121, 120), (212, 193, 84), (230, 206, 128),
          (33, 176, 59), (201, 91, 186), (204, 204, 204), (255, 255, 255)]


def bases(ruta_vram):
    """Las bases de las tablas, del .vdp de al lado o las del cartucho."""
    b = dict(nombres=0x3800, patrones=0x2000, colores=0x0000,
             spr_pat=0x1800, spr_atr=0x1B00, spr16=True, spr_mag=False)
    vdp = os.path.splitext(ruta_vram)[0] + ".vdp"
    if os.path.exists(vdp):
        r = open(vdp, "rb").read()
        if len(r) >= 7:
            b["nombres"] = (r[2] & 0x0F) * 0x400
            b["colores"] = 0x2000 if (r[3] & 0x80) else 0x0000
            b["patrones"] = 0x2000 if (r[4] & 0x04) else 0x0000
            b["spr_atr"] = (r[5] & 0x7F) * 0x80
            b["spr_pat"] = (r[6] & 0x07) * 0x800
            b["spr16"] = bool(r[1] & 0x02)
            b["spr_mag"] = bool(r[1] & 0x01)
    return b


def mapa(vram, b):
    filas = []
    for f in range(24):
        filas.append([vram[b["nombres"] + f * 32 + c] for c in range(32)])
    return filas


def pinta_tile(px, x0, y0, vram, pat, col, escala):
    for y in range(8):
        p = vram[pat + y]
        cc = vram[col + y]
        fg, bg = cc >> 4, cc & 0x0F
        for x in range(8):
            c = fg if p & (0x80 >> x) else bg
            if c == 0:
                c = 1               # transparente: sale el fondo (negro)
            for dy in range(escala):
                for dx in range(escala):
                    px[(x0 + x) * escala + dx, (y0 + y) * escala + dy] = PALETA[c]


def pantalla(vram, b, escala, sprites=True):
    from PIL import Image
    im = Image.new("RGB", (256 * escala, 192 * escala), PALETA[1])
    px = im.load()
    for f in range(24):
        tercio = f // 8
        for c in range(32):
            t = vram[b["nombres"] + f * 32 + c]
            pinta_tile(px, c * 8, f * 8, vram,
                       b["patrones"] + tercio * 0x800 + t * 8,
                       b["colores"] + tercio * 0x800 + t * 8, escala)
    if sprites:
        # La lista de sprites TERMINA en el primero con y=208, y hay que
        # contarlos hacia delante: los atributos que vienen detras son basura
        # sin inicializar. (Costo una tarde: dibujados al reves con un `break`
        # dentro, salian 31 sprites fantasma encima de la pantalla, y parecian
        # parte del juego.) Luego se pintan de mayor a menor indice, para que
        # el de numero mas bajo quede encima, como hace el VDP.
        validos = 32
        for i in range(32):
            if vram[b["spr_atr"] + i * 4] == 208:
                validos = i
                break
        for i in range(validos - 1, -1, -1):
            a = b["spr_atr"] + i * 4
            y, x, n, c = vram[a], vram[a + 1], vram[a + 2], vram[a + 3]
            if c & 0x80:
                x -= 32
            c &= 0x0F
            if c == 0:
                continue
            y = (y + 1) & 0xFF
            if b["spr16"]:
                n &= 0xFC
            for cuad in range(4 if b["spr16"] else 1):
                base = b["spr_pat"] + n * 8 + cuad * 8
                ox, oy = (cuad // 2) * 8, (cuad % 2) * 8
                for yy in range(8):
                    p = vram[base + yy]
                    for xx in range(8):
                        if p & (0x80 >> xx):
                            X, Y = x + ox + xx, y + oy + yy
                            if 0 <= X < 256 and 0 <= Y < 192:
                                for dy in range(escala):
                                    for dx in range(escala):
                                        px[X * escala + dx, Y * escala + dy] = PALETA[c]
    return im


def hoja(vram, b, tercio, escala):
    """Los 256 tiles del tercio, 16 por fila, cada uno con su numero encima."""
    from PIL import Image, ImageDraw, ImageFont
    paso = 8 * escala + 14
    im = Image.new("RGB", (16 * paso + 2, 16 * paso + 2), (60, 60, 60))
    px = im.load()
    dib = ImageDraw.Draw(im)
    fuente = ImageFont.load_default()
    for t in range(256):
        fy, fx = divmod(t, 16)
        x0, y0 = 2 + fx * paso, 14 + fy * paso
        dib.text((x0 + 1, y0 - 13), "%02X" % t, fill=(255, 255, 0), font=fuente)
        pat = b["patrones"] + tercio * 0x800 + t * 8
        col = b["colores"] + tercio * 0x800 + t * 8
        for y in range(8):
            p, cc = vram[pat + y], vram[col + y]
            fg, bg = cc >> 4, cc & 0x0F
            for x in range(8):
                c = fg if p & (0x80 >> x) else bg
                rgb = PALETA[c] if c else (20, 20, 20)
                for dy in range(escala):
                    for dx in range(escala):
                        px[x0 + x * escala + dx, y0 + y * escala + dy] = rgb
    return im


def main():
    args = sys.argv[1:]
    if not args:
        print(__doc__)
        return 2
    ruta = args[0]
    vram = open(ruta, "rb").read()
    b = bases(ruta)
    escala = int(args[args.index("--escala") + 1]) if "--escala" in args else 2
    png = args[args.index("--png") + 1] if "--png" in args else None
    if "--hoja" in args:
        tercio = int(args[args.index("--hoja") + 1])
        im = hoja(vram, b, tercio, max(escala, 3))
        im.save(png or os.path.splitext(ruta)[0] + "_hoja%d.png" % tercio)
        return 0
    if "--recorte" in args:
        f0, c0, f1, c1 = (int(x) for x in args[args.index("--recorte") + 1].split(","))
        im = pantalla(vram, b, escala, "--sin-sprites" not in args)
        im = im.crop((c0 * 8 * escala, f0 * 8 * escala, (c1 + 1) * 8 * escala, (f1 + 1) * 8 * escala))
        im.save(png or os.path.splitext(ruta)[0] + "_recorte.png")
        return 0
    filas = mapa(vram, b)
    texto = ["      " + " ".join("%2d" % c for c in range(32))]
    for f, fila in enumerate(filas):
        texto.append("f%2d:  " % f + " ".join("%02X" % t for t in fila))
    salida = "\n".join(texto) + "\n"
    if "--mapa" in args:
        open(args[args.index("--mapa") + 1], "w").write(salida)
    else:
        sys.stdout.write(salida)
    if png:
        pantalla(vram, b, escala, "--sin-sprites" not in args).save(png)
    return 0


if __name__ == "__main__":
    sys.exit(main())
