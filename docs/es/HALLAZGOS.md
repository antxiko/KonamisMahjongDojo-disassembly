# Hallazgos

Cosas que aparecieron al desmontar el cartucho y que no caben en ninguna otra
página. Cada una dice de dónde sale.

## El mismo 8 es un estado y una dificultad

Al arrancar el demo, el cartucho escribe un 8 en el byte del estado. Ese 8 no
llega a despacharse nunca —la instrucción siguiente pasa por la rutina que hace
`inc`, así que el estado que corre es el 9—, y sin embargo el 8 se escribe. La
razón está tres instrucciones más abajo:

    418C:  ld a,008h
    418E:  ld (0E000h),a    ; el estado... que se convertira en 9
    418F:  rra              ; el mismo 8, rotado: sale un 4
    4190:  ld (0E040h),a    ; y ese 4 es LA DIFICULTAD

El mismo byte sirve para dos cosas que no tienen nada que ver, y de rebote deja
el demo jugando **en la dificultad de en medio**. Se ve en la memoria —0xE040
vale 4 durante todo el ciclo— y se ve en pantalla, porque la barra de arriba lo
rotula: en el demo pone セミプロ, y una partida empezada con la tecla 1 pone
アマ en el mismo sitio.

Esa es también la única forma de llegar al estado 8 de verdad, el de la pantalla
de dificultad: escribiendo el 8 desde el lector de teclado, que es otro sitio y
no pasa por el `inc`. Por eso el demo no lo ve nunca.

## Cuatro bytes de relleno para una dirección redonda

INIT escribe a mano el salto del gancho de interrupción: `ld a,0C3h`, la
dirección, y a `H.KEYI`. La dirección que escribe es 0x4071, y el código que
viene antes se acaba con un `ret` en 0x406C. Los cuatro bytes que sobran,
0x406D a 0x4070, están rellenos de 0xFF: no son basura ni sobras del
ensamblador, están ahí para que la rutina de interrupción empiece exactamente
donde INIT dice que empieza.

## El texto de la mesa vive en el hueco de las fichas

La pantalla de la mesa está prácticamente llena: los 256 tiles de cada tercio
apenas dan para los dibujos de las fichas, que gastan seis tiles cada una.

Pero las hileras de fichas caen siempre **a caballo de dos tercios**, y eso deja
un hueco. En el tercio de en medio solo se ve la fila de abajo de las fichas de
arriba y la fila de arriba de las de abajo: **la fila del medio de cada ficha no
se dibuja nunca ahí**. Y ahí es donde está metido el texto.

Cruzando la tabla de fichas con las tablas de nombres de 124 volcados de memoria
de vídeo, de los 97 tiles que usa la barra central, **56 son exactamente el par
central de alguna ficha**: el 東 son los dos pares que sobran de las fichas que
empiezan en 0xA6 y 0xAC, el 局 los de las de 0xCA y 0xD0, y el menú de llamadas
entero sale de los huecos de cuatro fichas más. Los otros 41 son tiles propios.

O sea que el mismo número de tile es media ficha en un tercio y un kanji en
otro, sin estorbarse.

## El reparto lleva dentro una regla del mahjong de verdad

La animación del reparto va en tandas, y quien decide de cuántas fichas es cada
una es 0x4E59: si el contador de repartidas ya vale 12, la siguiente tanda es de
**una**; si no, de **cuatro**. Cuatro, cuatro, cuatro y una: trece, que es
exactamente como se reparte una mano en el mahjong japonés.

No es un detalle de dibujo. El bucle no termina hasta que el contador llega a
trece.

## La mano del rival en el demo está escrita en el cartucho

En una partida, la mano de la máquina se construye ficha a ficha. En el demo no:
0x78DD copia catorce bytes de 0x7AEA y ahí se acaba el reparto de ese lado.

Y esa mano es una broma para quien sepa mirarla. Los catorce bytes son `32 39
08 08 17 17 25 25 33 33 13 13 21 21`: **seis parejas, un 南 suelto y un
hueco**, o sea siete parejas a falta del 南 —una chiitoitsu a una ficha—. Al
llegar el recuento, la memoria del rival la tiene ordenada y sigue igual:
`08 08 13 13 17 17 21 21 25 25 32 33 33 39`.

Nunca la completa. El guion está escrito para que gane el otro.

## El sonido número 0 no se puede pedir

La tabla de punteros de los sonidos empieza en 0x9CA3, pero el código la indexa
desde **0x9CA1**, dos bytes antes, para que el sonido 1 caiga en la primera
entrada de verdad. Eso deja la entrada 0 pisando el final de la rutina que hay
justo encima: 0x9CA1 es el desplazamiento de un `djnz` y 0x9CA2 el `ret` que lo
sigue, así que el «puntero» del sonido 0 son los bytes 0xE8 y 0xC9. Pedirlo
sería saltar a 0xC9E8, fuera del cartucho.

No pasa, porque no lo pide nadie. Y en el otro extremo de la tabla, los sonidos
31, 32 y 33 apuntan los tres al mismo sitio.

## Un `ret` suelto al que llaman tres veces

En 0x9EA2, dentro del reproductor de sonido, hay un solo byte: un `ret`. Lo
llaman tres sitios distintos del propio driver. Lo que hubiera ahí se quitó en
algún momento y las llamadas se quedaron.

## Un bloque comprimido al que le falta la cabecera

El intérprete de dibujos comprimidos empieza leyendo dos bytes con el destino en
VRAM. Los patrones del menú de llamadas no los traen: 0x4B5B pone el destino a
mano en DE y entra al intérprete **tres bytes más adentro**, saltándose
justamente las dos instrucciones que lo leerían.

Y justo detrás está el complemento: en vez de comprimir también los colores de
esos 208 bytes, se rellena el mismo tramo de la tabla de color con un byte fijo,
repetido 208 veces. Mismo tamaño, mismo sitio, un byte de datos en vez de un
bloque.
