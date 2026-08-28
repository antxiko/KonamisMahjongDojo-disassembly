# Empezar

Este repositorio contiene un **desensamblado comentado** de Konami's Mahjong
para MSX (Konami, 1984, cartucho RC-707). Todo lo que hay aquí sale del binario
y se puede volver a generar desde él.

## Lo que hace falta

- **Python 3** (los dibujos de la web piden además Pillow)
- **pasmo**, para reensamblar
- **z80dasm**, que solo se usa para los mnemónicos
- **openMSX**, solo para rehacer las capturas
- la imagen del cartucho, que este repositorio **no distribuye**

La ROM va en la raíz, como `mahjong.rom`. Son 32768 bytes exactos:

    sha256  24cb5bda5f55dcd5ab1343fb61ebac67e8c292f9714ee7a492431e33188b9b40

`make comprueba` lo verifica.

## Los comandos

    make listado        # rehace src/mahjong.asm a partir de las anotaciones
    make verify         # reensambla y compara con la ROM, byte a byte
    make sanity         # nada declarado como datos puede salir como código,
                        # y ni un byte puede quedarse sin asignar
    make notas          # ningún comentario suelto ni repetido
    make test           # las comprobaciones
    make densidad       # cuántas instrucciones llevan comentario, rutina a rutina
    make capturas       # rehace las imágenes de la web con openMSX
    make web            # rehace esta web

## Qué hay en cada carpeta

| | |
|---|---|
| `src/mahjong.entries` | los puntos de entrada, cada uno con su justificación |
| `src/mahjong.nocode` | los rangos que el trazador no debe leer como código |
| `src/mahjong.notes` | **lo único que se edita a mano**: todas las anotaciones |
| `src/mahjong.asm` | el listado, lo genera `tools/mkasm.py` |
| `tools/` | el trazador, el generador del listado y las herramientas de medida |
| `tests/` | las comprobaciones sobre el listado y las anotaciones |
| `docs/` | esta web |

## Cómo se lee el listado

Las anotaciones van **ancladas a una dirección**, así que sobreviven a un
retrazado. Las directivas siguen las pautas de theNestruo:

| | |
|---|---|
| `L` | una etiqueta y qué hace la rutina |
| `C` | un comentario en esa línea |
| `B` | una cabecera de bloque antes de esa dirección |
| `D` | un rango de datos, con su nombre y su explicación |
| `F` | la anchura de las filas de un bloque de datos |

Las **340 rutinas con nombre** están bautizadas por lo que hacen, no por dónde
caen, y los **89 bloques de datos** llevan cada uno su nombre, su tamaño y la
anchura de sus filas, que es lo que permite leerlos como tablas y no como una
tira de bytes.

## Cómo se hizo

El trazador sigue el flujo real desde los puntos de entrada. Lo que no se puede
deducir estáticamente se declara a mano en el `.entries`, con la razón escrita
al lado: el vector INIT de la cabecera, el gancho de interrupción que INIT
escribe en `H.KEYI`, y los treinta y dos destinos de las cinco tablas del
despachador, que termina en `jp (hl)` y por ahí no se puede seguir.

Ese despachador obliga además a lo contrario: las tablas van **incrustadas
detrás del `call`** que lo invoca, así que esos bytes son datos aunque estén
en mitad del código. Van declarados en el `.nocode`, y `make sanity` comprueba
que ninguno se lea como instrucción.

Aquí no hay ninguna suposición disfrazada de hecho. Lo que no se sabe está en
[Preguntas abiertas](PREGUNTAS-ABIERTAS.html) y lo dice.

## Que se pueda repetir

`make verify` reensambla el listado y compara el resultado con la ROM original.
Tiene que salir **idéntico, byte a byte**. Y `make sanity` comprueba después lo
que el reensamblado no puede cazar: que ningún rango declarado como datos se
esté leyendo como código, y que **ni uno solo de los 32768 bytes** se quede sin
asignar.

Las imágenes de esta web tampoco se hacen a mano. `make capturas` arranca el
cartucho en openMSX sin pintar nada, vuelca la memoria de vídeo en unos
instantes fijos y monta el PNG desde el volcado; la primera pasada no pulsa
una sola tecla, porque el demo se juega solo.
