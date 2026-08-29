# Las reglas del cartucho, leídas del código

Konami's Mahjong (RC-707, 1984) es un mahjong de **dos jugadores**, y lo que en
el riichi de cuatro se da por hecho aquí no se supone. Este documento dice qué
reglas aplica el cartucho y **dónde** las aplica: cada línea lleva la dirección
de la rutina que la decide en `src/mahjong.asm`. El riichi de cuatro (el de
riichi.wiki) sale solo para ponerle nombre a lo que hace el cartucho y para
señalar dónde se separa de él.

Los estados:

- **LEÍDO** — sale de las instrucciones del listado, que reensambla byte a byte.
- **MEDIDO** — además se ha visto correr en openMSX; la evidencia va en la
  propia línea, con el fichero del volcado o del log.
- **SUPOSICIÓN** — una lectura que el código NO confirma. Van marcadas una a
  una y están todas juntas en el §11, que es la lista de lo que este documento
  **no** puede anclar al binario.

Cerrado el 2026-08-29 (paso 5). Las medidas nuevas de esta tanda se hicieron
con dos guiones de emulador que quedan en el repositorio:
`tools/omsx_mide_pagos.tcl` (la tabla de pago y los palos de riichi, llamando a
las rutinas del cartucho con la RAM puesta a mano) y `tools/omsx_fuerza_pantallas.tcl`
(las pantallas que el demo no enseña). Los volcados de VRAM y RAM del demo
salen de `tools/omsx_vuelca_vram.tcl`.

Lo que dice "jugador 1" es la mano de abajo (0xE13A, río 0xE15E, marcador
0xE047); "jugador 2" es la de arriba (0xE14C, río 0xE172, marcador 0xE044).
En partida el 1 es la persona y el 2 la máquina; en el demo el 1 lo lleva el
guion de 0x4AE8.

## 1. La mesa

| regla | dónde | estándar | estado |
| --- | --- | --- | --- |
| 34 tipos de ficha, 4 copias de cada: 136. Códigos palo<<4 \| número; 0x31-0x37 son los honores | tabla 0x4FBF, contadores 0xE186 | coincide | LEÍDO |
| **El palo 0 son los caracteres (萬), el 1 los círculos y el 2 los bambúes; y los honores 0x31-0x37 son 東南西北白發中 en ese orden**. Cada ficha son seis tiles (2 de ancho por 3 de alto) y su primero lo da la tabla 0x4735, indexada por el código | 0x4735, dibujadas por 0x472C | coincide | **MEDIDO**: la mano del demo en 0xE13A es `02 06 08 08 09 11 13 15 17 22 22 31 31 33` y en pantalla se lee 二萬 六萬 八萬 八萬 九萬 · 1 3 5 7 de círculos · dos 2 de bambú · 東 東 西 (`work/reglas/mano_del_demo.png`). Los siete honores, dibujados uno a uno desde la tabla, en `work/reglas/fichas_y_honores.png` |
| El bambú lo confirma además el 緑一色 (0x8118), que sólo acepta 0x22 0x23 0x24 0x26 0x28 y el dragón 0x36 | 0x8118 | coincide | LEÍDO |
| No hay muro: cada ficha se sortea al hacer falta, rechazando los tipos con 4 copias gastadas | 0x4F64, 0x4F2B | diverge (no hay muro muerto ni orden de robo) | LEÍDO |
| Dos indicadores: 0xE1D3 es el del dora y 0xE1D4 el del ura-dora, que sólo cuenta con riichi; el dora es el siguiente del indicador (9→1, 北→東, 中→白) | 0x81A9, 0x8270 | coincide | LEÍDO. **En el demo el indicador de dora es SIEMPRE 0x32 (南)**: 0x4EC5 sólo sortea el primero si hay partida (bit 6 de 0xE002). MEDIDO: 0xE1D3 = 0x32 en el volcado del demo |
| **El ura-dora se ve boca abajo mientras se juega y sólo se destapa en el recuento si el ganador iba en riichi.** Los dos indicadores se dibujan igual (0x7024), pero encima del segundo va una marca: al repartir se pone la "a" (tile 0x22, el dorso, 0x4ED0 → 0x701B) y al montar la pantalla de recuento se cambia por la "b" (tile 0x1A, la ficha destapada) sólo si el bit 0 del riichi del ganador está puesto | 0x7024; 0x4ED0; 0x5A52-0x5A64 (0xE1CD el 1, 0xE1AE el 2) | coincide | LEÍDO. MEDIDO en la mesa del demo: la celda f11 c20 trae el tile 0x22, el dorso |
| **El que reparte tiene 20 descartes y el otro 18** (0xE1C0 para el 1, 0xE1C1 para el 2, puestos en 0x50DD); en cuanto uno se pasa, la mano se agota sin ganador (0x548C, 0x55BC → 0x5654). A partir del descarte 18 ya no hay riichi | 0x50DD, 0x548C, 0x55BC, 0x665C | diverge (en cuatro manda el muro) | LEÍDO. **MEDIDO**: en el demo reparte el 1 (0xE04D = 0) y el volcado da 0xE1C0 = 0x14 (20) y 0xE1C1 = 0x12 (18) |
| 30.000 puntos por jugador al empezar | 0x4C43 | — | **MEDIDO**: 0xE047 y 0xE044 valen `00 00 03` (BCD de tres bytes, 30.000) y la barra los pinta |

## 2. El reparto: no es limpio

| regla | dónde | estado |
| --- | --- | --- |
| **La mano de la máquina se construye, no se roba.** Antes de repartir, 0x78CE arma 14 fichas con un plan (0xE058): un palo (0xE059), un objetivo de fichas en tríos (0xE057), el resto en escaleras del palo o en parejas, y una pareja al final. Luego QUITA una ficha (0x7A93): la máquina empieza cada mano a una ficha de completarla. Con la tecla 3 la que falta es siempre la de índice 11 | 0x78CE-0x7AB5 | LEÍDO |
| El plan depende del marcador de la máquina (en rojos → plan 4; por debajo de 10.000 → plan 2), de los honba (5 o más, 8 si reparte ella) y de sorteos | 0x78F5-0x7936 | LEÍDO |
| Las copias que la máquina gasta se descuentan de 0xE186: al jugador no le pueden salir después | 0x7ADA, 0x79B4 | LEÍDO |
| La mano del jugador se roba de verdad (13 fichas) y, **a partir de la tercera mano sin ganar él** (0xE062), se le siembra un trío y una o dos escaleras encima | 0x4DA6, 0x48E1; 0xE062 sube en 0x5EE1 y 0x76A9 y vuelve a cero en 0x5EF2 | LEÍDO |
| En el demo la máquina lleva siempre la mano fija de 0x7AEA: seis parejas y un 南 suelto, siete parejas a falta del 南 | 0x78D5, D 0x7AEA | LEÍDO. **MEDIDO**: 0x7AEA es `32 39 08 08 17 17 25 25 33 33 13 13 21 21` y el volcado del demo da 0xE14C = `08 08 13 13 17 17 21 21 25 25 32 33 33 39`, la misma mano ordenada |
| **La máquina no descarta de su mano.** Sus 13 fichas son fijas y la robada de cada turno pisa siempre el mismo hueco (0xE208, 0x54A5); lo que va a su río es una ficha SORTEADA del muro (0x583C), filtrada para que parezca un descarte humano: en las dificultades 2 y 3, los cuatro primeros son honores, del 4 al 7 unos, doses, ochos y nueves, nunca una de sus esperas antes de su turno de riichi, y con plan de palo nunca de su palo; en la 1, cualquiera. Cada candidata rechazada vuelve al montón (0x59A4) | 0x583C-0x58D5, 0x598F, 0x556C | LEÍDO |
| **El hueco que se ve vacío en su mano boca abajo es teatro** (0x553C): en riichi y desde el descarte 0xE33D siempre el de la robada; antes, al azar o la robada según el bit 0 de la semilla | 0x553C, 0x551D | LEÍDO |
| **La máquina no gana antes de su descarte 0xE33D** aunque tenga la ficha: con ron la deja pasar y con tsumo sortea otra robada que no sea espera; tampoco gana justo en su turno de riichi. Canta con 2 han o más, o con 1 si hay menos de 5 honba | 0x567B, 0x56B6 | LEÍDO |
| **Defensa**: en el descarte 15, si el jugador está en riichi con esperas y (su turno de riichi es de 15 en adelante, o el jugador ha soltado menos de dos honores o terminales, o el plan no tiene bits altos) pasa a defensa (0xE340 = 1); también en el 18 con la semilla par. En defensa no gana, no declara riichi, y descarta de verdad una ficha de su mano que ya esté en el río del jugador -segura por furiten-, reponiéndola con una sorteada | 0x59EB, 0x5A10, 0x567E, 0x577D | LEÍDO |
| Del descarte 12 en adelante, sin defensa, no suelta el palo que el jugador menos ha descartado (cuenta su río por palos, 0x58D6). La rama de los terminales está mal escrita: el `jr nz` tras `cp 1` devuelve antes de mirar el 9 y nunca rechaza nada | 0x58D6-0x5987, **errata en 0x595C** | LEÍDO |
| Una de cada cuatro veces tras robar (bits 0-1 de la semilla a cero) intenta un kan por el menú | 0x54A8 | LEÍDO |
| Si gana el jugador con menos de diez descartes, antes de destapar la mano de la máquina una ficha sorteada pisa su penúltimo hueco | 0x5083-0x50A1 | LEÍDO; **el porqué es SUPOSICIÓN** (§11) |

### 2.1. El plan de la máquina, bit a bit (0xE058)

El plan no es un número con nombre: es un byte de banderas, y cada bit lo mira
un sitio distinto. Esto es lo que hace cada uno, leído de los ocho sitios que
lo consultan.

| bit | quién lo mira | qué hace |
| ---: | --- | --- |
| 0 | 0x4EF1, 0x7AC7 | al construir la mano, cualquier ficha vale para la pareja suelta (0x7ACA); y en 0x4EF1 gobierna el ajuste del turno de tsumo: el ajuste se salta SÓLO si el bit 0 está puesto y los dos bits bajos de la semilla (0xE064) valen cero; en cualquier otro caso 0x4EFE sube 0xE33D a un valor entre 8 y 11 cuando había salido por debajo de 8 |
| 1 | 0x5802, 0x5865, 0x7ACC | con el 2: la máquina puede hacer **chi** (0x5805, `and 6`) y filtra sus descartes para no soltar su palo (0x5868, `and 6`); en la pareja suelta acepta un honor |
| 2 | 0x5802, 0x5865, 0x57EF | lo mismo que el 1: chi y filtro de palo; y con el 5, **pon** (0x57F2, `and 0x26`) |
| 3 | 0x799D, 0x79F0, 0x7A32, 0x7A74 | la mano se construye **sólo con terminales y honores**: tríos de 0x30 en adelante (0x79A5), escaleras 1-2-3 y 7-8-9 (0x79F8), parejas iguales (0x7A3A) y la pareja del final (0x7A7C) |
| 5 | 0x57EF; lo pone 0x798C | **pon** permitido. Se enciende solo cuando el objetivo de fichas en tríos es 12 (0x7987) |
| 7 | lo pone 0x7A67 | **siete parejas**: se enciende cuando el reparto por parejas llega a doce fichas, o sea seis parejas y la del final (0x7A5C) |
| 3-7 (0xF8) | 0x5A00 | con alguno puesto, la máquina **no se defiende** (0x5A03) |
| 1-7 (0xFE) | 0x5793 | con 5 honba o más, hace falta alguno para que la máquina **declare riichi** |

Los valores que se llegan a escribir: **0x81** en el demo (0x78D8: bit 0 + siete
parejas, que es justo la mano fija de 0x7AEA, seis parejas a falta del 南),
**4** si la máquina va en números rojos (0x78FA), **2** si está por debajo de
10.000 (0x7902), **1** o **2** o **9** por sorteo (0x7930, 0x7936, 0x794E), y el
`sra (hl)` de 0x7925 y 0x7942, que corre el plan un bit a la derecha. MEDIDO: en el
demo 0xE058 vale 0x81.

## 3. Las llamadas

| regla | dónde | estándar | estado |
| --- | --- | --- | --- |
| El menú de la derecha, de arriba abajo: agari, riichi, **pon, chi**, kan (bits 1, 2, 4, 8, 0x10 de 0xE1C7) | 0x660A, 0x663C | — | LEÍDO. `docs/la_partida.md` lo leyó de una captura como アガリ/リーチ/チー/ポン/カン; el código pone el pon antes que el chi |
| Pon: dos copias en mano y el último descarte del rival; no en riichi, no en la fase 1 | 0x680B | coincide | LEÍDO |
| Chi: escalera con el último descarte del rival, honores no; con dos o tres formas posibles el jugador elige con izquierda/derecha y espacio | 0x692F, 0x69F9 | coincide (en cuatro sólo se chi del de la izquierda; aquí sólo hay un rival) | LEÍDO |
| Kan: daiminkan (descarte del rival + 3 en mano), ankan (4 en mano, o 3 + la robada), shouminkan (la robada sobre un pon propio). El ankan se pinta con las dos de fuera boca abajo (código 0x38) | 0x6C12, 0x6DE4 | coincide | LEÍDO |
| **En riichi, el ankan sólo vale si no cambia las esperas**: se recalculan y, si cambian, se deshace. La máquina pasa esa comprobación siempre | 0x6E87, 0x6E0F | coincide con la regla estándar | LEÍDO |
| Tras un kan, la ficha siguiente es la de reposición y marca 0xE1CF para el 嶺上開花 | 0x6E45, 0x7EB1 | coincide | LEÍDO |
| Cada llamada sube 0xE2B6: mano abierta. Y lo que roba del rival se apunta en 0xE22D/0xE232 porque desaparece del río | 0x68BB, 0x6B95, 0x6917 | — | LEÍDO |
| **El pon de la máquina sale entero de su propia mano.** Al jugador se le piden DOS copias (0x6851, 0x6858) y la tercera es el descarte del rival; a la máquina se le pide una **tercera** (0x6863) y las tres se le quitan de la mano (0x6872 y 0x6875-0x6879), además de borrar el descarte del río (0x687B) como en el otro caso. El trío que se escribe son tres copias iguales (0x68A7-0x68AE) en los dos. Y la máquina **no ajusta los contadores** de fichas en la parte cerrada: 0x68BF se salta el bloque de 0x68D0 que sí le resta 3 al jugador. Cuadra con que su mano tiene catorce fichas -la robada ya está en 0xE208 cuando 0x577A prueba el pon- | 0x6841-0x687B, 0x68A7-0x68AE, 0x68BF-0x68D8 | — | LEÍDO |
| La máquina, además, no hace pon si la ficha-1 o la ficha+1 están al lado en su mano ordenada (0x684A y 0x686D); y con más de una forma de chi, no hace chi. Intenta el pon y el chi en la fase 5, DESPUÉS de robar (0x54BE → 0x577A → 0x57EF), y pasa por el mismo despachador que la persona (0x5828 → 0x663C) | 0x684A, 0x686D, 0x69FD, 0x577A, 0x5828 | — | LEÍDO |

## 4. El riichi

| regla | dónde | estándar | estado |
| --- | --- | --- | --- |
| Riichi: mano cerrada (0xE2B6 = 0), acabar de robar, no estar ya en riichi, no ir por el descarte 18 | 0x6653 | coincide salvo el límite de fichas | LEÍDO |
| Cuesta 1.000 puntos, que van a la mesa (0xE04A) | 0x53B8 (el jugador: 0x5F24 le quita mil y 0xE04A sube uno) / 0x579A (la máquina, 0x57AB) | coincide | LEÍDO en los dos |
| **El palo de riichi de la mesa sólo se lo lleva un ganador que estuviera en riichi** (bit 0 de 0xE1CD el 1, de 0xE1AE el 2), de mil en mil, uno cada 32 cuadros; la única excepción es el jugador 1 ganando en la mano que cierra la partida (sur, reparte el 2), que se los lleva esté o no en riichi. Si no, se quedan en la mesa (0xE04A) para la mano siguiente | 0x5E70-0x5EA8; el pago, 0x5EB2-0x5ECF | **diverge** (en cuatro los palos van al ganador siempre) | **MEDIDO** el 2026-08-29, llamando a 0x5E70 con la RAM puesta a mano y leyendo 0xE04A y los marcadores (`work/omsx_mide_pagos.log`): gana el 1 sin riichi → el palo se queda y nadie cobra; gana el 1 con riichi → 0xE04A a 0 y +1.000 al 1; gana el 2 sin riichi → se queda; gana el 2 con riichi → +1.000 al 2; **gana el 1 sin riichi en el cierre (sur + reparte el 2) → se lo lleva igual, +1.000**; y el 2 en ese mismo cierre y sin riichi, **no** |
| En el demo esto no llega a correr: 0x5E75 mira el bit 6 de 0xE002 y, sin persona jugando, se va directo a 0x5F00 | 0x5E70-0x5E75 | — | LEÍDO. MEDIDO: 0xE002 = 0x00 en el volcado del demo |
| Doble riichi: declarado con el descarte 0 (0xE1CC = 0; 0xE1BB para la máquina) | 0x7BBE, 0x7C0B | coincide | LEÍDO |
| Ippatsu: la mano se cierra en el descarte siguiente al de la declaración | 0x7BD2 | coincide (no se comprueba que no haya habido llamadas en medio) | LEÍDO |
| La máquina declara riichi exactamente en su descarte número 0xE1BB (y nunca en el 19), si tiene esperas, la mano está cerrada, no está en defensa y, con 5 honba o más, su plan lo permite (0x5793, `and 0xFE`); 0xE1BB = sorteo − 1 + 3/5/7 según la tecla 1/2/3 | 0x577A-0x57EC, 0x50F5 | — | LEÍDO. Si un 0xE1BB alto la hace más dura o más blanda **es SUPOSICIÓN** (§11) |

## 5. Ganar: agari, furiten y castigos

| regla | dónde | estándar | estado |
| --- | --- | --- | --- |
| El jugador canta con "agari" en el menú; la máquina se pregunta sola (0x575A) si tiene jugada | 0x5033, 0x575A | — | LEÍDO |
| Una mano completa son 4 figuras + pareja (0x6042), siete parejas (0x64F8, sin cuatro iguales) o trece huérfanos (0x651D). El motor es un árbol de casos con vuelta atrás de dos niveles | 0x6042-0x656D | coincide | LEÍDO |
| Cantar con la mano incompleta se rechaza sin castigo: sale el dibujo 2 de la caja de mensajes, que además suena y para un momento ("NOT ALLOWED" en el parche al inglés). El mismo dibujo lo piden el riichi rechazado (0x5378), el kan que no vale (0x66DA) y la llamada que no cuadra (0x68F7) | 0x505E-0x50A4 → 0x50B2-0x50B4, y 0x476F | — | LEÍDO. MEDIDO en pantalla: `work/parche/caja_not_allowed_en.png` |
| **Cantar sin jugada es castigo**: 12.000 si el jugador reparte, 8.000 si no, pagados por el jugador 1 | 0x7B08 → 0x4280 → 0x76D9, 0x4290 | coincide con el chombo (mano límite invertida) | LEÍDO |
| **Furiten**: las esperas del jugador cruzadas con su propio río (0xE15E) y con lo que la máquina le robó del río (0xE233). En la dificultad 1 el ron en furiten **se rechaza** sin castigo; en las 2 y 3 **se castiga** con 12.000/8.000 | 0x4833; 0x5045 (tecla 1), 0x4260 (teclas 2 y 3) | diverge en la forma (en cuatro el ron en furiten es chombo siempre, y el furiten permanente no se avisa) | LEÍDO |
| Furiten de riichi: en las dificultades 2 y 3, si tras el riichi del jugador la máquina descartó una de sus esperas, el ron posterior se castiga igual; y al acabarse la mano sin ganador también cuenta como castigo | 0x47FB, 0x76C6-0x76D9 | diverge (en cuatro sólo impide el ron) | LEÍDO |
| Los tres avisos que salen con el castigo, elegidos por (0xE1AC & 7) en la tabla 0x7853: furiten sobre el propio río, ron dejado pasar y canto sin jugada; debajo, el rótulo del chombo | 0x76F2-0x7708; listas 0x7865, 0x786F, 0x7879 y 0x785B | — | LEÍDO. MEDIDO en pantalla: `work/parche/aviso_furiten_en.png`, `aviso_missed_ron_en.png`, `aviso_no_yaku_en.png` y `penalty_hand_en.png` |
| **A partir de 5 honba hacen falta 2 han de jugadas, sin contar dora** (ryanhan shibari) | 0x7B11-0x7B26 | coincide con la variante | LEÍDO |
| El trío cerrado con la ficha de ron cuenta como abierto (fu y 暗刻) | 0x6185 | coincide | LEÍDO |
| Con cuatro iguales en la mano ordenada se borra la marca de ficha de ron | 0x5FEE | — | LEÍDO; **el porqué es SUPOSICIÓN** (§11) |

## 6. Las jugadas (yaku) y sus han

Detector 0x7B3F; cada jugada la apunta 0x82E6 con su índice (el de los nombres
de 0x747B, transcritos en la nota D) y sus han. "c/a" es cerrada/abierta.

| índice | nombre en el cartucho | han | dónde | estándar |
| ---: | --- | --- | --- | --- |
| 1 | テンホー tenhou | yakuman | 0x82DE | coincide |
| 2 | チーホー chiihou | yakuman | 0x82E3 | coincide; **el renhou (ron al primer descarte del que reparte) se apunta con este mismo índice** (diverge: en cuatro el renhou no suele ser yakuman) |
| 3 | コクシムソウ kokushi musou | yakuman | 0x7B54 | coincide |
| 4 | ツーイーソウ tsuuiisou | yakuman | 0x7EF4 | coincide |
| 5 | ダイスウシー daisuushii | yakuman | 0x8039 | coincide; **no hay shousuushii** |
| 6 | ダイサンゲン daisangen | yakuman | 0x8167 | coincide |
| 7 | チューレンポートー chuuren poutou | yakuman | 0x7F46 | **sólo se detecta en el palo 0**, el de los caracteres (0x7F1A) |
| 8 | チンロートウ chinroutou | yakuman | 0x81A3 | **deja pasar el 東 como si fuera un uno** (0x8197) |
| 9 | リューイーソウ ryuuiisou | yakuman | 0x8138 | coincide |
| 10 | スーアンコウ suuankou | yakuman | 0x7DD2 | coincide |
| 11 | スーカンツ suukantsu | yakuman | 0x7DA0 | coincide |
| 12 | ダブルリーチ | 2 | 0x7BF1 | coincide |
| 13 | リーチ | 1 | 0x7BEC | coincide |
| 14 | リーチソク riichi + ippatsu | 2 | 0x7BF6 | coincide (1+1) |
| 15 | ダブルリーチソク | 3 | 0x7BE7 | coincide (2+1) |
| 16 | メンゼン ツモ | 1 | 0x829F | coincide |
| 17 | チンイツ chinitsu | 6c/5a | 0x7EFD | coincide |
| 18 | リャンペイコウ ryanpeikou | 3 | 0x7D93 | coincide |
| 19 | サンシキドウコウ sanshoku doukou | **3** | 0x7E1C | **diverge: en cuatro son 2** |
| 20 | チートイ chiitoitsu | 2 | 0x7B5B | coincide en han; **no tiene sus 25 fu** (ver §7) |
| 21 | ホンイツ honitsu | 3c/2a | 0x80E3 | coincide |
| 22 | トイトイ | 2 | 0x7DBC | coincide |
| 23 | ジュンチャン junchan | 3c/2a | 0x7FD2 | coincide |
| 24 | サンアンコウ sanankou | 2 | 0x7DE1 | coincide |
| 25 | サンカンツ sankantsu | 2 | 0x7DA5 | coincide |
| 26 | ショウサンゲン shousangen | 2 | 0x8175 | coincide |
| 27 | ホンロートウ honroutou | 2 | 0x8112 | coincide |
| 28 | ピンフ pinfu | 1 | 0x7CBE | **sólo con ron** (0x7C99): diverge de riichi.wiki, coincide con la variante sin pinfu-tsumo |
| 29 | タンヤオ | 1 | 0x7ED5 | coincide; abierto vale (kuitan) |
| 30 | イーペーコウ | 1 | 0x7D8E | coincide |
| 31 | イッツウ ittsu | 2c/1a | 0x7CF1 | coincide |
| 32 | サンシキ sanshoku doujun | 2c/1a | 0x7D40 | coincide |
| 33 | チャンタ | 2c/1a | 0x7FC5 | coincide |
| 34 | ヤクハイ | 1 por trío (el viento doble, 2) | 0x8053 | coincide; el viento del asiento es 東 para el que reparte y 南 para el otro (0x8061-0x806B) |
| 35 | ハイテイ ツモ | 2 | 0x7C71 | **lleva el tsumo dentro** (0xE1D0 evita sumarlo dos veces): 1+1 |
| 36 | ハイテイ フリコミ (houtei) | 1 | 0x7C6B | coincide |
| 37 | リンシャンカイホウ | 1 | 0x7EBB | coincide |
| 38 | ドラ・ウラドラ | 1 por dora | 0x81D9 | coincide; el ura sólo con riichi |

Lo que **no** hay: shousuushii, chankan, nagashi mangan, aka-dora, kan-dora,
doble yakuman. Con un yakuman en la lista no se escriben las demás jugadas
(0x70CF).

## 7. Los fu

| regla | dónde | estándar | estado |
| --- | --- | --- | --- |
| Base 20; **30 si la mano está cerrada y es ron** | 0x7305-0x731D | coincide | LEÍDO |
| Trío: 2 (en medio, abierto), 4 (en medio cerrado, o terminal/honor abierto), 8 (terminal/honor cerrado) | 0x71BC-0x71D9 | coincide | LEÍDO |
| Cuarteto: 8/16 y 16/32 | 0x721D-0x723C | coincide | LEÍDO |
| Pareja: 2 si es dragón, viento de la ronda (0x31+0xE04C) o **viento del que reparte** (0x31+0xE04D, sea quien sea el ganador); 4 con los dos vientos | 0x7298-0x72B1 | diverge en el asiento del que no reparte (le cuenta el 東 en vez de su 南) | LEÍDO |
| Espera: kanchan, penchan y tanki 2; ryanmen y shanpon 0. Tsumo +2 (el código los lleva juntos en 0x72D1 y 0x72E2, y 0x7300 resta 2 en el ron) | 0x72B8, 0x5BDB-0x5C59 | coincide | LEÍDO |
| **El tipo de espera se escribe debajo del recuento**, con una tira de tiles por caso: 0x7428 ryanmen (bit 0 de 0xE1D2), 0x742F kanchan (bit 1), 0x7436 penchan (bit 2), 0x743D tanki (bit 3) y 0x7444 shanpon (ningún bit); y al lado el 0x744B del tsumo o el 0x744E del ron, según el bit 0 de 0xE1D1 | 0x72B8, 0x72EE, 0x72F4; listas en 0x7428-0x7451 | — | LEÍDO. En el parche al inglés se leen RYANMEN / KANCHAN / PENCHAN / TANKI / SHANPON y TSUMO / RON: `work/espera_en.png` |
| Total redondeado hacia arriba a la decena | 0x7356 | coincide | LEÍDO |
| **Siete parejas: sin el 25 fijo**, se cuentan como una mano normal (20/30 + pareja + espera) | 0x7176-0x731F no miran 0xE205 | **diverge** | LEÍDO |
| Todo en BCD, con `daa` | 0x7344 | — | LEÍDO |

## 8. El pago

| regla | dónde | estándar | estado |
| --- | --- | --- | --- |
| Menos de 5 han: tabla por fu (filas 20…90, y 100+) y han (1-4), la del que reparte (0x5C97) o la del otro (0x5CA9), según 0xE04E | 0x5B22-0x5B41, 0x5C5A, 0x5C70 | las cifras coinciden con la tabla de cuatro | **MEDIDO**: la tabla entera está abajo |
| **20 fu con 1 han paga 0** (más honba): la fila 0 de las dos tablas es 0000, 0x5C5A manda los 20 fu a esa fila y 0x7356 sólo redondea hacia arriba, sin mínimo de 30 para mano abierta. Sólo se llega con RON, mano abierta, espera ryanmen o shanpon y sin fu de figuras ni de pareja (con tsumo los +2 de la espera lo suben a 30): un tanyao abierto de escaleras ganado por ron | 0x5CBB, 0x5D03, 0x5C5A, 0x7356 | **diverge** | **MEDIDO** el 2026-08-29: con 0xE1E1 = 0x20 y 0xE316 = 1, la rutina 0x5B22 deja 0 en los dos pendientes, con las dos tablas y con ron y con tsumo (`work/omsx_mide_pagos.log`). Que **sólo** se llegue por esa vía sigue siendo lectura del código, no medida (§11) |
| **100 fu o más se paga como 8 han** (baiman: 24.000/16.000, y 8.000 con tsumo). Por eso la novena fila de las tres tablas de pago (0x5CFB, 0x5D43, 0x5DD5) no se lee nunca; la de "al robar" es una fila de 110 fu de verdad (1.800/3.600), muerta | 0x5B2D → 0x5B6B con A = 8 | diverge (rareza) | **MEDIDO**: con 0xE1E1/0xE1E2 = 0x0100 salen 24.000 (reparte) y 16.000 (el otro) con cualquier han, y 8.000 de pago con tsumo |
| 5 han o más: mangan 12.000/8.000, haneman (6-7) 18.000/12.000, baiman (8-10) 24.000/16.000, sanbaiman (11-13) 36.000/24.000; 13 es el tope | 0x5B6B, 0x5D4B, 0x5D5D | coincide (no hay kazoe yakuman: 13 han siguen siendo sanbaiman) | LEÍDO |
| Yakuman: 48.000/32.000, y se apilan (hasta cinco) | 0x5B57, 0x5D6F, 0x5D79 | coincide | LEÍDO |
| **Honba: +300 por honba en el ron, +100 en el tsumo** | 0x5C7F, 0x5BB5 | coincide en cifras (en cuatro el tsumo son 100 por pagador; aquí hay uno) | **MEDIDO**: 30 fu 1 han del que reparte, ron: 1.500 → 1.800 con 1 honba y 2.400 con 3. Con tsumo, lo pagado va 500 → 600 → 800 (+100) y lo cobrado 1.500 → 1.800 → 2.400 (+300) |
| **Con tsumo el perdedor paga la parte de un solo jugador** (tabla "al robar" de 0x5D83) **pero el ganador cobra la cifra entera del ron**: 0x5B85 carga la misma palabra en los dos pendientes y con tsumo sólo rebaja el del que paga (0xE1B1), no el del que cobra (0xE1E4). Se crean puntos de la nada, y la pantalla del recuento lo imprime tal cual: ハライ (lo pagado) y トクテン (lo cobrado) | 0x5B85-0x5BDA, 0x5D83-0x5DF9 | diverge (en cuatro los tres pagos del tsumo suman lo que cobra el ganador) | **MEDIDO** dos veces: en el demo (7 han 30 fu, reparte y gana el 1 por tsumo; 0xE1B1 = 0x0060 y 0xE1E4 = 0x0180, ハライ 6000 / トクテン 18000 en pantalla, marcadores 48.000 y 23.000, volcados 040-042) y forzando la rutina en las 72 casillas de la tabla |
| **La tabla del tsumo es UNA SOLA** (0x5D83): 0x5BAF la carga sin mirar 0xE04E, así que el perdedor paga lo mismo gane el que reparte o gane el otro | 0x5BAC-0x5BB2 | diverge (en cuatro el tsumo del que reparte cobra más a cada uno) | **MEDIDO**: las dos mitades del log dan los mismos pagos |
| Los puntos se mueven de cien en cien, un fotograma cada uno, con sonido | 0x5DF9 | — | LEÍDO |
| Tenpai al acabarse la mano: 1.500 del que no está al que está; con los dos o ninguno, nada. **A partir de 5 honba, para estar en tenpai cada espera tiene que valer 3 han** (0x7B3B: `cp 3 / ccf` deja el acarreo puesto con 3 o más, y 0x774E/0x77BA sin acarreo niegan el tenpai). Cada espera se evalúa desde cero (0x5F82 limpia 0xE2F1-0xE32A, donde vive el contador 0xE316) y sin dora (el salto de 0x7B00 se da antes de 0x7B28) | 0x7713-0x7814, 0x7B38 | 1.500 coincide con "dos y dos"; el requisito de 3 han diverge de todo lo conocido | LEÍDO; comprobado a mano el 2026-08-28, **no medido** (§11) |

### 8.1. La tabla de pago, medida

Medida el 2026-08-29 poniendo los fu en 0xE1E1, los han en 0xE316, quién gana
en 0xE04E y el tsumo en 0xE1D1, y llamando a 0x5B22 desde el bucle principal
con el juego congelado. Las 152 líneas están en `work/omsx_mide_pagos.log`; el
guion es `tools/omsx_mide_pagos.tcl`. Sin honba, en puntos.

**Ron — gana el que reparte (tabla 0x5C97):**

| fu | 1 han | 2 han | 3 han | 4 han |
| ---: | ---: | ---: | ---: | ---: |
| 20 | **0** | 2.000 | 3.900 | 7.700 |
| 30 | 1.500 | 2.900 | 5.800 | 11.600 |
| 40 | 2.000 | 3.900 | 7.700 | 12.000 |
| 50 | 2.400 | 4.800 | 9.600 | 12.000 |
| 60 | 2.900 | 5.800 | 11.600 | 12.000 |
| 70 | 3.400 | 6.800 | 12.000 | 12.000 |
| 80 | 3.900 | 7.700 | 12.000 | 12.000 |
| 90 | 4.400 | 8.700 | 12.000 | 12.000 |
| 100+ | 24.000 | 24.000 | 24.000 | 24.000 |

**Ron — gana el que no reparte (tabla 0x5CA9):**

| fu | 1 han | 2 han | 3 han | 4 han |
| ---: | ---: | ---: | ---: | ---: |
| 20 | **0** | 1.300 | 2.600 | 5.200 |
| 30 | 1.000 | 2.000 | 3.900 | 7.700 |
| 40 | 1.300 | 2.600 | 5.200 | 8.000 |
| 50 | 1.600 | 3.200 | 6.400 | 8.000 |
| 60 | 2.000 | 3.900 | 7.700 | 8.000 |
| 70 | 2.300 | 4.500 | 8.000 | 8.000 |
| 80 | 2.600 | 5.200 | 8.000 | 8.000 |
| 90 | 2.900 | 5.800 | 8.000 | 8.000 |
| 100+ | 16.000 | 16.000 | 16.000 | 16.000 |

**Tsumo — lo que PAGA el perdedor (tabla 0x5D83, la misma reparta quien
reparta).** Lo que COBRA el ganador es la cifra de las dos tablas de arriba,
sin rebajar: ahí está el agujero.

| fu | 1 han | 2 han | 3 han | 4 han |
| ---: | ---: | ---: | ---: | ---: |
| 20 | **0** | 700 | 1.300 | 2.600 |
| 30 | 500 | 1.000 | 2.000 | 3.900 |
| 40 | 700 | 1.300 | 2.600 | 4.000 |
| 50 | 800 | 1.600 | 3.200 | 4.000 |
| 60 | 1.000 | 2.000 | 3.900 | 4.000 |
| 70 | 1.200 | 2.300 | 4.000 | 4.000 |
| 80 | 1.300 | 2.600 | 4.000 | 4.000 |
| 90 | 1.500 | 3.000 | 4.000 | 4.000 |
| 100+ | 8.000 | 8.000 | 8.000 | 8.000 |

## 9. La partida

| regla | dónde | estado |
| --- | --- | --- |
| Ronda y reparto: (este, reparte 1) → (este, 2) → (sur, 1) → (sur, 2). El reparto pasa cuando gana el que no reparte; se queda si gana el que reparte o si está en tenpai en una mano sin ganador | 0x5ED0-0x5F12, 0x77CD-0x7809 | LEÍDO |
| **En la ronda del sur, una mano sin ganador no mueve el reparto** aunque el que reparte no esté en tenpai (0x7803, 0x77ED) | 0x77CD | LEÍDO; **si es intención o descuido es SUPOSICIÓN** (§11) |
| La partida se acaba cuando el que no reparte gana en (sur, reparte 2): 0x5F00 pone el bit 4 de 0xE1A8 | 0x5EFA-0x5F03 | LEÍDO |
| **El `cp 6` de 0x41EC NO cierra la partida**: calcula una espera en fotogramas antes de repartir. En la ronda del este, y en la del sur si el viento de la ronda no es el del que reparte, la espera son honba+1 fotogramas mientras no llegue a 6, y 64 en cuanto llega; 0x41FC sólo guarda A en 0xE004, la cuenta atrás del estado | 0x41DC-0x4206 | LEÍDO. Corrige la lectura anterior, que lo tomaba por el sexto envite |
| Honba: +1 por mano sin ganador y por mano que gana el que reparte; a cero cuando cambia el reparto | 0x780A, 0x5EEB, 0x5F08 | LEÍDO |
| Al final de la partida, el estado 13 pinta el rótulo de cierre y el 14 lo deja 112 cuentas de cuatro fotogramas antes de volver al demo | 0x43DB-0x43FD; rótulo 0x8598 | LEÍDO. **MEDIDO**: el demo pasa por ahí en cada vuelta; el volcado con el rótulo en pantalla es de t = 161,8 s arrancando en frío (`work/parche/final_end_en.png`) |
| Los marcadores pueden bajar de cero (signo en 0xE100) y la máquina lo mira para su plan (0x78F5) | 0x8307, 0x78F5 | LEÍDO |
| La mano sin ganador saca el cartel de 0x782C y, si hay castigo, el aviso de la fila 11 y el rótulo de la 12 | 0x76A6-0x7710 | LEÍDO. MEDIDO en pantalla: `work/parche/draw_game_en.png` |

## 10. Lo que las tres dificultades cambian, todo junto

| tecla | rótulo | qué cambia | dónde |
| --- | --- | --- | --- |
| 1 | AMACHUA | el ron en furiten se rechaza sin castigo; sin furiten de riichi; el riichi en furiten se rechaza (0x539A); la máquina suma 3 a su turno de riichi; sin reloj (hay que pulsar para robar); la ayuda de 0x49C6: en riichi no deja descartar una espera y avisa cuando el descarte de la máquina le da ron; los descartes de la máquina no se filtran | 0x5045, 0x4260, 0x539A, 0x50F5, 0x55F1, 0x49C6, 0x584B |
| 2 | SEMIPROFESSIONAL | el furiten se castiga con 12.000/8.000; +5 al turno de riichi de la máquina; reloj: 10 s para descartar (aviso a los 7) y el robo sale solo a los 12 s; los descartes de la máquina, filtrados | 0x4260, 0x50F5, 0x5292-0x52AB, 0x55E2-0x55EF, 0x583C |
| 3 | PROFESSIONAL | lo de la 2; +7 al turno de riichi; el sorteo de 0xE33D se repite si sale 20 o más; y **a la máquina le falta siempre la ficha de índice 11** de su mano construida | 0x4EEA, 0x7A9D |

La dificultad viaja en 0xE040 y no en 0xE002: con la tecla 1 queda 0x01, con la
2 queda 0x04 y con la 3 queda 0x02 (medido el 2026-08-22 con
`tools/omsx_prueba_dificultad.tcl`, un log por tecla en `work/`). En el demo,
sin tocar ninguna tecla, 0xE040 vale 0x04 y la mesa marca SEM.

## 11. Lo que este documento NO puede anclar al binario

Todo lo de arriba sale de instrucciones concretas. Esto no, y por eso va
aparte. Ninguna de estas frases debe repetirse en otro sitio como si fuera un
hecho del cartucho.

1. **Por qué, si gana el jugador con menos de diez descartes, una ficha
   sorteada pisa el penúltimo hueco de la mano de la máquina** (0x5083-0x50A1).
   El qué está leído; el para qué, no.
2. **Por qué se borra la marca de ficha de ron cuando hay cuatro iguales en la
   mano ordenada** (0x5FEE). Igual: se ve lo que hace, no por qué.
3. **Si el sur sin cambio de reparto (0x77CD) es intención o descuido.** El
   código no lo dice y no hay comentario ni tabla que lo aclare.
4. **Si un 0xE1BB alto hace a la máquina más dura o más blanda.** Se sabe cómo
   se calcula (0x50F5) y qué gatea (0x577A), no qué efecto tiene en la partida:
   eso pide jugar muchas manos y contar, no leer.
5. **Que a los 20 fu con 1 han SÓLO se llegue con ron, mano abierta y espera
   ryanmen o shanpon.** Que esa casilla paga 0 está medido; que ése sea el
   único camino para caer en ella es un recorrido a mano por el contador de fu
   (§7), no una medida.
6. **El tenpai con 3 han por espera a partir de 5 honba** (0x7B38, 0x774E,
   0x77BA). Leído instrucción a instrucción y comprobado a mano, pero **no
   medido**: haría falta llegar a 5 honba y agotar una mano.
7. **Que los 8 KB de 0x9FE5 a 0xBFFF del cartucho original fueran grabables.**
   No es una regla del juego, pero el parche al inglés los usa y conviene
   decirlo aquí también: en el binario son 0xFF, y que el chip real los tuviera
   grabables no lo dice nada del cartucho. En emulador y en flashcart funciona.

Y una cosa que **sí** se cerró y conviene no volver a abrir: el `cp 6` de
0x41EC no es el sexto envite de la partida, es una espera en fotogramas (§9).
