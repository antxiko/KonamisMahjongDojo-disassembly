#!/usr/bin/env python3
"""Censo de tiles: que numeros de tile aparecen en la tabla de nombres de cada
tercio, en todos los volcados de VRAM que se le den.

PARA QUE: el parche de traduccion necesita sitio para letras latinas en cada
tercio, y el sitio libre no se ve en la ROM (los tiles se escriben desde
codigo, no solo desde listas). Se mira lo que el juego pinta de verdad, en
todas las pantallas volcadas con tools/omsx_vuelca_vram.tcl. Un tile que no
sale en ningun volcado NO es seguro que este libre (habra situaciones sin
volcar), pero uno que sale seguro que no lo esta.

Uso: censo_tiles.py <volcado.vram> [...]      (admite comodines via shell)
"""
import os
import sys


def main():
    usados = [set(), set(), set()]
    donde = {}
    n = 0
    for ruta in sys.argv[1:]:
        if not ruta.endswith(".vram"):
            continue
        v = open(ruta, "rb").read()
        n += 1
        for f in range(24):
            for c in range(32):
                t = v[0x3800 + f * 32 + c]
                usados[f // 8].add(t)
                donde.setdefault((f // 8, t), os.path.basename(ruta))
    print("%d volcados" % n)
    for tercio in range(3):
        u = usados[tercio]
        libres = [t for t in range(256) if t not in u]
        print("\n== tercio %d: %d tiles usados, %d nunca vistos" % (tercio, len(u), len(libres)))
        print("   usados : " + " ".join("%02X" % t for t in sorted(u)))
        # los libres, en tramos
        tramos, ini = [], None
        for t in range(257):
            libre = t < 256 and t in libres
            if libre and ini is None:
                ini = t
            if not libre and ini is not None:
                tramos.append((ini, t - 1))
                ini = None
        print("   libres : " + " ".join(("%02X-%02X" % tr if tr[0] != tr[1] else "%02X" % tr[0]) for tr in tramos))
    return 0


if __name__ == "__main__":
    sys.exit(main())
