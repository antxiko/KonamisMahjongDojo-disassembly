# Las reglas

Este cartucho juega un mahjong reconocible: riichi japonés, con sus llamadas,
sus yaku, sus fu y su tabla de pago. Pero es de **dos jugadores**, y eso obliga
a decidir cosas que en una mesa de cuatro se dan por hechas. Cada regla de aquí
lleva la dirección de la rutina que la toma.

## Las fichas

Una ficha es un byte: el palo en el nibble alto y el número en el bajo. Salen
34 códigos con huecos —0x01 a 0x09, 0x11 a 0x19, 0x21 a 0x29 y 0x31 a 0x37—,
con cuatro copias de cada uno, o sea las 136 de un juego completo. La lista está
en 0x4FBF y la tabla inversa, la que devuelve un índice de 0 a 33 sin huecos,
en 0x59B3.

| palo | qué es |
| ---: | --- |
| 0 | los **caracteres**, 一萬 a 九萬 |
| 1 | los **círculos** |
| 2 | los **bambúes** |
| 3 | los siete **honores**, 東南西北白發中 en ese orden |

Los bambúes se identifican solos: el detector del 緑一色 de 0x8118 solo acepta
0x22, 0x23, 0x24, 0x26, 0x28 y el dragón 0x36, que son exactamente los bambúes
verdes. Los otros dos se ven en pantalla. La mano recién repartida del demo
—la de la imagen de [El juego](EL-JUEGO.html#la-mesa)— es
`02 06 08 08 09 · 11 13 15 17 · 22 22 · 31 31 33`, y lo que sale dibujado son
cinco caracteres, cuatro círculos, dos bambúes y tres honores, en ese orden.

Que el número vaya en el nibble bajo no es un capricho de codificación: hace
que «la siguiente de la escalera» sea una resta, y que los honores, a partir de
0x31, no puedan cuadrar en ninguna escalera por aritmética. El motor de manos
se apoya en eso todo el rato.

## No hay muro

Las fichas de una partida no salen de una tira revuelta al empezar. **Se
sortean una a una según hacen falta**, y lo que impide que salga una quinta
copia es una tabla de treinta y cuatro contadores en 0xE186, uno por tipo: si
el sorteo saca un tipo con las cuatro copias gastadas, se resiembra y se vuelve
a sortear (0x4F64, 0x4F2B). Es muestreo sin reemplazo por rechazo, no una
baraja.

De ahí que tampoco haya muro muerto ni orden de robo, y que el final de la mano
se decida de otra manera: **el que reparte tiene 20 descartes y el otro 18**
(0xE1C0 y 0xE1C1, puestos en 0x50DD). En cuanto uno se pasa, la mano se agota
sin ganador. Del descarte 18 en adelante ya no se puede declarar riichi.

## Las llamadas

| llamada | qué exige | dónde |
| --- | --- | ---: |
| pon | dos copias en mano y el último descarte del rival; no en riichi | 0x680B |
| chi | escalera con el último descarte del rival, honores no | 0x692F |
| kan | tres formas: con el descarte del rival, con cuatro en mano, o añadiendo la robada a un pon propio | 0x6C12 |

Con dos o tres formas posibles de chi, el jugador elige con izquierda y derecha
y confirma con espacio. El kan cerrado se pinta con las dos fichas de fuera
boca abajo, y trae de serie la regla que más se olvida: **en riichi, el kan
cerrado solo vale si no cambia las esperas**. 0x6E87 las recalcula, las compara
y, si no cuadran, deshace el kan.

Tras un kan la ficha siguiente es la de reposición, y queda marcada para el
嶺上開花. Cada llamada sube 0xE2B6, la cuenta de llamadas: la mano deja de estar
cerrada, y eso es lo que quita el riichi, el pinfu y un han a varias jugadas.

## El riichi

Se puede declarar con la mano cerrada, acabando de robar, no estando ya en
riichi y sin haber llegado al descarte 18 (0x6653). Cuesta **1.000 puntos**, que
van a la mesa (0xE04A) en forma de palo. Declarado con el primer descarte es
doble riichi, y si la mano se cierra en el descarte siguiente hay ippatsu.

Y aquí hay una divergencia clara: **el palo de la mesa solo se lo lleva un
ganador que estuviera en riichi**. Si gana quien no lo declaró, los palos se
quedan sobre la mesa para la mano siguiente (0x5E70-0x5EA8). La única excepción
es el jugador 1 ganando la mano que cierra la partida, que se los lleva
declarara o no.

## Ganar

Una mano completa son cuatro figuras y una pareja (0x6042), siete parejas
(0x64F8) o trece huérfanos (0x651D). Cantar con la mano incompleta se rechaza
sin castigo. Cantar **sin jugada** sí es castigo: 12.000 puntos si el jugador
reparte y 8.000 si no.

El furiten —esperar una ficha que ya se ha descartado— se calcula cruzando las
esperas con el propio río y con lo que el rival haya robado de él. Y no se
trata igual en las tres dificultades: con la primera, el ron en furiten se
rechaza y ya está; con la segunda y la tercera **se castiga** con esos mismos
12.000 u 8.000.

## Las jugadas

El detector de 0x7B3F pasa por veintisiete comprobaciones, y cada una que
cuadra apunta la jugada con su número de han. Los nombres están en 0x747B, en
katakana, y la tabla de punteros que los indexa en 0x7642: **treinta y ocho
jugadas con nombre**, de las cuales las once primeras son yakuman. En cuanto
sale un yakuman, la lista se corta y las demás jugadas no se escriben.

El último tile de cada nombre es el han de la jugada **abierta**, y 0x70BF lo
pisa con el valor cerrado cuando la mano no tiene llamadas: así una sola tabla
sirve para los dos casos.

Casi todo coincide con el riichi de cuatro jugadores, han incluidos, con las
rebajas de mano abierta —chinitsu 6 y 5, honitsu y junchan 3 y 2, ittsu,
sanshoku y chanta 2 y 1— y el tanyao abierto permitido. Lo que **no** hay:
shousuushii, chankan, nagashi mangan, aka-dora, kan-dora ni doble yakuman.

Y lo que se aparta, leído del código:

| jugada | qué hace este cartucho | dónde |
| --- | --- | ---: |
| pinfu | **solo vale con ron**, nunca con tsumo | 0x7C99 |
| sanshoku doukou | vale **3 han**, no 2 | 0x7E1C |
| chuuren poutou | **solo se detecta en el palo 0** | 0x7F1A |
| chinroutou | **deja pasar el 東** como si fuera un uno | 0x8197 |
| renhou | se apunta con el nombre del chiihou, o sea como yakuman | 0x82E3 |
| haitei con tsumo | vale 2 han **con el tsumo dentro**, para no sumarlo dos veces | 0x7C71 |
| siete parejas | valen sus 2 han, pero **no tienen sus 25 fu** | 0x7176 |

El viento del asiento es 東 para el que reparte y 南 para el otro, y el
yakuhai da un han por trío, dos si el viento es doble.

## Los fu

Se cuentan como en el riichi de cuatro: base 20, o 30 con la mano cerrada y
ron; trío 2 o 4 si es de fichas de en medio y 4 u 8 si es de terminales u
honores, según esté abierto o cerrado; cuarteto 8 y 16, o 16 y 32; pareja 2 si
es de dragón o de viento que cuente y 4 si es de los dos vientos; espera 2 con
kanchan, penchan o tanki; 2 más por tsumo; y el total redondeado a la decena de
arriba. Todo en BCD, con `daa`.

La excepción es la de las siete parejas, que en vez de sus 25 fu fijos se
cuentan como una mano cualquiera. Y hay un detalle en la pareja: al que no
reparte se le cuenta el 東 en vez de su 南, o sea el viento del que reparte y no
el suyo.

## El pago

Con menos de 5 han, el pago sale de dos tablas de nueve filas por cuatro
palabras cada una, en BCD: la del que reparte en 0x5CBB y la del otro en
0x5D03. La fila la dan los fu y la columna los han, y las cifras coinciden
exactamente con la tabla estándar del mahjong japonés: 30 fu y 2 han son 2.900
si gana el que reparte y 2.000 si no.

De 5 han en adelante ya no hay fila de fu, sino topes: mangan 12.000 y 8.000,
haneman 18.000 y 12.000, baiman 24.000 y 16.000, sanbaiman 36.000 y 24.000, y
13 han es el límite —no hay kazoe yakuman—. Un yakuman son 48.000 y 32.000, y
se apilan hasta cinco. A todo se le suman 300 puntos por honba en el ron y 100
en el tsumo.

Dos rarezas de esas tablas:

- **20 fu con 1 han paga cero.** La primera fila de las dos tablas es 0000, y
  como aquí no existe el mínimo de 30 fu para mano abierta, hay una mano —
  abierta, de escaleras, espera ryanmen y ron— que se canta y no cobra nada más
  que los honba.
- **De 100 fu para arriba se paga como 8 han**, o sea baiman. Por eso la novena
  fila de las tablas, que existe y está escrita, no se lee nunca.

### Los marcadores no suman 60.000, y es por diseño

Con tsumo, el cartucho saca el pago de otras tablas, las de «al robar», que son
lo que pagaría **un solo jugador** en una mesa de cuatro. Pero 0x5B85 carga la
misma palabra en los dos pendientes y luego solo rebaja el del que paga
(0xE1B1), no el del que cobra (0xE1E4). Resultado: el perdedor paga la parte de
uno y el ganador cobra la cifra entera del ron.

Se crean puntos de la nada, y la pantalla del recuento lo enseña sin disimulo:
ハライ es lo pagado y トクテン lo cobrado, y con tsumo son distintos. En el demo
—7 han, 30 fu, tsumo del que reparte— se pagan 6.000 y se cobran 18.000, y los
marcadores acaban en 48.000 y 23.000.

## La partida

El reparto pasa al otro cuando gana el que no reparte; se queda si gana el que
reparte o si está en tenpai en una mano sin ganador. Cada mano sin ganador y
cada mano que gana el que reparte suben el contador de honba, que vuelve a cero
al cambiar el reparto.

A partir de **5 honba** se endurece: hacen falta 2 han de jugadas, sin contar
dora, para poder ganar (*ryanhan shibari*), y para cobrar el tenpai de una mano
sin ganador cada espera tiene que valer 3 han. El tenpai se paga 1.500 del que
no está al que está; con los dos o con ninguno, nada.

Los marcadores pueden bajar de cero. El signo no va dentro del número, que es
BCD sin signo, sino aparte, en 0xE100, y se ve en pantalla: al pintar, 0x44E7
elige un tile u otro según ese bit.
