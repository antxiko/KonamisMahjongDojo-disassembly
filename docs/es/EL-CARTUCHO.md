# El cartucho

Son **32 KB** que ocupan dos páginas del mapa del MSX, de 0x4000 a 0xBFFF, y
un MSX1 les llega de sobra: no hay megaROM, ni conmutador de bancos, ni
hardware de sonido de más.

## Los dieciséis bytes que lee la BIOS

    4000:  41 42 10 40 00 00 00 00 00 00 00 00 00 00 00 00
           A  B  INIT=0x4010

La cabecera declara `AB` y un vector INIT, y deja los otros tres punteros
—STATEMENT, DEVICE y TEXT— a cero. El cartucho no añade instrucciones al BASIC
ni se declara como dispositivo: arranca y se queda con la máquina.

Pero la BIOS solo mapea la **página 1** al leer esa cabecera, así que la mitad
de arriba del cartucho no existe todavía cuando INIT empieza. Lo primero que
hace 0x4010 es encenderla él mismo: lee su propia ranura con `RSLREG`, se queda
con los dos bits de la página 1 y llama a `ENASLT` con H = 0x80, que es la
página 2. A partir de esa llamada hay 32 KB visibles.

Lo demás del arranque es corto: escribe `jp 0x4071` en el gancho de
interrupción `H.KEYI` (0xFD9A), pone la pila en 0xE400, borra de un tirón los
1024 bytes de 0xE000 a 0xE3FF —que son todas las variables del juego—, monta el
PSG y el VDP, y se mete en un salto a sí mismo del que no sale nunca. El resto
está en [El código](EL-CODIGO.html).

## El VDP, con las dos tablas cambiadas

Es SCREEN 2 con sprites de 16×16, y los ocho registros se cargan de la lista de
0x4A1A:

| tabla | dónde |
| --- | ---: |
| colores | 0x0000 |
| patrones de sprite | 0x1800 |
| patrones | 0x2000 |
| nombres | 0x3800 |
| atributos de sprite | 0x3B00 |

Lo llamativo es el orden: R3 = 0x7F y R4 = 0x07 dejan **los colores abajo y los
patrones arriba**, justo al revés de lo que sale con los valores de siempre
(0xFF y 0x03). Funciona igual, pero cualquiera que mire un volcado dando por
hecho lo habitual leerá una cosa por otra.

Hay otro detalle que despista al leer las listas de dibujo: los destinos de
VRAM que traen dentro son de dieciséis bits y **se salen de la memoria de
vídeo**, que en un MSX1 son 16 KB. 0x7962 no es un error: `SETWRT` se come los
dos bits de arriba y escribe en 0x3962, o sea la fila 11, columna 2 de la tabla
de nombres. Todas las listas del cartucho están escritas así.

## Los dos intérpretes de pintado

Casi todo lo que se ve en pantalla es una lista que pasa por uno de estos dos.

**El formato A** lo lee 0x4099, y es el sencillo: dos bytes de destino en VRAM
y detrás los bytes tal cual, con 0xFE para decir «viene otro destino» y 0xFF
para terminar. La gracia está en que tiene **dos puertas**: entrando por
0x409D los bytes pasan intactos y la lista pinta, y entrando por 0x4099 un
`and c` con C = 0 los convierte todos en cero y la misma lista **borra**. No
hay una segunda tabla para apagar lo que se encendió.

**El formato B** lo lee 0x468F, y comprime: cada orden es un contador de siete
bits, y el bit 7 dice si lo que sigue son ese número de bytes literales o un
solo byte que hay que repetir esas veces. Con él suben la fuente, los dibujos de
las fichas y los fondos.

## Las letras y las fichas

Los números de tile de los rótulos son **ASCII desplazado**. La fuente de
0x83B1 son 48 patrones que van a los tiles 0xC0 a 0xEF: los diez dígitos, el
círculo del copyright, el guion y la A a la Z, de forma que el tile de una letra
es su ASCII más 0x90. Por eso los rótulos del cartucho se leen en claro en un
volcado, sin descifrar nada. El mismo bloque se copia a la tabla de colores y a
la de patrones, para que las letras salgan con su color.

El dibujo de una ficha son **seis tiles seguidos**, dos de ancho por tres de
alto, y la tabla de 0x4735 da el primero de los seis a partir del código de la
ficha: una fila por palo, otra para los honores, y todas bajando de seis en
seis. En la fila de los honores hay dos valores que no son fichas: el código
0x38 dibuja el dorso y el 0x39 el hueco vacío.

## El sonido

El cartucho trae su propio reproductor, en 0x9C4A. Se le pide un sonido con su
número en A, y ese número es también su **prioridad**: si el canal ya lleva uno
mayor, la petición se ignora. Por debajo de 0x8D son efectos y van los tres al
mismo canal; de ahí en adelante son música a tres canales.

Cada canal son once bytes de RAM —contador, duración, número, puntero, octava,
volumen, cuenta de repeticiones—, y el driver da **un paso por cuadro** desde la
interrupción. Las órdenes de un sonido son un byte: 0x2n fija la duración, 0x1n
manda un ruido al registro 6 del PSG, 0xFE repite y 0xFF termina; en un efecto,
el nibble alto es el volumen y los doce bits siguientes el periodo.

Los tonos salen de doce divisores en 0x9FD9, uno por semitono, y la octava se
consigue **doblando el periodo** tantas veces como diga el registro de la nota:
cuanto más se dobla, más grave. Sonidos hay 33, de la tabla de punteros de
0x9CA3, y treinta y un sitios del cartucho piden alguno.

## Los últimos 8.219 bytes

De 0x9FE5 a 0xBFFF hay **8.219 bytes de 0xFF seguidos**, y ni una instrucción
del cartucho apunta ahí. El contenido acaba en 0x9FE4, veintisiete bytes antes
de la frontera de los 24 KB, o sea que el programa se escribió para caber en 24.

Lo que el binario **no** dice es qué chip llevaba el cartucho, porque 0xFF es lo
que devuelve tanto una EPROM sin grabar como un bus sin conectar. Puede ser una
memoria de 32 KB con el último banco en blanco o una de 24 KB de la que el
volcador leyó ocho de más, y desde el volcado las dos cosas son idénticas.

## La marca que no está

Muchos cartuchos de Konami de esta época llevan escondido al final de la ROM su
número de catálogo RC-7xx y el título del juego en katakana; lo descubrió
**Manuel Pazos** ([@ManuelPazosMSX](https://twitter.com/ManuelPazosMSX)).

Este no la lleva. En los 32768 bytes no hay ni un `RC-7` en ASCII, ni la palabra
`KONAMI`, ni nada parecido a esa firma: el último byte con contenido es de la
tabla de semitonos y detrás solo hay relleno. El RC-707 de este cartucho sale
del catálogo, no del binario.
