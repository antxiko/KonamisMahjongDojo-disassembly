#!/usr/bin/env python3
"""Empalma fragmentos de parche en el listado y comprueba que SOLO cambia lo
que se ha querido cambiar.

COMO FUNCIONA. El listado de src/mahjong.asm es el desensamblado fiel y no se
toca. Cada fragmento (un .asm en el directorio de fragmentos) empieza con una
cabecera que dice que bloque del listado sustituye:

    ; @bloque DATA_rotulos_del_menu        el bloque que empieza en esa etiqueta
    ; @hasta  DATA_logotipo_de_tres_filas  (opcional) y todos los siguientes,
                                           hasta justo antes de esta otra

y debajo van las lineas nuevas (defb, instrucciones, lo que sea). El bloque
original va desde su etiqueta hasta la siguiente etiqueta o comentario de
bloque. El listado empalmado lleva, detras de cada bloque sustituido, un
`if $ != fin / .error / endif`, asi que si el fragmento mide un byte de mas o
de menos pasmo se niega a ensamblar y nada se desplaza en silencio.

LA PRUEBA QUE DECIDE: se ensambla el listado empalmado y se compara con la ROM
original byte a byte; cualquier diferencia FUERA de los bloques sustituidos es
un error. Asi el parche no puede tocar nada por accidente.

Uso:
  parchea.py <listado.asm> <dir_fragmentos> <salida.asm> <rom_original> [org]
Deja <salida>.bin al lado (la ROM modificada) y sale con 1 si algo falla.
"""
import glob
import os
import re
import subprocess
import sys

RE_LABEL = re.compile(r"^([A-Za-z_.][\w.]*):")
RE_DIR = re.compile(r";\s*([0-9a-fA-F]{4})(?:\s|$)")


def direccion_de(lineas, i):
    """La direccion de la primera linea con contenido a partir de i."""
    for ln in lineas[i:]:
        if ln.strip() == "" or ln.startswith(";") or RE_LABEL.match(ln):
            continue
        m = RE_DIR.search(ln)
        if m:
            return int(m.group(1), 16)
        raise SystemExit("no se lee la direccion en: %r" % ln)
    return None


def fin_de_bloque(lineas, i):
    """Indice de la primera linea que ya no es del bloque que empieza en i."""
    j = i + 1
    while j < len(lineas):
        ln = lineas[j]
        if RE_LABEL.match(ln) or ln.startswith(";"):
            return j
        j += 1
    return j


def indice_de(lineas, etiqueta):
    for i, ln in enumerate(lineas):
        m = RE_LABEL.match(ln)
        if m and m.group(1) == etiqueta:
            return i
    raise SystemExit("no existe la etiqueta %s en el listado" % etiqueta)


def siguiente_etiqueta(lineas, j):
    for k in range(j, len(lineas)):
        if RE_LABEL.match(lineas[k]):
            return k
    return None


def lee_fragmento(ruta):
    bloque = hasta = None
    cuerpo = []
    for ln in open(ruta, encoding="utf-8"):
        ln = ln.rstrip("\n")
        m = re.match(r";\s*@(\w+)\s+(\S+)", ln)
        if m and m.group(1) in ("bloque", "hasta"):
            if m.group(1) == "bloque":
                bloque = m.group(2)
            else:
                hasta = m.group(2)
            continue
        cuerpo.append(ln)
    if not bloque:
        raise SystemExit("%s: le falta la cabecera '; @bloque ETIQUETA'" % ruta)
    return bloque, hasta, cuerpo


def main():
    if len(sys.argv) < 5:
        print(__doc__)
        return 2
    listado, dir_frag, salida, rom_orig = sys.argv[1:5]
    org = int(sys.argv[5], 0) if len(sys.argv) > 5 else 0x4000
    lineas = open(listado, encoding="utf-8").read().split("\n")
    fragmentos = sorted(glob.glob(os.path.join(dir_frag, "*.asm")))
    if not fragmentos:
        raise SystemExit("no hay fragmentos en %s" % dir_frag)

    # Cada sustitucion: (indice_inicio, indice_fin, dir_inicio, dir_fin, lineas, nombre)
    sust = []
    for ruta in fragmentos:
        bloque, hasta, cuerpo = lee_fragmento(ruta)
        i = indice_de(lineas, bloque)
        ini = direccion_de(lineas, i + 1)
        if hasta:
            j = indice_de(lineas, hasta)
            fin = direccion_de(lineas, j + 1)
            # los comentarios de cabecera de `hasta` son suyos, no del bloque
            while j > 0 and (lineas[j - 1].startswith(";") or lineas[j - 1].strip() == ""):
                j -= 1
        else:
            j = fin_de_bloque(lineas, i)
            k = siguiente_etiqueta(lineas, j)
            fin = direccion_de(lineas, k + 1) if k is not None else 0xC000
        nombre = os.path.basename(ruta)
        nuevas = [lineas[i], "; --- PARCHE: %s (0x%04X-0x%04X, %d bytes) ---"
                  % (nombre, ini, fin - 1, fin - ini)]
        nuevas += cuerpo
        nuevas += ["\tif $ != 0x%04X" % fin,
                   '\t.error "el parche de %s no acaba en 0x%04X"' % (bloque, fin),
                   "\tendif", ""]
        sust.append((i, j, ini, fin, nuevas, nombre))

    sust.sort()
    for a, b in zip(sust, sust[1:]):
        if a[1] > b[0]:
            raise SystemExit("los fragmentos %s y %s se solapan" % (a[5], b[5]))

    out = []
    pos = 0
    for i, j, ini, fin, nuevas, _ in sust:
        out += lineas[pos:i]
        out += nuevas
        pos = j
    out += lineas[pos:]
    open(salida, "w", encoding="utf-8").write("\n".join(out))

    binario = os.path.splitext(salida)[0] + ".bin"
    r = subprocess.run(["pasmo", "--bin", salida, binario], capture_output=True, text=True)
    if r.returncode != 0:
        print("FALLO: pasmo no ensambla el listado empalmado:")
        print((r.stderr or r.stdout)[:2000])
        return 1

    orig = open(rom_orig, "rb").read()
    nuevo = open(binario, "rb").read()
    if len(nuevo) != len(orig):
        print("FALLO: la ROM modificada mide %d bytes y la original %d" % (len(nuevo), len(orig)))
        return 1
    rangos = [(ini, fin, nombre) for _, _, ini, fin, _, nombre in sust]
    fuera = 0
    cambiados = {nombre: 0 for _, _, nombre in rangos}
    for k in range(len(orig)):
        if orig[k] == nuevo[k]:
            continue
        a = org + k
        for ini, fin, nombre in rangos:
            if ini <= a < fin:
                cambiados[nombre] += 1
                break
        else:
            fuera += 1
            if fuera <= 10:
                print("  byte cambiado FUERA de los bloques: 0x%04X (%02X -> %02X)"
                      % (a, orig[k], nuevo[k]))
    for ini, fin, nombre in rangos:
        print("  %-40s 0x%04X-0x%04X  %5d bytes, %5d cambiados"
              % (nombre, ini, fin - 1, fin - ini, cambiados[nombre]))
    total = sum(cambiados.values())
    print("ROM modificada: %s, %d bytes cambiados dentro de %d bloques, %d fuera"
          % (binario, total, len(rangos), fuera))
    if fuera:
        print("FALLO: el parche toca bytes fuera de sus bloques")
        return 1
    print("OK: fuera de los bloques sustituidos, la ROM es identica a la original")
    return 0


if __name__ == "__main__":
    sys.exit(main())
