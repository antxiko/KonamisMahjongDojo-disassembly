#!/usr/bin/env python3
"""Localiza el marcador en la RAM comparando los volcados del demo.

Los 55 volcados de work/estados/ram/ son 0xE000-0xE3FF en cada estado por el
que pasa el demo. En pantalla el marcador va 30000/30000 al empezar, 29000 tras
el riichi y otros valores al cobrar, asi que basta con buscar esos numeros en
BCD y quedarse con las direcciones que los llevan EN TODOS los volcados donde
tocan y en ninguno donde no.

No se supone la codificacion: se prueban BCD de 3 bytes en los dos ordenes y
16 bits binarios, y se dice cual encaja.
"""
import glob
import os
import re

BASE = 0xE000
DIR = 'work/estados/ram'


def candidatas(valor):
    """Las tiras de bytes con que un marcador puede estar escrito."""
    d = '%06d' % valor                      # 030000
    bcd = bytes(int(d[i:i + 2], 16) for i in range(0, 6, 2))
    return {
        'BCD 3 bytes (alto->bajo)': bcd,
        'BCD 3 bytes (bajo->alto)': bcd[::-1],
        'binario 16 bits (bajo->alto)': (valor & 0xFFFF).to_bytes(2, 'little'),
    }


def carga():
    fs = sorted(glob.glob(os.path.join(DIR, '*.bin')))
    return [(os.path.basename(f)[:-4], open(f, 'rb').read()) for f in fs]


def main():
    volcados = carga()
    if not volcados:
        print('no hay volcados en %s' % DIR)
        return
    print('%d volcados de %d bytes desde 0x%04X\n' % (
        len(volcados), len(volcados[0][1]), BASE))

    for valor in (30000, 29000):
        print('=== %d ===' % valor)
        for nombre, patron in candidatas(valor).items():
            # Direcciones donde aparece, y en cuantos volcados.
            donde = {}
            for etiqueta, datos in volcados:
                for m in re.finditer(re.escape(patron), datos):
                    donde.setdefault(m.start(), []).append(etiqueta)
            if not donde:
                continue
            for off, ets in sorted(donde.items()):
                if len(ets) < 2:            # una sola vez suele ser casualidad
                    continue
                print('  %-30s 0x%04X en %2d volcados  (%s .. %s)' % (
                    nombre, BASE + off, len(ets), ets[0][:12], ets[-1][:12]))
        print()


main()
