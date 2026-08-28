# La partida de Konami's Mahjong, medida

Paso 2 del plan: **qué hace el juego de verdad**, apuntado antes de explicar el
código. Todo lo de aquí está medido sobre el cartucho corriendo, y cada cifra
dice de dónde sale. Lo que es suposición va marcado como tal.

## Cómo se midió, y por qué así

**El demo se juega solo, y es determinista desde el encendido.** Arrancado el
cartucho sin tocar una sola tecla, la máquina reparte, juega una mano entera,
la puntúa y vuelve a empezar. Dos pasadas independientes -una sobre un replay
grabado y otra arrancando en frío- dieron los **mismos instantes al centésimo**
(estado 2 en t=172,87; estado 3 en t=174,46; estado 5 en t=175,54).

Eso hace innecesario el replay, y con él se van sus dos trampas conocidas: la
deriva de `reverse goto` + espera, y la relectura de la imagen. Aquí basta con
arrancar y mirar.

| herramienta | qué hace |
| --- | --- |
| `tools/omsx_estado_demo.tcl` | traza los cambios de 0xE000/0xE001 sobre el replay |
| `tools/omsx_retrata_estados.tcl` | arranca en frío y saca PNG + volcado de RAM en cada estado |
| `tools/busca_marcador.py` | cruza los 55 volcados para localizar el marcador |

Salidas: `work/estados/` (55 capturas), `work/estados/ram/` (55 volcados de
0xE000-0xE3FF) y los `.log` de cada pasada.

## El ciclo del demo: 168,96 s, y vuelve a empezar

`0xE000` es el estado y `0xE001` el submodo, los índices de las cinco tablas de
despacho. Tres subrutinas compartidas los gobiernan **todos**:

| rutina | qué hace |
| --- | --- |
| `L_41FF` (0x41FF) | `inc (0xE000)` + `ld (0xE001),0` — avanza de estado y resetea el submodo |
| `L_4212` (0x4212) | `inc (0xE001)` — avanza de submodo |
| `L_4196` (0x4196) | `xor a / ld (0xE000),a` — **cierra el bucle**, vuelve al estado 0 |

Medido: el demo vuelve al estado 0 en t=168,48 y otra vez en t=337,44. **El
ciclo completo dura 168,96 s.** El segundo ciclo transcurrió entero después de
agotarse el replay, o sea con cero entradas: el bucle es del cartucho.

### Los quince estados

Instantes del primer ciclo, en segundos emulados desde el encendido.

| estado | entra en | dura | qué se ve |
| ---: | ---: | ---: | --- |
| 0 | 4,95 | 3,4 s | pantalla en negro; arranque |
| 1 | 8,34 | 0,7 s | — |
| 2 | 8,99 | 1,6 s | — |
| 3 | 10,59 | 0,01 s | — |
| 4 | 10,60 | 1,1 s | — |
| **5** | **11,66** | **5,1 s** | **el título: 麻雀道場, © Konami 1984, y el menú** |
| 6 | 16,76 | 0,02 s | — |
| 7 | 16,78 | 0,03 s | — |
| *8* | *16,81* | *instantáneo* | **nunca se despacha** (ver abajo) |
| 9 | 16,81 | 1,9 s | negro; borrado de pantalla |
| 10 | 18,68 | 1,5 s | la mesa: marcador, 東一局, menú de llamadas |
| **11** | **20,19** | **130,3 s** | **la mano entera** (nueve submodos) |
| 12 | 150,50 | 9,1 s | cierre de la ronda |
| 13 | 159,55 | 0,02 s | — |
| **14** | **159,57** | **8,9 s** | **終局** (fin de la partida) sobre un muro de fichas |
| → 0 | 168,48 | | vuelve a empezar, desde `L_4196` |

**El estado 8 nunca llega a despacharse.** En 0x418C se escribe `8` en 0xE000,
pero el `jp L_41F4` que sigue desemboca en `L_41FF`, que hace `inc (hl)`: el 8
dura unas instrucciones y se convierte en 9. Por eso los dos aparecen en el
mismo instante (t=16,81). El `8` se escribe porque sirve doble: el `rra` de
0x418F lo convierte en 4 para 0xE040.

Esto **corrige la pregunta** que quedaba abierta en la misión ("identificar cuál
de los 15 estados es el demo"). No hay estado de demo: el demo recorre la
máquina de estados entera, la misma que juega una persona.

### El estado 11, la mano

La tabla de submodos de 0x421D tiene nueve palabras, y el demo recorre las
nueve. Las duraciones son del primer ciclo.

| submodo | entra en | dura | qué se ve |
| ---: | ---: | ---: | --- |
| 0 | 20,19 | instantáneo | — |
| 1 | 20,19 | 6,3 s | **el reparto**, ficha a ficha |
| **2** | **26,46** | **103,7 s** | **la mano se juega**: robos y descartes |
| 3 | 130,13 | 0,7 s | — |
| 4 | 130,84 | 3,5 s | — |
| 5 | 134,33 | 6,2 s | — |
| 6 | 140,57 | 5,1 s | — |
| **7** | **145,67** | **3,6 s** | **el recuento**: fu, han, yaku y pago |
| 8 | 149,28 | 1,2 s | → estado 12 |

El submodo 2 dura lo mismo las dos veces que se midió: 103,7 s en el primer
ciclo y 104,4 s en el segundo.

**El tamaño de las capturas mide el descarte.** Los once PNG del submodo 2, a
intervalos de 10 s, pesan 3350, 3694, 3866, 4053, 4210, 4399, 4723, 4850, 5342,
5558 y 6410 bytes. Crece sin excepciones: son las fichas acumulándose en la mesa.

## Lo que se ve en pantalla

**El título es 麻雀道場 (*Mahjong Dōjō*), en kanji**, no en katakana. Coincide
con el nombre que la base de datos de openMSX le da al cartucho ("Konami's
Mahjong Dojo") y con el segundo fichero del directorio `ROMS/`. Debajo, `©
Konami 1984`.

El menú del título va en ASCII: `KEYBOARD ONLY`, `PLAY SELECT`, y las tres
dificultades **en romaji**: `1-key AMACHUA` (アマチュア, *amateur*), `2-key
SEMIPROFESSIONAL`, `3-key PROFESSIONAL`.

**Es un mahjong de dos jugadores.** Marcador de 30000 y 30000, la mano del rival
boca abajo arriba y la propia abajo. El panel central lleva el viento y número
de mano (東一局) y el contador de repeticiones (〇本場). El panel cian de la
derecha es el menú de llamadas: アガリ / リーチ / ポン / チー / カン (el orden lo
fija la tabla de 0x660A: pon antes que chi; una lectura anterior de la captura
los tenía al revés).

La pantalla de recuento (estado 11, submodo 7) trae el desglose completo: 親
(banca), フ y フアン (fu y han), ハライ (pago), トクテン (puntos), la lista de
yaku con su valor en han, y la mano ganadora separada en grupos.

**Aviso sobre las lecturas de pantalla.** Los números leídos a ojo de una
captura de 256×212 **no son fiables**: en la pantalla de recuento se leyó 37400
donde la RAM dice 037500. Donde hay una dirección de memoria que lo diga, manda
la memoria. Las lecturas de esa pantalla que aquí no van respaldadas por RAM
(los valores de fu, han y pago, y los nombres de los yaku) están **sin
confirmar**.

## El marcador: 0xE044 y 0xE047

Dos contadores **BCD de tres bytes, byte bajo primero**. Cruzando los 55
volcados con lo que se ve en pantalla:

| volcado | 0xE044 | 0xE047 |
| --- | ---: | ---: |
| 020 (estado 10) | 030000 | 030000 |
| 033 (mano, t=100) | 030000 | 030000 |
| 036 (mano, t=130) | **029000** | 030000 |
| 041 (recuento, a mitad del pago) | **023000** | **037500** |
| 050 (終局) | 023000 | 048000 |

Y el código lo confirma por su cuenta, en dos rutinas que operan sobre esas
direcciones:

| rutina | qué hace |
| --- | --- |
| `L_838B` (0x838B) | **suma BCD de 3 bytes**: `add a,e / daa`, `adc a,d / daa`, arrastre al tercero |
| `L_839E` (0x839E) | **resta BCD de 3 bytes**: `sub e / daa`, `sbc a,d / daa` |

El `daa` demuestra que la codificación es BCD y el recorrido `inc l` / `inc hl`
que el byte bajo va primero. **Dos métodos independientes -el cruce de volcados
y el desensamblado- dan el mismo resultado.**

Alrededor de cada llamada hay dos bloques espejo: 0x8315-0x8346 opera sobre
0xE047 mirando los **bits 0 y 1 de 0xE100**, y 0x8349-0x8388 opera sobre 0xE044
mirando los **bits 6 y 7** de la misma dirección. Cada jugador tiene su par de
bits en 0xE100.

Los aciertos que la búsqueda dio en 0xE046 y 0xE049 son **ruido**: con dos
contadores `00 00 03` seguidos, leer desplazado dos bytes finge el orden de
bytes contrario.

## Lo que queda abierto

- ~~Qué es exactamente cada uno de los dos contadores.~~ **CERRADO el
  2026-08-28, en el paso 3.** Son los dos marcadores, y no se conservan POR
  DISEÑO: con tsumo el perdedor paga la parte de un solo jugador (tabla "al
  robar", pendiente 0xE1B1) y el ganador cobra la cifra entera del ron
  (pendiente 0xE1E4); lo carga 0x5B85 y lo mueve 0x5DF9. En el demo gana el 1
  por tsumo con 7 han y 30 fu repartiendo él: el volcado 040 tiene
  0xE1B1 = 0x0060 y 0xE1E4 = 0x0180 (6.000 y 18.000), la pantalla del recuento
  lo imprime como ハライ 6000 y トクテン 18000, y al final el 1 tiene
  30000+18000 = 48000 y el 2 30000−1000−6000 = 23000. El 60500 del volcado 041
  era una foto A MITAD del pago: el pendiente del perdedor ya estaba a cero y al
  del ganador le quedaban 0x0105, o sea 10.500 por cobrar. Y los 1.000 que
  faltan para 72.000 son el palo de riichi de la máquina, que sigue en la mesa
  (0xE04A = 1) porque el cierre del demo se salta el cobro (0x5E75).
- **Los estados 1, 2, 3, 4, 6, 7 y 13** no tienen todavía nada que se vea; hay
  captura de cada uno en `work/estados/`, pero varias salen en negro porque son
  transiciones de menos de un cuadro.
- **Los submodos 3, 4, 5 y 6 del estado 11** (entre que acaba la mano y sale el
  recuento) están medidos en duración pero no en contenido.
- **El texto de la pantalla de recuento**, que es la materia prima del paso 5,
  necesita leerse de la ROM y no de una captura.

## Suposiciones, marcadas

- ~~Que la bajada de 0xE044 de 030000 a 029000 a mitad de mano sea el palo de
  riichi.~~ **LEÍDO el 2026-08-28**: es el riichi de la máquina, 0x579A; le
  quita mil (0x57AB), sube 0xE04A (0x57B4) y pone 0xE1AE = 1 (0x57D8). El
  volcado 034 tiene las tres cosas a la vez: 029000, 0xE04A = 1 y 0xE1AE = 1.
