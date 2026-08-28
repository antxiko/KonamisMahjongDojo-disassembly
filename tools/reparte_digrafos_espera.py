#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""Reparte los tiles del TERCIO DE ABAJO entre los digrafos de los rotulos de
la espera, y escribe las secciones de la fase 3 para parche.txt.

PARA QUE: debajo del recuento el cartucho dice con que espera se gano la mano
-ryanmen, kanchan, penchan, tanki, shanpon- y si fue por tsumo o por ron. Ahi
no caben letras de 8x8: "RYANMEN" son siete y el hueco seis celdas. Con la
fuente estrecha de dos letras por tile entra de sobra.

LAS CUENTAS, QUE CUADRAN JUSTO: hacen falta 17 digrafos distintos y hay 17
tiles -0x0C-0x0F del bloque sin comprimir y 0x1A-0x26 del otro-, dejando el
0x27 para "FU", que en digrafos es un tile solo igual que antes. Para que el
0x26 entre en el reparto hay que quitarlo de los marcos de los fu.

EL CABO DEL TSUMO: "TSUMO" son tres tiles y su hueco (0x744B) da para dos. Pero
SHANPON baja de seis celdas a cuatro y deja libres 0x7449 y 0x744A, asi que el
tsumo empieza una posicion antes y solo hay que cambiar un `ld hl`.

Uso: reparte_digrafos_espera.py     -> escribe work/fase3.txt
"""
import io
import os

# los tiles libres del tercio de abajo, en el orden en que se reparten
# Del bloque SIN comprimir de 0x92E3, donde las letras no cuestan tamaño. Los
# 0x08, 0x09 y 0x0A son COPIAS BYTE A BYTE de 0x0C, 0x0D y 0x0E -medido sobre
# la ROM-, o sea material duplicado que no usa ningun rotulo; se aprovechan
# para cambiar menos tiles del bloque comprimido, que iba justo de sitio.
CRUDOS = "08 09 0A 0B 0C 0D 0E 0F".split()
COMPRIMIDOS = ("1A 1B 1C 1D 1E 1F 20 21 22 23 24 25 26").split()   # del de 0x9343

# (direccion del cuerpo, texto). Las cinco esperas y las dos marcas.
ROTULOS = [
    (0x7428, "RYANMEN"),
    (0x742F, "KANCHAN"),
    (0x7436, "PENCHAN"),
    (0x743D, "TANKI"),
    (0x7444, "SHANPON"),
    (0x744A, "TSUMO"),      # era 0x744B: se corre un byte, ver el docstring
    (0x744E, "RON"),
]


def pares(t):
    t = t if len(t) % 2 == 0 else t + " "
    return [t[i:i + 2] for i in range(0, len(t), 2)]


def main():
    todos = ["FU"]      # el cajetin de los fu; ver mas abajo
    for _, t in ROTULOS:
        todos += pares(t)
    distintos = sorted(set(todos))
    libres = CRUDOS + COMPRIMIDOS
    print("digrafos distintos: %d   tiles libres: %d" % (len(distintos), len(libres)))
    if len(distintos) > len(libres):
        raise SystemExit("NO CABE por %d" % (len(distintos) - len(libres)))
    mapa = dict(zip(distintos, libres))
    # que ningun cuerpo se salga de su hueco
    for i, (dirc, t) in enumerate(ROTULOS):
        fin = dirc + len(pares(t)) + 1
        siguiente = ROTULOS[i + 1][0] if i + 1 < len(ROTULOS) else 0x7451
        if fin > siguiente:
            raise SystemExit("%r acaba en 0x%04X y el siguiente empieza en 0x%04X"
                             % (t, fin, siguiente))

    out, w = [], None
    out = []
    w = out.append
    w("")
    w("# =========================================================================")
    w("# FASE 3: LOS ROTULOS DE LA ESPERA")
    w("# =========================================================================")
    w("# Debajo del recuento, el cartucho dice con que espera se gano la mano y si")
    w("# fue por tsumo o por ron. Es lo ultimo que quedaba en katakana, y ahora")
    w("# canta porque todo lo de arriba esta en ingles.")
    w("#")
    w("# Aqui tampoco caben letras de 8x8 -RYANMEN son siete y el hueco seis")
    w("# celdas-, asi que va con la misma fuente estrecha de dos letras por tile.")
    w("# Las cuentas cuadran JUSTO: 17 digrafos distintos y 17 tiles libres, y el")
    w("# 0x27 se queda para FU, que en digrafos es un tile solo igual que antes.")
    w("# El reparto lo hace tools/reparte_digrafos_espera.py; se regenera.")
    w("")
    w("# Los cuatro que salen del bloque SIN comprimir.")
    w("[crudos DATA_patrones_sin_comprimir_3020 base=rom destino=0x7020 tiles=0x04-0x0F]")
    for d in distintos:
        if mapa[d] in CRUDOS:
            w('%s estrecho "%s"' % (mapa[d], d))
    w("")
    w("# Y los trece del bloque grande, que se lee DOS veces: entero desde su")
    w("# principio y otra vez desde 0x93AA para las manos dibujadas del tablero.")
    w("# Esa segunda entrada cae justo en el tile 0x28, asi que los de antes se")
    w("# pueden cambiar recomprimiendo solo esa parte y reapuntando la instruccion.")
    w("")
    w("[patrones DATA_patrones_del_tercio_de_abajo base=rom destino=0x70D0 tiles=0x1A-0xFF"
      " cola=0x93AA reapunta=pinta_las_dos_manos_del_tablero]")
    for d in distintos:
        if mapa[d] in COMPRIMIDOS:
            w('%s estrecho "%s"' % (mapa[d], d))
    w("# Las siete tiras. El tsumo empieza en 0x744A y no en 0x744B: SHANPON baja")
    w("# de seis celdas a cuatro y deja ese byte libre, que es justo el que le")
    w("# faltaba a TSUMO (tres tiles y el remate).")
    w("")
    w("[cuerpos DATA_rotulos_de_la_espera charset=digrafos]")
    for dirc, t in ROTULOS:
        w('0x%04X "%s"' % (dirc, t))
    w("")
    w("[codigo L_72E4]")
    w("ld hl,0744bh => ld hl,0744ah")
    w("")
    w("# Y los marcos de los fu: sueltan su borde izquierdo (el tile 0x26, que hace")
    w("# falta para el reparto) y su フ pasa a decir FU, que en digrafos es un")
    w("# tile solo igual que antes. Ese FU va al bloque SIN comprimir porque el")
    w("# comprimido no daba para un tile mas.")
    w("")
    w("[formatoA DATA_marcos_de_los_fu charset=digrafos]")
    for pos in ("f16 c10", "f16 c22", "f19 c10", "f19 c22", "f22 c10", "f22 c22"):
        w("%-8s {01 01 01 %s}" % (pos, mapa["FU"]))
    w("")

    raiz = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
    io.open(os.path.join(raiz, "work", "fase3.txt"), "w", encoding="utf-8",
            newline="\n").write("\n".join(out))
    print("escrito work/fase3.txt")
    print("reparto:", " ".join("%s=%s" % (mapa[d], d.replace(" ", "_")) for d in distintos))


if __name__ == "__main__":
    main()
