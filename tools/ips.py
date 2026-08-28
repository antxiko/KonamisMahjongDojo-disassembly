#!/usr/bin/env python3
"""Parches IPS: crearlos, aplicarlos y comprobarlos.

PARA QUE: el parche de traduccion se publica como IPS, que es lo que entienden
los flashcarts, los emuladores y cualquier aplicador (Lunar IPS, Floating IPS,
romhacking). Ni la ROM original ni la modificada viajan en el repositorio, asi
que TODO lo que se distribuye es este fichero, y hay que poder demostrar que
original + parche = modificada byte a byte. Eso es lo que hace `check`, y lo
que corre el test.

El formato, entero: "PATCH", registros de (desplazamiento de 3 bytes, tamano
de 2 bytes, datos) o, con tamano 0, (cuantos de 2 bytes, byte) para rellenos,
y "EOF" al final. Un registro no puede empezar en el desplazamiento 0x454F46,
que se leeria como "EOF"; aqui no puede pasar (la ROM son 32 KB), pero se
comprueba igual. Los ficheros de un tamano distinto no se contemplan: la ROM
modificada mide lo mismo que la original, y `make` lo verifica.

Uso:
  ips.py make  <original> <modificada> <salida.ips>
  ips.py apply <original> <parche.ips> <salida>
  ips.py check <original> <parche.ips> <modificada>     (exit 1 si no cuadra)
  ips.py list  <parche.ips>                              (los registros)
"""
import hashlib
import sys

MAX_REG = 0xFFFF
UNIR = 6           # dos diferencias a menos de 6 bytes van en el mismo registro


def registros(a, b):
    """Los tramos en que b difiere de a, unidos si estan casi pegados."""
    assert len(a) == len(b), "los dos ficheros tienen que medir lo mismo"
    tramos = []
    i, n = 0, len(a)
    while i < n:
        if a[i] == b[i]:
            i += 1
            continue
        j = i
        while j < n and (a[j] != b[j] or any(a[k] != b[k] for k in range(j, min(j + UNIR, n)))):
            j += 1
        if tramos and i - tramos[-1][1] < UNIR:
            tramos[-1] = (tramos[-1][0], j)
        else:
            tramos.append((i, j))
        i = j
    return tramos


def make(a, b):
    out = bytearray(b"PATCH")
    for ini, fin in registros(a, b):
        while ini < fin:
            corte = min(fin, ini + MAX_REG)
            if ini == 0x454F46:              # se leeria como EOF: empezar un byte antes
                ini -= 1
            datos = b[ini:corte]
            if len(datos) >= 16 and len(set(datos)) == 1:
                out += ini.to_bytes(3, "big") + b"\x00\x00" + len(datos).to_bytes(2, "big") + datos[:1]
            else:
                out += ini.to_bytes(3, "big") + len(datos).to_bytes(2, "big") + datos
            ini = corte
    out += b"EOF"
    return bytes(out)


def leer(ips):
    assert ips[:5] == b"PATCH", "no es un IPS"
    p, regs = 5, []
    while ips[p:p + 3] != b"EOF":
        off = int.from_bytes(ips[p:p + 3], "big")
        tam = int.from_bytes(ips[p + 3:p + 5], "big")
        p += 5
        if tam == 0:
            cuantos = int.from_bytes(ips[p:p + 2], "big")
            regs.append((off, bytes([ips[p + 2]]) * cuantos, True))
            p += 3
        else:
            regs.append((off, ips[p:p + tam], False))
            p += tam
    return regs


def apply(a, ips):
    out = bytearray(a)
    for off, datos, _ in leer(ips):
        if off + len(datos) > len(out):
            out += bytes(off + len(datos) - len(out))
        out[off:off + len(datos)] = datos
    return bytes(out)


def sha(d):
    return hashlib.sha256(d).hexdigest()


def main():
    if len(sys.argv) < 3:
        print(__doc__)
        return 2
    orden = sys.argv[1]
    rd = lambda p: open(p, "rb").read()
    if orden == "make":
        a, b = rd(sys.argv[2]), rd(sys.argv[3])
        ips = make(a, b)
        assert apply(a, ips) == b, "el parche recien hecho no reproduce la modificada"
        open(sys.argv[4], "wb").write(ips)
        regs = leer(ips)
        print("%s: %d registros, %d bytes de parche, %d bytes cambiados"
              % (sys.argv[4], len(regs), len(ips), sum(len(d) for _, d, _ in regs)))
        return 0
    if orden == "apply":
        open(sys.argv[4], "wb").write(apply(rd(sys.argv[2]), rd(sys.argv[3])))
        return 0
    if orden == "check":
        a, ips, b = rd(sys.argv[2]), rd(sys.argv[3]), rd(sys.argv[4])
        r = apply(a, ips)
        print("original + parche : %d bytes  %s" % (len(r), sha(r)))
        print("modificada        : %d bytes  %s" % (len(b), sha(b)))
        if r == b:
            print("OK: original + parche = modificada, byte a byte")
            return 0
        dif = [i for i in range(min(len(r), len(b))) if r[i] != b[i]]
        print("DIFIERE en %d bytes (el primero en 0x%05X)" % (len(dif), dif[0] if dif else -1))
        return 1
    if orden == "list":
        for off, datos, rle in leer(rd(sys.argv[2])):
            print("  0x%05X  %5d bytes%s" % (off, len(datos), "  (relleno 0x%02X)" % datos[0] if rle else ""))
        return 0
    print(__doc__)
    return 2


if __name__ == "__main__":
    sys.exit(main())
