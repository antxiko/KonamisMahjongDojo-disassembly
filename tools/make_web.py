#!/usr/bin/env python3
"""Genera la portada de la web, en los dos idiomas.

El diseno es el compartido por la serie (tools/estilo_web.py) y la pagina sale
autocontenida, con las imagenes embebidas como data URI.

Las imagenes NO son ilustraciones ni montajes: son capturas del cartucho
corriendo en openMSX, hechas por tools/capturas_web.py con un guion de instantes
fijos, sin que nadie pulse nada a ojo. El rotulo de la cabecera esta recortado de
la propia pantalla de titulo.

Uso: make_web.py <docs/imagenes> <salida.html> <idioma>
"""
import base64
import os
import sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from estilo_web import ESTILO                                   # noqa: E402

# Las cifras salen de contar sobre el listado generado, no de escribirlas aqui
# a ojo: 32768 = 15432 + 17336, que es lo que imprime tools/presupuesto.py
# (make sanity). RUTINAS son las etiquetas de codigo con nombre propio, las
# mismas que cuenta el .notes con su directiva L. JUGADAS son los nombres de
# 0x747B, uno por yaku, sin contar la entrada 0, que esta vacia.
CODIGO = 15432
DATOS = 17336
RUTINAS = 340
JUGADAS = 38


def mil(n, idioma):
    return f"{n:,}".replace(",", "." if idioma == "es" else ",")


TXT = {
    "es": dict(
        titulo="Konami's Mahjong — desensamblado comentado",
        aviso="<b>Todas las imágenes de aquí son capturas del cartucho.</b> Y "
              "ninguna se ha hecho a mano: un guion arranca la ROM en openMSX "
              "sin pintar nada, vuelca la memoria de vídeo en unos instantes "
              "fijos y el PNG se monta desde el volcado. La primera pasada no "
              "pulsa una sola tecla, porque el demo se juega solo. El listado y "
              "las cifras salen del binario y se reproducen con <code>make</code>.",
        claim="Treinta y dos kilobytes en los que el hilo principal no hace "
              "nada: arranca, engancha la interrupción y se queda en un salto "
              "a sí mismo para siempre. Y el rival, que juega bien, tampoco "
              "piensa: su mano se construye a una ficha de completarse, y lo "
              "que echa al río es una ficha sorteada del muro con un filtro "
              "que la hace parecer humana.",
        ficha=["Konami · <b>© Konami 1984</b>",
               "Cartucho <b>RC-707</b>, 32 KB",
               "MSX1 · <b>páginas 1 y 2</b>", "Volcado <b>24cb5bda…</b>"],
        nav=[("#numbers", "Las cifras"), ("#findings", "Hallazgos"),
             ("#screens", "Lo que dibuja")],
        docnav=[("EMPEZAR.html", "Empezar"), ("EL-JUEGO.html", "El juego"),
                ("LAS-REGLAS.html", "Las reglas"),
                ("LA-MAQUINA.html", "La máquina"),
                ("EL-CARTUCHO.html", "El cartucho"),
                ("EL-CODIGO.html", "El código"),
                ("HALLAZGOS.html", "Hallazgos"),
                ("PREGUNTAS-ABIERTAS.html", "Preguntas abiertas")],
        otro=("../", "In English"),
        h_num="El juego en cifras", h_find="Lo que apareció al desmontarlo",
        h_scr="Lo que el cartucho dibuja",
        cifras=[("100 %", "del binario explicado"),
                (str(RUTINAS), "rutinas identificadas"),
                (str(JUGADAS), "jugadas con nombre"),
                (mil(CODIGO, "es"), "bytes de código"),
                (mil(DATOS, "es"), "bytes de datos"),
                ("0", "bytes sin identificar")],
        nota_scr="Debajo de cada imagen está el estado del juego en que se "
                 "hizo la captura y qué se está viendo.",
        pie_leg="Esto es trabajo de documentación y preservación: el código y "
                "los gráficos siguen siendo de sus autores y de Konami, y la "
                "imagen del cartucho no se distribuye.",
    ),
    "en": dict(
        titulo="Konami's Mahjong — a commented disassembly",
        aviso="<b>Every picture here is a screenshot of the cartridge.</b> And "
              "not one was taken by hand: a script boots the ROM in openMSX "
              "with nothing being drawn, dumps video memory at a few fixed "
              "instants, and the PNG is built from the dump. The first pass "
              "does not press a single key, because the demo plays itself. The "
              "listing and the numbers come from the binary and are "
              "reproducible with <code>make</code>.",
        claim="Thirty-two kilobytes in which the main thread does nothing: it "
              "starts up, hooks the interrupt and settles into a jump to "
              "itself forever. And the opponent, which plays well, does not "
              "think either: its hand is built one tile short of complete, and "
              "what goes into its river is a tile drawn at random from the "
              "wall through a filter that makes it look human.",
        ficha=["Konami · <b>© Konami 1984</b>",
               "An <b>RC-707</b> 32 KB cartridge",
               "MSX1 · <b>pages 1 and 2</b>", "Dump <b>24cb5bda…</b>"],
        nav=[("#numbers", "The numbers"), ("#findings", "What turned up"),
             ("#screens", "What it draws")],
        docnav=[("GETTING-STARTED.html", "Getting started"),
                ("THE-GAME.html", "The game"),
                ("THE-RULES.html", "The rules"),
                ("THE-MACHINE.html", "The machine"),
                ("THE-CARTRIDGE.html", "The cartridge"),
                ("THE-CODE.html", "The code"),
                ("FINDINGS.html", "Findings"),
                ("OPEN-QUESTIONS.html", "Open questions")],
        otro=("es/", "En castellano"),
        h_num="The game in numbers",
        h_find="What turned up when we took it apart",
        h_scr="What the cartridge draws",
        cifras=[("100%", "of the binary explained"),
                (str(RUTINAS), "routines identified"),
                (str(JUGADAS), "named yaku"),
                (mil(CODIGO, "en"), "bytes of code"),
                (mil(DATOS, "en"), "bytes of data"),
                ("0", "bytes unidentified")],
        nota_scr="Under each picture is the game state the screenshot was "
                 "taken in and what is on it.",
        pie_leg="This is documentation and preservation work: the code and "
                "artwork still belong to their authors and to Konami, and the "
                "cartridge image is not distributed.",
    ),
}

HALLAZGOS = {
    "es": [
        ("El rival juega bien y no piensa ni una vez",
         "<p>Declara riichi, canta pon y chi, se defiende cuando va perdiendo y "
         "gana manos caras. Pero no evalúa su mano en ningún momento, y las dos "
         "piezas que lo sostienen son igual de descaradas.</p>"
         "<p>La primera: <b>su mano no se roba, se construye</b>. Antes de "
         "repartir nada, 0x78CE arma catorce fichas a medida —un palo, unos "
         "cuantos tríos, escaleras o parejas, y una pareja al final— y luego "
         "<b>quita una</b>. La máquina empieza cada mano a una sola ficha de "
         "completarla, y las copias que gasta se descuentan de los contadores "
         "para que al jugador no le salgan después.</p>"
         "<p>La segunda: <b>no descarta de su mano</b>. Sus trece fichas no se "
         "mueven; lo que va a su río es una ficha <b>sorteada del muro</b> "
         "(0x583C) y pasada por un filtro: los cuatro primeros descartes son "
         "honores, los cuatro siguientes unos, doses, ochos y nueves, nunca una "
         "de sus propias esperas y nunca del palo al que va. O sea el orden en "
         "que descarta una persona, obtenido sin mirar la mano.</p>"),
        ("El hueco vacío de su mano es teatro",
         "<p>Al pintar la mano del rival boca abajo, una de las fichas se "
         "dibuja como hueco, y parece que dice de dónde acaba de robar. La "
         "mitad de las veces no es verdad: 0x553C elige ese hueco <b>al azar o "
         "el de la robada según el bit 0 de la semilla</b>, y solo se vuelve "
         "honesto cuando la máquina está en riichi.</p>"),
        ("Tres instrucciones que no corren desde 1984",
         "<p>Junto al filtro de descartes hay una comprobación para no soltar "
         "terminales, y está mal escrita. Compara el número de la ficha con el "
         "1 y, si no lo es, se vuelve; y si lo es, compara ese mismo 1 con el "
         "9, que tampoco cuadra, y se vuelve igual.</p>"
         "<pre class=\"asm\">5961:  cp 1\n"
         "5963:  jr nz,5987      ; no es un 1 -&gt; se acepta\n"
         "5965:  cp 9            ; A vale 1: nunca es 9\n"
         "5967:  jr nz,5987      ; -&gt; se acepta igual\n"
         "5969:  call ...        ; devolver al monton y sortear otra:\n"
         "596C:  call ...        ; TRES instrucciones que no corren nunca</pre>"
         "<p>El sorteo que hay debajo está perfectamente formado y no se "
         "ejecuta jamás.</p>"),
        ("Los marcadores no suman 60.000, y es a propósito",
         "<p>Con tsumo, el pago sale de las tablas de «al robar», que son lo "
         "que pagaría <b>un solo jugador</b> en una mesa de cuatro. Pero 0x5B85 "
         "carga la misma cifra en los dos pendientes y luego solo rebaja el del "
         "que paga, no el del que cobra: <b>el perdedor paga la parte de uno y "
         "el ganador cobra la cifra entera del ron</b>.</p>"
         "<p>Se crean puntos de la nada, y la pantalla del recuento lo imprime "
         "sin disimulo, con ハライ (lo pagado) y トクテン (lo cobrado) en dos "
         "líneas distintas. En el demo se pagan 6.000 y se cobran 18.000, y los "
         "dos marcadores acaban en 23.000 y 48.000.</p>"),
        ("El mismo 8 es un estado y una dificultad",
         "<p>Al arrancar el demo, el cartucho escribe un 8 en el byte del "
         "estado. Ese 8 no llega a despacharse nunca —la instrucción siguiente "
         "hace <code>inc</code>, así que el estado que corre es el 9—, y sin "
         "embargo se escribe:</p>"
         "<pre class=\"asm\">418C:  ld a,008h\n"
         "418E:  ld (0E000h),a   ; el estado... que se convertira en 9\n"
         "418F:  rra             ; el mismo 8, rotado: sale un 4\n"
         "4190:  ld (0E040h),a   ; y ese 4 es LA DIFICULTAD</pre>"
         "<p>De rebote, el demo juega <b>en la dificultad de en medio</b>: "
         "0xE040 vale 4 durante todo el ciclo, y la barra de arriba lo rotula "
         "セミプロ, mientras que una partida empezada con la tecla 1 pone アマ "
         "en el mismo sitio.</p>"),
        ("El texto de la mesa vive en el hueco de las fichas",
         "<p>Cada ficha se dibuja con seis tiles, dos de ancho por tres de "
         "alto, y las hileras caen siempre <b>a caballo de dos tercios de "
         "pantalla</b>. En el tercio de en medio solo se ve la fila de abajo de "
         "las fichas de arriba y la de arriba de las de abajo: la fila del "
         "medio de cada ficha no se dibuja nunca ahí.</p>"
         "<p>Y ahí es donde está el texto. Cruzando la tabla de fichas con las "
         "tablas de nombres de 124 volcados de memoria de vídeo, de los 97 "
         "tiles que usa la barra central <b>56 son exactamente el par central "
         "de alguna ficha</b>. El mismo número de tile es media ficha en un "
         "tercio y un kanji en otro.</p>"),
        ("El demo no piensa: lee ciento cuatro bytes",
         "<p>No hay un modo demo aparte. Cuando nadie toca nada, el cartucho "
         "recorre <b>la misma máquina de estados</b> que una partida, con las "
         "mismas rutinas; lo único que cambia es de dónde salen las "
         "pulsaciones. 0x416B engancha el bloque de 0x4AE8 —ciento cuatro "
         "bytes— en lugar del teclado, con las mismas máscaras de bits que arma "
         "el lector de verdad y un formato de longitud variable: el nibble bajo "
         "de cada entrada dice si ocupa uno o dos bytes.</p>"
         "<p>Por eso sale igual cada vez: dos arranques en frío independientes "
         "dan la misma traza, instante a instante. Lo que no es constante es "
         "cuánto dura cada vuelta —se miden <b>163,53, 168,96 y 170,56 "
         "segundos</b> entre pasadas por el estado 0—, porque la semilla del "
         "azar sale del registro R del refresco de memoria y con ella cambia la "
         "mano que se construye la máquina.</p>"),
        ("No lleva la marca oculta de Konami",
         "<p>Muchos cartuchos de Konami de esta época esconden al final de la "
         "ROM su número de catálogo RC-7xx y el título del juego en katakana; "
         "lo descubrió <b>Manuel Pazos</b> "
         "(<a href=\"https://twitter.com/ManuelPazosMSX\">@ManuelPazosMSX</a>).</p>"
         "<p>Este no. En los 32768 bytes no hay ni un <code>RC-7</code> en "
         "ASCII, ni la palabra <code>KONAMI</code>: el contenido acaba en "
         "0x9FE4, en la tabla de semitonos, y detrás solo hay <b>8.219 bytes de "
         "0xFF</b>. El RC-707 sale del catálogo, no del binario.</p>"),
    ],
    "en": [
        ("The opponent plays well and never thinks once",
         "<p>It declares riichi, calls pon and chi, defends itself when it is "
         "losing and wins expensive hands. But it never evaluates its hand, and "
         "the two pieces holding it up are equally brazen.</p>"
         "<p>The first: <b>its hand is not drawn, it is built</b>. Before "
         "anything is dealt, 0x78CE assembles fourteen tiles to order —a suit, "
         "a few triplets, runs or pairs, and a pair at the end— and then "
         "<b>takes one away</b>. The machine starts every hand one single tile "
         "short of completing it, and the copies it spends are deducted from "
         "the counters so the player cannot draw them later.</p>"
         "<p>The second: <b>it does not discard from its hand</b>. Its thirteen "
         "tiles never move; what goes into its river is a tile <b>drawn at "
         "random from the wall</b> (0x583C) and put through a filter: the first "
         "four discards are honours, the next four ones, twos, eights and "
         "nines, never one of its own waits and never from the suit it is going "
         "for. Which is the order a person discards in, arrived at without "
         "looking at the hand.</p>"),
        ("The empty slot in its hand is theatre",
         "<p>When the opponent's face-down hand is drawn, one of the tiles is "
         "shown as a gap, and it looks like it is telling you where it has just "
         "drawn. Half the time that is not true: 0x553C picks that gap <b>either "
         "at random or as the drawn tile's, depending on bit 0 of the seed</b>, "
         "and it only becomes honest once the machine is in riichi.</p>"),
        ("Three instructions that have not run since 1984",
         "<p>Next to the discard filter there is a check meant to avoid "
         "throwing terminals, and it is written wrong. It compares the tile's "
         "number with 1 and, if it is not a 1, returns; and if it is, it "
         "compares that same 1 with 9, which does not match either, and returns "
         "just the same.</p>"
         "<pre class=\"asm\">5961:  cp 1\n"
         "5963:  jr nz,5987      ; not a 1 -&gt; accepted\n"
         "5965:  cp 9            ; A is 1: it is never 9\n"
         "5967:  jr nz,5987      ; -&gt; accepted anyway\n"
         "5969:  call ...        ; put it back and draw another:\n"
         "596C:  call ...        ; THREE instructions that never run</pre>"
         "<p>The redraw below is perfectly well formed and never executes.</p>"),
        ("The scores do not add up to 60,000, and that is on purpose",
         "<p>With tsumo, the payment comes from the «on the draw» tables, which "
         "are what <b>a single player</b> would pay at a four-seat table. But "
         "0x5B85 loads the same figure into both pending amounts and then only "
         "reduces the payer's, not the collector's: <b>the loser pays one "
         "player's share and the winner collects the full ron figure</b>.</p>"
         "<p>Points are created out of nothing, and the scoring screen prints it "
         "without flinching, with ハライ (paid) and トクテン (collected) on two "
         "separate lines. In the demo 6,000 are paid and 18,000 collected, and "
         "the two scores end at 23,000 and 48,000.</p>"),
        ("The same 8 is both a state and a difficulty",
         "<p>When the demo starts, the cartridge writes an 8 into the state "
         "byte. That 8 never gets dispatched —the next instruction does an "
         "<code>inc</code>, so the state that runs is 9— and yet it is "
         "written:</p>"
         "<pre class=\"asm\">418C:  ld a,008h\n"
         "418E:  ld (0E000h),a   ; the state... which will turn into 9\n"
         "418F:  rra             ; the same 8, rotated: out comes a 4\n"
         "4190:  ld (0E040h),a   ; and that 4 is THE DIFFICULTY</pre>"
         "<p>As a side effect, the demo plays <b>on the middle difficulty</b>: "
         "0xE040 is 4 for the whole cycle, and the top bar labels it セミプロ, "
         "while a game started with key 1 reads アマ in the same place.</p>"),
        ("The table's text lives in the gap inside the tiles",
         "<p>Every tile is drawn with six characters, two wide by three tall, "
         "and the rows always fall <b>across two thirds of the screen</b>. In "
         "the middle third you only see the bottom row of the tiles above and "
         "the top row of the tiles below: the middle row of each tile is never "
         "drawn there.</p>"
         "<p>And that is where the text is. Crossing the tile table with the "
         "name tables of 124 video memory dumps, of the 97 tiles the central "
         "bar uses <b>56 are exactly the middle pair of some tile</b>. The same "
         "tile number is half a mahjong tile in one third and a kanji in "
         "another.</p>"),
        ("The demo does not think: it reads one hundred and four bytes",
         "<p>There is no separate demo mode. When nobody touches anything, the "
         "cartridge walks <b>the same state machine</b> a real game does, "
         "through the same routines; the only thing that changes is where the "
         "keypresses come from. 0x416B hooks the block at 0x4AE8 —one hundred "
         "and four bytes— up in place of the keyboard, with the very bit masks "
         "the real reader builds and a variable-length format: the low nibble "
         "of each entry says whether it takes one byte or two.</p>"
         "<p>That is why it comes out the same every time: two independent cold "
         "boots give the same trace, instant for instant. What is not constant "
         "is how long each lap takes —<b>163.53, 168.96 and 170.56 seconds</b> "
         "were measured between passes through state 0—, because the random "
         "seed comes from the memory refresh register R, and with it changes "
         "the hand the machine builds for itself.</p>"),
        ("It does not carry Konami's hidden mark",
         "<p>Many Konami cartridges of this period hide their RC-7xx catalogue "
         "number and the game's title in katakana at the end of the ROM; it was "
         "<b>Manuel Pazos</b> "
         "(<a href=\"https://twitter.com/ManuelPazosMSX\">@ManuelPazosMSX</a>) "
         "who found that out.</p>"
         "<p>This one does not. In all 32768 bytes there is not one "
         "<code>RC-7</code> in ASCII, nor the word <code>KONAMI</code>: the "
         "content ends at 0x9FE4, in the semitone table, and behind it there "
         "are only <b>8,219 bytes of 0xFF</b>. The RC-707 comes from the "
         "catalogue, not from the binary.</p>"),
    ],
}

GALERIA = [
    ("titulo.png",
     "Estado 5 — el título, 麻雀道場, con el copyright escrito en la fuente del "
     "propio juego y las tres dificultades en romaji. La tecla que se pulse "
     "aquí acaba en 0xE040, y de ahí no cambia en toda la partida",
     "State 5 — the title, 麻雀道場, with the copyright written in the game's "
     "own font and the three difficulties in romaji. Whichever key you press "
     "here ends up in 0xE040, and it does not change for the rest of the game"),
    ("mesa.png",
     "Estado 11, paso 1 — la mesa con el reparto empezando: los dos marcadores "
     "a 30.000, el viento y la mano (東一局), las dos fichas indicadoras, el "
     "contador de palos de riichi de la mesa a cero (０本) y el menú de "
     "llamadas en el panel cian",
     "State 11, step 1 — the table with the deal starting: both scores at "
     "30,000, the wind and hand number (東一局), the two indicator tiles, the "
     "table's riichi stick counter at zero (０本) and the call menu in the "
     "cyan panel"),
    ("reparto.png",
     "Estado 11, paso 2 — recién repartida. Trece fichas boca abajo arriba y "
     "catorce abajo, ordenadas: cinco caracteres, cuatro círculos, dos bambúes "
     "y tres honores, que son los códigos 02 06 08 08 09 · 11 13 15 17 · 22 22 "
     "· 31 31 33",
     "State 11, step 2 — just dealt. Thirteen tiles face down on top and "
     "fourteen below, sorted: five characters, four circles, two bamboos and "
     "three honours, which are codes 02 06 08 08 09 · 11 13 15 17 · 22 22 · "
     "31 31 33"),
    ("mano.png",
     "Estado 11, paso 2 — la mano avanzada, con los dos ríos llenos. El "
     "marcador de arriba ha bajado a 29.000 y la mesa tiene un palo: la "
     "máquina ha declarado riichi. En la caja cian, el aviso de カン o "
     "descarte",
     "State 11, step 2 — the hand well along, both rivers full. The top score "
     "has dropped to 29,000 and there is a stick on the table: the machine has "
     "declared riichi. In the cyan box, the カン or discard prompt"),
    ("recuento.png",
     "Estado 11, paso 7 — el recuento: 親 (gana el que reparte), 30 fu, 7 han, "
     "ハライ 6.000 y トクテン 18.000, la lista de jugadas a la derecha y la "
     "mano separada en figuras abajo, cada una con sus fu",
     "State 11, step 7 — the scoring: 親 (the dealer wins), 30 fu, 7 han, "
     "ハライ 6,000 and トクテン 18,000, the list of yaku on the right and the "
     "hand split into sets below, each with its fu"),
    ("final.png",
     "Estado 14 — 終局, fin de la partida, escrito sobre un muro de fichas que "
     "se monta ficha a ficha en el estado anterior",
     "State 14 — 終局, the end of the game, written over a wall of tiles that "
     "is built up tile by tile in the previous state"),
    ("partida.png",
     "Estado 11 en una partida de verdad, empezada con la tecla 1. Es la misma "
     "pantalla que la del demo con una diferencia: donde el demo rotula "
     "セミプロ, aquí pone アマ",
     "State 11 in a real game, started with key 1. It is the same screen as the "
     "demo's with one difference: where the demo reads セミプロ, this reads "
     "アマ"),
]


def img64(ruta):
    with open(ruta, "rb") as f:
        return "data:image/png;base64," + base64.b64encode(f.read()).decode()


def main(argv):
    if len(argv) < 4:
        print(__doc__)
        return 2
    imgdir, salida, idioma = argv[1:4]
    t = TXT[idioma]

    ruta_logo = os.path.join(imgdir, "logo.png")
    cabecera = (f'<img src="{img64(ruta_logo)}" alt="Konami\'s Mahjong">'
                if os.path.exists(ruta_logo) else "<h1>Konami's Mahjong</h1>")

    nav = "".join(f'<a href="{h}">{x}</a>' for h, x in t["nav"])
    nav += "".join(f'<a href="{h}">{x}</a>' for h, x in t["docnav"])
    nav += (f'<a href="{t["otro"][0]}" style="margin-left:auto;color:var(--oro)">'
            f'{t["otro"][1]}</a>')

    cifras = "".join(f'<div class="cifra"><b>{v}</b><span>{e}</span></div>'
                     for v, e in t["cifras"])
    halls = "".join(f'<div class="hall"><h3>{tit}</h3>{cuerpo}</div>'
                    for tit, cuerpo in HALLAZGOS[idioma])
    imgs = ""
    faltan = []
    for fich, es, en in GALERIA:
        ruta = os.path.join(imgdir, fich)
        if not os.path.exists(ruta):
            faltan.append(fich)
            continue
        pie = es if idioma == "es" else en
        imgs += (f'<figure><img src="{img64(ruta)}" alt="{pie}">'
                 f'<figcaption>{pie}</figcaption></figure>')
    if faltan:
        print("  (faltan %d imagenes: %s)" % (len(faltan), " ".join(faltan)))

    html = f"""<meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>{t['titulo']}</title>
<style>{ESTILO}</style>
<header class="top">
  {cabecera}
  <p class="claim">{t['claim']}</p>
  <p class="ficha">{' · '.join(t['ficha'])}</p>
</header>
<p class="ficha" style="border:1px solid var(--oro);padding:.8em 1em;margin:1.5em 0">
{t['aviso']}</p>
<nav>{nav}</nav>
<section id="numbers">
  <h2>{t['h_num']}</h2>
  <div class="cifras">{cifras}</div>
</section>
<section id="findings"><h2>{t['h_find']}</h2>{halls}</section>
<section id="screens">
  <h2>{t['h_scr']}</h2>
  <p class="n">{t['nota_scr']}</p>
  <div class="galeria">{imgs}</div>
</section>
<footer><p>{t['pie_leg']}</p></footer>
"""
    with open(salida, "w", encoding="utf-8") as f:
        f.write(html)
    print("  %s: %d KB (%s)" % (salida, len(html) // 1024, idioma))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
