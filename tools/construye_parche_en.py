#!/usr/bin/env python3
"""Construye los fragmentos del parche de traduccion a partir de definiciones
legibles: textos, fuentes en arte ASCII y sustituciones de codigo.

PARA QUE: el parche se escribe UNA vez en un formato que se pueda leer y
corregir (src/parche_en/parche.txt y src/parche_en/fuentes/*.txt), y de ahi
salen los fragmentos .asm que tools/parchea.py empalma en el listado. Nadie
tiene que escribir a mano numeros de tile ni comprimir bloques.

EL FICHERO parche.txt. Secciones con cabecera entre corchetes; dentro, una
orden por linea; las lineas vacias y las que empiezan por '#' se ignoran.
Las secciones se procesan en orden: los digrafos de la fuente estrecha se
definen en una seccion [patrones] y se usan despues.

  [formatoA BLOQUE charset=NOMBRE]
      fFILA cCOL [charset] token token ...
          token: "texto" (se codifica con el charset) o {A1 B2 ...} (bytes tal cual)
      Cada linea es un destino de la lista de formato A (0x409F). Una linea
      con solo '---' cierra la lista y empieza otra en el mismo bloque (los
      tres avisos de 0x7865 son asi).

  [formatoB BLOQUE charset=NOMBRE]
      fFILA cCOL [charset] token token ...
      Igual, pero sale comprimido en formato B (0x468F), como los avisos.

  Las dos admiten `reubica=RUTINA`: el bloque no cabe en su hueco, asi que se
  aparca en la zona libre del final y el `ld hl,0XXXXh` de RUTINA se reapunta.
  El hueco original queda a 0xFF. Si no lo carga un `ld hl` sino una TABLA DE
  PUNTEROS, se anade `puntero_en=BLOQUE_DE_LA_TABLA` y lo que se cambia son los
  dos defb de su entrada (`reubica=` sigue haciendo falta para pedirlo).

  [cuerpos BLOQUE charset=NOMBRE]
      0xDIRECCION token token ...
      Cuerpos de formato A SIN destino (los lee 0x40A3 con DE ya puesto),
      cada uno en la direccion fija que el codigo tiene escrita; se rematan
      con 0xFF y los huecos se rellenan con 0xFF.

  [patrones BLOQUE base=rom|vacio destino=0xVRAM tiles=0xINI-0xFIN
            [cola=0xDIR reapunta=RUTINA] [reubica=RUTINA]]
      TILE glifo@fuente          un glifo de 8x8 de una fuente
      TILE-TILE glifo@fuente     un glifo GRANDE (16x24...) repartido por el rango
      TILE estrecho "AB"         dos letras de la fuente estrecha, en un tile;
                                 ademas registra el digrafo "AB" -> TILE
      TILE {8 bytes hex}         el patron tal cual
      TILE copia=OTRO_TILE       el mismo patron que otro tile del bloque
      Con base=rom se parte de lo que tiene el cartucho descomprimido y solo
      cambian los tiles nombrados. Sale comprimido en formato B. Si asi no cabe
      en su hueco, `reubica=RUTINA` lo aparca en la zona libre y reapunta el
      `ld hl` de RUTINA (el bloque lleva dentro su destino de VRAM, asi que se
      puede leer desde cualquier sitio); no se puede juntar con `cola`. Con `cola`,
      el bloque se lee dos veces (entera y desde `cola`): se recomprimen solo
      los tiles de antes de la cola, la cola va con sus bytes originales y la
      instruccion de RUTINA que entraba por `cola` se reapunta.

  [crudos BLOQUE destino=0xVRAM tiles=0xINI-0xFIN]
      Igual que patrones, pero el bloque va sin comprimir (los 56 bytes de 0x8A9F).

  [colores BLOQUE base=rom destino=0xVRAM tiles=0xINI-0xFIN]
      TILE 0xF1                  los 8 bytes de color del tile, todos iguales
      TILE-TILE 0xF1             un rango

  [codigo BLOQUE]
      viejo => nuevo             sustitucion literal en las lineas del bloque
                                 del listado (tiene que aparecer UNA vez)

  [nombres BLOQUE_NOMBRES BLOQUE_PUNTEROS charset=NOMBRE relleno=N]
      INDICE "NOMBRE"            los 39 nombres de jugada. El han de cada uno
                                 se copia del registro original; los nombres
                                 van a la zona libre y la tabla de punteros se
                                 reconstruye en su sitio.

  [libre BLOQUE org=0xXXXX fin=0xYYYY]
      La zona libre del cartucho donde se recolocan los bloques que no caben
      en su sitio. Se rellena con 0xFF hasta `fin`.

  [diapositiva NOMBRE charset=NOMBRE]
      fFILA cCOL [charset] token token ...
      @0xDIRECCION      [charset] token token ...   destino CRUDO de la VRAM
      token <glifo@fuente>: los ocho bytes del patron de un glifo de 8x8
      centro fFILA [charset] token ...        texto centrado en las 32 columnas
      fichas centro fFILA MAN1 SOU5 ...      hilera de fichas centrada
      fichas fFILA cCOL MAN1 SOU5 DORSO ...   una hilera de fichas del mahjong,
          por su palo y numero (MAN/PIN/SOU/HON, mas DORSO y HUECO). Los tiles
          salen de la tabla 0x4735 de la ROM: no se escriben a mano.
      Como [formatoA], pero el bloque es NUEVO: no sustituye a nada del
      cartucho, se aparca en la zona libre con la etiqueta NOMBRE y el codigo
      de [asmlibre] la llama por ese nombre. Es lo que pinta cada pantalla del
      modo attract.

  [tilesnuevos NOMBRE patrones=0xDIR colores=0xDIR a=0xTILE [tercio=N]]
      MAN1 SOU5 HON1 ...
      Carga en la VRAM los tiles de unas fichas que en esa pantalla NO estan,
      REUBICADOS a partir del tile `a`: sus numeros de siempre los ocupa otra
      cosa (en la pantalla del final, el alfabeto del parche pisa justo los
      honores). Los patrones y los colores salen de dos bloques de formato B
      de la ROM ORIGINAL, y el bloque nuevo sale comprimido tambien en formato
      B, para el interprete de 0x468F. Las fichas nombradas tienen que ocupar
      tiles SEGUIDOS. A partir de la seccion, las diapositivas las piden por su
      nombre de siempre y salen los tiles nuevos.

  [asmlibre NOMBRE]
      lineas de ensamblador que se ensamblan AL FINAL de la zona libre, detras
      de los bloques reubicados. Para meter codigo NUEVO en el cartucho (el
      modo attract del paso 6). Las etiquetas las resuelve pasmo, asi que el
      codigo puede llamar a rutinas del cartucho por su nombre y a los bloques
      reubicados por el suyo (`X_en_ingles`). Si no cabe, el `defs` de cierre
      sale negativo y pasmo se planta.

  [asm BLOQUE [hasta=BLOQUE2]]
      lineas de ensamblador tal cual

Los charsets estan en CHARSETS, abajo: cada uno dice que numero de tile es
cada caracter en la pantalla donde se usa. El charset `digrafos` se construye
solo, con los tiles `estrecho` definidos antes: codifica un texto de dos en
dos letras.

Uso: construye_parche_en.py <parche.txt> <dir_fuentes> <listado.asm> <notes>
                             <rom> <dir_salida>
"""
import os
import re
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import formato_b  # noqa: E402

ORG = 0x4000


# ---------------------------------------------------------------- charsets
def _mapa(letras_en, digitos_en, espacio, extra):
    m = {}
    for i in range(26):
        m[chr(65 + i)] = letras_en + i
    for i in range(10):
        m[str(i)] = digitos_en + i
    m[" "] = espacio
    m.update(extra)
    return m


def _lista(tiles, digitos_en, espacio):
    """A-Z en los 26 tiles que se le den, que NO tienen por que ser seguidos."""
    t = [int(x, 16) for x in tiles.split()]
    if len(t) != 26:
        raise SystemExit("un charset por lista necesita 26 tiles y tiene %d" % len(t))
    m = {chr(65 + i): t[i] for i in range(26)}
    if digitos_en is not None:
        for i in range(10):
            m[str(i)] = digitos_en + i
    m[" "] = espacio
    return m


def _letras(letras, tiles, espacio):
    """Solo unas letras sueltas, cada una en su tile. Para los rotulos que no
    necesitan el alfabeto entero y andan justos de sitio."""
    t = [int(x, 16) for x in tiles.split()]
    if len(t) != len(letras):
        raise SystemExit("%r son %d letras y hay %d tiles" % (letras, len(letras), len(t)))
    m = {c: t[i] for i, c in enumerate(letras)}
    m[" "] = espacio
    return m


CHARSETS = {
    # la fuente grande del cartucho en su copia alta (0xC0-0xEF): el menu del titulo
    "alto0": _mapa(0xD1, 0xC0, 0x00, {"-": 0xD0, '"': 0xEB, "(c)": 0xCA}),
    # la misma en la copia baja (0x10-0x3F) con el negro (0x00) de espacio
    "bajo0": _mapa(0x21, 0x10, 0x00, {"-": 0x20, '"': 0x3B}),
    # y con el blanco de la mesa (tile 1) de espacio
    "bajo1": _mapa(0x21, 0x10, 0x01, {"-": 0x20}),
    # La fuente nueva del RECUENTO, en el sitio de la katakana (tiles 0x30-0x7F
    # del tercio de arriba). Los digitos NO son suyos: son los de la fuente
    # grande, que ya esta cargada en 0x10-0x19 y la katakana no llega a pisar.
    "recuento": _mapa(0x30, 0x10, 0x01, {"-": 0x4A, "/": 0x4B, ".": 0x4C, "+": 0x4D}),
    # LA BARRA de la mesa (tercio del medio). Aqui los tiles NO son contiguos:
    # el texto de ese tercio vive en las filas del medio de las fichas, que son
    # pares sueltos (b+2, b+3). Estos 26 son los que llevan color 0xF1, blanco
    # sobre negro, que es como se ve la barra. Los digitos siguen en 0x10-0x19
    # y el blanco es el tile 0x01.
    "barra": _lista("72 73 78 79 7E 7F 84 85 8A 8B 90 91 96 97 9C 9D "
                    "A2 A3 A8 A9 AE AF B4 B5 BA BB", 0x10, 0x01),
    # EL MENU y las cajas del mismo tercio: los tiles de color 0x17, negro
    # sobre cian. Son 21 con ese color de fabrica y cinco -D2 D3 D8 D9 DE- a
    # los que el parche les cambia el color, porque el dora y el ura pasan a
    # escribirse con las letras de la barra.
    "cajas": _lista("49 4F 54 55 5A 5B 60 61 66 67 6C 6D E4 E5 EB F0 F1 F6 "
                    "F7 FC FD D2 D3 D8 D9 DE", None, 0x02),
    # Los tres rotulos de dificultad, en rojo sobre negro (color 0x91). Solo
    # hacen falta las siete letras de AMA / PRO / SEM.
    "dificultad": _letras("AMPROSE", "2A 2B 30 31 36 37 3C", 0x01),
}
DIGRAFOS = {}          # "AB" -> tile, lo llenan las lineas `estrecho`
FUENTES = {}           # nombre -> glifos, para el token <glifo@fuente>
PRIMER_TILE = {}       # "MAN1" -> primer tile del dibujo, de la tabla 0x4735

# Los cuatro palos tal como los codifica el cartucho: el palo va en el nibble
# alto y el numero en el bajo (0x01-0x09 caracteres, 0x11-0x19 circulos,
# 0x21-0x29 bambues, 0x31-0x37 honores), y con ese codigo se indexa la tabla
# de 0x4735, que devuelve el PRIMER TILE de los seis que dibujan la ficha.
PALOS = [("MAN", 0x00, 9), ("PIN", 0x10, 9), ("SOU", 0x20, 9), ("HON", 0x30, 7)]


def lee_las_fichas(rom, org=0x4000):
    """Llena PRIMER_TILE leyendo la tabla 0x4735 de la ROM, no a mano."""
    base = 0x4735 - org
    for nombre, alto, cuantas in PALOS:
        for n in range(1, cuantas + 1):
            PRIMER_TILE["%s%d" % (nombre, n)] = rom[base + alto + n]
    PRIMER_TILE["DORSO"] = rom[base + 0x38]
    PRIMER_TILE["HUECO"] = rom[base + 0x39]


def tiles_de_la_rom(rom, dir_patrones, dir_colores, ini, fin):
    """Los patrones y los colores de un rango de tiles, sacados de los bloques
    de formato B del cartucho ORIGINAL.

    Hay que ir a la ROM y no a un volcado del emulador ni al bloque ya
    parcheado: el charset `cajas` mete letras en los tiles 0x49, 0x4F, 0x54 y
    0x55, que caen justo dentro del rango de los honores."""
    salida = []
    for direccion in (dir_patrones, dir_colores):
        tramos, _ = formato_b.descomprime(rom, direccion)
        destino, datos = tramos[0]
        base = (destino & 0x7FF) // 8          # el primer tile del tramo
        if ini < base or (fin + 1 - base) * 8 > len(datos):
            raise SystemExit("los tiles 0x%02X-0x%02X no caben en el bloque de 0x%04X"
                             % (ini, fin, direccion))
        salida.append(datos[(ini - base) * 8:(fin + 1 - base) * 8])
    return salida


def filas_de_fichas(fila, col, nombres):
    """Una hilera de fichas -> las TRES entradas de formato A que la pintan.

    Cada ficha son seis tiles seguidos, dos de ancho por tres de alto y por
    filas (0x6F72), asi que la hilera se pinta en tres tiras horizontales."""
    out = []
    for k in range(3):
        datos = bytearray()
        for nombre in nombres:
            if nombre not in PRIMER_TILE:
                raise SystemExit("no existe la ficha %s" % nombre)
            t = PRIMER_TILE[nombre]
            datos += bytes([t + k * 2, t + k * 2 + 1])
        out.append((vram(fila + k, col), bytes(datos)))
    return out


# ------------------------------------------------------------------ fuentes
def lee_fuente(ruta, ancho, alto):
    """Un fichero de glifos en arte ASCII -> {nombre: [filas]}."""
    glifos, g, filas = {}, None, []
    for ln in open(ruta, encoding="utf-8"):
        ln = ln.rstrip("\n")
        if ln.startswith("glifo "):
            if g is not None:
                glifos[g] = filas
            g, filas = ln[6:].strip(), []
        elif ln == "" or ln == "#" or ln.startswith("# "):
            continue
        elif re.fullmatch(r"[#.]+", ln):
            if len(ln) != ancho:
                raise SystemExit("%s: el glifo %s tiene una fila de %d columnas" % (ruta, g, len(ln)))
            filas.append(ln)
        else:
            raise SystemExit("%s: linea rara: %r" % (ruta, ln))
    if g is not None:
        glifos[g] = filas
    for g, filas in glifos.items():
        if len(filas) != alto:
            raise SystemExit("%s: el glifo %s tiene %d filas y no %d" % (ruta, g, len(filas), alto))
    return glifos


def lee_fuentes(dir_fuentes):
    """estrecha.txt son glifos de 3x7; NOMBRE_16x24.txt de 16x24; el resto 8x8."""
    fuentes = {}
    for f in sorted(os.listdir(dir_fuentes)):
        if not f.endswith(".txt"):
            continue
        nombre = f[:-4]
        if nombre == "estrecha":
            fuentes[nombre] = lee_fuente(os.path.join(dir_fuentes, f), 3, 7)
            continue
        m = re.match(r"(\w+)_(\d+)x(\d+)$", nombre)
        if m:
            fuentes[m.group(1)] = lee_fuente(os.path.join(dir_fuentes, f), int(m.group(2)), int(m.group(3)))
        else:
            fuentes[nombre] = lee_fuente(os.path.join(dir_fuentes, f), 8, 8)
    return fuentes


def filas_a_bytes(filas):
    return bytes(sum(0x80 >> k for k, c in enumerate(f) if c == "#") for f in filas)


def tile_estrecho(estrecha, texto):
    """Dos letras de la fuente estrecha (3x7) en un tile de 8x8: columnas 0-2 y
    4-6, fila 0 vacia. Con una sola letra, la segunda queda en blanco."""
    if len(texto) > 2:
        raise SystemExit("un tile estrecho lleva dos letras como mucho: %r" % texto)
    filas = ["........"]
    for y in range(7):
        fila = ""
        for i in range(2):
            c = texto[i] if i < len(texto) else " "
            nombre = "espacio" if c == " " else c
            if nombre not in estrecha:
                raise SystemExit("la fuente estrecha no tiene el glifo %r" % c)
            fila += estrecha[nombre][y] + "."
        filas.append(fila)
    return filas_a_bytes(filas)


# ------------------------------------------------------------ codificacion
def tokens(linea):
    """'"texto" {A1 B2} <A@fuente>' -> lista de ('t', texto) / ('b', bytes).

    El token <glifo@fuente> son los OCHO BYTES del patron de ese glifo: sirve
    para escribir directamente en la tabla de patrones del VDP, que es como el
    attract se carga los tiles que le faltan sin tocar nada del cartucho."""
    out = []
    for m in re.finditer(r'"([^"]*)"|\{([^}]*)\}|<([^>]*)>', linea):
        if m.group(1) is not None:
            out.append(("t", m.group(1)))
        elif m.group(2) is not None:
            out.append(("b", bytes(int(h, 16) for h in m.group(2).split())))
        else:
            glifo, _, fuente = m.group(3).partition("@")
            if fuente not in FUENTES or glifo not in FUENTES[fuente]:
                raise SystemExit("no existe el glifo %s@%s" % (glifo, fuente))
            filas = FUENTES[fuente][glifo]
            if len(filas) != 8 or len(filas[0]) != 8:
                raise SystemExit("<%s> no es de 8x8: mide %dx%d" % (m.group(3), len(filas[0]), len(filas)))
            out.append(("b", filas_a_bytes(filas)))
    return out


def codifica(texto, charset):
    if charset == "digrafos":
        out = bytearray()
        t = texto.upper()
        if len(t) % 2:
            t += " "
        for i in range(0, len(t), 2):
            par = t[i:i + 2]
            if par not in DIGRAFOS:
                raise SystemExit("no hay tile estrecho para el digrafo %r (en %r)" % (par, texto))
            out.append(DIGRAFOS[par])
        return bytes(out)
    if charset not in CHARSETS:
        raise SystemExit("charset desconocido: %r" % charset)
    m = CHARSETS[charset]
    out = bytearray()
    i = 0
    while i < len(texto):
        if texto.startswith("(c)", i):
            out.append(m["(c)"])
            i += 3
            continue
        c = texto[i].upper()
        if c not in m:
            raise SystemExit("el charset %s no tiene el caracter %r (en %r)" % (charset, c, texto))
        out.append(m[c])
        i += 1
    return bytes(out)


def vram(fila, col):
    return 0x3800 + fila * 32 + col


RE_POS = re.compile(r"^f(\d+)\s+c(\d+)\s+(\w+)?\s*(.*)$")


def es_charset(nombre):
    return nombre in CHARSETS or nombre == "digrafos"


def cuerpo_de(resto, charset):
    datos = bytearray()
    for tipo, valor in tokens(resto):
        datos += codifica(valor, charset) if tipo == "t" else valor
    return bytes(datos)


RE_CRUDO = re.compile(r"^@(0x[0-9A-Fa-f]+)\s+(\w+)?\s*(.*)$")
RE_FICHAS = re.compile(r"^fichas\s+f(\d+)\s+c(\d+)\s+(.*)$")
RE_CENTRO = re.compile(r"^centro\s+f(\d+)\s+(\w+)?\s*(.*)$")
RE_FICENTRO = re.compile(r"^fichas\s+centro\s+f(\d+)\s+(.*)$")


def lineas_de_texto(lineas, charset_defecto):
    """Las lineas 'fF cC [charset] tokens' -> [(vram, bytes)].

    Una linea puede dar el destino CRUDO como '@0xDIR' en vez de fila/columna:
    hace falta para escribir fuera de la tabla de nombres -en las tablas de
    patrones y de colores del VDP-, que es como el attract carga sus tiles."""
    out = []
    for ln in lineas:
        fc = RE_FICENTRO.match(ln)
        if fc:
            # una hilera de fichas centrada: cada ficha son DOS columnas
            nombres = fc.group(2).split()
            out += filas_de_fichas(int(fc.group(1)), (32 - 2 * len(nombres)) // 2, nombres)
            continue
        f = RE_FICHAS.match(ln)
        if f:
            out += filas_de_fichas(int(f.group(1)), int(f.group(2)), f.group(3).split())
            continue
        ce = RE_CENTRO.match(ln)
        if ce:
            # texto CENTRADO en las 32 columnas: la columna la calcula el
            # generador, que en un tutorial de trece pantallas es la diferencia
            # entre poder reescribir una frase y tener que recontar a mano.
            cs = ce.group(2) if ce.group(2) and es_charset(ce.group(2)) else charset_defecto
            resto = ln[ce.end(2):] if (ce.group(2) and es_charset(ce.group(2))) else ln[ce.end(1):]
            datos = cuerpo_de(resto, cs)
            if len(datos) > 32:
                raise SystemExit("no cabe centrado, %d celdas de 32: %r" % (len(datos), ln))
            out.append((vram(int(ce.group(1)), (32 - len(datos)) // 2), datos))
            continue
        c = RE_CRUDO.match(ln)
        if c:
            cs = c.group(2) if c.group(2) and es_charset(c.group(2)) else charset_defecto
            resto = ln[c.end(2):] if (c.group(2) and es_charset(c.group(2))) else ln[c.end(1):]
            out.append((int(c.group(1), 16), cuerpo_de(resto, cs)))
            continue
        m = RE_POS.match(ln)
        if not m:
            raise SystemExit("linea de texto rara: %r" % ln)
        f, c = int(m.group(1)), int(m.group(2))
        if m.group(3) and es_charset(m.group(3)):
            cs, resto = m.group(3), ln[m.end(3):]
        else:
            cs, resto = charset_defecto, ln[m.end(2):]
        out.append((vram(f, c), cuerpo_de(resto, cs)))
    return out


def formato_a(entradas):
    out = bytearray()
    for k, (de, datos) in enumerate(entradas):
        if k:
            out.append(0xFE)
        out += bytes([de & 0xFF, de >> 8]) + datos
    out.append(0xFF)
    return bytes(out)


# --------------------------------------------------------------- el listado
def bloques_de_las_notas(ruta_notes):
    """{nombre: (ini, fin)} de las lineas D de las notas."""
    res = {}
    for ln in open(ruta_notes, encoding="utf-8"):
        m = re.match(r"^D\s+0x([0-9A-Fa-f]+)\s+0x([0-9A-Fa-f]+)\s+(\S+)", ln)
        if m:
            res[m.group(3)] = (int(m.group(1), 16), int(m.group(2), 16))
    return res


def lineas_del_bloque(listado, etiqueta):
    """Las lineas del listado que forman el bloque `etiqueta` (hasta la
    siguiente etiqueta global o comentario de bloque), sin la etiqueta."""
    for i, ln in enumerate(listado):
        if ln.startswith(etiqueta + ":"):
            j = i + 1
            while j < len(listado) and not (re.match(r"^[A-Za-z_.][\w.]*:", listado[j])
                                            or listado[j].startswith(";")):
                j += 1
            return listado[i + 1:j]
    raise SystemExit("no existe %s en el listado" % etiqueta)


def sustituye(lineas, pares, bloque):
    texto = "\n".join(lineas)
    for viejo, nuevo in pares:
        if texto.count(viejo) != 1:
            raise SystemExit("%s: %r aparece %d veces y no una" % (bloque, viejo, texto.count(viejo)))
        texto = texto.replace(viejo, nuevo)
    return texto.split("\n")


# ------------------------------------------------------------------- salida
TAB = "\t"


def defb(datos, comentario=None):
    out = []
    for i in range(0, len(datos), 16):
        out.append(TAB + "defb " + ",".join("0%02xh" % b for b in datos[i:i + 16]))
    if comentario:
        out.insert(0, "; " + comentario)
    return out


def relleno(n):
    return [TAB + "defs %d,0ffh" % n] if n > 0 else []


def mete_en_la_zona_libre(libre, bloque, datos, tal_cual=False):
    """Aparca `datos` en la zona libre del final y devuelve su direccion.

    Con tal_cual la etiqueta es el nombre pelado (lo quieren las diapositivas
    del attract, que son bloques NUEVOS y no la version inglesa de nada)."""
    if libre is None:
        raise SystemExit("%s: hace falta una seccion [libre] ANTES para reubicar" % bloque)
    org = libre[1] + sum(len(d) for _, d in libre[3])
    nombre = bloque[5:] if bloque.startswith("DATA_") else bloque
    libre[3].append((nombre if tal_cual else nombre + "_en_ingles", datos))
    return org


PARCHEADAS = {}     # rutina -> sus lineas ya sustituidas
NFRAG = {}          # rutina -> el numero de fragmento que le toco la primera vez


def reapunta_rutina(listado, dir_salida, n, rutina, pares):
    """Sustituye en una rutina ACUMULANDO: dos secciones pueden tocar la misma
    -el bloque de patrones del tablero y el de sus colores los carga los dos
    pinta_el_tablero-, y la segunda tiene que partir de lo que dejo la primera
    o le borra el cambio. Siempre se escribe el mismo fichero de fragmento."""
    base = PARCHEADAS.get(rutina) or lineas_del_bloque(listado, rutina)
    lineas = sustituye(base, pares, rutina)
    PARCHEADAS[rutina] = lineas
    escribe_fragmento(dir_salida, NFRAG.setdefault(rutina, n), rutina, lineas)
    return lineas


def escribe_fragmento(dir_salida, n, bloque, lineas, hasta=None):
    ruta = os.path.join(dir_salida, "%02d_%s.asm" % (n, bloque))
    cab = ["; @bloque %s" % bloque]
    if hasta:
        cab.append("; @hasta %s" % hasta)
    open(ruta, "w", encoding="utf-8").write("\n".join(cab + lineas) + "\n")
    return ruta


def lee_secciones(ruta):
    secciones = []
    for ln in open(ruta, encoding="utf-8"):
        ln = ln.rstrip("\n")
        if not ln.strip() or ln.lstrip().startswith("#"):
            continue
        m = re.match(r"^\[(\w+)\s*([^\]]*)\]$", ln.strip())
        if m:
            args, pos = {}, []
            for p in m.group(2).split():
                if "=" in p:
                    k, v = p.split("=", 1)
                    args[k] = v
                else:
                    pos.append(p)
            secciones.append((m.group(1), pos, args, []))
        else:
            if not secciones:
                raise SystemExit("linea fuera de seccion: %r" % ln)
            secciones[-1][3].append(ln.strip())
    return secciones


# --------------------------------------------------------------------- main
def main():
    if len(sys.argv) < 7:
        print(__doc__)
        return 2
    ruta_parche, dir_fuentes, ruta_listado, ruta_notes, ruta_rom, dir_salida = sys.argv[1:7]
    rom = open(ruta_rom, "rb").read()
    listado = open(ruta_listado, encoding="utf-8").read().split("\n")
    bloques = bloques_de_las_notas(ruta_notes)
    fuentes = lee_fuentes(dir_fuentes)
    FUENTES.update(fuentes)
    lee_las_fichas(rom)
    os.makedirs(dir_salida, exist_ok=True)
    for f in os.listdir(dir_salida):
        if f.endswith(".asm"):
            os.remove(os.path.join(dir_salida, f))

    def tamano(bloque):
        # en el listado las etiquetas de datos llevan DATA_ delante; en las notas no
        clave = bloque[5:] if bloque.startswith("DATA_") else bloque
        if clave not in bloques:
            raise SystemExit("el bloque %s no esta en las notas" % bloque)
        ini, fin = bloques[clave]
        return ini, fin, fin - ini

    libre = None          # [bloque, org, fin, [(nombre, bytes)], [lineas asm]]
    informe = []
    n = 0

    for tipo, pos, args, cuerpo in lee_secciones(ruta_parche):
        n += 1

        if tipo == "libre":
            libre = [pos[0], int(args["org"], 0), int(args["fin"], 0), [], []]
            continue

        if tipo == "asmlibre":
            if libre is None:
                raise SystemExit("asmlibre: hace falta una seccion [libre] ANTES")
            libre[4] += ["", "; ---- %s ----" % pos[0]] + cuerpo
            informe.append("%-38s asm en la zona libre, %d lineas" % (pos[0], len(cuerpo)))
            continue

        if tipo == "diapositiva":
            # Una lista de formato A NUEVA, que no sustituye a ningun bloque del
            # cartucho: se aparca en la zona libre con su nombre y el codigo del
            # attract la llama por la etiqueta.
            nombre = pos[0]
            cs = args.get("charset")
            datos = bytearray()
            listas = [[]]
            for ln in cuerpo:
                if ln == "---":
                    listas.append([])
                else:
                    listas[-1].append(ln)
            for lista in listas:
                datos += formato_a(lineas_de_texto(lista, cs))
            org = mete_en_la_zona_libre(libre, nombre, bytes(datos), tal_cual=True)
            informe.append("%-38s diapositiva, %4d bytes -> 0x%04X" % (nombre, len(datos), org))
            continue

        if tipo == "tilesnuevos":
            # Fichas que en ESTA pantalla no se pueden dibujar porque sus tiles
            # de siempre estan ocupados: se cargan en un hueco libre y a partir
            # de aqui las diapositivas las piden por su nombre de siempre.
            nombre = pos[0]
            fichas = " ".join(cuerpo).split()
            for f in fichas:
                if f not in PRIMER_TILE:
                    raise SystemExit("%s: no existe la ficha %s" % (nombre, f))
            primeros = [PRIMER_TILE[f] for f in fichas]
            ini, fin = min(primeros), max(primeros) + 5
            if fin - ini + 1 != 6 * len(fichas):
                raise SystemExit("%s: los tiles de %s no van seguidos en la ROM"
                                 % (nombre, " ".join(fichas)))
            patrones, colores = tiles_de_la_rom(
                rom, int(args["patrones"], 0), int(args["colores"], 0), ini, fin)
            a, tercio = int(args["a"], 0), int(args.get("tercio", "0"), 0)
            if a + (fin - ini) > 0xFF:
                raise SystemExit("%s: los tiles no caben a partir de 0x%02X" % (nombre, a))
            datos = formato_b.comprime([(0x6000 + tercio * 0x800 + a * 8, patrones),
                                        (0x4000 + tercio * 0x800 + a * 8, colores)])
            org = mete_en_la_zona_libre(libre, nombre, datos, tal_cual=True)
            for f, primero in zip(fichas, primeros):
                PRIMER_TILE[f] = primero - ini + a
            informe.append("%-38s %d fichas, tiles 0x%02X-0x%02X -> 0x%02X, %4d bytes -> 0x%04X"
                           % (nombre, len(fichas), ini, fin, a, len(datos), org))
            continue

        if tipo in ("formatoA", "formatoB"):
            bloque = pos[0]
            ini, fin, tam = tamano(bloque)
            cs = args.get("charset")
            datos = bytearray()
            listas = [[]]
            for ln in cuerpo:
                if ln == "---":
                    listas.append([])
                else:
                    listas[-1].append(ln)
            for lista in listas:
                entradas = lineas_de_texto(lista, cs)
                datos += formato_a(entradas) if tipo == "formatoA" else formato_b.comprime(entradas)
            if "reubica" in args:
                # No cabe en su hueco (o no queremos que quepa): el bloque se va
                # a la zona libre del final y la instruccion que lo carga se
                # reapunta. El hueco original queda a 0xFF.
                nuevo = mete_en_la_zona_libre(libre, bloque, bytes(datos))
                rutina = args["reubica"]
                if "puntero_en" in args:
                    # no lo carga un `ld hl` sino una TABLA de punteros: lo que
                    # hay que cambiar son los dos defb de su entrada
                    reapunta_rutina(listado, dir_salida, n, args["puntero_en"],
                                    [("defb 0%02xh,0%02xh" % (ini & 0xFF, ini >> 8),
                                      "defb 0%02xh,0%02xh" % (nuevo & 0xFF, nuevo >> 8))])
                else:
                    reapunta_rutina(listado, dir_salida, n, rutina,
                                    [("0%04xh" % ini, "0%04xh" % nuevo)])
                escribe_fragmento(dir_salida, n, bloque,
                                  ["; reubicado en 0x%04X: no cabia en sus %d bytes" % (nuevo, tam)]
                                  + relleno(tam))
                informe.append("%-38s %-8s %4d bytes -> 0x%04X (su hueco eran %d)"
                               % (bloque, tipo, len(datos), nuevo, tam))
                continue
            if len(datos) > tam:
                raise SystemExit("%s: %d bytes y solo caben %d (usa reubica=RUTINA)" % (bloque, len(datos), tam))
            lineas = defb(datos, "%s: %d de %d bytes" % (tipo, len(datos), tam)) + relleno(tam - len(datos))
            escribe_fragmento(dir_salida, n, bloque, lineas)
            informe.append("%-38s %-8s %4d/%4d bytes" % (bloque, tipo, len(datos), tam))
            continue

        if tipo == "cuerpos":
            bloque = pos[0]
            ini, fin, tam = tamano(bloque)
            cs = args.get("charset")
            datos = bytearray(b"\xFF" * tam)
            ocupado = [False] * tam
            for ln in cuerpo:
                m = re.match(r"^(0x[0-9A-Fa-f]+)\s+(.*)$", ln)
                if not m:
                    raise SystemExit("%s: linea rara: %r" % (bloque, ln))
                a = int(m.group(1), 16)
                b = cuerpo_de(m.group(2), cs) + b"\xFF"
                off = a - ini
                if off < 0 or off + len(b) > tam:
                    raise SystemExit("%s: el cuerpo de 0x%04X se sale del bloque" % (bloque, a))
                if any(ocupado[off:off + len(b)]):
                    raise SystemExit("%s: el cuerpo de 0x%04X pisa otro" % (bloque, a))
                datos[off:off + len(b)] = b
                for k in range(off, off + len(b)):
                    ocupado[k] = True
            escribe_fragmento(dir_salida, n, bloque, defb(bytes(datos), "cuerpos de formato A a direccion fija"))
            informe.append("%-38s cuerpos  %4d bytes" % (bloque, tam))
            continue

        if tipo in ("patrones", "colores", "crudos"):
            bloque = pos[0]
            ini, fin, tam = tamano(bloque)
            destino = int(args["destino"], 0)
            t_ini, t_fin = (int(x, 0) for x in args["tiles"].split("-"))
            ntiles = t_fin - t_ini + 1
            if tipo == "crudos":
                tramos = [(destino, rom[ini - ORG:fin - ORG])]
            elif args.get("base", "rom") == "rom":
                tramos, _ = formato_b.descomprime(rom, ini)
            else:
                tramos = [(destino, bytes(ntiles * 8))]
            if len(tramos) != 1 or tramos[0][0] != destino or len(tramos[0][1]) != ntiles * 8:
                raise SystemExit("%s: el bloque del cartucho no es un tramo de %d tiles a 0x%04X"
                                 % (bloque, ntiles, destino))
            original = tramos[0][1]
            datos = bytearray(original)
            for ln in cuerpo:
                partes = ln.split(None, 1)
                rango, resto = partes[0], (partes[1] if len(partes) > 1 else "")
                if "-" in rango:
                    a, b = (int(x, 16) for x in rango.split("-"))
                else:
                    a = b = int(rango, 16)
                for t in range(a, b + 1):
                    off = (t - t_ini) * 8
                    if not 0 <= off < len(datos):
                        raise SystemExit("%s: el tile %02X no esta en %s" % (bloque, t, args["tiles"]))
                    if tipo == "colores":
                        datos[off:off + 8] = bytes([int(resto, 0)]) * 8
                    elif resto.startswith("{"):
                        datos[off:off + 8] = bytes(int(h, 16) for h in resto.strip("{}").split())
                    elif resto.startswith("copia="):
                        src = (int(resto[6:], 16) - t_ini) * 8
                        datos[off:off + 8] = datos[src:src + 8]
                    elif resto.startswith("estrecho "):
                        texto = re.search(r'"([^"]*)"', resto).group(1)
                        datos[off:off + 8] = tile_estrecho(fuentes["estrecha"], texto)
                        DIGRAFOS[(texto + " ")[:2].upper()] = t
                    elif "@" in resto:
                        glifo, fuente = resto.split("@")
                        if fuente not in fuentes or glifo not in fuentes[fuente]:
                            raise SystemExit("%s: no existe el glifo %s@%s" % (bloque, glifo, fuente))
                        filas = fuentes[fuente][glifo]
                        ancho, alto = len(filas[0]) // 8, len(filas) // 8
                        if ancho * alto > 1:
                            if b - a + 1 != ancho * alto:
                                raise SystemExit("%s: %s mide %d tiles y el rango %s tiene %d"
                                                 % (bloque, glifo, ancho * alto, rango, b - a + 1))
                            fy, fx = divmod(t - a, ancho)
                            sub = [fila[fx * 8:fx * 8 + 8] for fila in filas[fy * 8:fy * 8 + 8]]
                            datos[off:off + 8] = filas_a_bytes(sub)
                        else:
                            datos[off:off + 8] = filas_a_bytes(filas)
                    else:
                        raise SystemExit("%s: orden rara: %r" % (bloque, ln))

            if tipo == "crudos":
                if len(datos) != tam:
                    raise SystemExit("%s: %d bytes crudos y el bloque mide %d" % (bloque, len(datos), tam))
                escribe_fragmento(dir_salida, n, bloque,
                                  defb(bytes(datos), "patrones crudos: %d tiles a 0x%04X" % (ntiles, destino)))
                informe.append("%-38s crudos   %4d bytes" % (bloque, tam))
                continue

            if "cola" in args:
                # El bloque se lee DOS veces: entero desde su principio, y desde
                # `cola` como flujo para otro uso. Se recomprimen solo los tiles
                # de antes de la cola; la cola va con sus bytes originales, y la
                # instruccion que entraba por `cola` se reapunta.
                cola = int(args["cola"], 0)
                previos = formato_b.descomprime_hasta(rom, ini, cola)
                if previos % 8:
                    raise SystemExit("%s: la cola 0x%04X no cae en frontera de tile" % (bloque, cola))
                nt = previos // 8
                if bytes(datos[nt * 8:]) != original[nt * 8:]:
                    raise SystemExit("%s: solo se pueden cambiar los tiles de antes de la cola (0x%02X-0x%02X)"
                                     % (bloque, t_ini, t_ini + nt - 1))
                prefijo = formato_b.comprime_tramo(bytes(datos[:nt * 8]))
                comp = bytes([destino & 0xFF, destino >> 8]) + prefijo + rom[cola - ORG:fin - ORG]
                nueva_cola = ini + 2 + len(prefijo)
                tr2, _ = formato_b.descomprime(comp, 0, org=0)
                if tr2 != [(destino, bytes(datos))]:
                    raise SystemExit("%s: el bloque con cola no descomprime a lo esperado" % bloque)
                if "reapunta" in args:
                    rutina = args["reapunta"]
                    reapunta_rutina(listado, dir_salida, n, rutina,
                                    [("0%04xh" % cola, "0%04xh" % nueva_cola)])
                    informe.append("%-38s reapuntada: 0x%04X -> 0x%04X" % (rutina, cola, nueva_cola))
            else:
                comp = formato_b.comprime([(destino, bytes(datos))])
            if "reubica" in args:
                # Comprimido ya no cabe en su hueco -las letras comprimen peor
                # que los kanji-, asi que el bloque entero se va a la zona libre
                # del final y el `ld hl` que lo carga se reapunta. El bloque
                # lleva dentro su propio destino de VRAM, o sea que da igual
                # desde donde se lea. El hueco original queda a 0xFF.
                if "cola" in args:
                    raise SystemExit("%s: reubica y cola no se pueden juntar" % bloque)
                nuevo_org = mete_en_la_zona_libre(libre, bloque, comp)
                rutina = args["reubica"]
                reapunta_rutina(listado, dir_salida, n, rutina,
                                [("0%04xh" % ini, "0%04xh" % nuevo_org)])
                escribe_fragmento(dir_salida, n, bloque,
                                  ["; reubicado en 0x%04X: comprimido son %d bytes y su hueco %d"
                                   % (nuevo_org, len(comp), tam)] + relleno(tam))
                informe.append("%-38s %-8s %4d bytes -> 0x%04X (su hueco eran %d)"
                               % (bloque, tipo, len(comp), nuevo_org, tam))
                continue
            if len(comp) > tam:
                raise SystemExit("%s: comprimido ocupa %d bytes y solo caben %d" % (bloque, len(comp), tam))
            lineas = defb(comp, "%s: %d tiles a 0x%04X, %d de %d bytes comprimido"
                          % (tipo, ntiles, destino, len(comp), tam)) + relleno(tam - len(comp))
            escribe_fragmento(dir_salida, n, bloque, lineas)
            informe.append("%-38s %-8s %4d/%4d bytes" % (bloque, tipo, len(comp), tam))
            continue

        if tipo == "codigo":
            bloque = pos[0]
            pares = []
            for ln in cuerpo:
                if "=>" not in ln:
                    raise SystemExit("%s: sustitucion rara: %r" % (bloque, ln))
                viejo, nuevo = (x.strip() for x in ln.split("=>", 1))
                pares.append((viejo, nuevo))
            reapunta_rutina(listado, dir_salida, n, bloque, pares)
            informe.append("%-38s codigo, %d sustituciones" % (bloque, len(pares)))
            continue

        if tipo == "asm":
            escribe_fragmento(dir_salida, n, pos[0], cuerpo, args.get("hasta"))
            informe.append("%-38s asm, %d lineas" % (pos[0], len(cuerpo)))
            continue

        if tipo == "nombres":
            bloque, punteros = pos[0], pos[1]
            cs = args["charset"]
            campo = int(args.get("relleno", "10"))
            if libre is None:
                raise SystemExit("nombres: hace falta una seccion [libre] antes")
            ini, fin, tam = tamano(bloque)
            ini_p, fin_p, tam_p = tamano(punteros)
            # LOS REGISTROS NO ESTAN EN ORDEN DE INDICE: los ordena la tabla de
            # punteros. Para copiar el han de cada jugada hay que ir por ella.
            tabla_orig = rom[ini_p - ORG:fin_p - ORG]
            registros = {}
            for idx in range(39):
                d = tabla_orig[idx * 2] | (tabla_orig[idx * 2 + 1] << 8)
                if not ini <= d < fin:
                    raise SystemExit("nombres: el puntero %d (0x%04X) no cae en el bloque" % (idx, d))
                registros[idx] = bytes(rom[d - ORG:rom.index(0xFF, d - ORG)])
            nombres = {}
            for ln in cuerpo:
                m = re.match(r'^(\d+)\s+"([^"]*)"', ln)
                if not m:
                    raise SystemExit("nombres: linea rara: %r" % ln)
                nombres[int(m.group(1))] = m.group(2)
            faltan = [i for i in range(1, 39) if i not in nombres]
            if faltan:
                raise SystemExit("nombres: faltan los indices %s" % faltan)
            blanco = CHARSETS[cs][" "]
            datos = bytearray([0xFF])
            desplaz = {0: 0}
            con_han = 0
            for idx in range(1, 39):
                reg = registros[idx]
                # Los registros normales acaban en `00 01 han` (el 0x00 separa,
                # el 0x01 son las decenas en blanco). Los once yakuman no llevan
                # han: su nombre acaba y ya. Ningun tile de nombre es 0x00, asi
                # que el patron distingue los dos casos sin ambiguedad.
                han = reg[-1] if len(reg) >= 3 and reg[-3] == 0x00 else None
                cod = codifica(nombres[idx], cs)
                if len(cod) > campo:
                    raise SystemExit("nombres: %r mide %d celdas y el campo es de %d" % (nombres[idx], len(cod), campo))
                desplaz[idx] = len(datos)
                if han is not None:
                    con_han += 1
                    cod = cod + bytes([blanco]) * (campo - len(cod)) + bytes([0x00, 0x01, han])
                datos += cod + b"\xFF"
            org_nombres = mete_en_la_zona_libre(libre, bloque, bytes(datos))
            tabla = bytearray()
            for idx in range(39):
                d = org_nombres + desplaz[idx]
                tabla += bytes([d & 0xFF, d >> 8])
            if len(tabla) != tam_p:
                raise SystemExit("la tabla de punteros mide %d y no %d" % (len(tabla), tam_p))
            escribe_fragmento(dir_salida, n, punteros, defb(tabla, "punteros a los nombres en ingles, en 0x%04X" % org_nombres))
            escribe_fragmento(dir_salida, n, bloque,
                              ["; los nombres en katakana ya no se usan: los ingleses estan en 0x%04X" % org_nombres]
                              + relleno(tam))
            informe.append("%-38s nombres: 38 (%d con han) en %d bytes desde 0x%04X (antes %d)"
                           % (bloque, con_han, len(datos), org_nombres, tam))
            continue

        raise SystemExit("seccion desconocida: %s" % tipo)

    if libre is not None:
        bloque, org, fin, trozos, asmlin = libre
        lineas, cursor = [], org
        for nombre, datos in trozos:
            lineas.append("%s:%s; 0x%04X, %d bytes" % (nombre, TAB, cursor, len(datos)))
            lineas += defb(datos)
            cursor += len(datos)
        if cursor > fin:
            raise SystemExit("la zona libre se desborda: %d bytes de %d" % (cursor - org, fin - org))
        # El codigo nuevo va DETRAS de los datos reubicados: asi no le mueve la
        # direccion a nadie y es pasmo quien le resuelve las etiquetas. Si se
        # pasa del final, el `defs` de abajo sale negativo y pasmo lo caza.
        lineas += asmlin
        lineas.append(TAB + "defs 0x%04X-$,0ffh" % fin)
        escribe_fragmento(dir_salida, 99, bloque, lineas)
        informe.append("%-38s zona libre: %d de %d bytes usados" % (bloque, cursor - org, fin - org))

    for ln in informe:
        print("  " + ln)
    return 0


if __name__ == "__main__":
    sys.exit(main())
