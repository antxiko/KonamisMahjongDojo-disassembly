#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Compone el logo del titulo y lo trocea en los 54 tiles que el cartucho usa.

PARA QUE: el titulo lleva 麻雀道場 (Mahjong Dojo) en cuatro kanji dibujados con
los tiles 0xA0-0xD5 del tercio 0. El parche pone ahi el nombre en letras
latinas, y para eso hay que componer un lienzo de 144x24 pixeles y repartirlo
en 54 tiles de 8x8.

LA TRAMPA: esos tiles van ordenados POR COLUMNAS, no por filas. A0 es la fila
4 columna 7, A1 la fila 5 de esa MISMA columna, A2 la fila 6, y A3 vuelve
arriba en la columna 8. El reparto de glifos grandes de construye_parche_en.py
va por filas, asi que aqui se trocea a mano y se escriben los patrones tal
cual, que es algo que la seccion [patrones] ya admite (`TILE {8 bytes}`).

Escribe work/logo.txt con las lineas listas para pegar en parche.txt.

Uso: dibuja_logo.py [TEXTO]        (por defecto "MAHJONG DOJO")
"""
import io
import os
import re
import sys

ANCHO_GLIFO, ALTO_GLIFO = 11, 20
PASO = 12                      # 11 de dibujo + 1 de aire
COLS, FILAS = 18, 3            # tiles del hueco
PRIMER_TILE = 0xA0
NOMBRES = {" ": "espacio"}


def lee_glifos(ruta):
    glifos, g, filas = {}, None, []
    for ln in io.open(ruta, encoding="utf-8"):
        ln = ln.rstrip("\n")
        if ln.startswith("glifo "):
            if g is not None:
                glifos[g] = filas
            g, filas = ln[6:].strip(), []
        elif g is not None and re.fullmatch(r"[#.]+", ln):
            # ojo: una fila del dibujo tambien empieza por almohadilla, asi que
            # se mira ANTES que los comentarios; lo que las separa es que las
            # filas van DENTRO de un glifo y la cabecera no
            if len(ln) != ANCHO_GLIFO:
                raise SystemExit("%s: el glifo %s tiene una fila de %d y no %d"
                                 % (ruta, g, len(ln), ANCHO_GLIFO))
            filas.append(ln)
        elif ln.startswith("#") or not ln.strip():
            continue
        else:
            raise SystemExit("%s: linea rara: %r" % (ruta, ln))
    if g is not None:
        glifos[g] = filas
    for g, filas in glifos.items():
        if len(filas) != ALTO_GLIFO:
            raise SystemExit("%s: el glifo %s tiene %d filas y no %d"
                             % (ruta, g, len(filas), ALTO_GLIFO))
    return glifos


def compone(texto, glifos):
    """El lienzo entero: 144 x 24, con las veinte filas del dibujo centradas."""
    ancho, alto = COLS * 8, FILAS * 8
    if len(texto) * PASO > ancho:
        raise SystemExit("%r son %d pixeles y el hueco mide %d"
                         % (texto, len(texto) * PASO, ancho))
    lienzo = [["."] * ancho for _ in range(alto)]
    margen = (alto - ALTO_GLIFO) // 2
    # centrado tambien en horizontal, por si el texto no llena las 18 columnas
    izq = (ancho - len(texto) * PASO) // 2
    for i, c in enumerate(texto):
        g = glifos.get(NOMBRES.get(c, c))
        if g is None:
            raise SystemExit("no hay glifo para %r" % c)
        for y, fila in enumerate(g):
            for x, p in enumerate(fila):
                if p == "#":
                    lienzo[margen + y][izq + i * PASO + x] = "#"
    return lienzo


def trocea(lienzo):
    """Los 54 tiles, POR COLUMNAS: primero las tres filas de la columna 0."""
    salida = []
    for col in range(COLS):
        for fil in range(FILAS):
            octetos = []
            for y in range(8):
                fila = lienzo[fil * 8 + y]
                b = 0
                for x in range(8):
                    if fila[col * 8 + x] == "#":
                        b |= 0x80 >> x
                octetos.append(b)
            salida.append((PRIMER_TILE + len(salida), octetos))
    return salida


def main():
    texto = (sys.argv[1] if len(sys.argv) > 1 else "MAHJONG DOJO").upper()
    raiz = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    glifos = lee_glifos(os.path.join(raiz, "src", "parche_en", "fuentes", "logo_11x20.txt"))
    lienzo = compone(texto, glifos)
    tiles = trocea(lienzo)
    if tiles[-1][0] != 0xD5:
        raise SystemExit("el ultimo tile sale 0x%02X y tenia que ser 0xD5" % tiles[-1][0])

    out = ["", "# =========================================================================",
           "# EL LOGO DEL TITULO", "# =========================================================================",
           "# El cartucho pone ahi 麻雀道場 (Mahjong Dojo) en cuatro kanji de 32x24, con",
           "# los tiles 0xA0-0xD5 del tercio 0: dieciocho columnas por tres filas, o sea",
           "# un lienzo de 144x24 pixeles. Aqui va el nombre en letras latinas, al estilo",
           "# de los logos de Konami de esos anos.",
           "#",
           "# Los tiles van ordenados POR COLUMNAS -A0 es f4c7, A1 f5c7, A2 f6c7 y A3",
           "# vuelve arriba en la c8-, que no es como reparte los glifos grandes la",
           "# seccion [patrones]; por eso el troceado lo hace tools/dibuja_logo.py y aqui",
           "# van los patrones ya cortados. Se regenera, no se edita a mano.",
           "",
           "[patrones DATA_patrones_del_titulo_500 base=rom destino=0x6500 tiles=0xA0-0xD5]"]
    for t, oct_ in tiles:
        out.append("%02X {%s}" % (t, " ".join("%02X" % b for b in oct_)))
    out.append("")
    io.open(os.path.join(raiz, "work", "logo.txt"), "w", encoding="utf-8",
            newline="\n").write("\n".join(out))

    for y, fila in enumerate(lienzo):
        print("".join(fila))
    print("%d tiles, 0x%02X a 0x%02X -> work/logo.txt" % (len(tiles), tiles[0][0], tiles[-1][0]))


if __name__ == "__main__":
    main()
