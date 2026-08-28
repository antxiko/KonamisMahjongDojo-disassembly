#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Reparte los tiles libres del tercio 1 entre los digrafos que hacen falta y
escribe las secciones de la fase 2b para parche.txt."""
import io

# --- los tiles libres, medidos contra DATA_primer_tile_de_cada_ficha --------
# fila del medio de una ficha y sin usar tras la fase 2a, menos 4E (barra cian
# de la caja de mensajes) y EA (cursor del menu), que hay que conservar
LIBRES = ("3D 42 43 48 49 4F 54 55 5A 5B 60 61 66 67 6C 6D C0 C1 C6 C7 CC CD "
          "D2 D3 D8 D9 DE DF E4 E5 EB F0 F1 F6 F7 FC FD").split()
# y las 12 letras del charset `barra` que no se usan en ningun rotulo
SOBRAN_BARRA = "7F 84 8B 91 96 9D A2 AF B4 B5 BA BB".split()

# --- los textos, celda a celda ---------------------------------------------
# (bloque, tipo, [(fila, col, ancho_en_celdas, texto), ...])
# TODOS los textos llevan un TILE ENTERO de margen a la izquierda -dos
# espacios-: pegados al borde de su caja se leen mal. Que el margen sea un tile
# y no medio tiene ademas un premio: el texto empieza en frontera de tile, los
# pares salen alineados y se repiten entre rotulos, asi que cuesta bastantes
# menos tiles (con medio tile de margen no cabia: 53 pares para 49 tiles).
# Y por la derecha no se deja mas de UN tile vacio, para que la caja se vea
# llena; con 7 celdas eso son textos de 10 a 12 caracteres tras el margen.
MENU = [
    ("f10 c26", 6, "  WIN"),
    ("f11 c26", 6, "  RIICHI"),
    ("f12 c26", 6, "  PON"),
    ("f13 c26", 6, "  CHI"),
    ("f14 c26", 6, "  KAN"),
]
CAJA = [                                     # 7 celdas = 14 caracteres
    ("DATA_dibujo_0", [("f11 c2", 7, "  CALL TSUMO"), ("f12 c2", 7, "  PON CHI KAN")]),
    ("DATA_dibujo_1", [("f11 c2", 7, "  CALL KAN OR"), ("f12 c2", 7, "  DISCARD ONE")]),
    ("DATA_dibujo_2", [("f11 c2", 7, "  NOT ALLOWED"), ("f12 c2", 7, "")]),
]
AVISOS = ["  FURITEN HAND", "  MISSED RON", "  NO YAKU HAND"]   # f11 c2, 7 celdas
CHOMBO = "  PENALTY HAND"                                     # f12 c2, 7 celdas
# El cartel de la mano sin ganador (ryuukyoku): una caja de 8 celdas de ancho
# con 流局 en dos kanji de 16x16. Sus tiles (C0 C1 C6 C7 CC CD D2 D3) entran en
# el reparto de digrafos, asi que hay que reescribirlo por narices.
RYUU = [("f11 c17", 8, "      DRAW"), ("f12 c17", 8, "      GAME")]


def pares(t, celdas):
    t = t.ljust(celdas * 2)[:celdas * 2]
    return [t[i:i + 2] for i in range(0, celdas * 2, 2)]


todos = []
for _, n, t in MENU:
    todos += pares(t, n)
for _, lineas in CAJA:
    for _, n, t in lineas:
        todos += pares(t, n)
for t in AVISOS:
    todos += pares(t, 7)
todos += pares(CHOMBO, 7)
for _, n_, t in RYUU:
    todos += pares(t, n_)

for bloque, lineas in CAJA:
    for _, n_, t in lineas:
        if t and (n_ - (len(t) + 1) // 2) > 1:
            raise SystemExit("%s: %r deja %d tiles vacios a la derecha"
                             % (bloque, t, n_ - (len(t) + 1) // 2))
        if t and not t.startswith("  "):
            raise SystemExit("%s: %r sin el tile de margen a la izquierda" % (bloque, t))

distintos = sorted(set(todos))
disponibles = LIBRES + SOBRAN_BARRA
print("digrafos distintos: %d   tiles disponibles: %d" % (len(distintos), len(disponibles)))
if len(distintos) > len(disponibles):
    raise SystemExit("NO CABE por %d tiles" % (len(distintos) - len(disponibles)))
mapa = dict(zip(distintos, disponibles))

out = []
w = out.append
w("")
w("# =========================================================================")
w("# FASE 2b: EL MENU, LOS MENSAJES Y LOS AVISOS")
w("# =========================================================================")
w("# Aqui las letras de 8x8 no dan de si: la caja de mensajes son siete celdas")
w("# por linea y el japones dice en cuatro silabas lo que en ingles son cuatro")
w("# palabras. Asi que este tercio pasa a la FUENTE ESTRECHA de 3x7 y mete DOS")
w("# letras en cada tile, con lo que la caja pasa de 7 a 14 caracteres por")
w("# linea y el menu de 6 a 12.")
w("#")
w("# Lo que cuesta: un tile por cada PAR DISTINTO de letras -no por letra-, y")
w("# aqui salen %d. Hay %d tiles libres (los que son fila del medio de una" % (len(distintos), len(disponibles)))
w("# ficha y no gasto la fase 2a, mas las doce letras del alfabeto de la barra")
w("# que ningun rotulo usa), asi que entra con %d de margen. La rejilla de" % (len(disponibles) - len(distintos)))
w("# 'caracter y medio' -letras de 5px- costaria 66 tiles y NO cabria: al caer")
w("# a caballo de dos tiles, cada celda del texto es casi unica.")
w("#")
w("# OJO al tocar estos textos: el tile depende del PAR, asi que cambiar una")
w("# palabra cambia el reparto de tiles. Se regeneran con tools/reparte_digrafos.py.")
w("")
w("[patrones DATA_patrones_del_tablero_900 base=rom destino=0x6900 tiles=0x20-0xFF reubica=pinta_el_tablero]")
for d in distintos:
    w('%s estrecho "%s"' % (mapa[d], d))
w("")
w("# Las letras heredan el color del tile que ocupan, y estos venian de tres")
w("# sitios distintos -kanji blancos de la barra, katakana negra sobre cian de")
w("# las cajas y el 流局-. Todos pasan a 0x17, negro sobre cian, que es el de")
w("# la caja de mensajes y el del menu.")
w("")
w("# (Tampoco cabe comprimido en su hueco, asi que se reubica igual que el de")
w("# patrones: los dos los carga pinta_el_tablero y las dos sustituciones se")
w("# acumulan sobre la misma rutina.)")
w("[colores DATA_colores_del_tablero_900 base=rom destino=0x4900 tiles=0x20-0xFF reubica=pinta_el_tablero]")
for d in distintos:
    w("%s 0x17" % mapa[d])
w("")
w("# EL MENU DE LLAMADAS. Seis celdas por fila (c26-c31) con el cursor en c25.")
w("# アガリ es ganar la mano; リーチ, cantar riichi.")
w("")
w("# (Con el margen ya no cabe en su hueco -51 bytes de 50-, asi que se")
w("# reubica y se reapunta el ld hl de L_4CAF.)")
w("[formatoB DATA_dibujo_de_seis_filas charset=digrafos reubica=L_4CAF]")
w('f9 c26  {02 02 02 02 02 02}')
for pos, n, t in MENU:
    w('%-8s "%s"' % (pos, t.ljust(n * 2)))
w("")
w("# LOS MENSAJES DE LA CAJA CIAN, dos lineas de siete celdas. El cartucho los")
w("# dice en katakana: ツモ・ポン・チー・カン セヨ (haz tsumo, pon, chi o kan),")
w("# カン・ステハイ セヨ (haz kan o descarta) y デキマセン (no puedes).")
for bloque, lineas in CAJA:
    w("")
    # los tres no los carga un `ld hl` sino la tabla de punteros de 0x47B2, y
    # con el margen ya no caben en su hueco: se reubican y se reapunta la tabla
    w("[formatoB %s charset=digrafos reubica=si puntero_en=DATA_punteros_de_los_tres_dibujos]"
      % bloque)
    for pos, n, t in lineas:
        w('%-8s "%s"' % (pos, t.ljust(n * 2)))
w("")
w("# LOS TRES AVISOS de la fila 11, cada uno una lista de formato A al mismo")
w("# destino: furiten (no puedes ganar con esa ficha), minogashi (dejaste pasar")
w("# el ron) y yakunashi (cantaste sin jugada).")
w("")
w("[formatoA DATA_tres_avisos_de_la_fila_11 charset=digrafos]")
for i, t in enumerate(AVISOS):
    if i:
        w("---")
    w('f11 c2  "%s"' % t.ljust(14))
w("")
w("# Y el que sale debajo cuando la mano acaba con penalizacion: チョンボ.")
w("")
w("[formatoA DATA_rotulo_de_la_fila_12 charset=digrafos]")
w('f12 c2  "%s"' % CHOMBO.ljust(14))
w("")
w("# Y el cartel de la mano sin ganador. La caja son ocho celdas (c17-c24) en")
w("# las filas 9 a 13; el japones pone ahi 流局 en dos kanji de 16x16, que en")
w("# ingles caben centrados en dos lineas.")
w("")
w("[formatoB DATA_cartel_de_ryuukyoku charset=digrafos]")
w("f9 c20  {01 01}")
w("f10 c17 {01 01 01 01 01 01 01}")
for pos, n_, t in RYUU:
    w('%-8s "%s"' % (pos, t.ljust(n_ * 2)))
w("f13 c17 {01 01 01 01 01 01 01}")
w("")

io.open("work/fase2b.txt", "w", encoding="utf-8", newline="\n").write("\n".join(out))
print("escrito work/fase2b.txt")
print("reparto:", " ".join("%s=%s" % (mapa[d], d.replace(" ", "_")) for d in distintos))
