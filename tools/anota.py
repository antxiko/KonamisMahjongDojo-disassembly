#!/usr/bin/env python3
"""Anade lineas al .notes sin riesgo de truncarlo ni de repetir comentarios.

    python3 tools/anota.py fichero_con_las_lineas
    python3 tools/anota.py --arregla        (solo junta lo que ya hay dentro)

Hace dos cosas que hacen falta:

1. ANADE DE VERDAD. `cat >> src/mahjong.notes <<'EOF'` en el Bash de esta
   maquina se comio el fichero dos veces en vez de anadir al final.

2. JUNTA LAS `C` DE LA MISMA DIRECCION. Una frase larga se escribe en varias
   lineas seguidas, pero mkasm solo se queda con una y el test
   `test_ningun_comentario_de_linea_repetido` las ve duplicadas. Aqui se juntan
   en una sola antes de escribir, que es lo que el listado va a mostrar.
"""
import sys

DESTINO = 'src/mahjong.notes'


def junta(texto):
    """Une las `C` consecutivas que van ancladas a la misma direccion."""
    salida, previa = [], None
    for ln in texto.splitlines():
        if (ln.startswith('C 0x') and previa is not None
                and previa.startswith('C 0x')
                and ln.split(None, 2)[1].lower() == previa.split(None, 2)[1].lower()):
            trozo = ln.split(None, 2)
            previa = previa.rstrip() + ' ' + (trozo[2].strip() if len(trozo) > 2 else '')
            continue
        if previa is not None:
            salida.append(previa)
        previa = ln
    if previa is not None:
        salida.append(previa)
    return '\n'.join(salida), len(texto.splitlines()) - len(salida)


def main():
    viejo = open(DESTINO, encoding='utf-8').read()
    if sys.argv[1:2] == ['--arregla']:
        texto, juntadas = junta(viejo)
        open(DESTINO, 'w', encoding='utf-8').write(texto.rstrip('\n') + '\n')
        print('%s: %d lineas juntadas' % (DESTINO, juntadas))
        return
    nuevo = open(sys.argv[1], encoding='utf-8').read()
    texto, juntadas = junta(nuevo)
    open(DESTINO, 'w', encoding='utf-8').write(
        viejo.rstrip('\n') + '\n\n' + texto.rstrip('\n') + '\n')
    print('%s: +%d lineas%s' % (DESTINO, len(texto.splitlines()),
          ' (%d juntadas por ir en la misma direccion)' % juntadas if juntadas else ''))


main()
