# Preguntas abiertas

El binario está explicado al 100 %: no queda un byte sin asignar ni una rutina
sin nombre. Lo que queda son preguntas de **por qué**, y esas el binario no las
contesta solo.

## Si el riichi tardío de la máquina la hace más dura o más blanda

El descarte en el que la máquina declara riichi sale de un sorteo más 3, 5 o 7
según la dificultad, y ese mismo número es el que le abre la puerta a cantar.
Está leído qué hace y está medido que las tres teclas dan tres cantidades
distintas. Lo que no está claro es hacia dónde tira: declarar riichi más tarde
significa jugar más turnos sin descubrirse, pero también dejar pasar manos que
podría haber cerrado antes. Para saberlo hay que jugar muchas partidas y
contarlas, no leer más código.

## Qué distingue de verdad los planes de mano

Antes de cada mano, la máquina elige un plan y lo guarda en un byte. Está leído
qué compuertas abre cada bit —hacia un palo, permitirse el pon, permitirse el
chi, no defenderse— y está leído quién lo decide, con su marcador y sus honba.
Lo que no está es qué significa cada plan en dureza: si el que sale cuando la
máquina va perdiendo es más agresivo o simplemente distinto.

## Si la mano que paga cero se puede dar jugando

La primera fila de las dos tablas de pago es 0000, y aquí no existe el mínimo de
30 fu que en el riichi de cuatro impide llegar a ella. Sobre el papel, una mano
abierta de escaleras, con espera ryanmen, ganada por ron y con una sola jugada,
cobra cero más los honba. Está **leído y comprobado a mano, pero no medido**: no
se ha visto ocurrir en el emulador.

## De qué tamaño era el chip

El cartucho acaba en 0x9FE4 y detrás hay 8.219 bytes de 0xFF. Eso es compatible
con una memoria de 32 KB con el último banco sin grabar y con una de 24 KB de la
que el volcador leyó ocho de más, y desde el volcado las dos son idénticas.
Solo lo aclara mirar un cartucho de verdad.

## Dos decisiones que parecen descuidos

En la ronda del sur, una mano sin ganador **no mueve el reparto** aunque el que
reparte no esté en tenpai, que es justo al revés de lo que hace en la ronda del
este. Y si el jugador gana con menos de diez descartes, antes de destapar la
mano de la máquina una ficha sorteada pisa su penúltimo hueco. Las dos cosas
están leídas del código; si son intención o descuido, no lo dice.

Hay un tercer caso parecido: con cuatro fichas iguales en la mano ordenada se
borra la marca de la ficha de ron, lo que cambia los fu de esa figura. El qué
está claro, el porqué no.
