#!/usr/bin/env python3
"""Censo de tiles: quien usa cada numero de tile de cada tercio, en todos los
volcados de VRAM que se le den.

PARA QUE: el parche de traduccion necesita meter letras latinas en tiles que
ahora mismo son katakana, y en el tercio del medio los tiles de texto estan
mezclados con los de las fichas del tablero. Cambiar el tile equivocado no da
ningun error: simplemente sale una ficha con una letra dentro. Esto lo dice
antes, mirando lo que el juego pinta de verdad en los volcados que deja
tools/omsx_vuelca_vram.tcl.

Aviso de alcance: un tile que no sale en ningun volcado NO es seguro que este
libre -habra situaciones sin volcar-, pero uno que sale seguro que no lo esta.
Por eso conviene volcar antes las pantallas donde se sabe que hay texto.

Uso:
  censo_tiles.py <volcado.vram> [...]              resumen por tercio
  censo_tiles.py --donde <tercio> <volcado> [...]  cada tile, con las celdas
                                                   (fila,columna) donde sale
  censo_tiles.py --filas F0-F1 <tercio> <vol> ...  solo esas filas de pantalla
"""
import os
import sys


def celdas(ruta):
    v = open(ruta, "rb").read()
    for f in range(24):
        for c in range(32):
            yield f, c, v[0x3800 + f * 32 + c]


def tramos(lista):
    out, i = [], 0
    lista = sorted(lista)
    while i < len(lista):
        j = i
        while j + 1 < len(lista) and lista[j + 1] == lista[j] + 1:
            j += 1
        out.append("%02X" % lista[i] if i == j else "%02X-%02X" % (lista[i], lista[j]))
        i = j + 1
    return " ".join(out) if out else "(ninguno)"


def main():
    args = sys.argv[1:]
    filas = None
    if "--filas" in args:
        i = args.index("--filas")
        a, b = args[i + 1].split("-")
        filas = (int(a), int(b))
        del args[i:i + 2]
    if args and args[0] == "--donde":
        tercio = int(args[1], 0)
        usos = {}
        n = 0
        for ruta in args[2:]:
            if not ruta.endswith(".vram"):
                continue
            n += 1
            for f, c, t in celdas(ruta):
                if f // 8 != tercio:
                    continue
                if filas and not filas[0] <= f <= filas[1]:
                    continue
                usos.setdefault(t, set()).add((f, c))
        print("tercio %d, %d volcados%s" % (tercio, n, "" if not filas else
                                            ", solo las filas %d-%d" % filas))
        for t in sorted(usos):
            sitios = sorted(usos[t])
            resumen = " ".join("f%d,c%d" % (f, c) for f, c in sitios[:12])
            if len(sitios) > 12:
                resumen += " ... (%d celdas)" % len(sitios)
            print("  tile %02X: %s" % (t, resumen))
        print("\n  nunca vistos: %s" % tramos([t for t in range(256) if t not in usos]))
        return 0

    usados = [set(), set(), set()]
    n = 0
    for ruta in args:
        if not ruta.endswith(".vram"):
            continue
        n += 1
        for f, c, t in celdas(ruta):
            usados[f // 8].add(t)
    print("%d volcados" % n)
    for tercio in range(3):
        u = usados[tercio]
        print("\n== tercio %d: %d tiles usados, %d nunca vistos" % (tercio, len(u), 256 - len(u)))
        print("   usados : " + tramos(sorted(u)))
        print("   libres : " + tramos([t for t in range(256) if t not in u]))
    return 0


if __name__ == "__main__":
    sys.exit(main())
