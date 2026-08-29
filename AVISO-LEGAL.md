# Aviso legal y atribución

*(Also available [in English](LEGAL-NOTICE.md).)*

## De quién es cada cosa

**El juego no es nuestro.** *Konami's Mahjong Dojo* lo publicó **Konami** como cartucho
RC-707 para MSX; el propio cartucho firma «© Konami 1984». Todos los derechos sobre el juego siguen siendo de
sus titulares.

**Lo que sí es nuestro** son las herramientas de este repositorio, los
comentarios del listado, el análisis y la documentación. Eso se publica con la
licencia de `LICENSE`.

## Qué hay en este repositorio

El fichero `src/mahjong.asm` es el desensamblado comentado del cartucho. Se
publica para la **preservación, el estudio y la documentación** de un título que es parte de la historia del software del MSX.

La imagen del cartucho (`.rom`) **no** se distribuye aquí. Quien quiera volver
a montar el listado tiene que poner la suya, y el `Makefile` comprueba su
sha256 antes de hacer nada.

Las capturas de este repositorio no son fotos sueltas: las saca `make capturas`,
que arranca el cartucho en openMSX con `renderer none`, vuelca la memoria de
vídeo en unos instantes fijos y monta el PNG desde el volcado, sin pulsar una
sola tecla. Por eso salen siempre iguales y cualquiera puede repetirlas.

## En qué se apoya

En nada de nadie. Todo lo que se afirma aquí sale de leer este binario, y cada
afirmación lleva su evidencia al lado: la instrucción que lee un dato, la tabla
que cierra exactamente donde tiene que cerrar, o la cuenta que sale sola. Lo
que no está cerrado se dice que no lo está.

## Si eres uno de los autores

Si trabajaste en *Konami's Mahjong Dojo* o tienes derechos sobre el juego, y
preferirías que este material no estuviera publicado, **dilo y se retira, sin
discusión**. La intención de este trabajo es justo la contraria de
perjudicarte: es dejar constancia de cómo se hizo.
