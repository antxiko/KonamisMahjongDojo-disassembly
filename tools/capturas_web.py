#!/usr/bin/env python3
"""Saca del cartucho las imagenes de la web, sin tocar el teclado a mano.

Las imagenes de esta web son CAPTURAS. El juego dibuja cada ficha con seis
tiles repartidos entre dos tercios de pantalla, asi que reconstruir una mesa
fuera del emulador no ensenaria una mesa, ensenaria trozos. Lo que si se puede
es hacer la captura reproducible, y eso es lo que hay aqui: openMSX arranca el
cartucho con `renderer none`, un guion de instantes vuelca la VRAM y los
registros del VDP, y tools/pantalla.py monta el PNG desde el volcado. Nadie
pulsa nada a ojo: la pasada A es el demo, que se juega solo y es determinista
desde el encendido, y la pasada B pulsa dos teclas en instantes fijos.

El nombre de cada volcado lleva dentro el estado y el submodo en que se hizo
(_eXX_sYY), asi que la propia captura dice de donde sale.

Uso: capturas_web.py <mahjong.rom> <docs/imagenes> [ruta de openmsx]
"""
import glob
import os
import subprocess
import sys

AQUI = os.path.dirname(os.path.abspath(__file__))
RAIZ = os.path.dirname(AQUI)
TRABAJO = os.path.join(RAIZ, "work", "web")

OPENMSX = os.environ.get("OPENMSX", "C:/Program Files/openMSX/openmsx.exe")
MAQUINA = os.environ.get("OPENMSX_MAQUINA", "Philips_VG_8020")

# Los instantes salen de haber medido el ciclo del demo: 168,96 s de reloj
# emulado, con el titulo en el estado 5, el reparto y la mano en el 11 y el
# rotulo del final en el 14.
GUION_A = """\
# Pasada A: el demo, que se juega solo. No se pulsa nada.
0 out work/web/vram
14.0 vram titulo
20.5 vram mesa
28.5 vram reparto
128.0 vram mano
148.0 vram recuento
162.0 vram final
"""

GUION_B = """\
# Pasada B: una tecla en el titulo lleva a la pantalla de dificultad, y otra
# arranca una partida de verdad en la primera de las tres.
0 out work/web/vramb
13.0 key 0 1
15.0 vram dificultad
21.0 key 0 2
40.0 vram partida
"""

# Que imagen sale de que etiqueta. El recorte, cuando lo hay, va en filas y
# columnas de caracter: el rotulo del titulo son las filas 4 a 8, columnas 7 a
# 24, que es donde lo pone la lista de 0x8531.
IMAGENES = [
    ("vram", "titulo", "titulo.png", None),
    ("vram", "titulo", "logo.png", (4, 7, 8, 24)),
    ("vram", "mesa", "mesa.png", None),
    ("vram", "reparto", "reparto.png", None),
    ("vram", "mano", "mano.png", None),
    ("vram", "recuento", "recuento.png", None),
    ("vram", "final", "final.png", None),
    ("vramb", "partida", "partida.png", None),
]


def pasada(rom, texto, openmsx):
    """Una pasada de openMSX con su guion, sin pintar y sin acelerador."""
    with open(os.path.join(TRABAJO, "guion.txt"), "w", encoding="utf-8") as f:
        f.write(texto)
    tcl = os.path.join(AQUI, "omsx_capturas_web.tcl")
    subprocess.run([openmsx, "-machine", MAQUINA, "-cart", rom, "-script", tcl],
                   cwd=RAIZ, check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def volcado(carpeta, etiqueta):
    """El .vram de una etiqueta. El numero de foto de delante no se fija."""
    v = sorted(glob.glob(os.path.join(TRABAJO, carpeta,
                                      "*_%s_e*.vram" % etiqueta)))
    return v[-1] if v else None


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 2
    rom, destino = os.path.abspath(argv[1]), os.path.abspath(argv[2])
    openmsx = argv[3] if len(argv) > 3 else OPENMSX
    os.makedirs(destino, exist_ok=True)
    os.makedirs(TRABAJO, exist_ok=True)

    print("  openMSX, pasada A (el demo)")
    pasada(rom, GUION_A, openmsx)
    print("  openMSX, pasada B (una partida)")
    pasada(rom, GUION_B, openmsx)

    sys.path.insert(0, AQUI)
    import pantalla                                            # noqa: E402

    faltan = 0
    for carpeta, etiqueta, salida, recorte in IMAGENES:
        ruta = volcado(carpeta, etiqueta)
        if not ruta:
            print("  FALTA el volcado de la etiqueta '%s'" % etiqueta)
            faltan += 1
            continue
        vram = open(ruta, "rb").read()
        b = pantalla.bases(ruta)
        escala = 4 if recorte else 2
        im = pantalla.pantalla(vram, b, escala, recorte is None)
        if recorte:
            f0, c0, f1, c1 = recorte
            im = im.crop((c0 * 8 * escala, f0 * 8 * escala,
                          (c1 + 1) * 8 * escala, (f1 + 1) * 8 * escala))
        im.save(os.path.join(destino, salida))
        print("  %-13s <- %s" % (salida, os.path.basename(ruta)))
    return 1 if faltan else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
