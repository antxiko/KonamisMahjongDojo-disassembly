# Las reglas del cartucho, leídas del código

Borrador del paso 3 para el paso 5 (2026-08-28). Cada regla lleva la dirección
de la rutina que la decide en `src/mahjong.asm`, si coincide con el riichi de
cuatro jugadores (el de riichi.wiki, que aquí solo sirve para ponerle nombre a
lo que hace el cartucho) o diverge, y su estado: **LEÍDO** sale de las
instrucciones; **SUPOSICIÓN** es una lectura que el código no confirma;
**MEDIDO** se ha visto correr en el emulador. Es un cartucho de DOS jugadores,
y lo que en cuatro jugadores se da por hecho aquí no se supone.

Lo que dice "jugador 1" es la mano de abajo (0xE13A, río 0xE15E, marcador
0xE047); "jugador 2" es la de arriba (0xE14C, río 0xE172, marcador 0xE044).
En partida el 1 es la persona y el 2 la máquina; en el demo el 1 lo lleva el
guion de 0x4AE8.

## 1. La mesa

| regla | dónde | estándar | estado |
| --- | --- | --- | --- |
| 34 tipos de ficha, 4 copias de cada: 136. Códigos palo<<4 \| número; 0x31-0x37 son los honores (東南西北白發中 en ese orden) | tabla 0x4FBF, contadores 0xE186 | coincide | LEÍDO |
| El palo 2 (0x21-0x29) son los bambúes: lo dice el 緑一色 (0x8118), que sólo acepta 0x22 0x23 0x24 0x26 0x28 y el dragón 0x36 | 0x8118 | coincide | LEÍDO |
| Los palos 0 y 1 son caracteres y círculos, en algún orden | — | — | SUPOSICIÓN (no leído; se vería en los patrones de las fichas) |
| No hay muro: cada ficha se sortea al hacer falta, rechazando los tipos con 4 copias gastadas | 0x4F64, 0x4F2B | diverge (no hay muro muerto ni orden de robo) | LEÍDO |
| Dos indicadores: 0xE1D3 es el del dora y 0xE1D4 el del ura-dora, que sólo cuenta con riichi; el dora es el siguiente del indicador (9→1, 北→東, 中→白) | 0x81A9, 0x8270 | coincide en la cuenta; los dos indicadores se pintan igual en pantalla (0x7024) | LEÍDO; que el ura se vea es SUPOSICIÓN de que no se tapa en otro sitio |
| **El que reparte tiene 20 descartes y el otro 18** (0xE1C0 para el 1, 0xE1C1 para el 2, puestos en 0x50DD); en cuanto uno se pasa, la mano se agota sin ganador (0x548C, 0x55BC → 0x5654). A partir del descarte 18 ya no hay riichi | 0x50DD, 0x548C, 0x55BC, 0x665C | diverge (en cuatro manda el muro) | LEÍDO |
| 30.000 puntos por jugador al empezar | 0x4C43 | — | MEDIDO |

## 2. El reparto: no es limpio

| regla | dónde | estado |
| --- | --- | --- |
| **La mano de la máquina se construye, no se roba.** Antes de repartir, 0x78CE arma 14 fichas con un plan (0xE058): un palo (0xE059), un objetivo de fichas en tríos (0xE057), el resto en escaleras del palo o en parejas, y una pareja al final. Luego QUITA una ficha (0x7A93): la máquina empieza cada mano a una ficha de completarla. Con la tecla 3 la que falta es siempre la de índice 11 | 0x78CE-0x7AB5 | LEÍDO |
| El plan depende del marcador de la máquina (en rojos → plan 4; por debajo de 10.000 → plan 2), de los honba (5 o más, 8 si reparte ella) y de sorteos | 0x78F5-0x7936 | LEÍDO; qué significa cada plan para la dureza es SUPOSICIÓN |
| Las copias que la máquina gasta se descuentan de 0xE186: al jugador no le pueden salir después | 0x7ADA, 0x79B4 | LEÍDO |
| La mano del jugador se roba de verdad (13 fichas) y, **a partir de la tercera mano sin ganar él** (0xE062), se le siembra un trío y una o dos escaleras encima | 0x4DA6, 0x48E1; 0xE062 sube en 0x5EE1 y 0x76A9 y vuelve a cero en 0x5EF2 | LEÍDO (el contador es "manos sin ganar el jugador 1", corrige la nota de la tanda 5 que sólo lo veía subir) |
| En el demo la máquina lleva siempre la mano fija de 0x7AEA: seis parejas y un 南 suelto, siete parejas a falta del 南 | 0x78D5, D 0x7AEA | LEÍDO |
| **La máquina no descarta de su mano.** Sus 13 fichas son fijas y la robada de cada turno pisa siempre el mismo hueco (0xE208, 0x54A5); lo que va a su río es una ficha SORTEADA del muro (0x583C), filtrada para que parezca un descarte humano: en las dificultades 2 y 3, los cuatro primeros son honores, del 4 al 7 unos, doses, ochos y nueves, nunca una de sus esperas antes de su turno de riichi, y con plan de palo nunca de su palo; en la 1, cualquiera. Cada candidata rechazada vuelve al montón (0x59A4) | 0x583C-0x58D5, 0x598F, 0x556C | LEÍDO |
| **El hueco que se ve vacío en su mano boca abajo es teatro** (0x553C): en riichi y desde el descarte 0xE33D siempre el de la robada; antes, al azar o la robada según el bit 0 de la semilla | 0x553C, 0x551D | LEÍDO |
| **La máquina no gana antes de su descarte 0xE33D** aunque tenga la ficha: con ron la deja pasar y con tsumo sortea otra robada que no sea espera; tampoco gana justo en su turno de riichi. Canta con 2 han o más, o con 1 si hay menos de 5 honba | 0x567B, 0x56B6 | LEÍDO |
| **Defensa**: en el descarte 15, si el jugador está en riichi con esperas y (su turno de riichi es de 15 en adelante, o el jugador ha soltado menos de dos honores o terminales, o el plan no tiene bits altos) pasa a defensa (0xE340 = 1); también en el 18 con la semilla par. En defensa no gana, no declara riichi, y descarta de verdad una ficha de su mano que ya esté en el río del jugador -segura por furiten-, reponiéndola con una sorteada | 0x59EB, 0x5A10, 0x567E, 0x577D | LEÍDO |
| Del descarte 12 en adelante, sin defensa, no suelta el palo que el jugador menos ha descartado (cuenta su río por palos, 0x58D6). La rama de los terminales está mal escrita: el `jr nz` tras `cp 1` devuelve antes de mirar el 9 y nunca rechaza nada | 0x58D6-0x5987, **errata en 0x595C** | LEÍDO |
| Una de cada cuatro veces tras robar (bits 0-1 de la semilla a cero) intenta un kan por el menú | 0x54A8 | LEÍDO |
| Si gana el jugador con menos de diez descartes, antes de destapar la mano de la máquina una ficha sorteada pisa su penúltimo hueco | 0x5083-0x50A1 | LEÍDO; el porqué es SUPOSICIÓN |

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
| La máquina, en el pon, exige tres copias y que ni la ficha-1 ni la ficha+1 estén al lado; con más de una forma de chi, no hace chi. Intenta el pon y el chi en la fase 5, DESPUÉS de robar, con la robada ya en su hueco (0x54BE → 0x577A → 0x57EF), y pasa por el mismo despachador que la persona (0x5828 → 0x663C) | 0x684A-0x686E, 0x69FD, 0x577A, 0x5828 | — | LEÍDO el código y el momento; que las 14 fichas expliquen las tres copias sigue siendo SUPOSICIÓN |

## 4. El riichi

| regla | dónde | estándar | estado |
| --- | --- | --- | --- |
| Riichi: mano cerrada (0xE2B6 = 0), acabar de robar, no estar ya en riichi, no ir por el descarte 18 | 0x6653 | coincide salvo el límite de fichas | LEÍDO |
| Cuesta 1.000 puntos, que van a la mesa (0xE04A) | 0x53B8 (el jugador: 0x5F24 le quita mil y 0xE04A sube uno) / 0x579A (la máquina, 0x57AB) | coincide | LEÍDO en los dos |
| **El palo de riichi de la mesa sólo se lo lleva un ganador que estuviera en riichi** (bit 0 de 0xE1CD el 1, de 0xE1AE el 2), de mil en mil, uno cada 32 cuadros; la única excepción es el jugador 1 ganando en la mano que cierra la partida (sur, reparte el 2), que se los lleva esté o no en riichi. Si no, se quedan en la mesa (0xE04A) para la mano siguiente. En el demo el cierre se salta este paso (0x5E75) y el palo se queda: los volcados 042-055 dan 0xE04A = 1 | 0x5E70-0x5EA8 | **diverge** (en cuatro los palos van al ganador siempre) | LEÍDO; comprobado a mano el 2026-08-28 |
| Doble riichi: declarado con el descarte 0 (0xE1CC = 0; 0xE1BB para la máquina) | 0x7BBE, 0x7C0B | coincide | LEÍDO |
| Ippatsu: la mano se cierra en el descarte siguiente al de la declaración | 0x7BD2 | coincide (no se comprueba que no haya habido llamadas en medio) | LEÍDO |
| La máquina declara riichi exactamente en su descarte número 0xE1BB (y nunca en el 19), si tiene esperas, la mano está cerrada, no está en defensa y, con 5 honba o más, su plan lo permite; 0xE1BB = sorteo − 1 + 3/5/7 según la tecla 1/2/3 | 0x577A-0x57EC, 0x50F5 | — | LEÍDO. Si un 0xE1BB alto la hace más dura o más blanda sigue sin saberse |

## 5. Ganar: agari, furiten y castigos

| regla | dónde | estándar | estado |
| --- | --- | --- | --- |
| El jugador canta con "agari" en el menú; la máquina se pregunta sola (0x575A) si tiene jugada | 0x5033, 0x575A | — | LEÍDO |
| Una mano completa son 4 figuras + pareja (0x6042), siete parejas (0x64F8, sin cuatro iguales) o trece huérfanos (0x651D). El motor es un árbol de casos con vuelta atrás de dos niveles | 0x6042-0x656D | coincide | LEÍDO |
| Cantar con la mano incompleta se rechaza sin castigo (el dibujo del rincón) | 0x505E-0x50A4 | — | LEÍDO |
| **Cantar sin jugada es castigo**: 12.000 si el jugador reparte, 8.000 si no, pagados por el jugador 1 | 0x7B08 → 0x4280 → 0x76D9, 0x4290 | coincide con el chombo (mano límite invertida) | LEÍDO |
| **Furiten**: las esperas del jugador cruzadas con su propio río (0xE15E) y con lo que la máquina le robó del río (0xE233). En la dificultad 1 el ron en furiten **se rechaza** sin castigo; en las 2 y 3 **se castiga** con 12.000/8.000 | 0x4833; 0x5045 (tecla 1), 0x4260 (teclas 2 y 3) | diverge en la forma (en cuatro el ron en furiten es chombo siempre, y el furiten permanente no se avisa) | LEÍDO |
| Furiten de riichi: en las dificultades 2 y 3, si tras el riichi del jugador la máquina descartó una de sus esperas, el ron posterior se castiga igual; y al acabarse la mano sin ganador también cuenta como castigo | 0x47FB, 0x76C6-0x76D9 | diverge (en cuatro sólo impide el ron) | LEÍDO |
| **A partir de 5 honba hacen falta 2 han de jugadas, sin contar dora** (ryanhan shibari) | 0x7B11-0x7B26 | coincide con la variante | LEÍDO |
| El trío cerrado con la ficha de ron cuenta como abierto (fu y 暗刻) | 0x6185 | coincide | LEÍDO |
| Con cuatro iguales en la mano ordenada se borra la marca de ficha de ron | 0x5FEE | — | LEÍDO; el porqué es SUPOSICIÓN |

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
| 7 | チューレンポートー chuuren poutou | yakuman | 0x7F46 | **sólo se detecta en el palo 0** (0x7F1A) |
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
| Espera: kanchan, penchan y tanki 2; ryanmen y shanpon 0. Tsumo +2 (el código los lleva juntos y resta 2 en el ron) | 0x72B8, 0x5BDB-0x5C59 | coincide | LEÍDO |
| Total redondeado hacia arriba a la decena | 0x7356 | coincide | LEÍDO |
| **Siete parejas: sin el 25 fijo**, se cuentan como una mano normal (20/30 + pareja + espera) | 0x7176-0x731F no miran 0xE205 | **diverge** | LEÍDO |
| Todo en BCD, con `daa` | 0x7344 | — | LEÍDO |

## 8. El pago

| regla | dónde | estándar | estado |
| --- | --- | --- | --- |
| Menos de 5 han: tabla por fu (filas 20…90, y 100+) y han (1-4), la del que reparte (0x5C97) o la del otro (0x5CA9), según 0xE04E | 0x5B22-0x5B41, 0x5C5A, 0x5C70 | las cifras coinciden con la tabla de cuatro | LEÍDO |
| **20 fu con 1 han paga 0** (más honba): la fila 0 de las dos tablas es 0000, 0x5C5A manda los 20 fu a esa fila y 0x7356 sólo redondea hacia arriba, sin mínimo de 30 para mano abierta. Sólo se llega con RON, mano abierta, espera ryanmen o shanpon y sin fu de figuras ni de pareja (con tsumo los +2 de la espera lo suben a 30): un tanyao abierto de escaleras ganado por ron | 0x5CBB, 0x5D03, 0x5C5A, 0x7356 | **diverge** | LEÍDO y comprobado a mano el 2026-08-28; no medido |
| **100 fu o más se paga como 8 han** (baiman: 24.000/16.000, y 8.000 con tsumo). Por eso la novena fila de las tres tablas de pago (0x5CFB, 0x5D43, 0x5DD5) no se lee nunca; la de "al robar" es una fila de 110 fu de verdad (1.800/3.600), muerta | 0x5B2D → 0x5B6B con A = 8 | diverge (rareza) | LEÍDO; comprobado a mano el 2026-08-28 |
| 5 han o más: mangan 12.000/8.000, haneman (6-7) 18.000/12.000, baiman (8-10) 24.000/16.000, sanbaiman (11-13) 36.000/24.000; 13 es el tope | 0x5B6B, 0x5D4B, 0x5D5D | coincide (no hay kazoe yakuman: 13 han siguen siendo sanbaiman) | LEÍDO |
| Yakuman: 48.000/32.000, y se apilan (hasta cinco) | 0x5B57, 0x5D6F, 0x5D79 | coincide | LEÍDO |
| **Honba: +300 por honba en el ron, +100 en el tsumo** | 0x5C7F, 0x5BB5 | coincide en cifras (en cuatro el tsumo son 100 por pagador; aquí hay uno) | LEÍDO |
| **Con tsumo el perdedor paga la parte de un solo jugador** (tablas "al robar": 30 fu 1 han = 500, mangan = 4.000, yakuman = 16.000) **pero el ganador cobra la cifra entera del ron**: 0x5B85 carga la misma palabra en los dos pendientes y con tsumo sólo rebaja el del que paga (0xE1B1), no el del que cobra (0xE1E4). Se crean puntos de la nada, y la pantalla del recuento lo imprime tal cual: ハライ (lo pagado) y トクテン (lo cobrado) | 0x5B85-0x5BDA, 0x5D83-0x5DF9, 0x5DF9 | diverge (en cuatro los tres pagos del tsumo suman lo que cobra el ganador) | **MEDIDO** en el demo: 7 han 30 fu, reparte y gana el 1 por tsumo; 0xE1B1 = 0x0060 y 0xE1E4 = 0x0180 (volcado 040), ハライ 6000 / トクテン 18000 en pantalla, y los marcadores acaban en 48.000 y 23.000 (volcado 042) |
| Los puntos se mueven de cien en cien, un fotograma cada uno, con sonido | 0x5DF9 | — | LEÍDO |
| Tenpai al acabarse la mano: 1.500 del que no está al que está; con los dos o ninguno, nada. **A partir de 5 honba, para estar en tenpai cada espera tiene que valer 3 han** (0x7B3B: `cp 3 / ccf` deja el acarreo puesto con 3 o más, y 0x774E/0x77BA sin acarreo niegan el tenpai). Cada espera se evalúa desde cero (0x5F82 limpia 0xE2F1-0xE32A, donde vive el contador 0xE316) y sin dora (el salto de 0x7B00 se da antes de 0x7B28) | 0x7713-0x7814, 0x7B38 | 1.500 coincide con "dos y dos"; el requisito de 3 han diverge de todo lo conocido | LEÍDO; comprobado a mano el 2026-08-28 |

## 9. La partida

| regla | dónde | estado |
| --- | --- | --- |
| Ronda y reparto: (este, reparte 1) → (este, 2) → (sur, 1) → (sur, 2). El reparto pasa cuando gana el que no reparte; se queda si gana el que reparte o si está en tenpai en una mano sin ganador | 0x5ED0-0x5F12, 0x77CD-0x7809 | LEÍDO |
| **En la ronda del sur, una mano sin ganador no mueve el reparto** aunque el que reparte no esté en tenpai (0x7803, 0x77ED) | 0x77CD | LEÍDO; si es intención o descuido es SUPOSICIÓN |
| La partida se acaba cuando el que no reparte gana en (sur, reparte 2) | 0x5EFA-0x5F03 | LEÍDO; el "sexto envite" de 0x41EC es otro cierre, no leído en esta tanda |
| Honba: +1 por mano sin ganador y por mano que gana el que reparte; a cero cuando cambia el reparto | 0x780A, 0x5EEB, 0x5F08 | LEÍDO |
| Los marcadores pueden bajar de cero (signo en 0xE100) y la máquina lo mira para su plan (0x78F5) | 0x8307, 0x78F5 | LEÍDO |

## 10. Lo que las tres dificultades cambian, todo junto

| tecla | rótulo | qué cambia | dónde |
| --- | --- | --- | --- |
| 1 | AMACHUA | el ron en furiten se rechaza sin castigo; sin furiten de riichi; el riichi en furiten se rechaza (0x539A); la máquina suma 3 a su turno de riichi; sin reloj (hay que pulsar para robar); la ayuda de 0x49C6: en riichi no deja descartar una espera y avisa cuando el descarte de la máquina le da ron; los descartes de la máquina no se filtran | 0x5045, 0x4260, 0x539A, 0x50F5, 0x55F1, 0x49C6, 0x584B |
| 2 | SEMIPROFESSIONAL | el furiten se castiga con 12.000/8.000; +5 al turno de riichi de la máquina; reloj: 10 s para descartar (aviso a los 7) y el robo sale solo a los 12 s; los descartes de la máquina, filtrados | 0x4260, 0x50F5, 0x5292-0x52AB, 0x55E2-0x55EF, 0x583C |
| 3 | PROFESSIONAL | lo de la 2; +7 al turno de riichi; el sorteo de 0xE33D se repite si sale 20 o más; y **a la máquina le falta siempre la ficha de índice 11** de su mano construida | 0x4EEA, 0x7A9D |

## Cabos abiertos para el paso 5

- Qué palo es el 0 y cuál el 1 (caracteres/círculos): mirar los patrones de las
  fichas, 0x4735 dice qué tiles son.
- Qué dicen los rótulos de la espera (tiles 0x0C-0x27 de 0x86D6, trozos de
  kanji): no se han leído.
- Medir en el emulador las dos divergencias que quedan sin medir: el 20 fu/1 han
  a cero y el palo de riichi que se queda en la mesa (el pago del tsumo ya está
  medido en el demo, volcados 040-042).
- El "sexto envite" de 0x41EC y cómo casa con el cierre de 0x5F00.
- Quién cobra los 1.000 del riichi del jugador (0x53B8, en la zona de la IA).
