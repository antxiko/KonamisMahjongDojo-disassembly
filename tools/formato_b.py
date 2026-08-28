#!/usr/bin/env python3
"""El formato B del cartucho: descomprimir y COMPRIMIR.

Es el formato con el que el juego guarda los bloques grandes de VRAM
(patrones, colores, dibujos de la tabla de nombres) y lo interpreta 0x468F:

    destino (2 bytes, bajo primero)
    orden*  :  n con el bit 7 puesto  -> n & 0x7F bytes literales a continuacion
               n entre 1 y 0x7F       -> el byte siguiente, repetido n veces
               0x80                   -> viene otro destino (y siguen ordenes)
               0x00                   -> fin del bloque

El parche de traduccion tiene que REESCRIBIR bloques asi (la fuente katakana,
los patrones del tablero, los avisos), y para que quepan donde estaban hace
falta comprimirlos. La prueba de que el compresor es correcto esta en
`--prueba`: descomprime todos los bloques del cartucho, los vuelve a comprimir
y comprueba que descomprimen a lo mismo, y dice si el resultado mide igual,
mas o menos que el original.

Uso:
  formato_b.py <rom> <direccion>            describe el bloque
  formato_b.py <rom> --prueba               comprueba el compresor con todos
  (desde Python) descomprime(rom, addr) -> (tramos, fin); comprime(tramos) -> bytes
"""
import sys

ORG = 0x4000


def descomprime(rom, addr, org=ORG):
    """Devuelve ([(destino, bytes), ...], direccion_siguiente)."""
    p = addr - org
    tramos = []
    while True:
        de = rom[p] | (rom[p + 1] << 8)
        p += 2
        out = bytearray()
        while True:
            n = rom[p]
            p += 1
            if n == 0x00:
                tramos.append((de, bytes(out)))
                return tramos, org + p
            if n == 0x80:
                tramos.append((de, bytes(out)))
                break
            if n & 0x80:
                k = n & 0x7F
                out += rom[p:p + k]
                p += k
            else:
                out += bytes([rom[p]]) * n
                p += 1


def descomprime_hasta(rom, addr, hasta, org=ORG):
    """Cuantos bytes de salida produce el primer tramo del bloque de `addr`
    ANTES de llegar a la orden que empieza en `hasta`. Sirve para saber en que
    tile cae una segunda entrada al mismo bloque (0x93AA en el tercio de abajo)."""
    p = addr - org + 2
    n = 0
    while org + p < hasta:
        k = rom[p]
        p += 1
        if k in (0x00, 0x80):
            raise SystemExit("el tramo acaba antes de 0x%04X" % hasta)
        if k & 0x80:
            n += k & 0x7F
            p += k & 0x7F
        else:
            n += k
            p += 1
    if org + p != hasta:
        raise SystemExit("0x%04X cae en mitad de una orden del formato B" % hasta)
    return n


def comprime_tramo(datos):
    """Las ordenes de un tramo. Voraz: una tira de 3 o mas iguales va como
    repeticion (cuesta 2 bytes), lo demas como literal (1 byte por cada 127)."""
    out = bytearray()
    i, n = 0, len(datos)
    lit = bytearray()

    def vuelca_lit():
        nonlocal lit, out
        while lit:
            trozo = lit[:127]
            out.append(0x80 | len(trozo))
            out += trozo
            lit = lit[len(trozo):]

    while i < n:
        j = i
        while j < n and datos[j] == datos[i] and j - i < 127:
            j += 1
        if j - i >= 3:
            vuelca_lit()
            out.append(j - i)
            out.append(datos[i])
            i = j
        else:
            lit.append(datos[i])
            i += 1
    vuelca_lit()
    return bytes(out)


def comprime(tramos):
    out = bytearray()
    for k, (de, datos) in enumerate(tramos):
        out += bytes([de & 0xFF, de >> 8])
        out += comprime_tramo(datos)
        out.append(0x80 if k < len(tramos) - 1 else 0x00)
    return bytes(out)


def bloques_del_cartucho(ruta_notes):
    import re
    res = []
    for ln in open(ruta_notes, encoding="utf-8"):
        m = re.match(r"^D\s+0x([0-9A-Fa-f]+)\s+0x([0-9A-Fa-f]+)\s+(\S+)\s+(.*)", ln)
        if m and "Formato B" in m.group(4) and "SIN cabecera" not in m.group(4):
            res.append((int(m.group(1), 16), int(m.group(2), 16), m.group(3)))
    return res


def main():
    rom = open(sys.argv[1], "rb").read()
    if sys.argv[2] == "--prueba":
        import os
        notes = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "src", "mahjong.notes")
        mal = 0
        for ini, fin, nombre in bloques_del_cartucho(notes):
            tramos, sig = descomprime(rom, ini)
            nuevo = comprime(tramos)
            tramos2, _ = descomprime(nuevo, 0, org=0)
            ok = tramos2 == tramos
            tam = fin - ini
            marca = "OK " if ok else "MAL"
            if not ok:
                mal += 1
            print("%s 0x%04X %-34s original %5d B (fin leido 0x%04X)  recomprimido %5d B  salida %5d B"
                  % (marca, ini, nombre, tam, sig, len(nuevo), sum(len(d) for _, d in tramos)))
        print("bloques mal: %d" % mal)
        return 1 if mal else 0
    addr = int(sys.argv[2], 0)
    tramos, sig = descomprime(rom, addr)
    print("bloque 0x%04X-0x%04X (%d bytes), %d tramos" % (addr, sig - 1, sig - addr, len(tramos)))
    for de, datos in tramos:
        print("   destino 0x%04X: %d bytes" % (de, len(datos)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
