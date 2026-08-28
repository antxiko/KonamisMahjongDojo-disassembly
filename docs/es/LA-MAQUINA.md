# La máquina

El rival de este cartucho juega bien. Declara riichi, canta pon y chi, se
defiende cuando va perdiendo y gana manos caras. Lo que no hace es **pensar**:
no evalúa su mano, no calcula esperas para decidir qué soltar y no tiene nada
parecido a una búsqueda. Lo que tiene es un decorado muy bien montado, y todo
él está en el código.

## Su mano no se roba: se construye

Antes de repartir nada, 0x78CE arma catorce fichas a medida siguiendo un plan
que guarda en 0xE058: elige un palo, un objetivo de cuántas fichas van en
tríos, y rellena el resto con escaleras de ese palo o con parejas, dejando una
pareja al final. Después **quita una** (0x7A93).

O sea que la máquina empieza cada mano **a una sola ficha de completarla**. Y no
es un atajo invisible: las copias que gasta se descuentan de los contadores de
0xE186, así que al jugador ya no le pueden salir después.

El plan lo deciden el marcador de la propia máquina —en números rojos tira de
uno, por debajo de 10.000 de otro—, los honba y varios sorteos. Con la tercera
dificultad, además, la ficha que falta es siempre la de índice 11.

## Ni descarta de su mano

Sus trece fichas no se mueven en toda la mano. La que roba cada turno cae
siempre en el mismo hueco (0xE208), y **lo que va a su río es una ficha sorteada
del muro**, no una de su mano (0x583C).

Ese sorteo pasa por un filtro que lo hace parecer un descarte humano. Con las
dificultades 2 y 3:

- los **cuatro primeros** descartes son honores, y nada más que honores;
- los **cuatro siguientes**, unos, doses, ochos y nueves; del noveno en
  adelante ya vale cualquiera;
- nunca una de sus propias esperas, hasta que llega su turno de riichi;
- si el plan va a un palo, nunca una de ese palo;
- y del descarte 12 en adelante, sin defensa, tampoco el palo que el jugador
  menos ha soltado, que 0x58D6 cuenta yendo por su río.

Cada candidata rechazada vuelve al montón y se vuelve a sortear. Con la primera
dificultad no hay filtro: sale lo que salga.

Es exactamente el orden en que descarta una persona —primero lo que no sirve,
luego los extremos, al final lo del medio—, obtenido sin mirar la mano ni una
vez.

### La errata de 0x595C

Junto al filtro del palo hay otro que debería evitar soltar terminales, y está
mal escrito. Compara el número de la ficha con el 1 y, si no lo es, se vuelve;
y si lo es, compara ese mismo 1 con el 9, que tampoco cuadra, y se vuelve
igual:

    595C:  ld a,(0E22Bh)      ; la candidata
    595F:  and 0Fh            ; su numero
    5961:  cp 1
    5963:  jr nz,5987         ; no es un 1 -> se acepta
    5965:  cp 9               ; A vale 1: nunca es 9
    5967:  jr nz,5987         ; -> se acepta igual
    5969:  call ...           ; devolver al monton y sortear otra:
    596C:  call ...           ; TRES instrucciones que no corren nunca

Las tres instrucciones de abajo están perfectamente formadas y **no se ejecutan
jamás**. Se nota poco, porque el filtro de los cuatro descartes que van del
quinto al octavo ya empuja hacia los extremos por otro camino.

## El hueco vacío de su mano es teatro

Al pintar la mano del rival boca abajo, una de las fichas se dibuja como hueco
para que se vea de dónde acaba de robar. Cuál se elija lo decide 0x553C: en
riichi, y a partir de cierto descarte, siempre el de la ficha robada; antes de
eso, **al azar o el de la robada según el bit 0 de la semilla**.

No hay nada detrás. La información que ese hueco parece dar —«acaba de robar y
se ha quedado esa»— la mitad de las veces es falsa.

## No gana cuando puede, gana cuando toca

La máquina tiene un número de descarte marcado (0xE33D) antes del cual **no
canta**, aunque tenga la mano hecha (0x567B). Con ron, deja pasar la ficha; con
tsumo, sortea otra robada que no sea de sus esperas. Tampoco gana justo en su
turno de riichi.

Y cuando por fin canta, exige que valga la pena: 2 han o más, o 1 si hay menos
de 5 honba.

El riichi lo declara **exactamente en el descarte número 0xE1BB**, que se arma
sumándole a un sorteo una cantidad que depende de la tecla: 3 con la primera
dificultad, 5 con la segunda y 7 con la tercera. Y el bit 0 de la semilla decide
si esa suma se hace o no, así que la mitad de las veces la dificultad no cuenta.

## La defensa

En el descarte 15, si el jugador está en riichi con esperas y se cumple alguna
de tres condiciones —que el turno de riichi del rival caiga del 15 en adelante,
que el jugador haya soltado menos de dos honores o terminales, o que el plan no
tenga los bits altos—, la máquina pasa a defensa. También en el 18, si la
semilla es par.

En defensa cambia de comportamiento entero: no gana, no declara riichi, y por
primera vez **descarta de verdad una ficha de su mano**, eligiendo una que ya
esté en el río del jugador, que por furiten no le puede dar ron. El hueco que
deja se rellena con una sorteada.

## Las tres dificultades, todas juntas

| | 1 · AMACHUA | 2 · SEMIPROFESSIONAL | 3 · PROFESSIONAL |
| --- | --- | --- | --- |
| ron en furiten | se rechaza, sin castigo | castigo de 12.000 / 8.000 | castigo de 12.000 / 8.000 |
| furiten de riichi | no hay | sí | sí |
| reloj para descartar | no hay | 10 s, aviso a los 7 | 10 s, aviso a los 7 |
| ayuda al jugador | sí: avisa del ron y no deja descartar una espera propia en riichi | no | no |
| descartes del rival | sin filtrar | filtrados | filtrados |
| turno de riichi del rival | sorteo + 3 | sorteo + 5 | sorteo + 7 |
| la mano construida | — | — | le falta siempre la ficha 11 |
| sorteo de 0xE33D | se acepta el primero | se acepta el primero | se repite si sale 20 o más |

![Una partida en la primera dificultad](../imagenes/partida.png)

Y no hace falta acordarse de qué se pulsó: la barra de arriba lo rotula durante
toda la partida, con una lista distinta para cada dificultad (0x4CB8).
