# Konami's Mahjong Dojo (Konami, MSX1) — desensamblado comentado

El cartucho RC-707 de Konami, desmontado byte a byte. Los 32.768 bytes están
asignados y explicados: ni huecos sin justificar, ni «bloque de gráficos», ni
tablas adivinadas.

🌐 **[Leerlo como web](https://antxiko.github.io/KonamisMahjongDojo-disassembly/es/)**

[README in English](README.md)

---

## Qué es esto

麻雀道場 (*Mahjong Dōjō*) es un mahjong de dos jugadores: tú contra el
ordenador, 30.000 puntos cada uno, dos rondas. Esto es su código, comentado, con
las herramientas para reconstruirlo y comprobar que lo que sale es el original.

El cartucho ocupa 32 KB en las páginas 1 y 2 (0x4000-0xBFFF). El arranque
escribe un `jp` en el gancho `H.KEYI` y se quita de en medio: el programa
principal es un `ei / jr $` en 0x404F que no vuelve a hacer nada en toda la
sesión.

## Qué tiene de particular

**El juego entero corre dentro de la interrupción.** No una parte: todo. El
reparto, la máquina que juega, el recuento, las pantallas — una máquina de
quince estados (0xE000) con su submodo (0xE001), despachada en cada fotograma
desde el gancho del teclado. El programa principal no recupera el control nunca.

**El ordenador no juega al mahjong.** Sus trece fichas son fijas —las escribe
0x78CE en el cartucho, a una de completarse— y no descarta jamás de su mano: la
ficha que suelta la **sortea del muro** (0x583C) y luego la filtra para que
parezca un descarte humano. En las dificultades 2 y 3 los cuatro primeros son
honores, los cuatro siguientes terminales, nunca una de sus propias esperas, y
nunca de su palo si ya tiene plan de palo. Cada candidata rechazada vuelve al
montón. El hueco vacío que se le ve en la mano boca abajo también es teatro
(0x553C).

**El texto de la mesa vive en el hueco de las fichas.** Cada ficha son seis
tiles, dos de ancho por tres de alto, y las hileras caen a caballo de dos
tercios de la pantalla: la fila del medio de cada ficha no se dibuja nunca en el
tercio central. El cartucho escribe ahí sus rótulos, justo en esos huecos: de
los 97 tiles que gasta la barra de estado, 56 son el par central de alguna
ficha.

## Por qué te puedes fiar

`make` traza el flujo, genera el listado y exige que al ensamblarlo salga
exactamente el original:

```
  ensamblado : 32768 bytes  24cb5bda...188b9b40
  original   : 32768 bytes  24cb5bda...188b9b40
OK: reproducible byte a byte
```

Un listado puede reensamblar perfecto y estar mal —si unos gráficos se leen como
instrucciones los bytes no cambian—, así que corren dos controles más: ningún
rango declarado como datos puede salir como código, y ningún punto de entrada
puede caer dentro de uno.

## El cartucho en cifras

| | |
|---|---|
| bytes de código | 15.432 (47,09 %) |
| bytes de datos | 17.336 (52,91 %) |
| bytes sin identificar | **0** |
| etiquetas con nombre | 1.091 |
| comentarios anclados | 2.320 (30,7 % de las líneas) |
| rutinas por debajo del 10 % comentado | **0 de 1.001** |
| rangos de datos explicados | 89 |

## Algo de lo que salió

- **El mismo 8 es estado y dificultad.** 0x418C escribe 8 en 0xE000, y el `rra`
  de dos instrucciones más allá convierte ese mismo 8 en el 4 que va a 0xE040.
  El estado 8 no llega a despacharse nunca: el `jp` que sigue desemboca en la
  rutina que hace `inc`, así que dura unas instrucciones y se convierte en 9.
- **El despachador lee su propia dirección de retorno.** 0x408F empieza con
  `pop hl`, o sea que la tabla de saltos va **pegada detrás del `call`**. Por eso
  no se puede añadir un decimosexto estado: la tabla está pegada al código del
  estado 0.
- **El palo de riichi sólo se lo lleva un ganador que estuviera en riichi**, de
  mil en mil, y si no se queda en la mesa para la mano siguiente — que no es
  como funciona el mahjong de cuatro. La única excepción es el jugador 1 ganando
  la mano que cierra la partida (sur, reparte el 2). **Medido** llamando a
  0x5E70 con la RAM puesta a mano y leyendo 0xE04A y los dos marcadores.
- **Con tsumo el perdedor paga la parte de un jugador pero el ganador cobra la
  cifra entera del ron** (0xE1B1 contra 0xE1E4). Por eso los dos marcadores no
  suman 60.000, y eso explica una lectura que parecía un fallo.
- **A partir de 5 honba, para estar en tenpai cada espera tiene que valer 3 han**
  (0x7B3B: `cp 3 / ccf`), contados desde cero y sin dora. Diverge de todo lo
  documentado sobre la variante.
- **Una errata del cartucho en 0x595C**: la rama que evita que el ordenador
  suelte terminales se vuelve en el `jr nz` de después del `cp 1` y nunca llega
  a mirar el 9, así que no rechaza nada.
- **La mano del rival en el demo está escrita en el cartucho**, no repartida.
- **El sonido número 0 no se puede pedir**: el puntero de la tabla se pone dos
  bytes antes (0x9CA1) para que el sonido 1 caiga en la primera entrada de
  verdad.
- **El reproductor de sonido no es el de Athletic Land.** Misma casa, mismo año,
  y lo único que comparten es la tabla de doce semitonos.
- **El demo no juega dos veces la misma mano.** Dos arrancadas en frío dan
  trazas idénticas, pero dos vueltas seguidas del mismo encendido no: volcando
  0xE000-0xE3FF en la pantalla de recuento de las dos vueltas salen 72 bytes
  distintos de 1.024.
- **Este cartucho no lleva la marca oculta de Konami.** Otros cartuchos de la
  misma casa esconden su número de catálogo y el título en katakana al final de
  la ROM, un detalle documentado por Manuel Pazos; aquí los últimos 8.219 bytes
  son 0xFF y nada más.

## El cabo que el binario no puede cerrar

El cartucho acaba con **8.219 bytes de 0xFF** (0x9FE5-0xBFFF) y ninguna
instrucción suya toca 0xA000-0xBFFF. Dos explicaciones dan el mismo fichero: un
chip de 32 KB con 8 KB sin grabar, o uno de 24 KB cuyo volcado leyó de más. Nada
en el código decide entre las dos, así que se publica como ROM de 32 KB —que es
como se juega en emulador y en flashcart— y la pregunta se deja abierta.

## Para empezar

Hacen falta `pasmo`, `z80dasm` y Python 3. La imagen del cartucho **no** se
distribuye aquí: pon la tuya en la raíz como `mahjong.rom`, 32768 bytes,
sha256 `24cb5bda5f55dcd5ab1343fb61ebac67e8c292f9714ee7a492431e33188b9b40`.

```sh
make          # traza, genera el listado y lo comprueba todo
make verify   # ensambla y compara con el cartucho
make sanity   # lo que el reensamblado no puede cazar
make test     # los tests del listado
make densidad # cuánto del listado está comentado
```

## Licencia y atribución

El juego no es nuestro: *Konami's Mahjong Dojo* es de Konami, y todos los
derechos siguen siendo de quien los tenga. Lo que sí es nuestro —las
herramientas, los comentarios y la documentación— se publica con la licencia de
`LICENSE`. La imagen del cartucho no se distribuye. Ver
[AVISO-LEGAL.md](AVISO-LEGAL.md).
