# El código

De los 32768 bytes del cartucho, **15.432 son código y 17.336 son datos**. No
queda ni uno sin asignar.

## El juego entero corre dentro de la interrupción

Cuando INIT termina de montar la máquina, no llama a ningún bucle principal:
llega a 0x404F, que es un `jr` a sí mismo, y ahí se queda para siempre. Todo lo
demás cuelga del gancho `H.KEYI` que acaba de instalar.

    404F:  jr 404Fh

La rutina de interrupción hace tres cosas en orden. Reconoce el VDP, mueve el
sonido —siempre, pase lo que pase—, y luego mira el semáforo de 0xE005: si el
fotograma anterior sigue dentro, se sale sin más; si no, lo levanta, vuelve a
abrir las interrupciones, lee los mandos y le da un latido a la máquina de
estados. Ese semáforo es lo único que impide que un cuadro largo se solape con
el siguiente.

Así que un fotograma de este juego es una llamada, no una vuelta de bucle, y
todo el estado tiene que vivir fuera de la pila. De ahí que el kilobyte de
0xE000 a 0xE3FF esté lleno de contadores, cursores y banderas.

## El despachador que se lee a sí mismo

Los quince estados y sus pasos se despachan con esta rutina, y no es la de
siempre:

    408F:  add a,a          ; cada entrada son dos bytes
    4090:  pop hl           ; la direccion de RETORNO es la tabla
    4091:  call 4063h       ; HL += A
    4094:  ld e,(hl)
    4095:  inc hl
    4096:  ld d,(hl)
    4097:  ex de,hl
    4098:  jp (hl)          ; y salta: no se vuelve por aqui

El `pop hl` se queda con la dirección de retorno y la usa como base de la tabla,
o sea que **la tabla va pegada detrás del `call`** que invoca al despachador. Se
ahorra el `ld hl,tabla` de cada llamada, y a cambio el manejador que salga
hereda como dirección de retorno lo que hubiera debajo de la tabla.

Hay cinco tablas escritas así, y entre las cinco son todo el esqueleto del
juego: quince palabras para los estados en 0x40ED, y dos, dos, nueve y cuatro
para los pasos de los estados 7, 10, 11 y 12.

Para el desensamblado esto es un problema por partida doble: el `jp (hl)` corta
el trazado, y los bytes que hay detrás de cada `call` son datos en mitad del
código. Los treinta y dos destinos van declarados a mano en el `.entries` y los
cinco rangos en el `.nocode`, cada uno con su justificación escrita al lado.

## Un solo juego de variables para los dos jugadores

El menú de llamadas, el motor de manos y el detector de jugadas no saben de
quién es el turno. Trabajan siempre sobre las mismas direcciones, y lo que hay
antes y después es una copia: 0x517A trae a esas variables compartidas las del
jugador que toca —cursor, hueco de la ficha robada, último hueco, marca de
tsumo, riichi y esperas— y 0x51BC las devuelve.

Es la razón de que la máquina pueda cantar pon o chi pasando **por el mismo
despachador de menú** que la persona: se le cargan sus variables, se le pone el
bit de la llamada y entra por donde entraría un jugador.

## El motor de manos

Decidir si una mano está completa es lo más grande del cartucho (0x5F3E-0x656D),
y no es una tabla ni una búsqueda genérica: es un **árbol de casos escrito a
mano** sobre la mano ya ordenada. En cada paso mira la ficha del cursor y las
tres o cuatro siguientes, y de lo que encuentra —iguales, seguidas, sueltas—
cuelga una rama distinta. Lo que va encontrando lo apunta en cuatro listas:
escaleras, tríos, cuartetos y la pareja, cada figura con una marca que dice si
está abierta.

Cuando una rama no cuadra, hay vuelta atrás, pero **no es recursiva**: se guarda
una copia de la mano y de las figuras en uno de dos huecos, con un byte que dice
cuántas copias hay y otro qué rama probar al restaurar. Dos niveles y ni uno
más. Si se agotan, la mano se declara indescomponible.

Encima de ese motor corre el detector de jugadas de 0x7B3F: **veintisiete
comprobaciones** que leen lo que dejaron las cuatro listas y apuntan cada
jugada que cuadra con su número de han.

Y todo se apoya en cómo está codificada una ficha. El número va en el nibble
bajo, así que «la siguiente de la escalera» es una resta que da 0xFF, y los
honores, que empiezan en 0x31, no cuadran en ninguna escalera sin que nadie
tenga que comprobarlo.

## Cómo se hizo, y por qué te puedes fiar

El listado no se escribe a mano. `tools/z80trace.py` sigue el flujo real desde
los puntos de entrada declarados, `tools/mkasm.py` monta el `.asm` con las
anotaciones ancladas a dirección, y de ahí salen las cifras.

`make verify` reensambla y compara con la ROM original: tiene que salir
**idéntico byte a byte**, y sale. Pero eso solo no basta, porque unos datos
leídos como código dan el mismo binario —los bytes no cambian, cambia lo que se
dice de ellos—, así que `make sanity` comprueba además que ningún rango
declarado como datos aparezca como instrucción, que ningún punto de entrada
caiga dentro de una zona de datos, y que ni uno de los 32768 bytes se quede sin
asignar.

Sobre eso hay dos medidas más. `make notas` caza los dos fallos que se pierden
en silencio al anotar: un comentario anclado a una dirección que no es
instrucción, y dos comentarios para la misma. Y `tools/densidad.py` mide, rutina
a rutina, cuántas instrucciones llevan comentario:

| | |
| --- | ---: |
| bloques de código con etiqueta | 1.001 |
| de ellos, con nombre propio | 340 |
| bloques de datos, con su nombre y la anchura de sus filas | 89 |
| instrucciones | 7.548 |
| instrucciones con comentario | 2.320 (**30,7 %**) |
| rutinas por debajo del 10 % de comentarios | **0** |

Esa última fila es la que importa: una rutina con nombre pero sin un solo
comentario está bautizada, no explicada, y aquí no queda ninguna.
