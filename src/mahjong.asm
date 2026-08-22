; ==========================================================================
; KONAMI'S MAHJONG - Konami - MSX1 - cartucho RC-707 de 32 KB en las paginas 1 y 2
; ==========================================================================
; Generado por tools/mkasm.py a partir del trazado de flujo real.
; Los comentarios provienen de tools/../src/*.notes y estan anclados a
; direccion, de modo que sobreviven a un retrazado.
; ==========================================================================

	org 0x04000


; ----------------------------------------------------------------------
; Direcciones que solo aparecen como VALOR -en un `ld`, no en
; un salto-: son punteros que el codigo se pasa o numeros que
; casualmente coinciden con una direccion. No hay nada que
; trazar en ellas; el equ existe para que el listado ensamble.
; ----------------------------------------------------------------------
l4600h:	equ 0x04600

; ----------------------------------------------------------------------
; DATOS cabecera: Los dieciseis bytes que lee la BIOS al arrancar la maquina:
;   AB, INIT=0x4010, y los otros tres punteros a cero. Este cartucho no
;   declara STATEMENT, ni DEVICE, ni TEXT.
;   0x4000..0x4010  (16 bytes)
DATA_cabecera:
	defb 041h,042h,010h,040h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h,000h	; 4000  AB.@............

; ======================================================================
; CODIGO 0x4010..0x406d  (93 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; EL ARRANQUE. La BIOS llega aqui por el vector INIT de la cabecera AB. Enciende la pagina 2 del cartucho (la BIOS solo le ha mapeado la 1), monta la pila y la RAM, instala la interrupcion y se queda dando vueltas en 0x404F: A PARTIR DE AHI EL JUEGO ENTERO CORRE DENTRO DE LA INTERRUPCION.
; ----------------------------------------------------------------------
init:
	di			;4010   ; nada de interrupciones mientras se monta la maquina
	im 1		;4011
	ld a,001h		;4013   ; semaforo de la interrupcion a 1: aun no se puede reentrar
	ld (0e005h),a		;4015
	call 00138h		;4018   ; BIOS RSLREG - Reads the primary slot register | RSLREG da las cuatro ranuras empaquetadas en un byte
	and 00ch		;401b   ; se queda con los dos bits de la pagina 1, que es donde esta el cartucho
	rrca			;401d
	rrca			;401e
	ld h,080h		;401f   ; H=0x80: la pagina que se quiere encender es la 2, 0x8000-0xBFFF
	call 00024h		;4021   ; BIOS ENASLT - Switches to specified slot and page definitively | ENASLT enciende la mitad de arriba del cartucho, hasta ahora invisible
	ld a,0c3h		;4024   ; 0xC3 = jp: se escribe a mano el salto del gancho
	ld (0fd9ah),a		;4026   ; H.KEYI, el gancho de interrupcion de la BIOS
	ld hl,04071h		;4029   ; y el destino del salto: la rutina de 0x4071
	ld (0fd9bh),hl		;402c
	ld sp,0e400h		;402f   ; la pila justo debajo de la RAM del juego
	ld hl,0e000h		;4032   ; borra de un tiron 0xE000-0xE3FF, las variables enteras
	ld de,0e001h		;4035
	ld bc,003ffh		;4038
	ld (hl),000h		;403b
	ldir		;403d
	ld a,001h		;403f   ; semaforo a 1 otra vez: la inicializacion no quiere que la corten
	ld (0e005h),a		;4041
	call arranca_el_hardware		;4044   ; monta el PSG, el VDP y limpia la VRAM
	xor a			;4047
	ld (0e005h),a		;4048   ; semaforo a 0: ya se puede interrumpir, y el juego echa a andar
	call 0013eh		;404b   ; BIOS RDVDP - Reads VDP status register | RDVDP borra la peticion pendiente del VDP antes del primer ei
	ei			;404e
L_404F:
	jr L_404F		;404f   ; AQUI SE QUEDA PARA SIEMPRE: el juego vive en la interrupcion

; ----------------------------------------------------------------------
; Escribe A en la direccion de VRAM que trae DE. Envuelve al puerto: 0x470F prepara el VDP y deja el puerto de datos en C', y el out (c),a de aqui lo suelta. El ei del final es porque 0x470F entra con di.
; ----------------------------------------------------------------------
escribe_en_vram:
	call prepara_escritura_vram		;4051   ; arma la direccion en el VDP y deja el puerto en C'
	exx			;4054
	out (c),a		;4055   ; el byte, al puerto de datos
	exx			;4057
	ei			;4058
	ret			;4059

; ----------------------------------------------------------------------
; La hermana de 0x4051: devuelve en A el byte de la VRAM que apunta DE.
; ----------------------------------------------------------------------
lee_de_vram:
	call prepara_lectura_vram		;405a
	exx			;405d
	in a,(c)		;405e
	exx			;4060
	ei			;4061
	ret			;4062

; ----------------------------------------------------------------------
; Suma A a HL con el arrastre bien puesto. Es la rutina mas llamada del cartucho: la usan el despachador, todas las tablas indexadas y el lector de la fuente.
; ----------------------------------------------------------------------
suma_a_a_hl:
	add a,l			;4063
	ld l,a			;4064
	ret nc			;4065   ; sin arrastre no hay que tocar H
	inc h			;4066
	ret			;4067

; ----------------------------------------------------------------------
; La hermana de 0x4063 para DE. La usan las rutinas que van bajando por la VRAM de fila en fila, sumando 0x20.
; ----------------------------------------------------------------------
suma_a_a_de:
	add a,e			;4068
	ld e,a			;4069
	ret nc			;406a
	inc d			;406b
	ret			;406c

; ----------------------------------------------------------------------
; DATOS relleno_hasta_la_interrupcion: Cuatro bytes 0xFF para que la rutina de
;   interrupcion caiga exactamente en 0x4071, que es lo que INIT escribe en el
;   gancho H.KEYI.
;   0x406d..0x4071  (4 bytes)
DATA_relleno_hasta_la_interrupcion:
	defb 0ffh,0ffh,0ffh,0ffh	; 406d

; ======================================================================
; CODIGO 0x4071..0x40b2  (65 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; LA INTERRUPCION, y con ella el bucle principal del juego. La instala INIT en H.KEYI. Hace tres cosas en orden: reconoce el VDP, mueve el sonido, y -si no se esta pisando a si misma- lee los mandos y da un latido a la maquina de estados. El semaforo 0xE005 es lo que impide que un fotograma lento se solape con el siguiente.
; ----------------------------------------------------------------------
interrupcion:
	di			;4071
	call 0013eh		;4072   ; BIOS RDVDP - Reads VDP status register | RDVDP: leer el registro de estado es lo que reconoce la interrupcion
	call L_9EA3		;4075   ; el sonido va SIEMPRE, aunque el fotograma anterior no haya terminado
	ld hl,0e005h		;4078   ; el semaforo de reentrada
	bit 0,(hl)		;407b   ; si ya hay un fotograma dentro, no se entra
	jr nz,L_408C		;407d
	inc (hl)			;407f   ; lo levanta, y ahora ya se puede interrumpir otra vez
	ei			;4080
	call lee_los_mandos		;4081   ; lee los mandos: teclado de verdad si hay partida, guion si es demo
	call latido		;4084   ; y el latido de la maquina de estados
	di			;4087
	xor a			;4088
	ld (0e005h),a		;4089   ; semaforo abajo, el fotograma ha terminado
L_408C:
	ei			;408c
	reti		;408d

; ----------------------------------------------------------------------
; EL DESPACHADOR, y el truco de la casa: no lleva la tabla en un registro, la coge del pop hl, o sea que la tabla va PEGADA DETRAS del call que lo invoca y nunca se vuelve a el. A cambio, el manejador que salga hereda como direccion de retorno lo que hubiera debajo. Entra con A = indice. Hay cinco tablas: 0x40ED (estados), 0x4164, 0x41AB, 0x421D y 0x4389 (submodos).
; ----------------------------------------------------------------------
despacha_por_tabla:
	add a,a			;408f   ; cada entrada son dos bytes
	pop hl			;4090   ; la direccion de retorno ES la tabla
	call suma_a_a_hl		;4091   ; suma el indice ya doblado
	ld e,(hl)			;4094   ; saca la palabra
	inc hl			;4095
	ld d,(hl)			;4096
	ex de,hl			;4097
	jp (hl)			;4098   ; y salta: no vuelve por aqui

; ----------------------------------------------------------------------
; Las DOS puertas del interprete de formato A, y la gracia del cartucho: la MISMA lista pinta o borra segun por donde se entre. Por 0x4099 C vale 0 y el and c de 0x40AB deja todos los bytes a cero; por 0x409D C vale 0xFF y pasan tal cual. Entra con HL apuntando a la lista.
; ----------------------------------------------------------------------
pinta_o_borra_lista:
	ld c,000h		;4099   ; C=0: todo byte se convertira en 0 - esta puerta BORRA
	jr L_409F		;409b
L_409D:
	ld c,0ffh		;409d   ; C=0xFF: los bytes pasan intactos - esta puerta PINTA
L_409F:
	ld e,(hl)			;409f   ; los dos bytes de destino en VRAM, byte bajo primero
	inc hl			;40a0
	ld d,(hl)			;40a1
	inc hl			;40a2
L_40A3:
	ld a,(hl)			;40a3   ; siguiente byte de la lista
	inc hl			;40a4
	ld b,a			;40a5
	inc b			;40a6   ; 0xFF cuenta como fin: el inc b lo lleva a cero
	ret z			;40a7
	inc b			;40a8   ; 0xFE cuenta como "vuelve a leer un destino nuevo"
	jr z,L_409F		;40a9
	and c			;40ab   ; la mascara: aqui se decide si esto pinta o borra
	call escribe_en_vram		;40ac   ; y al VDP
	inc de			;40af
	jr L_40A3		;40b0

; ----------------------------------------------------------------------
; DATOS codigo_al_que_no_llega_nadie: Dos rutinas completas y validas a las
;   que no apunta ni un salto ni una llamada en los 32 KB: 0x40B2 pinta 0xE127
;   en 0x3AE6 con 0x4518, y 0x40BE es una espera de 256x256 vueltas. Se dejan
;   como datos porque nadie las alcanza.
;   0x40b2..0x40ca  (24 bytes)
DATA_codigo_al_que_no_llega_nadie:
	defb 021h,027h,0e1h,011h,0e6h,03ah,006h,001h,0cdh,018h,045h,0c9h,00eh,000h,006h,000h	; 40b2  !'...:....E.....
	defb 0e5h,0e1h,010h,0fch,00dh,020h,0f7h,0c9h	; 40c2  ..... ..

; ======================================================================
; CODIGO 0x40ca..0x40ed  (35 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; EL LATIDO, una vez por fotograma. Lleva los dos relojes, y luego despacha el estado. El push hl de 0x40E9 es un retorno postizo: el manejador del estado, al hacer ret, no vuelve aqui sino a donde diga HL. Y HL depende del bit 6 de 0xE002, o sea de si hay alguien jugando: en partida va a 0x41A4, que es un ret pelado y no hace nada; en demo va a 0x4ABC, que es quien vigila si alguien pulsa una tecla para empezar de verdad.
; ----------------------------------------------------------------------
latido:
	ld hl,0e003h		;40ca   ; el contador de fotogramas de 8 bits
	inc (hl)			;40cd
	ld hl,(0e052h)		;40ce   ; y el de 16 bits, que no se reinicia nunca
	inc hl			;40d1
	ld (0e052h),hl		;40d2
	ld a,(0e002h)		;40d5   ; el byte de la partida: bit 6 = hay una persona jugando
	and 040h		;40d8
	ld hl,041a4h		;40da   ; con partida, el retorno postizo es un ret pelado: nada que hacer
	jr nz,L_40E2		;40dd
	ld hl,04abch		;40df   ; sin partida es el DEMO, y toca vigilar el teclado para arrancar
L_40E2:
	ld a,(0e000h)		;40e2   ; el estado del juego
	cp 008h		;40e5   ; el estado 8 es el unico que NO quiere el retorno postizo
	jr z,L_40EA		;40e7
	push hl			;40e9   ; se cuela debajo del retorno del call de abajo
L_40EA:
	call despacha_por_tabla		;40ea   ; y a la tabla de quince que viene pegada detras

; ----------------------------------------------------------------------
; DATOS tabla_de_estados: Las quince palabras del despachador de 0x408F,
;   pegadas detras del `call` de 0x40EA. El indice es (0xE000), el estado del
;   juego.
;   0x40ed..0x410b  (30 bytes)
DATA_tabla_de_estados:
	defb 00bh,041h	; 40ed
	defb 018h,041h	; 40ef
	defb 02ch,041h	; 40f1
	defb 03bh,041h	; 40f3
	defb 03eh,041h	; 40f5
	defb 046h,041h	; 40f7
	defb 04eh,041h	; 40f9
	defb 05eh,041h	; 40fb
	defb 00bh,044h	; 40fd
	defb 051h,041h	; 40ff
	defb 0a5h,041h	; 4101
	defb 017h,042h	; 4103
	defb 083h,043h	; 4105
	defb 0dbh,043h	; 4107
	defb 0ebh,043h	; 4109

; ======================================================================
; CODIGO 0x410b..0x4164  (89 bytes)
; ======================================================================


L_410B:
	call pinta_una_franja_del_tapete		;410b   ; ESTADO 0: espera 24 fotogramas pintando la mesa; ver 0x44B2
	ret p			;410e   ; aun no ha terminado la cuenta
	call L_446F		;410f   ; pinta el tapete y las fichas del fondo
	call carga_los_registros_del_vdp		;4112   ; y recarga los ocho registros del VDP
	jp avanza_de_estado		;4115   ; al estado 1
L_4118:
	ld a,(0e003h)		;4118   ; ESTADO 1: parpadeo del rotulo, un fotograma de cada dos
	rra			;411b   ; el bit 0 del contador de fotogramas: solo los impares
	ret nc			;411c
	call baja_el_rotulo_un_paso		;411d
	ret nz			;4120
	ld hl,085bfh		;4121
	call L_409D		;4124   ; pinta el rotulo
	ld a,050h		;4127   ; y se queda 80 fotogramas en el estado siguiente
	jp L_41FC		;4129
L_412C:
	ld hl,0e004h		;412c   ; ESTADO 2: cuenta atras con el rotulo puesto
	dec (hl)			;412f
	ret nz			;4130
	ld hl,085bfh		;4131   ; al agotarse, BORRA el mismo rotulo que pinto el estado 1
	call pinta_o_borra_lista		;4134
	xor a			;4137
	ld (0e00ah),a		;4138   ; reinicia el contador de lineas de 0x45B4
L_413B:
	jp avanza_de_estado		;413b   ; ESTADO 3: al 4 sin mas, y sin espera ninguna
L_413E:
	call suelta_una_linea_de_texto		;413e   ; ESTADO 4: va soltando las lineas del texto, una por fotograma
	ret c			;4141   ; mientras queden lineas, sigue en este estado
	xor a			;4142
	jp L_41FC		;4143   ; A=0: al estado siguiente sin espera
L_4146:
	ld hl,0e004h		;4146   ; ESTADO 5: pura cuenta atras
	dec (hl)			;4149
	ret nz			;414a
	jp avanza_de_estado		;414b
L_414E:
	jp espera_32_y_avanza_de_estado		;414e   ; ESTADO 6: sin nada que hacer, a 0x41F4 y al 7
L_4151:
	call pinta_una_franja_del_tapete		;4151   ; ESTADO 9: otros 24 fotogramas de cuenta pintando la mesa
	ret p			;4154
	call pone_los_marcadores_a_30000		;4155   ; pinta la mesa de la mano que va a empezar
	ld a,010h		;4158   ; 0x10 y luego inc a: 17 fotogramas de espera
	inc a			;415a
	jp L_41FC		;415b
L_415E:
	ld a,(0e001h)		;415e   ; ESTADO 7: se parte en dos submodos por (0xE001)
	call despacha_por_tabla		;4161

; ----------------------------------------------------------------------
; DATOS tabla_de_submodos_7: Las dos palabras del despachador, detras del
;   `call` de 0x4161. El indice es (0xE001).
;   0x4164..0x4168  (4 bytes)
DATA_tabla_de_submodos_7:
	defb 068h,041h	; 4164
	defb 096h,041h	; 4166

; ======================================================================
; CODIGO 0x4168..0x41ab  (67 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; SUBMODO 0 DEL ESTADO 7: AQUI ARRANCA EL DEMO. Borra el marcador, engancha el guion de teclas grabado y apaga el bit 6 de 0xE002 para que 0x4A27 lea del guion y no del teclado.
; ----------------------------------------------------------------------
L_4168:
	call L_44A4		;4168   ; pone a cero el marcador y las 622 variables que le siguen
	ld hl,04ae8h		;416b   ; engancha el guion del demo (0x4AE8) como fuente de pulsaciones
	ld (0e066h),hl		;416e
	ld hl,049a6h		;4171   ; y las dos rutinas que lo atienden
	ld (0e06ah),hl		;4174
	ld hl,049b5h		;4177
	ld (0e06ch),hl		;417a
	xor a			;417d   ; contador y repeticiones del guion, a cero
	ld (0e068h),a		;417e
	ld (0e069h),a		;4181
	ld hl,0e002h		;4184
	res 6,(hl)		;4187   ; bit 6 abajo: NO hay persona jugando, esto es el demo
	ld hl,0e000h		;4189
	ld a,008h		;418c   ; EL ESTADO 8 NO SE DESPACHA POR AQUI: se escribe 8, pero el `jp L_41F4` de 0x4193 desemboca en `avanza_de_estado`, que hace `inc`, asi que el estado que corre es el 9. Se escribe porque sirve doble: el `rra` de 0x418F lo convierte en 4 para 0xE040. CORRECCION del paso 2, que lo dio por muerto: el estado 8 SI se despacha -y va a 0x440B, la pantalla de dificultad- cuando quien escribe el 8 es 0x4ABC, o sea cuando alguien pulsa una tecla para jugar de verdad. En el demo no se llega nunca, y de ahi salio la lectura equivocada.
	ld (hl),a			;418e
	rra			;418f
	ld (0e040h),a		;4190   ; el 8 rotado a la derecha da 4, que es lo que quiere 0xE040
	jp espera_32_y_avanza_de_estado		;4193

; ----------------------------------------------------------------------
; CIERRA EL BUCLE DEL JUEGO: pone el estado a 0 y el submodo a 0. Medido en el demo: se llega aqui en t=168,48 y otra vez en t=337,44, o sea cada 168,96 s.
; ----------------------------------------------------------------------
vuelve_al_estado_0:
	xor a			;4196
	ld (0e000h),a		;4197   ; estado = 0, se empieza de nuevo
	ld a,020h		;419a
	ld (0e004h),a		;419c
	ld hl,0e001h		;419f
	ld (hl),000h		;41a2   ; y el submodo tambien
	ret			;41a4
L_41A5:
	ld a,(0e001h)		;41a5
	call despacha_por_tabla		;41a8

; ----------------------------------------------------------------------
; DATOS tabla_de_submodos_10: Las dos palabras del despachador, detras del
;   `call` de 0x41A8. El indice es (0xE001).
;   0x41ab..0x41af  (4 bytes)
DATA_tabla_de_submodos_10:
	defb 0afh,041h	; 41ab
	defb 0b6h,041h	; 41ad

; ======================================================================
; CODIGO 0x41af..0x421d  (110 bytes)
; ======================================================================


submodo_0_del_estado_10:
	ld hl,0e004h		;41af   ; SUBMODO 0 DEL ESTADO 10: cuenta atras y al submodo siguiente
	dec (hl)			;41b2
	ret nz			;41b3
	jr espera_32_y_avanza_de_submodo		;41b4
L_41B6:
	call pinta_una_franja_del_tapete		;41b6   ; SUBMODO 1 DEL ESTADO 10: reparte la mano
	ret p			;41b9
	call monta_la_mano		;41ba   ; el reparto
	ld hl,03959h		;41bd
	ld (0e1c5h),hl		;41c0
	ld hl,0e064h		;41c3
	ld a,r		;41c6   ; LA SEMILLA DEL AZAR: el registro R del refresco de la memoria
	or a			;41c8   ; si R sale cero se usa el contador de fotogramas en su lugar
	jr nz,L_41CE		;41c9
	ld a,(0e003h)		;41cb
L_41CE:
	ld (hl),a			;41ce
	inc hl			;41cf
	ld a,(0e003h)		;41d0   ; el segundo byte de la semilla, siempre el contador de fotogramas
	ld (hl),a			;41d3
	call prepara_el_reparto		;41d4
	ld hl,0e1a8h		;41d7
	set 0,(hl)		;41da   ; bit 0 de 0xE1A8: hay mano repartida
	ld a,(0e04ch)		;41dc
	or a			;41df
	jr z,L_41E8		;41e0
	ld hl,0e04dh		;41e2
	xor (hl)			;41e5
	jr z,L_41F0		;41e6
L_41E8:
	ld a,(0e04bh)		;41e8
	inc a			;41eb
	cp 006h		;41ec   ; el sexto envite cierra la partida
	jr c,L_41FC		;41ee
L_41F0:
	ld a,040h		;41f0
	jr L_41FC		;41f2

; ----------------------------------------------------------------------
; La salida corriente de un estado: borra 0xE1B8, pide 32 fotogramas de espera y pasa al estado siguiente. 0x41FC es la entrada de los que traen su propia espera en A, y 0x41FF la de los que no quieren ninguna.
; ----------------------------------------------------------------------
espera_32_y_avanza_de_estado:
	ld hl,00000h		;41f4   ; el desplazamiento del tapete, a cero
	ld (0e1b8h),hl		;41f7
	ld a,020h		;41fa   ; 32 fotogramas de espera
L_41FC:
	ld (0e004h),a		;41fc   ; entra aqui quien trae su propia espera en A

; ----------------------------------------------------------------------
; Avanza al estado siguiente y resetea el submodo: `inc (0xE000)` y luego `ld (0xE001),0`. La usan los estados 1 a 14, y es el 0x4202/0x4204 que aparece escribiendo en el trazado del demo.
; ----------------------------------------------------------------------
avanza_de_estado:
	ld hl,0e000h		;41ff   ; hl = 0xE000, el estado del juego
	inc (hl)			;4202   ; estado = estado + 1
	inc hl			;4203   ; hl = 0xE001, el submodo
	ld (hl),000h		;4204   ; submodo = 0, que el estado nuevo empieza por el suyo
	ret			;4206

; ----------------------------------------------------------------------
; La gemela de 0x41F4 pero para submodos: misma espera de 32 fotogramas y mismo borrado de 0xE1B8, solo que al final hace crecer (0xE001) en vez de (0xE000).
; ----------------------------------------------------------------------
espera_32_y_avanza_de_submodo:
	ld hl,00000h		;4207
	ld (0e1b8h),hl		;420a
	ld a,020h		;420d
L_420F:
	ld (0e004h),a		;420f   ; entra aqui quien trae su propia espera en A

; ----------------------------------------------------------------------
; Avanza al submodo siguiente dentro del estado: `inc (0xE001)`. Es el unico sitio que hace crecer el submodo; en el demo la mano entera (estado 11) recorre asi sus nueve.
; ----------------------------------------------------------------------
avanza_de_submodo:
	ld hl,0e001h		;4212
	inc (hl)			;4215   ; submodo = submodo + 1
	ret			;4216
L_4217:
	ld a,(0e001h)		;4217
	call despacha_por_tabla		;421a

; ----------------------------------------------------------------------
; DATOS tabla_de_submodos_11: Las nueve palabras del despachador, detras del
;   `call` de 0x421A. El indice es (0xE001).
;   0x421d..0x422f  (18 bytes)
DATA_tabla_de_submodos_11:
	defb 02fh,042h	; 421d
	defb 03bh,042h	; 421f
	defb 048h,042h	; 4221
	defb 0aeh,042h	; 4223
	defb 003h,043h	; 4225
	defb 00bh,043h	; 4227
	defb 023h,043h	; 4229
	defb 030h,043h	; 422b
	defb 058h,043h	; 422d

; ======================================================================
; CODIGO 0x422f..0x4389  (346 bytes)
; ======================================================================


submodo_0_del_estado_11:
	ld hl,0e004h		;422f   ; SUBMODO 0 DEL ESTADO 11: espera y calla el sonido de la mano anterior
	dec (hl)			;4232
	ret nz			;4233
	ld a,09fh		;4234   ; 0x9F: silencio
	call L_9C4A		;4236
	jr $-39		;4239   ; y al submodo 1
submodo_1_del_estado_11:
	call L_4D58		;423b   ; SUBMODO 1 DEL ESTADO 11: reparte y espera a que termine el reparto
	ld hl,0e1a8h		;423e
	bit 0,(hl)		;4241   ; bit 0 de 0xE1A8: mientras haya reparto en curso, aqui se sigue
	ret nz			;4243
	set 1,(hl)		;4244   ; bit 1: el reparto ha terminado, el guion del demo ya puede tocar
	jr $-52		;4246   ; y al submodo 2, que es la mano de verdad

; ----------------------------------------------------------------------
; SUBMODO 2 DEL ESTADO 11: LA MANO JUGANDOSE, y el submodo mas largo con diferencia (103,7 s de los 130,3 del estado 11 en el demo, medido). Cada fotograma mueve un turno y decide si la mano sigue o se acaba. Las tres salidas son: 0x42A8 si la mano termina normal, 0x429E si termina con jugada cantada (salta al submodo 5 en vez de al 3) y el `ret` de 0x4258 mientras aun quede algo pendiente.
; ----------------------------------------------------------------------
submodo_2_del_estado_11:
	call juega_el_turno		;4248   ; mueve el turno
	ld hl,0e302h		;424b
	bit 2,(hl)		;424e   ; bit 2 de 0xE302: el turno es de la maquina
	ex de,hl			;4250
	jr nz,L_4285		;4251
	ld hl,0e1a8h		;4253
	bit 1,(hl)		;4256   ; mientras el reparto no haya terminado, no se juega
	ret nz			;4258
	set 2,(hl)		;4259
	ld a,(de)			;425b
	rra			;425c
	rra			;425d
	jr c,L_42A8		;425e
	ld a,(0e040h)		;4260   ; la dificultad, tal como la dejo la pantalla del estado 8
	and 006h		;4263
	jr z,L_42A8		;4265
	ld a,(0e1d1h)		;4267   ; bit 0 de 0xE1D1: hay que saltarse la comprobacion
	rra			;426a
	jr c,L_42A8		;426b
	call busca_en_las_dos_listas		;426d
	ld a,(0e1cdh)		;4270
	rra			;4273
	jr nc,L_4279		;4274
	call L_47FB		;4276   ; bit 0 de 0xE1CD
L_4279:
	ld a,(0e1cdh)		;4279
	and 060h		;427c   ; los bits 5 y 6 de 0xE1CD son los que llevan a cantar jugada
	jr z,L_42A8		;427e
L_4280:
	call L_76D9		;4280
	jr L_4288		;4283
L_4285:
	call L_76A6		;4285
L_4288:
	ld a,(0e1ach)		;4288
	and 0c0h		;428b   ; los dos bits altos de 0xE1AC deciden el importe
	jr z,L_429E		;428d
	rla			;428f
	ld hl,00120h		;4290   ; 0x0120 en BCD: 120 pasos de 100 puntos, o sea 12.000
	jr c,L_4298		;4293
	ld hl,00080h		;4295   ; y si no, 0x0080: 80 pasos de 100, o sea 8.000
L_4298:
	ld (0e1e4h),hl		;4298   ; lo mismo en los dos sitios, que 0x5DF9 los va gastando en paralelo
	ld (0e1b1h),hl		;429b
L_429E:
	ld a,005h		;429e   ; con jugada cantada se salta al submodo 5, no al 3
	ld (0e001h),a		;42a0
	ld a,0c0h		;42a3   ; y con 192 fotogramas de espera
	jp L_420F		;42a5
L_42A8:
	call L_7AF8		;42a8   ; salida normal: al submodo 3
	jp espera_32_y_avanza_de_submodo		;42ab

; ----------------------------------------------------------------------
; SUBMODO 3 DEL ESTADO 11: destapa la mano y prepara el recuento. Vuelve a pintar la mesa mientras baja el reloj, y cuando se agota monta las direcciones de la lista de nombres de jugada (0xE317 y 0xE319) y se va al submodo 4 o al 5 segun haya algo que pagar.
; ----------------------------------------------------------------------
submodo_3_del_estado_11:
	call pinta_una_franja_del_tapete		;42ae   ; sigue pintando la mesa hasta que el reloj se agote
	ret p			;42b1
	call L_5A46		;42b2
	ld a,(0e302h)		;42b5   ; bit 1 de 0xE302
	bit 1,a		;42b8
	jr nz,L_42C1		;42ba
	ld a,093h		;42bc   ; sonido 0x93
	call L_9C4A		;42be
L_42C1:
	ld hl,0382fh		;42c1   ; 0x382F, donde empieza a escribirse el nombre de la jugada
	ld (0e317h),hl		;42c4
	ld hl,0e305h		;42c7   ; y de donde se lee, 0xE305
	ld (0e319h),hl		;42ca
	ld a,005h		;42cd   ; cinco lineas de recuento
	ld (0e1d8h),a		;42cf
	xor a			;42d2
	ld hl,0e1d9h		;42d3   ; borra las tres celdas de 0xE1D9
	ld (hl),a			;42d6
	inc hl			;42d7
	ld (hl),a			;42d8
	inc hl			;42d9
	ld (hl),a			;42da
	ld a,(0e205h)		;42db   ; 0xE205: si no hay nada apuntado, se va por 0x42F3
	or a			;42de
	ld hl,0e1c8h		;42df
	jr z,L_42F3		;42e2
	rra			;42e4
	set 1,(hl)		;42e5   ; bit 1 de 0xE1C8
	jr nc,L_42F0		;42e7
	ld de,00030h		;42e9   ; 0x30 = 48 pasos de 100, o sea 4.800 puntos
	ld (0e1e1h),de		;42ec
L_42F0:
	jp avanza_de_submodo		;42f0
L_42F3:
	set 4,(hl)		;42f3   ; bit 4 de 0xE1C8: la mano se va sin pagar
	ld a,(0e302h)		;42f5
	bit 1,a		;42f8
	ld a,010h		;42fa   ; 16 fotogramas si el turno era de la maquina
	jr nz,L_4300		;42fc
	ld a,0b0h		;42fe   ; y 176 si era del jugador, que hay mas que leer
L_4300:
	jp L_420F		;4300
submodo_4_del_estado_11:
	ld hl,0e004h		;4303   ; SUBMODO 4 DEL ESTADO 11: pura cuenta atras antes del recuento
	dec (hl)			;4306
	ret nz			;4307
	jp avanza_de_submodo		;4308

; ----------------------------------------------------------------------
; SUBMODO 5 DEL ESTADO 11: canta la jugada. 0x5AEE es quien decide de que jugada se trata y la escribe; mientras el bit 2 de 0xE1A8 siga puesto, aqui no se avanza. Al terminar pinta los tres digitos de 0xE1B2 en 0x38A8.
; ----------------------------------------------------------------------
submodo_5_del_estado_11:
	call L_5AEE		;430b
	ld hl,0e1a8h		;430e   ; bit 2 de 0xE1A8: la jugada aun se esta cantando
	bit 2,(hl)		;4311
	ret nz			;4313
	ld hl,0e1b2h		;4314   ; los tres digitos del importe
	ld de,038a8h		;4317   ; 0x38A8, donde van
	ld b,003h		;431a   ; tres celdas
	call pinta_un_numero_bcd		;431c
	xor a			;431f   ; sin espera, al submodo 6
	jp L_420F		;4320
submodo_6_del_estado_11:
	ld hl,0e004h		;4323   ; SUBMODO 6 DEL ESTADO 11: espera, y levanta el bit 3 de 0xE1A8
	dec (hl)			;4326
	ret nz			;4327
	ld hl,0e1a8h		;4328
	set 3,(hl)		;432b   ; bit 3: la senal para que el submodo 7 pague
	jp avanza_de_submodo		;432d

; ----------------------------------------------------------------------
; SUBMODO 7 DEL ESTADO 11: EL PAGO. 0x5DF9 va moviendo los puntos de cien en cien, con su sonido, hasta que no queda nada pendiente; el bit 3 de 0xE1A8 es lo que dice que aun queda. Al terminar carga 0xE050, que es cuanto se espera en el submodo 8 antes de seguir solo: uno en el demo, y diez o dos en partida.
; ----------------------------------------------------------------------
submodo_7_del_estado_11:
	call mueve_cien_puntos		;4330   ; mueve cien puntos y pinta el marcador
	ld hl,0e1a8h		;4333
	bit 3,(hl)		;4336   ; bit 3 de 0xE1A8: aun queda por pagar
	ret nz			;4338
	ld a,(0e002h)		;4339
	bit 6,a		;433c   ; bit 6 de 0xE002: hay una persona jugando
	jr nz,L_4345		;433e
	ld hl,00001h		;4340   ; en el demo no se espera nada: un fotograma y a otra cosa
	jr L_4352		;4343
L_4345:
	ld a,(0e302h)		;4345
	bit 2,a		;4348   ; bit 2 de 0xE302
	ld hl,0000ah		;434a   ; diez fotogramas de espera
	jr z,L_4352		;434d
	ld hl,00002h		;434f   ; o dos
L_4352:
	ld (0e050h),hl		;4352   ; el reloj del submodo 8
	jp avanza_de_submodo		;4355

; ----------------------------------------------------------------------
; SUBMODO 8 DEL ESTADO 11, EL ULTIMO: "pulsa para seguir". Sale de aqui de dos maneras -por espacio o select (la mascara 0x30 de 0xE009), o porque se agote el reloj de 16 bits de 0xE050- y entonces DECIDE SI LA PARTIDA SIGUE: con el bit 4 de 0xE1A8 puesto pasa al estado 12, el recuento final; sin el, vuelve al estado 9 y se reparte otra mano.
; ----------------------------------------------------------------------
submodo_8_del_estado_11:
	ld a,(0e009h)		;4358   ; las teclas de este fotograma
	and 030h		;435b   ; bits 4 y 5: espacio o select valen igual
	jr nz,L_436E		;435d
	ld a,(0e003h)		;435f   ; y si no, hay que esperar a que pase el contador de fotogramas
	or a			;4362
	ret nz			;4363
	ld hl,(0e050h)		;4364   ; el reloj de 16 bits que cargo el submodo 7
	dec hl			;4367
	ld (0e050h),hl		;4368
	ld a,l			;436b
	or h			;436c
	ret nz			;436d
L_436E:
	call borra_la_fila_de_abajo		;436e   ; limpia lo que hubiera en pantalla
	ld hl,0e1a8h		;4371
	bit 4,(hl)		;4374   ; bit 4 de 0xE1A8: la partida se ha terminado
	jp nz,avanza_de_estado		;4376   ; al estado 12, el recuento final
	ld hl,0e000h		;4379
	ld (hl),009h		;437c   ; y si no, al estado 9: otra mano
	ld a,030h		;437e   ; con 48 fotogramas de espera
	jp L_41FC		;4380
L_4383:
	ld a,(0e001h)		;4383   ; ESTADO 12: cuatro submodos por (0xE001)
	call despacha_por_tabla		;4386

; ----------------------------------------------------------------------
; DATOS tabla_de_submodos_12: Las cuatro palabras del despachador, detras del
;   `call` de 0x4386. El indice es (0xE001).
;   0x4389..0x4391  (8 bytes)
DATA_tabla_de_submodos_12:
	defb 091h,043h	; 4389
	defb 094h,043h	; 438b
	defb 0c6h,043h	; 438d
	defb 0ceh,043h	; 438f

; ======================================================================
; CODIGO 0x4391..0x446b  (218 bytes)
; ======================================================================


L_4391:
	jp espera_32_y_avanza_de_submodo		;4391   ; SUBMODO 0 DEL ESTADO 12: paso de largo
L_4394:
	call pinta_una_franja_del_tapete		;4394   ; SUBMODO 1 DEL ESTADO 12: monta la pantalla del recuento final
	ret p			;4397
	ld hl,0e1a8h		;4398   ; 0xE1A8 a 1: solo el bit 0, todo lo demas limpio
	ld (hl),001h		;439b
	ld hl,038c5h		;439d   ; 0x38C5, donde va el texto
	ld (0e05dh),hl		;43a0
	xor a			;43a3
	call L_4A22		;43a4   ; borra el sonido
	ld hl,086d6h		;43a7
	call pinta_lista_formato_b		;43aa
	ld hl,08799h		;43ad
	call pinta_lista_formato_b		;43b0
	call L_4669		;43b3
	ld hl,087b4h		;43b6
	call pinta_lista_formato_b		;43b9
	ld hl,0e128h		;43bc
	ld (hl),038h		;43bf
	ld a,040h		;43c1   ; 0x38 en 0xE128
	jp L_420F		;43c3   ; 64 fotogramas
L_43C6:
	ld hl,0e004h		;43c6   ; SUBMODO 2 DEL ESTADO 12: cuenta atras
	dec (hl)			;43c9
	ret nz			;43ca
	jp avanza_de_submodo		;43cb
L_43CE:
	call desfila_el_recuento		;43ce   ; SUBMODO 3 DEL ESTADO 12: el recuento, y hasta que 0xE1A8 no quede a cero no se sale
	ld a,(0e1a8h)		;43d1
	or a			;43d4   ; mientras quede un solo bit puesto, aqui se sigue
	ret nz			;43d5
	ld a,080h		;43d6   ; 128 fotogramas y al estado 13
	jp L_41FC		;43d8
L_43DB:
	ld a,099h		;43db   ; ESTADO 13: el rotulo del final
	call L_9C4A		;43dd   ; sonido 0x99
	ld hl,08598h		;43e0
	call L_409D		;43e3   ; pinta el rotulo
	ld a,070h		;43e6   ; 112 fotogramas
	jp L_41FC		;43e8
L_43EB:
	ld a,(0e003h)		;43eb   ; ESTADO 14: cuenta atras, uno de cada cuatro fotogramas
	and 003h		;43ee   ; solo cuenta uno de cada cuatro: la espera sale por cuatro
	ret nz			;43f0
	ld hl,0e004h		;43f1
	dec (hl)			;43f4
	ret nz			;43f5
	ld hl,0e002h		;43f6
	ld a,(hl)			;43f9
	and 0bfh		;43fa   ; APAGA EL BIT 6: la partida se acaba y vuelve a mandar el demo
	ld (hl),a			;43fc
	jp vuelve_al_estado_0		;43fd   ; y al estado 0, a empezar de nuevo

; ----------------------------------------------------------------------
; La salida del estado 8: pone 0xE002 a 0x50, borra el marcador y se va al estado 9. ESE 0x50 SE ESCRIBE SIEMPRE, sin mirar que tecla se habia pulsado, y parece que se lleve por delante la dificultad recien elegida. NO SE LA LLEVA, y esta medido: la dificultad ya no viaja en 0xE002 a estas alturas, sino en 0xE040, que 0x4453 calculo durante el parpadeo y aqui nadie toca. De 0xE002 solo se mira el bit 6 de aqui en adelante, y 0x50 lo lleva puesto.
; Medido en openMSX arrancando en frio, pulsando una sola tecla en el demo y leyendo la RAM (tools/omsx_prueba_dificultad.tcl, un log por tecla en work/): con la tecla 1, 0xE002 pasa por 0x40 y 0xE040 queda en 0x01; con la 2, por 0x60 y queda en 0x04; con la 3, por 0x50 y queda en 0x02. En los tres casos 0xE002 acaba en 0x50 y 0xE040 se conserva hasta el final de la mano. Las tres dificultades SI llegan al juego.
; ----------------------------------------------------------------------
cierra_la_pantalla_de_dificultad:
	ld a,050h		;4400   ; 0x50: bit 6 puesto, y los bits 5-4 fijos pase lo que pase
	ld (0e002h),a		;4402
	call L_44A4		;4405   ; borra el marcador y las 622 variables de detras
	jp espera_32_y_avanza_de_estado		;4408

; ----------------------------------------------------------------------
; EL ESTADO 8, LA PANTALLA DE DIFICULTAD. Es el estado al que salta 0x4ABC cuando alguien pulsa 1, 2 o 3 durante el demo, y el unico al que 0x40CA no le pone retorno postizo. El submodo 0 limpia el sonido y la pantalla y carga 80 fotogramas; a partir de ahi 0x4438 hace parpadear la linea de la dificultad elegida -ocho fotogramas puesta, ocho quitada, que es lo que mide el bit 3 del reloj- hasta que se agota, y entonces pasa por 0x4400 camino del estado 9.
; ----------------------------------------------------------------------
estado_8_elige_dificultad:
	ld a,(0e001h)		;440b
	or a			;440e
	jr nz,L_4438		;440f
	ld hl,0e010h		;4411   ; borra los cuarenta bytes de los canales de sonido
	ld (hl),000h		;4414
	ld de,0e011h		;4416
	ld bc,00027h		;4419
	ldir		;441c
	call limpia_la_pantalla_entera		;441e   ; limpia la pantalla
	xor a			;4421
	call L_4A22		;4422
	call L_4472		;4425   ; pinta la mesa
	call L_45AA		;4428   ; y el texto de las tres dificultades
	ld a,050h		;442b
	ld (0e004h),a		;442d   ; 80 fotogramas de parpadeo
	ld a,09ch		;4430   ; sonido 0x9C, el de empezar partida
	call L_9C4A		;4432
	jp avanza_de_submodo		;4435
L_4438:
	ld hl,0e004h		;4438   ; cada fotograma mientras dure el parpadeo
	dec (hl)			;443b
	jr z,cierra_la_pantalla_de_dificultad		;443c   ; agotado: por 0x4400 al estado 9
	ld a,(hl)			;443e
	and 008h		;443f   ; bit 3 del reloj: ocho fotogramas si y ocho no
	jp nz,L_45AA		;4441   ; en los "si", el texto entero repintado
	ld a,(0e002h)		;4444   ; y en los "no", se borra la linea de la elegida
	rra			;4447
	rra			;4448
	rra			;4449
	rra			;444a
	and 003h		;444b   ; los bits 5 y 4 de 0xE002 bajados a un indice de 0 a 3
	ld c,a			;444d
	or a			;444e
	jr nz,L_4452		;444f
	ccf			;4451   ; la dificultad 0 no vale cero: se le mete el acarreo
L_4452:
	rla			;4452
	ld (0e040h),a		;4453   ; 0xE040, la dificultad tal como la lee el estado 11: 1, 4 o 2
	ld a,c			;4456
	ld hl,0446bh		;4457   ; la tabla de las cuatro filas
	call suma_a_a_hl		;445a
	ld a,(hl)			;445d
	ld de,03a40h		;445e   ; 0x3A40, la primera de las tres lineas de dificultad
	call suma_a_a_de		;4461
	ld bc,00020h		;4464   ; borra la fila entera, 32 celdas
	xor a			;4467
	jp rellena_la_vram		;4468

; ----------------------------------------------------------------------
; DATOS desplazamientos_de_borrado: Cuatro desplazamientos, 0x00 0x80 0x40
;   0xC0, que 0x4457 saca con el indice de C y suma a la direccion de VRAM
;   0x3A40 antes de borrar 0x20 bytes.
;   0x446b..0x446f  (4 bytes)
DATA_desplazamientos_de_borrado:
	defb 000h,080h,040h,0c0h	; 446b

; ======================================================================
; CODIGO 0x446f..0x4708  (665 bytes)
; ======================================================================


L_446F:
	call monta_el_rotulo_que_baja		;446f
L_4472:
	ld hl,083b1h		;4472
	ld de,06600h		;4475
	ld bc,00180h		;4478
	call L_460B		;447b
	ld de,l4600h		;447e
	ld bc,00180h		;4481
	ld a,070h		;4484
	call rellena_la_vram		;4486
	call L_4674		;4489
	ld hl,085d5h		;448c
	call pinta_lista_formato_b		;448f
	ld de,04500h		;4492
	ld bc,002f0h		;4495
	ld a,0c0h		;4498
L_449A:
	call escribe_en_vram		;449a
	inc de			;449d
	dec c			;449e
	jr nz,L_449A		;449f
	djnz L_449A		;44a1
	ret			;44a3
L_44A4:
	ld hl,0e047h		;44a4
	ld bc,0026eh		;44a7
	ld d,h			;44aa
	ld e,l			;44ab
	inc e			;44ac
	ld (hl),000h		;44ad
	ldir		;44af
	ret			;44b1

; ----------------------------------------------------------------------
; Baja los dos relojes (0xE003 y 0xE004) y, mientras el de 0xE004 no se agote, va pintando 24 celdas de una columna del tapete. El xor 0x1F de 0x44C0 le da la vuelta al indice en los fotogramas pares, asi que la franja avanza en un sentido y luego en el otro. Sale con el signo puesto para que el estado sepa si ya ha terminado (ret p en los estados 0, 6 y 10).
; ----------------------------------------------------------------------
pinta_una_franja_del_tapete:
	ld b,018h		;44b2   ; 24 celdas, una columna entera de la pantalla
	ld hl,0e003h		;44b4
	dec (hl)			;44b7   ; baja el reloj de fotogramas
	inc hl			;44b8
	dec (hl)			;44b9   ; y el de la espera del estado
	ret m			;44ba   ; negativo: la espera se ha agotado, el estado puede seguir
	ld a,(hl)			;44bb
	srl a		;44bc
	jr c,L_44C2		;44be
	xor 01fh		;44c0   ; en los fotogramas pares el recorrido va al reves
L_44C2:
	ld e,a			;44c2
	ld d,038h		;44c3   ; 0x38xx, la tabla de nombres de la pantalla
	ld a,(0e1b8h)		;44c5   ; mas el desplazamiento del tapete
	add a,e			;44c8
	ld e,a			;44c9
	ld a,(0e1b9h)		;44ca
	add a,d			;44cd
	ld d,a			;44ce
L_44CF:
	xor a			;44cf
	call escribe_en_vram		;44d0
	ld a,020h		;44d3
	call suma_a_a_de		;44d5   ; 0x20 = una fila entera abajo
	djnz L_44CF		;44d8

; ----------------------------------------------------------------------
; Escribe el tile 0xD0 en 0x3B00 y vuelve con A a cero. Es lo que limpia el aviso de "pulsa para seguir" al salir del submodo 8.
; ----------------------------------------------------------------------
borra_la_fila_de_abajo:
	ld de,03b00h		;44da
	ld a,0d0h		;44dd
	call escribe_en_vram		;44df
	xor a			;44e2
	ret			;44e3
L_44E4:
	call pinta_el_contador_de_e04b		;44e4

; ----------------------------------------------------------------------
; Pinta los dos marcadores con su signo delante. El signo no es un caracter que se calcule: son dos tiles distintos, el 0x01 y el 0x21, y se elige mirando el bit de 0xE100. El de 0xE047 va en 0x39C2 y el de 0xE044 en 0x3922, tres celdas cada uno.
; ----------------------------------------------------------------------
pinta_los_dos_marcadores:
	ld de,039c2h		;44e7   ; 0x39C2, donde va el marcador de 0xE047
	ld a,(0e100h)		;44ea
	rra			;44ed
	rra			;44ee   ; el bit 1 del signo
	ld a,001h		;44ef   ; tile 0x01: el marcador esta en positivo
	jr nc,L_44F5		;44f1
	ld a,021h		;44f3   ; tile 0x21: esta en numeros rojos
L_44F5:
	call escribe_en_vram		;44f5
	ld hl,0e049h		;44f8   ; y detras los tres bytes BCD
	inc de			;44fb
	ld b,003h		;44fc
	call pinta_un_numero_bcd		;44fe
	ld de,03922h		;4501   ; 0x3922, el otro marcador
	ld a,(0e100h)		;4504
	rla			;4507
	rla			;4508   ; aqui el bit que manda es el 7
	ld a,001h		;4509
	jr nc,L_450F		;450b
	ld a,021h		;450d
L_450F:
	call escribe_en_vram		;450f
	ld hl,0e046h		;4512
	inc de			;4515
	ld b,003h		;4516

; ----------------------------------------------------------------------
; EL PINTADOR DE NUMEROS, y no es un simple volcado: SUPRIME LOS CEROS DE LA IZQUIERDA. Entra con HL en el byte MAS significativo del contador, B = cuantos bytes y DE = donde va en la VRAM. Cada byte da dos cifras, nibble alto primero, y la cifra se convierte en tile sumandole 0x10: el tile 0x10 es el "0" y el 0x19 el "9". El tile 0x01 es el blanco, y es lo que se pinta en lugar de un cero mientras no haya salido ninguna cifra distinta de cero. Para saberlo mira los bytes de ENCIMA, que en un contador de byte bajo primero son los mas significativos. Baja por la memoria con el `dec hl` de 0x456B, o sea que pinta de la cifra mas alta a la mas baja.
; ----------------------------------------------------------------------
pinta_un_numero_bcd:
	ld a,(hl)			;4518   ; el byte que toca, dos cifras dentro
	push af			;4519
	and 00fh		;451a   ; el nibble bajo, la cifra de la derecha
	or 010h		;451c   ; mas 0x10: asi la cifra 0 es el tile 0x10
	ld c,a			;451e
	pop af			;451f
	and 0f0h		;4520   ; y ahora el nibble alto
	rra			;4522   ; cuatro rotaciones para bajarlo
	rra			;4523
	rra			;4524
	rra			;4525
	or 010h		;4526
	push de			;4528
	ld d,a			;4529
	ld a,b			;452a
	cp 003h		;452b   ; el primer byte no tiene ninguno encima que mirar
	ld a,d			;452d
	jr z,L_4555		;452e
	inc hl			;4530   ; mira el byte de encima, el mas significativo
	ld a,(hl)			;4531
	dec hl			;4532
	or a			;4533
	ld a,d			;4534
	jr nz,L_4562		;4535   ; si alguno de arriba no era cero, ya no se suprime nada
	ld a,b			;4537
	cp 002h		;4538   ; el segundo byte solo tiene uno encima
	ld a,d			;453a
	jr z,L_4555		;453b
	inc hl			;453d   ; y el tercero tiene dos
	inc hl			;453e
	ld a,(hl)			;453f
	dec hl			;4540
	dec hl			;4541
	or a			;4542
	ld a,d			;4543
	jr nz,L_4562		;4544
	cp 010h		;4546   ; la cifra alta es un cero: candidata a suprimirse
	jr nz,L_4562		;4548
	ld a,c			;454a   ; y si la baja tambien lo es, las dos van en blanco
	cp 010h		;454b
	ld a,001h		;454d   ; tile 0x01, el blanco
	jr nz,L_4562		;454f
	ld c,010h		;4551   ; la baja tambien en blanco
	jr L_4562		;4553
L_4555:
	cp 010h		;4555   ; el primer byte del todo: mismo criterio, sin nada encima
	jr nz,L_4562		;4557
	ld a,c			;4559
	cp 010h		;455a
	ld a,001h		;455c
	jr nz,L_4562		;455e
	ld c,001h		;4560
L_4562:
	pop de			;4562
	call escribe_en_vram		;4563   ; la cifra alta a la VRAM
	inc de			;4566
	ld a,c			;4567
	call escribe_en_vram		;4568   ; y la baja en la celda de al lado
	dec hl			;456b   ; se baja al byte siguiente, que es menos significativo
	inc de			;456c
	djnz pinta_un_numero_bcd		;456d
	ret			;456f

; ----------------------------------------------------------------------
; Pinta el byte de 0xE04A -dos cifras BCD- en 0x3985. Igual que su gemela de abajo pero con otra variable y otro sitio; las dos comparten el cuerpo de 0x457E.
; ----------------------------------------------------------------------
pinta_el_contador_de_e04a:
	ld de,03985h		;4570
	ld hl,0e04ah		;4573
	jr L_457E		;4576

; ----------------------------------------------------------------------
; Pinta el byte de 0xE04B en 0x39AA. Cae por abajo en el cuerpo comun. La diferencia con 0x4518 es que aqui la cifra alta, cuando es cero, no se pinta en blanco sino como tile 1: es un contador de dos cifras, no un marcador.
; ----------------------------------------------------------------------
pinta_el_contador_de_e04b:
	ld de,039aah		;4578
	ld hl,0e04bh		;457b
L_457E:
	ld a,(hl)			;457e
	push af			;457f
	and 00fh		;4580
	or 010h		;4582
	ld c,a			;4584
	pop af			;4585
	and 0f0h		;4586
	rra			;4588
	rra			;4589
	rra			;458a
	rra			;458b
	or a			;458c   ; la cifra alta a cero
	jr nz,L_4592		;458d
	inc a			;458f   ; tile 1 en vez del 0x10
	jr L_4594		;4590
L_4592:
	or 010h		;4592
L_4594:
	call escribe_en_vram		;4594
	inc de			;4597
	ld a,c			;4598
	jp escribe_en_vram		;4599
L_459C:
	ld a,(hl)			;459c
	and 00fh		;459d
	or 010h		;459f
	cp 010h		;45a1
	jr nz,L_45A7		;45a3
	ld a,001h		;45a5
L_45A7:
	jp escribe_en_vram		;45a7
L_45AA:
	xor a			;45aa
	ld (0e00ah),a		;45ab
L_45AE:
	call suelta_una_linea_de_texto		;45ae
	jr c,L_45AE		;45b1
	ret			;45b3

; ----------------------------------------------------------------------
; Suelta una linea del texto de presentacion por fotograma, hasta 18 (0x12), llevando la cuenta en 0xE00A. Vuelve con acarreo mientras queden lineas, y sin el cuando se acaban: por eso el estado 3 hace ret c para quedarse.
; ----------------------------------------------------------------------
suelta_una_linea_de_texto:
	ld hl,0e00ah		;45b4
	ld a,(hl)			;45b7   ; la linea que toca
	inc (hl)			;45b8
	cp 012h		;45b9   ; dieciocho lineas y se acabo
	jr nc,L_45DA		;45bb
	ld de,03887h		;45bd   ; 0x3887, la primera celda del texto
	ld c,a			;45c0
	add a,e			;45c1
	ld e,a			;45c2
	ld a,c			;45c3
	add a,a			;45c4   ; tres celdas de ancho por linea
	add a,c			;45c5
	add a,0a0h		;45c6
	ld c,a			;45c8
	ld b,003h		;45c9   ; tres celdas
	inc c			;45cb
L_45CC:
	call escribe_en_vram		;45cc
	ld a,020h		;45cf
	call suma_a_a_de		;45d1   ; 0x20: baja una fila
	ld a,c			;45d4
	inc c			;45d5
	djnz L_45CC		;45d6
	scf			;45d8   ; acarreo puesto: aun quedan lineas
	ret			;45d9
L_45DA:
	push af			;45da
	ld hl,08531h		;45db
	call z,L_409D		;45de
	pop af			;45e1
	cp 034h		;45e2
	ret			;45e4

; ----------------------------------------------------------------------
; Resta A de DE. La contraria de 0x4068, para las rutinas que suben por la VRAM en vez de bajar.
; ----------------------------------------------------------------------
resta_a_de_de:
	ld b,a			;45e5
	ld a,e			;45e6
	sub b			;45e7
	ld e,a			;45e8
	ret nc			;45e9
	dec d			;45ea
	ret			;45eb

; ----------------------------------------------------------------------
; Borra el aviso de abajo y luego los 768 bytes de la tabla de nombres a partir de 0x7800. Lo llama el estado 8 al empezar la partida.
; ----------------------------------------------------------------------
limpia_la_pantalla_entera:
	call borra_la_fila_de_abajo		;45ec
	ld de,07800h		;45ef   ; 0x7800, la tabla de nombres del tercer tercio
	ld bc,00300h		;45f2   ; 768 bytes, la pantalla entera
	xor a			;45f5

; ----------------------------------------------------------------------
; Rellena BC bytes de VRAM desde DE con el valor de A. Es el borrador de todo el cartucho: lo usan el arranque (16 KB de golpe), el borrado de filas del menu y la limpieza entre pantallas. El bucle escribe directo al puerto que 0x470F dejo en C', sin volver a armar la direccion cada byte.
; ----------------------------------------------------------------------
rellena_la_vram:
	call prepara_escritura_vram		;45f6   ; arma la direccion y deja el puerto en C'
L_45F9:
	ex af,af'			;45f9
L_45FA:
	ex af,af'			;45fa
	exx			;45fb
	out (c),a		;45fc   ; el byte, al puerto de datos
	exx			;45fe
	ex af,af'			;45ff
L_4600:
	dec bc			;4600
	ld a,b			;4601
	or c			;4602
	jr nz,L_45FA		;4603
	ei			;4605
	ret			;4606
L_4607:
	ld a,(hl)			;4607
	inc hl			;4608
	jr L_45F9		;4609
L_460B:
	di			;460b
	call prepara_escritura_vram		;460c
L_460F:
	ld a,(hl)			;460f
	exx			;4610
	out (c),a		;4611
	exx			;4613
	inc hl			;4614
	dec bc			;4615
	ld a,b			;4616
	or c			;4617
	jr nz,L_460F		;4618
	ei			;461a
	ret			;461b
L_461C:
	di			;461c
	call prepara_lectura_vram		;461d
L_4620:
	exx			;4620
	in a,(c)		;4621
	exx			;4623
	ld (hl),a			;4624
	inc hl			;4625
	dec bc			;4626
	ld a,b			;4627
	or c			;4628
	push hl			;4629
	pop hl			;462a
	jr nz,L_4620		;462b
	ei			;462d
	ret			;462e
L_462F:
	call prepara_lectura_vram		;462f
L_4632:
	exx			;4632
	in a,(c)		;4633
	exx			;4635
	ld d,a			;4636
	and 00fh		;4637
	jr nz,L_463C		;4639
	inc d			;463b
L_463C:
	ld a,d			;463c
	ld (hl),a			;463d
	inc hl			;463e
	dec bc			;463f
	ld a,b			;4640
	or c			;4641
	push hl			;4642
	pop hl			;4643
	jr nz,L_4632		;4644
	ei			;4646
	ret			;4647
L_4648:
	call lee_de_vram		;4648
	ex de,hl			;464b
	call escribe_en_vram		;464c
	ex de,hl			;464f
	inc hl			;4650
	inc de			;4651
	dec bc			;4652
	ld a,c			;4653
	or b			;4654
	jr nz,L_4648		;4655
	ret			;4657
L_4658:
	ld de,02000h		;4658
	ld hl,02800h		;465b
L_465E:
	ld bc,00800h		;465e
	call L_4648		;4661
	ld bc,00800h		;4664
	jr L_4648		;4667
L_4669:
	call L_4658		;4669
	ld de,00000h		;466c
	ld hl,00800h		;466f
	jr L_465E		;4672
L_4674:
	ld a,0f0h		;4674
L_4676:
	ld de,00080h		;4676
	ld bc,00180h		;4679
	call rellena_la_vram		;467c
	ld hl,083b1h		;467f
	ld a,020h		;4682
	add a,d			;4684
	ld d,a			;4685
	ld bc,00180h		;4686
	call L_460B		;4689
	jp L_4669		;468c

; ----------------------------------------------------------------------
; El interprete de FORMATO B, el que gasta casi todos los dibujos del cartucho. Lee dos bytes de destino en la VRAM y luego ordenes, cada una un byte: los siete bits bajos son la CUENTA y el bit 7 elige que hacer con ella, 0x4607 o 0x460F. Una orden con la cuenta a cero termina: si el bit 7 esta puesto (byte 0x80) vuelve arriba a leer otro destino, y si el byte es 0x00 del todo, se acabo la lista. La entrada de 0x4693 se salta la lectura del destino, para las listas que lo traen ya puesto en DE desde fuera.
; ----------------------------------------------------------------------
pinta_lista_formato_b:
	ld e,(hl)			;468f   ; los dos bytes de destino, byte bajo primero
	inc hl			;4690
	ld d,(hl)			;4691
	inc hl			;4692
L_4693:
	di			;4693   ; entra aqui quien ya trae el destino en DE
	call prepara_escritura_vram		;4694   ; arma el VDP y deja el puerto de datos en C'
L_4697:
	ld a,(hl)			;4697
	and 07fh		;4698   ; los siete bits bajos son la cuenta
	ld c,a			;469a
	ld a,(hl)			;469b   ; y el byte entero, con su bit 7
	inc hl			;469c
	jr nz,L_46A4		;469d   ; cuenta distinta de cero: hay orden que ejecutar
	cp c			;469f   ; cuenta cero y bit 7 puesto: viene otro destino
	jr nz,pinta_lista_formato_b		;46a0
	ei			;46a2   ; cuenta cero y byte cero: fin de la lista
	ret			;46a3
L_46A4:
	ld b,000h		;46a4
	cp c			;46a6   ; compara el byte con su parte baja: dice si el bit 7 esta puesto
	push af			;46a7
	call nz,L_460F		;46a8   ; con el bit 7 puesto, por 0x460F
	pop af			;46ab
	call z,L_4607		;46ac   ; y sin el, por 0x4607
	jr L_4697		;46af

; ----------------------------------------------------------------------
; Vuelca 36 columnas de 48 bytes leyendo 0xE2E5 HACIA ATRAS y dandole la vuelta a cada byte con 0x46D0. Bajar por la memoria invierte el orden vertical y el espejo de bits invierte el horizontal: el dibujo sale girado 180 grados. Es la mano del jugador de enfrente, que se ve del reves desde este lado de la mesa.
; ----------------------------------------------------------------------
pinta_la_mano_del_espejo:
	call prepara_escritura_vram		;46b1
	ld c,024h		;46b4   ; 36 columnas
L_46B6:
	push bc			;46b6
	call L_7883		;46b7   ; rellena el trozo de 0xE2E5 antes de volcarlo
	pop bc			;46ba
	ld hl,0e2e5h		;46bb
	ld b,030h		;46be   ; 48 bytes por columna
L_46C0:
	call espeja_los_bits		;46c0   ; el byte, ya con los bits del reves
	exx			;46c3
	out (c),a		;46c4   ; y al VDP
	exx			;46c6
	inc de			;46c7
	dec hl			;46c8   ; hacia ATRAS por la memoria: eso invierte el dibujo de arriba abajo
	djnz L_46C0		;46c9
	dec c			;46cb
	jr nz,L_46B6		;46cc
	ei			;46ce
	ret			;46cf

; ----------------------------------------------------------------------
; Le da la vuelta a los ocho bits de A. El truco son las dos rotaciones encadenadas: `rl c` saca el bit de mas peso de C al acarreo y `rra` lo mete a A por el otro extremo, ocho veces. Un byte de patron espejado es ese mismo dibujo visto del reves de izquierda a derecha.
; ----------------------------------------------------------------------
espeja_los_bits:
	ld a,(hl)			;46d0
	push bc			;46d1
	ld b,008h		;46d2   ; ocho bits
	ld c,a			;46d4
L_46D5:
	rl c		;46d5   ; saca el bit de mas peso por el acarreo
	rra			;46d7   ; y entra en A por el de menos peso
	djnz L_46D5		;46d8
	pop bc			;46da
	ret			;46db

; ----------------------------------------------------------------------
; Vuelca 36 columnas de 48 bytes desde 0xE2E5, un byte por celda. Es la gemela de 0x46B1 sin el espejo de bits: las dos recorren el mismo trozo de RAM hacia atras -lo que da la vuelta al dibujo de arriba abajo- y solo una le da tambien la vuelta de izquierda a derecha. Una mano, vista desde los dos lados de la mesa.
; ----------------------------------------------------------------------
vuelca_la_mano_de_este_lado:
	call prepara_escritura_vram		;46dc
	ld c,024h		;46df   ; 36 columnas
L_46E1:
	push bc			;46e1
	call L_7883		;46e2   ; rellena el trozo de 0xE2E5 antes de volcar la columna
	pop bc			;46e5
	ld hl,0e2e5h		;46e6
	ld b,030h		;46e9   ; 48 bytes cada una
L_46EB:
	ld a,(hl)			;46eb   ; el byte tal cual, sin espejar
	exx			;46ec
	out (c),a		;46ed
	exx			;46ef
	inc de			;46f0
	dec hl			;46f1   ; hacia ATRAS por la memoria
	djnz L_46EB		;46f2
	dec c			;46f4
	jr nz,L_46E1		;46f5
	ei			;46f7
	ret			;46f8

; ----------------------------------------------------------------------
; Borra 48 bytes de la VRAM en 0x6000 y suelta encima la lista de 0x4708. Cae en el interprete con un `jr`, sin gastar un `call`.
; ----------------------------------------------------------------------
limpia_y_pinta_los_ceros:
	xor a			;46f9
	ld de,06000h		;46fa   ; 0x6000, que en la VRAM de 16 KB es 0x2000: los colores
	ld bc,00030h		;46fd
	call rellena_la_vram		;4700
	ld hl,04708h		;4703   ; y encima, la lista de siete bytes de aqui al lado
	jr pinta_lista_formato_b		;4706

; ----------------------------------------------------------------------
; DATOS lista_de_los_seis_ceros: Lista de formato B que 0x4703 pinta llamando
;   a 0x468F: destino 0x4008, ocho bytes de salida.
;   0x4708..0x470f  (7 bytes)
DATA_lista_de_los_seis_ceros:
	defb 008h,040h,008h,001h,008h,007h,000h	; 4708

; ======================================================================
; CODIGO 0x470f..0x4735  (38 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; Prepara el VDP para escribir en la direccion que trae DE y deja el puerto de datos en C'. Guarda A en A' porque SETWRT lo machaca. Sale con las interrupciones QUITADAS a proposito: quien llama las devuelve.
; ----------------------------------------------------------------------
prepara_escritura_vram:
	ex af,af'			;470f
	ex de,hl			;4710
	call 00053h		;4711   ; BIOS SETWRT - Enables VDP to write | SETWRT arma la direccion de escritura
	di			;4714   ; nadie puede colarse entre la direccion y el dato
	ex de,hl			;4715
	exx			;4716
	ld a,(00006h)		;4717   ; 0x0006 = el puerto de datos del VDP, que la BIOS deja ahi
	ld c,a			;471a
	exx			;471b
	ex af,af'			;471c
	ret			;471d

; ----------------------------------------------------------------------
; La hermana de 0x470F para leer: SETRD en vez de SETWRT, y coge el puerto de 0x0007.
; ----------------------------------------------------------------------
prepara_lectura_vram:
	ex de,hl			;471e
	call 00050h		;471f   ; BIOS SETRD - Enables VDP to read
	di			;4722
	ex de,hl			;4723
	exx			;4724
	ld a,(00007h)		;4725
	ld c,a			;4728
	exx			;4729
	ret			;472a

; ----------------------------------------------------------------------
; Devuelve en A un byte de la tabla de 0x4735, indexando con el A de entrada. Son cuatro filas de diez posiciones que bajan de seis en seis, una por orientacion de la mesa.
; ----------------------------------------------------------------------
saca_una_posicion:
	push hl			;472b
	ld hl,04735h		;472c
	call suma_a_a_hl		;472f   ; indexa la tabla con A
	ld a,(hl)			;4732
	pop hl			;4733
	ret			;4734

; ----------------------------------------------------------------------
; DATOS cuatro_filas_de_posiciones: Cuatro filas de 16 bytes con diez valores
;   utiles cada una, que bajan de seis en seis: 0xFA..0xC4, 0x88..0x58,
;   0xBE..0x8E y 0x52..0x28. La lee 0x472C indexando con A. Son las cuatro
;   orientaciones de la mesa.
;   0x4735..0x476f  (58 bytes)
DATA_cuatro_filas_de_posiciones:
	defb 0fah,0f4h,0eeh,0e8h,0e2h,0dch,0d6h,0d0h,0cah,0c4h,000h,000h,000h,000h,000h,000h	; 4735  ................
	defb 000h,088h,082h,07ch,076h,070h,06ah,064h,05eh,058h,000h,000h,000h,000h,000h,000h	; 4745  ...|vpjd^X......
	defb 000h,0beh,0b8h,0b2h,0ach,0a6h,0a0h,09ah,094h,08eh,000h,000h,000h,000h,000h,000h	; 4755  ................
	defb 000h,052h,04ch,046h,040h,03ah,034h,02eh,028h,0fah	; 4765  .RLF@:4.(.

; ======================================================================
; CODIGO 0x476f..0x47b2  (67 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; Pinta en la fila 11 y la 12 de la columna 2 uno de los tres dibujos de 0x47C2, 0x47D8 y 0x47EB, con el numero en A. Antes borra el sitio con la lista de fondo. El dibujo 2 es distinto de los otros dos: suena al aparecer -pero solo si el que habia antes no era ya el 2- y detras se queda una espera larga a pelo. Se pide desde seis sitios distintos del juego de la mano.
; ----------------------------------------------------------------------
pinta_uno_de_los_tres_dibujos:
	push hl			;476f
	push de			;4770
	push bc			;4771
	push af			;4772
	ld hl,047b8h		;4773   ; borra las dos filas antes de pintar nada
	call pinta_lista_formato_b		;4776
	pop af			;4779
	cp 002h		;477a   ; el dibujo 2 es el unico que suena
	push af			;477c
	jr nz,L_478B		;477d
	ld a,(0e061h)		;477f   ; y solo suena si el que habia no era ya el 2
	cp 002h		;4782
	jr z,L_478B		;4784
	ld a,08dh		;4786   ; sonido 0x8D
	call L_9C4A		;4788
L_478B:
	pop af			;478b
	push af			;478c
	ld (0e061h),a		;478d   ; se apunta cual queda puesto, para la vez siguiente
	add a,a			;4790   ; cada puntero son dos bytes
	ld hl,047b2h		;4791
	call suma_a_a_hl		;4794
	ld e,(hl)			;4797
	inc hl			;4798
	ld d,(hl)			;4799
	ex de,hl			;479a
	call pinta_lista_formato_b		;479b   ; y a pintarlo
	pop af			;479e
	cp 002h		;479f   ; otra vez el 2: ademas de sonar, se para un momento
	call z,para_un_momento		;47a1
	pop bc			;47a4
	pop de			;47a5
	pop hl			;47a6
	ret			;47a7

; ----------------------------------------------------------------------
; Espera a pelo: 255 vueltas de 255. No mira el reloj ni la interrupcion, cuenta y ya. Como todo esto corre DENTRO de la interrupcion, mientras dura no avanza nada mas.
; ----------------------------------------------------------------------
para_un_momento:
	ld h,0ffh		;47a8   ; 255 vueltas de fuera
L_47AA:
	ld b,0ffh		;47aa   ; por 255 de dentro
L_47AC:
	djnz L_47AC		;47ac
	dec h			;47ae
	jr nz,L_47AA		;47af
	ret			;47b1

; ----------------------------------------------------------------------
; DATOS punteros_de_los_tres_dibujos: Tres palabras -0x47C2, 0x47D8, 0x47EB-
;   que 0x4791 indexa con A doblado. Cada una es una lista de formato B.
;   0x47b2..0x47b8  (6 bytes)
DATA_punteros_de_los_tres_dibujos:
	defb 0c2h,047h	; 47b2
	defb 0d8h,047h	; 47b4
	defb 0ebh,047h	; 47b6

; ----------------------------------------------------------------------
; DATOS lista_de_fondo: Formato B desde 0x4776: borra las filas 10 y 13 de la
;   columna 2.
;   0x47b8..0x47c2  (10 bytes)
DATA_lista_de_fondo:
	defb 042h,079h,007h,04eh,080h,0a2h,079h,007h,020h,000h	; 47b8  By.N..y. .

; ----------------------------------------------------------------------
; DATOS dibujo_0: Formato B: siete tiles en la fila 11 y siete en la fila 12,
;   columna 2.
;   0x47c2..0x47d8  (22 bytes)
DATA_dibujo_0:
	defb 062h,079h,087h,055h,05ah,05bh,0f7h,0e5h,0f0h,05bh,080h,082h,079h,087h,0f1h,0ebh	; 47c2  by.UZ[...[..y...
	defb 05bh,0fdh,0f0h,067h,060h,000h	; 47d2

; ----------------------------------------------------------------------
; DATOS dibujo_1: Formato B, las mismas dos filas con otro dibujo.
;   0x47d8..0x47eb  (19 bytes)
DATA_dibujo_1:
	defb 062h,079h,087h,0fdh,0f0h,05bh,06ch,06dh,04fh,054h,080h,082h,079h,005h,002h,082h	; 47d8  by...[lmOT..y...
	defb 067h,060h,000h	; 47e8

; ----------------------------------------------------------------------
; DATOS dibujo_2: Formato B, las mismas dos filas con el tercer dibujo.
;   0x47eb..0x47fb  (16 bytes)
DATA_dibujo_2:
	defb 062h,079h,087h,06dh,0e4h,061h,066h,067h,0f0h,002h,080h,082h,079h,007h,002h,000h	; 47eb  by.m.afg....y...

; ======================================================================
; CODIGO 0x47fb..0x4968  (365 bytes)
; ======================================================================


L_47FB:
	ld hl,0e233h		;47fb
	ld de,0e172h		;47fe
	ld a,(0e1cch)		;4801
	ld c,a			;4804
	ld a,(0e04dh)		;4805
	rra			;4808
	jr nc,L_480C		;4809
	inc c			;480b
L_480C:
	ld a,c			;480c
	call suma_a_a_de		;480d
	ld a,(0e1bfh)		;4810
	sub c			;4813
	ret z			;4814
	ld c,a			;4815
	ld a,(0e302h)		;4816
	bit 2,a		;4819
	jr z,L_481E		;481b
	inc c			;481d
L_481E:
	ld hl,0e1f5h		;481e
	ld (0e203h),de		;4821
	call L_4865		;4825
	ld hl,0e1cdh		;4828
	set 5,(hl)		;482b
	ld hl,0e1ach		;482d
	ld (hl),001h		;4830
	ret			;4832

; ----------------------------------------------------------------------
; Cruza la lista de 0xE1F5 contra dos sitios: primero contra los cuatro bytes de 0xE233 (por 0x487D) y luego contra la lista a la que apunta 0xE203, con C entradas. En cuanto encuentra un byte que este en las dos, levanta el bit 6 de 0xE1CD y pone 0xE1AC a cero, que es la senal que mira el submodo 2 del estado 11 para cantar jugada.
; ----------------------------------------------------------------------
busca_en_las_dos_listas:
	ld hl,0e1f5h		;4833
	call L_487D		;4836
	ld hl,0e1f5h		;4839
	ld de,0e15eh		;483c
	ld (0e203h),de		;483f   ; la segunda lista donde buscar
	ld a,(0e1beh)		;4843   ; cuantas entradas tiene, una mas de las que dice 0xE1BE
	inc a			;4846
	ld c,a			;4847
	call L_4865		;4848
	ld hl,0e1cdh		;484b
	set 6,(hl)		;484e   ; bit 6 de 0xE1CD: hay coincidencia
	ld hl,0e1ach		;4850
	ld (hl),000h		;4853   ; y 0xE1AC a cero
	ret			;4855

; ----------------------------------------------------------------------
; El bucle de busqueda: por cada byte de HL recorre los C bytes de (0xE203) buscando uno igual. Un cero en cualquiera de las dos listas la termina. El `pop de` de 0x486B es una salida a lo bruto: se come la direccion de retorno para volver DOS niveles arriba de golpe cuando la lista de HL se acaba.
; ----------------------------------------------------------------------
recorre_la_lista_larga:
	ld de,(0e203h)		;4856
	ld b,c			;485a
L_485B:
	ld a,(de)			;485b
	or a			;485c
	jr z,L_4864		;485d   ; un cero termina la lista de dentro
	cp (hl)			;485f
	ret z			;4860   ; encontrado: se vuelve con el byte en A
	inc de			;4861
	djnz L_485B		;4862
L_4864:
	inc hl			;4864   ; no estaba: al siguiente de la lista de fuera
L_4865:
	ld a,(hl)			;4865
	or a			;4866
	jr z,L_486B		;4867
	jr recorre_la_lista_larga		;4869
L_486B:
	pop de			;486b   ; se come el retorno y sale dos niveles arriba
	ret			;486c

; ----------------------------------------------------------------------
; La misma busqueda contra los CUATRO bytes fijos de 0xE233. Entra por 0x487D, que es quien comprueba primero que la lista de HL no este vacia.
; ----------------------------------------------------------------------
recorre_los_cuatro_de_e233:
	ld de,0e233h		;486d
	ld b,004h		;4870   ; cuatro bytes, ni uno mas
L_4872:
	ld a,(de)			;4872
	or a			;4873
	jr z,L_487C		;4874   ; el cero corta antes de los cuatro
	cp (hl)			;4876
	jr z,marca_la_coincidencia		;4877   ; encontrado
	inc de			;4879
	djnz L_4872		;487a
L_487C:
	inc hl			;487c
L_487D:
	ld a,(hl)			;487d
	or a			;487e
	ret z			;487f   ; lista vacia: no hay nada que cruzar
	jr recorre_los_cuatro_de_e233		;4880

; ----------------------------------------------------------------------
; Levanta el bit 6 de 0xE1CD y borra 0xE1AC. Es lo que hacen las dos busquedas al encontrar algo, y lo que el submodo 2 del estado 11 lee en 0x427C para irse a cantar la jugada.
; ----------------------------------------------------------------------
marca_la_coincidencia:
	ld hl,0e1cdh		;4882
	set 6,(hl)		;4885
	ld hl,0e1ach		;4887
	ld (hl),000h		;488a
	ret			;488c

; ----------------------------------------------------------------------
; EL DESFILE DE LA PANTALLA FINAL, y quien la termina. Corre uno de cada ocho fotogramas y va escribiendo por parejas: 0xE05D es donde toca, y cada diez pasos baja 0x50 en la VRAM -dos filas y media- y sube el contador de columna. A la CUARTA columna pone 0xE1A8 a cero, que es exactamente lo que el submodo 3 del estado 12 esta esperando en 0x43D4 para dar la partida por cerrada.
; ----------------------------------------------------------------------
desfila_el_recuento:
	ld a,(0e003h)		;488d
	and 007h		;4890   ; uno de cada ocho fotogramas
	ret nz			;4892
	ld de,(0e05dh)		;4893   ; por donde va el desfile
	ld hl,0e05fh		;4897
	inc (hl)			;489a
	ld a,(hl)			;489b
	cp 00ah		;489c   ; a los diez pasos se cambia de sitio
	jr nz,L_48B6		;489e
	ld a,050h		;48a0
	call suma_a_a_de		;48a2   ; 0x50 mas abajo en la VRAM
	ld (0e05dh),de		;48a5
	ld (hl),001h		;48a9   ; y el contador vuelve a uno
	ld hl,0e060h		;48ab
	inc (hl)			;48ae
	ld a,(hl)			;48af
	cp 004h		;48b0   ; a la cuarta columna se acaba
	jr z,cierra_el_recuento		;48b2
	jr L_48BC		;48b4
L_48B6:
	inc de			;48b6   ; dentro de la misma columna se avanza de dos en dos
	inc de			;48b7
	ld (0e05dh),de		;48b8
L_48BC:
	ld hl,0e128h		;48bc
	call L_6F72		;48bf
	ld a,001h		;48c2
	call L_9C4A		;48c4   ; sonido 1 en cada paso: el tecleo del recuento
	ret			;48c7

; ----------------------------------------------------------------------
; Pone 0xE1A8 a cero de golpe, los ocho bits. Es la senal de "ya no queda nada pendiente" que espera el ultimo submodo del estado 12.
; ----------------------------------------------------------------------
cierra_el_recuento:
	ld hl,0e1a8h		;48c8
	ld (hl),000h		;48cb
	ret			;48cd

; ----------------------------------------------------------------------
; Pide numeros al azar a 0x4F2B hasta que sale uno que vale. Con 0xE208 por debajo de 4 devuelve 1 sin mas; si no, insiste hasta dar con uno que no pase de H. Es un bucle de rechazo, o sea que el tiempo que tarda depende de la suerte.
; ----------------------------------------------------------------------
saca_un_numero_menor_que_h:
	call saca_un_numero_al_azar		;48ce
	ld a,(0e208h)		;48d1
	cp 004h		;48d4   ; con menos de cuatro no se sortea nada
	jr c,L_48DE		;48d6
	inc a			;48d8
	cp h			;48d9
	jr c,saca_un_numero_menor_que_h		;48da   ; si se pasa de H, otro numero
	ld a,h			;48dc
	ret			;48dd
L_48DE:
	ld a,001h		;48de   ; por debajo de cuatro, siempre el 1
	ret			;48e0

; ----------------------------------------------------------------------
; SIEMBRA COMBINACIONES EN LA MANO YA REPARTIDA. Sin partida se va a 0x495C y copia la mano fija de la ROM. Con partida, y solo a partir de la tercera vez (0xE062), mete un TRIO en los huecos 0, 3 y 8 y luego una o dos ESCALERAS por 0x4918. Para el trio sortea tipos hasta dar con uno del que no haya ya dos copias.
; ----------------------------------------------------------------------
siembra_la_mano:
	ld a,(0e002h)		;48e1
	bit 6,a		;48e4   ; bit 6 de 0xE002: hay partida
	jr z,carga_la_mano_del_demo		;48e6   ; en el demo la mano no se sortea, se copia de la ROM
	ld a,(0e062h)		;48e8
	cp 003h		;48eb   ; las dos primeras manos van limpias
	ret c			;48ed
	call saca_un_numero_al_azar		;48ee
	ld a,h			;48f1
	cp 011h		;48f2   ; con este numero alto no se siembra trio, solo escaleras
	jr nc,siembra_una_o_dos_escaleras		;48f4
L_48F6:
	call saca_una_ficha_al_azar		;48f6   ; saca una ficha al azar
	call apunta_al_contador_del_tipo		;48f9   ; y mira cuantas copias hay ya de ese tipo
	ld a,(hl)			;48fc
	cp 002h		;48fd   ; con dos o mas ya repartidas, no cabe un trio: otra
	jr nc,L_48F6		;48ff
	inc (hl)			;4901   ; apunta las TRES copias de golpe
	inc (hl)			;4902
	inc (hl)			;4903
	ld hl,0e12ch		;4904   ; el primer hueco de la mano
	ld (hl),c			;4907
	ld a,003h		;4908
	call suma_a_a_hl		;490a   ; tres huecos mas alla
	ld (hl),c			;490d
	ld a,005h		;490e
	call suma_a_a_hl		;4910   ; y cinco mas: el trio queda repartido, no seguido
	ld (hl),c			;4913
	ld hl,0e063h		;4914
	inc (hl)			;4917   ; una mano mas sembrada

; ----------------------------------------------------------------------
; Siembra una escalera, o dos si 0xE063 es par: el `rra` saca el bit 0 y el `call nc` mete la primera solo cuando no hay acarreo, y luego la segunda va siempre. Al salir pone el contador a cero.
; ----------------------------------------------------------------------
siembra_una_o_dos_escaleras:
	ld hl,0e063h		;4918
	push hl			;491b
	ld a,(hl)			;491c
	rra			;491d   ; el bit 0 de la cuenta de manos sembradas
	call nc,siembra_una_escalera		;491e   ; con el bit a cero, dos escaleras en vez de una
	call siembra_una_escalera		;4921
	pop hl			;4924
	ld (hl),000h		;4925   ; y el contador vuelve a empezar
	ret			;4927

; ----------------------------------------------------------------------
; Mete tres fichas seguidas del mismo palo. Sortea hasta que le sale una que sirva, y para eso descarta dos cosas: los HONORES, que no forman escalera (codigo 0x31 o mas), y los numeros 7, 8 y 9, porque encima de ellos no caben dos mas. Ademas comprueba que de los tres tipos no haya ya cuatro copias repartidas, que son todas las que existen. Los tres huecos que ocupa son el 1, el 6 y el 11.
; ----------------------------------------------------------------------
siembra_una_escalera:
	call saca_una_ficha_al_azar		;4928
	ld a,b			;492b
	cp 030h		;492c   ; codigo 0x30 o mas: es un honor, no forma escalera
	jr nc,siembra_una_escalera		;492e
	and 00fh		;4930   ; el numero dentro del palo
	cp 007h		;4932   ; del 7 para arriba no caben dos fichas encima
	jr nc,siembra_una_escalera		;4934
	call apunta_al_contador_del_tipo		;4936   ; los contadores de los tres tipos seguidos
	ld b,003h		;4939   ; la ficha y las dos de encima
L_493B:
	ld a,(hl)			;493b
	cp 004h		;493c   ; cuatro copias ya repartidas: no queda ninguna, otra escalera
	jr nc,siembra_una_escalera		;493e
	inc hl			;4940
	djnz L_493B		;4941
	ex de,hl			;4943
	inc (hl)			;4944   ; apunta las tres
	inc hl			;4945
	inc (hl)			;4946
	inc hl			;4947
	inc (hl)			;4948
	ld hl,0e12dh		;4949   ; el segundo hueco de la mano
	ld (hl),c			;494c
	ld a,005h		;494d
	call suma_a_a_hl		;494f   ; cinco mas alla, y la ficha siguiente
	inc c			;4952
	ld (hl),c			;4953
	ld a,005h		;4954
	call suma_a_a_hl		;4956   ; y otros cinco, con la tercera
	inc c			;4959
	ld (hl),c			;495a
	ret			;495b

; ----------------------------------------------------------------------
; Copia los catorce codigos de 0x4968 a 0xE12C. Es lo que hace el demo en lugar de repartir, y por eso el attract juega siempre la misma mano.
; ----------------------------------------------------------------------
carga_la_mano_del_demo:
	ld hl,04968h		;495c
	ld de,0e12ch		;495f
	ld bc,0000eh		;4962   ; catorce fichas
	ldir		;4965
	ret			;4967

; ----------------------------------------------------------------------
; DATOS mano_de_ejemplo: Catorce codigos de ficha validos, uno por hueco de la
;   mano, que 0x495C carga de golpe. Es una mano fija metida en la ROM.
;   0x4968..0x4976  (14 bytes)
DATA_mano_de_ejemplo:
	defb 017h,015h,009h,031h,013h,008h,022h,011h,006h,031h,022h,033h,008h,002h	; 4968  ...1.."..1"3..

; ======================================================================
; CODIGO 0x4976..0x49a6  (48 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; Devuelve una ficha al azar: pide un numero a 0x4F2B, se queda con H como INDICE de 0 a 33 y lo pasa por la tabla de 0x4FBF para sacar el CODIGO, con el palo en el nibble alto y el numero en el bajo. Sale con C = el indice y B = el codigo. Los dos hacen falta: el indice para contar copias en 0xE186 y el codigo para saber si es honor o que numero lleva.
; ----------------------------------------------------------------------
saca_una_ficha_al_azar:
	call saca_un_numero_al_azar		;4976
	ld a,h			;4979   ; el indice, de 0 a 33
	ld c,a			;497a
	ld de,04fbfh		;497b   ; la tabla de los 34 tipos de ficha
	call suma_a_a_de		;497e
	ld a,(de)			;4981   ; y el codigo que le corresponde
	ld b,a			;4982
	ret			;4983

; ----------------------------------------------------------------------
; Deja HL y DE apuntando al contador de copias del tipo que hay en C, dentro de la tabla de 0xE186. Ahi se lleva la cuenta de cuantas de cada tipo se han repartido ya, y por eso el sembrado puede comprobar que no se pasa de cuatro.
; ----------------------------------------------------------------------
apunta_al_contador_del_tipo:
	ld a,c			;4984
	ld c,b			;4985
	ld hl,0e186h		;4986   ; la tabla de copias repartidas por tipo
	call suma_a_a_hl		;4989
	ld d,h			;498c
	ld e,l			;498d
	ret			;498e

; ----------------------------------------------------------------------
; Saca la ficha siguiente del muro y adelanta el puntero. Hay DOS punteros, 0xE06A y 0xE06C, y el bit 0 de 0xE206 dice cual toca: son los dos extremos por los que se roba. Adelanta el puntero primero y devuelve la ficha de la posicion anterior.
; ----------------------------------------------------------------------
saca_del_muro:
	ld a,(0e206h)		;498f
	rra			;4992   ; bit 0 de 0xE206: por que extremo se roba
	ld hl,0e06ah		;4993
	jr nc,L_499B		;4996
	ld hl,0e06ch		;4998
L_499B:
	ld e,(hl)			;499b
	inc hl			;499c
	ld d,(hl)			;499d
	inc de			;499e   ; adelanta el puntero antes de leer nada
	ld (hl),d			;499f
	dec hl			;49a0
	ld (hl),e			;49a1
	dec de			;49a2   ; y lee de donde estaba
	ex de,hl			;49a3
	ld a,(hl)			;49a4
	ret			;49a5

; ----------------------------------------------------------------------
; DATOS dos_repartos_fijos: Dos tiras de quince codigos de ficha: 0x4171
;   guarda la primera en 0xE06A y 0x4177 la segunda en 0xE06C, las dos al
;   entrar en el estado 7.
;   0x49a6..0x49c6  (32 bytes)
DATA_dos_repartos_fijos:
	defb 001h,023h,007h,036h,035h,033h,015h,004h,012h,007h,011h,021h,035h,015h,005h,024h	; 49a6  .#.653.....!5..$
	defb 016h,002h,034h,035h,031h,021h,025h,014h,001h,003h,018h,023h,034h,029h,014h,014h	; 49b6  ..451!%....#4)..

; ======================================================================
; CODIGO 0x49c6..0x4a1a  (84 bytes)
; ======================================================================


L_49C6:
	ld c,a			;49c6
	ld a,(0e040h)		;49c7
	rra			;49ca
	ret nc			;49cb
	ld a,(0e1cdh)		;49cc
	rra			;49cf
	ret nc			;49d0
	ld a,c			;49d1
	ld hl,0e1f5h		;49d2
	ld b,00dh		;49d5
L_49D7:
	inc (hl)			;49d7
	dec (hl)			;49d8
	jr z,L_49E1		;49d9
	cp (hl)			;49db
	jr z,L_49E3		;49dc
	inc hl			;49de
	djnz L_49D7		;49df
L_49E1:
	or a			;49e1
	ret			;49e2
L_49E3:
	scf			;49e3
	ret			;49e4

; ----------------------------------------------------------------------
; Enciende la maquina: apaga la lampara de CAPS, calla el PSG, para el sonido del juego y borra los 16 KB de VRAM de un tiron. Cae por abajo en 0x49FE, que carga los registros del VDP.
; ----------------------------------------------------------------------
arranca_el_hardware:
	call 00132h		;49e5   ; BIOS CHGCAP - Alternates the CAPS lamp status | CHGCAP apaga la lampara de bloqueo de mayusculas
	ld a,007h		;49e8   ; registro 7 del PSG: todos los canales callados
	ld e,0b8h		;49ea
	call 00093h		;49ec   ; BIOS WRTPSG - Writes data to PSG-register
	ld a,09fh		;49ef   ; 0x9F para el sonido que estuviera sonando
	call L_9C4A		;49f1
	ld de,00000h		;49f4   ; borra la VRAM entera, 0x0000 a 0x3FFF, con ceros
	ld bc,04000h		;49f7
	xor a			;49fa
	call rellena_la_vram		;49fb

; ----------------------------------------------------------------------
; Copia los ocho registros del VDP a la RAM (0xE038) y luego los escribe uno a uno. Se pasan por RAM para poder retocar uno solo sin volver a la tabla; 0x4A09 es la entrada de los que ya lo han retocado.
; ----------------------------------------------------------------------
carga_los_registros_del_vdp:
	ld hl,04a1ah		;49fe
	ld de,0e038h		;4a01
	ld bc,00008h		;4a04
	ldir		;4a07
L_4A09:
	ld hl,0e038h		;4a09   ; entra aqui quien solo quiere reescribirlos
	ld d,008h		;4a0c
	ld c,000h		;4a0e
L_4A10:
	ld b,(hl)			;4a10
	call 00047h		;4a11   ; BIOS WRTVDP - Writes data in the VDP-register
	inc hl			;4a14
	inc c			;4a15
	dec d			;4a16
	jr nz,L_4A10		;4a17
	ret			;4a19

; ----------------------------------------------------------------------
; DATOS registros_del_vdp: Los ocho registros del VDP. 0x49FE los copia a
;   0xE038 y 0x4A10 los escribe uno a uno con WRTVDP subiendo C de 0 a 7:
;   R0=0x02, R1=0xE2, R2=0x0E, R3=0x7F, R4=0x07, R5=0x76, R6=0x03, R7=0xE1.
;   0x4a1a..0x4a22  (8 bytes)
DATA_registros_del_vdp:
	defb 002h,0e2h,00eh,07fh,007h,076h,003h,0e1h	; 4a1a  .....v..

; ======================================================================
; CODIGO 0x4a22..0x4ae0  (190 bytes)
; ======================================================================


L_4A22:
	ld (0e03fh),a		;4a22
	jr $-28		;4a25

; ----------------------------------------------------------------------
; De donde salen las teclas cada fotograma, y el bit 6 de 0xE002 decide de cual de los dos sitios: si hay partida, de la matriz del teclado de verdad; si no, del guion grabado del demo. Las dos ramas terminan en 0x4A52 con la misma mascara en A: bit 0 arriba, bit 1 abajo, bit 2 izquierda, bit 3 derecha, bit 4 espacio, bit 5 select.
; ----------------------------------------------------------------------
lee_los_mandos:
	ld a,(0e002h)		;4a27
	bit 6,a		;4a2a   ; bit 6: hay una persona jugando
	jr z,sirve_el_guion_del_demo		;4a2c   ; sin partida, las teclas salen del guion del demo
	ld a,007h		;4a2e
	call 00141h		;4a30   ; BIOS SNSMAT - Returns the value of the specified line from the keyboard matrix | fila 7 de la matriz, de donde sale SELECT
	cpl			;4a33   ; la matriz da los ceros como pulsados: se le da la vuelta
	rrca			;4a34
	and 020h		;4a35   ; SELECT queda en el bit 5
	ld e,a			;4a37
	ld a,008h		;4a38
	call 00141h		;4a3a   ; BIOS SNSMAT - Returns the value of the specified line from the keyboard matrix | fila 8: las cuatro flechas y el espacio
	cpl			;4a3d
	rrca			;4a3e
	rrca			;4a3f
	ld b,a			;4a40
	and 004h		;4a41   ; izquierda al bit 2
	or e			;4a43
	ld c,a			;4a44
	ld a,b			;4a45
	rrca			;4a46
	rrca			;4a47
	ld b,a			;4a48
	and 018h		;4a49   ; derecha al bit 3 y espacio al bit 4
	or c			;4a4b
	ld c,a			;4a4c
	ld a,b			;4a4d
	rrca			;4a4e
	and 003h		;4a4f   ; arriba al bit 0 y abajo al bit 1
	or c			;4a51

; ----------------------------------------------------------------------
; Guarda la mascara de teclas de este fotograma en 0xE009 y empuja la anterior a 0xE008. Con las dos se saca el FLANCO del espacio: 0xE23A vale 1 solo el fotograma en que se acaba de pulsar, no mientras se mantiene.
; ----------------------------------------------------------------------
guarda_las_teclas:
	ld hl,0e009h		;4a52
	ld c,(hl)			;4a55   ; la de antes pasa a 0xE008
	ld (hl),a			;4a56
	dec hl			;4a57
	ld (hl),c			;4a58
	and 010h		;4a59   ; el bit 4, el espacio
	jr z,L_4A64		;4a5b
	ld b,a			;4a5d
	and c			;4a5e   ; si ya estaba pulsado el fotograma anterior, no cuenta
	xor b			;4a5f
	jr z,L_4A64		;4a60
	ld a,001h		;4a62
L_4A64:
	ld (0e23ah),a		;4a64   ; 1 = el espacio se acaba de pulsar AHORA
	ret			;4a67

; ----------------------------------------------------------------------
; Sirve la pulsacion siguiente del guion grabado en 0x4AE8, y por eso el demo sale igual cada vez. Formato de longitud variable: el nibble bajo de la entrada dice si ocupa uno o dos bytes. Con nibble bajo cero la entrada dura 64 fotogramas y ocupa un byte; con nibble bajo no cero ocupa dos y el segundo es cuantas veces seguidas se repite. 0xE066 es el puntero, 0xE068 el contador de los 64 y 0xE069 lo que queda de repeticion.
; ----------------------------------------------------------------------
sirve_el_guion_del_demo:
	ld a,(0e1a8h)		;4a68
	bit 1,a		;4a6b   ; bit 1 de 0xE1A8: sin el, el demo no toca ninguna tecla
	jr z,L_4AB9		;4a6d
	ld de,(0e066h)		;4a6f   ; donde va el guion
	ld a,(de)			;4a73
	ld c,00fh		;4a74
	and 00fh		;4a76   ; el nibble bajo decide el formato de la entrada
	jr z,L_4AA8		;4a78   ; nibble bajo cero: entrada de un solo byte
	ld a,(0e069h)		;4a7a   ; si no queda repeticion en curso, se carga la cuenta
	or a			;4a7d
	jr nz,L_4A86		;4a7e
	inc de			;4a80
	ld a,(de)			;4a81   ; el segundo byte es cuantas veces
	ld (0e069h),a		;4a82
	dec de			;4a85
L_4A86:
	ld a,(de)			;4a86
	and 00ch		;4a87   ; las teclas de los bits 2 y 3 no esperan a los 64 fotogramas
	jr nz,L_4A94		;4a89
	ld hl,0e068h		;4a8b
	inc (hl)			;4a8e   ; sube el contador de 64
	ld a,(hl)			;4a8f
	and 03fh		;4a90   ; y hasta que no da la vuelta, no hay tecla
	jr nz,L_4AB9		;4a92
L_4A94:
	ld a,(0e069h)		;4a94
	dec a			;4a97   ; gasta una repeticion
	ld (0e069h),a		;4a98
	jr nz,L_4AA5		;4a9b
	inc de			;4a9d   ; agotada la cuenta, la entrada de dos bytes queda atras
	inc de			;4a9e
	ld (0e066h),de		;4a9f
	dec de			;4aa3
	dec de			;4aa4
L_4AA5:
	ld a,(de)			;4aa5   ; la tecla que se sirve este fotograma
	jr guarda_las_teclas		;4aa6
L_4AA8:
	ld hl,0e068h		;4aa8
	inc (hl)			;4aab
	ld a,(hl)			;4aac
	and 03fh		;4aad
	jr nz,L_4AB9		;4aaf
	ld a,(de)			;4ab1
	inc de			;4ab2   ; la entrada de un byte se pasa de largo con un inc
	ld (0e066h),de		;4ab3
	jr guarda_las_teclas		;4ab7
L_4AB9:
	xor a			;4ab9   ; fuera del guion no se toca ninguna tecla
	jr guarda_las_teclas		;4aba

; ----------------------------------------------------------------------
; LA PUERTA DE ENTRADA AL JUEGO DE VERDAD. Solo se llama mientras corre el demo (0x40CA elige entre esta y un ret pelado segun el bit 6 de 0xE002). Mira la fila 0 del teclado: las teclas 1, 2 y 3 arrancan partida, cada una con su dificultad, y saltan al estado 8. La tecla 4 cae en una entrada vacia de la tabla y no hace nada.
; ----------------------------------------------------------------------
arranca_la_partida:
	xor a			;4abc   ; fila 0 de la matriz: las teclas 0 a 7
	call 00141h		;4abd   ; BIOS SNSMAT - Returns the value of the specified line from the keyboard matrix
	cpl			;4ac0
	and 01eh		;4ac1   ; solo interesan las teclas 1, 2, 3 y 4
	rra			;4ac3   ; las baja a indice 0-7
	dec a			;4ac4
	cp 008h		;4ac5   ; si hay varias pulsadas a la vez el indice se dispara: fuera
	ret nc			;4ac7
	ld hl,04ae0h		;4ac8
	call suma_a_a_hl		;4acb   ; la tabla que traduce tecla a dificultad
	ld a,(hl)			;4ace
	or a			;4acf
	ret z			;4ad0   ; la entrada vacia: esa tecla no arranca nada
	ld (0e002h),a		;4ad1   ; EL BYTE DE LA PARTIDA: bit 6 encendido, mas la dificultad en 5 y 4
	ld hl,00008h		;4ad4   ; estado 8 y submodo 0 de una tacada, que son bytes contiguos
	ld (0e000h),hl		;4ad7
	ld a,09fh		;4ada   ; y calla el sonido del demo
	call L_9C4A		;4adc
	ret			;4adf

; ----------------------------------------------------------------------
; DATOS tabla_de_dificultad: Ocho bytes, 0x40 0x60 0x00 0x50 y cuatro ceros,
;   que 0x4ACC indexa con la tecla de la fila 0 del teclado ya reducida a 0-7
;   (`and 0x1E` deja las teclas 1 a 4, `rra` las divide por dos y `dec a` las
;   baja a indice). ESTA TABLA ES LA QUE ARRANCA LA PARTIDA: el valor que sale
;   va a 0xE002, y su bit 6 es lo que distingue partida de demo en 0x40CA y en
;   0x4A27. Indice 0 (tecla 1) = 0x40, indice 1 (tecla 2) = 0x60, indice 3
;   (tecla 3) = 0x50; los bits 5 y 4 son la DIFICULTAD (ninguno, bit 5, bit
;   4), las tres que el titulo rotula AMACHUA, SEMIPROFESSIONAL y
;   PROFESSIONAL. La tecla 4 cae en el indice 7, que vale cero: no hace nada.
;   0x4ae0..0x4ae8  (8 bytes)
DATA_tabla_de_dificultad:
	defb 040h,060h,000h,050h,000h,000h,000h,000h	; 4ae0  @`.P....

; ----------------------------------------------------------------------
; DATOS guion_del_demo: EL DEMO NO PIENSA: LEE ESTE GUION. Ciento cuatro bytes
;   que 0x416B guarda en 0xE066 al entrar en el estado 7 y que 0x4A68 va
;   sirviendo en lugar del teclado mientras el bit 6 de 0xE002 este a cero.
;   Por eso el demo es determinista al centesimo desde el encendido (medido:
;   dos pasadas independientes, ver docs/la_partida.md). Los valores son las
;   MISMAS mascaras que arma 0x4A27 leyendo la matriz: bit 0 arriba, bit 1
;   abajo, bit 2 izquierda, bit 3 derecha, bit 4 espacio, bit 5 select. El
;   formato es de longitud variable y lo decide el nibble bajo: si es cero
;   (0x00, 0x10, 0x20, 0x30) la entrada ocupa UN byte y se sirve una vez cada
;   64 fotogramas; si no (0x01, 0x02, 0x04, 0x08, 0x18, 0x38) ocupa DOS y el
;   segundo es cuantas veces seguidas se repite. Los ocho ceros del final son
;   el guion agotado: tecla ninguna para siempre.
;   0x4ae8..0x4b50  (104 bytes)
DATA_guion_del_demo:
	defb 000h,008h,030h,010h,000h,010h,000h,008h,030h,010h,000h,010h,000h,004h,030h,010h	; 4ae8  ..0.....0.....0.
	defb 000h,010h,000h,004h,038h,010h,000h,010h,010h,000h,010h,010h,000h,002h,002h,020h	; 4af8  ....8.......... 
	defb 000h,004h,008h,010h,000h,010h,000h,004h,010h,010h,000h,010h,010h,000h,010h,000h	; 4b08  ................
	defb 004h,018h,010h,000h,010h,010h,000h,002h,001h,020h,000h,008h,010h,000h,004h,010h	; 4b18  ......... ......
	defb 000h,008h,010h,000h,004h,010h,010h,000h,004h,018h,010h,000h,010h,010h,000h,010h	; 4b28  ................
	defb 010h,000h,010h,010h,000h,010h,010h,000h,010h,010h,000h,010h,000h,002h,002h,020h	; 4b38  ............... 
	defb 000h,000h,000h,000h,000h,000h,000h,000h	; 4b48  ........

; ======================================================================
; CODIGO 0x4b50..0x4bb0  (96 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; Prepara la caida del rotulo del principio: diecisiete pasos en 0xE00A, la altura a cero en 0xE00E, los colores del bloque de 0x4BB0 descomprimidos en 0x2200 y los patrones de al lado rellenos a 0xF0. Cada paso lo da 0x4B75.
; ----------------------------------------------------------------------
monta_el_rotulo_que_baja:
	ld a,011h		;4b50   ; diecisiete pasos de caida
	ld (0e00ah),a		;4b52
	ld hl,00000h		;4b55   ; y empieza arriba del todo
	ld (0e00eh),hl		;4b58
	ld hl,04bb0h		;4b5b   ; los colores, en formato B sin cabecera de destino
	ld de,06200h		;4b5e
	call L_4693		;4b61
	ld de,00200h		;4b64   ; y los patrones del mismo tercio, con el byte fijo 0xF0
	ld bc,000d0h		;4b67
	ld a,0f0h		;4b6a
	call rellena_la_vram		;4b6c
	call L_4658		;4b6f
	jp L_4669		;4b72

; ----------------------------------------------------------------------
; Baja el rotulo una fila: sube 0x20 la altura de 0xE00E, la resta de 0x3AAA para saber donde toca pintar -o sea que cuanto mas ha bajado, mas arriba empieza- y suelta tres tiras de tiles consecutivos con 0x4BA1. Detras borra lo que dejo la fila anterior. Devuelve el paso que queda en 0xE00A, y el estado 1 lo mira para saber cuando parar.
; ----------------------------------------------------------------------
baja_el_rotulo_un_paso:
	ld hl,(0e00eh)		;4b75
	ld de,00020h		;4b78   ; una fila entera de la pantalla
	add hl,de			;4b7b
	ld (0e00eh),hl		;4b7c
	ex de,hl			;4b7f
	or a			;4b80
	ld hl,03aaah		;4b81   ; desde abajo hacia arriba
	sbc hl,de		;4b84
	ex de,hl			;4b86
	ld a,040h		;4b87   ; los tiles del rotulo empiezan en el 0x40
	ld b,003h		;4b89   ; tres celdas la primera tira
	call pinta_una_tira_de_tiles		;4b8b
	ld bc,00b0ch		;4b8e   ; doce celdas la segunda
	call pinta_una_tira_de_tiles		;4b91
	ld b,c			;4b94
	call pinta_una_tira_de_tiles		;4b95
	xor a			;4b98
	call rellena_la_vram		;4b99   ; y detras, a borrar lo de antes
	ld hl,0e00ah		;4b9c
	dec (hl)			;4b9f   ; un paso menos
	ret			;4ba0

; ----------------------------------------------------------------------
; Pinta B celdas seguidas con tiles que van subiendo de uno en uno desde A, y deja DE una fila mas abajo. Es el ladrillo con el que 0x4B75 construye el rotulo.
; ----------------------------------------------------------------------
pinta_una_tira_de_tiles:
	push de			;4ba1
L_4BA2:
	call escribe_en_vram		;4ba2
	inc de			;4ba5
	inc a			;4ba6   ; el tile siguiente
	djnz L_4BA2		;4ba7
	pop de			;4ba9
	ld hl,00020h		;4baa   ; y al terminar, una fila mas abajo
	add hl,de			;4bad
	ex de,hl			;4bae
	ret			;4baf

; ----------------------------------------------------------------------
; DATOS colores_del_menu_200: Formato B SIN cabecera de destino: 0x4B5B llama
;   a la entrada 0x4693 (tres bytes dentro de 0x468F, saltandose el `ld
;   e,(hl)/ld d,(hl)` que lee el destino) con DE=0x6200 puesto a mano, o sea
;   que este bloque son solo ORDENES, sin los dos bytes de VRAM delante.
;   Descomprime a 208 bytes en los colores 0x2200. Justo detras, 0x4B64
;   rellena los patrones 0x0200 con el byte fijo 0xF0 repetido 208 veces (`ld
;   de,0x0200 / ld bc,0xD0 / ld a,0xF0 / call 0x45F6`): mismo tercio, mismo
;   tamano, patron solido en vez de comprimido.
;   0x4bb0..0x4c43  (147 bytes)
DATA_colores_del_menu_200:
	defb 00eh,000h,082h,007h,00fh,006h,000h,082h,0f8h,0f0h,004h,03eh,004h,03fh,090h,01fh	; 4bb0  ...........>.?..
	defb 03fh,07fh,0ffh,0feh,0fch,0f8h,0f0h,0e0h,0c0h,080h,000h,000h,000h,03eh,03eh,005h	; 4bc0  ?............>>.
	defb 000h,083h,01fh,07fh,0fbh,005h,000h,083h,00fh,0cfh,0efh,005h,000h,083h,078h,0fch	; 4bd0  ..............x.
	defb 0bch,005h,000h,083h,03fh,07fh,0f3h,005h,000h,083h,087h,0c7h,0c7h,005h,000h,083h	; 4be0  ....?...........
	defb 0bch,0feh,0dfh,005h,000h,08dh,078h,0fch,0bch,060h,0f0h,0f0h,060h,000h,0f0h,0f0h	; 4bf0  ......x..`..`...
	defb 0f0h,03fh,03fh,006h,03eh,090h,0f8h,0fch,0feh,07fh,03fh,01fh,00fh,007h,03eh,03eh	; 4c00  .??.>.....?...>>
	defb 03eh,07eh,0fch,0fch,0f8h,0e0h,005h,0f1h,083h,0fbh,07fh,01fh,006h,0efh,082h,0cfh	; 4c10  >~..............
	defb 00fh,008h,01eh,088h,0e1h,003h,03fh,0f1h,0e1h,0f3h,07fh,01eh,008h,0e7h,008h,08fh	; 4c20  ......?.........
	defb 008h,01eh,082h,0f1h,0f2h,004h,0f5h,08ah,0f2h,0f1h,0e0h,010h,0c8h,068h,0c8h,028h	; 4c30  .............h.(
	defb 010h,0e0h,000h	; 4c40

; ======================================================================
; CODIGO 0x4c43..0x4ce4  (161 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; EL MARCADOR DE SALIDA: 30.000 puntos para cada uno. Escribe 0x0300 en 0xE045 y en 0xE048, que son los bytes medio y alto de los dos contadores BCD; el bajo ya estaba a cero. Cuadra con lo medido en los volcados del paso 2, que daban 030000 y 030000 nada mas empezar. Lo llama el estado 9.
; ----------------------------------------------------------------------
pone_los_marcadores_a_30000:
	ld hl,00300h		;4c43   ; 0x0300 en BCD son 30.000 con el byte bajo a cero
	ld (0e045h),hl		;4c46   ; el marcador de 0xE044
	ld (0e048h),hl		;4c49   ; y el de 0xE047
	call limpia_y_pinta_los_ceros		;4c4c   ; limpia y pinta los ceros
	ld a,0f1h		;4c4f
	call L_4676		;4c51
	ld a,00ch		;4c54
	jp L_4A22		;4c56

; ----------------------------------------------------------------------
; Deja la mesa lista para jugar: borra 398 bytes de variables desde 0xE127, pinta la barra y la mano, y decide si hay que enseñar alguno de los dos rotulos cortos. El primero sale con 0xE04B en cinco o mas, el segundo cuando 0xE04C y 0xE04D comparten algun bit; cada uno deja su marca en los bits 0 y 1 de 0xE127, y segun cual sea suena 3 o 12.
; ----------------------------------------------------------------------
monta_la_mano:
	ld hl,0e127h		;4c59
	ld de,0e128h		;4c5c
	ld bc,0018eh		;4c5f   ; 398 bytes de variables de la mano
	ld (hl),000h		;4c62
	ldir		;4c64
	call L_6FC1		;4c66
	call pinta_la_barra_de_arriba		;4c69
	call L_5A67		;4c6c
	xor a			;4c6f
	ld (0e127h),a		;4c70
	ld a,(0e04bh)		;4c73
	cp 005h		;4c76   ; de cinco para arriba sale el primer rotulo
	jr c,L_4C85		;4c78
	ld hl,04ce4h		;4c7a
	call L_409D		;4c7d
	ld hl,0e127h		;4c80
	ld (hl),001h		;4c83   ; y se apunta que ha salido
L_4C85:
	ld a,(0e04ch)		;4c85
	ld c,a			;4c88
	ld a,(0e04dh)		;4c89
	and c			;4c8c   ; los dos bytes tienen que compartir algun bit
	jr z,L_4C9A		;4c8d
	ld hl,04cebh		;4c8f
	call L_409D		;4c92
	ld hl,0e127h		;4c95
	set 1,(hl)		;4c98   ; la marca del segundo rotulo
L_4C9A:
	ld a,(0e127h)		;4c9a
	and 003h		;4c9d   ; ninguno de los dos: no suena nada
	jr z,L_4CAF		;4c9f
	rra			;4ca1
	ld a,003h		;4ca2   ; sonido 3 para uno
	jr nc,L_4CA8		;4ca4
	ld a,00ch		;4ca6   ; y sonido 12 para el otro
L_4CA8:
	call L_9C4A		;4ca8
	xor a			;4cab
	ld (0e127h),a		;4cac   ; la marca se gasta al sonar
L_4CAF:
	ld hl,04cf2h		;4caf
	call pinta_lista_formato_b		;4cb2
	jp L_6FDF		;4cb5

; ----------------------------------------------------------------------
; Repinta la barra de arriba entera: la limpia con el tile 1, suelta los dos marcadores con su signo, el rotulo de tres trozos y el contador de 0xE04A, y remata con el rotulo de la DIFICULTAD, que elige entre tres listas mirando los bits 0 y 1 de 0xE040. Con la tecla 1 sale 0x4D36, con la 3 sale 0x4D3E y con la 2 la tercera, 0x4D47.
; ----------------------------------------------------------------------
pinta_la_barra_de_arriba:
	ld a,001h		;4cb8   ; el tile 1 es el blanco
	ld de,03920h		;4cba   ; 192 celdas: las seis filas de la barra
	ld bc,000c0h		;4cbd
	call rellena_la_vram		;4cc0
	call L_44E4		;4cc3   ; los dos marcadores con su signo
	ld hl,04d24h		;4cc6
	call L_409D		;4cc9
	call pinta_el_contador_de_e04a		;4ccc   ; y el contador de 0xE04A
	ld a,(0e040h)		;4ccf   ; LA DIFICULTAD, tal como la dejo la pantalla del estado 8
	rra			;4cd2   ; bit 0: la tecla 1
	ld hl,04d36h		;4cd3
	jr c,L_4CE1		;4cd6
	rra			;4cd8   ; bit 1: la tecla 3
	ld hl,04d3eh		;4cd9
	jr c,L_4CE1		;4cdc
	ld hl,04d47h		;4cde   ; y si no es ninguno de los dos, la tecla 2
L_4CE1:
	jp L_409D		;4ce1

; ----------------------------------------------------------------------
; DATOS rotulo_corto_1: Formato A desde 0x4C7D: cuatro tiles en la fila 16,
;   columna 23.
;   0x4ce4..0x4ceb  (7 bytes)
DATA_rotulo_corto_1:
	defb 037h,03ah,008h,009h,00ah,00bh,0ffh	; 4ce4

; ----------------------------------------------------------------------
; DATOS rotulo_corto_2: Formato A desde 0x4C92: cuatro tiles en la fila 16,
;   columna 23 de la linea de arriba.
;   0x4ceb..0x4cf2  (7 bytes)
DATA_rotulo_corto_2:
	defb 017h,03ah,004h,005h,006h,007h,0ffh	; 4ceb

; ----------------------------------------------------------------------
; DATOS dibujo_de_seis_filas: Formato B desde 0x4CB2: seis destinos entre las
;   filas 9 y 14, por la parte derecha de la pantalla.
;   0x4cf2..0x4d24  (50 bytes)
DATA_dibujo_de_seis_filas:
	defb 03ah,079h,006h,002h,080h,059h,079h,087h,0eah,0fch,0fdh,0e4h,0f6h,002h,002h,080h	; 4cf2  :y...Yy.........
	defb 07ah,079h,083h,0f6h,0ebh,0f1h,003h,002h,080h,09ah,079h,083h,0f7h,0e5h,0f0h,003h	; 4d02  zy........y.....
	defb 002h,080h,0bah,079h,082h,0f1h,0ebh,004h,002h,080h,0dah,079h,082h,0fdh,0f0h,004h	; 4d12  ...y.......y....
	defb 002h,000h	; 4d22

; ----------------------------------------------------------------------
; DATOS rotulo_de_tres_trozos: Formato A desde 0x4CC9: tres destinos en las
;   filas 11, 12 y 13.
;   0x4d24..0x4d36  (18 bytes)
DATA_rotulo_de_tres_trozos:
	defb 068h,039h,072h,0feh,082h,039h,042h,043h,048h,001h,001h,073h,078h,0feh,0a8h,039h	; 4d24  h9r..9BCH..sx..9
	defb 079h,0ffh	; 4d34

; ----------------------------------------------------------------------
; DATOS marca_a: Formato A desde 0x4CD3: un tile en la fila 11 y otro en la
;   fila 13, columna 23.
;   0x4d36..0x4d3e  (8 bytes)
DATA_marca_a:
	defb 077h,039h,02ah,0feh,0b7h,039h,02bh,0ffh	; 4d36  w9*..9+.

; ----------------------------------------------------------------------
; DATOS marca_b: Formato A desde 0x4CD9: lo mismo con otros tiles.
;   0x4d3e..0x4d47  (9 bytes)
DATA_marca_b:
	defb 077h,039h,030h,03dh,0feh,0b7h,039h,031h,0ffh	; 4d3e  w90=..91.

; ----------------------------------------------------------------------
; DATOS marca_c: Formato A desde 0x4CE1: cuatro destinos, filas 10 a 13.
;   0x4d47..0x4d58  (17 bytes)
DATA_marca_c:
	defb 057h,039h,036h,0feh,077h,039h,037h,0feh,097h,039h,030h,03dh,0feh,0b7h,039h,031h	; 4d47  W96.w97..90=..91
	defb 0ffh	; 4d57

; ======================================================================
; CODIGO 0x4d58..0x4fb1  (601 bytes)
; ======================================================================


L_4D58:
	call despacha_el_reparto		;4d58
	call L_6F2E		;4d5b
	call L_6F3E		;4d5e
	ld a,(0e1a8h)		;4d61
	rra			;4d64
	ret c			;4d65
	ld hl,0e21ch		;4d66
	ld de,0e14ch		;4d69
	ld bc,0000eh		;4d6c
	ldir		;4d6f
	ret			;4d71

; ----------------------------------------------------------------------
; Deja la mesa a cero para una mano nueva: borra los 34 contadores de copias por tipo, apunta 0xE054 al principio de la mano y guarda en 0xE1B7 de quien es el turno, con el contrario en 0xE33F.
; ----------------------------------------------------------------------
prepara_el_reparto:
	ld hl,0e186h		;4d72   ; los 34 contadores, uno por tipo de ficha
	ld de,0e187h		;4d75
	ld bc,00021h		;4d78
	ld (hl),000h		;4d7b   ; a cero: no hay ninguna repartida
	ldir		;4d7d
	ld hl,0e21ch		;4d7f   ; donde empieza la mano
	ld (0e054h),hl		;4d82
	ld a,(0e04dh)		;4d85
	ld (0e1b7h),a		;4d88   ; de quien es el turno
	xor 001h		;4d8b   ; y el contrario, que es el otro jugador
	ld (0e33fh),a		;4d8d
	ret			;4d90

; ----------------------------------------------------------------------
; Reparte por fases, una por bit de 0xE1A9: los `rra` encadenados van bajando bits y el primero que este a cero manda. Sin ningun bit puesto se empieza por 0x4DA6, que es el reparto inicial.
; ----------------------------------------------------------------------
despacha_el_reparto:
	ld a,(0e1a9h)		;4d91
	rra			;4d94   ; bit 0: aun no ha empezado el reparto
	jr nc,reparte_la_mano		;4d95
	rra			;4d97   ; bit 1
	jp nc,reparte_una_tanda		;4d98
	rra			;4d9b   ; bit 2
	jp nc,borra_la_mano_de_trabajo		;4d9c
	rra			;4d9f   ; bit 3
	jp nc,ensena_la_mano_ficha_a_ficha		;4da0
	jp c,cierra_el_reparto		;4da3

; ----------------------------------------------------------------------
; EL REPARTO INICIAL. Copia catorce fichas a 0xE32B, deja los dos contadores de mano en trece, saca las trece de 0xE12C una a una con 0x4F64 y remata con la catorce en 0xE139. Y en cuanto termina llama a 0x48E1, que puede sembrarle un trio y una o dos escaleras encima de lo repartido.
; ----------------------------------------------------------------------
reparte_la_mano:
	call L_78CE		;4da6
	ld hl,0e21ch		;4da9
	ld de,0e32bh		;4dac
	ld bc,0000eh		;4daf   ; catorce fichas
	ldir		;4db2
	ld a,00dh		;4db4   ; trece en la mano, la catorce va aparte
	ld (0e209h),a		;4db6
	ld (0e20ah),a		;4db9
	ld a,001h		;4dbc
	ld (0e206h),a		;4dbe   ; por que extremo se empieza a robar
	call L_66E7		;4dc1
	xor a			;4dc4
	ld (0e1cdh),a		;4dc5
	ld (0e302h),a		;4dc8
	ld (0e205h),a		;4dcb
	ld b,00dh		;4dce   ; trece fichas, una a una
L_4DD0:
	call reparte_una_ficha		;4dd0   ; la ficha siguiente
	ld a,b			;4dd3
	dec a			;4dd4
	ld de,0e12ch		;4dd5   ; y a su hueco de la mano
	call suma_a_a_de		;4dd8
	ld a,(hl)			;4ddb
	ld (de),a			;4ddc
	djnz L_4DD0		;4ddd
	ld a,(0e04dh)		;4ddf
	rra			;4de2
	ld a,039h		;4de3   ; 0x39, que no es un codigo de ficha valido: el hueco vacio
	jr c,L_4DEA		;4de5
	call reparte_una_ficha		;4de7   ; y si no, una ficha de verdad
L_4DEA:
	ld (0e139h),a		;4dea
	call siembra_la_mano		;4ded   ; AQUI SE SIEMBRA la mano recien repartida
	ld hl,0e1a9h		;4df0
	set 0,(hl)		;4df3   ; bit 0 de 0xE1A9: el reparto ya esta hecho
	ret			;4df5

; ----------------------------------------------------------------------
; FASE 1 DEL REPARTO: las tandas. Cada 32 fotogramas suena el golpe de la ficha y le toca a uno de los dos, alternandose con el bit 0 de 0xE1B7. Cada tanda copia CUATRO fichas -o UNA, si ya van doce- y cuando el contador de cualquiera de los dos llega a trece se pasa a la fase siguiente.
; ----------------------------------------------------------------------
reparte_una_tanda:
	ld a,(0e003h)		;4df6
	and 01fh		;4df9   ; una tanda cada 32 fotogramas
	ret nz			;4dfb
	ld a,007h		;4dfc
	call L_9C4A		;4dfe   ; sonido 7: el golpe de la ficha en la mesa
	ld hl,0e1b7h		;4e01
	inc (hl)			;4e04   ; le toca al otro
	ld a,(hl)			;4e05
	rra			;4e06   ; el bit 0 dice a cual de los dos
	jr c,L_4E2D		;4e07
	ld a,(0e1b5h)		;4e09
	ld hl,0e04dh		;4e0c
	call cuantas_tocan_ahora		;4e0f   ; cuantas van y cuantas tocan ahora
	ld (0e1b5h),a		;4e12
	ld hl,04fb1h		;4e15
	ld de,0e14ch		;4e18
	ld c,a			;4e1b
	ld b,000h		;4e1c
	ldir		;4e1e
	ld a,(0e04dh)		;4e20
	rra			;4e23
	ret c			;4e24
	ld a,(0e1b5h)		;4e25
	cp 00dh		;4e28   ; trece: este ya tiene su mano entera
	jr z,L_4E4F		;4e2a
	ret			;4e2c
L_4E2D:
	ld a,(0e1b6h)		;4e2d   ; el otro jugador, con su propio contador
	ld hl,0e33fh		;4e30
	call cuantas_tocan_ahora		;4e33
	ld (0e1b6h),a		;4e36
	ld hl,0e12ch		;4e39   ; y su propia mano
	ld de,0e13ah		;4e3c
	ld c,a			;4e3f
	ld b,000h		;4e40
	ldir		;4e42
	ld a,(0e04dh)		;4e44
	rra			;4e47
	ret nc			;4e48
	ld a,(0e1b6h)		;4e49
	cp 00dh		;4e4c   ; trece tambien
	ret nz			;4e4e
L_4E4F:
	xor a			;4e4f
	ld (0e1b7h),a		;4e50   ; el turno vuelve al primero
	ld hl,0e1a9h		;4e53
	set 1,(hl)		;4e56   ; bit 1 de 0xE1A9: las tandas se han acabado
	ret			;4e58

; ----------------------------------------------------------------------
; CUANTAS FICHAS LLEVA LA TANDA SIGUIENTE, y aqui esta la regla: si ya van DOCE repartidas, la tanda es de UNA; si no, de CUATRO. Suma esa cantidad al contador que entra en A y lo devuelve. Cuatro, cuatro, cuatro y una: trece.
; ----------------------------------------------------------------------
cuantas_tocan_ahora:
	ld c,(hl)			;4e59
	inc c			;4e5a
	cp 00ch		;4e5b   ; doce repartidas: la ultima va de una en una
	jr z,L_4E61		;4e5d
	ld c,004h		;4e5f   ; y hasta entonces, de cuatro en cuatro
L_4E61:
	add a,c			;4e61   ; el contador con la tanda ya sumada
	ret			;4e62

; ----------------------------------------------------------------------
; FASE 2: cada 16 fotogramas borra los catorce huecos de 0xE13A y ordena lo que haga falta con 0x4F96. Es el hueco de en medio entre repartir y enseñar.
; ----------------------------------------------------------------------
borra_la_mano_de_trabajo:
	ld a,(0e003h)		;4e63
	and 00fh		;4e66   ; cada 16 fotogramas
	ret nz			;4e68
	xor a			;4e69
	ld hl,0e13ah		;4e6a
	ld b,00eh		;4e6d   ; catorce huecos
L_4E6F:
	ld (hl),a			;4e6f
	inc hl			;4e70
	djnz L_4E6F		;4e71
	call ordena_la_mano		;4e73
	ld hl,0e1a9h		;4e76
	set 2,(hl)		;4e79   ; bit 2 de 0xE1A9: hecho
	ret			;4e7b

; ----------------------------------------------------------------------
; FASE 3: va pasando las fichas de 0xE12C a 0xE13A de UNA EN UNA, cada cuatro fotogramas y con su sonido, hasta las catorce. Es lo que se ve como la mano colocandose. El hueco catorce solo se rellena de verdad si toca; si no, se marca con 0x39, que no es un codigo de ficha valido.
; ----------------------------------------------------------------------
ensena_la_mano_ficha_a_ficha:
	ld a,(0e003h)		;4e7c
	and 003h		;4e7f   ; cada cuatro fotogramas, una ficha
	ret nz			;4e81
	ld a,001h		;4e82
	call L_9C4A		;4e84   ; sonido 1: la ficha colocandose
	ld a,(0e04dh)		;4e87
	rra			;4e8a
	jr nc,L_4E92		;4e8b
	ld a,039h		;4e8d   ; 0x39, la marca de hueco vacio
	ld (0e139h),a		;4e8f
L_4E92:
	ld a,(0e1b7h)		;4e92
	cp 00eh		;4e95   ; a las catorce se acaba
	jr z,cierra_el_reparto		;4e97
	push af			;4e99
	ld hl,0e12ch		;4e9a
	call suma_a_a_hl		;4e9d   ; la ficha que toca de la mano repartida
	pop af			;4ea0
	ld de,0e13ah		;4ea1
	call suma_a_a_de		;4ea4   ; y su hueco en la mano que se ve
	ld a,(hl)			;4ea7
	ld (de),a			;4ea8
	ld hl,0e1b7h		;4ea9
	inc (hl)			;4eac   ; una ficha mas colocada
	ret			;4ead

; ----------------------------------------------------------------------
; FASE 4, la ultima del reparto. Borra 205 bytes de trabajo, saca DOS fichas mas -0xE1D3 y 0xE1D4-, sortea 0xE33D con las correcciones de abajo y baja el bit 0 de 0xE1A8, que es la senal de "reparto terminado" que espera el submodo 1 del estado 11. En el demo la primera de las dos fichas no se sortea: se le mete 0x32 a pelo.
; ----------------------------------------------------------------------
cierra_el_reparto:
	ld hl,0e2b6h		;4eae
	ld de,0e2b7h		;4eb1
	ld bc,000cdh		;4eb4   ; 205 bytes de trabajo, a cero
	ld (hl),000h		;4eb7
	ldir		;4eb9
	call reparte_una_ficha		;4ebb   ; la primera de las dos fichas
	ld hl,0e002h		;4ebe
	bit 6,(hl)		;4ec1   ; bit 6 de 0xE002: con partida vale la sorteada
	jr nz,L_4EC7		;4ec3
	ld a,032h		;4ec5   ; y en el demo, siempre la misma: 0x32
L_4EC7:
	ld (0e1d3h),a		;4ec7
	call reparte_una_ficha		;4eca   ; la segunda, esta siempre sorteada
	ld (0e1d4h),a		;4ecd
	call L_7015		;4ed0
	ld hl,0e2b6h		;4ed3
	ld de,0e2b7h		;4ed6
	ld (hl),000h		;4ed9
	ld bc,00030h		;4edb   ; otros 48 bytes limpios
	ldir		;4ede
L_4EE0:
	call saca_un_numero_al_azar		;4ee0
	ld (0e33dh),a		;4ee3   ; el numero que se sortea aqui
	cp 014h		;4ee6   ; de 20 para arriba
	jr c,L_4EF1		;4ee8
	ld a,(0e040h)		;4eea
	rra			;4eed
	rra			;4eee   ; EL BIT 1 DE LA DIFICULTAD: solo con la tecla 3 se rechaza y se repite
	jr c,L_4EE0		;4eef
L_4EF1:
	ld a,(0e058h)		;4ef1
	rra			;4ef4   ; bit 0 de 0xE058
	jr nc,L_4EFE		;4ef5
	ld a,(0e064h)		;4ef7
	and 003h		;4efa   ; los dos bits bajos de la semilla
	jr z,L_4F0E		;4efc
L_4EFE:
	ld hl,0e33dh		;4efe
	ld a,(hl)			;4f01
	cp 008h		;4f02   ; por debajo de 8 no se deja
	jr nc,L_4F0E		;4f04
	ld a,(0e064h)		;4f06
	and 003h		;4f09
	add a,008h		;4f0b   ; se sube a un valor entre 8 y 11
	ld (hl),a			;4f0d
L_4F0E:
	ld a,(0e04bh)		;4f0e
	cp 007h		;4f11   ; con 0xE04B en siete o mas
	jr c,L_4F22		;4f13
	ld a,(0e065h)		;4f15
	rra			;4f18   ; y el bit 0 de 0xE065 a cero
	jr c,L_4F22		;4f19
	ld a,(0e33dh)		;4f1b
	rra			;4f1e   ; el valor se parte por la mitad
	ld (0e33dh),a		;4f1f
L_4F22:
	ld hl,0e1a8h		;4f22
	res 0,(hl)		;4f25   ; bit 0 de 0xE1A8 abajo: el reparto ha terminado
	inc hl			;4f27
	ld (hl),000h		;4f28   ; y el submodo, a cero
	ret			;4f2a

; ----------------------------------------------------------------------
; EL GENERADOR DE NUMEROS AL AZAR, y devuelve directamente un tipo de ficha: sale con H entre 0 y 33. Por dentro es una division: mete la semilla de 0xE064 por ocho vueltas de `adc hl,hl` restando 57 cuando cabe, de modo que H acaba valiendo la semilla modulo 57 y L el cociente, que pasa a ser la semilla nueva. Como 57 es mas que 34, los restos de 34 a 56 no valen: en vez de doblarlos -que cargaria el dado hacia los primeros tipos- los TIRA y vuelve a sortear. Y si el byte bajo de la semilla se queda a cero, la resiembra con el registro R del refresco, para que no se clave.
; ----------------------------------------------------------------------
saca_un_numero_al_azar:
	push de			;4f2b
L_4F2C:
	ld c,b			;4f2c
	ld e,039h		;4f2d   ; 57, el modulo de la division
	ld hl,(0e064h)		;4f2f   ; la semilla
	ld a,l			;4f32
	or a			;4f33   ; semilla a cero: hay que resembrarla o se queda clavada
	jr nz,L_4F39		;4f34
	ld a,r		;4f36   ; el registro R del refresco de memoria, que nunca para
	ld l,a			;4f38
L_4F39:
	inc h			;4f39
	inc l			;4f3a
	ld b,008h		;4f3b   ; ocho vueltas, una por bit
	xor a			;4f3d
L_4F3E:
	adc hl,hl		;4f3e   ; va metiendo bits por abajo
	ld a,h			;4f40
	jr c,L_4F46		;4f41
	cp e			;4f43
	jr c,L_4F49		;4f44
L_4F46:
	sub e			;4f46   ; cabe el 57: se resta y queda el resto
	ld h,a			;4f47
	xor a			;4f48
L_4F49:
	ccf			;4f49
	djnz L_4F3E		;4f4a
	rl l		;4f4c
	ld (0e064h),hl		;4f4e   ; la semilla nueva, para la proxima
	ld b,c			;4f51
	ld a,h			;4f52
	cp e			;4f53   ; si el resto se pasa de 57 algo va mal: se resiembra
	jr c,L_4F5E		;4f54
	ld a,(0e064h)		;4f56
	ld (0e065h),a		;4f59
	jr L_4F2C		;4f5c
L_4F5E:
	cp 022h		;4f5e   ; 34: de ahi para arriba no hay tipo de ficha, se tira y otra vez
	jr nc,L_4F2C		;4f60
	pop de			;4f62
	ret			;4f63

; ----------------------------------------------------------------------
; De donde sale la ficha siguiente. Con mano ya repartida (bit 0 de 0xE1A8) o con partida en marcha, se SORTEA; si no, se roba de la tira fija por 0x498F, que es lo que hace el demo. Al sortear comprueba la tabla de copias de 0xE186: de cada tipo hay cuatro fichas y ni una mas, asi que si el sorteo saca un tipo agotado se resiembra la semilla y se vuelve a tirar.
; ----------------------------------------------------------------------
reparte_una_ficha:
	ld a,(0e1a8h)		;4f64
	rra			;4f67   ; bit 0 de 0xE1A8: ya hay mano repartida
	jr c,L_4F74		;4f68
	ld hl,0e002h		;4f6a
	bit 6,(hl)		;4f6d   ; y bit 6 de 0xE002: hay partida
	jr nz,L_4F74		;4f6f
	jp saca_del_muro		;4f71   ; ni una cosa ni la otra: se roba de la tira fija
L_4F74:
	call saca_un_numero_al_azar		;4f74
	ld hl,0e186h		;4f77   ; la tabla de copias repartidas por tipo
	call suma_a_a_hl		;4f7a
	ld a,(hl)			;4f7d
	cp 004h		;4f7e   ; cuatro copias es el maximo: de ese tipo no queda ninguna
	jr c,saca_la_ficha_de_e065		;4f80
	ld a,(0e064h)		;4f82   ; se resiembra la semilla y se sortea otra vez
	ld (0e065h),a		;4f85
	jr reparte_una_ficha		;4f88

; ----------------------------------------------------------------------
; Sube el contador al que apunta HL y devuelve el codigo de la ficha cuyo indice esta en 0xE065, pasandolo por la tabla de los 34 tipos. Es la salida de 0x4F74 cuando el tipo sorteado si tenia copias libres.
; ----------------------------------------------------------------------
saca_la_ficha_de_e065:
	inc (hl)			;4f8a   ; una copia mas repartida de ese tipo
	ld a,(0e065h)		;4f8b
	ld hl,04fbfh		;4f8e   ; la tabla de los 34 tipos
	call suma_a_a_hl		;4f91
	ld a,(hl)			;4f94
	ret			;4f95

; ----------------------------------------------------------------------
; ORDENA LOS CATORCE HUECOS DE LA MANO, y por eso las fichas se ven agrupadas por palo en vez de en el orden en que salieron. Es una ordenacion por seleccion a la vieja usanza: por cada hueco recorre lo que queda buscando el mayor y lo trae, usando A' para el intercambio porque el Z80 no tiene otro sitio donde dejarlo. La entrada de 0x4F99 sirve para ordenar cualquier otra tira de catorce.
; ----------------------------------------------------------------------
ordena_la_mano:
	ld hl,0e12ch		;4f96   ; la mano
L_4F99:
	ld b,00eh		;4f99   ; catorce huecos
L_4F9B:
	ld a,(hl)			;4f9b   ; el candidato de esta vuelta
	ld c,b			;4f9c
	ld d,h			;4f9d
	ld e,l			;4f9e
L_4F9F:
	cp (hl)			;4f9f   ; compara con el que toca
	jr c,L_4FA7		;4fa0   ; el candidato es menor: se queda como esta
	ex af,af'			;4fa2   ; y si no, se intercambian pasando por A'
	ld a,(hl)			;4fa3
	ex af,af'			;4fa4
	ld (hl),a			;4fa5
	ex af,af'			;4fa6
L_4FA7:
	inc hl			;4fa7
	dec c			;4fa8
	jr nz,L_4F9F		;4fa9
	ex de,hl			;4fab
	ld (hl),a			;4fac   ; el elegido, a su sitio
	inc hl			;4fad
	djnz L_4F9B		;4fae
	ret			;4fb0

; ----------------------------------------------------------------------
; DATOS mano_vacia: Catorce bytes 0x38, uno por hueco de la mano. 0x38 es el
;   codigo siguiente al ultimo honor (0x37), o sea "aqui no hay ficha".
;   0x4fb1..0x4fbf  (14 bytes)
DATA_mano_vacia:
	defb 038h,038h,038h,038h,038h,038h,038h,038h,038h,038h,038h,038h,038h,038h	; 4fb1  88888888888888

; ----------------------------------------------------------------------
; DATOS los_treinta_y_cuatro_tipos: Los 34 codigos de ficha en orden:
;   0x01-0x09, 0x11-0x19, 0x21-0x29 y 0x31-0x37. Lo leen siete sitios
;   distintos, entre ellos 0x497B, 0x4F8E, 0x674E, 0x7953 y 0x7ABC.
;   0x4fbf..0x4fe1  (34 bytes)
DATA_los_treinta_y_cuatro_tipos:
	defb 001h,002h,003h,004h,005h,006h,007h,008h,009h,011h,012h,013h,014h,015h,016h,017h,018h,019h,021h,022h,023h,024h,025h,026h,027h,028h,029h,031h,032h,033h,034h,035h,036h,037h	; 4fbf  ..................!"#$%&'()1234567

; ======================================================================
; CODIGO 0x4fe1..0x51f4  (531 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; EL TURNO. Decide a cual de los dos le toca -0xE206, que sale de mirar si 0xE1AA vale 0x1F o 0x3F-, copia sus dieciocho bytes de mano al buffer de trabajo de 0xE32B, juega, y devuelve el resultado a la mano de quien fuera. Las dos manos viven en 0xE13A y 0xE14C, y todo lo que se juega se hace sobre la copia.
; ----------------------------------------------------------------------
juega_el_turno:
	ld b,001h		;4fe1
	ld a,(0e1aah)		;4fe3
	cp 01fh		;4fe6   ; los dos valores que ponen el turno en el segundo jugador
	jr z,L_4FEF		;4fe8
	cp 03fh		;4fea
	jr z,L_4FEF		;4fec
	dec b			;4fee
L_4FEF:
	ld a,b			;4fef
	ld (0e206h),a		;4ff0   ; de quien es el turno
	ld hl,0e13ah		;4ff3   ; la mano del primero
	or a			;4ff6
	jr z,L_4FFC		;4ff7
	ld hl,0e14ch		;4ff9   ; o la del segundo
L_4FFC:
	ld de,0e32bh		;4ffc
	ld bc,00012h		;4fff   ; dieciocho bytes de mano
	ldir		;5002
	call L_517A		;5004   ; y a jugar
	ld a,(0e206h)		;5007
	rra			;500a
	jr c,L_5013		;500b
	call L_65BD		;500d
	call L_660A		;5010
L_5013:
	ld a,(0e206h)		;5013
	ld de,0e13ah		;5016
	or a			;5019
	jr z,L_501F		;501a
	ld de,0e14ch		;501c
L_501F:
	ld hl,0e32bh		;501f
	ld bc,00012h		;5022
	ldir		;5025   ; la mano jugada vuelve a su sitio
	ld a,(0e1a9h)		;5027
	cp 0ffh		;502a   ; 0xFF: caso aparte
	jp z,L_5661		;502c
	or a			;502f
	jp nz,L_56B6		;5030
	ld hl,0e1c7h		;5033
	bit 0,(hl)		;5036   ; bit 0 de 0xE1C7
	jr z,despacha_la_fase_de_la_mano		;5038
	res 0,(hl)		;503a
	ld a,(0e206h)		;503c
	rra			;503f
	jr c,L_505B		;5040
	call L_66E7		;5042
	ld a,(0e040h)		;5045   ; LA DIFICULTAD otra vez: sin el bit 0 no se comprueba nada
	rra			;5048
	jr nc,L_505B		;5049
	ld a,(0e1d1h)		;504b
	rra			;504e   ; bit 0 de 0xE1D1
	jr c,L_505B		;504f
	call busca_en_las_dos_listas		;5051   ; cruza la mano contra las dos listas
	ld hl,0e1cdh		;5054
	bit 6,(hl)		;5057   ; bit 6 de 0xE1CD: hay coincidencia
	jr nz,apaga_la_marca_y_sigue		;5059
L_505B:
	call L_5F3E		;505b
	ld a,(0e302h)		;505e
	rra			;5061   ; bit 0 de 0xE302
	jr c,L_50A4		;5062
	ld a,(0e206h)		;5064
	rra			;5067
	jp c,L_5661		;5068
	ld hl,0e1cch		;506b
	ld a,(0e1beh)		;506e
	inc a			;5071
	cp (hl)			;5072   ; comparar con 0xE1CC
	jr nz,L_5079		;5073
	xor a			;5075
	ld (0e1cdh),a		;5076   ; no cuadra: se olvida lo apuntado
L_5079:
	ld a,040h		;5079
	ld (0e1a9h),a		;507b   ; 0x40 en 0xE1A9
	ld a,(0e1beh)		;507e
	cp 00ah		;5081   ; diez fichas
	jp nc,L_56F7		;5083
	call L_583C		;5086
	ld a,(0e208h)		;5089
	push af			;508c
	dec a			;508d
	ld hl,0e14ch		;508e
	call suma_a_a_hl		;5091
	ld a,(0e22bh)		;5094
	ld (hl),a			;5097
	pop af			;5098
	inc a			;5099
	ld b,a			;509a
	ld hl,0e14ch		;509b
	call L_4F9B		;509e   ; y se reordena la mano con lo nuevo
	jp L_56F7		;50a1
L_50A4:
	call L_67A1		;50a4

; ----------------------------------------------------------------------
; Baja el bit 6 de 0xE1CD -la marca de coincidencia- y, si el turno es del primero, saca el dibujo 2 del rincon, que es el unico de los tres que suena.
; ----------------------------------------------------------------------
apaga_la_marca_y_sigue:
	ld hl,0e1cdh		;50a7
	res 6,(hl)		;50aa   ; bit 6 abajo: la marca ya esta usada
	ld a,(0e206h)		;50ac
	rra			;50af   ; de quien es el turno
	jr c,despacha_la_fase_de_la_mano		;50b0
	ld a,002h		;50b2
	call pinta_uno_de_los_tres_dibujos		;50b4   ; el dibujo que suena

; ----------------------------------------------------------------------
; El despachador de la mano: ocho ramas colgadas de los bits de 0xE1AA, con los `rra` encadenados bajando bit a bit. El PRIMER bit que este a cero manda; si estan los ocho puestos, se va a 0x5654. Es el mismo truco que 0x4D91 usa para el reparto.
; ----------------------------------------------------------------------
despacha_la_fase_de_la_mano:
	ld a,(0e1aah)		;50b7
	rra			;50ba   ; bit 0
	jp nc,arranca_la_mano		;50bb
	rra			;50be   ; bit 1
	jp nc,L_527F		;50bf
	rra			;50c2   ; bit 2
	jp nc,L_535E		;50c3
	rra			;50c6   ; bit 3
	jp nc,L_540C		;50c7
	rra			;50ca   ; bit 4
	jp nc,L_5436		;50cb
	rra			;50ce   ; bit 5
	jp nc,L_5460		;50cf
	rra			;50d2   ; bit 6
	jp nc,L_54EB		;50d3
	rra			;50d6   ; bit 7
	jp nc,L_55A2		;50d7
	jp L_5654		;50da   ; los ocho puestos

; ----------------------------------------------------------------------
; Pone en pie todos los contadores de una mano nueva: los dos limites de 0xE1C0, la cantidad de la DIFICULTAD sumada a 0xE33D, los contadores a 13, los indices a 0xFF y 0x12, y de quien es el turno. Es el punto donde la dificultad elegida se convierte por fin en un numero que el juego usa.
; ----------------------------------------------------------------------
arranca_la_mano:
	ld hl,0e1c0h		;50dd
	ld a,(0e04dh)		;50e0
	rra			;50e3   ; bit 0 de 0xE04D: quien es mano
	ld a,012h		;50e4   ; dieciocho
	jr c,L_50EA		;50e6
	ld a,014h		;50e8   ; o veinte
L_50EA:
	ld (hl),a			;50ea
	inc hl			;50eb
	ld a,012h		;50ec
	jr nc,L_50F2		;50ee
	ld a,014h		;50f0
L_50F2:
	ld (hl),a			;50f2
	ld b,003h		;50f3   ; la cantidad por defecto: tres
	ld a,(0e040h)		;50f5   ; LA DIFICULTAD, y aqui se vuelve un numero: 3, 5 o 7
	rra			;50f8   ; bit 0: la tecla 1 se queda con tres
	jr c,L_5102		;50f9
	ld b,007h		;50fb   ; la tecla 3 vale siete
	rra			;50fd   ; bit 1
	jr c,L_5102		;50fe
	ld b,005h		;5100   ; y la tecla 2, cinco
L_5102:
	ld a,(0e064h)		;5102
	rra			;5105   ; el bit 0 de la semilla decide si la dificultad cuenta esta vez
	ld a,(0e33dh)		;5106
	dec a			;5109   ; una menos
	jr c,L_510D		;510a
	add a,b			;510c   ; y aqui se le suma
L_510D:
	ld (0e1bbh),a		;510d   ; el numero con el que se juega la mano. MEDIDO en openMSX, una pasada por tecla: la 1 da 0xE33D=28 y 0xE1BB=30 (28-1+3), la 2 da 29 y 33 (29-1+5), y la 3 da 11 y 10 (11-1, sin sumar, porque esa vez la semilla salio impar). Las tres cuadran con lo que dice este codigo, incluida la vez que no suma.
	ld a,0ffh		;5110   ; 0xFF: aun no hay ninguna elegida
	ld (0e1beh),a		;5112
	ld (0e1bfh),a		;5115
	ld a,00dh		;5118   ; trece fichas
	ld (0e1c2h),a		;511a
	ld (0e207h),a		;511d
	ld (0e1c3h),a		;5120
	ld (0e208h),a		;5123
	ld a,012h		;5126   ; dieciocho
	ld (0e1ceh),a		;5128
	ld (0e20ch),a		;512b
	ld a,(0e04dh)		;512e
	ld (0e22ah),a		;5131   ; quien es mano
	xor 001h		;5134   ; y el contrario
	ld (0e1d1h),a		;5136
	or a			;5139
	jr nz,L_5144		;513a
	ld a,03fh		;513c
	ld (0e1aah),a		;513e   ; 0x3F: las seis fases de la mano por hacer
	call L_598F		;5141
L_5144:
	ld hl,0e240h		;5144
	ld de,0e241h		;5147
	ld (hl),000h		;514a
	ld bc,00076h		;514c   ; 118 bytes de trabajo a cero
	ldir		;514f
	ld hl,051f4h		;5151
	ld de,0e0a8h		;5154
	ld bc,00058h		;5157
	ldir		;515a
	ld hl,0524ch		;515c
	call pinta_lista_formato_b		;515f
	ld hl,05204h		;5162
	ld de,03b10h		;5165
	ld bc,00048h		;5168
	call L_460B		;516b
	ld hl,00000h		;516e
	ld (0e052h),hl		;5171
	ld hl,0e1aah		;5174
	set 0,(hl)		;5177
	ret			;5179
L_517A:
	ld a,(0e1c2h)		;517a
	ld (0e209h),a		;517d
	ld a,(0e1c3h)		;5180
	ld (0e20ah),a		;5183
	ld a,(0e1ceh)		;5186
	ld (0e20bh),a		;5189
	ld a,(0e1d1h)		;518c
	ld (0e22ch),a		;518f
	ld a,(0e1cdh)		;5192
	ld (0e33eh),a		;5195
	ld a,(0e206h)		;5198
	rra			;519b
	ret nc			;519c
	ld a,(0e207h)		;519d
	ld (0e209h),a		;51a0
	ld a,(0e208h)		;51a3
	ld (0e20ah),a		;51a6
	ld a,(0e20ch)		;51a9
	ld (0e20bh),a		;51ac
	ld a,(0e22ah)		;51af
	ld (0e22ch),a		;51b2
	ld a,(0e1aeh)		;51b5
	ld (0e33eh),a		;51b8
	ret			;51bb
L_51BC:
	ld a,(0e206h)		;51bc
	rra			;51bf
	jr c,L_51DB		;51c0
	ld a,(0e209h)		;51c2
	ld (0e1c2h),a		;51c5
	ld a,(0e20ah)		;51c8
	ld (0e1c3h),a		;51cb
	ld a,(0e20bh)		;51ce
	ld (0e1ceh),a		;51d1
	ld a,(0e33eh)		;51d4
	ld (0e1cdh),a		;51d7
	ret			;51da
L_51DB:
	ld a,(0e209h)		;51db
	ld (0e207h),a		;51de
	ld a,(0e20ah)		;51e1
	ld (0e208h),a		;51e4
	ld a,(0e20bh)		;51e7
	ld (0e20ch),a		;51ea
	ld a,(0e33eh)		;51ed
	ld (0e1aeh),a		;51f0
	ret			;51f3

; ----------------------------------------------------------------------
; DATOS atributos_de_sprite: Veintidos registros de cuatro bytes que 0x5151 y
;   0x5162 mandan a la tabla de atributos de sprite. 0x5162 entra por el
;   registro cuatro (0x5204).
;   0x51f4..0x524c  (88 bytes)
DATA_atributos_de_sprite:
	defb 0aah,0e0h,000h,00dh	; 51f4
	defb 0afh,0e0h,004h,00dh	; 51f8
	defb 0aah,0e0h,000h,00dh	; 51fc
	defb 0afh,0e0h,004h,00dh	; 5200
	defb 0e0h,0b0h,008h,00fh	; 5204
	defb 0e0h,0b0h,00ch,00fh	; 5208
	defb 0e0h,0b0h,010h,00fh	; 520c
	defb 0e0h,0b0h,014h,006h	; 5210
	defb 0e0h,048h,008h,00fh	; 5214
	defb 0e0h,048h,00ch,00fh	; 5218
	defb 0e0h,048h,010h,00fh	; 521c
	defb 0e0h,048h,014h,006h	; 5220
	defb 0e0h,010h,018h,005h	; 5224
	defb 0e0h,0e0h,018h,005h	; 5228
	defb 0e0h,000h,018h,008h	; 522c
	defb 0e0h,000h,018h,008h	; 5230
	defb 0e0h,000h,018h,008h	; 5234
	defb 0e0h,000h,018h,008h	; 5238
	defb 0e0h,000h,018h,008h	; 523c
	defb 0e0h,000h,018h,008h	; 5240
	defb 0e0h,000h,018h,008h	; 5244
	defb 0e0h,000h,018h,008h	; 5248

; ----------------------------------------------------------------------
; DATOS patrones_de_sprite: Formato B desde 0x515F: 224 bytes a 0x1800, o sea
;   los patrones de sprite. Es el unico bloque del cartucho que escribe ahi.
;   0x524c..0x527f  (51 bytes)
DATA_patrones_de_sprite:
	defb 000h,018h,002h,0ffh,00eh,000h,002h,0ffh,01ch,000h,002h,0ffh,00eh,000h,002h,0ffh	; 524c  ................
	defb 003h,000h,081h,01ch,00ch,03eh,010h,000h,007h,03eh,002h,022h,007h,03eh,010h,000h	; 525c  .....>...>.".>..
	defb 00ch,03eh,081h,01ch,01ah,000h,002h,01ch,017h,000h,003h,07fh,00dh,000h,003h,0feh	; 526c  .>..............
	defb 00dh,000h,000h	; 527c

; ======================================================================
; CODIGO 0x527f..0x5350  (209 bytes)
; ======================================================================


L_527F:
	ld a,001h		;527f
	call pinta_uno_de_los_tres_dibujos		;5281
	call L_663C		;5284
	call L_51BC		;5287
	ld a,(0e1aah)		;528a
	cp 0ffh		;528d
	jp z,L_5603		;528f
	ld a,(0e040h)		;5292
	rra			;5295
	rra			;5296
	jr nc,L_52AD		;5297
	ld hl,001a4h		;5299
	call L_5636		;529c
	jr nc,L_52AD		;529f
	ld a,008h		;52a1
	call L_9C4A		;52a3
	ld hl,00258h		;52a6
	sbc hl,de		;52a9
	jr c,L_52B3		;52ab
L_52AD:
	ld a,(0e23ah)		;52ad
	rra			;52b0
	jr nc,L_52D1		;52b1
L_52B3:
	ld a,(0e1c2h)		;52b3
	ld hl,0e13ah		;52b6
	call suma_a_a_hl		;52b9
	ld a,(hl)			;52bc
	ld (0e1bch),a		;52bd
	call L_49C6		;52c0
	jr nc,L_52CA		;52c3
	ld a,002h		;52c5
	jp pinta_uno_de_los_tres_dibujos		;52c7
L_52CA:
	ld hl,0e1aah		;52ca
	set 1,(hl)		;52cd
	jr L_5334		;52cf
L_52D1:
	ld a,(0e003h)		;52d1
	and 007h		;52d4
	ret nz			;52d6
	ld a,(0e1cdh)		;52d7
	cp 081h		;52da
	jr nz,L_52E6		;52dc
	ld a,(0e1c3h)		;52de
	ld (0e1c2h),a		;52e1
	jr L_5324		;52e4
L_52E6:
	ld hl,0e009h		;52e6
	bit 2,(hl)		;52e9
	jr z,L_5305		;52eb
	ld a,005h		;52ed
	call L_9C4A		;52ef
	ld a,(0e1c2h)		;52f2
	dec a			;52f5
	ld (0e1c2h),a		;52f6
	or a			;52f9
	jp p,L_5324		;52fa
	ld a,(0e1c3h)		;52fd
	ld (0e1c2h),a		;5300
	jr L_5324		;5303
L_5305:
	ld hl,0e009h		;5305
	bit 3,(hl)		;5308
	jr z,L_5324		;530a
	ld a,005h		;530c
	call L_9C4A		;530e
	ld a,(0e1c2h)		;5311
	inc a			;5314
	ld hl,0e1c3h		;5315
	ld (0e1c2h),a		;5318
	cp (hl)			;531b
	jr c,L_5324		;531c
	jr z,L_5324		;531e
	xor a			;5320
	ld (0e1c2h),a		;5321
L_5324:
	ld a,(0e1c2h)		;5324
	ld hl,05350h		;5327
	call suma_a_a_hl		;532a
	ld a,(hl)			;532d
	ld (0e0a9h),a		;532e
	ld (0e0adh),a		;5331
L_5334:
	ld a,0e0h		;5334
	ld de,03b08h		;5336
	call escribe_en_vram		;5339
	ld a,0e0h		;533c
	ld de,03b0ch		;533e
	call escribe_en_vram		;5341
	ld hl,0e0a8h		;5344
	ld de,03b00h		;5347
	ld bc,00008h		;534a
	jp L_460B		;534d

; ----------------------------------------------------------------------
; DATOS multiplos_de_dieciseis: Los catorce multiplos de 0x10, de 0x10 a 0xE0,
;   uno por hueco de la mano. Lo leen siete sitios: 0x5327, 0x53EB, 0x57CB,
;   0x6A7B, 0x6A89, 0x6B48 y 0x6B6E.
;   0x5350..0x535e  (14 bytes)
DATA_multiplos_de_dieciseis:
	defb 010h,020h,030h,040h,050h,060h,070h,080h,090h,0a0h,0b0h,0c0h,0d0h,0e0h	; 5350  . 0@P`p.......

; ======================================================================
; CODIGO 0x535e..0x59b3  (1621 bytes)
; ======================================================================


L_535E:
	ld a,(0e003h)		;535e
	and 003h		;5361
	ret nz			;5363
	ld a,(0e1cdh)		;5364
	rra			;5367
	jr nc,L_53C7		;5368
	bit 6,a		;536a
	jr nz,L_53C7		;536c
	call L_66E7		;536e
	ld a,(0e1cdh)		;5371
	sla a		;5374
	jr c,L_539A		;5376
L_5378:
	ld a,002h		;5378
	call pinta_uno_de_los_tres_dibujos		;537a
	ld b,004h		;537d
	ld de,03b10h		;537f
L_5382:
	ld a,0e0h		;5382
	push de			;5384
	call escribe_en_vram		;5385
	pop de			;5388
	ld a,004h		;5389
	call suma_a_a_de		;538b
	djnz L_5382		;538e
	xor a			;5390
	ld (0e1cdh),a		;5391
	ld hl,0e1aah		;5394
	res 1,(hl)		;5397
	ret			;5399
L_539A:
	ld a,(0e040h)		;539a
	rra			;539d
	jr nc,L_53B8		;539e
	ld a,(0e1bch)		;53a0
	ld hl,0e1f5h		;53a3
	ld b,00dh		;53a6
	call L_6E5D		;53a8
	cp (hl)			;53ab
	jr z,L_5378		;53ac
	call busca_en_las_dos_listas		;53ae
	ld a,(0e1cdh)		;53b1
	and 040h		;53b4
	jr nz,L_5378		;53b6
L_53B8:
	ld de,01000h		;53b8
	call cobra_mil_el_de_e047		;53bb
	ld a,(0e04ah)		;53be
	add a,001h		;53c1
	daa			;53c3
	ld (0e04ah),a		;53c4
L_53C7:
	ld a,(0e1c2h)		;53c7
	ld hl,0e13ah		;53ca
	call suma_a_a_hl		;53cd
	ld (hl),039h		;53d0
	call L_6F2E		;53d2
	ld a,(0e1cdh)		;53d5
	rra			;53d8
	jr nc,L_5402		;53d9
	ld hl,0e0d8h		;53db
	ld (hl),090h		;53de
	ld a,(0e1cch)		;53e0
	cp 00ah		;53e3
	jr c,L_53EB		;53e5
	sub 00ah		;53e7
	ld (hl),0a8h		;53e9
L_53EB:
	ld hl,05350h		;53eb
	call suma_a_a_hl		;53ee
	ld a,(hl)			;53f1
	ld hl,0e0d9h		;53f2
	ld (hl),a			;53f5
	ld hl,0e0d8h		;53f6
	ld de,03b30h		;53f9
	ld bc,00004h		;53fc
	call L_460B		;53ff
L_5402:
	xor a			;5402
	ld (0e1cfh),a		;5403
	ld hl,0e1aah		;5406
	set 2,(hl)		;5409
	ret			;540b
L_540C:
	ld a,(0e003h)		;540c
	and 007h		;540f
	ret nz			;5411
	ld a,(0e1c3h)		;5412
	inc a			;5415
	ld b,a			;5416
	ld hl,0e13ah		;5417
	call L_4F9B		;541a
	call L_6F2E		;541d
	ld a,0e0h		;5420
	ld de,03b00h		;5422
	call escribe_en_vram		;5425
	ld a,0e0h		;5428
	ld de,03b04h		;542a
	call escribe_en_vram		;542d
	ld hl,0e1aah		;5430
	set 3,(hl)		;5433
	ret			;5435
L_5436:
	ld a,(0e003h)		;5436
	and 007h		;5439
	ret nz			;543b
	ld hl,0e1d1h		;543c
	res 0,(hl)		;543f
	ld a,006h		;5441
	call L_9C4A		;5443
	ld hl,0e1beh		;5446
	inc (hl)			;5449
	ld a,(0e1beh)		;544a
	ld hl,0e15eh		;544d
	call suma_a_a_hl		;5450
	ld a,(0e1bch)		;5453
	ld (hl),a			;5456
	call L_6F4E		;5457
	ld hl,0e1aah		;545a
	set 4,(hl)		;545d
	ret			;545f
L_5460:
	ld a,(0e003h)		;5460
	and 007h		;5463
	ret nz			;5465
	ld hl,0e2b6h		;5466
	ld de,0e240h		;5469
	ld bc,0003bh		;546c
	ldir		;546f
	ld hl,0e27bh		;5471
	ld de,0e2b6h		;5474
	ld bc,0003bh		;5477
	ldir		;547a
	call L_567B		;547c
	ld a,(0e1a9h)		;547f
	or a			;5482
	ret nz			;5483
	ld a,(0e1c7h)		;5484
	rra			;5487
	ret c			;5488
	ld hl,0e1beh		;5489
	ld a,(0e1c0h)		;548c
	cp (hl)			;548f
	jr nc,L_549D		;5490
	call L_563D		;5492
	ld hl,0e1aah		;5495
	res 4,(hl)		;5498
	jp L_5654		;549a
L_549D:
	ld a,001h		;549d
	ld (0e22ah),a		;549f
	call L_5A2B		;54a2
	call L_54DE		;54a5
	ld a,(0e064h)		;54a8
	and 003h		;54ab
	jr nz,L_54BE		;54ad
	ld a,010h		;54af
	ld (0e20dh),a		;54b1
	call L_5828		;54b4
	ld a,c			;54b7
	rra			;54b8
	jr c,L_54BE		;54b9
	call L_5820		;54bb
L_54BE:
	call L_577A		;54be
	call L_551D		;54c1
	call L_6F3E		;54c4
	ld hl,0e21ch		;54c7
	ld de,0e14ch		;54ca
	call L_5535		;54cd
	ldir		;54d0
	ld a,(0e22bh)		;54d2
	call L_54DE		;54d5
	ld hl,0e1aah		;54d8
	set 5,(hl)		;54db
	ret			;54dd
L_54DE:
	push af			;54de
	ld a,(0e208h)		;54df
	ld hl,0e14ch		;54e2
	call suma_a_a_hl		;54e5
	pop af			;54e8
	ld (hl),a			;54e9
	ret			;54ea
L_54EB:
	ld hl,0e1c4h		;54eb
	bit 2,(hl)		;54ee
	jp nz,L_556C		;54f0
	ld a,(0e003h)		;54f3
	and 01fh		;54f6
	ret nz			;54f8
	set 2,(hl)		;54f9
	call L_567B		;54fb
	ld a,(0e1a9h)		;54fe
	or a			;5501
	ret nz			;5502
	ld a,(0e1c7h)		;5503
	rra			;5506
	ret c			;5507
	call L_551D		;5508
	call L_553C		;550b
L_550E:
	call L_6F3E		;550e
	ld hl,0e21ch		;5511
	ld de,0e14ch		;5514
	call L_5535		;5517
	ldir		;551a
	ret			;551c
L_551D:
	ld hl,0e14ch		;551d
	ld de,0e21ch		;5520
	call L_5535		;5523
	ldir		;5526
	ld hl,04fb1h		;5528
	ld de,0e14ch		;552b
	call L_5535		;552e
	inc c			;5531
	ldir		;5532
	ret			;5534
L_5535:
	ld b,000h		;5535
	ld a,(0e208h)		;5537
	ld c,a			;553a
	ret			;553b
L_553C:
	ld a,(0e1aeh)		;553c
	rra			;553f
	jr c,L_5567		;5540
	ld hl,0e33dh		;5542
	ld a,(0e1bfh)		;5545
	cp (hl)			;5548
	jr nc,L_5567		;5549
	cp 008h		;554b
	jr nc,L_5561		;554d
	ld a,(0e064h)		;554f
	rra			;5552
	jr c,L_5567		;5553
L_5555:
	call saca_un_numero_menor_que_h		;5555
	ld hl,0e14ch		;5558
	call suma_a_a_hl		;555b
	ld (hl),039h		;555e
	ret			;5560
L_5561:
	ld a,(0e064h)		;5561
	rra			;5564
	jr c,L_5555		;5565
L_5567:
	ld a,039h		;5567
	jp L_54DE		;5569
L_556C:
	ld a,(0e003h)		;556c
	and 00fh		;556f
	ret nz			;5571
	res 2,(hl)		;5572
	call L_5988		;5574
	call L_598F		;5577
	xor a			;557a
	ld (0e22ah),a		;557b
	ld a,006h		;557e
	call L_9C4A		;5580
	ld hl,0e1bfh		;5583
	inc (hl)			;5586
	ld a,(0e1bfh)		;5587
	ld hl,0e172h		;558a
	call suma_a_a_hl		;558d
	ld a,(0e22bh)		;5590
	ld (hl),a			;5593
	call L_6F60		;5594
	ld hl,00000h		;5597
	ld (0e052h),hl		;559a
	ld hl,0e1aah		;559d
	set 6,(hl)		;55a0
L_55A2:
	ld hl,0e1c4h		;55a2
	bit 1,(hl)		;55a5
	jr nz,L_55B9		;55a7
	set 1,(hl)		;55a9
	call L_551D		;55ab
	ld a,039h		;55ae
	call L_54DE		;55b0
	call L_550E		;55b3
	call L_563D		;55b6
L_55B9:
	ld hl,0e1bfh		;55b9
	ld a,(0e1c1h)		;55bc
	cp (hl)			;55bf
	jr nc,L_55CC		;55c0
	ld hl,001a4h		;55c2
	call L_5636		;55c5
	ret nc			;55c8
	jp L_5654		;55c9
L_55CC:
	xor a			;55cc
	call pinta_uno_de_los_tres_dibujos		;55cd
	call L_663C		;55d0
	call L_51BC		;55d3
	ld a,(0e1aah)		;55d6
	cp 001h		;55d9
	jp z,L_5630		;55db
	cp 0ffh		;55de
	jr z,L_5603		;55e0
	ld a,(0e040h)		;55e2
	rra			;55e5
	rra			;55e6
	jr nc,L_55F1		;55e7
	ld hl,002d0h		;55e9
	call L_5636		;55ec
	jr c,L_55F6		;55ef
L_55F1:
	ld a,(0e23ah)		;55f1
	rra			;55f4
	ret nc			;55f5
L_55F6:
	ld a,(0e22bh)		;55f6
	call L_49C6		;55f9
	jr nc,L_5603		;55fc
	ld a,002h		;55fe
	jp pinta_uno_de_los_tres_dibujos		;5600
L_5603:
	ld hl,00000h		;5603
	ld (0e052h),hl		;5606
	ld a,007h		;5609
	call L_9C4A		;560b
	ld hl,0e1d1h		;560e
	set 0,(hl)		;5611
	call reparte_una_ficha		;5613
	push af			;5616
	ld a,(0e1c3h)		;5617
	ld hl,0e13ah		;561a
	call suma_a_a_hl		;561d
	pop af			;5620
	ld (hl),a			;5621
	call L_6F2E		;5622
	ld hl,0e1aah		;5625
	ld a,(0e1c3h)		;5628
	ld (0e1c2h),a		;562b
	ld (hl),001h		;562e
L_5630:
	ld hl,0e1c4h		;5630
	res 1,(hl)		;5633
	ret			;5635
L_5636:
	ld de,(0e052h)		;5636
	sbc hl,de		;563a
	ret			;563c
L_563D:
	ld hl,0e2b6h		;563d
	ld de,0e27bh		;5640
	ld bc,0003bh		;5643
	ldir		;5646
	ld hl,0e240h		;5648
	ld de,0e2b6h		;564b
	ld bc,0003bh		;564e
	ldir		;5651
	ret			;5653
L_5654:
	ld a,080h		;5654
	ld (0e1a9h),a		;5656
	jp L_56F7		;5659
L_565C:
	ld hl,0e302h		;565c
	set 2,(hl)		;565f
L_5661:
	ld a,0ffh		;5661
	ld (0e1a9h),a		;5663
	ld de,(0e052h)		;5666
	ld hl,000b4h		;566a
	sbc hl,de		;566d
	ret nc			;566f
	ld hl,0e1a8h		;5670
	xor a			;5673
	res 1,(hl)		;5674
	inc hl			;5676
	ld (hl),a			;5677
	inc hl			;5678
	ld (hl),a			;5679
	ret			;567a
L_567B:
	ld a,(0e340h)		;567b
	rra			;567e
	ret c			;567f
	ld a,(0e22bh)		;5680
	ld hl,0e1aah		;5683
	bit 5,(hl)		;5686
	jr nz,L_568D		;5688
	ld a,(0e1bch)		;568a
L_568D:
	call L_576E		;568d
	cp (hl)			;5690
	ret nz			;5691
	ld (0e1bah),a		;5692
	ld a,(0e1bfh)		;5695
	inc a			;5698
	ld hl,0e33dh		;5699
	cp (hl)			;569c
	jr nc,L_56A8		;569d
	ld hl,0e1aah		;569f
	bit 5,(hl)		;56a2
	ret z			;56a4
	jp L_598F		;56a5
L_56A8:
	ld hl,0e1bbh		;56a8
	ld a,(0e1bfh)		;56ab
	inc a			;56ae
	cp (hl)			;56af
	ret z			;56b0
	ld a,001h		;56b1
	ld (0e1a9h),a		;56b3
L_56B6:
	cp 001h		;56b6
	jr nz,L_571C		;56b8
	call L_575A		;56ba
	cp 002h		;56bd
	jr nc,L_56E3		;56bf
	rra			;56c1
	jr nc,L_56CB		;56c2
	ld a,(0e04bh)		;56c4
	cp 005h		;56c7
	jr c,L_56E3		;56c9
L_56CB:
	call L_67A1		;56cb
	xor a			;56ce
	ld (0e1a9h),a		;56cf
L_56D2:
	xor a			;56d2
	ld hl,0e305h		;56d3
	ld de,0e306h		;56d6
	ld (hl),a			;56d9
	ld bc,00011h		;56da
	ldir		;56dd
	ld (0e1d1h),a		;56df
	ret			;56e2
L_56E3:
	ld a,090h		;56e3
	call L_9C4A		;56e5
	call L_56D2		;56e8
	ld a,(0e22ah)		;56eb
	ld (0e1d1h),a		;56ee
	rra			;56f1
	jr nc,L_56F7		;56f2
	call L_5754		;56f4
L_56F7:
	ld hl,0e14ch		;56f7
	ld de,0e12bh		;56fa
	ld bc,0000eh		;56fd
	ldir		;5700
	ld a,(0e208h)		;5702
	inc a			;5705
	ld (0e129h),a		;5706
	ld b,a			;5709
	xor a			;570a
	ld (0e1b7h),a		;570b
	ld hl,0e14ch		;570e
L_5711:
	ld (hl),a			;5711
	inc hl			;5712
	djnz L_5711		;5713
	ld hl,0e1a9h		;5715
	set 1,(hl)		;5718
	jr L_5740		;571a
L_571C:
	ld a,(0e003h)		;571c
	and 007h		;571f
	ret nz			;5721
	ld hl,0e129h		;5722
	ld a,(0e1b7h)		;5725
	cp (hl)			;5728
	jr z,L_5743		;5729
	ld hl,0e12bh		;572b
	call suma_a_a_hl		;572e
	ld a,(0e1b7h)		;5731
	ld de,0e14ch		;5734
	call suma_a_a_de		;5737
	ld a,(hl)			;573a
	ld (de),a			;573b
	ld hl,0e1b7h		;573c
	inc (hl)			;573f
L_5740:
	jp L_6F3E		;5740
L_5743:
	ld hl,00000h		;5743
	ld (0e052h),hl		;5746
	ld a,(0e1a9h)		;5749
	rla			;574c
	jp c,L_565C		;574d
	rla			;5750
	jp L_5661		;5751
L_5754:
	ld a,(0e1bah)		;5754
	jp L_54DE		;5757
L_575A:
	call L_5F3E		;575a
	xor a			;575d
	ld (0e316h),a		;575e
	ld a,(0e22ah)		;5761
	ld (0e1d1h),a		;5764
	call L_7B3F		;5767
	ld a,(0e316h)		;576a
	ret			;576d
L_576E:
	ld b,00eh		;576e
	ld hl,0e20eh		;5770
L_5773:
	cp (hl)			;5773
	ret z			;5774
	inc hl			;5775
	djnz L_5773		;5776
	dec hl			;5778
	ret			;5779
L_577A:
	ld a,(0e340h)		;577a
	rra			;577d
	jr c,L_57EF		;577e
	ld a,(0e20eh)		;5780
	or a			;5783
	jr z,L_57EF		;5784
	ld a,(0e2b6h)		;5786
	or a			;5789
	jr nz,L_57EF		;578a
	ld a,(0e04bh)		;578c
	cp 005h		;578f
	jr c,L_579A		;5791
	ld a,(0e058h)		;5793
	and 0feh		;5796
	jr z,L_57EF		;5798
L_579A:
	ld a,(0e1bfh)		;579a
	inc a			;579d
	ld hl,0e1bbh		;579e
	cp (hl)			;57a1
	jr nz,L_57EF		;57a2
	cp 013h		;57a4
	jr z,L_57EF		;57a6
	ld de,01000h		;57a8
	call cobra_mil_el_de_e044		;57ab
	ld a,(0e04ah)		;57ae
	add a,001h		;57b1
	daa			;57b3
	ld (0e04ah),a		;57b4
	ld a,(0e1bbh)		;57b7
	ld hl,0e0dch		;57ba
	ld (hl),02ch		;57bd
	cp 00ah		;57bf
	jr c,L_57C7		;57c1
	sub 00ah		;57c3
	ld (hl),014h		;57c5
L_57C7:
	sub 00eh		;57c7
	xor 0ffh		;57c9
	ld hl,05350h		;57cb
	call suma_a_a_hl		;57ce
	ld a,(hl)			;57d1
	ld hl,0e0ddh		;57d2
	ld (hl),a			;57d5
	ld a,001h		;57d6
	ld (0e1aeh),a		;57d8
	ld a,002h		;57db
	ld (0e20dh),a		;57dd
	ld hl,0e0dch		;57e0
	ld de,03b34h		;57e3
	ld bc,00004h		;57e6
	call L_460B		;57e9
	jp L_5828		;57ec
L_57EF:
	ld a,(0e058h)		;57ef
	and 026h		;57f2
	jr z,L_5802		;57f4
	ld a,004h		;57f6
	ld (0e20dh),a		;57f8
	call L_5828		;57fb
	ld a,c			;57fe
	rra			;57ff
	jr nc,L_5813		;5800
L_5802:
	ld a,(0e058h)		;5802
	and 006h		;5805
	ret z			;5807
	ld a,008h		;5808
	ld (0e20dh),a		;580a
	call L_5828		;580d
	ld a,c			;5810
	rra			;5811
	ret c			;5812
L_5813:
	ld hl,0e20eh		;5813
	ld (hl),000h		;5816
	ld de,0e20fh		;5818
	ld bc,0000dh		;581b
	ldir		;581e
L_5820:
	call L_66E7		;5820
	xor a			;5823
	ld (0e205h),a		;5824
	ret			;5827
L_5828:
	ld a,(0e20dh)		;5828
	ld (0e1c7h),a		;582b
	call L_517A		;582e
	call L_663C		;5831
	call L_51BC		;5834
	xor a			;5837
	ld (0e1c7h),a		;5838
	ret			;583b
L_583C:
	ld hl,0e002h		;583c
	bit 6,(hl)		;583f
	ret z			;5841
	call reparte_una_ficha		;5842
	ld (0e22bh),a		;5845
	ld a,(0e040h)		;5848
	rra			;584b
	ret c			;584c
	ld a,(0e1bfh)		;584d
	cp 00ch		;5850
	jr nc,L_58AA		;5852
	inc a			;5854
	ld hl,0e33dh		;5855
	cp (hl)			;5858
	jr nc,L_5865		;5859
	ld a,(0e22bh)		;585b
	call L_576E		;585e
	cp (hl)			;5861
	jr z,L_587C		;5862
	ret			;5864
L_5865:
	ld a,(0e058h)		;5865
	and 006h		;5868
	jr z,L_5884		;586a
	ld a,(0e1bfh)		;586c
	cp 009h		;586f
	ret nc			;5871
	ld a,(0e22bh)		;5872
	and 0f0h		;5875
	ld hl,0e059h		;5877
	xor (hl)			;587a
	ret nz			;587b
L_587C:
	ld a,(0e22bh)		;587c
	call L_59A4		;587f
	jr L_583C		;5882
L_5884:
	ld a,(0e1bfh)		;5884
	cp 004h		;5887
	jr nc,L_5896		;5889
	ld a,(0e22bh)		;588b
	and 0f0h		;588e
	cp 030h		;5890
	jr z,L_58A9		;5892
	jr L_587C		;5894
L_5896:
	cp 008h		;5896
	jr nc,L_58A9		;5898
	ld a,(0e22bh)		;589a
	and 00fh		;589d
	cp 008h		;589f
	jr nc,L_58A9		;58a1
	cp 003h		;58a3
	jr c,L_58A9		;58a5
	jr L_587C		;58a7
L_58A9:
	ret			;58a9
L_58AA:
	ld a,(0e1aeh)		;58aa
	rra			;58ad
	ret c			;58ae
	ld a,(0e1bfh)		;58af
	cp 00fh		;58b2
	jr nz,L_58BA		;58b4
	call L_59EB		;58b6
	ret			;58b9
L_58BA:
	ld a,(0e1bfh)		;58ba
	cp 012h		;58bd
	jr nz,L_58CC		;58bf
	ld a,(0e064h)		;58c1
	rra			;58c4
	jr c,L_58CC		;58c5
	ld a,001h		;58c7
	ld (0e340h),a		;58c9
L_58CC:
	ld a,(0e340h)		;58cc
	rra			;58cf
	jr nc,L_58D6		;58d0
	call L_5A10		;58d2
	ret			;58d5
L_58D6:
	ld hl,0e341h		;58d6
	ld de,0e342h		;58d9
	ld (hl),000h		;58dc
	ld bc,00006h		;58de
	ldir		;58e1
	ld a,(0e1beh)		;58e3
	ld b,a			;58e6
	ld de,0e15eh		;58e7
L_58EA:
	ld a,(de)			;58ea
	and 0f0h		;58eb
	jr nz,L_58F5		;58ed
	ld hl,0e341h		;58ef
	inc (hl)			;58f2
	jr L_5911		;58f3
L_58F5:
	cp 010h		;58f5
	jr nz,L_58FF		;58f7
	ld hl,0e342h		;58f9
	inc (hl)			;58fc
	jr L_5911		;58fd
L_58FF:
	cp 020h		;58ff
	jr nz,L_5909		;5901
	ld hl,0e343h		;5903
	inc (hl)			;5906
	jr L_5911		;5907
L_5909:
	cp 030h		;5909
	jr nz,L_5911		;590b
	ld hl,0e344h		;590d
	inc (hl)			;5910
L_5911:
	ld a,(de)			;5911
	cp 031h		;5912
	jr z,L_5924		;5914
	and 00fh		;5916
	cp 001h		;5918
	jr z,L_5920		;591a
	cp 009h		;591c
	jr nz,L_5924		;591e
L_5920:
	ld hl,0e345h		;5920
	inc (hl)			;5923
L_5924:
	inc de			;5924
	djnz L_58EA		;5925
	ld c,001h		;5927
	ld hl,0e341h		;5929
	ld de,0e346h		;592c
	ld b,005h		;592f
L_5931:
	ld a,(hl)			;5931
	cp 002h		;5932
	jr nc,L_5939		;5934
	ld a,(de)			;5936
	or c			;5937
	ld (de),a			;5938
L_5939:
	sla c		;5939
	inc hl			;593b
	djnz L_5931		;593c
	xor a			;593e
	ld hl,0e346h		;593f
	bit 0,(hl)		;5942
	jr nz,L_5971		;5944
	ld a,010h		;5946
	bit 1,(hl)		;5948
	jr nz,L_5971		;594a
	ld a,020h		;594c
	bit 2,(hl)		;594e
	jr nz,L_5971		;5950
	ld a,030h		;5952
	bit 3,(hl)		;5954
	jr nz,L_5971		;5956
	bit 4,(hl)		;5958
	jr z,L_5987		;595a
L_595C:
	ld a,(0e22bh)		;595c
	and 00fh		;595f
	cp 001h		;5961
	jr nz,L_5987		;5963
	cp 009h		;5965
	jr nz,L_5987		;5967
	call L_5988		;5969
	call L_5A2B		;596c
	jr L_595C		;596f
L_5971:
	ld (0e347h),a		;5971
	ld a,(0e22bh)		;5974
	and 0f0h		;5977
	ld hl,0e347h		;5979
	xor (hl)			;597c
	jr nz,L_5987		;597d
	call L_5988		;597f
	call L_5A2B		;5982
	jr L_5971		;5985
L_5987:
	ret			;5987
L_5988:
	ld a,(0e22bh)		;5988
	call L_59A4		;598b
	ret			;598e
L_598F:
	call L_583C		;598f
	ld a,(0e22bh)		;5992
	call L_576E		;5995
	cp (hl)			;5998
	jr nz,L_59A3		;5999
	ld a,(0e22bh)		;599b
	call L_59A4		;599e
	jr L_598F		;59a1
L_59A3:
	ret			;59a3
L_59A4:
	ld hl,059b3h		;59a4
	call suma_a_a_hl		;59a7
	ld a,(hl)			;59aa
	ld hl,0e186h		;59ab
	call suma_a_a_hl		;59ae
	dec (hl)			;59b1
	ret			;59b2

; ----------------------------------------------------------------------
; DATOS indice_por_codigo_de_ficha: La tabla INVERSA de la anterior: indexada
;   por el codigo de ficha da 0..33 sin huecos ni repetidos, y los huecos del
;   codigo (0x0A-0x10, 0x1A-0x20, 0x2A-0x30) valen 0. La lee 0x59A4.
;   0x59b3..0x59eb  (56 bytes)
DATA_indice_por_codigo_de_ficha:
	defb 000h,000h,001h,002h,003h,004h,005h,006h	; 59b3  ........
	defb 007h,008h,000h,000h,000h,000h,000h,000h	; 59bb  ........
	defb 000h,009h,00ah,00bh,00ch,00dh,00eh,00fh	; 59c3  ........
	defb 010h,011h,000h,000h,000h,000h,000h,000h	; 59cb  ........
	defb 000h,012h,013h,014h,015h,016h,017h,018h	; 59d3  ........
	defb 019h,01ah,000h,000h,000h,000h,000h,000h	; 59db  ........
	defb 000h,01bh,01ch,01dh,01eh,01fh,020h,021h	; 59e3  ...... !

; ======================================================================
; CODIGO 0x59eb..0x5a8e  (163 bytes)
; ======================================================================


L_59EB:
	ld a,(0e1cdh)		;59eb
	cp 081h		;59ee
	jr nz,L_5A07		;59f0
	ld a,(0e33dh)		;59f2
	cp 00fh		;59f5
	jr nc,L_5A0A		;59f7
	ld a,(0e346h)		;59f9
	and 018h		;59fc
	jr nz,L_5A0A		;59fe
	ld a,(0e058h)		;5a00
	and 0f8h		;5a03
	jr z,L_5A0A		;5a05
L_5A07:
	xor a			;5a07
	jr L_5A0C		;5a08
L_5A0A:
	ld a,001h		;5a0a
L_5A0C:
	ld (0e340h),a		;5a0c
	ret			;5a0f
L_5A10:
	ld a,(0e208h)		;5a10
	ld b,a			;5a13
	ld de,0e14ch		;5a14
L_5A17:
	push bc			;5a17
	ld a,(0e1beh)		;5a18
	inc a			;5a1b
	ld b,a			;5a1c
	ld hl,0e15eh		;5a1d
L_5A20:
	ld a,(de)			;5a20
	cp (hl)			;5a21
	jr z,L_5A32		;5a22
	inc hl			;5a24
	djnz L_5A20		;5a25
	inc de			;5a27
	pop bc			;5a28
	djnz L_5A17		;5a29
L_5A2B:
	call reparte_una_ficha		;5a2b
	ld (0e22bh),a		;5a2e
	ret			;5a31
L_5A32:
	pop bc			;5a32
	ld (0e22bh),a		;5a33
	call reparte_una_ficha		;5a36
	ld (de),a			;5a39
	ld a,(0e208h)		;5a3a
	inc a			;5a3d
	ld b,a			;5a3e
	ld hl,0e14ch		;5a3f
	call L_4F9B		;5a42
	ret			;5a45
L_5A46:
	call L_708B		;5a46
	call pinta_la_barra_de_arriba		;5a49
	call L_7097		;5a4c
	call L_5A67		;5a4f
	ld a,(0e302h)		;5a52
	bit 1,a		;5a55
	ld de,0e1cdh		;5a57
	jr z,L_5A5F		;5a5a
	ld de,0e1aeh		;5a5c
L_5A5F:
	ld a,(de)			;5a5f
	rra			;5a60
	jp nc,L_7018		;5a61
	jp L_701E		;5a64
L_5A67:
	ld hl,05a8eh		;5a67
	call L_409D		;5a6a
	ld hl,0e04ch		;5a6d
	ld a,(hl)			;5a70
	inc hl			;5a71
	rra			;5a72
	jr nc,L_5A81		;5a73
	ld a,(hl)			;5a75
	rra			;5a76
	ld hl,05ad2h		;5a77
	jr nc,L_5A8B		;5a7a
	ld hl,05ae0h		;5a7c
	jr L_5A8B		;5a7f
L_5A81:
	ld a,(hl)			;5a81
	rra			;5a82
	ld hl,05ab6h		;5a83
	jr nc,L_5A8B		;5a86
	ld hl,05ac4h		;5a88
L_5A8B:
	jp L_409D		;5a8b

; ----------------------------------------------------------------------
; DATOS marcador_de_la_mano: Formato A desde 0x5A6A: seis destinos entre las
;   filas 8 y 14.
;   0x5a8e..0x5ab6  (40 bytes)
DATA_marcador_de_la_mano:
	defb 034h,039h,0d9h,0deh,0feh,04eh,039h,0cch,0d2h,001h,0d8h,0deh,001h,0d8h,0deh,0feh	; 5a8e  49...N9.........
	defb 06eh,039h,0cdh,0d3h,0feh,08dh,039h,072h,07eh,07fh,0feh,0ach,039h,073h,078h,084h	; 5a9e  n9....9r~...9sx.
	defb 085h,0feh,0cdh,039h,079h,08ah,08bh,0ffh	; 5aae  ...9y...

; ----------------------------------------------------------------------
; DATOS contador_0: Formato A: cuatro tiles en las filas 10 y 11, columna 10.
;   0x5ab6..0x5ac4  (14 bytes)
DATA_contador_0:
	defb 04ah,039h,0a8h,0aeh,09ch,0a2h,0feh,06ah,039h,0a9h,0afh,09dh,0a3h,0ffh	; 5ab6  J9.....j9.....

; ----------------------------------------------------------------------
; DATOS contador_1: Formato A desde 0x5A8B, mismas dos filas.
;   0x5ac4..0x5ad2  (14 bytes)
DATA_contador_1:
	defb 04ah,039h,0a8h,0aeh,090h,096h,0feh,06ah,039h,0a9h,0afh,091h,097h,0ffh	; 5ac4  J9.....j9.....

; ----------------------------------------------------------------------
; DATOS contador_2: Formato A, mismas dos filas.
;   0x5ad2..0x5ae0  (14 bytes)
DATA_contador_2:
	defb 04ah,039h,0b4h,0bah,09ch,0a2h,0feh,06ah,039h,0b5h,0bbh,09dh,0a3h,0ffh	; 5ad2  J9.....j9.....

; ----------------------------------------------------------------------
; DATOS contador_3: Formato A, mismas dos filas.
;   0x5ae0..0x5aee  (14 bytes)
DATA_contador_3:
	defb 04ah,039h,0b4h,0bah,090h,096h,0feh,06ah,039h,0b5h,0bbh,091h,097h,0ffh	; 5ae0  J9.....j9.....

; ======================================================================
; CODIGO 0x5aee..0x5c97  (425 bytes)
; ======================================================================


L_5AEE:
	ld a,(0e1c8h)		;5aee
	rra			;5af1
	jr c,L_5B01		;5af2
	rra			;5af4
	jp c,L_7356		;5af5
	rra			;5af8
	jr c,L_5B43		;5af9
	rra			;5afb
	jr c,L_5B46		;5afc
	rra			;5afe
	jr c,L_5B4E		;5aff
L_5B01:
	call L_70BF		;5b01
	ld a,(0e1a8h)		;5b04
	bit 2,a		;5b07
	ret nz			;5b09
	ld hl,0e127h		;5b0a
	ld (hl),000h		;5b0d
	ld de,0e305h		;5b0f
	ld b,020h		;5b12
L_5B14:
	ld a,(de)			;5b14
	dec a			;5b15
	cp 00bh		;5b16
	jr nc,L_5B1E		;5b18
	inc (hl)			;5b1a
	inc de			;5b1b
	djnz L_5B14		;5b1c
L_5B1E:
	ld a,(hl)			;5b1e
	or a			;5b1f
	jr nz,L_5B57		;5b20
	ld a,(0e316h)		;5b22
	cp 005h		;5b25
	jp nc,L_5B6B		;5b27
	call L_5C5A		;5b2a
	cp 008h		;5b2d
	jp z,L_5B6B		;5b2f
	ld a,(0e04eh)		;5b32
	rra			;5b35
	ld hl,05c97h		;5b36
	jr nc,L_5B3E		;5b39
	ld hl,05ca9h		;5b3b
L_5B3E:
	call L_5C70		;5b3e
	jr L_5B85		;5b41
L_5B43:
	jp L_7320		;5b43
L_5B46:
	call L_82F9		;5b46
	call L_72B8		;5b49
	jr L_5B51		;5b4c
L_5B4E:
	jp L_7176		;5b4e
L_5B51:
	ld hl,0e1c8h		;5b51
	srl (hl)		;5b54
	ret			;5b56
L_5B57:
	ld (0e1b3h),a		;5b57
	dec a			;5b5a
	add a,a			;5b5b
	ld hl,0e04eh		;5b5c
	bit 0,(hl)		;5b5f
	ld hl,05d6fh		;5b61
	jr z,L_5B85		;5b64
	ld hl,05d79h		;5b66
	jr L_5B85		;5b69
L_5B6B:
	cp 00dh		;5b6b
	jr c,L_5B71		;5b6d
	ld a,00dh		;5b6f
L_5B71:
	sub 004h		;5b71
	ld (0e1b4h),a		;5b73
	dec a			;5b76
	add a,a			;5b77
	ld hl,0e04eh		;5b78
	bit 0,(hl)		;5b7b
	ld hl,05d4bh		;5b7d
	jr z,L_5B85		;5b80
	ld hl,05d5dh		;5b82
L_5B85:
	call L_5C7F		;5b85
	ld (0e1b1h),de		;5b88
	ld (0e1e4h),de		;5b8c
	ld de,038e8h		;5b90
	ld hl,0e1e5h		;5b93
	ld b,003h		;5b96
	call pinta_un_numero_bcd		;5b98
	ld a,(0e1d1h)		;5b9b
	rra			;5b9e
	ret nc			;5b9f
	ld a,(0e1b3h)		;5ba0
	or a			;5ba3
	jr nz,L_5BCD		;5ba4
	ld a,(0e1b4h)		;5ba6
	or a			;5ba9
	jr nz,L_5BD4		;5baa
	call L_5C5A		;5bac
	ld hl,05d83h		;5baf
	call L_5C70		;5bb2
L_5BB5:
	call suma_a_a_hl		;5bb5
	ld e,(hl)			;5bb8
	inc hl			;5bb9
	ld d,(hl)			;5bba
	ld a,(0e04bh)		;5bbb
	add a,e			;5bbe
	daa			;5bbf
	ld e,a			;5bc0
	jr nc,L_5BC8		;5bc1
	ld a,d			;5bc3
	add a,001h		;5bc4
	daa			;5bc6
	ld d,a			;5bc7
L_5BC8:
	ld (0e1b1h),de		;5bc8
	ret			;5bcc
L_5BCD:
	dec a			;5bcd
	add a,a			;5bce
	ld hl,05defh		;5bcf
	jr L_5BD9		;5bd2
L_5BD4:
	dec a			;5bd4
	add a,a			;5bd5
	ld hl,05dddh		;5bd6
L_5BD9:
	jr L_5BB5		;5bd9
L_5BDB:
	ld a,(0e1e8h)		;5bdb
	ld c,a			;5bde
	cp 030h		;5bdf
	ret nc			;5be1
	ld a,(0e2c8h)		;5be2
	or a			;5be5
	ret z			;5be6
	ld b,a			;5be7
	ld de,0e2b7h		;5be8
L_5BEB:
	ld a,(de)			;5beb
	ld h,a			;5bec
	inc de			;5bed
	inc de			;5bee
	cp c			;5bef
	ld a,(de)			;5bf0
	jr z,L_5C0F		;5bf1
	cp c			;5bf3
	jr nz,L_5C00		;5bf4
	ld a,h			;5bf6
	and 00fh		;5bf7
	dec a			;5bf9
	jr nz,L_5C15		;5bfa
L_5BFC:
	ld hl,0e127h		;5bfc
	inc (hl)			;5bff
L_5C00:
	inc de			;5c00
	inc de			;5c01
	djnz L_5BEB		;5c02
	ld a,(0e127h)		;5c04
	or a			;5c07
	ret z			;5c08
	ld hl,0e1d2h		;5c09
	set 2,(hl)		;5c0c
	ret			;5c0e
L_5C0F:
	and 00fh		;5c0f
	cp 009h		;5c11
	jr z,L_5BFC		;5c13
L_5C15:
	ld hl,0e1d2h		;5c15
	set 0,(hl)		;5c18
	ret			;5c1a
L_5C1B:
	ld a,(0e1d2h)		;5c1b
	or a			;5c1e
	ret nz			;5c1f
	ld a,(0e1e8h)		;5c20
	ld c,a			;5c23
	cp 030h		;5c24
	ret nc			;5c26
	ld a,(0e2c8h)		;5c27
	or a			;5c2a
	ret z			;5c2b
	ld b,a			;5c2c
	ld de,0e2b8h		;5c2d
L_5C30:
	ld a,(de)			;5c30
	cp c			;5c31
	jr z,L_5C3C		;5c32
	ld a,004h		;5c34
	call suma_a_a_de		;5c36
	djnz L_5C30		;5c39
	ret			;5c3b
L_5C3C:
	ld hl,0e1d2h		;5c3c
	set 1,(hl)		;5c3f
	ret			;5c41
L_5C42:
	ld a,(0e1d2h)		;5c42
	or a			;5c45
	ret nz			;5c46
	ld a,(0e1e8h)		;5c47
	ld c,a			;5c4a
	ld a,(0e300h)		;5c4b
	cp c			;5c4e
	ld hl,0e1d2h		;5c4f
	jr z,L_5C57		;5c52
	set 4,(hl)		;5c54
	ret			;5c56
L_5C57:
	set 3,(hl)		;5c57
	ret			;5c59
L_5C5A:
	ld de,(0e1e1h)		;5c5a
	ld a,d			;5c5e
	or a			;5c5f
	jr z,L_5C65		;5c60
	ld a,008h		;5c62
	ret			;5c64
L_5C65:
	srl e		;5c65
	srl e		;5c67
	srl e		;5c69
	srl e		;5c6b
	dec e			;5c6d
	dec e			;5c6e
	ret			;5c6f
L_5C70:
	ld a,e			;5c70
	add a,a			;5c71
	call suma_a_a_hl		;5c72
	ld e,(hl)			;5c75
	inc hl			;5c76
	ld d,(hl)			;5c77
	ex de,hl			;5c78
	ld a,(0e316h)		;5c79
	dec a			;5c7c
	add a,a			;5c7d
	ret			;5c7e
L_5C7F:
	call suma_a_a_hl		;5c7f
	ld e,(hl)			;5c82
	inc hl			;5c83
	ld d,(hl)			;5c84
	ld a,(0e04bh)		;5c85
	ld c,a			;5c88
	add a,a			;5c89
	daa			;5c8a
	adc a,c			;5c8b
	daa			;5c8c
	adc a,e			;5c8d
	daa			;5c8e
	ld e,a			;5c8f
	ret nc			;5c90
	ld a,d			;5c91
	add a,001h		;5c92
	daa			;5c94
	ld d,a			;5c95
	ret			;5c96

; ----------------------------------------------------------------------
; DATOS punteros_de_puntuacion_del_que_reparte: Nueve palabras, 0x5CBB a
;   0x5CFB de ocho en ocho. 0x5B36 las usa cuando el bit 0 de 0xE04E esta a
;   cero.
;   0x5c97..0x5ca9  (18 bytes)
DATA_punteros_de_puntuacion_del_que_reparte:
	defb 0bbh,05ch	; 5c97
	defb 0c3h,05ch	; 5c99
	defb 0cbh,05ch	; 5c9b
	defb 0d3h,05ch	; 5c9d
	defb 0dbh,05ch	; 5c9f
	defb 0e3h,05ch	; 5ca1
	defb 0ebh,05ch	; 5ca3
	defb 0f3h,05ch	; 5ca5
	defb 0fbh,05ch	; 5ca7

; ----------------------------------------------------------------------
; DATOS punteros_de_puntuacion_del_resto: Las otras nueve, 0x5D03 a 0x5D43.
;   Las usa 0x5B3B.
;   0x5ca9..0x5cbb  (18 bytes)
DATA_punteros_de_puntuacion_del_resto:
	defb 003h,05dh	; 5ca9
	defb 00bh,05dh	; 5cab
	defb 013h,05dh	; 5cad
	defb 01bh,05dh	; 5caf
	defb 023h,05dh	; 5cb1
	defb 02bh,05dh	; 5cb3
	defb 033h,05dh	; 5cb5
	defb 03bh,05dh	; 5cb7
	defb 043h,05dh	; 5cb9

; ----------------------------------------------------------------------
; DATOS pagos_del_que_reparte: Nueve filas de cuatro palabras: el pago por 1,
;   2, 3 y 4 han. 20 fu da 0/2.000/3.900/7.700; 30 fu da
;   1.500/2.900/5.800/11.600; y asi hasta 90 fu. La novena fila es 12.000 en
;   las cuatro, el tope del que reparte.
;   0x5cbb..0x5d03  (72 bytes)
DATA_pagos_del_que_reparte:
	defb 000h,000h,020h,000h,039h,000h,077h,000h	; 5cbb  .. .9.w.
	defb 015h,000h,029h,000h,058h,000h,016h,001h	; 5cc3  ..).X...
	defb 020h,000h,039h,000h,077h,000h,020h,001h	; 5ccb   .9.w. .
	defb 024h,000h,048h,000h,096h,000h,020h,001h	; 5cd3  $.H... .
	defb 029h,000h,058h,000h,016h,001h,020h,001h	; 5cdb  ).X... .
	defb 034h,000h,068h,000h,020h,001h,020h,001h	; 5ce3  4.h. . .
	defb 039h,000h,077h,000h,020h,001h,020h,001h	; 5ceb  9.w. . .
	defb 044h,000h,087h,000h,020h,001h,020h,001h	; 5cf3  D... . .
	defb 020h,001h,020h,001h,020h,001h,020h,001h	; 5cfb   . . . .

; ----------------------------------------------------------------------
; DATOS pagos_del_resto: Las mismas nueve filas para quien no reparte: 20 fu
;   da 0/1.300/2.600/5.200, 30 fu da 1.000/2.000/3.900/7.700, y el tope es
;   8.000.
;   0x5d03..0x5d4b  (72 bytes)
DATA_pagos_del_resto:
	defb 000h,000h,013h,000h,026h,000h,052h,000h	; 5d03  ....&.R.
	defb 010h,000h,020h,000h,039h,000h,077h,000h	; 5d0b  .. .9.w.
	defb 013h,000h,026h,000h,052h,000h,080h,000h	; 5d13  ..&.R...
	defb 016h,000h,032h,000h,064h,000h,080h,000h	; 5d1b  ..2.d...
	defb 020h,000h,039h,000h,077h,000h,080h,000h	; 5d23   .9.w...
	defb 023h,000h,045h,000h,080h,000h,080h,000h	; 5d2b  #.E.....
	defb 026h,000h,052h,000h,080h,000h,080h,000h	; 5d33  &.R.....
	defb 029h,000h,058h,000h,080h,000h,080h,000h	; 5d3b  ).X.....
	defb 080h,000h,080h,000h,080h,000h,080h,000h	; 5d43  ........

; ----------------------------------------------------------------------
; DATOS topes_del_que_reparte: Nueve palabras: 12.000, 18.000, 18.000, 24.000,
;   24.000, 24.000, 36.000, 36.000 y 36.000. Los cuatro escalones de mano
;   limite, cada uno repetido las veces que hace falta para que el indice de
;   han caiga en el suyo. La lee 0x5B7D.
;   0x5d4b..0x5d5d  (18 bytes)
DATA_topes_del_que_reparte:
	defb 020h,001h	; 5d4b
	defb 080h,001h	; 5d4d
	defb 080h,001h	; 5d4f
	defb 040h,002h	; 5d51
	defb 040h,002h	; 5d53
	defb 040h,002h	; 5d55
	defb 060h,003h	; 5d57
	defb 060h,003h	; 5d59
	defb 060h,003h	; 5d5b

; ----------------------------------------------------------------------
; DATOS topes_del_resto: Las mismas nueve, para quien no reparte: 8.000,
;   12.000, 12.000, 16.000, 16.000, 16.000, 24.000, 24.000 y 24.000. La lee
;   0x5B82.
;   0x5d5d..0x5d6f  (18 bytes)
DATA_topes_del_resto:
	defb 080h,000h	; 5d5d
	defb 020h,001h	; 5d5f
	defb 020h,001h	; 5d61
	defb 060h,001h	; 5d63
	defb 060h,001h	; 5d65
	defb 060h,001h	; 5d67
	defb 040h,002h	; 5d69
	defb 040h,002h	; 5d6b
	defb 040h,002h	; 5d6d

; ----------------------------------------------------------------------
; DATOS mano_maxima_del_que_reparte: Cinco palabras: 48.000, 96.000, 144.000,
;   192.000 y 240.000, o sea de una a cinco manos maximas. La lee 0x5B61.
;   0x5d6f..0x5d79  (10 bytes)
DATA_mano_maxima_del_que_reparte:
	defb 080h,004h	; 5d6f
	defb 060h,009h	; 5d71
	defb 040h,014h	; 5d73
	defb 020h,019h	; 5d75
	defb 000h,024h	; 5d77

; ----------------------------------------------------------------------
; DATOS mano_maxima_del_resto: 32.000, 64.000, 96.000, 128.000 y 160.000. La
;   lee 0x5B66.
;   0x5d79..0x5d83  (10 bytes)
DATA_mano_maxima_del_resto:
	defb 020h,003h	; 5d79
	defb 040h,006h	; 5d7b
	defb 060h,009h	; 5d7d
	defb 080h,012h	; 5d7f
	defb 000h,016h	; 5d81

; ----------------------------------------------------------------------
; DATOS punteros_de_pago_al_robar: Nueve palabras, 0x5D95 a 0x5DD5 de ocho en
;   ocho. La lee 0x5BAF.
;   0x5d83..0x5d95  (18 bytes)
DATA_punteros_de_pago_al_robar:
	defb 095h,05dh	; 5d83
	defb 09dh,05dh	; 5d85
	defb 0a5h,05dh	; 5d87
	defb 0adh,05dh	; 5d89
	defb 0b5h,05dh	; 5d8b
	defb 0bdh,05dh	; 5d8d
	defb 0c5h,05dh	; 5d8f
	defb 0cdh,05dh	; 5d91
	defb 0d5h,05dh	; 5d93

; ----------------------------------------------------------------------
; DATOS pagos_al_robar: Nueve filas de cuatro palabras con lo que paga CADA
;   jugador cuando se gana robando: 0/700/1.300/2.600 a 20 fu,
;   500/1.000/2.000/3.900 a 30 fu, y el tope en 4.000.
;   0x5d95..0x5ddd  (72 bytes)
DATA_pagos_al_robar:
	defb 000h,000h,007h,000h,013h,000h,026h,000h	; 5d95  ......&.
	defb 005h,000h,010h,000h,020h,000h,039h,000h	; 5d9d  .... .9.
	defb 007h,000h,013h,000h,026h,000h,040h,000h	; 5da5  ....&.@.
	defb 008h,000h,016h,000h,032h,000h,040h,000h	; 5dad  ....2.@.
	defb 010h,000h,020h,000h,039h,000h,040h,000h	; 5db5  .. .9.@.
	defb 012h,000h,023h,000h,040h,000h,040h,000h	; 5dbd  ..#.@.@.
	defb 013h,000h,026h,000h,040h,000h,040h,000h	; 5dc5  ..&.@.@.
	defb 015h,000h,030h,000h,040h,000h,040h,000h	; 5dcd  ..0.@.@.
	defb 018h,000h,036h,000h,040h,000h,040h,000h	; 5dd5  ..6.@.@.

; ----------------------------------------------------------------------
; DATOS topes_al_robar: Nueve palabras: 4.000, 6.000, 6.000, 8.000, 8.000,
;   8.000, 12.000, 12.000 y 12.000. Es la parte que le toca al que reparte en
;   las manos limite. La lee 0x5BD6.
;   0x5ddd..0x5def  (18 bytes)
DATA_topes_al_robar:
	defb 040h,000h	; 5ddd
	defb 060h,000h	; 5ddf
	defb 060h,000h	; 5de1
	defb 080h,000h	; 5de3
	defb 080h,000h	; 5de5
	defb 080h,000h	; 5de7
	defb 020h,001h	; 5de9
	defb 020h,001h	; 5deb
	defb 020h,001h	; 5ded

; ----------------------------------------------------------------------
; DATOS mano_maxima_al_robar: Cinco palabras: 16.000, 32.000, 48.000, 64.000 y
;   80.000. La lee 0x5BCF.
;   0x5def..0x5df9  (10 bytes)
DATA_mano_maxima_al_robar:
	defb 060h,001h	; 5def
	defb 020h,003h	; 5df1
	defb 080h,004h	; 5df3
	defb 040h,006h	; 5df5
	defb 000h,008h	; 5df7

; ======================================================================
; CODIGO 0x5df9..0x6560  (1895 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; EL PAGO, cien puntos por fotograma. Lleva DOS pendientes en paralelo, 0xE1B1 y 0xE1E4, cada uno un contador BCD de dos bytes que cuenta PASOS DE CIEN: los 0x0120 y 0x0080 que carga 0x4290 son 12.000 y 8.000 puntos. Cada fotograma quita cien de un marcador y los pone en el otro, y baja el pendiente en uno con 0x5F18. Quien cobra y quien paga sale de 0xE302, 0xE1AC y 0xE1AD. El segundo pendiente ademas suena cada cuatro fotogramas: es el tintineo del recuento.
; ----------------------------------------------------------------------
mueve_cien_puntos:
	ld hl,(0e1b1h)		;5df9   ; el primer pendiente
	ld a,h			;5dfc
	or l			;5dfd   ; si esta a cero, no hay nada que mover por aqui
	jr z,L_5E2E		;5dfe
	ld de,00100h		;5e00   ; cien puntos, en BCD
	ld a,(0e302h)		;5e03
	bit 2,a		;5e06   ; bit 2 de 0xE302: quien tiene el turno
	jr nz,L_5E10		;5e08
	rra			;5e0a
	rra			;5e0b
	jr nc,L_5E1D		;5e0c
	jr L_5E22		;5e0e
L_5E10:
	ld a,(0e1ach)		;5e10
	and 0c0h		;5e13
	jr nz,L_5E22		;5e15
	ld a,(0e1adh)		;5e17
	rra			;5e1a
	jr nc,L_5E22		;5e1b
L_5E1D:
	call resta_del_marcador_de_e044		;5e1d   ; cobra el jugador de 0xE044
	jr L_5E25		;5e20
L_5E22:
	call resta_del_marcador_de_e047		;5e22   ; cobra el jugador de 0xE047
L_5E25:
	ld hl,(0e1b1h)		;5e25
	call baja_un_paso_bcd		;5e28   ; y el pendiente baja un paso, o sea cien puntos
	ld (0e1b1h),hl		;5e2b
L_5E2E:
	ld hl,(0e1e4h)		;5e2e   ; el segundo pendiente, con el mismo mecanismo
	ld a,h			;5e31
	or l			;5e32
	jr z,L_5E70		;5e33
	ld a,(0e003h)		;5e35
	and 003h		;5e38   ; uno de cada cuatro fotogramas
	jr nz,L_5E41		;5e3a
	ld a,002h		;5e3c
	call L_9C4A		;5e3e   ; sonido 2: el tintineo de las fichas de puntos
L_5E41:
	ld de,00100h		;5e41
	ld a,(0e302h)		;5e44
	bit 2,a		;5e47
	jr nz,L_5E51		;5e49
	rra			;5e4b
	rra			;5e4c
	jr nc,L_5E5E		;5e4d
	jr L_5E63		;5e4f
L_5E51:
	ld a,(0e1ach)		;5e51
	and 0c0h		;5e54
	jr nz,L_5E63		;5e56
	ld a,(0e1adh)		;5e58
	rra			;5e5b
	jr nc,L_5E63		;5e5c
L_5E5E:
	call suma_al_marcador_de_e047		;5e5e
	jr L_5E66		;5e61
L_5E63:
	call suma_al_marcador_de_e044		;5e63
L_5E66:
	ld hl,(0e1e4h)		;5e66
	call baja_un_paso_bcd		;5e69
	ld (0e1e4h),hl		;5e6c
	ret			;5e6f
L_5E70:
	ld a,(0e002h)		;5e70   ; sin nada pendiente: si no hay persona jugando, por 0x5F00
	bit 6,a		;5e73
	jp z,L_5F00		;5e75
	ld a,(0e302h)		;5e78
	and 005h		;5e7b
	jr nz,L_5ED0		;5e7d
	ld hl,0e04ah		;5e7f
	ld a,(hl)			;5e82
	or a			;5e83
	jr z,L_5ED0		;5e84
	ld a,(0e003h)		;5e86
	and 01fh		;5e89
	ret nz			;5e8b
	ld a,(0e302h)		;5e8c
	bit 1,a		;5e8f
	jr nz,L_5EA4		;5e91
	ld a,(0e04ch)		;5e93
	rra			;5e96
	jr nc,L_5E9F		;5e97
	ld a,(0e04dh)		;5e99
	rra			;5e9c
	jr c,L_5EAA		;5e9d
L_5E9F:
	ld a,(0e1cdh)		;5e9f
	jr L_5EA7		;5ea2
L_5EA4:
	ld a,(0e1aeh)		;5ea4
L_5EA7:
	rra			;5ea7
	jr nc,L_5ED0		;5ea8
L_5EAA:
	ld a,(hl)			;5eaa
	sub 001h		;5eab
	daa			;5ead
	ld (hl),a			;5eae
	call pinta_el_contador_de_e04a		;5eaf
	ld a,002h		;5eb2
	call L_9C4A		;5eb4
	ld b,00ah		;5eb7
L_5EB9:
	push bc			;5eb9
	ld de,00100h		;5eba
	ld a,(0e302h)		;5ebd
	bit 1,a		;5ec0
	jr nz,L_5EC9		;5ec2
	call suma_al_marcador_de_e047		;5ec4
	jr L_5ECC		;5ec7
L_5EC9:
	call suma_al_marcador_de_e044		;5ec9
L_5ECC:
	pop bc			;5ecc
	djnz L_5EB9		;5ecd
	ret			;5ecf
L_5ED0:
	ld a,(0e302h)		;5ed0
	and 005h		;5ed3
	jr nz,L_5F12		;5ed5
	ld a,(0e302h)		;5ed7
	rra			;5eda
	rra			;5edb
	ld hl,0e062h		;5edc
	jr nc,L_5EF2		;5edf
	inc (hl)			;5ee1
	ld a,(0e04dh)		;5ee2
	rra			;5ee5
	jr c,L_5F0F		;5ee6
	ld hl,0e04bh		;5ee8
	ld (hl),000h		;5eeb
	call L_77F7		;5eed
	jr L_5F12		;5ef0
L_5EF2:
	ld (hl),000h		;5ef2
	ld a,(0e04dh)		;5ef4
	rra			;5ef7
	jr nc,L_5F0F		;5ef8
	ld a,(0e04ch)		;5efa
	rra			;5efd
	jr nc,L_5F05		;5efe
L_5F00:
	ld hl,0e1a8h		;5f00
	set 4,(hl)		;5f03
L_5F05:
	ld hl,0e04bh		;5f05
	ld (hl),000h		;5f08
	call L_77EF		;5f0a
	jr L_5F12		;5f0d
L_5F0F:
	call L_780A		;5f0f
L_5F12:
	ld hl,0e1a8h		;5f12
	res 3,(hl)		;5f15
	ret			;5f17

; ----------------------------------------------------------------------
; Resta uno en BCD al contador de dos bytes de HL. Es lo que gasta los pendientes de 0x5DF9, de cien en cien puntos.
; ----------------------------------------------------------------------
baja_un_paso_bcd:
	ld a,l			;5f18
	sub 001h		;5f19
	daa			;5f1b   ; daa: tambien aqui la cuenta es decimal
	ld l,a			;5f1c
	ret nc			;5f1d   ; sin acarreo no hay que tocar el byte alto
	ld a,h			;5f1e
	sub 001h		;5f1f
	daa			;5f21
	ld h,a			;5f22
	ret			;5f23

; ----------------------------------------------------------------------
; Mil puntos de golpe para el marcador de 0xE047: diez vueltas de cien. La hermana de abajo hace lo mismo con el otro. Mil es lo que cuesta el palo de riichi.
; ----------------------------------------------------------------------
cobra_mil_el_de_e047:
	ld b,00ah		;5f24
L_5F26:
	push bc			;5f26
	ld de,00100h		;5f27
	call resta_del_marcador_de_e047		;5f2a
	pop bc			;5f2d
	djnz L_5F26		;5f2e
	ret			;5f30

; ----------------------------------------------------------------------
; La gemela de 0x5F24 para el marcador de 0xE044: diez vueltas de cien puntos.
; ----------------------------------------------------------------------
cobra_mil_el_de_e044:
	ld b,00ah		;5f31
L_5F33:
	push bc			;5f33
	ld de,00100h		;5f34
	call resta_del_marcador_de_e044		;5f37
	pop bc			;5f3a
	djnz L_5F33		;5f3b
	ret			;5f3d
L_5F3E:
	call L_5F4C		;5f3e
	call L_6038		;5f41
	ld a,(0e302h)		;5f44
	rra			;5f47
	ret c			;5f48
	jp L_656D		;5f49
L_5F4C:
	ld a,(0e206h)		;5f4c
	rra			;5f4f
	ld a,(0e1d1h)		;5f50
	ld (0e22ch),a		;5f53
	ld a,(0e1c3h)		;5f56
	ld (0e20ah),a		;5f59
	jr nc,L_5F6A		;5f5c
	ld a,(0e208h)		;5f5e
	ld (0e20ah),a		;5f61
	ld a,(0e22ah)		;5f64
	ld (0e22ch),a		;5f67
L_5F6A:
	ld de,0e2feh		;5f6a
	ld hl,0e2bah		;5f6d
	ld bc,00403h		;5f70
	call L_5FFA		;5f73
	ld hl,0e2cch		;5f76
	ld bc,00403h		;5f79
	call L_5FFA		;5f7c
	call L_6019		;5f7f
	ld hl,0e2f1h		;5f82
	ld de,0e2f2h		;5f85
	ld bc,00039h		;5f88
	ld (hl),000h		;5f8b
	ldir		;5f8d
	xor a			;5f8f
	ld (0e347h),a		;5f90
	ld a,(0e20ah)		;5f93
	ld hl,0e32bh		;5f96
	call suma_a_a_hl		;5f99
	ld c,(hl)			;5f9c
	ld a,(0e22ch)		;5f9d
	or a			;5fa0
	jr nz,L_5FC7		;5fa1
	ld a,(0e206h)		;5fa3
	rra			;5fa6
	ld hl,0e172h		;5fa7
	ld a,(0e1bfh)		;5faa
	jr nc,L_5FB5		;5fad
	ld hl,0e15eh		;5faf
	ld a,(0e1beh)		;5fb2
L_5FB5:
	call suma_a_a_hl		;5fb5
	ld c,(hl)			;5fb8
	ld hl,0e32bh		;5fb9
	ld a,(0e20ah)		;5fbc
	call suma_a_a_hl		;5fbf
	ld (hl),c			;5fc2
	ld a,c			;5fc3
	ld (0e347h),a		;5fc4
L_5FC7:
	ld hl,0e1e8h		;5fc7
	ld (hl),c			;5fca
	ld hl,0e32bh		;5fcb
	ld de,0e2f1h		;5fce
	ld a,(0e20ah)		;5fd1
	ld c,a			;5fd4
	ld b,000h		;5fd5
	inc bc			;5fd7
	ldir		;5fd8
	ld a,(0e20ah)		;5fda
	inc a			;5fdd
	ld b,a			;5fde
	ld hl,0e2f1h		;5fdf
	call L_4F9B		;5fe2
	ld a,(0e347h)		;5fe5
	ld de,0e2f1h		;5fe8
	ld hl,0e2f2h		;5feb
	call L_6E6F		;5fee
	ld a,c			;5ff1
	cp 003h		;5ff2
	ret nz			;5ff4
	xor a			;5ff5
	ld (0e347h),a		;5ff6
	ret			;5ff9
L_5FFA:
	push bc			;5ffa
	push hl			;5ffb
	xor a			;5ffc
	cp (hl)			;5ffd
	jr nz,L_6008		;5ffe
	dec hl			;6000
	ld b,c			;6001
L_6002:
	ld (hl),a			;6002
	dec hl			;6003
	djnz L_6002		;6004
	jr L_6010		;6006
L_6008:
	dec hl			;6008
	ld b,c			;6009
L_600A:
	ld a,(hl)			;600a
	ld (de),a			;600b
	dec hl			;600c
	dec de			;600d
	djnz L_600A		;600e
L_6010:
	pop hl			;6010
	pop bc			;6011
	ld a,l			;6012
	add a,c			;6013
	inc a			;6014
	ld l,a			;6015
	djnz L_5FFA		;6016
	ret			;6018
L_6019:
	ld a,(0e2f0h)		;6019
	ld c,a			;601c
	add a,a			;601d
	add a,a			;601e
	add a,c			;601f
	ld hl,0e2dbh		;6020
	call suma_a_a_hl		;6023
	ld a,004h		;6026
	sub c			;6028
	or a			;6029
	ret z			;602a
	ld b,a			;602b
L_602C:
	push bc			;602c
	ld b,005h		;602d
L_602F:
	ld (hl),000h		;602f
	inc hl			;6031
	djnz L_602F		;6032
	pop bc			;6034
	djnz L_602C		;6035
	ret			;6037
L_6038:
	xor a			;6038
	ld (0e237h),a		;6039
	ld (0e239h),a		;603c
	ld (0e205h),a		;603f
L_6042:
	ld hl,0e2f1h		;6042
	ld a,(0e304h)		;6045
	ld de,0e2f1h		;6048
	call suma_a_a_de		;604b
	ld l,e			;604e
	inc l			;604f
	ld a,(de)			;6050
	cp (hl)			;6051
	jr z,L_6072		;6052
	ld a,(de)			;6054
	sub (hl)			;6055
	cp 0ffh		;6056
	jr nz,L_606D		;6058
	call L_620A		;605a
	jr nz,L_6064		;605d
	call L_6159		;605f
	jr L_6091		;6062
L_6064:
	cp 0ffh		;6064
	jr nz,L_60E0		;6066
	call L_6216		;6068
	jr L_6091		;606b
L_606D:
	call L_651D		;606d
	jr L_6091		;6070
L_6072:
	inc hl			;6072
	cp (hl)			;6073
	jr nz,L_6084		;6074
	inc hl			;6076
	cp (hl)			;6077
	jr z,L_607F		;6078
	call L_63F2		;607a
	jr L_6091		;607d
L_607F:
	call L_62D7		;607f
	jr L_6091		;6082
L_6084:
	sub (hl)			;6084
	cp 0ffh		;6085
	jr z,L_608E		;6087
	call L_64F8		;6089
	jr L_6091		;608c
L_608E:
	call L_6376		;608e
L_6091:
	ld a,(0e20ah)		;6091
	ld b,a			;6094
	ld c,a			;6095
	inc b			;6096
	dec c			;6097
	ld a,(0e302h)		;6098
	dec a			;609b
	jr z,L_60E0		;609c
	ld a,(0e304h)		;609e
	cp c			;60a1
	jp c,L_6042		;60a2
	cp b			;60a5
	jr z,L_60B4		;60a6
	ld a,(0e304h)		;60a8
	ld de,0e2f1h		;60ab
	call suma_a_a_de		;60ae
	call L_61DA		;60b1
L_60B4:
	ld a,(0e303h)		;60b4
	rra			;60b7
	rra			;60b8
	jr nc,L_60BE		;60b9
	ld (0e205h),a		;60bb
L_60BE:
	ld a,(0e205h)		;60be
	rra			;60c1
	jr nc,L_60C8		;60c2
	xor a			;60c4
	ld (0e303h),a		;60c5
L_60C8:
	ld hl,0e302h		;60c8
	res 1,(hl)		;60cb
	ld a,(0e206h)		;60cd
	rra			;60d0
	jr nc,L_60D5		;60d1
	set 1,(hl)		;60d3
L_60D5:
	ld a,(0e20ah)		;60d5
	inc a			;60d8
	ld (0e304h),a		;60d9
	ret			;60dc
L_60DD:
	jp L_6042		;60dd
L_60E0:
	ld a,(0e205h)		;60e0
	rra			;60e3
	jr c,L_60B4		;60e4
	xor a			;60e6
	ld hl,0e237h		;60e7
	cp (hl)			;60ea
	jr nz,L_60F5		;60eb
	ld a,001h		;60ed
	ld (0e302h),a		;60ef
	jp L_67AE		;60f2
L_60F5:
	dec (hl)			;60f5
	ld hl,0e239h		;60f6
	bit 0,(hl)		;60f9
	jr z,L_6108		;60fb
	res 0,(hl)		;60fd
	call L_612A		;60ff
	call L_63C1		;6102
	jp L_60DD		;6105
L_6108:
	bit 1,(hl)		;6108
	jr z,L_6121		;610a
	res 0,(hl)		;610c
	call L_612A		;610e
	call L_6386		;6111
	ld a,(de)			;6114
	push af			;6115
	ld a,006h		;6116
	call suma_a_a_de		;6118
	pop af			;611b
	inc a			;611c
	ld (de),a			;611d
	jp L_60DD		;611e
L_6121:
	call L_612A		;6121
	call L_6185		;6124
	jp L_60DD		;6127
L_612A:
	ld hl,0e237h		;612a
	ld a,(hl)			;612d
	ld hl,0e36eh		;612e
	or a			;6131
	jr z,L_6137		;6132
	ld hl,0e094h		;6134
L_6137:
	ld de,0e2f1h		;6137
	ld bc,00014h		;613a
	ldir		;613d
	ld hl,0e101h		;613f
	or a			;6142
	jr z,L_6148		;6143
	ld hl,0e06eh		;6145
L_6148:
	ld de,0e2b6h		;6148
	ld bc,00026h		;614b
	ldir		;614e
	ld a,(0e304h)		;6150
	ld de,0e2f1h		;6153
	jp suma_a_a_de		;6156
L_6159:
	ld a,(0e304h)		;6159
	cp 00eh		;615c
	ret z			;615e
	ld a,(de)			;615f
	cp 031h		;6160
	jp nc,L_60E0		;6162
	ld hl,0e2c8h		;6165
	inc (hl)			;6168
	ld a,(0e304h)		;6169
	add a,003h		;616c
	ld (0e304h),a		;616e
	ld hl,0e2b7h		;6171
	ld a,(0e2c8h)		;6174
	dec a			;6177
	add a,a			;6178
	add a,a			;6179
	add a,l			;617a
	ld l,a			;617b
	ld b,003h		;617c
	ld a,(de)			;617e
L_617F:
	ld (hl),a			;617f
	inc a			;6180
	inc hl			;6181
	djnz L_617F		;6182
	ret			;6184
L_6185:
	ld a,(0e304h)		;6185
	cp 00eh		;6188
	ret z			;618a
	ld hl,0e2dah		;618b
	inc (hl)			;618e
	ld a,(0e304h)		;618f
	add a,003h		;6192
	ld (0e304h),a		;6194
	ld hl,0e2c9h		;6197
	ld a,(0e2dah)		;619a
	dec a			;619d
	add a,a			;619e
	add a,a			;619f
	add a,l			;61a0
	ld l,a			;61a1
	ld b,003h		;61a2
	ld a,(de)			;61a4
L_61A5:
	ld (hl),a			;61a5
	inc hl			;61a6
	inc de			;61a7
	djnz L_61A5		;61a8
	push hl			;61aa
	ld hl,0e347h		;61ab
	cp (hl)			;61ae
	pop hl			;61af
	ret nz			;61b0
	ld a,001h		;61b1
	ld (hl),a			;61b3
	ld hl,0e2d9h		;61b4
	inc (hl)			;61b7
	ret			;61b8
L_61B9:
	ld hl,0e2f0h		;61b9
	inc (hl)			;61bc
	ld a,(0e304h)		;61bd
	add a,004h		;61c0
	ld (0e304h),a		;61c2
L_61C5:
	ld hl,0e2dbh		;61c5
	ld a,(0e2f0h)		;61c8
	dec a			;61cb
	ld c,a			;61cc
	add a,a			;61cd
	add a,a			;61ce
	add a,c			;61cf
	add a,l			;61d0
	ld l,a			;61d1
	ld b,004h		;61d2
	ld a,(de)			;61d4
L_61D5:
	ld (hl),a			;61d5
	inc hl			;61d6
	djnz L_61D5		;61d7
	ret			;61d9
L_61DA:
	ld a,(0e304h)		;61da
	cp 00eh		;61dd
	ret z			;61df
	ld a,(0e300h)		;61e0
	or a			;61e3
	jp nz,L_60E0		;61e4
	ld a,(de)			;61e7
	ld h,d			;61e8
	ld l,e			;61e9
	inc hl			;61ea
	cp (hl)			;61eb
	jp nz,L_60E0		;61ec
	ld (0e300h),a		;61ef
	ld (0e301h),a		;61f2
	inc de			;61f5
	inc de			;61f6
	ld a,(0e304h)		;61f7
	add a,002h		;61fa
	ld (0e304h),a		;61fc
	ret			;61ff
L_6200:
	inc hl			;6200
	ld a,(de)			;6201
	sub (hl)			;6202
	ret			;6203
L_6204:
	call L_6200		;6204
	cp 0ffh		;6207
	ret			;6209
L_620A:
	call L_6200		;620a
	cp 0feh		;620d
	ret			;620f
L_6210:
	call L_6200		;6210
	cp 0fdh		;6213
	ret			;6215
L_6216:
	call L_620A		;6216
	jr z,L_624D		;6219
	cp 0ffh		;621b
	jp nz,L_60E0		;621d
	call L_6204		;6220
	jr z,L_626D		;6223
	cp 0feh		;6225
	jp nz,L_60E0		;6227
	call L_620A		;622a
	jr nz,L_628E		;622d
	call L_620A		;622f
	jr nz,L_628E		;6232
	call L_6210		;6234
	jr nz,L_628E		;6237
	call L_6210		;6239
	jr nz,L_628E		;623c
	call L_6159		;623e
	inc de			;6241
	call L_6159		;6242
	call L_6159		;6245
	ld hl,0e303h		;6248
	inc (hl)			;624b
	ret			;624c
L_624D:
	call L_620A		;624d
	jp nz,L_60E0		;6250
	call L_6210		;6253
	jr nz,L_625F		;6256
	call L_6159		;6258
	inc de			;625b
	jp L_6159		;625c
L_625F:
	cp 0feh		;625f
	jp nz,L_60E0		;6261
	call L_6159		;6264
	inc de			;6267
	inc de			;6268
	ld a,(de)			;6269
	inc de			;626a
	ld (de),a			;626b
	ret			;626c
L_626D:
	call L_620A		;626d
	jp nz,L_60E0		;6270
	call L_620A		;6273
	jr nz,L_6283		;6276
L_6278:
	dec hl			;6278
	dec hl			;6279
	ld a,(hl)			;627a
	inc hl			;627b
	ld (hl),a			;627c
	call L_6159		;627d
	inc de			;6280
	jr L_6295		;6281
L_6283:
	cp 0fdh		;6283
	jr z,L_6278		;6285
L_6287:
	call L_6159		;6287
	inc de			;628a
	jp L_6185		;628b
L_628E:
	call L_6159		;628e
	inc de			;6291
	jp L_61DA		;6292
L_6295:
	ld a,(0e300h)		;6295
	or a			;6298
	jp nz,L_6185		;6299
	call L_62A5		;629c
	call L_61DA		;629f
	jp L_60DD		;62a2
L_62A5:
	ld hl,0e237h		;62a5
	inc (hl)			;62a8
	ld a,(hl)			;62a9
	ld hl,0e2f1h		;62aa
	ld de,0e36eh		;62ad
	cp 001h		;62b0
	jr z,L_62B7		;62b2
	ld de,0e094h		;62b4
L_62B7:
	ld bc,00014h		;62b7
	ldir		;62ba
	ld hl,0e2b6h		;62bc
	ld de,0e101h		;62bf
	cp 001h		;62c2
	jr z,L_62C9		;62c4
	ld de,0e06eh		;62c6
L_62C9:
	ld bc,00026h		;62c9
	ldir		;62cc
	ld a,(0e304h)		;62ce
	ld de,0e2f1h		;62d1
	jp suma_a_a_de		;62d4
L_62D7:
	call L_6204		;62d7
	jp nz,L_60E0		;62da
	call L_6204		;62dd
	jr z,L_62ED		;62e0
	cp 0feh		;62e2
	jp nz,L_60E0		;62e4
L_62E7:
	call L_6185		;62e7
	jp L_6159		;62ea
L_62ED:
	call L_6204		;62ed
	jr z,L_62F4		;62f0
	jr L_6295		;62f2
L_62F4:
	call L_6204		;62f4
	jr z,L_6332		;62f7
	cp 0feh		;62f9
	jp nz,L_60E0		;62fb
	call L_620A		;62fe
	jr z,L_630A		;6301
	call L_62E7		;6303
	inc de			;6306
	jp L_61DA		;6307
L_630A:
	call L_620A		;630a
	jr nz,L_635B		;630d
	call L_6210		;630f
	jr nz,L_6327		;6312
	call L_61DA		;6314
	call L_6159		;6317
	call L_6159		;631a
	inc de			;631d
	inc de			;631e
	call L_6159		;631f
	ld hl,0e303h		;6322
	inc (hl)			;6325
	ret			;6326
L_6327:
	cp 0feh		;6327
	jp nz,L_60E0		;6329
	call L_636D		;632c
	jp L_6185		;632f
L_6332:
	call L_620A		;6332
	jp nz,L_60E0		;6335
	call L_620A		;6338
	jr z,L_6344		;633b
	call L_62E7		;633d
	inc de			;6340
	jp L_6185		;6341
L_6344:
	call L_620A		;6344
	jp nz,L_6185		;6347
	call L_620A		;634a
	jp nz,L_6185		;634d
	call L_62E7		;6350
	inc de			;6353
	inc de			;6354
	call L_6185		;6355
	jp L_6185		;6358
L_635B:
	cp 0fdh		;635b
	jp nz,L_60E0		;635d
	call L_6200		;6360
	cp 0fch		;6363
	jr nz,L_636D		;6365
	call L_636D		;6367
	jp L_6159		;636a
L_636D:
	call L_62E7		;636d
	inc de			;6370
	call L_61DA		;6371
	inc de			;6374
	ret			;6375
L_6376:
	call L_6204		;6376
	jr nz,L_6391		;6379
	call L_620A		;637b
	jr nz,L_63A2		;637e
	call L_620A		;6380
	jp nz,L_60E0		;6383
L_6386:
	call L_6159		;6386
	call L_6159		;6389
	ld hl,0e303h		;638c
	inc (hl)			;638f
	ret			;6390
L_6391:
	cp 0feh		;6391
	jp nz,L_60E0		;6393
	call L_6210		;6396
	jp nz,L_61DA		;6399
	call L_61DA		;639c
	jp L_6159		;639f
L_63A2:
	cp 0ffh		;63a2
	jp nz,L_64F8		;63a4
	call L_6204		;63a7
	jr nz,L_63DD		;63aa
	call L_620A		;63ac
	jp nz,L_60E0		;63af
	call L_620A		;63b2
	jp nz,L_61DA		;63b5
	call L_620A		;63b8
	jr z,L_63C9		;63bb
	cp 0fdh		;63bd
	jr z,L_63C9		;63bf
L_63C1:
	call L_6386		;63c1
	inc de			;63c4
	inc de			;63c5
	jp L_61DA		;63c6
L_63C9:
	ld hl,0e239h		;63c9
	set 0,(hl)		;63cc
L_63CE:
	call L_62A5		;63ce
	call L_63D7		;63d1
	jp L_60DD		;63d4
L_63D7:
	call L_61DA		;63d7
	jp L_6185		;63da
L_63DD:
	cp 0feh		;63dd
	jr nz,L_63D7		;63df
	call L_620A		;63e1
	jr nz,L_63D7		;63e4
	call L_620A		;63e6
	jr nz,L_63D7		;63e9
	ld hl,0e239h		;63eb
	set 1,(hl)		;63ee
	jr L_63CE		;63f0
L_63F2:
	sub (hl)			;63f2
	cp 0ffh		;63f3
	jp nz,L_6185		;63f5
	call L_620A		;63f8
	jp nz,L_647D		;63fb
	call L_6210		;63fe
	jr nz,L_6441		;6401
	call L_6200		;6403
	cp 0fch		;6406
	jr nz,L_643B		;6408
	call L_6200		;640a
	cp 0fbh		;640d
	jr nz,L_643B		;640f
	call L_6200		;6411
	cp 0fah		;6414
	jr nz,L_6430		;6416
	call L_6200		;6418
	cp 0f9h		;641b
	jr nz,L_642B		;641d
	call L_6200		;641f
	cp 0f8h		;6422
	jr nz,L_642B		;6424
	call L_6430		;6426
	jr L_6436		;6429
L_642B:
	call L_643B		;642b
	jr L_6436		;642e
L_6430:
	call L_61DA		;6430
	call L_6159		;6433
L_6436:
	call L_64F3		;6436
	jr L_643E		;6439
L_643B:
	call L_6185		;643b
L_643E:
	jp L_6159		;643e
L_6441:
	cp 0feh		;6441
	jr nz,L_6477		;6443
	call L_620A		;6445
	jr nz,L_646F		;6448
	call L_6210		;644a
	jr nz,L_6455		;644d
	call L_6185		;644f
	jp L_628E		;6452
L_6455:
	cp 0feh		;6455
	jr nz,L_646F		;6457
	call L_6210		;6459
	jr nz,L_6464		;645c
	call L_6185		;645e
	jp L_6287		;6461
L_6464:
	call L_61DA		;6464
	call L_6159		;6467
	inc de			;646a
	inc de			;646b
	jp L_6185		;646c
L_646F:
	cp 0fdh		;646f
	jp nz,L_60E0		;6471
	jp L_6295		;6474
L_6477:
	call L_61DA		;6477
	jp L_6159		;647a
L_647D:
	cp 0ffh		;647d
	jp nz,L_60E0		;647f
	call L_6204		;6482
	jr nz,L_6496		;6485
	call L_6204		;6487
	jr z,L_64A1		;648a
	cp 0feh		;648c
	jr z,L_64B8		;648e
	call L_6185		;6490
	jp L_6185		;6493
L_6496:
	cp 0feh		;6496
	jp z,L_6295		;6498
	call L_6185		;649b
	jp L_61DA		;649e
L_64A1:
	call L_620A		;64a1
	jp nz,L_60E0		;64a4
	call L_6210		;64a7
	jr z,L_64C5		;64aa
	cp 0feh		;64ac
	jp z,L_6295		;64ae
L_64B1:
	call L_6477		;64b1
	inc de			;64b4
	jp L_6185		;64b5
L_64B8:
	call L_620A		;64b8
	jp nz,L_6185		;64bb
	cp 0fdh		;64be
	jp nz,L_6295		;64c0
	jr L_64B1		;64c3
L_64C5:
	call L_6200		;64c5
	cp 0fch		;64c8
	jr z,L_64D2		;64ca
L_64CC:
	call L_6185		;64cc
	jp L_643B		;64cf
L_64D2:
	call L_6200		;64d2
	cp 0fbh		;64d5
	jr nz,L_64E6		;64d7
	call L_6200		;64d9
	cp 0fah		;64dc
	jr z,L_64ED		;64de
	call L_64B1		;64e0
	jp L_6436		;64e3
L_64E6:
	cp 0fch		;64e6
	jp nz,L_60E0		;64e8
	jr L_64CC		;64eb
L_64ED:
	call L_6185		;64ed
	jp L_642B		;64f0
L_64F3:
	ld a,e			;64f3
	add a,003h		;64f4
	ld e,a			;64f6
	ret			;64f7
L_64F8:
	push de			;64f8
	ld a,(0e2b6h)		;64f9
	or a			;64fc
	jr nz,L_6519		;64fd
	ld hl,0e2f1h		;64ff
	ld de,0e2f2h		;6502
	ld b,007h		;6505
L_6507:
	ld a,(de)			;6507
	cp (hl)			;6508
	jr nz,L_6519		;6509
	inc hl			;650b
	inc hl			;650c
	cp (hl)			;650d
	jr z,L_6519		;650e
	inc de			;6510
	inc de			;6511
	djnz L_6507		;6512
	ld a,001h		;6514
	ld (0e205h),a		;6516
L_6519:
	pop de			;6519
	jp L_61DA		;651a
L_651D:
	ld a,(0e2b6h)		;651d
	or a			;6520
	jp nz,L_60E0		;6521
	ld de,0e2f1h		;6524
	ld hl,0e2f2h		;6527
	ld b,00dh		;652a
L_652C:
	ld a,(de)			;652c
	cp (hl)			;652d
	jr z,L_6537		;652e
	inc de			;6530
	inc hl			;6531
	djnz L_652C		;6532
	jp L_60E0		;6534
L_6537:
	ld a,(hl)			;6537
	ld (0e300h),a		;6538
	ld (0e301h),a		;653b
	ld a,039h		;653e
	ld (hl),a			;6540
	ld hl,0e2f1h		;6541
	call L_4F99		;6544
	ld b,00dh		;6547
	ld hl,06560h		;6549
	ld de,0e2f1h		;654c
L_654F:
	ld a,(de)			;654f
	cp (hl)			;6550
	jp nz,L_60E0		;6551
	inc de			;6554
	inc hl			;6555
	djnz L_654F		;6556
	ld a,002h		;6558
	ld (0e205h),a		;655a
	jp L_60B4		;655d

; ----------------------------------------------------------------------
; DATOS los_trece_terminales_y_honores: Los trece codigos que no son fichas de
;   en medio: 0x01 y 0x09, 0x11 y 0x19, 0x21 y 0x29 -el uno y el nueve de cada
;   palo- y los siete honores 0x31-0x37. La lee 0x6549.
;   0x6560..0x656d  (13 bytes)
DATA_los_trece_terminales_y_honores:
	defb 001h,009h,011h,019h,021h,029h,031h,032h,033h,034h,035h,036h,037h	; 6560  ....!)1234567

; ======================================================================
; CODIGO 0x656d..0x7376  (3593 bytes)
; ======================================================================


L_656D:
	ld a,(0e305h)		;656d
	or a			;6570
	ret nz			;6571
	ld de,0e2f1h		;6572
	ld a,(0e2c8h)		;6575
	or a			;6578
	jr z,L_6582		;6579
	ld hl,0e2b7h		;657b
	ld b,a			;657e
	call L_65B2		;657f
L_6582:
	ld a,(0e2dah)		;6582
	or a			;6585
	jr z,L_658F		;6586
	ld hl,0e2c9h		;6588
	ld b,a			;658b
	call L_65B2		;658c
L_658F:
	ld a,(0e2f0h)		;658f
	or a			;6592
	jr z,L_65A4		;6593
	ld hl,0e2dbh		;6595
	ld b,a			;6598
L_6599:
	push bc			;6599
	ld bc,00003h		;659a
	ldir		;659d
	inc hl			;659f
	inc hl			;65a0
	pop bc			;65a1
	djnz L_6599		;65a2
L_65A4:
	ld hl,0e300h		;65a4
	ld bc,00002h		;65a7
	ldir		;65aa
	ld hl,0e2f1h		;65ac
	jp L_4F99		;65af
L_65B2:
	push bc			;65b2
	ld bc,00003h		;65b3
	ldir		;65b6
	inc hl			;65b8
	pop bc			;65b9
	djnz L_65B2		;65ba
	ret			;65bc
L_65BD:
	ld a,(0e009h)		;65bd
	and 003h		;65c0
	ret z			;65c2
	ld c,a			;65c3
	ld a,(0e008h)		;65c4
	and 003h		;65c7
	xor c			;65c9
	ret z			;65ca
	ld b,a			;65cb
	ld a,004h		;65cc
	call L_9C4A		;65ce
	ld hl,(0e1c5h)		;65d1
	ld d,h			;65d4
	ld e,l			;65d5
	ld a,001h		;65d6
	call escribe_en_vram		;65d8
	ex de,hl			;65db
	ld a,b			;65dc
	rra			;65dd
	jr c,L_65F9		;65de
	ld a,020h		;65e0
	call suma_a_a_de		;65e2
	ld a,e			;65e5
	cp 0f9h		;65e6
	jr nz,L_65EF		;65e8
	ld a,0a0h		;65ea
	call resta_a_de_de		;65ec
L_65EF:
	ld h,d			;65ef
	ld l,e			;65f0
	ld (0e1c5h),hl		;65f1
	ld a,0eah		;65f4
	jp escribe_en_vram		;65f6
L_65F9:
	ld a,020h		;65f9
	call resta_a_de_de		;65fb
	ld a,e			;65fe
	cp 039h		;65ff
	jr nz,L_65EF		;6601
	ld a,0a0h		;6603
	call suma_a_a_de		;6605
	jr L_65EF		;6608
L_660A:
	ld hl,(0e1c5h)		;660a
	ld a,l			;660d
	and 0f0h		;660e
	ld h,001h		;6610
	cp 050h		;6612
	jr z,L_662A		;6614
	ld h,002h		;6616
	cp 070h		;6618
	jr z,L_662A		;661a
	ld h,004h		;661c
	cp 090h		;661e
	jr z,L_662A		;6620
	ld h,008h		;6622
	cp 0b0h		;6624
	jr z,L_662A		;6626
	ld h,010h		;6628
L_662A:
	ld a,(0e009h)		;662a
	and 020h		;662d
	ret z			;662f
	ld c,a			;6630
	ld a,(0e008h)		;6631
	and 020h		;6634
	ret nz			;6636
	ld a,h			;6637
	ld (0e1c7h),a		;6638
	ret			;663b
L_663C:
	ld hl,0e1c7h		;663c
	bit 1,(hl)		;663f
	jr nz,L_6653		;6641
	bit 2,(hl)		;6643
	jp nz,L_680B		;6645
	bit 3,(hl)		;6648
	jp nz,L_692F		;664a
	bit 4,(hl)		;664d
	jp nz,L_6C12		;664f
	ret			;6652
L_6653:
	ld a,(0e206h)		;6653
	rra			;6656
	jr c,L_6666		;6657
	ld a,(0e1beh)		;6659
	cp 012h		;665c
	jr z,L_66DA		;665e
	ld a,(0e33eh)		;6660
	rra			;6663
	jr c,L_66DA		;6664
L_6666:
	ld a,(0e2b6h)		;6666
	or a			;6669
	jr nz,L_66DA		;666a
	ld a,(0e22ch)		;666c
	rra			;666f
	jr nc,L_66DA		;6670
	ld hl,0e33eh		;6672
	set 0,(hl)		;6675
	ld a,078h		;6677
	ld (0e0b8h),a		;6679
	ld a,088h		;667c
	ld (0e0bch),a		;667e
	ld a,098h		;6681
	ld (0e0c0h),a		;6683
	ld a,088h		;6686
	ld (0e0c4h),a		;6688
	ld a,(0e206h)		;668b
	rra			;668e
	ld a,(0e1bfh)		;668f
	jr nc,L_66AB		;6692
	ld a,018h		;6694
	ld (0e0c8h),a		;6696
	ld a,028h		;6699
	ld (0e0cch),a		;669b
	ld a,038h		;669e
	ld (0e0d0h),a		;66a0
	ld a,028h		;66a3
	ld (0e0d4h),a		;66a5
	ld a,(0e1beh)		;66a8
L_66AB:
	ld a,(0e206h)		;66ab
	rra			;66ae
	jr c,L_66B8		;66af
	ld a,(0e1beh)		;66b1
	inc a			;66b4
	ld (0e1cch),a		;66b5
L_66B8:
	ld a,00ah		;66b8
	call L_9C4A		;66ba
	ld hl,0e0b8h		;66bd
	ld de,03b10h		;66c0
	ld a,(0e206h)		;66c3
	rra			;66c6
	jr nc,L_66CF		;66c7
	ld hl,0e0c8h		;66c9
	ld de,03b20h		;66cc
L_66CF:
	ld bc,00010h		;66cf
	call L_460B		;66d2
L_66D5:
	xor a			;66d5
	ld (0e1c7h),a		;66d6
	ret			;66d9
L_66DA:
	ld a,002h		;66da
	call pinta_uno_de_los_tres_dibujos		;66dc
	jr L_66D5		;66df
L_66E1:
	ld a,(0e20ah)		;66e1
	ld (0e209h),a		;66e4
L_66E7:
	ld c,000h		;66e7
	ld b,022h		;66e9
L_66EB:
	xor a			;66eb
	ld (0e128h),a		;66ec
	ld (0e347h),a		;66ef
	push bc			;66f2
	ld hl,0e1f5h		;66f3
	ld de,0e1f6h		;66f6
	ld a,(0e206h)		;66f9
	rra			;66fc
	jr nc,L_6705		;66fd
	ld hl,0e20eh		;66ff
	ld de,0e20fh		;6702
L_6705:
	ld (hl),000h		;6705
	ld bc,0000dh		;6707
	ldir		;670a
	pop bc			;670c
L_670D:
	push bc			;670d
	ld hl,0e2bah		;670e
	call L_67C2		;6711
	ld hl,0e2cch		;6714
	call L_67C2		;6717
	ld hl,0e2f1h		;671a
	ld de,0e2f2h		;671d
	ld bc,00013h		;6720
	ld (hl),000h		;6723
	ldir		;6725
	ld hl,0e32bh		;6727
	ld de,0e2f1h		;672a
	ld a,(0e20ah)		;672d
	inc a			;6730
	ld (0e12ah),a		;6731
	ld c,a			;6734
	ld b,000h		;6735
	ldir		;6737
	pop bc			;6739
	ld a,(0e209h)		;673a
	ld de,0e2f1h		;673d
	call suma_a_a_de		;6740
	ld hl,(0e382h)		;6743
	ld a,c			;6746
	cp 0ffh		;6747
	jr z,L_6754		;6749
	ld a,b			;674b
	sub 001h		;674c
	ld hl,04fbfh		;674e
	call suma_a_a_hl		;6751
L_6754:
	ld a,(hl)			;6754
	ld (de),a			;6755
	ld (0e129h),a		;6756
	push bc			;6759
	ld hl,0e2f1h		;675a
	ld a,(0e12ah)		;675d
	ld b,a			;6760
	call L_4F9B		;6761
	call L_6038		;6764
	pop bc			;6767
	ld a,(0e302h)		;6768
	rra			;676b
	jr c,L_678B		;676c
	ld a,(0e206h)		;676e
	rra			;6771
	ld hl,0e1f5h		;6772
	jr nc,L_677A		;6775
	ld hl,0e20eh		;6777
L_677A:
	ld a,(0e128h)		;677a
	call suma_a_a_hl		;677d
	ld a,(0e129h)		;6780
	ld (hl),a			;6783
	ld a,(0e128h)		;6784
	inc a			;6787
	ld (0e128h),a		;6788
L_678B:
	djnz L_670D		;678b
	ld a,(0e128h)		;678d
	or a			;6790
	jr z,L_679E		;6791
	ld a,(0e206h)		;6793
	rra			;6796
	jr c,L_679E		;6797
	ld hl,0e1cdh		;6799
	set 7,(hl)		;679c
L_679E:
	ld a,c			;679e
	or a			;679f
	ret nz			;67a0
L_67A1:
	ld hl,0e2f1h		;67a1
	ld de,0e2f2h		;67a4
	ld bc,00013h		;67a7
	ld (hl),000h		;67aa
	ldir		;67ac
L_67AE:
	ld hl,0e2bah		;67ae
	call L_67C2		;67b1
	ld hl,0e2cch		;67b4
	call L_67C2		;67b7
	call L_67E6		;67ba
	xor a			;67bd
	ld (0e347h),a		;67be
	ret			;67c1
L_67C2:
	ld bc,00403h		;67c2
L_67C5:
	push bc			;67c5
	push hl			;67c6
	xor a			;67c7
	cp (hl)			;67c8
	jr nz,L_67D1		;67c9
	dec hl			;67cb
	ld b,c			;67cc
L_67CD:
	ld (hl),a			;67cd
	dec hl			;67ce
	djnz L_67CD		;67cf
L_67D1:
	pop hl			;67d1
	pop bc			;67d2
	ld a,l			;67d3
	add a,c			;67d4
	inc a			;67d5
	ld l,a			;67d6
	djnz L_67C5		;67d7
	ld a,(0e2c7h)		;67d9
	ld (0e2c8h),a		;67dc
	ld a,(0e2d9h)		;67df
	ld (0e2dah),a		;67e2
	ret			;67e5
L_67E6:
	ld b,004h		;67e6
	ld a,(0e347h)		;67e8
	or a			;67eb
	ret z			;67ec
	ld hl,0e2c9h		;67ed
L_67F0:
	cp (hl)			;67f0
	jr z,L_67FD		;67f1
	push af			;67f3
	ld a,004h		;67f4
	call suma_a_a_hl		;67f6
	pop af			;67f9
	djnz L_67F0		;67fa
	ret			;67fc
L_67FD:
	ld b,004h		;67fd
	xor a			;67ff
L_6800:
	ld (hl),a			;6800
	inc hl			;6801
	djnz L_6800		;6802
	ld hl,0e2d9h		;6804
	dec (hl)			;6807
	inc hl			;6808
	dec (hl)			;6809
	ret			;680a
L_680B:
	ld a,(0e33eh)		;680b
	rra			;680e
	jp c,L_68EF		;680f
	ld a,(0e1aah)		;6812
	dec a			;6815
	jp z,L_68EF		;6816
	ld a,(0e206h)		;6819
	rra			;681c
	ld a,(0e1bfh)		;681d
	ld hl,0e172h		;6820
	jr nc,L_682B		;6823
	ld a,(0e1beh)		;6825
	ld hl,0e15eh		;6828
L_682B:
	call suma_a_a_hl		;682b
	ld a,(hl)			;682e
	cp 039h		;682f
	jp z,L_68EF		;6831
	ld (0e128h),a		;6834
	ex de,hl			;6837
	ld a,(0e128h)		;6838
	ld hl,0e32bh		;683b
	call L_6E5D		;683e
	ld a,(0e206h)		;6841
	rra			;6844
	jr nc,L_6851		;6845
	ld a,(0e128h)		;6847
	dec a			;684a
	dec hl			;684b
	cp (hl)			;684c
	jp z,L_68EF		;684d
	inc hl			;6850
L_6851:
	ld a,(0e128h)		;6851
	cp (hl)			;6854
	jp nz,L_68EF		;6855
	inc hl			;6858
	cp (hl)			;6859
	jp nz,L_68EF		;685a
	ld a,(0e206h)		;685d
	rra			;6860
	jr nc,L_6875		;6861
	ld a,(0e128h)		;6863
	inc hl			;6866
	cp (hl)			;6867
	jp nz,L_68FC		;6868
	inc a			;686b
	inc hl			;686c
	cp (hl)			;686d
	jp z,L_68FC		;686e
	dec hl			;6871
	ld (hl),039h		;6872
	dec hl			;6874
L_6875:
	ld a,039h		;6875
	ld (hl),a			;6877
	dec hl			;6878
	ld (hl),a			;6879
	ex de,hl			;687a
	ld (hl),a			;687b
	call L_6F60		;687c
	ld a,(0e206h)		;687f
	rra			;6882
	jr nc,L_6888		;6883
	call L_6F4E		;6885
L_6888:
	ld a,(0e20ah)		;6888
	inc a			;688b
	ld b,a			;688c
	ld hl,0e32bh		;688d
	call L_4F9B		;6890
	ld a,(0e20bh)		;6893
	sub 004h		;6896
	cp 00ch		;6898
	jr nz,L_689D		;689a
	dec a			;689c
L_689D:
	ld (0e20bh),a		;689d
	inc a			;68a0
	ld hl,0e32bh		;68a1
	call suma_a_a_hl		;68a4
	ld a,(0e128h)		;68a7
	ld (hl),a			;68aa
	inc hl			;68ab
	ld (hl),a			;68ac
	inc hl			;68ad
	ld (hl),a			;68ae
	ex de,hl			;68af
	call L_6185		;68b0
	inc (hl)			;68b3
	ld hl,0e2d9h		;68b4
	inc (hl)			;68b7
	ld hl,0e2b6h		;68b8
	inc (hl)			;68bb
	call L_6917		;68bc
	ld a,(0e206h)		;68bf
	rra			;68c2
	jr nc,L_68CA		;68c3
	call L_690B		;68c5
	jr L_68D0		;68c8
L_68CA:
	call L_68FF		;68ca
	call L_6F2E		;68cd
L_68D0:
	ld a,(0e20ah)		;68d0
	sub 003h		;68d3
	ld (0e209h),a		;68d5
	ld (0e20ah),a		;68d8
	ld a,(0e206h)		;68db
	rra			;68de
	jr c,L_68E6		;68df
	ld a,001h		;68e1
	ld (0e1aah),a		;68e3
L_68E6:
	ld a,00bh		;68e6
	call L_9C4A		;68e8
	ld c,000h		;68eb
	jr L_68FC		;68ed
L_68EF:
	ld c,001h		;68ef
	ld a,(0e206h)		;68f1
	rra			;68f4
	jr c,L_68FC		;68f5
	ld a,002h		;68f7
	call pinta_uno_de_los_tres_dibujos		;68f9
L_68FC:
	jp L_66D5		;68fc
L_68FF:
	ld hl,0e32bh		;68ff
	ld de,0e13ah		;6902
	ld bc,00012h		;6905
	ldir		;6908
	ret			;690a
L_690B:
	ld hl,0e32bh		;690b
	ld de,0e14ch		;690e
	ld bc,00012h		;6911
	ldir		;6914
	ret			;6916
L_6917:
	ld hl,0e22dh		;6917
	ld a,(0e206h)		;691a
	rra			;691d
	jr nc,L_6923		;691e
	ld hl,0e232h		;6920
L_6923:
	ld a,(hl)			;6923
	ld d,a			;6924
	inc (hl)			;6925
	inc hl			;6926
	call suma_a_a_hl		;6927
	ld a,(0e128h)		;692a
	ld (hl),a			;692d
	ret			;692e
L_692F:
	ld a,(0e1aah)		;692f
	dec a			;6932
	jp z,L_6BC6		;6933
	ld a,(0e33eh)		;6936
	rra			;6939
	jp c,L_6BC6		;693a
	ld hl,0e1abh		;693d
	bit 0,(hl)		;6940
	jp z,L_694B		;6942
	bit 1,(hl)		;6945
	jp z,L_69F9		;6947
	ret			;694a
L_694B:
	ld a,0ffh		;694b
	ld (0e1efh),a		;694d
	ld a,(0e206h)		;6950
	rra			;6953
	ld a,(0e1bfh)		;6954
	ld hl,0e172h		;6957
	jr nc,L_6962		;695a
	ld a,(0e1beh)		;695c
	ld hl,0e15eh		;695f
L_6962:
	call suma_a_a_hl		;6962
	ld a,(hl)			;6965
	cp 031h		;6966
	jp nc,L_6BC6		;6968
	ld (0e128h),a		;696b
	ld (0e129h),hl		;696e
	ld c,000h		;6971
	ld a,(0e128h)		;6973
	dec a			;6976
	ld hl,0e32bh		;6977
	call L_6E5D		;697a
	cp (hl)			;697d
	jr nz,L_69A1		;697e
	ld c,001h		;6980
	ld (0e12bh),hl		;6982
	dec a			;6985
	ld hl,0e32bh		;6986
	call L_6E5D		;6989
	cp (hl)			;698c
	jr nz,L_69A1		;698d
	call L_6C02		;698f
	ld hl,(0e12bh)		;6992
	call L_6C02		;6995
	ld a,(0e128h)		;6998
	dec a			;699b
	dec a			;699c
	ld b,a			;699d
	call L_6BF5		;699e
L_69A1:
	ld a,(0e128h)		;69a1
	inc a			;69a4
	ld hl,0e32bh		;69a5
	call L_6E5D		;69a8
	cp (hl)			;69ab
	jr nz,L_69E5		;69ac
	ld (0e12dh),hl		;69ae
	ld a,c			;69b1
	cp 001h		;69b2
	jr nz,L_69C7		;69b4
	call L_6C02		;69b6
	ld hl,(0e12bh)		;69b9
	call L_6C02		;69bc
	ld a,(0e128h)		;69bf
	dec a			;69c2
	ld b,a			;69c3
	call L_6BF5		;69c4
L_69C7:
	ld a,(0e128h)		;69c7
	inc a			;69ca
	inc a			;69cb
	ld hl,0e32bh		;69cc
	call L_6E5D		;69cf
	cp (hl)			;69d2
	jr nz,L_69E5		;69d3
	call L_6C02		;69d5
	ld hl,(0e12dh)		;69d8
	call L_6C02		;69db
	ld a,(0e128h)		;69de
	ld b,a			;69e1
	call L_6BF5		;69e2
L_69E5:
	ld a,(0e1efh)		;69e5
	cp 0ffh		;69e8
	jp z,L_6BC6		;69ea
	sra a		;69ed
	ld (0e1efh),a		;69ef
	cp 001h		;69f2
	jr nc,L_69F9		;69f4
	jp L_6AA2		;69f6
L_69F9:
	ld a,(0e206h)		;69f9
	rra			;69fc
	jp c,L_6BD3		;69fd
	ld hl,0e1abh		;6a00
	set 1,(hl)		;6a03
	ld hl,0e1c4h		;6a05
	ld a,(0e009h)		;6a08
	and 010h		;6a0b
	jr nz,L_6A13		;6a0d
	res 0,(hl)		;6a0f
	jr L_6A21		;6a11
L_6A13:
	bit 0,(hl)		;6a13
	jr nz,L_6A21		;6a15
	set 0,(hl)		;6a17
	ld a,006h		;6a19
	call L_9C4A		;6a1b
	jp L_6AA2		;6a1e
L_6A21:
	ld a,(0e003h)		;6a21
	and 00fh		;6a24
	ret nz			;6a26
	ld hl,0e009h		;6a27
	bit 2,(hl)		;6a2a
	jr z,L_6A46		;6a2c
	ld a,005h		;6a2e
	call L_9C4A		;6a30
	ld a,(0e1f0h)		;6a33
	dec a			;6a36
	ld (0e1f0h),a		;6a37
	or a			;6a3a
	jp p,L_6A65		;6a3b
	ld a,(0e1efh)		;6a3e
	ld (0e1f0h),a		;6a41
	jr L_6A65		;6a44
L_6A46:
	ld hl,0e009h		;6a46
	bit 3,(hl)		;6a49
	jr z,L_6A65		;6a4b
	ld a,005h		;6a4d
	call L_9C4A		;6a4f
	ld a,(0e1f0h)		;6a52
	inc a			;6a55
	ld hl,0e1efh		;6a56
	ld (0e1f0h),a		;6a59
	cp (hl)			;6a5c
	jr c,L_6A65		;6a5d
	jr z,L_6A65		;6a5f
	xor a			;6a61
	ld (0e1f0h),a		;6a62
L_6A65:
	ld a,(0e1f0h)		;6a65
	sla a		;6a68
	ld hl,0e1e9h		;6a6a
	call suma_a_a_hl		;6a6d
	ld b,(hl)			;6a70
	inc hl			;6a71
	ld c,(hl)			;6a72
	ld hl,0e32bh		;6a73
	ld a,b			;6a76
	sub l			;6a77
	ld b,a			;6a78
	ld a,c			;6a79
	sub l			;6a7a
	ld hl,05350h		;6a7b
	call suma_a_a_hl		;6a7e
	ld a,(hl)			;6a81
	ld (0e0a9h),a		;6a82
	ld (0e0adh),a		;6a85
	ld a,b			;6a88
	ld hl,05350h		;6a89
	call suma_a_a_hl		;6a8c
	ld a,(hl)			;6a8f
	ld (0e0b1h),a		;6a90
	ld (0e0b5h),a		;6a93
	ld hl,0e0a8h		;6a96
	ld de,03b00h		;6a99
	ld bc,00010h		;6a9c
	jp L_460B		;6a9f
L_6AA2:
	ld a,(0e206h)		;6aa2
	rra			;6aa5
	jr nc,L_6AB7		;6aa6
	ld a,(0e128h)		;6aa8
	ld hl,0e32bh		;6aab
	call L_6E5D		;6aae
	cp (hl)			;6ab1
	jp nz,L_6BD3		;6ab2
	ld (hl),039h		;6ab5
L_6AB7:
	ld a,(0e1f0h)		;6ab7
	sla a		;6aba
	ld hl,0e1e9h		;6abc
	call suma_a_a_hl		;6abf
	ld b,(hl)			;6ac2
	inc hl			;6ac3
	ld c,(hl)			;6ac4
	ld hl,0e32bh		;6ac5
	ld l,b			;6ac8
	ld (hl),039h		;6ac9
	ld l,c			;6acb
	ld (hl),039h		;6acc
	ld de,(0e129h)		;6ace
	ld a,039h		;6ad2
	ld (de),a			;6ad4
	call L_6F60		;6ad5
	ld a,(0e206h)		;6ad8
	rra			;6adb
	jr nc,L_6AE1		;6adc
	call L_6F4E		;6ade
L_6AE1:
	ld a,(0e20ah)		;6ae1
	inc a			;6ae4
	ld b,a			;6ae5
	ld hl,0e32bh		;6ae6
	call L_4F9B		;6ae9
	ld a,(0e20bh)		;6aec
	sub 004h		;6aef
	cp 00ch		;6af1
	jr nz,L_6AF6		;6af3
	dec a			;6af5
L_6AF6:
	ld (0e20bh),a		;6af6
	inc a			;6af9
	ld hl,0e32bh		;6afa
	call suma_a_a_hl		;6afd
	ld a,(0e1f0h)		;6b00
	ld de,0e1f1h		;6b03
	call suma_a_a_de		;6b06
	ld a,(de)			;6b09
	ld (hl),a			;6b0a
	inc a			;6b0b
	inc hl			;6b0c
	ld (hl),a			;6b0d
	inc a			;6b0e
	inc hl			;6b0f
	ld (hl),a			;6b10
	push de			;6b11
	call L_6917		;6b12
	ld a,(0e20bh)		;6b15
	add a,004h		;6b18
	ld b,a			;6b1a
	dec a			;6b1b
	ld hl,0e32bh		;6b1c
	call suma_a_a_hl		;6b1f
	ld a,(0e128h)		;6b22
L_6B25:
	cp (hl)			;6b25
	jr z,L_6B2B		;6b26
	dec hl			;6b28
	djnz L_6B25		;6b29
L_6B2B:
	dec b			;6b2b
	ld a,d			;6b2c
	rla			;6b2d
	rla			;6b2e
	ld d,a			;6b2f
	ld a,(0e206h)		;6b30
	rra			;6b33
	ld a,d			;6b34
	jr c,L_6B59		;6b35
	ld hl,0e0e0h		;6b37
	call suma_a_a_hl		;6b3a
	ld (hl),0bch		;6b3d
	ld a,b			;6b3f
	cp 00eh		;6b40
	jr c,L_6B48		;6b42
	sub 004h		;6b44
	ld (hl),0a8h		;6b46
L_6B48:
	ld hl,05350h		;6b48
	call suma_a_a_hl		;6b4b
	ld a,d			;6b4e
	ld de,0e0e1h		;6b4f
	call suma_a_a_de		;6b52
	ld a,(hl)			;6b55
	ld (de),a			;6b56
	jr L_6B7D		;6b57
L_6B59:
	ld hl,0e0f0h		;6b59
	call suma_a_a_hl		;6b5c
	ld (hl),0ffh		;6b5f
	ld a,b			;6b61
	cp 00eh		;6b62
	jr c,L_6B6A		;6b64
	sub 004h		;6b66
	ld (hl),017h		;6b68
L_6B6A:
	sub 00eh		;6b6a
	xor 0ffh		;6b6c
	ld hl,05350h		;6b6e
	call suma_a_a_hl		;6b71
	ld a,d			;6b74
	ld de,0e0f1h		;6b75
	call suma_a_a_de		;6b78
	ld a,(hl)			;6b7b
	ld (de),a			;6b7c
L_6B7D:
	ld hl,0e0e0h		;6b7d
	ld de,03b38h		;6b80
	ld bc,00020h		;6b83
	call L_460B		;6b86
	pop de			;6b89
	call L_6159		;6b8a
	inc (hl)			;6b8d
	ld hl,0e2c7h		;6b8e
	inc (hl)			;6b91
	ld hl,0e2b6h		;6b92
	inc (hl)			;6b95
	ld a,(0e206h)		;6b96
	rra			;6b99
	jr c,L_6BA4		;6b9a
	call L_68FF		;6b9c
	call L_6F2E		;6b9f
	jr L_6BA7		;6ba2
L_6BA4:
	call L_690B		;6ba4
L_6BA7:
	ld a,(0e20ah)		;6ba7
	sub 003h		;6baa
	ld (0e209h),a		;6bac
	ld (0e20ah),a		;6baf
	ld a,(0e206h)		;6bb2
	rra			;6bb5
	jr c,L_6BBD		;6bb6
	ld a,001h		;6bb8
	ld (0e1aah),a		;6bba
L_6BBD:
	ld a,00bh		;6bbd
	call L_9C4A		;6bbf
	ld c,000h		;6bc2
	jr L_6BD3		;6bc4
L_6BC6:
	ld c,001h		;6bc6
	ld a,(0e206h)		;6bc8
	rra			;6bcb
	jr c,L_6BD3		;6bcc
	ld a,002h		;6bce
	call pinta_uno_de_los_tres_dibujos		;6bd0
L_6BD3:
	xor a			;6bd3
	ld (0e1abh),a		;6bd4
	ld (0e1c7h),a		;6bd7
	xor a			;6bda
	ld b,00bh		;6bdb
	ld hl,0e1e9h		;6bdd
L_6BE0:
	ld (hl),a			;6be0
	inc hl			;6be1
	djnz L_6BE0		;6be2
	ld b,004h		;6be4
L_6BE6:
	ld a,0e0h		;6be6
	ld de,03b00h		;6be8
	call escribe_en_vram		;6beb
	ld a,e			;6bee
	add a,004h		;6bef
	ld e,a			;6bf1
	djnz L_6BE6		;6bf2
	ret			;6bf4
L_6BF5:
	ld a,(0e1efh)		;6bf5
	sra a		;6bf8
	ld hl,0e1f1h		;6bfa
	call suma_a_a_hl		;6bfd
	ld (hl),b			;6c00
	ret			;6c01
L_6C02:
	ld b,l			;6c02
	ld hl,0e1efh		;6c03
	inc (hl)			;6c06
	ld a,(0e1efh)		;6c07
	ld hl,0e1e9h		;6c0a
	call suma_a_a_hl		;6c0d
	ld (hl),b			;6c10
	ret			;6c11
L_6C12:
	ld hl,0e32bh		;6c12
	ld de,0e348h		;6c15
	ld bc,00012h		;6c18
	ldir		;6c1b
	ld a,(0e22ch)		;6c1d
	or a			;6c20
	jr nz,L_6C41		;6c21
	ld a,(0e33eh)		;6c23
	rra			;6c26
	jp c,L_6E4D		;6c27
	ld a,(0e206h)		;6c2a
	rra			;6c2d
	ld a,(0e1bfh)		;6c2e
	ld hl,0e172h		;6c31
	jr nc,L_6C3C		;6c34
	ld a,(0e1beh)		;6c36
	ld hl,0e15eh		;6c39
L_6C3C:
	call suma_a_a_hl		;6c3c
	jr L_6C4A		;6c3f
L_6C41:
	ld a,(0e209h)		;6c41
	ld hl,0e32bh		;6c44
	call suma_a_a_hl		;6c47
L_6C4A:
	ld a,(hl)			;6c4a
	cp 039h		;6c4b
	jp z,L_6E5A		;6c4d
	ld (0e128h),a		;6c50
	ld (0e129h),hl		;6c53
	ld a,(0e128h)		;6c56
	ld hl,0e32bh		;6c59
	call L_6E5D		;6c5c
	ld a,(0e128h)		;6c5f
	cp (hl)			;6c62
	jr nz,L_6CCA		;6c63
	inc hl			;6c65
	cp (hl)			;6c66
	jr nz,L_6CCA		;6c67
	inc hl			;6c69
	cp (hl)			;6c6a
	jr nz,L_6CCA		;6c6b
	ld a,(0e20ah)		;6c6d
	ld de,0e32bh		;6c70
	call suma_a_a_de		;6c73
	ld a,e			;6c76
	cp l			;6c77
	jr z,L_6CCA		;6c78
	push hl			;6c7a
	ld c,000h		;6c7b
	ld a,c			;6c7d
	ld (0e12bh),a		;6c7e
	ld a,(0e22ch)		;6c81
	or a			;6c84
	jr z,L_6CC6		;6c85
	ld hl,0e20ah		;6c87
	ld a,(0e209h)		;6c8a
	cp (hl)			;6c8d
	jr z,L_6CC6		;6c8e
	ld a,(0e128h)		;6c90
	pop hl			;6c93
	inc hl			;6c94
	cp (hl)			;6c95
	jr z,L_6CB0		;6c96
	dec hl			;6c98
	ex de,hl			;6c99
	ld a,(0e20ah)		;6c9a
	ld hl,0e32bh		;6c9d
	call suma_a_a_hl		;6ca0
	ld a,(0e128h)		;6ca3
	cp (hl)			;6ca6
	jr nz,L_6CCA		;6ca7
	ld (0e129h),hl		;6ca9
	ex de,hl			;6cac
	jp L_6D57		;6cad
L_6CB0:
	push hl			;6cb0
	ld a,(0e209h)		;6cb1
	ld hl,0e32bh		;6cb4
	call suma_a_a_hl		;6cb7
	ld (0e129h),hl		;6cba
	ld c,001h		;6cbd
	ld hl,(0e129h)		;6cbf
	ld a,(hl)			;6cc2
	ld (0e128h),a		;6cc3
L_6CC6:
	pop hl			;6cc6
	jp L_6D57		;6cc7
L_6CCA:
	ld a,(0e22ch)		;6cca
	rra			;6ccd
	jp nc,L_6E4D		;6cce
	call L_6E69		;6cd1
	ld a,c			;6cd4
	cp 003h		;6cd5
	jr nz,L_6CE7		;6cd7
	ld a,(hl)			;6cd9
	ld (0e128h),a		;6cda
	ld (0e129h),hl		;6cdd
	ld a,002h		;6ce0
	ld (0e12bh),a		;6ce2
	jr L_6D57		;6ce5
L_6CE7:
	ld a,(0e22ch)		;6ce7
	rra			;6cea
	jp nc,L_6E4D		;6ceb
	ld hl,0e20bh		;6cee
	ld a,012h		;6cf1
	sub (hl)			;6cf3
	or a			;6cf4
	jp z,L_6E4D		;6cf5
	ld b,a			;6cf8
	ld hl,0e32bh		;6cf9
	ld a,(0e20bh)		;6cfc
	call suma_a_a_hl		;6cff
	ld a,(0e128h)		;6d02
L_6D05:
	cp (hl)			;6d05
	jr z,L_6D0E		;6d06
	inc hl			;6d08
	djnz L_6D05		;6d09
	jp L_6E4D		;6d0b
L_6D0E:
	inc hl			;6d0e
	cp (hl)			;6d0f
	jp nz,L_6E4D		;6d10
	inc hl			;6d13
	cp (hl)			;6d14
	jp nz,L_6E4D		;6d15
	dec hl			;6d18
	dec hl			;6d19
	dec hl			;6d1a
	ld (hl),a			;6d1b
	ld hl,0e2c9h		;6d1c
	ld b,004h		;6d1f
L_6D21:
	cp (hl)			;6d21
	jr z,L_6D2A		;6d22
	ld a,l			;6d24
	add a,002h		;6d25
	ld l,a			;6d27
	djnz L_6D21		;6d28
L_6D2A:
	ex de,hl			;6d2a
	ld hl,0e2c9h		;6d2b
	ld a,(0e2dah)		;6d2e
	add a,a			;6d31
	add a,a			;6d32
	add a,l			;6d33
	ld l,a			;6d34
	push hl			;6d35
	ld bc,00004h		;6d36
	ldir		;6d39
	pop hl			;6d3b
	xor a			;6d3c
	ld (hl),a			;6d3d
	inc hl			;6d3e
	ld (hl),a			;6d3f
	inc hl			;6d40
	ld (hl),a			;6d41
	inc hl			;6d42
	ld (hl),a			;6d43
	ld hl,0e2d9h		;6d44
	dec (hl)			;6d47
	ld hl,0e304h		;6d48
	dec (hl)			;6d4b
	ld hl,0e2dah		;6d4c
	dec (hl)			;6d4f
	ld a,001h		;6d50
	ld (0e12bh),a		;6d52
	jr L_6D64		;6d55
L_6D57:
	ld b,039h		;6d57
	ld (hl),b			;6d59
	dec hl			;6d5a
	ld (hl),b			;6d5b
	dec hl			;6d5c
	ld (hl),b			;6d5d
	ld a,c			;6d5e
	or a			;6d5f
	jr z,L_6D64		;6d60
	dec hl			;6d62
	ld (hl),b			;6d63
L_6D64:
	ld hl,(0e129h)		;6d64
	ld a,(0e22ch)		;6d67
	or a			;6d6a
	jr nz,L_6D7D		;6d6b
	ld (hl),039h		;6d6d
	call L_6F60		;6d6f
	ld a,(0e206h)		;6d72
	rra			;6d75
	jr nc,L_6D7B		;6d76
	call L_6F4E		;6d78
L_6D7B:
	jr L_6D7F		;6d7b
L_6D7D:
	ld (hl),039h		;6d7d
L_6D7F:
	ld a,(0e12bh)		;6d7f
	cp 001h		;6d82
	jr z,L_6D93		;6d84
	ld a,(0e20bh)		;6d86
	sub 004h		;6d89
	cp 00ch		;6d8b
	jr nz,L_6D90		;6d8d
	dec a			;6d8f
L_6D90:
	ld (0e20bh),a		;6d90
L_6D93:
	ld hl,0e128h		;6d93
	ex de,hl			;6d96
	call L_61B9		;6d97
	ld a,(0e22ch)		;6d9a
	or a			;6d9d
	jr z,L_6DA6		;6d9e
	ld a,(0e12bh)		;6da0
	dec a			;6da3
	jr nz,L_6DB9		;6da4
L_6DA6:
	inc (hl)			;6da6
	ld a,(0e22ch)		;6da7
	cp 001h		;6daa
	jr z,L_6DB9		;6dac
	ld hl,0e2b6h		;6dae
	inc (hl)			;6db1
	ld hl,0e2efh		;6db2
	inc (hl)			;6db5
	call L_6917		;6db6
L_6DB9:
	ld a,(0e20ah)		;6db9
	ld b,a			;6dbc
	ld a,(0e22ch)		;6dbd
	or a			;6dc0
	jr z,L_6DC4		;6dc1
	inc b			;6dc3
L_6DC4:
	ld hl,0e32bh		;6dc4
	call L_4F9B		;6dc7
	ld a,(0e12bh)		;6dca
	dec a			;6dcd
	jr z,L_6DED		;6dce
	ld a,(0e20bh)		;6dd0
	ld hl,0e32bh		;6dd3
	call suma_a_a_hl		;6dd6
	ld a,(0e128h)		;6dd9
	ld b,a			;6ddc
	ld c,a			;6ddd
	ld a,(0e22ch)		;6dde
	or a			;6de1
	jr z,L_6DE6		;6de2
	ld c,038h		;6de4
L_6DE6:
	ld (hl),c			;6de6
	inc hl			;6de7
	ld (hl),b			;6de8
	inc hl			;6de9
	ld (hl),b			;6dea
	inc hl			;6deb
	ld (hl),c			;6dec
L_6DED:
	ld a,(0e209h)		;6ded
	ld (0e12ch),a		;6df0
	ld a,(0e20ah)		;6df3
	ld (0e12dh),a		;6df6
	ld a,(0e12bh)		;6df9
	dec a			;6dfc
	jr z,L_6E20		;6dfd
	ld a,(0e20ah)		;6dff
	sub 003h		;6e02
	ld (0e209h),a		;6e04
	ld (0e20ah),a		;6e07
	ld b,000h		;6e0a
	ld a,(0e206h)		;6e0c
	rra			;6e0f
	jr c,L_6E18		;6e10
	ld a,(0e33eh)		;6e12
	rra			;6e15
	jr nc,L_6E1B		;6e16
L_6E18:
	call L_6E87		;6e18
L_6E1B:
	ld a,b			;6e1b
	dec a			;6e1c
	jp z,L_6E4D		;6e1d
L_6E20:
	ld a,(0e206h)		;6e20
	rra			;6e23
	jr c,L_6E2E		;6e24
	call L_68FF		;6e26
	call L_6F2E		;6e29
	jr L_6E31		;6e2c
L_6E2E:
	call L_690B		;6e2e
L_6E31:
	ld c,000h		;6e31
	ld a,(0e206h)		;6e33
	rra			;6e36
	jr c,L_6E5A		;6e37
	ld a,0ffh		;6e39
	ld (0e1aah),a		;6e3b
	ld a,00bh		;6e3e
	call L_9C4A		;6e40
	ld a,001h		;6e43
	ld (0e1cfh),a		;6e45
	call para_un_momento		;6e48
	jr L_6E5A		;6e4b
L_6E4D:
	ld c,001h		;6e4d
	ld a,(0e206h)		;6e4f
	rra			;6e52
	jr c,L_6E5A		;6e53
	ld a,002h		;6e55
	call pinta_uno_de_los_tres_dibujos		;6e57
L_6E5A:
	jp L_66D5		;6e5a
L_6E5D:
	push hl			;6e5d
	ld hl,0e20ah		;6e5e
	ld b,(hl)			;6e61
	pop hl			;6e62
L_6E63:
	cp (hl)			;6e63
	ret z			;6e64
	inc hl			;6e65
	djnz L_6E63		;6e66
	ret			;6e68
L_6E69:
	ld de,0e32bh		;6e69
	ld hl,0e32ch		;6e6c
L_6E6F:
	ld c,000h		;6e6f
	ld a,(0e20ah)		;6e71
	ld b,a			;6e74
L_6E75:
	ld a,(de)			;6e75
	cp (hl)			;6e76
	jr nz,L_6E7C		;6e77
	inc c			;6e79
	jr L_6E7E		;6e7a
L_6E7C:
	ld c,000h		;6e7c
L_6E7E:
	ld a,c			;6e7e
	cp 003h		;6e7f
	ret z			;6e81
	inc hl			;6e82
	inc de			;6e83
	djnz L_6E75		;6e84
	ret			;6e86
L_6E87:
	ld a,(0e206h)		;6e87
	rra			;6e8a
	push af			;6e8b
	ld hl,0e1f5h		;6e8c
	jr nc,L_6E94		;6e8f
	ld hl,0e20eh		;6e91
L_6E94:
	ld de,0e12eh		;6e94
	ld bc,0000ch		;6e97
	ldir		;6e9a
	call L_66E7		;6e9c
	pop af			;6e9f
	ld hl,0e1f5h		;6ea0
	jr nc,L_6EA8		;6ea3
	ld hl,0e20eh		;6ea5
L_6EA8:
	ld de,0e12eh		;6ea8
	ld b,00ch		;6eab
L_6EAD:
	ld a,(de)			;6ead
	cp (hl)			;6eae
	jr nz,L_6EB6		;6eaf
	inc hl			;6eb1
	inc de			;6eb2
	djnz L_6EAD		;6eb3
	ret			;6eb5
L_6EB6:
	ld a,(0e206h)		;6eb6
	rra			;6eb9
	ld hl,0e12eh		;6eba
	ld de,0e1f5h		;6ebd
	jr nc,L_6EC5		;6ec0
	ld de,0e20eh		;6ec2
L_6EC5:
	ld bc,0000ch		;6ec5
	ldir		;6ec8
	ld hl,0e348h		;6eca
	ld de,0e32bh		;6ecd
	ld bc,00012h		;6ed0
	ldir		;6ed3
	ld a,(0e12ch)		;6ed5
	ld (0e209h),a		;6ed8
	ld a,(0e12dh)		;6edb
	ld (0e20ah),a		;6ede
	ld hl,0e2f0h		;6ee1
	dec (hl)			;6ee4
	xor a			;6ee5
	ld (0e128h),a		;6ee6
	ld de,0e128h		;6ee9
	call L_61C5		;6eec
	ld (hl),000h		;6eef
	ld b,001h		;6ef1
	ret			;6ef3
L_6EF4:
	ld a,(0e302h)		;6ef4
	rra			;6ef7
	rra			;6ef8
	jr nc,L_6F0C		;6ef9
	call L_5754		;6efb
	ld hl,0e14ch		;6efe
	ld de,0e13ah		;6f01
	ld bc,00012h		;6f04
	ldir		;6f07
	jp L_6F2E		;6f09
L_6F0C:
	ld de,0e1e8h		;6f0c
	ld a,(0e1c3h)		;6f0f
	ld hl,0e13ah		;6f12
	call suma_a_a_hl		;6f15
	ld a,(de)			;6f18
	ld (hl),a			;6f19
	jr L_6F2E		;6f1a
L_6F1C:
	ld a,00ah		;6f1c
	ld de,03971h		;6f1e
	jr L_6F78		;6f21
L_6F23:
	ld a,022h		;6f23
	jr L_6F29		;6f25
L_6F27:
	ld a,01ah		;6f27
L_6F29:
	ld de,03974h		;6f29
	jr L_6F78		;6f2c
L_6F2E:
	ld hl,0e13ah		;6f2e
	ld de,03aa2h		;6f31
	call L_6FA3		;6f34
	ld de,03a56h		;6f37
	ld c,004h		;6f3a
	jr L_6FA5		;6f3c
L_6F3E:
	ld hl,0e14ch		;6f3e
	ld de,0381ch		;6f41
	call L_6FB2		;6f44
	ld de,03868h		;6f47
	ld c,004h		;6f4a
	jr L_6FB4		;6f4c
L_6F4E:
	ld hl,0e15eh		;6f4e
	ld de,039e2h		;6f51
	ld c,00ah		;6f54
	call L_6FA5		;6f56
	ld de,03a42h		;6f59
	ld c,00ah		;6f5c
	jr L_6FA5		;6f5e
L_6F60:
	ld hl,0e172h		;6f60
	ld de,038dch		;6f63
	ld c,00ah		;6f66
	call L_6FB4		;6f68
	ld de,0387ch		;6f6b
	ld c,00ah		;6f6e
	jr L_6FB4		;6f70
L_6F72:
	di			;6f72
	ld a,(hl)			;6f73
L_6F74:
	di			;6f74
	call saca_una_posicion		;6f75
L_6F78:
	di			;6f78
	ld (0e127h),a		;6f79
	ld b,003h		;6f7c
L_6F7E:
	call prepara_escritura_vram		;6f7e
	ld a,(0e127h)		;6f81
	exx			;6f84
	out (c),a		;6f85
	exx			;6f87
	or a			;6f88
	jr z,L_6F8C		;6f89
	inc a			;6f8b
L_6F8C:
	call L_6FA2		;6f8c
	exx			;6f8f
	out (c),a		;6f90
	exx			;6f92
	or a			;6f93
	jr z,L_6F97		;6f94
	inc a			;6f96
L_6F97:
	ld (0e127h),a		;6f97
	ld a,020h		;6f9a
	call suma_a_a_de		;6f9c
	djnz L_6F7E		;6f9f
	ei			;6fa1
L_6FA2:
	ret			;6fa2
L_6FA3:
	ld c,00eh		;6fa3
L_6FA5:
	call L_6F72		;6fa5
	ld a,05eh		;6fa8
	call resta_a_de_de		;6faa
	inc hl			;6fad
	dec c			;6fae
	jr nz,L_6FA5		;6faf
	ret			;6fb1
L_6FB2:
	ld c,00eh		;6fb2
L_6FB4:
	call L_6F72		;6fb4
	ld a,062h		;6fb7
	call resta_a_de_de		;6fb9
	inc hl			;6fbc
	dec c			;6fbd
	jr nz,L_6FB4		;6fbe
	ret			;6fc0
L_6FC1:
	ld hl,08ad7h		;6fc1
	call pinta_lista_formato_b		;6fc4
	ld hl,090d4h		;6fc7
	call pinta_lista_formato_b		;6fca
	ld hl,08a9fh		;6fcd
	ld de,02818h		;6fd0
	ld bc,00038h		;6fd3
	call L_460B		;6fd6
	ld hl,090cfh		;6fd9
	jp pinta_lista_formato_b		;6fdc
L_6FDF:
	ld hl,093aah		;6fdf
	ld (0e05bh),hl		;6fe2
	ld de,02140h		;6fe5
	call pinta_la_mano_del_espejo		;6fe8
	ld hl,09a05h		;6feb
	ld de,00140h		;6fee
	ld (0e05bh),hl		;6ff1
	call vuelca_la_mano_de_este_lado		;6ff4
	ld hl,092e3h		;6ff7
	ld de,03020h		;6ffa
	ld bc,00060h		;6ffd
	call L_460B		;7000
	ld hl,09343h		;7003
	call pinta_lista_formato_b		;7006
	ld hl,099f4h		;7009
	call pinta_lista_formato_b		;700c
	ld hl,099f9h		;700f
	jp pinta_lista_formato_b		;7012
L_7015:
	call L_7024		;7015
L_7018:
	call L_6F1C		;7018
	jp L_6F23		;701b
L_701E:
	call L_6F1C		;701e
	jp L_6F27		;7021
L_7024:
	ld a,(0e1d3h)		;7024
	ld de,02850h		;7027
	ld hl,03000h		;702a
	call L_7053		;702d
	ld a,(0e1d4h)		;7030
	ld de,028d0h		;7033
	ld hl,03000h		;7036
	call L_7053		;7039
	ld a,(0e1d3h)		;703c
	ld de,00850h		;703f
	ld hl,01000h		;7042
	call L_706B		;7045
	ld a,(0e1d4h)		;7048
	ld de,008d0h		;704b
	ld hl,01000h		;704e
	jr L_706B		;7051
L_7053:
	push de			;7053
	call saca_una_posicion		;7054
	ex de,hl			;7057
	ld l,a			;7058
	ld h,000h		;7059
	add hl,hl			;705b
	add hl,hl			;705c
	add hl,hl			;705d
	add hl,de			;705e
	ex de,hl			;705f
	ld bc,00030h		;7060
	ld hl,0e2b6h		;7063
	call L_461C		;7066
	jr L_7081		;7069
L_706B:
	push de			;706b
	call saca_una_posicion		;706c
	ex de,hl			;706f
	ld l,a			;7070
	ld h,000h		;7071
	add hl,hl			;7073
	add hl,hl			;7074
	add hl,hl			;7075
	add hl,de			;7076
	ex de,hl			;7077
	ld bc,00030h		;7078
	ld hl,0e2b6h		;707b
	call L_462F		;707e
L_7081:
	pop de			;7081
	ld hl,0e2b6h		;7082
	ld bc,00030h		;7085
	jp L_460B		;7088
L_708B:
	ld hl,08832h		;708b
	call pinta_lista_formato_b		;708e
	ld hl,08a78h		;7091
	jp pinta_lista_formato_b		;7094
L_7097:
	call L_6EF4		;7097
	ld hl,07376h		;709a
	call pinta_lista_formato_b		;709d
	ld a,(0e04dh)		;70a0
	ld c,a			;70a3
	ld a,(0e302h)		;70a4
	rra			;70a7
	and 001h		;70a8
	xor c			;70aa
	ld a,000h		;70ab
	ld (0e04eh),a		;70ad
	ld hl,07404h		;70b0
	jr z,L_70BC		;70b3
	inc a			;70b5
	ld (0e04eh),a		;70b6
	ld hl,07416h		;70b9
L_70BC:
	jp L_409D		;70bc
L_70BF:
	ld a,(0e315h)		;70bf
	and a			;70c2
	jp z,L_7156		;70c3
	dec a			;70c6
	ld (0e315h),a		;70c7
	ld hl,(0e319h)		;70ca
	ld a,(hl)			;70cd
	ex de,hl			;70ce
	cp 00ch		;70cf
	jr nc,L_70E0		;70d1
	inc de			;70d3
	ld a,(de)			;70d4
	dec de			;70d5
	cp 00ch		;70d6
	ld a,(de)			;70d8
	jr c,L_70E0		;70d9
	ld hl,0e315h		;70db
	ld (hl),000h		;70de
L_70E0:
	inc de			;70e0
	ld (0e319h),de		;70e1
	push af			;70e5
	add a,a			;70e6
	ld hl,07642h		;70e7
	call suma_a_a_hl		;70ea
	ld e,(hl)			;70ed
	inc hl			;70ee
	ld d,(hl)			;70ef
	ex de,hl			;70f0
	ld de,(0e317h)		;70f1
	push de			;70f5
	ld c,0ffh		;70f6
	call L_40A3		;70f8
	pop de			;70fb
	pop af			;70fc
	push de			;70fd
	cp 022h		;70fe
	jr nz,L_7107		;7100
	ld hl,0e1d6h		;7102
	jr L_7143		;7105
L_7107:
	cp 026h		;7107
	jr nz,L_7110		;7109
	ld hl,0e1d7h		;710b
	jr L_7143		;710e
L_7110:
	ld c,a			;7110
	ld a,(0e2b6h)		;7111
	or a			;7114
	jr nz,L_714B		;7115
	ld a,c			;7117
	cp 011h		;7118
	jr nz,L_7123		;711a
	ld hl,0e127h		;711c
	ld (hl),006h		;711f
	jr L_7143		;7121
L_7123:
	cp 015h		;7123
	jr c,L_7136		;7125
	cp 018h		;7127
	jr nc,L_7136		;7129
	cp 016h		;712b
	jr z,L_7136		;712d
	ld hl,0e127h		;712f
	ld (hl),003h		;7132
	jr L_7143		;7134
L_7136:
	cp 01fh		;7136
	jr c,L_714B		;7138
	cp 022h		;713a
	jr nc,L_714B		;713c
	ld hl,0e127h		;713e
	ld (hl),002h		;7141
L_7143:
	ld a,00bh		;7143
	call suma_a_a_de		;7145
	call L_457E		;7148
L_714B:
	pop de			;714b
	ld a,020h		;714c
	call suma_a_a_de		;714e
	ld (0e317h),de		;7151
	ret			;7155
L_7156:
	ld a,(0e305h)		;7156
	cp 00ch		;7159
	jr c,L_7170		;715b
	ld hl,0e316h		;715d
	ld a,(hl)			;7160
	add a,000h		;7161
	daa			;7163
	ld (0e127h),a		;7164
	ld hl,0e127h		;7167
	ld de,0386ch		;716a
	call L_457E		;716d
L_7170:
	ld hl,0e1a8h		;7170
	res 2,(hl)		;7173
	ret			;7175
L_7176:
	ld a,(0e003h)		;7176
	and 03fh		;7179
	ret nz			;717b
	ld a,009h		;717c
	call L_9C4A		;717e
	ld hl,0e1d8h		;7181
	dec (hl)			;7184
	ld a,(hl)			;7185
	ld hl,07690h		;7186
	add a,a			;7189
	call suma_a_a_hl		;718a
	ld e,(hl)			;718d
	inc hl			;718e
	ld d,(hl)			;718f
	ld a,(0e1d8h)		;7190
	or a			;7193
	jp z,L_727A		;7194
	ld a,(0e2dah)		;7197
	or a			;719a
	ld c,a			;719b
	jr z,L_71DD		;719c
	ld a,(0e1d9h)		;719e
	cp c			;71a1
	jr z,L_71DD		;71a2
	inc a			;71a4
	ld (0e1d9h),a		;71a5
	ld hl,0e2c5h		;71a8
	sla a		;71ab
	sla a		;71ad
	call suma_a_a_hl		;71af
	ld c,003h		;71b2
	call L_6FA5		;71b4
	ld c,(hl)			;71b7
	ex de,hl			;71b8
	dec de			;71b9
	ld b,002h		;71ba
	ld a,(de)			;71bc
	cp 030h		;71bd
	jr nc,L_71D3		;71bf
	and 00fh		;71c1
	cp 001h		;71c3
	jr z,L_71D3		;71c5
	cp 009h		;71c7
	jr z,L_71D3		;71c9
	ld a,c			;71cb
	rra			;71cc
	jr c,L_723E		;71cd
	ld b,004h		;71cf
	jr L_723E		;71d1
L_71D3:
	ld b,004h		;71d3
	ld a,c			;71d5
	rra			;71d6
	jr c,L_723E		;71d7
	ld b,008h		;71d9
	jr L_723E		;71db
L_71DD:
	ld a,(0e2f0h)		;71dd
	or a			;71e0
	ld c,a			;71e1
	jr z,L_724C		;71e2
	ld a,(0e1dah)		;71e4
	cp c			;71e7
	jr z,L_724C		;71e8
	inc a			;71ea
	ld (0e1dah),a		;71eb
	ld hl,0e2d6h		;71ee
	ld b,a			;71f1
	sla a		;71f2
	sla a		;71f4
	add a,b			;71f6
	call suma_a_a_hl		;71f7
	ld c,004h		;71fa
	dec de			;71fc
	dec de			;71fd
	push de			;71fe
	call L_6FA5		;71ff
	pop de			;7202
	ld c,(hl)			;7203
	ld a,(hl)			;7204
	rra			;7205
	jr c,L_721B		;7206
	push hl			;7208
	push de			;7209
	ld a,038h		;720a
	call L_6F74		;720c
	pop de			;720f
	ld a,006h		;7210
	call suma_a_a_de		;7212
	ld a,038h		;7215
	call L_6F74		;7217
	pop hl			;721a
L_721B:
	ex de,hl			;721b
	dec de			;721c
	ld b,008h		;721d
	ld a,(de)			;721f
	cp 030h		;7220
	jr nc,L_7236		;7222
	and 00fh		;7224
	cp 001h		;7226
	jr z,L_7236		;7228
	cp 009h		;722a
	jr z,L_7236		;722c
	ld a,c			;722e
	rra			;722f
	jr c,L_723E		;7230
	ld b,016h		;7232
	jr L_723E		;7234
L_7236:
	ld b,016h		;7236
	ld a,c			;7238
	rra			;7239
	jr c,L_723E		;723a
	ld b,032h		;723c
L_723E:
	ld de,0e322h		;723e
	ld hl,0e32ah		;7241
	ld a,(hl)			;7244
	call suma_a_a_de		;7245
	ld a,b			;7248
	ld (de),a			;7249
	inc (hl)			;724a
	ret			;724b
L_724C:
	ld a,(0e2c8h)		;724c
	or a			;724f
	ld c,a			;7250
	jr z,L_727A		;7251
	ld a,(0e1dbh)		;7253
	cp c			;7256
	jr z,L_727A		;7257
	inc a			;7259
	ld (0e1dbh),a		;725a
	ld hl,0e2b3h		;725d
	sla a		;7260
	sla a		;7262
	call suma_a_a_hl		;7264
	ld c,003h		;7267
	call L_6FA5		;7269
	ld de,0e322h		;726c
	ld hl,0e32ah		;726f
	ld a,(hl)			;7272
	call suma_a_a_de		;7273
	xor a			;7276
	ld (de),a			;7277
	inc (hl)			;7278
	ret			;7279
L_727A:
	ld b,012h		;727a
	ld hl,0e13ah		;727c
	ld a,039h		;727f
	push de			;7281
L_7282:
	ld (hl),a			;7282
	inc hl			;7283
	djnz L_7282		;7284
	call L_6F2E		;7286
	pop de			;7289
	ld hl,0e300h		;728a
	ld c,002h		;728d
	call L_6FA5		;728f
	ex de,hl			;7292
	dec de			;7293
	ld b,000h		;7294
	ld a,(de)			;7296
	ld c,a			;7297
	cp 035h		;7298
	jr nc,L_72B0		;729a
	ld hl,0e04ch		;729c
	ld a,(hl)			;729f
	add a,031h		;72a0
	cp c			;72a2
	jr nz,L_72A7		;72a3
	inc b			;72a5
	inc b			;72a6
L_72A7:
	ld hl,0e04dh		;72a7
	ld a,(hl)			;72aa
	add a,031h		;72ab
	cp c			;72ad
	jr nz,L_72B2		;72ae
L_72B0:
	inc b			;72b0
	inc b			;72b1
L_72B2:
	call L_723E		;72b2
	jp L_5B51		;72b5
L_72B8:
	ld c,0ffh		;72b8
	ld a,(0e1d2h)		;72ba
	rra			;72bd
	jr c,L_72CE		;72be
	rra			;72c0
	jr c,L_72D5		;72c1
	rra			;72c3
	jr c,L_72DA		;72c4
	rra			;72c6
	jr c,L_72DF		;72c7
	ld hl,07444h		;72c9
	jr L_72D1		;72cc
L_72CE:
	ld hl,07428h		;72ce
L_72D1:
	ld b,002h		;72d1
	jr L_72E4		;72d3
L_72D5:
	ld hl,0742fh		;72d5
	jr L_72DD		;72d8
L_72DA:
	ld hl,07436h		;72da
L_72DD:
	jr L_72E2		;72dd
L_72DF:
	ld hl,0743dh		;72df
L_72E2:
	ld b,004h		;72e2
L_72E4:
	ex de,hl			;72e4
	ld hl,0e327h		;72e5
	ld (hl),b			;72e8
	ld hl,0e32ah		;72e9
	inc (hl)			;72ec
	ex de,hl			;72ed
	ld de,03acfh		;72ee
	call L_40A3		;72f1
	ld a,(0e1d1h)		;72f4
	rra			;72f7
	ld hl,0744bh		;72f8
	jr c,L_7305		;72fb
	ld hl,0e327h		;72fd
	dec (hl)			;7300
	dec (hl)			;7301
	ld hl,0744eh		;7302
L_7305:
	call L_40A3		;7305
	ld hl,07451h		;7308
	call L_409D		;730b
	ld a,(0e2b6h)		;730e
	or a			;7311
	ld hl,0e1e1h		;7312
	ld (hl),020h		;7315
	ret nz			;7317
	ld a,(0e1d1h)		;7318
	or a			;731b
	ret nz			;731c
	ld (hl),030h		;731d
	ret			;731f
L_7320:
	ld hl,0769ah		;7320
	ld a,(0e32ah)		;7323
	or a			;7326
	jr z,L_7356		;7327
	dec a			;7329
	ld (0e32ah),a		;732a
	add a,a			;732d
	call suma_a_a_hl		;732e
	ld e,(hl)			;7331
	inc hl			;7332
	ld d,(hl)			;7333
	ld hl,0e1d8h		;7334
	inc (hl)			;7337
	ld a,(hl)			;7338
	ld hl,0e321h		;7339
	call suma_a_a_hl		;733c
	ld a,(0e1e1h)		;733f
	ld c,(hl)			;7342
	add a,c			;7343
	daa			;7344
	ld (0e1e1h),a		;7345
	jr nc,L_7353		;7348
	ld a,(0e1e2h)		;734a
	add a,001h		;734d
	daa			;734f
	ld (0e1e2h),a		;7350
L_7353:
	jp L_457E		;7353
L_7356:
	ld hl,0e1e2h		;7356
	ld de,0382bh		;7359
	call L_459C		;735c
	ld hl,0e1e1h		;735f
	ld a,(hl)			;7362
	and 00fh		;7363
	ld a,(hl)			;7365
	jr z,L_736A		;7366
	add a,010h		;7368
L_736A:
	and 0f0h		;736a
	ld (hl),a			;736c
	ld de,0382ch		;736d
	call L_457E		;7370
	jp L_5B51		;7373

; ----------------------------------------------------------------------
; DATOS dibujo_de_la_cabecera: Formato B desde 0x709D: nueve destinos, las
;   filas 0 a 8 de la columna 8.
;   0x7376..0x7404  (142 bytes)
DATA_dibujo_de_la_cabecera:
	defb 008h,078h,006h,067h,081h,000h,003h,06fh,084h,06ah,06fh,06fh,06bh,003h,06fh,084h	; 7376  .x.g...o.jook.o.
	defb 000h,06ch,06dh,06eh,080h,028h,078h,081h,04bh,005h,001h,081h,000h,00ah,001h,081h	; 7386  .lmn.(x.K.......
	defb 000h,003h,001h,080h,048h,078h,006h,068h,081h,000h,00ah,001h,081h,000h,003h,001h	; 7396  ....Hx.h........
	defb 080h,068h,078h,083h,04bh,062h,05dh,003h,001h,081h,000h,00ah,001h,081h,000h,003h	; 73a6  .hx.Kb].........
	defb 001h,080h,083h,078h,005h,067h,006h,068h,081h,000h,00ah,001h,081h,000h,003h,001h	; 73b6  ...x.g.h........
	defb 080h,0a3h,078h,083h,049h,056h,031h,008h,001h,081h,000h,00ah,001h,081h,000h,003h	; 73c6  ..x.IV1.........
	defb 001h,080h,0c3h,078h,00bh,068h,081h,000h,00ah,001h,081h,000h,003h,001h,080h,0e3h	; 73d6  ...x.h..........
	defb 078h,084h,043h,037h,042h,05dh,007h,001h,081h,000h,00ah,001h,081h,000h,003h,001h	; 73e6  x.C7B]..........
	defb 080h,003h,079h,00bh,0dfh,081h,000h,00ah,0dfh,081h,000h,003h,0dfh,000h	; 73f6  ..y...........

; ----------------------------------------------------------------------
; DATOS rotulo_de_tres_filas_b: Formato A: tres tiles en cada una de las filas
;   1, 2 y 3, la version alterna del bloque de 0x7416.
;   0x7404..0x7416  (18 bytes)
DATA_rotulo_de_tres_filas_b:
	defb 023h,038h,070h,071h,072h,0feh,043h,038h,073h,074h,075h,0feh,063h,038h,076h,077h	; 7404  #8pqr.C8stu.c8vw
	defb 078h,0ffh	; 7414

; ----------------------------------------------------------------------
; DATOS rotulo_de_tres_filas: Formato A desde 0x70BC: tres tiles en cada una
;   de las filas 1, 2 y 3.
;   0x7416..0x7428  (18 bytes)
DATA_rotulo_de_tres_filas:
	defb 023h,038h,079h,07ah,07bh,0feh,043h,038h,07ch,07dh,07eh,0feh,063h,038h,001h,07fh	; 7416  #8yz{.C8|}~.c8..
	defb 001h,0ffh	; 7426

; ----------------------------------------------------------------------
; DATOS siete_rotulos_cortos: Siete tiras de numeros de tile terminadas en
;   0xFF, cada una apuntada por su cuenta desde 0x72C9-0x7302: 0x7428, 0x742F,
;   0x7436, 0x743D, 0x7444, 0x744B y 0x744E.
;   0x7428..0x7451  (41 bytes)
DATA_siete_rotulos_cortos:
	defb 00ch,00dh,00eh,00fh,00eh,001h,0ffh,01ah,00eh,01bh,00dh,00eh,001h,0ffh,01ch,025h	; 7428  ...............%
	defb 00eh,01bh,00dh,00eh,0ffh,01dh,00eh,01eh,001h,001h,001h,0ffh,01fh,00dh,020h,024h	; 7438  .............. $
	defb 00eh,001h,0ffh,021h,022h,0ffh,023h,00eh,0ffh	; 7448  ...!".#..

; ----------------------------------------------------------------------
; DATOS rotulo_repetido_seis_veces: Formato A desde 0x730B: el mismo grupo de
;   cuatro tiles en seis sitios de las filas 16, 19 y 22.
;   0x7451..0x747b  (42 bytes)
DATA_rotulo_repetido_seis_veces:
	defb 00ah,03ah,026h,001h,001h,027h,0feh,016h,03ah,026h,001h,001h,027h,0feh,06ah,03ah	; 7451  .:&..'..:&..'.j:
	defb 026h,001h,001h,027h,0feh,076h,03ah,026h,001h,001h,027h,0feh,0cah,03ah,026h,001h	; 7461  &..'.v:&..'..:&.
	defb 001h,027h,0feh,0d7h,03ah,026h,001h,001h,027h,0ffh	; 7471  .'..:&..'.

; ----------------------------------------------------------------------
; DATOS nombres_de_las_jugadas: Treinta y nueve registros de texto en la
;   fuente katakana (tiles 0x30-0x7F), cada uno terminado en 0xFF. El primero
;   (indice 0) es un registro VACIO -un solo 0xFF-, la entrada "ninguna
;   jugada". Dentro de cada registro los bytes 0x01 y 0x00 aparecen como
;   separadores, y el byte que va justo antes del 0xFF final toma solo los
;   valores 0x11, 0x12, 0x13 o 0x15 segun el registro: es SUPOSICION, sin
;   confirmar, que sea el numero de han de la jugada.
;   0x747b..0x7642  (455 bytes)
DATA_nombres_de_las_jugadas:
	defb 0ffh,057h,061h,040h,001h,001h,001h,001h,001h,001h,001h,000h,001h,011h,0ffh,03fh	; 747b  .Wa@...........?
	defb 05eh,04bh,05eh,058h,057h,061h,040h,03eh,037h,000h,001h,013h,0ffh,051h,05dh,03dh	; 748b  ^K^XWa@>7....Q]=
	defb 05eh,05dh,001h,041h,052h,001h,001h,000h,001h,011h,0ffh,049h,031h,042h,031h,001h	; 749b  ^].AR......I1B1.
	defb 041h,052h,001h,001h,001h,000h,001h,012h,0ffh,049h,031h,042h,031h,001h,04bh,057h	; 74ab  AR.......I1B1.KW
	defb 039h,04fh,001h,000h,001h,011h,0ffh,057h,05dh,03bh,064h,05dh,035h,031h,04dh,032h	; 74bb  9O.....W];d]51M2
	defb 001h,000h,001h,011h,0ffh,04ah,05fh,05dh,04bh,001h,001h,001h,001h,001h,001h,000h	; 74cb  .....J_]K.......
	defb 001h,011h,0ffh,03fh,05dh,053h,034h,001h,001h,001h,001h,001h,001h,000h,001h,011h	; 74db  ...?]S4.........
	defb 0ffh,031h,061h,04ch,05fh,061h,039h,032h,001h,001h,001h,000h,001h,011h,0ffh,031h	; 74eb  .1aL_a92.......1
	defb 063h,041h,032h,001h,001h,001h,001h,001h,001h,000h,001h,011h,0ffh,040h,064h,05dh	; 74fb  cA2..........@d]
	defb 03fh,001h,001h,001h,001h,001h,001h,000h,001h,011h,0ffh,03ah,05dh,03bh,036h,001h	; 750b  ?..........:];6.
	defb 001h,001h,001h,001h,001h,000h,001h,011h,0ffh,053h,037h,049h,031h,001h,001h,001h	; 751b  .........S7I1...
	defb 001h,001h,001h,000h,001h,011h,0ffh,03fh,05eh,04bh,05eh,058h,057h,061h,040h,001h	; 752b  .......?^K^XWa@.
	defb 001h,000h,001h,012h,0ffh,057h,061h,040h,03eh,037h,001h,001h,001h,001h,001h,000h	; 753b  .....Wa@>7......
	defb 001h,012h,0ffh,040h,061h,043h,031h,001h,001h,001h,001h,001h,001h,000h,001h,012h	; 754b  ...@aC1.........
	defb 0ffh,03bh,05eh,065h,05dh,040h,064h,05dh,001h,001h,001h,000h,001h,012h,0ffh,043h	; 755b  .;^e]@d].......C
	defb 031h,043h,031h,001h,001h,001h,001h,001h,001h,000h,001h,012h,0ffh,04dh,05dh,031h	; 756b  1C1..........M]1
	defb 041h,001h,001h,001h,001h,001h,001h,000h,001h,012h,0ffh,03ah,05dh,030h,05dh,039h	; 757b  A..........:]0]9
	defb 032h,001h,001h,001h,001h,000h,001h,012h,0ffh,03ah,05dh,035h,05dh,041h,001h,001h	; 758b  2........:]5]A..
	defb 001h,001h,001h,000h,001h,012h,0ffh,04dh,05dh,05ah,061h,043h,032h,001h,001h,001h	; 759b  .......M]ZaC2...
	defb 001h,000h,001h,012h,0ffh,03bh,066h,032h,03ah,05dh,038h,05eh,05dh,001h,001h,000h	; 75ab  .....;f2:]8^]...
	defb 001h,012h,0ffh,057h,064h,05dh,04ch,05fh,031h,039h,032h,001h,001h,000h,001h,013h	; 75bb  ...Wd]L_192.....
	defb 0ffh,03ah,05dh,03bh,036h,043h,05eh,032h,039h,032h,001h,000h,001h,013h,0ffh,040h	; 75cb  .:];6C^292.....@
	defb 05dh,031h,041h,001h,001h,001h,001h,001h,001h,000h,001h,015h,0ffh,03ch,061h,030h	; 75db  ]1A..........<a0
	defb 05dh,039h,032h,0ffh,03ch,061h,035h,05dh,041h,0ffh,041h,061h,031h,061h,03eh,032h	; 75eb  ]92.<a5]A.Aa1a>2
	defb 0ffh,03fh,05eh,031h,03ah,05dh,038h,05eh,05dh,0ffh,040h,05dh,05ah,061h,043h,032h	; 75fb  .?^1:]8^].@]ZaC2
	defb 0ffh,057h,065h,061h,031h,061h,03eh,032h,0ffh,03fh,05eh,031h,03ch,032h,03bh,061h	; 760b  .Wea1a>2.?^1<2;a
	defb 0ffh,039h,037h,03bh,050h,03eh,032h,0ffh,040h,065h,061h,059h,05dh,04dh,05fh,061h	; 761b  .97;P>2.@eaY]M_a
	defb 043h,061h,0ffh,042h,05dh,04dh,061h,0ffh,040h,061h,04dh,061h,0ffh,043h,05eh,056h	; 762b  Ca.B]Ma.@aMa.C^V
	defb 060h,032h,056h,043h,05eh,056h,0ffh	; 763b

; ----------------------------------------------------------------------
; DATOS tabla_de_punteros_de_jugadas: Las 39 palabras que indexan el bloque de
;   arriba. 0x70E7 la usa doblando A (el numero de jugada, 0-38) antes de
;   sumarlo con 0x4063.
;   0x7642..0x7690  (78 bytes)
DATA_tabla_de_punteros_de_jugadas:
	defb 07bh,074h	; 7642
	defb 02eh,076h	; 7644
	defb 033h,076h	; 7646
	defb 01ch,076h	; 7648
	defb 0f5h,075h	; 764a
	defb 014h,076h	; 764c
	defb 0fch,075h	; 764e
	defb 023h,076h	; 7650
	defb 005h,076h	; 7652
	defb 00ch,076h	; 7654
	defb 0e8h,075h	; 7656
	defb 0efh,075h	; 7658
	defb 032h,075h	; 765a
	defb 07ch,074h	; 765c
	defb 040h,075h	; 765e
	defb 08ah,074h	; 7660
	defb 098h,074h	; 7662
	defb 0dah,075h	; 7664
	defb 0beh,075h	; 7666
	defb 0cch,075h	; 7668
	defb 04eh,075h	; 766a
	defb 078h,075h	; 766c
	defb 06ah,075h	; 766e
	defb 05ch,075h	; 7670
	defb 086h,075h	; 7672
	defb 094h,075h	; 7674
	defb 0b0h,075h	; 7676
	defb 0a2h,075h	; 7678
	defb 0d0h,074h	; 767a
	defb 0deh,074h	; 767c
	defb 0ech,074h	; 767e
	defb 0fah,074h	; 7680
	defb 016h,075h	; 7682
	defb 008h,075h	; 7684
	defb 024h,075h	; 7686
	defb 0a6h,074h	; 7688
	defb 0b4h,074h	; 768a
	defb 0c2h,074h	; 768c
	defb 038h,076h	; 768e

; ----------------------------------------------------------------------
; DATOS tabla_de_filas_del_marcador: Once palabras con direcciones de VRAM
;   (fila de nombres), de 0x39E4 a 0x3AA6. 0x7186 la indexa con (0xE1D8)
;   doblado; el mismo bloque, desde su quinta entrada (0x769A), lo vuelve a
;   indexar 0x7320 con (0xE32A) doblado.
;   0x7690..0x76a6  (22 bytes)
DATA_tabla_de_filas_del_marcador:
	defb 0a6h,03ah	; 7690
	defb 050h,03ah	; 7692
	defb 044h,03ah	; 7694
	defb 0f0h,039h	; 7696
	defb 0e4h,039h	; 7698
	defb 0d8h,03ah	; 769a
	defb 0cbh,03ah	; 769c
	defb 077h,03ah	; 769e
	defb 06bh,03ah	; 76a0
	defb 017h,03ah	; 76a2
	defb 00bh,03ah	; 76a4

; ======================================================================
; CODIGO 0x76a6..0x782c  (390 bytes)
; ======================================================================


L_76A6:
	ld hl,0e062h		;76a6
	inc (hl)			;76a9
	ld hl,0782ch		;76aa
	call pinta_lista_formato_b		;76ad
	xor a			;76b0
	ld (0e206h),a		;76b1
	ld a,(0e302h)		;76b4
	push af			;76b7
	call L_66E1		;76b8
	pop af			;76bb
	ld (0e302h),a		;76bc
	ld a,(0e040h)		;76bf
	and 006h		;76c2
	jr z,L_7713		;76c4
	ld a,(0e1cdh)		;76c6
	rra			;76c9
	jr nc,L_7713		;76ca
	call L_47FB		;76cc
	call busca_en_las_dos_listas		;76cf
	ld a,(0e1cdh)		;76d2
	and 060h		;76d5
	jr z,L_7713		;76d7
L_76D9:
	ld hl,0e302h		;76d9
	ld (hl),005h		;76dc
	ld hl,0e1ach		;76de
	set 7,(hl)		;76e1
	ld a,(0e04dh)		;76e3
	rra			;76e6
	jr nc,L_76ED		;76e7
	res 7,(hl)		;76e9
	set 6,(hl)		;76eb
L_76ED:
	ld hl,0e1adh		;76ed
	ld (hl),002h		;76f0
	ld a,(0e1ach)		;76f2
	and 007h		;76f5
	add a,a			;76f7
	ld hl,07853h		;76f8
	call suma_a_a_hl		;76fb
	ld e,(hl)			;76fe
	inc hl			;76ff
	ld d,(hl)			;7700
	ex de,hl			;7701
	call L_409D		;7702
	ld hl,0785bh		;7705
	call L_409D		;7708
	ld a,090h		;770b
	call L_9C4A		;770d
	jp L_77CD		;7710
L_7713:
	ld a,096h		;7713
	call L_9C4A		;7715
	ld a,(0e04bh)		;7718
	cp 005h		;771b
	jr c,L_7756		;771d
	call L_781E		;771f
	ld a,(0e1c3h)		;7722
	ld (0e20ah),a		;7725
	ld (0e209h),a		;7728
	ld a,(de)			;772b
	or a			;772c
	jr z,L_7761		;772d
L_772F:
	ld (0e382h),de		;772f
	ld c,0ffh		;7733
	ld b,001h		;7735
	push de			;7737
	call L_66EB		;7738
	ld a,004h		;773b
	ld (0e302h),a		;773d
	call L_7AF8		;7740
	push af			;7743
	call L_67A1		;7744
	xor a			;7747
	ld (0e316h),a		;7748
	pop af			;774b
	pop de			;774c
	inc de			;774d
	jr nc,L_7761		;774e
	ld a,(de)			;7750
	or a			;7751
	jr nz,L_772F		;7752
	jr L_775C		;7754
L_7756:
	ld a,(0e1cdh)		;7756
	rla			;7759
	jr nc,L_7761		;775a
L_775C:
	ld hl,0e1adh		;775c
	set 0,(hl)		;775f
L_7761:
	ld hl,0e1cdh		;7761
	res 7,(hl)		;7764
	ld a,(0e208h)		;7766
	ld (0e209h),a		;7769
	ld (0e20ah),a		;776c
	ld hl,0e27bh		;776f
	ld de,0e2b6h		;7772
	ld bc,0003bh		;7775
	ldir		;7778
	ld hl,0e14ch		;777a
	ld de,0e32bh		;777d
	ld bc,0000eh		;7780
	ldir		;7783
	call L_66E1		;7785
	ld a,(0e04bh)		;7788
	cp 005h		;778b
	jr c,L_77C2		;778d
	call L_781E		;778f
	ld a,(de)			;7792
	or a			;7793
	jr z,L_77CD		;7794
L_7796:
	ld (0e382h),de		;7796
	ld c,0ffh		;779a
	ld b,001h		;779c
	push de			;779e
	call L_66EB		;779f
	ld a,006h		;77a2
	ld (0e302h),a		;77a4
	call L_7AF8		;77a7
	ld a,004h		;77aa
	ld (0e302h),a		;77ac
	push af			;77af
	call L_67A1		;77b0
	xor a			;77b3
	ld (0e316h),a		;77b4
	pop af			;77b7
	pop de			;77b8
	inc de			;77b9
	jr nc,L_77CD		;77ba
	ld a,(de)			;77bc
	or a			;77bd
	jr nz,L_7796		;77be
	jr L_77C8		;77c0
L_77C2:
	ld a,(0e1cdh)		;77c2
	rla			;77c5
	jr nc,L_77CD		;77c6
L_77C8:
	ld hl,0e1adh		;77c8
	set 1,(hl)		;77cb
L_77CD:
	ld a,004h		;77cd
	ld (0e302h),a		;77cf
	call L_780A		;77d2
	ld a,(0e1adh)		;77d5
	cp 003h		;77d8
	ret z			;77da
	or a			;77db
	call nz,L_7814		;77dc
	ld c,a			;77df
	ld a,(0e04dh)		;77e0
	rra			;77e3
	jr nc,L_7800		;77e4
	ld a,c			;77e6
	rra			;77e7
	rra			;77e8
	ret c			;77e9
	ld a,(0e04ch)		;77ea
	rra			;77ed
	ret c			;77ee
L_77EF:
	ld a,(0e04ch)		;77ef
	xor 001h		;77f2
	ld (0e04ch),a		;77f4
L_77F7:
	ld a,(0e04dh)		;77f7
	xor 001h		;77fa
	ld (0e04dh),a		;77fc
	ret			;77ff
L_7800:
	ld a,c			;7800
	rra			;7801
	ret c			;7802
	ld a,(0e04ch)		;7803
	rra			;7806
	jr nc,L_77F7		;7807
	ret			;7809
L_780A:
	ld a,(0e04bh)		;780a
	add a,001h		;780d
	daa			;780f
	ld (0e04bh),a		;7810
	ret			;7813
L_7814:
	ld hl,00015h		;7814
	ld (0e1b1h),hl		;7817
	ld (0e1e4h),hl		;781a
	ret			;781d
L_781E:
	ld hl,0e1f5h		;781e
	ld de,0e348h		;7821
	push de			;7824
	ld bc,0000ch		;7825
	ldir		;7828
	pop de			;782a
	ret			;782b

; ----------------------------------------------------------------------
; DATOS dibujo_de_cinco_filas: Formato B desde 0x76AD: cinco destinos entre
;   las filas 9 y 13.
;   0x782c..0x7853  (39 bytes)
DATA_dibujo_de_cinco_filas:
	defb 034h,079h,002h,001h,080h,051h,079h,007h,001h,080h,071h,079h,088h,001h,0c0h,0c6h	; 782c  4y...Qy...qy....
	defb 001h,0cch,0d2h,001h,001h,080h,091h,079h,088h,001h,0c1h,0c7h,001h,0cdh,0d3h,001h	; 783c  .......y........
	defb 001h,080h,0b1h,079h,007h,001h,000h	; 784c

; ----------------------------------------------------------------------
; DATOS rotulo_largo (tramo): Formato A desde 0x7702: quince tiles seguidos en
;   la fila 3.
;   0x7853..0x785b  (8 bytes)  de 0x7853..0x7865 (18 bytes)
DATA_rotulo_largo:
	defb 065h,078h,06fh,078h,079h,078h,079h,078h	; 7853  exoxyxyx

; ----------------------------------------------------------------------
; DATOS rotulo_corto: Formato A desde 0x7708: los siete ultimos tiles del
;   bloque anterior, en la fila 12. Los dos rotulos COMPARTEN los mismos
;   bytes; el corto entra por en medio del largo.
;   0x785b..0x7865  (10 bytes)
DATA_rotulo_corto:
	defb 082h,039h,002h,002h,0f1h,049h,0f0h,0f7h,0e4h,0ffh	; 785b  .9...I....

; ----------------------------------------------------------------------
; DATOS tres_dibujos_de_la_fila_11: Tres listas de formato A de diez bytes,
;   las tres al mismo destino 0x3962. No las apunta ningun inmediato: se llega
;   a ellas calculando.
;   0x7865..0x7883  (30 bytes)
DATA_tres_dibujos_de_la_fila_11:
	defb 062h,039h,002h,004h,0f6h,06dh,0f0h,002h,002h,0ffh,062h,039h,002h,005h,003h,0fdh	; 7865  b9...m....b9....
	defb 0e4h,006h,002h,0ffh,062h,039h,002h,007h,008h,009h,006h,002h,002h,0ffh	; 7875  ....b9........

; ======================================================================
; CODIGO 0x7883..0x7aea  (615 bytes)
; ======================================================================


L_7883:
	ld hl,(0e05bh)		;7883
	ld de,0e2b6h		;7886
L_7889:
	ld a,(hl)			;7889
	and 07fh		;788a
	ld c,a			;788c
	ld a,(hl)			;788d
	inc hl			;788e
	ret z			;788f
	ld b,000h		;7890
	cp c			;7892
	push af			;7893
	call nz,L_78AA		;7894
	pop af			;7897
	call z,L_78BA		;7898
	ld a,(0e05ah)		;789b
	cp 030h		;789e
	jr nz,L_7889		;78a0
	xor a			;78a2
	ld (0e05ah),a		;78a3
	ld (0e05bh),hl		;78a6
	ret			;78a9
L_78AA:
	ld a,(hl)			;78aa
	ld (de),a			;78ab
	push hl			;78ac
	ld hl,0e05ah		;78ad
	inc (hl)			;78b0
	pop hl			;78b1
	inc hl			;78b2
	inc de			;78b3
	dec bc			;78b4
	ld a,b			;78b5
	or c			;78b6
	jr nz,L_78AA		;78b7
	ret			;78b9
L_78BA:
	ld a,(hl)			;78ba
	inc hl			;78bb
	push hl			;78bc
	push af			;78bd
L_78BE:
	pop af			;78be
	ld (de),a			;78bf
	ld hl,0e05ah		;78c0
	inc (hl)			;78c3
	inc de			;78c4
	dec bc			;78c5
	push af			;78c6
	ld a,b			;78c7
	or c			;78c8
	jr nz,L_78BE		;78c9
	pop af			;78cb
	pop hl			;78cc
	ret			;78cd
L_78CE:
	ld a,(0e002h)		;78ce
	bit 6,a		;78d1
	jr nz,L_78E8		;78d3
	ld hl,0e058h		;78d5
	ld (hl),081h		;78d8
	ld de,0e21ch		;78da
	ld hl,07aeah		;78dd
	ld bc,0000eh		;78e0
	ldir		;78e3
	jp L_7AAF		;78e5
L_78E8:
	ld hl,0e056h		;78e8
	ld (hl),000h		;78eb
	inc hl			;78ed
	ld (hl),000h		;78ee
	ld hl,0e058h		;78f0
	ld (hl),000h		;78f3
	ld a,(0e100h)		;78f5
	rla			;78f8
	rla			;78f9
	ld (hl),004h		;78fa
	jr c,L_7944		;78fc
	ld a,(0e046h)		;78fe
	or a			;7901
	ld (hl),002h		;7902
	jr z,L_7944		;7904
	ld a,(0e04bh)		;7906
	cp 005h		;7909
	jr c,L_7938		;790b
	ld c,a			;790d
	ld a,(0e04dh)		;790e
	rra			;7911
	jr nc,L_7919		;7912
	ld a,c			;7914
	cp 008h		;7915
	jr nc,L_7938		;7917
L_7919:
	call L_7AE5		;7919
	cp 021h		;791c
	ld hl,0e058h		;791e
	ld (hl),004h		;7921
	jr z,L_7950		;7923
	sra (hl)		;7925
	cp 019h		;7927
	jr nc,L_7950		;7929
	cp 00fh		;792b
	jp nc,L_7A27		;792d
	ld (hl),001h		;7930
	cp 008h		;7932
	jr nc,L_7987		;7934
	ld (hl),002h		;7936
L_7938:
	call L_7AE5		;7938
	ld hl,0e058h		;793b
	cp 01eh		;793e
	jr nc,L_7944		;7940
	sra (hl)		;7942
L_7944:
	call L_7AE5		;7944
	cp 021h		;7947
	jr c,L_7950		;7949
	ld hl,0e058h		;794b
	ld (hl),009h		;794e
L_7950:
	call L_7AE5		;7950
	ld hl,04fbfh		;7953
	call suma_a_a_hl		;7956
	ld a,(hl)			;7959
	cp 030h		;795a
	jr nc,L_7944		;795c
	and 0f0h		;795e
	ld (0e059h),a		;7960
	call L_7AE5		;7963
	cp 021h		;7966
	jr z,L_7987		;7968
	cp 020h		;796a
	jr z,L_7983		;796c
	cp 01fh		;796e
	jp z,L_7A27		;7970
	cp 017h		;7973
	jr nc,L_79D5		;7975
	cp 008h		;7977
	jr nc,L_797F		;7979
	ld a,006h		;797b
	jr L_798E		;797d
L_797F:
	ld a,003h		;797f
	jr L_798E		;7981
L_7983:
	ld a,009h		;7983
	jr L_798E		;7985
L_7987:
	ld a,00ch		;7987
	ld hl,0e058h		;7989
	set 5,(hl)		;798c
L_798E:
	ld hl,0e057h		;798e
	ld (hl),a			;7991
L_7992:
	call L_7AB8		;7992
	call L_7ADA		;7995
	ld a,(hl)			;7998
	cp 002h		;7999
	jr nc,L_7992		;799b
	ld a,(0e058h)		;799d
	bit 3,a		;79a0
	jr z,L_79B3		;79a2
	ld a,c			;79a4
	cp 030h		;79a5
	jr nc,L_79B3		;79a7
	and 00fh		;79a9
	cp 001h		;79ab
	jr z,L_79B3		;79ad
	cp 009h		;79af
	jr nz,L_7992		;79b1
L_79B3:
	ex de,hl			;79b3
	inc (hl)			;79b4
	inc (hl)			;79b5
	inc (hl)			;79b6
	ld hl,(0e054h)		;79b7
	ld (hl),c			;79ba
	inc hl			;79bb
	ld (hl),c			;79bc
	inc hl			;79bd
	ld (hl),c			;79be
	inc hl			;79bf
	ld (0e054h),hl		;79c0
	ld hl,0e056h		;79c3
	inc (hl)			;79c6
	inc (hl)			;79c7
	inc (hl)			;79c8
	ld a,(hl)			;79c9
	ld hl,0e057h		;79ca
	cp (hl)			;79cd
	jr nz,L_7992		;79ce
	cp 00ch		;79d0
	jp z,L_7A69		;79d2
L_79D5:
	call L_7AB8		;79d5
	ld a,b			;79d8
	cp 030h		;79d9
	jr nc,L_79D5		;79db
	and 00fh		;79dd
	cp 008h		;79df
	jr nc,L_79D5		;79e1
	call L_7ADA		;79e3
	ld b,003h		;79e6
L_79E8:
	ld a,(hl)			;79e8
	cp 004h		;79e9
	jr nc,L_79D5		;79eb
	inc hl			;79ed
	djnz L_79E8		;79ee
	ld a,(0e058h)		;79f0
	bit 3,a		;79f3
	jr z,L_7A02		;79f5
	ld a,c			;79f7
	and 00fh		;79f8
	cp 001h		;79fa
	jr z,L_7A02		;79fc
	cp 007h		;79fe
	jr nz,L_79D5		;7a00
L_7A02:
	ex de,hl			;7a02
	inc (hl)			;7a03
	inc hl			;7a04
	inc (hl)			;7a05
	inc hl			;7a06
	inc (hl)			;7a07
	ld hl,(0e054h)		;7a08
	ld (hl),c			;7a0b
	inc hl			;7a0c
	inc c			;7a0d
	ld (hl),c			;7a0e
	inc hl			;7a0f
	inc c			;7a10
	ld (hl),c			;7a11
	inc hl			;7a12
	ld (0e054h),hl		;7a13
	ld hl,0e056h		;7a16
	inc (hl)			;7a19
	inc (hl)			;7a1a
	inc (hl)			;7a1b
	ld a,(hl)			;7a1c
	cp 00ch		;7a1d
	jr nz,L_79D5		;7a1f
	xor a			;7a21
	ld (0e056h),a		;7a22
	jr L_7A69		;7a25
L_7A27:
	call L_7AB8		;7a27
	call L_7ADA		;7a2a
	ld a,(hl)			;7a2d
	cp 002h		;7a2e
	jr nc,L_7A27		;7a30
	ld a,(0e058h)		;7a32
	bit 3,a		;7a35
	jr z,L_7A48		;7a37
	ld a,c			;7a39
	cp 030h		;7a3a
	jr nc,L_7A48		;7a3c
	and 00fh		;7a3e
	cp 001h		;7a40
	jr z,L_7A48		;7a42
	cp 009h		;7a44
	jr nz,L_7A27		;7a46
L_7A48:
	inc (hl)			;7a48
	inc (hl)			;7a49
	ld hl,(0e054h)		;7a4a
	ld (hl),c			;7a4d
	inc hl			;7a4e
	ld (hl),c			;7a4f
	inc hl			;7a50
	ld (0e054h),hl		;7a51
	ld a,(0e056h)		;7a54
	add a,002h		;7a57
	ld (0e056h),a		;7a59
	cp 00ch		;7a5c
	jr nz,L_7A27		;7a5e
	xor a			;7a60
	ld (0e056h),a		;7a61
	ld hl,0e058h		;7a64
	set 7,(hl)		;7a67
L_7A69:
	call L_7AB8		;7a69
	call L_7ADA		;7a6c
	ld a,(hl)			;7a6f
	cp 002h		;7a70
	jr nc,L_7A69		;7a72
	ld a,(0e058h)		;7a74
	bit 3,a		;7a77
	jr z,L_7A8A		;7a79
	ld a,c			;7a7b
	cp 030h		;7a7c
	jr nc,L_7A8A		;7a7e
	and 00fh		;7a80
	cp 001h		;7a82
	jr z,L_7A8A		;7a84
	cp 009h		;7a86
	jr nz,L_7A69		;7a88
L_7A8A:
	ex de,hl			;7a8a
	inc (hl)			;7a8b
	inc (hl)			;7a8c
	ld hl,(0e054h)		;7a8d
	ld (hl),c			;7a90
	inc hl			;7a91
	ld (hl),c			;7a92
L_7A93:
	call L_7AE5		;7a93
	cp 00eh		;7a96
	jr nc,L_7A93		;7a98
	ld hl,0e040h		;7a9a
	bit 1,(hl)		;7a9d
	jr nz,L_7AA5		;7a9f
	cp 00ch		;7aa1
	jr nc,L_7AA7		;7aa3
L_7AA5:
	ld a,00bh		;7aa5
L_7AA7:
	ld hl,0e21ch		;7aa7
	call suma_a_a_hl		;7aaa
	ld (hl),039h		;7aad
L_7AAF:
	ld hl,0e21ch		;7aaf
	ld (0e054h),hl		;7ab2
	jp L_4F99		;7ab5
L_7AB8:
	call L_7AE5		;7ab8
	ld c,a			;7abb
	ld de,04fbfh		;7abc
	call suma_a_a_de		;7abf
	ld a,(de)			;7ac2
	ld b,a			;7ac3
	and 0f0h		;7ac4
	ld d,a			;7ac6
	ld a,(0e058h)		;7ac7
	rra			;7aca
	ret c			;7acb
	rra			;7acc
	jr nc,L_7AD3		;7acd
	ld a,d			;7acf
	cp 030h		;7ad0
	ret z			;7ad2
L_7AD3:
	ld a,(0e059h)		;7ad3
	cp d			;7ad6
	ret z			;7ad7
	jr L_7AB8		;7ad8
L_7ADA:
	ld a,c			;7ada
	ld c,b			;7adb
	ld hl,0e186h		;7adc
	call suma_a_a_hl		;7adf
	ld d,h			;7ae2
	ld e,l			;7ae3
	ret			;7ae4
L_7AE5:
	call saca_un_numero_al_azar		;7ae5
	ld a,h			;7ae8
	ret			;7ae9

; ----------------------------------------------------------------------
; DATOS mano_de_ejemplo_2: Catorce bytes que 0x78DD copia con LDIR a partir de
;   0xE21C, el mismo formato de mano que 0x4968: 0x32 0x39 0x08 0x08 0x17 0x17
;   0x25 0x25 0x33 0x33 0x13 0x13 0x21 0x21. El byte 0x39 en la segunda
;   posicion NO es un codigo de ficha valido (el 0x38 ya es "hueco vacio"), y
;   justo despues 0x7AAD sobreescribe el hueco de indice 11 con otro 0x39: dos
;   huecos de los catorce quedan marcados igual, y los otros doce forman SEIS
;   parejas (0x08, 0x17, 0x25, 0x33, 0x13, 0x21, cada uno dos veces). Es
;   SUPOSICION, no confirmada: podria ser una mano de siete parejas
;   (chiitoitsu) con dos huecos por rellenar en tiempo real.
;   0x7aea..0x7af8  (14 bytes)
DATA_mano_de_ejemplo_2:
	defb 032h,039h,008h,008h,017h,017h,025h,025h,033h,033h,013h,013h,021h,021h	; 7aea  29....%%33..!!

; ======================================================================
; CODIGO 0x7af8..0x7cd5  (477 bytes)
; ======================================================================


L_7AF8:
	call L_7B3F		;7af8
	ld a,(0e302h)		;7afb
	bit 2,a		;7afe
	jr nz,L_7B38		;7b00
	ld a,(0e305h)		;7b02
	or a			;7b05
	jr nz,L_7B11		;7b06
L_7B08:
	ld hl,0e1ach		;7b08
	ld (hl),003h		;7b0b
	pop hl			;7b0d
	jp L_4280		;7b0e
L_7B11:
	ld a,(0e04bh)		;7b11
	cp 005h		;7b14
	jr c,L_7B28		;7b16
	call L_7B2E		;7b18
	ld a,(0e305h)		;7b1b
	cp 00ch		;7b1e
	jr c,L_7B28		;7b20
	ld a,(0e316h)		;7b22
	dec a			;7b25
	jr z,L_7B08		;7b26
L_7B28:
	call L_81A9		;7b28
	call L_82F9		;7b2b
L_7B2E:
	ld hl,0e305h		;7b2e
	ld a,(0e315h)		;7b31
	ld b,a			;7b34
	jp L_4F9B		;7b35
L_7B38:
	ld a,(0e316h)		;7b38
	cp 003h		;7b3b
	ccf			;7b3d
	ret			;7b3e
L_7B3F:
	xor a			;7b3f
	ld (0e1d2h),a		;7b40
	ld (0e127h),a		;7b43
	call L_5BDB		;7b46
	call L_5C1B		;7b49
	call L_5C42		;7b4c
	ld a,(0e205h)		;7b4f
	bit 1,a		;7b52
	ld bc,00003h		;7b54
	jp nz,L_7BF9		;7b57
	rra			;7b5a
	ld bc,00214h		;7b5b
	call c,L_82E6		;7b5e
	call L_7C48		;7b61
	call L_8290		;7b64
	call L_82F9		;7b67
	call L_7DAB		;7b6a
	call L_7EC1		;7b6d
	call L_7EE0		;7b70
	call L_80BC		;7b73
	call L_7BAF		;7b76
	call L_7BFC		;7b79
	call L_82F9		;7b7c
	call L_7C7C		;7b7f
	call L_7D83		;7b82
	call L_7D98		;7b85
	call L_7EB1		;7b88
	call L_82F9		;7b8b
	call L_7F0C		;7b8e
	call L_80F2		;7b91
	call L_82F9		;7b94
	call L_7F4C		;7b97
	call L_8016		;7b9a
	call L_8053		;7b9d
	call L_8118		;7ba0
	call L_82F9		;7ba3
	call L_813E		;7ba6
	call L_818C		;7ba9
	jp L_82A4		;7bac
L_7BAF:
	ld a,(0e302h)		;7baf
	bit 1,a		;7bb2
	ret nz			;7bb4
	ld hl,0e1cdh		;7bb5
	ld a,(hl)			;7bb8
	rra			;7bb9
	ret nc			;7bba
	ld a,(0e1cch)		;7bbb
	or a			;7bbe
	jr nz,L_7BC3		;7bbf
	set 1,(hl)		;7bc1
L_7BC3:
	ld c,a			;7bc3
	ld de,0e15eh		;7bc4
	call suma_a_a_de		;7bc7
	ld a,(de)			;7bca
	cp 039h		;7bcb
	jr z,L_7BD7		;7bcd
	ld a,(0e1beh)		;7bcf
	cp c			;7bd2
	jr nz,L_7BD7		;7bd3
	set 2,(hl)		;7bd5
L_7BD7:
	ld a,(hl)			;7bd7
	and 007h		;7bd8
	or a			;7bda
	ret z			;7bdb
	dec a			;7bdc
	jr z,L_7BEC		;7bdd
	dec a			;7bdf
	dec a			;7be0
	jr z,L_7BF1		;7be1
	dec a			;7be3
	dec a			;7be4
	jr z,L_7BF6		;7be5
	ld bc,0030fh		;7be7
	jr L_7BEF		;7bea
L_7BEC:
	ld bc,0010dh		;7bec
L_7BEF:
	jr L_7BF4		;7bef
L_7BF1:
	ld bc,0020ch		;7bf1
L_7BF4:
	jr L_7BF9		;7bf4
L_7BF6:
	ld bc,0020eh		;7bf6
L_7BF9:
	jp L_82E6		;7bf9
L_7BFC:
	ld a,(0e302h)		;7bfc
	bit 1,a		;7bff
	ret z			;7c01
	ld hl,0e1aeh		;7c02
	ld a,(hl)			;7c05
	rra			;7c06
	ret nc			;7c07
	ld a,(0e1bbh)		;7c08
	or a			;7c0b
	jr nz,L_7C10		;7c0c
	set 1,(hl)		;7c0e
L_7C10:
	ld c,a			;7c10
	ld de,0e172h		;7c11
	call suma_a_a_de		;7c14
	ld a,(de)			;7c17
	cp 039h		;7c18
	jr z,L_7C24		;7c1a
	ld a,(0e1bfh)		;7c1c
	cp c			;7c1f
	jr nz,L_7C24		;7c20
	set 2,(hl)		;7c22
L_7C24:
	ld a,(hl)			;7c24
	and 007h		;7c25
	or a			;7c27
	ret z			;7c28
	dec a			;7c29
	jr z,L_7C39		;7c2a
	dec a			;7c2c
	dec a			;7c2d
	jr z,L_7C3E		;7c2e
	dec a			;7c30
	dec a			;7c31
	jr z,L_7C43		;7c32
	ld bc,0030fh		;7c34
	jr L_7C3C		;7c37
L_7C39:
	ld bc,0010dh		;7c39
L_7C3C:
	jr L_7C41		;7c3c
L_7C3E:
	ld bc,0020ch		;7c3e
L_7C41:
	jr L_7C46		;7c41
L_7C43:
	ld bc,0020eh		;7c43
L_7C46:
	jr L_7BF9		;7c46
L_7C48:
	ld a,(0e04dh)		;7c48
	rra			;7c4b
	ld hl,0e1beh		;7c4c
	ld de,0e1bfh		;7c4f
	jr nc,L_7C55		;7c52
	ex de,hl			;7c54
L_7C55:
	ld a,(0e1d1h)		;7c55
	ld b,a			;7c58
	rra			;7c59
	ld c,014h		;7c5a
	jr nc,L_7C5F		;7c5c
	dec c			;7c5e
L_7C5F:
	ld a,(hl)			;7c5f
	cp c			;7c60
	jr nc,L_7C6A		;7c61
	ld a,(de)			;7c63
	dec c			;7c64
	cp c			;7c65
	ret c			;7c66
	ld a,b			;7c67
	rra			;7c68
	ret c			;7c69
L_7C6A:
	ld a,b			;7c6a
	ld bc,00124h		;7c6b
	rra			;7c6e
	jr nc,L_7C79		;7c6f
	ld bc,00223h		;7c71
	ld hl,0e1d0h		;7c74
	ld (hl),001h		;7c77
L_7C79:
	jp L_82E6		;7c79
L_7C7C:
	ld a,(0e2c8h)		;7c7c
	cp 003h		;7c7f
	ret c			;7c81
	call L_7CC4		;7c82
	call L_82F9		;7c85
	call L_7D17		;7c88
	ld a,(0e2c8h)		;7c8b
	cp 004h		;7c8e
	ret nz			;7c90
	ld a,(0e2b6h)		;7c91
	or a			;7c94
	ret nz			;7c95
	ld a,(0e1d1h)		;7c96
	or a			;7c99
	ret nz			;7c9a
	ld a,(0e300h)		;7c9b
	cp 035h		;7c9e
	ret nc			;7ca0
	sub 031h		;7ca1
	ld hl,0e04ch		;7ca3
	cp (hl)			;7ca6
	ret z			;7ca7
	ld c,a			;7ca8
	ld a,(0e302h)		;7ca9
	bit 1,a		;7cac
	ld hl,0e04dh		;7cae
	ld a,(hl)			;7cb1
	jr z,L_7CB6		;7cb2
	xor 001h		;7cb4
L_7CB6:
	cp c			;7cb6
	ret z			;7cb7
	ld hl,0e1d2h		;7cb8
	bit 0,(hl)		;7cbb
	ret z			;7cbd
	ld bc,0011ch		;7cbe
	jp L_82E6		;7cc1
L_7CC4:
	ld hl,07cd5h		;7cc4
	ld b,003h		;7cc7
L_7CC9:
	push bc			;7cc9
	xor a			;7cca
	ld (0e127h),a		;7ccb
	call L_7CDE		;7cce
	pop bc			;7cd1
	djnz L_7CC9		;7cd2
	ret			;7cd4

; ----------------------------------------------------------------------
; DATOS los_nueve_comienzos_de_escalera: 0x01 0x04 0x07, 0x11 0x14 0x17 y 0x21
;   0x24 0x27: los tres sitios por donde puede empezar una escalera en cada
;   uno de los tres palos. La lee 0x7CC4.
;   0x7cd5..0x7cde  (9 bytes)
DATA_los_nueve_comienzos_de_escalera:
	defb 001h,004h,007h,011h,014h,017h,021h,024h,027h	; 7cd5  ......!$'

; ======================================================================
; CODIGO 0x7cde..0x83b1  (1747 bytes)
; ======================================================================


L_7CDE:
	ld c,003h		;7cde
L_7CE0:
	call L_7CFE		;7ce0
	inc hl			;7ce3
	dec c			;7ce4
	jr nz,L_7CE0		;7ce5
	ld a,(0e127h)		;7ce7
	cp 003h		;7cea
	ret c			;7cec
	ld a,(0e2b6h)		;7ced
	or a			;7cf0
	ld bc,0011fh		;7cf1
	jr nz,L_7CF8		;7cf4
	ld b,002h		;7cf6
L_7CF8:
	call L_82E6		;7cf8
	pop bc			;7cfb
	pop bc			;7cfc
	ret			;7cfd
L_7CFE:
	ld de,0e2b7h		;7cfe
	ld b,004h		;7d01
L_7D03:
	ld a,(de)			;7d03
	cp (hl)			;7d04
	jr nz,L_7D0F		;7d05
	ld a,(0e127h)		;7d07
	inc a			;7d0a
	ld (0e127h),a		;7d0b
	ret			;7d0e
L_7D0F:
	ld a,004h		;7d0f
	call suma_a_a_de		;7d11
	djnz L_7D03		;7d14
	ret			;7d16
L_7D17:
	ld a,(0e2c8h)		;7d17
	ld b,a			;7d1a
	ld hl,0e2b7h		;7d1b
	ld de,0e127h		;7d1e
	ld c,000h		;7d21
L_7D23:
	ld a,(hl)			;7d23
	and 0f0h		;7d24
	jr nz,L_7D2C		;7d26
	ld a,(hl)			;7d28
	ld (de),a			;7d29
	inc de			;7d2a
	inc c			;7d2b
L_7D2C:
	ld a,004h		;7d2c
	call suma_a_a_hl		;7d2e
	djnz L_7D23		;7d31
	ld a,c			;7d33
	or a			;7d34
	ret z			;7d35
	cp 003h		;7d36
	ret nc			;7d38
	call L_7D4A		;7d39
	ld a,(0e2b6h)		;7d3c
	or a			;7d3f
	ld bc,00120h		;7d40
	jr nz,L_7D47		;7d43
	ld b,002h		;7d45
L_7D47:
	jp L_82E6		;7d47
L_7D4A:
	ld de,0e127h		;7d4a
	ld c,002h		;7d4d
L_7D4F:
	ld a,(0e2c8h)		;7d4f
	or a			;7d52
	ret z			;7d53
	ld b,a			;7d54
	ld hl,0e2b7h		;7d55
L_7D58:
	ld a,(de)			;7d58
	add a,010h		;7d59
	cp (hl)			;7d5b
	jr z,L_7D6B		;7d5c
	ld a,004h		;7d5e
	call suma_a_a_hl		;7d60
	djnz L_7D58		;7d63
	inc de			;7d65
	dec c			;7d66
	jr nz,L_7D4F		;7d67
	pop hl			;7d69
	ret			;7d6a
L_7D6B:
	ld (de),a			;7d6b
	ld a,(0e2c8h)		;7d6c
	or a			;7d6f
	ret z			;7d70
	ld b,a			;7d71
	ld hl,0e2b7h		;7d72
L_7D75:
	ld a,(de)			;7d75
	add a,010h		;7d76
	cp (hl)			;7d78
	ret z			;7d79
	ld a,004h		;7d7a
	call suma_a_a_hl		;7d7c
	djnz L_7D75		;7d7f
	pop hl			;7d81
	ret			;7d82
L_7D83:
	ld a,(0e2b6h)		;7d83
	or a			;7d86
	ret nz			;7d87
	ld a,(0e303h)		;7d88
	or a			;7d8b
	ret z			;7d8c
	dec a			;7d8d
	ld bc,0011eh		;7d8e
	jr z,L_7D96		;7d91
	ld bc,00312h		;7d93
L_7D96:
	jr L_7D47		;7d96
L_7D98:
	ld a,(0e2f0h)		;7d98
	cp 003h		;7d9b
	ret c			;7d9d
	cp 004h		;7d9e
	ld bc,0000bh		;7da0
	jr z,L_7DA8		;7da3
	ld bc,00219h		;7da5
L_7DA8:
	jp L_82E6		;7da8
L_7DAB:
	ld a,(0e2dah)		;7dab
	ld hl,0e2f0h		;7dae
	add a,(hl)			;7db1
	cp 003h		;7db2
	ret c			;7db4
	push af			;7db5
	call L_7DE7		;7db6
	pop af			;7db9
	jr z,L_7DD9		;7dba
	ld bc,00216h		;7dbc
	ld hl,0e1e0h		;7dbf
	ld (hl),001h		;7dc2
	call L_82E6		;7dc4
	ld a,(0e2d9h)		;7dc7
	ld hl,0e2efh		;7dca
	add a,(hl)			;7dcd
	cp 002h		;7dce
	ret nc			;7dd0
	or a			;7dd1
	ld bc,0000ah		;7dd2
	jr z,L_7DE4		;7dd5
	jr L_7DE1		;7dd7
L_7DD9:
	ld a,(0e2d9h)		;7dd9
	ld hl,0e2efh		;7ddc
	add a,(hl)			;7ddf
	ret nz			;7de0
L_7DE1:
	ld bc,00218h		;7de1
L_7DE4:
	jp L_82E6		;7de4
L_7DE7:
	ld a,(0e2dah)		;7de7
	or a			;7dea
	jr z,L_7DFE		;7deb
	ld b,a			;7ded
	ld hl,0e2c9h		;7dee
	ld de,0e128h		;7df1
	ld c,000h		;7df4
	ld a,004h		;7df6
	ld (0e127h),a		;7df8
	call L_7E9F		;7dfb
L_7DFE:
	ld a,(0e2f0h)		;7dfe
	or a			;7e01
	jr z,L_7E12		;7e02
	ld b,a			;7e04
	ld hl,0e2dbh		;7e05
	ld c,000h		;7e08
	ld a,005h		;7e0a
	ld (0e127h),a		;7e0c
	call L_7E9F		;7e0f
L_7E12:
	ld a,c			;7e12
	or a			;7e13
	ret z			;7e14
	cp 003h		;7e15
	ret nc			;7e17
	ld c,a			;7e18
	call L_7E22		;7e19
	ld bc,00313h		;7e1c
	jp L_82E6		;7e1f
L_7E22:
	ld de,0e128h		;7e22
	ld c,002h		;7e25
L_7E27:
	ld a,(0e2dah)		;7e27
	or a			;7e2a
	jr z,L_7E42		;7e2b
	ld b,a			;7e2d
	ld hl,0e2c9h		;7e2e
L_7E31:
	ld a,(de)			;7e31
	add a,010h		;7e32
	cp (hl)			;7e34
	jr z,L_7E64		;7e35
	ld a,004h		;7e37
	call suma_a_a_hl		;7e39
	djnz L_7E31		;7e3c
	inc de			;7e3e
	dec c			;7e3f
	jr nz,L_7E27		;7e40
L_7E42:
	ld de,0e128h		;7e42
	ld c,002h		;7e45
L_7E47:
	ld a,(0e2f0h)		;7e47
	or a			;7e4a
	jr z,L_7E9D		;7e4b
	ld b,a			;7e4d
	ld hl,0e2dbh		;7e4e
L_7E51:
	ld a,(de)			;7e51
	add a,010h		;7e52
	cp (hl)			;7e54
	jr z,L_7E64		;7e55
	ld a,005h		;7e57
	call suma_a_a_hl		;7e59
	djnz L_7E51		;7e5c
	inc de			;7e5e
	dec c			;7e5f
	jr nz,L_7E47		;7e60
	jr L_7E9D		;7e62
L_7E64:
	ld (de),a			;7e64
	ld c,002h		;7e65
L_7E67:
	ld a,(0e2dah)		;7e67
	or a			;7e6a
	jr z,L_7E81		;7e6b
	ld b,a			;7e6d
	ld hl,0e2c9h		;7e6e
L_7E71:
	ld a,(de)			;7e71
	add a,010h		;7e72
	cp (hl)			;7e74
	ret z			;7e75
	ld a,004h		;7e76
	call suma_a_a_hl		;7e78
	djnz L_7E71		;7e7b
	inc de			;7e7d
	dec c			;7e7e
	jr nz,L_7E67		;7e7f
L_7E81:
	ld c,002h		;7e81
L_7E83:
	ld a,(0e2f0h)		;7e83
	or a			;7e86
	jr z,L_7E9D		;7e87
	ld b,a			;7e89
	ld hl,0e2dbh		;7e8a
L_7E8D:
	ld a,(de)			;7e8d
	add a,010h		;7e8e
	cp (hl)			;7e90
	ret z			;7e91
	ld a,005h		;7e92
	call suma_a_a_hl		;7e94
	djnz L_7E8D		;7e97
	inc de			;7e99
	dec c			;7e9a
	jr nz,L_7E83		;7e9b
L_7E9D:
	pop hl			;7e9d
	ret			;7e9e
L_7E9F:
	ld a,(hl)			;7e9f
	and 0f0h		;7ea0
	jr nz,L_7EA8		;7ea2
	ld a,(hl)			;7ea4
	ld (de),a			;7ea5
	inc de			;7ea6
	inc c			;7ea7
L_7EA8:
	ld a,(0e127h)		;7ea8
	call suma_a_a_hl		;7eab
	djnz L_7E9F		;7eae
	ret			;7eb0
L_7EB1:
	ld a,(0e1cfh)		;7eb1
	rra			;7eb4
	ret nc			;7eb5
	ld a,(0e1d1h)		;7eb6
	rra			;7eb9
	ret nc			;7eba
	ld bc,00125h		;7ebb
	jp L_82E6		;7ebe
L_7EC1:
	ld b,00eh		;7ec1
	ld de,0e2f1h		;7ec3
L_7EC6:
	ld a,(de)			;7ec6
	cp 030h		;7ec7
	ret nc			;7ec9
	and 00fh		;7eca
	cp 001h		;7ecc
	ret z			;7ece
	cp 009h		;7ecf
	ret z			;7ed1
	inc de			;7ed2
	djnz L_7EC6		;7ed3
	ld bc,0011dh		;7ed5
	ld hl,0e1ddh		;7ed8
	ld (hl),001h		;7edb
	jp L_82E6		;7edd
L_7EE0:
	ld b,00eh		;7ee0
	ld de,0e2f1h		;7ee2
	ld a,(de)			;7ee5
	and 0f0h		;7ee6
	ld c,a			;7ee8
L_7EE9:
	ld a,(de)			;7ee9
	and 0f0h		;7eea
	cp c			;7eec
	ret nz			;7eed
	inc de			;7eee
	djnz L_7EE9		;7eef
	ld a,c			;7ef1
	cp 030h		;7ef2
	ld bc,00004h		;7ef4
	jr z,L_7F09		;7ef7
	ld a,(0e2b6h)		;7ef9
	or a			;7efc
	ld bc,00511h		;7efd
	jr nz,L_7F04		;7f00
	ld b,006h		;7f02
L_7F04:
	ld hl,0e1deh		;7f04
	ld (hl),001h		;7f07
L_7F09:
	jp L_82E6		;7f09
L_7F0C:
	ld a,(0e205h)		;7f0c
	rra			;7f0f
	ret c			;7f10
	ld a,(0e1deh)		;7f11
	rra			;7f14
	ret nc			;7f15
	ld de,0e2f1h		;7f16
	ld a,(de)			;7f19
	cp 00ah		;7f1a
	ret nc			;7f1c
	ld a,(0e2b6h)		;7f1d
	or a			;7f20
	ret nz			;7f21
	ld b,00eh		;7f22
	ld hl,0e127h		;7f24
L_7F27:
	push hl			;7f27
	ld a,(de)			;7f28
	call suma_a_a_hl		;7f29
	inc (hl)			;7f2c
	pop hl			;7f2d
	inc de			;7f2e
	djnz L_7F27		;7f2f
	ld hl,0e128h		;7f31
	ld a,(hl)			;7f34
	cp 003h		;7f35
	ret c			;7f37
	inc hl			;7f38
	ld bc,00700h		;7f39
L_7F3C:
	ld a,(hl)			;7f3c
	or c			;7f3d
	ret z			;7f3e
	inc hl			;7f3f
	djnz L_7F3C		;7f40
	ld a,(hl)			;7f42
	cp 003h		;7f43
	ret c			;7f45
	ld bc,00007h		;7f46
	jp L_82E6		;7f49
L_7F4C:
	ld a,(0e238h)		;7f4c
	rra			;7f4f
	ret c			;7f50
	xor a			;7f51
	ld (0e127h),a		;7f52
	ld a,(0e205h)		;7f55
	rra			;7f58
	jp c,L_7FF7		;7f59
	ld a,(0e300h)		;7f5c
	cp 030h		;7f5f
	jr c,L_7F69		;7f61
	ld hl,0e127h		;7f63
	inc (hl)			;7f66
	jr L_7F72		;7f67
L_7F69:
	and 00fh		;7f69
	cp 009h		;7f6b
	jr z,L_7F72		;7f6d
	cp 001h		;7f6f
	ret nz			;7f71
L_7F72:
	ld a,(0e2c8h)		;7f72
	or a			;7f75
	jr z,L_7F9F		;7f76
	add a,a			;7f78
	ld b,a			;7f79
	ld de,0e2b7h		;7f7a
L_7F7D:
	ld a,(de)			;7f7d
	cp 030h		;7f7e
	jr c,L_7F85		;7f80
	inc (hl)			;7f82
	jr L_7F94		;7f83
L_7F85:
	and 00fh		;7f85
	cp 009h		;7f87
	jr z,L_7F94		;7f89
	cp 001h		;7f8b
	jr z,L_7F94		;7f8d
	ld a,b			;7f8f
	rra			;7f90
	ret c			;7f91
	jr L_7F9B		;7f92
L_7F94:
	ld a,b			;7f94
	rra			;7f95
	jr c,L_7F9B		;7f96
	dec b			;7f98
	inc de			;7f99
	inc de			;7f9a
L_7F9B:
	inc de			;7f9b
	inc de			;7f9c
	djnz L_7F7D		;7f9d
L_7F9F:
	ld a,(0e2dah)		;7f9f
	or a			;7fa2
	jr z,L_7FAE		;7fa3
	ld b,a			;7fa5
	ld de,0e2c9h		;7fa6
	ld c,004h		;7fa9
	call L_7FDC		;7fab
L_7FAE:
	ld a,(0e2f0h)		;7fae
	or a			;7fb1
	jr z,L_7FBD		;7fb2
	ld b,a			;7fb4
	ld de,0e2dbh		;7fb5
	ld c,005h		;7fb8
	call L_7FDC		;7fba
L_7FBD:
	ld a,(hl)			;7fbd
	or a			;7fbe
	jr z,L_7FCE		;7fbf
	ld a,(0e2b6h)		;7fc1
	or a			;7fc4
	ld bc,00121h		;7fc5
	jr nz,L_7FCC		;7fc8
	ld b,002h		;7fca
L_7FCC:
	jr L_7FD9		;7fcc
L_7FCE:
	ld a,(0e2b6h)		;7fce
	or a			;7fd1
	ld bc,00217h		;7fd2
	jr nz,L_7FD9		;7fd5
	ld b,003h		;7fd7
L_7FD9:
	jp L_82E6		;7fd9
L_7FDC:
	ld a,(de)			;7fdc
	cp 030h		;7fdd
	jr c,L_7FE4		;7fdf
	inc (hl)			;7fe1
	jr L_7FF0		;7fe2
L_7FE4:
	and 00fh		;7fe4
	cp 009h		;7fe6
	jr z,L_7FF0		;7fe8
	cp 001h		;7fea
	jr z,L_7FF0		;7fec
	pop de			;7fee
	ret			;7fef
L_7FF0:
	ld a,c			;7ff0
	call suma_a_a_de		;7ff1
	djnz L_7FDC		;7ff4
	ret			;7ff6
L_7FF7:
	ld hl,0e127h		;7ff7
	ld de,0e2f1h		;7ffa
	ld b,007h		;7ffd
L_7FFF:
	ld a,(de)			;7fff
	cp 030h		;8000
	jr c,L_8007		;8002
	inc (hl)			;8004
	jr L_8010		;8005
L_8007:
	and 00fh		;8007
	cp 009h		;8009
	jr z,L_8010		;800b
	cp 001h		;800d
	ret nz			;800f
L_8010:
	inc de			;8010
	inc de			;8011
	djnz L_7FFF		;8012
	jr L_7FBD		;8014
L_8016:
	ld a,(0e1e0h)		;8016
	rra			;8019
	ret nc			;801a
	ld a,(0e2dah)		;801b
	or a			;801e
	jr z,L_802A		;801f
	ld b,a			;8021
	ld de,0e2c9h		;8022
	ld c,004h		;8025
	call L_803F		;8027
L_802A:
	ld a,(0e2f0h)		;802a
	or a			;802d
	jr z,L_8039		;802e
	ld b,a			;8030
	ld de,0e2dbh		;8031
	ld c,005h		;8034
	call L_803F		;8036
L_8039:
	ld bc,00005h		;8039
	jp L_82E6		;803c
L_803F:
	ld a,(de)			;803f
	cp 030h		;8040
	jr c,L_8051		;8042
	and 00fh		;8044
	cp 005h		;8046
	jr nc,L_8051		;8048
	ld a,c			;804a
	call suma_a_a_de		;804b
	djnz L_803F		;804e
	ret			;8050
L_8051:
	pop de			;8051
	ret			;8052
L_8053:
	ld a,(0e205h)		;8053
	rra			;8056
	ret c			;8057
	ld a,(0e04ch)		;8058
	add a,031h		;805b
	ld l,a			;805d
	ld a,(0e302h)		;805e
	bit 1,a		;8061
	ld a,(0e04dh)		;8063
	jr z,L_806B		;8066
	cpl			;8068
	and 001h		;8069
L_806B:
	add a,031h		;806b
	ld h,a			;806d
	ld c,000h		;806e
	ld a,(0e2dah)		;8070
	or a			;8073
	jr z,L_8082		;8074
	ld b,a			;8076
	ld de,0e2c9h		;8077
	ld a,004h		;807a
	ld (0e127h),a		;807c
	call L_80A1		;807f
L_8082:
	ld a,(0e2f0h)		;8082
	or a			;8085
	jr z,L_8094		;8086
	ld b,a			;8088
	ld de,0e2dbh		;8089
	ld a,005h		;808c
	ld (0e127h),a		;808e
	call L_80A1		;8091
L_8094:
	ld hl,0e1d6h		;8094
	ld a,c			;8097
	or a			;8098
	ret z			;8099
	ld (hl),c			;809a
	ld b,c			;809b
	ld c,022h		;809c
	jp L_82E6		;809e
L_80A1:
	ld a,(de)			;80a1
	cp h			;80a2
	jr nz,L_80A6		;80a3
	inc c			;80a5
L_80A6:
	cp l			;80a6
	jr nz,L_80AA		;80a7
	inc c			;80a9
L_80AA:
	cp 035h		;80aa
	jr c,L_80B3		;80ac
	cp 038h		;80ae
	jr nc,L_80B3		;80b0
	inc c			;80b2
L_80B3:
	ld a,(0e127h)		;80b3
	call suma_a_a_de		;80b6
	djnz L_80A1		;80b9
	ret			;80bb
L_80BC:
	ld a,(0e1deh)		;80bc
	rra			;80bf
	ret c			;80c0
	ld b,00eh		;80c1
	ld de,0e2f1h		;80c3
L_80C6:
	ld a,(de)			;80c6
	and 0f0h		;80c7
	cp 030h		;80c9
	jr nz,L_80D0		;80cb
	inc de			;80cd
	djnz L_80C6		;80ce
L_80D0:
	ld b,00eh		;80d0
	ld c,a			;80d2
L_80D3:
	ld a,(de)			;80d3
	and 0f0h		;80d4
	cp c			;80d6
	jr z,L_80DC		;80d7
	cp 030h		;80d9
	ret nz			;80db
L_80DC:
	inc de			;80dc
	djnz L_80D3		;80dd
	ld a,(0e2b6h)		;80df
	or a			;80e2
	ld bc,00215h		;80e3
	jr nz,L_80EA		;80e6
	ld b,003h		;80e8
L_80EA:
	ld hl,0e1dch		;80ea
	ld (hl),001h		;80ed
	jp L_82E6		;80ef
L_80F2:
	ld a,(0e2c8h)		;80f2
	or a			;80f5
	ret nz			;80f6
	ld b,00eh		;80f7
	ld de,0e2f1h		;80f9
L_80FC:
	ld a,(de)			;80fc
	cp 030h		;80fd
	jr nc,L_810A		;80ff
	and 00fh		;8101
	cp 001h		;8103
	jr z,L_810A		;8105
	cp 009h		;8107
	ret nz			;8109
L_810A:
	inc de			;810a
	djnz L_80FC		;810b
	ld hl,0e238h		;810d
	ld (hl),001h		;8110
	ld bc,0021bh		;8112
	jp L_82E6		;8115
L_8118:
	ld b,00eh		;8118
	ld de,0e2f1h		;811a
L_811D:
	ld a,(de)			;811d
	cp 036h		;811e
	jr z,L_8135		;8120
	cp 022h		;8122
	jr z,L_8135		;8124
	cp 023h		;8126
	jr z,L_8135		;8128
	cp 024h		;812a
	jr z,L_8135		;812c
	cp 026h		;812e
	jr z,L_8135		;8130
	cp 028h		;8132
	ret nz			;8134
L_8135:
	inc de			;8135
	djnz L_811D		;8136
	ld bc,00009h		;8138
	jp L_82E6		;813b
L_813E:
	ld hl,0e127h		;813e
	ld (hl),000h		;8141
	ld a,(0e2dah)		;8143
	or a			;8146
	jr z,L_8152		;8147
	ld b,a			;8149
	ld de,0e2c9h		;814a
	ld c,004h		;814d
	call L_817B		;814f
L_8152:
	ld a,(0e2f0h)		;8152
	or a			;8155
	jr z,L_8161		;8156
	ld b,a			;8158
	ld de,0e2dbh		;8159
	ld c,005h		;815c
	call L_817B		;815e
L_8161:
	ld a,(hl)			;8161
	cp 002h		;8162
	ret c			;8164
	jr z,L_816C		;8165
	ld bc,00006h		;8167
	jr L_8178		;816a
L_816C:
	ld a,(0e300h)		;816c
	cp 035h		;816f
	ret c			;8171
	cp 038h		;8172
	ret nc			;8174
	ld bc,0021ah		;8175
L_8178:
	jp L_82E6		;8178
L_817B:
	ld a,(de)			;817b
	cp 035h		;817c
	jr c,L_8185		;817e
	cp 038h		;8180
	jr nc,L_8185		;8182
	inc (hl)			;8184
L_8185:
	ld a,c			;8185
	call suma_a_a_de		;8186
	djnz L_817B		;8189
	ret			;818b
L_818C:
	ld a,(0e2c8h)		;818c
	or a			;818f
	ret nz			;8190
	ld b,00eh		;8191
	ld de,0e2f1h		;8193
L_8196:
	ld a,(de)			;8196
	and 00fh		;8197
	cp 001h		;8199
	jr z,L_81A0		;819b
	cp 009h		;819d
	ret nz			;819f
L_81A0:
	inc de			;81a0
	djnz L_8196		;81a1
	ld bc,00008h		;81a3
L_81A6:
	jp L_82E6		;81a6
L_81A9:
	ld hl,0e127h		;81a9
	ld (hl),000h		;81ac
	ld a,(0e205h)		;81ae
	rra			;81b1
	jr c,L_81DD		;81b2
	ld a,(0e302h)		;81b4
	bit 1,a		;81b7
	ld de,0e1cdh		;81b9
	jr z,L_81C1		;81bc
	ld de,0e1aeh		;81be
L_81C1:
	ld a,(de)			;81c1
	rra			;81c2
	ld a,(0e1d4h)		;81c3
	ld c,a			;81c6
	call c,L_8210		;81c7
	ld a,(0e1d3h)		;81ca
	ld c,a			;81cd
	call L_8210		;81ce
L_81D1:
	ld a,(hl)			;81d1
	or a			;81d2
	ret z			;81d3
	ld hl,0e1d7h		;81d4
	ld (hl),a			;81d7
	ld b,a			;81d8
	ld c,026h		;81d9
	jr L_81A6		;81db
L_81DD:
	ld a,(0e302h)		;81dd
	bit 1,a		;81e0
	ld de,0e1cdh		;81e2
	jr z,L_81EA		;81e5
	ld de,0e1aeh		;81e7
L_81EA:
	ld a,(0e1d4h)		;81ea
	ld c,a			;81ed
	call L_8270		;81ee
	ld a,(de)			;81f1
	rra			;81f2
	call c,L_8202		;81f3
	ld a,(0e1d3h)		;81f6
	ld c,a			;81f9
	call L_8270		;81fa
	call L_8202		;81fd
	jr L_81D1		;8200
L_8202:
	ld de,0e2f1h		;8202
	ld b,00eh		;8205
L_8207:
	ld a,(de)			;8207
	cp c			;8208
	jr nz,L_820C		;8209
	inc (hl)			;820b
L_820C:
	inc de			;820c
	djnz L_8207		;820d
	ret			;820f
L_8210:
	call L_8270		;8210
	ld a,(0e2c8h)		;8213
	or a			;8216
	jr z,L_822C		;8217
	ld b,a			;8219
	ld de,0e2b7h		;821a
L_821D:
	call L_826B		;821d
	inc de			;8220
	call L_826B		;8221
	inc de			;8224
	call L_826B		;8225
	inc de			;8228
	inc de			;8229
	djnz L_821D		;822a
L_822C:
	ld a,(0e2dah)		;822c
	or a			;822f
	jr z,L_823E		;8230
	ld b,a			;8232
	ld de,0e2c9h		;8233
	ld a,004h		;8236
	ld (0e128h),a		;8238
	call L_8258		;823b
L_823E:
	ld a,(0e2f0h)		;823e
	or a			;8241
	jr z,L_8250		;8242
	ld b,a			;8244
	ld de,0e2dbh		;8245
	ld a,005h		;8248
	ld (0e128h),a		;824a
	call L_8258		;824d
L_8250:
	ld a,(0e300h)		;8250
	cp c			;8253
	ret nz			;8254
	inc (hl)			;8255
	inc (hl)			;8256
	ret			;8257
L_8258:
	ld a,(de)			;8258
	cp c			;8259
	jr nz,L_8262		;825a
	ld a,(0e128h)		;825c
	dec a			;825f
	add a,(hl)			;8260
	ld (hl),a			;8261
L_8262:
	ld a,(0e128h)		;8262
	call suma_a_a_de		;8265
	djnz L_8258		;8268
	ret			;826a
L_826B:
	ld a,(de)			;826b
	cp c			;826c
	ret nz			;826d
	inc (hl)			;826e
	ret			;826f
L_8270:
	cp 030h		;8270
	jr c,L_8284		;8272
	cp 034h		;8274
	jr nz,L_827C		;8276
	ld a,030h		;8278
	jr L_828D		;827a
L_827C:
	cp 037h		;827c
	jr nz,L_828D		;827e
	ld a,034h		;8280
	jr L_828D		;8282
L_8284:
	and 00fh		;8284
	cp 009h		;8286
	ld a,c			;8288
	jr nz,L_828D		;8289
	and 0f0h		;828b
L_828D:
	inc a			;828d
	ld c,a			;828e
	ret			;828f
L_8290:
	ld a,(0e1d0h)		;8290
	or a			;8293
	ret nz			;8294
	ld a,(0e2b6h)		;8295
	or a			;8298
	ret nz			;8299
	ld a,(0e1d1h)		;829a
	rra			;829d
	ret nc			;829e
	ld bc,00110h		;829f
	jr L_82E6		;82a2
L_82A4:
	ld a,(0e1d1h)		;82a4
	rra			;82a7
	ld a,(0e04dh)		;82a8
	ld c,a			;82ab
	jr nc,L_82BC		;82ac
	rra			;82ae
	ld a,(0e1bfh)		;82af
	jr nc,L_82B7		;82b2
	ld a,(0e1beh)		;82b4
L_82B7:
	cp 0ffh		;82b7
	ret nz			;82b9
	jr L_82D7		;82ba
L_82BC:
	rra			;82bc
	jr nc,L_82CA		;82bd
	ld a,(0e302h)		;82bf
	bit 1,a		;82c2
	ret nz			;82c4
	ld a,(0e1bfh)		;82c5
	jr L_82D3		;82c8
L_82CA:
	ld a,(0e302h)		;82ca
	bit 1,a		;82cd
	ret z			;82cf
	ld a,(0e1beh)		;82d0
L_82D3:
	or a			;82d3
	ret nz			;82d4
	jr L_82E3		;82d5
L_82D7:
	ld a,(0e302h)		;82d7
	rra			;82da
	and 001h		;82db
	xor c			;82dd
	ld bc,00001h		;82de
	jr z,L_82E6		;82e1
L_82E3:
	ld bc,00002h		;82e3
L_82E6:
	ld hl,0e315h		;82e6
	inc (hl)			;82e9
	ld a,(hl)			;82ea
	ld hl,0e304h		;82eb
	call suma_a_a_hl		;82ee
	ld (hl),c			;82f1
	ld hl,0e316h		;82f2
	ld a,(hl)			;82f5
	add a,b			;82f6
	ld (hl),a			;82f7
	ret			;82f8
L_82F9:
	ld hl,0e127h		;82f9
	ld (hl),000h		;82fc
	ld de,0e128h		;82fe
	ld bc,00012h		;8301
	ldir		;8304
	ret			;8306

; ----------------------------------------------------------------------
; Suma DE al marcador de 0xE047 teniendo en cuenta el signo de 0xE100. Si el marcador esta en negativo, sumar es restar del valor absoluto, y si al restar se llega a cero se le da la vuelta al signo.
; ----------------------------------------------------------------------
suma_al_marcador_de_e047:
	ld hl,0e100h		;8307
	ld a,(hl)			;830a
	rra			;830b   ; bit 0 del signo
	jr nc,L_8310		;830c
	res 1,(hl)		;830e   ; con el bit 0 puesto, el 1 sobra
L_8310:
	rra			;8310   ; bit 1: el marcador esta en numeros rojos
	jr c,L_8325		;8311   ; en rojos, sumar es restar del valor absoluto
	res 0,(hl)		;8313
	ld hl,0e047h		;8315   ; marcador del jugador de 0xE047: suma
	call suma_bcd_de_3_bytes		;8318
	jr L_832D		;831b

; ----------------------------------------------------------------------
; Resta DE del marcador de 0xE047. Si ya estaba en negativo (algun bit de los dos bajos puesto) lo que hace es SUMAR al valor absoluto, que es lo mismo que restar de un numero rojo.
; ----------------------------------------------------------------------
resta_del_marcador_de_e047:
	ld hl,0e100h		;831d
	ld a,(hl)			;8320
	and 003h		;8321   ; los dos bits del signo de este marcador
	jr nz,L_833B		;8323   ; ya esta en rojos: se le suma al valor absoluto
L_8325:
	res 0,(hl)		;8325
	ld hl,0e047h		;8327   ; marcador del jugador de 0xE047: resta
	call resta_bcd_de_3_bytes		;832a
L_832D:
	or e			;832d   ; el resultado, byte a byte: hay que saber si ha quedado en cero
	or d			;832e
	ld hl,0e100h		;832f
	jr nz,L_8339		;8332
	res 1,(hl)		;8334   ; justo en cero: se sale de los numeros rojos
	nop			;8336
	set 0,(hl)		;8337
L_8339:
	jr L_8346		;8339
L_833B:
	res 0,(hl)		;833b
	nop			;833d
	set 1,(hl)		;833e
	ld hl,0e047h		;8340   ; marcador del jugador de 0xE047: suma
	call suma_bcd_de_3_bytes		;8343
L_8346:
	jp pinta_los_dos_marcadores		;8346   ; y a repintar los dos marcadores

; ----------------------------------------------------------------------
; La misma de 0x8307 para el otro marcador, con los bits 7 y 6 de 0xE100 en vez de los bits 0 y 1, y `rla` en vez de `rra` para mirarlos.
; ----------------------------------------------------------------------
suma_al_marcador_de_e044:
	ld hl,0e100h		;8349
	ld a,(hl)			;834c
	rla			;834d   ; bit 7 del signo
	jr nc,L_8352		;834e
	res 6,(hl)		;8350
L_8352:
	rla			;8352   ; bit 6: este marcador esta en numeros rojos
	jr c,L_8367		;8353
	res 7,(hl)		;8355
	ld hl,0e044h		;8357   ; marcador del jugador de 0xE044: suma
	call suma_bcd_de_3_bytes		;835a
	jr L_836F		;835d

; ----------------------------------------------------------------------
; La misma de 0x831D para el marcador de 0xE044, con los bits 7 y 6.
; ----------------------------------------------------------------------
resta_del_marcador_de_e044:
	ld hl,0e100h		;835f
	ld a,(hl)			;8362
	and 0c0h		;8363   ; los dos bits altos, el signo de este marcador
	jr nz,L_837D		;8365
L_8367:
	res 7,(hl)		;8367
	ld hl,0e044h		;8369   ; marcador del jugador de 0xE044: resta
	call resta_bcd_de_3_bytes		;836c
L_836F:
	or e			;836f
	or d			;8370
	ld hl,0e100h		;8371
	jr nz,L_837B		;8374
	set 7,(hl)		;8376   ; justo en cero: se sale de los numeros rojos
	nop			;8378
	res 6,(hl)		;8379
L_837B:
	jr L_8388		;837b
L_837D:
	res 7,(hl)		;837d
	nop			;837f
	set 6,(hl)		;8380
	ld hl,0e044h		;8382   ; marcador del jugador de 0xE044: suma
	call suma_bcd_de_3_bytes		;8385
L_8388:
	jp pinta_los_dos_marcadores		;8388

; ----------------------------------------------------------------------
; Suma DE en BCD sobre el contador de tres bytes al que apunta HL, byte bajo primero. El `daa` detras de cada suma es lo que lo hace decimal; el tercer byte solo se toca si hubo arrastre (`ret nc`). La usan los dos marcadores, 0xE044 y 0xE047.
; ----------------------------------------------------------------------
suma_bcd_de_3_bytes:
	ld a,(hl)			;838b
	add a,e			;838c
	daa			;838d   ; daa: la suma es DECIMAL, no binaria
	ld (hl),a			;838e
	ld e,a			;838f
	inc l			;8390
	ld a,(hl)			;8391
	adc a,d			;8392
	daa			;8393
	ld (hl),a			;8394
	ld d,a			;8395
	inc hl			;8396
	ld a,(hl)			;8397
	ret nc			;8398   ; si no hubo arrastre, el byte alto se queda como esta
	add a,001h		;8399
	daa			;839b
	ld (hl),a			;839c
	ret			;839d

; ----------------------------------------------------------------------
; La hermana de suma_bcd_de_3_bytes: resta DE en BCD sobre el contador de tres bytes al que apunta HL. Mismo recorrido de byte bajo a alto y mismo `ret nc` para no tocar el tercero sin necesidad.
; ----------------------------------------------------------------------
resta_bcd_de_3_bytes:
	ld a,(hl)			;839e
	sub e			;839f
	daa			;83a0   ; daa: la resta tambien es DECIMAL
	ld (hl),a			;83a1
	ld e,a			;83a2
	inc hl			;83a3
	ld a,(hl)			;83a4
	sbc a,d			;83a5
	daa			;83a6
	ld (hl),a			;83a7
	ld d,a			;83a8
	inc hl			;83a9
	ld a,(hl)			;83aa
	ret nc			;83ab
	sub 001h		;83ac
	daa			;83ae
	ld (hl),a			;83af
	ret			;83b0

; ----------------------------------------------------------------------
; DATOS fuente_grande: Los 48 patrones de 8x8 de los tiles 0xC0-0xEF:
;   0xC0-0xC9 son los diez digitos, 0xCA es el circulo del copyright, 0xD0 es
;   el guion, 0xD1-0xEA son la A a la Z y el resto son trazos japoneses.
;   0x4472 la copia entera a los patrones 0x0600 y 0x448C a los colores
;   0x2600.
;   0x83b1..0x8531  (384 bytes)
DATA_fuente_grande:
	defb 000h,01ch,022h,063h,063h,063h,022h,01ch	; 83b1  .."ccc".
	defb 000h,018h,038h,018h,018h,018h,018h,07eh	; 83b9  ..8....~
	defb 000h,03eh,063h,003h,00eh,03ch,070h,07fh	; 83c1  .>c..<p.
	defb 000h,03eh,063h,003h,00eh,003h,063h,03eh	; 83c9  .>c...c>
	defb 000h,00eh,01eh,036h,066h,066h,07fh,006h	; 83d1  ...6ff..
	defb 000h,07fh,060h,07eh,063h,003h,063h,03eh	; 83d9  ..`~c.c>
	defb 000h,03eh,063h,060h,07eh,063h,063h,03eh	; 83e1  .>c`~cc>
	defb 000h,07fh,063h,006h,00ch,018h,018h,018h	; 83e9  ..c.....
	defb 000h,03eh,063h,063h,03eh,063h,063h,03eh	; 83f1  .>cc>cc>
	defb 000h,03eh,063h,063h,03fh,003h,063h,03eh	; 83f9  .>cc?.c>
	defb 03ch,042h,099h,0a1h,0a1h,099h,042h,03ch	; 8401  <B....B<
	defb 000h,003h,003h,003h,003h,003h,003h,003h	; 8409  ........
	defb 01ch,038h,070h,0e1h,0cdh,0cdh,0fdh,079h	; 8411  .8p....y
	defb 000h,000h,000h,0eeh,06bh,06bh,06bh,0ebh	; 8419  ....kkk.
	defb 000h,000h,000h,073h,01ah,07ah,05ah,07ah	; 8421  ...s.zZz
	defb 000h,003h,000h,0f3h,05bh,05bh,05bh,05bh	; 8429  ....[[[[
	defb 000h,000h,000h,000h,07eh,000h,000h,000h	; 8431  ....~...
	defb 000h,01ch,036h,063h,063h,07fh,063h,063h	; 8439  ..6cc.cc
	defb 000h,07eh,063h,063h,07eh,063h,063h,07eh	; 8441  .~cc~cc~
	defb 000h,03eh,063h,060h,060h,060h,063h,03eh	; 8449  .>c```c>
	defb 000h,07ch,066h,063h,063h,063h,066h,07ch	; 8451  .|fcccf|
	defb 000h,07fh,060h,060h,07eh,060h,060h,07fh	; 8459  ..``~``.
	defb 000h,07fh,060h,060h,07eh,060h,060h,060h	; 8461  ..``~```
	defb 000h,03eh,063h,060h,067h,063h,063h,03fh	; 8469  .>c`gcc?
	defb 000h,063h,063h,063h,07fh,063h,063h,063h	; 8471  .ccc.ccc
	defb 000h,03ch,018h,018h,018h,018h,018h,03ch	; 8479  .<.....<
	defb 000h,01fh,006h,006h,006h,006h,066h,03ch	; 8481  ......f<
	defb 000h,063h,066h,06ch,078h,07ch,06eh,067h	; 8489  .cflx|ng
	defb 000h,060h,060h,060h,060h,060h,060h,07fh	; 8491  .``````.
	defb 000h,063h,077h,07fh,07fh,06bh,063h,063h	; 8499  .cw..kcc
	defb 000h,063h,073h,07bh,07fh,06fh,067h,063h	; 84a1  .cs{.ogc
	defb 000h,03eh,063h,063h,063h,063h,063h,03eh	; 84a9  .>ccccc>
	defb 000h,07eh,063h,063h,063h,07eh,060h,060h	; 84b1  .~ccc~``
	defb 000h,03eh,063h,063h,063h,06fh,066h,03dh	; 84b9  .>cccof=
	defb 000h,07eh,063h,063h,062h,07ch,066h,063h	; 84c1  .~ccb|fc
	defb 000h,03eh,063h,060h,03eh,003h,063h,03eh	; 84c9  .>c`>.c>
	defb 000h,07eh,018h,018h,018h,018h,018h,018h	; 84d1  .~......
	defb 000h,063h,063h,063h,063h,063h,063h,03eh	; 84d9  .cccccc>
	defb 000h,063h,063h,063h,063h,036h,01ch,008h	; 84e1  .cccc6..
	defb 000h,063h,063h,06bh,06bh,07fh,077h,022h	; 84e9  .cckk.w"
	defb 000h,063h,076h,03ch,01ch,01eh,037h,063h	; 84f1  .cv<..7c
	defb 000h,066h,066h,07eh,03ch,018h,018h,018h	; 84f9  .ff~<...
	defb 000h,07fh,007h,00eh,01ch,038h,070h,07fh	; 8501  .....8p.
	defb 000h,024h,024h,024h,000h,000h,000h,000h	; 8509  .$$$....
	defb 000h,000h,040h,049h,05ah,073h,052h,059h	; 8511  ..@IZsRY
	defb 000h,000h,000h,092h,052h,0ceh,002h,0dch	; 8519  ....R...
	defb 000h,000h,002h,000h,08ah,0aah,0aah,0dah	; 8521  ........
	defb 000h,000h,008h,048h,0eeh,04ah,04ah,06ah	; 8529  ...H.JJj

; ----------------------------------------------------------------------
; DATOS rotulos_del_menu: Formato A desde 0x45DE. Seis destinos: KEYBOARD ONLY
;   (fila 13), PLAY SELECT (fila 16) y las tres dificultades numeradas -1
;   AMACHUA, 2 SEMIPROFESSIONAL, 3 PROFESSIONAL- en las filas 18, 20 y 22, mas
;   el logotipo con el ano 1984 en la fila 8. El juego escribe el japones en
;   ROMAJI con la fuente latina: AMACHUA es la transcripcion de amateur.
;   0x8531..0x8598  (103 bytes)
DATA_rotulos_del_menu:
	defb 0a9h,039h,02bh,025h,039h,022h,02fh,021h,032h,024h,000h,02fh,02eh,02ch,039h,0feh	; 8531  .9+%9"/!2$./.,9.
	defb 00ah,03ah,030h,02ch,021h,039h,000h,033h,025h,02ch,025h,023h,034h,0feh,046h,03ah	; 8541  .:0,!9.3%,%#4.F:
	defb 0c1h,0d0h,0ech,0edh,000h,0d1h,0ddh,0d1h,0d3h,0d8h,0e5h,0d1h,0feh,086h,03ah,0c2h	; 8551  ..............:.
	defb 0d0h,0ech,0edh,000h,0e3h,0d5h,0ddh,0d9h,0e0h,0e2h,0dfh,0d6h,0d5h,0e3h,0e3h,0d9h	; 8561  ................
	defb 0dfh,0deh,0d1h,0dch,0feh,0c6h,03ah,0c3h,0d0h,0ech,0edh,000h,0e0h,0e2h,0dfh,0d6h	; 8571  ......:.........
	defb 0d5h,0e3h,0e3h,0d9h,0dfh,0deh,0d1h,0dch,0feh,00ah,039h,01ah,01bh,01ch,01dh,01eh	; 8581  ..........9.....
	defb 01fh,000h,011h,019h,018h,014h,0ffh	; 8591

; ----------------------------------------------------------------------
; DATOS logotipo_de_tres_filas: Formato A desde 0x43E3: tres filas de diez
;   tiles en las filas 10, 11 y 12, columna 11.
;   0x8598..0x85bf  (39 bytes)
DATA_logotipo_de_tres_filas:
	defb 04bh,039h,001h,010h,011h,012h,001h,001h,019h,01ah,01bh,001h,0feh,06bh,039h,001h	; 8598  K9...........k9.
	defb 013h,014h,015h,001h,001h,01ch,01dh,01eh,001h,0feh,08bh,039h,001h,016h,017h,018h	; 85a8  ...........9....
	defb 001h,001h,01fh,020h,021h,001h,0ffh	; 85b8

; ----------------------------------------------------------------------
; DATOS rotulo_video_cartridge: Formato A desde 0x4124 y 0x4134: VIDEO
;   CARTRIDGE entre dos tiles de adorno, en la fila 11 columna 6. Se pinta por
;   0x409D y se BORRA por 0x4099, con la misma lista.
;   0x85bf..0x85d5  (22 bytes)
DATA_rotulo_video_cartridge:
	defb 066h,039h,020h,000h,036h,029h,024h,025h,02fh,000h,023h,021h,032h,034h,032h,029h	; 85bf  f9 .6)$%/.#!242)
	defb 024h,027h,025h,000h,020h,0ffh	; 85cf

; ----------------------------------------------------------------------
; DATOS colores_del_titulo_500: Formato B desde 0x448F: 432 bytes a los
;   colores 0x2500.
;   0x85d5..0x86d6  (257 bytes)
DATA_colores_del_titulo_500:
	defb 000h,065h,004h,000h,091h,004h,007h,003h,004h,006h,006h,007h,00dh,00ch,00ch,018h	; 85d5  .e..............
	defb 019h,031h,023h,062h,045h,080h,004h,000h,096h,018h,01ch,01bh,0ffh,0fch,083h,0e1h	; 85e5  .1#bE...........
	defb 063h,07fh,0f7h,0e1h,0e3h,0e3h,0f3h,0ffh,065h,065h,069h,0f1h,0e9h,027h,003h,003h	; 85f5  c.......eei..'..
	defb 000h,088h,040h,0e0h,0e0h,000h,000h,080h,0e0h,0f0h,004h,080h,086h,0c0h,0e0h,0b8h	; 8605  ..@.............
	defb 09ch,08fh,087h,003h,080h,035h,000h,083h,002h,006h,006h,004h,000h,087h,001h,003h	; 8615  .....5..........
	defb 007h,00eh,01ch,018h,020h,007h,000h,096h,020h,031h,031h,033h,036h,03ch,038h,070h	; 8625  .... ... 1136<8p
	defb 07ch,0efh,0cfh,0feh,047h,07fh,0deh,0c7h,0ffh,0deh,0e7h,0ffh,0e0h,040h,003h,000h	; 8635  |...G........@..
	defb 082h,0e0h,0f0h,006h,000h,08bh,0c0h,080h,000h,080h,000h,000h,0c0h,080h,000h,0e0h	; 8645  ................
	defb 0f0h,037h,000h,083h,030h,01dh,01ch,003h,000h,0a4h,038h,0fch,05ch,018h,010h,018h	; 8655  .7..0.....8.\...
	defb 00ch,018h,098h,0f3h,07fh,038h,000h,000h,003h,087h,0c3h,066h,00fh,03ch,0f0h,03fh	; 8665  .....8.....f.<.?
	defb 061h,0ddh,0f5h,041h,05dh,075h,041h,04fh,0ffh,043h,000h,000h,0ffh,01fh,005h,000h	; 8675  a..A]uAO.C......
	defb 085h,080h,0c0h,0c0h,000h,000h,009h,080h,085h,000h,000h,0fch,0f0h,0c0h,035h,000h	; 8685  ..............5.
	defb 081h,008h,004h,006h,083h,04fh,03fh,01eh,003h,006h,084h,007h,01eh,07ch,030h,008h	; 8695  .....O?......|0.
	defb 000h,094h,013h,01eh,019h,01fh,01ch,019h,09fh,008h,000h,00fh,0f8h,04ch,09fh,034h	; 86a5  .............L.4
	defb 066h,084h,00dh,019h,022h,004h,003h,000h,097h,0c0h,0e0h,070h,060h,0e0h,060h,0e0h	; 86b5  f..."......p`.`.
	defb 0e0h,040h,07ch,0feh,000h,0f8h,08ch,0ceh,0cch,08ch,098h,01ch,0b0h,0f0h,060h,000h	; 86c5  .@|...........`.
	defb 000h	; 86d5

; ----------------------------------------------------------------------
; DATOS colores_del_titulo_080: Formato B desde 0x43AA: 264 bytes a los
;   colores 0x2080.
;   0x86d6..0x8799  (195 bytes)
DATA_colores_del_titulo_080:
	defb 080h,060h,0bdh,004h,007h,003h,007h,006h,00ch,099h,0e3h,000h,006h,007h,00ch,00ch	; 86d6  .`..............
	defb 018h,018h,035h,000h,0e0h,0e0h,060h,060h,0c0h,0c0h,080h,036h,01ch,018h,031h,0e7h	; 86e6  ..5...``...6..1.
	defb 0fch,061h,00ch,007h,0c3h,043h,0e6h,066h,02ch,09bh,0a1h,080h,000h,080h,0e0h,070h	; 86f6  .a...C.f,......p
	defb 038h,0bch,0deh,066h,033h,03bh,01ah,030h,020h,000h,000h,0c0h,061h,067h,003h,001h	; 8706  8..f3;.0 ...ag..
	defb 003h,000h,085h,0cfh,080h,000h,080h,0c0h,003h,000h,002h,000h,081h,001h,005h,000h	; 8716  ................
	defb 088h,000h,000h,0cfh,0fch,060h,060h,061h,07fh,083h,010h,0f8h,0fch,003h,018h,082h	; 8726  .....``a........
	defb 0f8h,010h,008h,000h,088h,07ch,060h,067h,07ch,060h,0cbh,0cch,0cch,088h,00ch,07eh	; 8736  .....|`g|`.....~
	defb 0c7h,003h,0c3h,0e3h,063h,063h,084h,001h,001h,003h,006h,004h,000h,083h,08ch,087h	; 8746  ....cc..........
	defb 007h,005h,000h,086h,0c3h,0e3h,047h,00eh,03ch,008h,005h,000h,081h,00fh,004h,01fh	; 8756  ......G.<.......
	defb 003h,000h,081h,0f0h,004h,0f8h,004h,01fh,081h,00fh,003h,000h,004h,0f8h,081h,0f0h	; 8766  ................
	defb 006h,000h,00ah,0ffh,003h,000h,081h,07fh,007h,0bfh,081h,0fch,007h,0feh,008h,0bfh	; 8776  ................
	defb 008h,0feh,006h,0bfh,082h,07fh,000h,006h,0feh,082h,0fch,000h,008h,01fh,008h,0f8h	; 8786  ................
	defb 008h,0ffh,000h	; 8796

; ----------------------------------------------------------------------
; DATOS patrones_del_titulo_080: Formato B desde 0x43B0: los 264 bytes de
;   patrones que hacen pareja con el bloque de arriba, a 0x0080.
;   0x8799..0x87b4  (27 bytes)
DATA_patrones_del_titulo_080:
	defb 080h,040h,048h,0b1h,048h,0b1h,030h,0c0h,081h,096h,007h,09fh,008h,096h,008h,09fh	; 8799  .@H.H.0.........
	defb 008h,096h,006h,09fh,00ah,096h,010h,0c0h,008h,030h,000h	; 87a9  .........0.

; ----------------------------------------------------------------------
; DATOS nombres_del_titulo: Formato B desde 0x43B9: catorce destinos, las
;   filas 5 a 18 de la columna 6.
;   0x87b4..0x8832  (126 bytes)
DATA_nombres_del_titulo:
	defb 0a6h,078h,081h,022h,012h,026h,081h,023h,080h,0c6h,078h,081h,02eh,012h,030h,081h	; 87b4  .x.".&.#..x...0.
	defb 02fh,080h,0e6h,078h,081h,02eh,012h,030h,081h,02fh,080h,006h,079h,081h,02eh,012h	; 87c4  /..x...0./..y...
	defb 030h,081h,02fh,080h,026h,079h,081h,02eh,012h,030h,081h,02fh,080h,046h,079h,081h	; 87d4  0./.&y...0./.Fy.
	defb 02eh,012h,030h,081h,02fh,080h,066h,079h,081h,02eh,012h,030h,081h,02fh,080h,086h	; 87e4  ..0./.fy...0./..
	defb 079h,081h,02eh,012h,030h,081h,02fh,080h,0a6h,079h,081h,02eh,012h,030h,081h,02fh	; 87f4  y...0./..y...0./
	defb 080h,0c6h,079h,081h,02eh,012h,030h,081h,02fh,080h,0e6h,079h,081h,02eh,012h,030h	; 8804  ..y...0./..y...0
	defb 081h,02fh,080h,006h,07ah,081h,02eh,012h,030h,081h,02fh,080h,026h,07ah,081h,02eh	; 8814  ./..z...0./.&z..
	defb 012h,030h,081h,02fh,080h,046h,07ah,081h,024h,012h,027h,081h,025h,000h	; 8824  .0./.Fz.$.'.%.

; ----------------------------------------------------------------------
; DATOS colores_del_titulo_180: Formato B desde 0x708E: 640 bytes a los
;   colores 0x2180.
;   0x8832..0x8a78  (582 bytes)
DATA_colores_del_titulo_180:
	defb 080h,061h,09ah,07eh,002h,00ah,00ch,008h,008h,010h,000h,002h,004h,018h,028h,048h	; 8832  .a.~..........(H
	defb 008h,008h,000h,018h,07eh,042h,042h,002h,004h,018h,000h,000h,07ch,004h,010h,08ch	; 8842  ....~BB.....|...
	defb 03eh,000h,008h,07eh,008h,018h,028h,048h,008h,000h,020h,07eh,004h,022h,086h,044h	; 8852  >..~..(H.. ~.".D
	defb 000h,008h,03eh,008h,03eh,003h,008h,093h,000h,03eh,022h,042h,002h,004h,008h,030h	; 8862  ..>.>....>"B...0
	defb 000h,020h,03eh,024h,044h,004h,004h,018h,000h,000h,07eh,004h,002h,0bbh,07eh,000h	; 8872  . >$D.....~...~.
	defb 024h,07eh,024h,024h,004h,004h,008h,000h,000h,060h,002h,062h,002h,004h,078h,000h	; 8882  $~$$.....`.b..x.
	defb 07eh,002h,004h,008h,018h,024h,042h,000h,020h,07eh,022h,024h,020h,020h,01eh,000h	; 8892  ~....$B. ~"$  ..
	defb 042h,042h,022h,002h,002h,004h,018h,000h,03eh,022h,052h,00ah,004h,008h,030h,000h	; 88a2  BB".....>"R...0.
	defb 004h,038h,008h,07eh,008h,008h,010h,000h,000h,003h,052h,087h,002h,004h,018h,000h	; 88b2  .8.~......R.....
	defb 03ch,000h,07eh,003h,008h,082h,010h,000h,003h,020h,08fh,038h,024h,020h,020h,000h	; 88c2  <.~...... .8$  .
	defb 008h,008h,07eh,008h,008h,010h,020h,000h,000h,03ch,004h,000h,092h,07eh,000h,07eh	; 88d2  ..~... ..<...~.~
	defb 002h,014h,008h,014h,020h,040h,000h,008h,07eh,00ch,018h,02ch,04ah,008h,000h,005h	; 88e2  .... @..~..,J...
	defb 004h,086h,008h,010h,000h,000h,008h,004h,004h,042h,084h,000h,040h,040h,07eh,003h	; 88f2  .........B..@@~.
	defb 040h,083h,03eh,000h,07eh,004h,002h,0b6h,004h,018h,000h,020h,050h,008h,004h,002h	; 8902  @.>.~...... P...
	defb 002h,000h,000h,008h,03eh,008h,008h,02ah,02ah,008h,000h,000h,07eh,002h,002h,014h	; 8912  ....>..**...~...
	defb 008h,004h,000h,000h,03ch,000h,03ch,000h,03ch,002h,000h,000h,010h,020h,042h,042h	; 8922  ....<.<.<.... BB
	defb 07eh,002h,000h,002h,002h,014h,008h,014h,022h,040h,000h,07eh,010h,07eh,003h,010h	; 8932  ~......."@.~.~..
	defb 08ch,00eh,000h,010h,010h,07eh,012h,014h,010h,010h,000h,000h,03ch,004h,004h,092h	; 8942  .....~......<...
	defb 07eh,000h,07eh,002h,002h,03eh,002h,002h,07eh,000h,03ch,000h,07eh,002h,002h,004h	; 8952  ~.~..>..~.<.~...
	defb 018h,000h,003h,022h,086h,002h,002h,004h,008h,000h,008h,003h,028h,084h,02ah,02ah	; 8962  ..."........(.**
	defb 04ch,000h,004h,020h,086h,022h,024h,038h,000h,000h,07eh,004h,042h,09dh,07eh,000h	; 8972  L.. ."$8..~.B.~.
	defb 07eh,042h,042h,002h,002h,004h,018h,000h,07eh,002h,07eh,002h,002h,00ch,030h,000h	; 8982  ~BB.....~.~...0.
	defb 000h,060h,002h,002h,004h,008h,070h,000h,010h,048h,020h,005h,000h,083h,070h,050h	; 8992  .`....p..H ...pP
	defb 070h,008h,000h,082h,018h,018h,006h,000h,081h,07eh,007h,000h,084h,03eh,002h,00ch	; 89a2  p........~...>..
	defb 008h,004h,000h,084h,02ah,002h,002h,01ch,003h,000h,085h,020h,01ch,074h,010h,010h	; 89b2  ....*...... .t..
	defb 004h,000h,084h,01ch,004h,004h,03eh,003h,000h,085h,03eh,002h,01eh,002h,03eh,007h	; 89c2  ......>...>...>.
	defb 000h,003h,0ffh,005h,000h,003h,0ffh,007h,000h,091h,010h,010h,07eh,012h,014h,010h	; 89d2  ............~...
	defb 010h,000h,03eh,022h,042h,002h,004h,008h,030h,000h,07eh,004h,002h,082h,004h,018h	; 89e2  ..>"B...0.~.....
	defb 004h,000h,08dh,03eh,002h,00ch,008h,000h,000h,060h,002h,002h,004h,008h,070h,000h	; 89f2  ...>.....`....p.
	defb 007h,0ffh,003h,000h,086h,01ch,006h,006h,000h,027h,01ch,005h,000h,083h,093h,0deh	; 8a02  .........'......
	defb 058h,004h,000h,0b3h,040h,0e0h,070h,060h,013h,01bh,01ah,007h,0dch,076h,007h,03eh	; 8a12  X...@.p`.....v.>
	defb 01bh,01eh,018h,0dbh,05eh,018h,0dbh,05fh,0e0h,060h,060h,0e0h,060h,060h,0e0h,060h	; 8a22  ....^.._.``.``.`
	defb 006h,00fh,01eh,016h,026h,026h,002h,000h,00dh,08dh,0c9h,099h,031h,061h,0c0h,000h	; 8a32  ....&&......1a..
	defb 080h,000h,000h,008h,008h,00ch,0f8h,005h,000h,082h,002h,001h,006h,000h,084h,03fh	; 8a42  ...............?
	defb 0f0h,001h,003h,003h,000h,084h,080h,0c0h,0c0h,080h,006h,000h,08fh,004h,003h,000h	; 8a52  ................
	defb 006h,01ch,018h,00fh,01ch,076h,0c6h,006h,000h,000h,070h,0d8h,004h,000h,004h,006h	; 8a62  .....v....p.....
	defb 084h,0ech,038h,010h,000h,000h	; 8a72

; ----------------------------------------------------------------------
; DATOS patrones_del_titulo_180: Formato B desde 0x7094: los 640 bytes de
;   patrones de la pareja, a 0x0180.
;   0x8a78..0x8a9f  (39 bytes)
DATA_patrones_del_titulo_180:
	defb 080h,041h,078h,0f1h,078h,0f1h,078h,0f1h,050h,0f1h,018h,010h,007h,0f1h,081h,000h	; 8a78  .Ax.x.x.P.......
	defb 007h,0f1h,081h,000h,007h,0f1h,081h,000h,007h,0f1h,081h,000h,007h,0f1h,081h,000h	; 8a88  ................
	defb 008h,010h,078h,0f1h,008h,0f1h,000h	; 8a98

; ----------------------------------------------------------------------
; DATOS patrones_sin_comprimir: Los 56 bytes que 0x6FCD copia tal cual, sin
;   pasar por ningun interprete, a los patrones 0x0818.
;   0x8a9f..0x8ad7  (56 bytes)
DATA_patrones_sin_comprimir:
	defb 004h,004h,004h,004h,004h,008h,010h,000h	; 8a9f  ........
	defb 07eh,002h,002h,002h,002h,004h,018h,000h	; 8aa7  ~.......
	defb 000h,03ch,000h,03ch,000h,03ch,002h,000h	; 8aaf  .<.<.<..
	defb 000h,060h,002h,062h,002h,004h,078h,000h	; 8ab7  .`.b..x.
	defb 010h,010h,07eh,012h,014h,010h,010h,000h	; 8abf  ..~.....
	defb 03eh,022h,042h,002h,004h,008h,030h,000h	; 8ac7  >"B...0.
	defb 008h,008h,07eh,008h,008h,010h,020h,000h	; 8acf  ..~... .

; ----------------------------------------------------------------------
; DATOS colores_del_tablero_900: Formato B desde 0x6FC4: 1792 bytes a los
;   colores 0x2900.
;   0x8ad7..0x90cf  (1528 bytes)
DATA_colores_del_tablero_900:
	defb 000h,069h,003h,0ffh,009h,000h,081h,07eh,006h,000h,081h,07fh,004h,0ffh,003h,000h	; 8ad7  .i.....~........
	defb 081h,0fch,004h,0feh,008h,0ffh,008h,0feh,007h,0ffh,081h,07fh,007h,0feh,081h,0fch	; 8ae7  ................
	defb 003h,000h,081h,07fh,004h,0ffh,003h,000h,081h,0fch,004h,0feh,090h,07eh,002h,00ah	; 8af7  .............~..
	defb 00ch,008h,008h,010h,000h,000h,07eh,002h,002h,014h,008h,004h,000h,004h,07fh,081h	; 8b07  ......~.........
	defb 03fh,003h,000h,004h,0ffh,081h,0feh,006h,000h,085h,07fh,0ffh,0fch,0feh,0feh,003h	; 8b17  ?...............
	defb 000h,086h,0fch,0feh,0feh,07eh,0feh,07eh,004h,002h,085h,004h,018h,000h,000h,07eh	; 8b27  .....~.~.......~
	defb 004h,042h,087h,07eh,000h,07fh,07eh,07fh,07fh,03fh,003h,000h,085h,07fh,07fh,03fh	; 8b37  .B.~..~..?.....?
	defb 0ffh,0feh,006h,000h,085h,07fh,0ffh,0ffh,0f9h,0e4h,003h,000h,085h,0fch,0feh,0deh	; 8b47  ................
	defb 0eeh,0deh,095h,020h,07eh,022h,024h,020h,020h,01eh,000h,000h,03ch,000h,03ch,000h	; 8b57  ... ~"$  ...<.<.
	defb 03ch,002h,000h,07bh,077h,07bh,07fh,03fh,003h,000h,085h,027h,09fh,0ffh,0ffh,0feh	; 8b67  <..{w{.?...'....
	defb 006h,000h,081h,07fh,004h,0ffh,003h,000h,081h,0fch,004h,0feh,081h,008h,003h,028h	; 8b77  ...............(
	defb 087h,02ah,02ah,04ch,000h,070h,050h,070h,005h,000h,004h,07fh,081h,03fh,003h,000h	; 8b87  .**L.pPp.....?..
	defb 004h,0ffh,081h,0feh,006h,000h,081h,07fh,004h,0ffh,003h,000h,081h,0fch,004h,0feh	; 8b97  ................
	defb 004h,000h,084h,07fh,0ffh,0ffh,07fh,004h,000h,084h,0ffh,0c3h,0c3h,0ffh,004h,07fh	; 8ba7  ................
	defb 081h,03fh,003h,000h,004h,0ffh,081h,0feh,006h,000h,081h,07fh,004h,0ffh,003h,000h	; 8bb7  .?..............
	defb 081h,0fch,004h,0feh,004h,000h,08ch,0feh,0ffh,0ffh,0feh,000h,000h,03eh,002h,01eh	; 8bc7  .............>..
	defb 002h,03eh,000h,004h,07fh,081h,03fh,003h,000h,004h,0ffh,081h,0feh,006h,000h,085h	; 8bd7  .>....?.........
	defb 07fh,0ffh,0ffh,0feh,0feh,003h,000h,081h,0fch,003h,0feh,081h,0beh,005h,000h,003h	; 8be7  ................
	defb 0ffh,083h,000h,008h,004h,004h,042h,086h,000h,07fh,07fh,07dh,07fh,03fh,003h,000h	; 8bf7  ......B....}.?..
	defb 085h,07fh,07fh,0ffh,0ffh,0feh,006h,000h,085h,07fh,0ffh,0ffh,0feh,0feh,003h,000h	; 8c07  ................
	defb 081h,0fch,004h,0feh,089h,002h,004h,018h,028h,048h,008h,008h,000h,000h,003h,052h	; 8c17  ........(H.....R
	defb 084h,002h,004h,018h,000h,004h,07fh,081h,03fh,003h,000h,085h,07fh,07fh,0ffh,0ffh	; 8c27  ........?.......
	defb 0feh,006h,000h,085h,07fh,0ffh,0c4h,091h,0aah,003h,000h,088h,0fch,0feh,046h,012h	; 8c37  ..............F.
	defb 0aah,07eh,010h,07eh,003h,010h,081h,00eh,004h,000h,082h,018h,018h,003h,000h,085h	; 8c47  .~.~............
	defb 055h,048h,062h,07fh,03fh,003h,000h,085h,055h,089h,023h,0ffh,0feh,006h,000h,085h	; 8c57  UHb.?...U.#.....
	defb 07fh,0ffh,0e3h,0c9h,0d5h,003h,000h,091h,0fch,0feh,08eh,026h,056h,07eh,002h,002h	; 8c67  ...........&V~..
	defb 03eh,002h,002h,07eh,000h,008h,03eh,008h,03eh,003h,008h,086h,000h,06ah,064h,071h	; 8c77  >..~..>.>....jdq
	defb 07fh,03fh,003h,000h,085h,0abh,093h,0c7h,0ffh,0feh,006h,000h,085h,07fh,0c7h,090h	; 8c87  .?..............
	defb 0a9h,092h,003h,000h,09ah,0fch,0feh,07eh,006h,092h,000h,07eh,002h,002h,014h,008h	; 8c97  .......~...~....
	defb 004h,000h,020h,07eh,022h,024h,020h,020h,01eh,000h,049h,060h,07eh,07fh,03fh,003h	; 8ca7  .. ~"$  ..I`~.?.
	defb 000h,085h,049h,095h,009h,0e3h,0feh,006h,000h,085h,07fh,0ffh,0e3h,0c9h,0d5h,003h	; 8cb7  ..I.............
	defb 000h,090h,0fch,0feh,08eh,026h,056h,07eh,002h,004h,008h,018h,024h,042h,000h,03ch	; 8cc7  .....&V~....$B.<
	defb 000h,07eh,003h,008h,087h,010h,000h,06ah,064h,071h,07fh,03fh,003h,000h,085h,0abh	; 8cd7  .~.....jdq.?....
	defb 093h,0c7h,0ffh,0feh,006h,000h,085h,07fh,0ffh,0ffh,0e3h,0c9h,003h,000h,085h,0fch	; 8ce7  ................
	defb 0feh,0feh,08eh,026h,006h,000h,084h,020h,020h,000h,003h,003h,000h,088h,001h,002h	; 8cf7  ...&...  .......
	defb 004h,064h,071h,07fh,07fh,03fh,003h,000h,085h,093h,0c7h,0ffh,0ffh,0feh,006h,000h	; 8d07  .dq..?..........
	defb 085h,07fh,0ffh,0ffh,0e3h,0c9h,003h,000h,08fh,0fch,0feh,0feh,08eh,026h,024h,0feh	; 8d17  .............&$.
	defb 070h,0a8h,0ach,026h,023h,0f9h,020h,020h,006h,000h,085h,064h,071h,07fh,07fh,03fh	; 8d27  p..&#.  ...dq..?
	defb 003h,000h,085h,093h,0c7h,0ffh,0ffh,0feh,006h,000h,085h,07fh,0ffh,0ffh,0e3h,0c9h	; 8d37  ................
	defb 003h,000h,081h,0fch,004h,0feh,007h,000h,081h,004h,006h,000h,082h,0fch,084h,004h	; 8d47  ................
	defb 07fh,081h,03fh,003h,000h,085h,093h,0c7h,0ffh,0ffh,0feh,006h,000h,085h,07fh,0ffh	; 8d57  ..?.............
	defb 0fch,0fbh,0f6h,003h,000h,09ah,0fch,0feh,07eh,0beh,0deh,004h,004h,01eh,004h,007h	; 8d67  ........~.......
	defb 004h,018h,011h,0fch,084h,0fch,000h,0ffh,080h,0feh,02ah,07bh,07dh,07eh,07fh,03fh	; 8d77  ..........*{}~.?
	defb 003h,000h,085h,06fh,0dfh,03fh,0ffh,0feh,006h,000h,081h,07fh,003h,0ffh,081h,0fch	; 8d87  ...o.?..........
	defb 003h,000h,081h,0fch,003h,0feh,082h,07eh,002h,007h,000h,082h,052h,0ach,006h,000h	; 8d97  .......~....R...
	defb 081h,07eh,003h,07fh,081h,03fh,003h,000h,081h,03fh,003h,0ffh,081h,0feh,006h,000h	; 8da7  .~...?...?......
	defb 085h,07fh,0ffh,0c4h,0eeh,0d5h,003h,000h,085h,0fch,0feh,046h,0eeh,056h,005h,000h	; 8db7  ...........F.V..
	defb 081h,01fh,003h,000h,081h,03fh,006h,000h,085h,06ah,077h,062h,07fh,03fh,003h,000h	; 8dc7  .....?...jwb.?..
	defb 085h,0abh,077h,023h,0ffh,0feh,006h,000h,085h,07fh,0ffh,0c4h,0eeh,0edh,003h,000h	; 8dd7  ..w#............
	defb 085h,0fch,0feh,046h,0eeh,06eh,004h,000h,086h,020h,0f0h,000h,000h,010h,0f8h,006h	; 8de7  ...F.n... ......
	defb 000h,085h,076h,077h,062h,07fh,03fh,003h,000h,085h,0b7h,077h,023h,0ffh,0feh,006h	; 8df7  ..vwb.?....w#...
	defb 000h,085h,07fh,0ffh,0fch,0feh,0fdh,003h,000h,085h,0fch,0feh,07eh,0feh,07eh,008h	; 8e07  ............~.~.
	defb 000h,081h,03fh,007h,000h,085h,07eh,07fh,07eh,07fh,03fh,003h,000h,085h,0bfh,07fh	; 8e17  ..?...~.~.?.....
	defb 03fh,0ffh,0feh,006h,000h,085h,07fh,0ffh,0c4h,0eeh,0eeh,003h,000h,085h,0fch,0feh	; 8e27  ?...............
	defb 046h,0eeh,0eeh,007h,000h,082h,010h,0f8h,007h,000h,085h,077h,077h,062h,07fh,03fh	; 8e37  F..........wwb.?
	defb 003h,000h,085h,077h,077h,023h,0ffh,0feh,006h,000h,085h,07fh,0ffh,0e3h,0f7h,0ebh	; 8e47  ...ww#..........
	defb 003h,000h,09ah,0fch,0feh,08eh,0deh,0aeh,000h,001h,001h,03fh,001h,01fh,011h,01fh	; 8e57  ...........?....
	defb 011h,01fh,007h,00dh,019h,071h,001h,000h,075h,07bh,071h,07fh,03fh,003h,000h,085h	; 8e67  .....q..u{q.?...
	defb 0d7h,0efh,0c7h,0ffh,0feh,006h,000h,085h,07fh,0ffh,0e3h,0f7h,0f7h,003h,000h,085h	; 8e77  ................
	defb 0fch,0feh,08eh,0deh,0deh,003h,000h,092h,0f8h,000h,0f0h,010h,0f0h,010h,0f0h,0c0h	; 8e87  ................
	defb 060h,030h,01ch,000h,000h,07bh,07bh,071h,07fh,03fh,003h,000h,085h,0efh,0efh,0c7h	; 8e97  `0...{{q.?......
	defb 0ffh,0feh,006h,000h,085h,07fh,0ffh,0fch,0feh,0feh,003h,000h,09ah,0fch,0feh,07eh	; 8ea7  ...............~
	defb 0feh,0feh,000h,001h,001h,03fh,001h,001h,03fh,024h,024h,022h,02fh,021h,02fh,021h	; 8eb7  .....?..?$$"/!/!
	defb 021h,000h,07fh,07fh,07eh,07fh,03fh,003h,000h,085h,07fh,07fh,03fh,0ffh,0feh,006h	; 8ec7  !...~.?.....?...
	defb 000h,085h,07fh,0ffh,0fch,0feh,0feh,003h,000h,085h,0fch,0feh,07eh,0feh,0feh,003h	; 8ed7  ............~...
	defb 000h,092h,0f8h,000h,000h,0f8h,048h,048h,088h,0e8h,008h,0e8h,008h,010h,000h,07fh	; 8ee7  ......HH........
	defb 07fh,07eh,07fh,03fh,003h,000h,085h,07fh,07fh,03fh,0ffh,0feh,006h,000h,085h,07fh	; 8ef7  .~.?.....?......
	defb 0f6h,0fbh,0eah,0f5h,003h,000h,09ah,0fch,0beh,06eh,05eh,096h,000h,000h,020h,017h	; 8f07  .........n^... .
	defb 000h,001h,002h,067h,001h,002h,00ah,00ah,012h,062h,044h,000h,069h,07ah,076h,07dh	; 8f17  ...g.....bD.izv}
	defb 03fh,003h,000h,085h,02fh,057h,0dfh,06fh,0feh,006h,000h,085h,07fh,0fbh,0eah,0f1h	; 8f27  ?.../W.o........
	defb 0fbh,003h,000h,090h,0fch,0feh,07eh,03eh,07eh,000h,080h,090h,0f8h,080h,020h,010h	; 8f37  ......~>~..... .
	defb 0f8h,048h,0a0h,0a0h,003h,0a2h,087h,01ch,000h,07eh,07ch,07eh,07fh,03fh,003h,000h	; 8f47  .H.......~|~.?..
	defb 085h,0dfh,08fh,057h,0dfh,0feh,006h,000h,085h,07fh,0feh,0ffh,0fdh,0fdh,003h,000h	; 8f57  ...W............
	defb 09ah,0fch,0feh,07eh,0beh,0beh,000h,010h,00fh,008h,008h,00fh,008h,00fh,008h,00bh	; 8f67  ...~............
	defb 00ah,00ah,01bh,010h,020h,000h,07dh,07dh,07eh,07fh,03fh,003h,000h,085h,0bfh,0bfh	; 8f77  .... .}}~.?.....
	defb 0ffh,07fh,0feh,006h,000h,085h,07fh,0fbh,0f9h,0fbh,0f8h,003h,000h,09ah,0fch,0feh	; 8f87  ................
	defb 0ceh,03eh,0feh,000h,020h,0f0h,018h,010h,0f0h,000h,0f8h,008h,0e4h,024h,024h,0e4h	; 8f97  .>.. ........$$.
	defb 004h,018h,000h,07fh,07ch,073h,07fh,03fh,003h,000h,085h,01fh,0dfh,09fh,0dfh,0feh	; 8fa7  ....|s.?........
	defb 006h,000h,085h,07fh,0fdh,0feh,0f0h,0ffh,003h,000h,09ah,0fch,0feh,0deh,00eh,0feh	; 8fb7  ................
	defb 022h,025h,022h,038h,024h,020h,020h,000h,018h,07eh,042h,042h,002h,004h,018h,000h	; 8fc7  "%"8$  ..~BB....
	defb 07fh,070h,07bh,07fh,03fh,003h,000h,085h,0ffh,00fh,07fh,0bfh,0feh,006h,000h,085h	; 8fd7  .p{.?...........
	defb 07fh,0fah,0fbh,0f7h,0eah,003h,000h,08eh,0fch,01eh,07eh,05eh,00eh,03ch,000h,07eh	; 8fe7  ..........~^.<.~
	defb 002h,002h,004h,018h,000h,0ffh,007h,000h,085h,070h,07ah,07eh,078h,03fh,003h,000h	; 8ff7  .........pz~x?..
	defb 085h,057h,0efh,0dfh,05fh,0feh,006h,000h,085h,07fh,0ffh,0e8h,0f5h,0f5h,003h,000h	; 9007  .W.._...........
	defb 088h,0fch,0deh,00eh,026h,02eh,010h,048h,020h,005h,000h,083h,070h,050h,070h,005h	; 9017  ....&..H ...pPp.
	defb 000h,085h,074h,064h,070h,07bh,03fh,003h,000h,085h,0afh,0afh,017h,0ffh,0feh,006h	; 9027  ..tdp{?.........
	defb 000h,085h,07fh,0ffh,0f0h,0ffh,0f8h,003h,000h,08ch,0fch,0feh,01eh,0feh,03eh,000h	; 9037  ..............>.
	defb 000h,070h,0ffh,0f8h,0f8h,0f0h,004h,000h,081h,07eh,004h,000h,085h,07ch,07fh,078h	; 9047  .p.......~...|.x
	defb 07fh,03fh,003h,000h,085h,01fh,0ffh,00fh,0ffh,0feh,006h,000h,085h,07fh,0ffh,0ffh	; 9057  .?..............
	defb 0f0h,0ffh,003h,000h,09ah,0fch,0feh,0feh,01eh,0feh,000h,060h,002h,002h,004h,008h	; 9067  ...........`....
	defb 070h,000h,004h,038h,008h,07eh,008h,008h,010h,000h,07fh,078h,07fh,07fh,03fh,003h	; 9077  p..8.~.....x..?.
	defb 000h,085h,0ffh,00fh,0ffh,0ffh,0feh,006h,000h,081h,07fh,003h,0ffh,081h,0e0h,003h	; 9087  ................
	defb 000h,085h,0fch,0feh,0feh,0eeh,006h,003h,022h,092h,002h,002h,004h,008h,000h,008h	; 9097  ........".......
	defb 03eh,008h,008h,02ah,02ah,008h,000h,060h,077h,07fh,07fh,03fh,003h,000h,081h,007h	; 90a7  >..**..`w..?....
	defb 003h,0ffh,081h,0feh,013h,000h,08ah,07eh,002h,00ah,00ch,008h,008h,010h,000h,020h	; 90b7  .......~....... 
	defb 07eh,004h,022h,081h,044h,011h,000h,000h	; 90c7  ~.".D...

; ----------------------------------------------------------------------
; DATOS patrones_sueltos_818: Formato B desde 0x6FDC: 56 bytes a los patrones
;   0x0818.
;   0x90cf..0x90d4  (5 bytes)
DATA_patrones_sueltos_818:
	defb 018h,048h,038h,017h,000h	; 90cf

; ----------------------------------------------------------------------
; DATOS patrones_del_tablero_900: Formato B desde 0x6FCA: los 1792 bytes de
;   patrones de la pareja, a 0x0900.
;   0x90d4..0x92e3  (527 bytes)
DATA_patrones_del_tablero_900:
	defb 000h,049h,008h,071h,008h,0f1h,030h,081h,010h,080h,010h,091h,010h,080h,004h,0f0h	; 90d4  .I.q..0.........
	defb 004h,0f6h,004h,0f0h,004h,0f6h,010h,091h,004h,0f6h,004h,0f0h,004h,0f6h,008h,0f0h	; 90e4  ................
	defb 004h,0fch,004h,0f0h,004h,0fch,010h,091h,004h,0fch,004h,0f0h,004h,0fch,014h,0f0h	; 90f4  ................
	defb 010h,091h,014h,0f0h,004h,0f1h,004h,0f0h,011h,0f1h,002h,0f6h,005h,0f1h,004h,0f0h	; 9104  ................
	defb 004h,0f1h,008h,0f0h,004h,0f1h,004h,0f0h,00ch,0f1h,008h,017h,004h,0f1h,004h,0f0h	; 9114  ................
	defb 004h,0f1h,008h,0f0h,004h,0f1h,004h,0f0h,004h,0f1h,008h,071h,008h,017h,004h,0f1h	; 9124  ...........q....
	defb 004h,0f0h,004h,0f1h,008h,0f0h,004h,0f1h,004h,0f0h,004h,0f1h,010h,017h,004h,0f1h	; 9134  ................
	defb 004h,0f0h,004h,0f1h,008h,0f0h,004h,0f1h,004h,0f0h,004h,0f1h,010h,017h,004h,0f1h	; 9144  ................
	defb 004h,0f0h,004h,0f1h,008h,0f0h,004h,0f1h,004h,0f0h,004h,0f1h,010h,017h,004h,0f1h	; 9154  ................
	defb 004h,0f0h,004h,0f1h,008h,0f0h,004h,0f1h,004h,0f0h,004h,0f1h,010h,017h,004h,0f1h	; 9164  ................
	defb 004h,0f0h,004h,0f1h,008h,0f0h,004h,0f1h,004h,0f0h,004h,0f1h,010h,017h,004h,0f1h	; 9174  ................
	defb 004h,0f0h,004h,0f1h,008h,0f0h,004h,0f1h,004h,0f0h,018h,0f1h,004h,0f0h,004h,0f1h	; 9184  ................
	defb 008h,0f0h,004h,0f1h,004h,0f0h,018h,0f1h,004h,0f0h,004h,0f1h,008h,0f0h,004h,0f1h	; 9194  ................
	defb 004h,0f0h,018h,0f1h,004h,0f0h,004h,0f1h,008h,0f0h,004h,0f1h,004h,0f0h,018h,0f1h	; 91a4  ................
	defb 004h,0f0h,004h,0f1h,008h,0f0h,004h,0f1h,004h,0f0h,018h,0f1h,004h,0f0h,004h,0f1h	; 91b4  ................
	defb 008h,0f0h,004h,0fch,004h,0f0h,004h,0fch,010h,0f1h,004h,0fch,004h,0f0h,004h,0fch	; 91c4  ................
	defb 008h,0f0h,004h,0fch,004h,0f0h,004h,0fch,010h,0f1h,004h,0fch,004h,0f0h,004h,0fch	; 91d4  ................
	defb 008h,0f0h,004h,0f6h,004h,0f0h,004h,0f6h,010h,0f1h,004h,0f6h,004h,0f0h,004h,0f6h	; 91e4  ................
	defb 008h,0f0h,004h,0fch,004h,0f0h,004h,0fch,010h,0f1h,004h,0fch,004h,0f0h,004h,0fch	; 91f4  ................
	defb 008h,0f0h,004h,0fch,004h,0f0h,004h,0fch,010h,0f1h,004h,0fch,004h,0f0h,004h,0fch	; 9204  ................
	defb 008h,0f0h,004h,0fch,004h,0f0h,004h,0fch,010h,0f1h,004h,0fch,004h,0f0h,004h,0fch	; 9214  ................
	defb 008h,0f0h,004h,0fch,004h,0f0h,004h,0fch,010h,0f1h,004h,0fch,004h,0f0h,004h,0fch	; 9224  ................
	defb 008h,0f0h,004h,0fch,004h,0f0h,004h,0fch,010h,0f1h,004h,0fch,004h,0f0h,004h,0fch	; 9234  ................
	defb 008h,0f0h,004h,0fch,004h,0f0h,004h,0fch,010h,0f1h,004h,0fch,004h,0f0h,004h,0fch	; 9244  ................
	defb 008h,0f0h,004h,0f1h,004h,0f0h,018h,0f1h,004h,0f0h,004h,0f1h,008h,0f0h,004h,0f1h	; 9254  ................
	defb 004h,0f0h,018h,0f1h,004h,0f0h,004h,0f1h,008h,0f0h,004h,0f1h,004h,0f0h,018h,0f1h	; 9264  ................
	defb 004h,0f0h,004h,0f1h,008h,0f0h,004h,0f1h,004h,0f0h,018h,0f1h,004h,0f0h,004h,0f1h	; 9274  ................
	defb 008h,0f0h,004h,0f1h,004h,0f0h,00ch,0f1h,008h,010h,004h,0f1h,004h,0f0h,004h,0f1h	; 9284  ................
	defb 008h,0f0h,004h,0f1h,004h,0f0h,004h,0f1h,010h,017h,004h,0f1h,004h,0f0h,004h,0f1h	; 9294  ................
	defb 008h,0f0h,004h,0f1h,004h,0f0h,004h,0f1h,003h,0b1h,081h,0f1h,004h,0b1h,008h,017h	; 92a4  ................
	defb 004h,0f1h,004h,0f0h,004h,0f1h,008h,0f0h,004h,0f1h,004h,0f0h,004h,0f1h,010h,017h	; 92b4  ................
	defb 004h,0f1h,004h,0f0h,004h,0f1h,008h,0f0h,004h,0f1h,004h,0f0h,004h,0f1h,010h,017h	; 92c4  ................
	defb 004h,0f1h,004h,0f0h,004h,0f1h,004h,0f0h,010h,000h,010h,017h,010h,000h,000h	; 92d4  ...............

; ----------------------------------------------------------------------
; DATOS colores_sin_comprimir: Los 96 bytes que 0x6FF7 copia tal cual a los
;   colores 0x3020.
;   0x92e3..0x9343  (96 bytes)
DATA_colores_sin_comprimir:
	defb 008h,07eh,008h,018h,028h,048h,008h,000h	; 92e3  .~..(H..
	defb 000h,000h,000h,07eh,000h,000h,000h,000h	; 92eb  ...~....
	defb 03ch,000h,07eh,002h,002h,004h,018h,000h	; 92f3  <.~.....
	defb 07eh,002h,004h,008h,018h,024h,042h,000h	; 92fb  ~....$B.
	defb 022h,022h,022h,002h,002h,004h,008h,000h	; 9303  """.....
	defb 000h,000h,020h,01ch,074h,010h,010h,000h	; 930b  .. .t...
	defb 000h,060h,002h,002h,004h,008h,070h,000h	; 9313  .`....p.
	defb 000h,060h,002h,062h,002h,004h,078h,000h	; 931b  .`.b..x.
	defb 022h,022h,022h,002h,002h,004h,008h,000h	; 9323  """.....
	defb 000h,000h,020h,01ch,074h,010h,010h,000h	; 932b  .. .t...
	defb 000h,060h,002h,002h,004h,008h,070h,000h	; 9333  .`....p.
	defb 002h,002h,014h,008h,014h,022h,040h,000h	; 933b  ....."@.

; ----------------------------------------------------------------------
; DATOS colores_del_tercio_de_abajo: Formato B. Se lee DOS VECES y de dos
;   maneras: 0x7003 lo pasa entero por 0x468F a los colores 0x30D0 (1840 bytes
;   de salida), y 0x6FDF entra por 0x93AA, 103 bytes mas adelante, saltandose
;   el prologo, para sacar por 0x7883 los 1728 bytes -36 tandas de 48- que
;   0x46B1 vuelca GIRADOS. La diferencia son 112 bytes exactos, y los dos
;   caminos acaban en el mismo 0x99F3.
;   0x9343..0x99f4  (1713 bytes)
DATA_colores_del_tercio_de_abajo:
	defb 0d0h,070h,082h,020h,07eh,004h,022h,09eh,044h,000h,004h,038h,008h,07eh,008h,008h	; 9343  .p. ~.".D..8.~..
	defb 010h,000h,020h,050h,008h,004h,002h,002h,000h,000h,03eh,022h,052h,00ah,004h,008h	; 9353  .. P......>"R...
	defb 030h,000h,008h,03eh,008h,03eh,003h,008h,092h,000h,000h,060h,002h,062h,002h,004h	; 9363  0..>.>.....`.b..
	defb 078h,000h,008h,03eh,008h,008h,02ah,02ah,008h,000h,000h,003h,052h,087h,002h,004h	; 9373  x..>..**....R...
	defb 018h,000h,07eh,010h,07eh,003h,010h,084h,00eh,000h,000h,07eh,004h,042h,085h,07eh	; 9383  ..~.~......~.B.~
	defb 000h,010h,048h,020h,005h,000h,083h,070h,050h,070h,009h,000h,081h,07eh,004h,000h	; 9393  ..H ...pPp...~..
	defb 081h,07eh,004h,002h,082h,004h,018h,003h,000h,081h,07fh,004h,0ffh,003h,000h,081h	; 93a3  .~..............
	defb 0fch,004h,0feh,008h,0ffh,008h,0feh,007h,0ffh,081h,07fh,007h,0feh,081h,0fch,003h	; 93b3  ................
	defb 000h,085h,07fh,0ffh,0fch,0feh,0feh,003h,000h,084h,0fch,0feh,0feh,07eh,003h,0feh	; 93c3  .............~..
	defb 08eh,0ech,0e2h,0e6h,0e6h,0f6h,0f0h,0feh,09eh,00eh,0e6h,0eeh,0eeh,0ceh,05eh,006h	; 93d3  ..............^.
	defb 0feh,082h,0ffh,07fh,007h,0feh,081h,0fch,003h,000h,085h,07fh,0ffh,0ffh,0f9h,0e4h	; 93e3  ................
	defb 003h,000h,0a5h,0fch,0feh,0deh,0eeh,0deh,0fdh,0ebh,0f7h,0f3h,0e8h,0dah,0a3h,0efh	; 93f3  ................
	defb 036h,0aeh,09eh,05eh,0eeh,026h,072h,00eh,0e0h,09bh,0fah,0b6h,0c5h,0fbh,0ffh,07fh	; 9403  6..^.&r.........
	defb 03eh,05eh,0deh,0eeh,0e6h,0feh,0feh,0fch,003h,000h,081h,07fh,004h,0ffh,003h,000h	; 9413  >^..............
	defb 081h,0fch,004h,0feh,008h,0ffh,008h,0feh,007h,0ffh,081h,07fh,007h,0feh,081h,0fch	; 9423  ................
	defb 003h,000h,081h,07fh,004h,0ffh,003h,000h,081h,0fch,004h,0feh,094h,0ffh,0ffh,0fbh	; 9433  ................
	defb 0fdh,0edh,0f5h,0f5h,0fch,0beh,03eh,07eh,07eh,06eh,04eh,01eh,07eh,0f9h,0f5h,0c5h	; 9443  ......>~~nN.~...
	defb 0efh,003h,0ffh,085h,07fh,07eh,07eh,076h,08eh,003h,0feh,081h,0fch,003h,000h,081h	; 9453  .....~~v........
	defb 07fh,004h,0ffh,003h,000h,081h,0fch,004h,0feh,094h,0ffh,0d8h,0e3h,0fdh,0fbh,0fbh	; 9463  ................
	defb 0e8h,0e9h,00eh,0f6h,07eh,03eh,07eh,00eh,066h,06eh,0edh,0e7h,0e6h,0f0h,003h,0ffh	; 9473  ....~>~.fn......
	defb 085h,07fh,06eh,06eh,0deh,03eh,003h,0feh,081h,0fch,003h,000h,085h,07fh,0ffh,0ffh	; 9483  ..nn.>..........
	defb 0feh,0feh,003h,000h,081h,0fch,003h,0feh,095h,0beh,0feh,0f2h,0feh,0fbh,0fah,0f0h	; 9493  ................
	defb 0eeh,0fch,07eh,0feh,0beh,0aeh,016h,072h,076h,0b6h,0eeh,0ech,0f6h,0feh,003h,0ffh	; 94a3  ..~....rv.......
	defb 089h,07fh,0f6h,076h,0f6h,0eeh,01eh,0feh,0feh,0fch,003h,000h,085h,07fh,0ffh,0ffh	; 94b3  ...v............
	defb 0feh,0feh,003h,000h,081h,0fch,005h,0feh,09fh,0f0h,0feh,0f0h,0f2h,0f8h,0fah,0f8h	; 94c3  ................
	defb 0beh,07eh,0feh,01eh,09eh,03eh,0beh,03eh,0fah,0f6h,0e6h,0cch,0deh,0ffh,0ffh,07fh	; 94d3  .~...>.>........
	defb 0beh,0deh,0ceh,0e6h,0f2h,0feh,0feh,0fch,003h,000h,085h,07fh,0ffh,0c4h,091h,0aah	; 94e3  ................
	defb 003h,000h,0a5h,0fch,0feh,046h,012h,0aah,091h,0c4h,0ffh,0c4h,091h,0aah,091h,0c4h	; 94f3  .....F..........
	defb 012h,046h,0feh,046h,012h,0aah,012h,046h,0ffh,0c4h,091h,0aah,091h,0c4h,0ffh,07fh	; 9503  .F.F...F........
	defb 0feh,046h,012h,0aah,012h,046h,0feh,0fch,003h,000h,085h,07fh,0ffh,0e3h,0c9h,0d5h	; 9513  .F...F..........
	defb 003h,000h,0a5h,0fch,0feh,08eh,026h,056h,0c9h,0e3h,0c9h,0d5h,0c9h,0e3h,0c9h,0d5h	; 9523  ......&V........
	defb 026h,08eh,026h,056h,026h,08eh,026h,056h,0c9h,0e3h,0c9h,0d5h,0c9h,0e3h,0ffh,07fh	; 9533  &.&V&.&V........
	defb 026h,08eh,026h,056h,026h,08eh,0feh,0fch,003h,000h,085h,07fh,0c7h,090h,0a9h,092h	; 9543  &.&V&...........
	defb 003h,000h,0a5h,0fch,0feh,07eh,006h,092h,0c1h,0fch,0ffh,0ffh,0e3h,0c9h,0d5h,0c9h	; 9553  .....~..........
	defb 02ah,012h,0c6h,0feh,08eh,026h,056h,026h,0e3h,0e3h,0c9h,0d5h,0c9h,0e3h,0ffh,07fh	; 9563  *....&V&........
	defb 08eh,08eh,026h,056h,026h,08eh,0feh,0fch,003h,000h,085h,07fh,0ffh,0e3h,0c9h,0d5h	; 9573  ..&V&...........
	defb 003h,000h,0a5h,0fch,0feh,08eh,026h,056h,0c9h,0e3h,0ffh,0ffh,0e3h,0c9h,0d5h,0c9h	; 9583  ......&V........
	defb 026h,08eh,0feh,0feh,08eh,026h,056h,026h,0e3h,0e3h,0c9h,0d5h,0c9h,0e3h,0ffh,07fh	; 9593  &....&V&........
	defb 08eh,08eh,026h,056h,026h,08eh,0feh,0fch,003h,000h,085h,07fh,0ffh,0ffh,0e3h,0c9h	; 95a3  ..&V&...........
	defb 003h,000h,0a5h,0fch,0feh,0feh,08eh,026h,0d5h,0c9h,0e3h,0fch,0f9h,0fah,0f9h,0fch	; 95b3  .......&........
	defb 056h,026h,08eh,07eh,03eh,0beh,03eh,07eh,0e3h,0c9h,0d5h,0c9h,0e3h,0ffh,0ffh,07fh	; 95c3  V&.~>.>~........
	defb 08eh,026h,056h,026h,08eh,0feh,0feh,0fch,003h,000h,085h,07fh,0ffh,0ffh,0e3h,0c9h	; 95d3  .&V&............
	defb 003h,000h,088h,0fch,0feh,0feh,08eh,026h,0d5h,0c9h,0e3h,005h,0ffh,083h,056h,026h	; 95e3  .......&......V&
	defb 08eh,005h,0feh,090h,0e3h,0c9h,0d5h,0c9h,0e3h,0ffh,0ffh,07fh,08eh,026h,056h,026h	; 95f3  .............&V&
	defb 08eh,0feh,0feh,0fch,003h,000h,085h,07fh,0ffh,0ffh,0e3h,0c9h,003h,000h,081h,0fch	; 9603  ................
	defb 004h,0feh,088h,0d5h,0c9h,0e3h,0fch,0f9h,0fah,0f9h,0fch,003h,0feh,085h,07eh,03eh	; 9613  ..............~>
	defb 0beh,03eh,07eh,007h,0ffh,089h,07fh,08eh,026h,056h,026h,08eh,0feh,0feh,0fch,003h	; 9623  .>~.....&V&.....
	defb 000h,085h,07fh,0ffh,0fch,0fbh,0f6h,003h,000h,089h,0fch,0feh,07eh,0beh,0deh,0f5h	; 9633  ............~...
	defb 0f6h,0fbh,0fch,003h,0ffh,085h,0fch,05eh,0deh,0beh,07eh,003h,0feh,091h,07eh,0fbh	; 9643  .......^..~...~.
	defb 0f6h,0f5h,0f6h,0fbh,0fch,0ffh,07fh,0beh,0deh,05eh,0deh,0beh,07eh,0feh,0fch,003h	; 9653  .........^..~...
	defb 000h,081h,07fh,003h,0ffh,081h,0fch,003h,000h,081h,0fch,003h,0feh,085h,07eh,0f0h	; 9663  ..............~.
	defb 0e3h,0cch,0c8h,003h,093h,085h,0c8h,01eh,08eh,066h,026h,003h,092h,085h,026h,0cch	; 9673  .........f&...&.
	defb 0e3h,0f0h,0fch,003h,0ffh,085h,07fh,066h,08eh,01eh,07eh,003h,0feh,081h,0fch,003h	; 9683  .......f..~.....
	defb 000h,085h,07fh,0ffh,0c4h,0eeh,0d5h,003h,000h,0a5h,0fch,0feh,046h,0eeh,056h,0eeh	; 9693  ............F.V.
	defb 0c4h,0ffh,0c4h,0eeh,0d5h,0eeh,0c4h,0eeh,046h,0feh,046h,0eeh,056h,0eeh,046h,0ffh	; 96a3  ........F.F.V.F.
	defb 0c4h,0eeh,0d5h,0eeh,0c4h,0ffh,07fh,0feh,046h,0eeh,056h,0eeh,046h,0feh,0fch,003h	; 96b3  ........F.V.F...
	defb 000h,085h,07fh,0ffh,0c4h,0eeh,0edh,003h,000h,089h,0fch,0feh,046h,0eeh,06eh,0d5h	; 96c3  ............F.n.
	defb 0ebh,0e3h,0c7h,003h,0ffh,085h,0c7h,056h,0aeh,08eh,0c6h,003h,0feh,091h,0c6h,0e3h	; 96d3  .......V........
	defb 0ebh,0d5h,0edh,0eeh,0c4h,0ffh,07fh,08eh,0aeh,056h,06eh,0eeh,046h,0feh,0fch,003h	; 96e3  .........Vn.F...
	defb 000h,085h,07fh,0ffh,0fch,0feh,0fdh,003h,000h,0a5h,0fch,0feh,07eh,0feh,07eh,0feh	; 96f3  ............~.~.
	defb 0fch,0ffh,0c4h,0eeh,0d5h,0eeh,0c4h,0feh,07eh,0feh,046h,0eeh,056h,0eeh,046h,0ffh	; 9703  ........~.F.V.F.
	defb 0c4h,0eeh,0d5h,0eeh,0c4h,0ffh,07fh,0feh,046h,0eeh,056h,0eeh,046h,0feh,0fch,003h	; 9713  ........F.V.F...
	defb 000h,085h,07fh,0ffh,0c4h,0eeh,0eeh,003h,000h,089h,0fch,0feh,046h,0eeh,0eeh,0d5h	; 9723  ............F...
	defb 0eeh,0eeh,0c4h,003h,0ffh,085h,0c4h,056h,0eeh,0eeh,046h,003h,0feh,091h,046h,0eeh	; 9733  .......V..F...F.
	defb 0eeh,0d5h,0eeh,0eeh,0c4h,0ffh,07fh,0eeh,0eeh,056h,0eeh,0eeh,046h,0feh,0fch,003h	; 9743  .........V..F...
	defb 000h,085h,07fh,0ffh,0e3h,0f7h,0ebh,003h,000h,0a5h,0fch,0feh,08eh,0deh,0aeh,0f7h	; 9753  ................
	defb 0e3h,0ffh,0fch,0feh,0fdh,0feh,0fch,0deh,08eh,0feh,07eh,0feh,07eh,0feh,07eh,0ffh	; 9763  ..........~.~.~.
	defb 0e3h,0f7h,0ebh,0f7h,0e3h,0ffh,07fh,0feh,08eh,0deh,0aeh,0deh,08eh,0feh,0fch,003h	; 9773  ................
	defb 000h,085h,07fh,0ffh,0e3h,0f7h,0f7h,003h,000h,089h,0fch,0feh,08eh,0deh,0deh,0ebh	; 9783  ................
	defb 0f7h,0f7h,0e3h,003h,0ffh,085h,0e3h,0aeh,0deh,0deh,08eh,003h,0feh,091h,08eh,0f7h	; 9793  ................
	defb 0f7h,0ebh,0f7h,0f7h,0e3h,0ffh,07fh,0deh,0deh,0aeh,0deh,0deh,08eh,0feh,0fch,003h	; 97a3  ................
	defb 000h,085h,07fh,0ffh,0fch,0feh,0feh,003h,000h,089h,0fch,0feh,07eh,0feh,0feh,0fdh	; 97b3  ............~...
	defb 0feh,0feh,0fch,003h,0ffh,085h,0e3h,07eh,0feh,0feh,07eh,003h,0feh,091h,08eh,0f7h	; 97c3  .......~..~.....
	defb 0f7h,0ebh,0f7h,0f7h,0e3h,0ffh,07fh,0deh,0deh,0aeh,0deh,0deh,08eh,0feh,0fch,003h	; 97d3  ................
	defb 000h,085h,07fh,0ffh,0fch,0feh,0feh,003h,000h,089h,0fch,0feh,07eh,0feh,0feh,0fdh	; 97e3  ............~...
	defb 0feh,0feh,0fch,003h,0ffh,085h,0fch,07eh,0feh,0feh,07eh,003h,0feh,091h,07eh,0feh	; 97f3  .......~..~...~.
	defb 0feh,0fdh,0feh,0feh,0fch,0ffh,07fh,0feh,0feh,07eh,0feh,0feh,07eh,0feh,0fch,003h	; 9803  .........~..~...
	defb 000h,085h,07fh,0f6h,0fbh,0eah,0f4h,003h,000h,0a5h,0fch,0beh,06eh,05eh,096h,0d5h	; 9813  ............n^..
	defb 0eah,0f5h,0f8h,0e2h,0ddh,0cch,09fh,02eh,056h,026h,086h,052h,08eh,046h,016h,0ech	; 9823  ........V&.R.F..
	defb 0afh,097h,0c8h,0fdh,0fdh,0f2h,07fh,01eh,02eh,04eh,09eh,07eh,07eh,03eh,0fch,003h	; 9833  .........N.~~>..
	defb 000h,085h,07fh,0fbh,0eah,0f1h,0fbh,003h,000h,0a5h,0fch,0feh,07eh,03eh,07eh,0fbh	; 9843  ............~>~.
	defb 0f7h,0efh,0ffh,0fbh,0fch,0e0h,0f8h,07eh,076h,086h,0beh,0beh,07eh,006h,01eh,0f6h	; 9853  .......~v...~...
	defb 0f0h,0f6h,0c0h,0cch,0c8h,0e7h,07fh,0deh,01eh,0ceh,006h,0a6h,006h,0ceh,0fch,003h	; 9863  ................
	defb 000h,085h,07fh,0feh,0ffh,0fdh,0fdh,003h,000h,0a5h,0fch,0feh,07eh,0beh,0beh,0fbh	; 9873  ............~...
	defb 0fbh,0f7h,0ffh,0fbh,0fch,0e0h,0f8h,0deh,0ceh,0e6h,0beh,0beh,07eh,006h,01eh,0f6h	; 9883  ............~...
	defb 0f0h,0f6h,0c0h,0cch,0c8h,0e7h,07fh,0deh,01eh,0ceh,006h,0a6h,006h,0ceh,0fch,003h	; 9893  ................
	defb 000h,085h,07fh,0fbh,0f9h,0fbh,0f8h,003h,000h,0a5h,0fch,0feh,0ceh,03eh,0feh,0f3h	; 98a3  .............>..
	defb 0c9h,0fch,0ffh,0fbh,0fch,0e0h,0f8h,0feh,0feh,01eh,0beh,0beh,07eh,006h,01eh,0f6h	; 98b3  ............~...
	defb 0f0h,0f6h,0c0h,0cch,0c8h,0e7h,07fh,0deh,01eh,0ceh,006h,0a6h,006h,0ceh,0fch,003h	; 98c3  ................
	defb 000h,085h,07fh,0fdh,0feh,0f0h,0ffh,003h,000h,0a5h,0fch,0feh,0deh,00eh,0feh,0fbh	; 98d3  ................
	defb 0f7h,0f7h,0ffh,0fbh,0fch,0e0h,0f8h,09eh,0ceh,0ceh,0beh,0beh,07eh,006h,01eh,0f6h	; 98e3  ............~...
	defb 0f0h,0f6h,0c0h,0cch,0c8h,0e7h,07fh,0deh,01eh,0ceh,006h,0a6h,006h,0ceh,0fch,003h	; 98f3  ................
	defb 000h,085h,07fh,0fah,0fbh,0f7h,0eah,003h,000h,0a5h,0fch,01eh,07eh,05eh,00eh,0dbh	; 9903  ............~^..
	defb 0fah,0f4h,0ffh,0fbh,0fch,0e0h,0f8h,05eh,0deh,006h,0beh,0beh,07eh,006h,01eh,0f6h	; 9913  .......^....~...
	defb 0f0h,0f6h,0c0h,0cch,0c8h,0e7h,07fh,0deh,01eh,0ceh,006h,0a6h,006h,0ceh,0fch,003h	; 9923  ................
	defb 000h,085h,07fh,0ffh,0e8h,0f5h,0f5h,003h,000h,0a5h,0fch,0deh,00eh,026h,02eh,0f5h	; 9933  .............&..
	defb 0f0h,0fbh,0ffh,0fbh,0fch,0e0h,0f8h,06eh,00eh,0deh,0beh,0beh,07eh,006h,01eh,0f6h	; 9943  .......n....~...
	defb 0f0h,0f6h,0c0h,0cch,0c8h,0e7h,07fh,0deh,01eh,0ceh,006h,0a6h,006h,0ceh,0fch,003h	; 9953  ................
	defb 000h,085h,07fh,0ffh,0f0h,0ffh,0f8h,003h,000h,0a5h,0fch,0feh,01eh,0feh,03eh,0ffh	; 9963  ..............>.
	defb 0c0h,0ffh,0ffh,0fbh,0fch,0e0h,0f8h,0eeh,006h,0feh,0beh,0beh,07eh,006h,01eh,0f6h	; 9973  ............~...
	defb 0f0h,0f6h,0c0h,0cch,0c8h,0e7h,07fh,0deh,01eh,0ceh,006h,0a6h,006h,0ceh,0fch,003h	; 9983  ................
	defb 000h,085h,07fh,0ffh,0ffh,0f0h,0ffh,003h,000h,0a5h,0fch,0feh,0feh,01eh,0feh,0ffh	; 9993  ................
	defb 0e0h,0ffh,0ffh,0fbh,0fch,0e0h,0f8h,0eeh,006h,0feh,0beh,0beh,07eh,006h,01eh,0f6h	; 99a3  ............~...
	defb 0f0h,0f6h,0c0h,0cch,0c8h,0e7h,07fh,0deh,01eh,0ceh,006h,0a6h,006h,0ceh,0fch,003h	; 99b3  ................
	defb 000h,081h,07fh,003h,0ffh,081h,0e0h,003h,000h,085h,0fch,0feh,0feh,0eeh,006h,004h	; 99c3  ................
	defb 0ffh,084h,0fbh,0fch,0e0h,0f8h,003h,0feh,095h,0beh,0beh,07eh,006h,01eh,0f6h,0f0h	; 99d3  ...........~....
	defb 0f6h,0c0h,0cch,0c8h,0e7h,07fh,0deh,01eh,0ceh,006h,0a6h,006h,0ceh,0fch,030h,000h	; 99e3  ..............0.
	defb 000h	; 99f3

; ----------------------------------------------------------------------
; DATOS patrones_sueltos_020: Formato B desde 0x700C: 96 bytes a los patrones
;   0x0020.
;   0x99f4..0x99f9  (5 bytes)
DATA_patrones_sueltos_020:
	defb 020h,050h,060h,0f1h,000h	; 99f4

; ----------------------------------------------------------------------
; DATOS patrones_del_tercio_de_abajo: Formato B, la pareja del bloque de
;   colores. 0x700F lo pasa entero a los patrones 0x10D0, y 0x6FEB entra por
;   0x9A05 -12 bytes mas adelante- para el mismo volcado girado, esta vez por
;   0x46DC. Otra vez 1840 bytes por un camino y 1728 por el otro, y los dos
;   acaban en 0x9C49.
;   0x99f9..0x9c4a  (593 bytes)
DATA_patrones_del_tercio_de_abajo:
	defb 0d0h,050h,060h,0f1h,004h,000h,081h,0f0h,003h,000h,008h,0f1h,030h,080h,004h,0f0h	; 99f9  .P`.........0...
	defb 004h,0f6h,004h,0f0h,01bh,0f6h,081h,0f0h,007h,0f6h,081h,0f0h,004h,0f0h,004h,0fch	; 9a09  ................
	defb 004h,0f0h,01bh,0fch,081h,0f0h,007h,0fch,081h,0f0h,030h,0f0h,004h,0f0h,004h,0f1h	; 9a19  ..........0.....
	defb 004h,0f0h,01bh,0f1h,081h,0f0h,007h,0f1h,081h,0f0h,004h,0f0h,004h,0f1h,004h,0f0h	; 9a29  ................
	defb 01bh,0f1h,081h,0f0h,007h,0f1h,081h,0f0h,004h,0f0h,004h,0f1h,004h,0f0h,01bh,0f1h	; 9a39  ................
	defb 081h,0f0h,007h,0f1h,081h,0f0h,004h,0f0h,004h,0f1h,004h,0f0h,01bh,0f1h,081h,0f0h	; 9a49  ................
	defb 007h,0f1h,081h,0f0h,004h,0f0h,004h,0f1h,004h,0f0h,007h,0f1h,005h,0f6h,003h,0f1h	; 9a59  ................
	defb 005h,0f6h,007h,0f1h,081h,0f0h,007h,0f1h,081h,0f0h,004h,0f0h,004h,0f1h,004h,0f0h	; 9a69  ................
	defb 01bh,0f1h,081h,0f0h,007h,0f1h,081h,0f0h,004h,0f0h,004h,0f1h,004h,0f0h,008h,0f1h	; 9a79  ................
	defb 004h,0f6h,004h,0f1h,00bh,0f6h,081h,0f0h,007h,0f6h,081h,0f0h,004h,0f0h,004h,0f1h	; 9a89  ................
	defb 004h,0f0h,008h,0f1h,004h,0f6h,004h,0f1h,00bh,0f6h,081h,0f0h,007h,0f6h,081h,0f0h	; 9a99  ................
	defb 004h,0f0h,004h,0f1h,004h,0f0h,007h,0f1h,005h,0f6h,003h,0f1h,005h,0f6h,007h,0f1h	; 9aa9  ................
	defb 081h,0f0h,007h,0f1h,081h,0f0h,004h,0f0h,004h,0f1h,004h,0f0h,01bh,0f1h,081h,0f0h	; 9ab9  ................
	defb 007h,0f1h,081h,0f0h,004h,0f0h,004h,0f1h,004h,0f0h,007h,0f1h,005h,0f6h,003h,0f1h	; 9ac9  ................
	defb 005h,0f6h,007h,0f1h,081h,0f0h,007h,0f1h,081h,0f0h,004h,0f0h,004h,0f1h,004h,0f0h	; 9ad9  ................
	defb 01bh,0f1h,081h,0f0h,007h,0f1h,081h,0f0h,004h,0f0h,004h,0f1h,004h,0f0h,01bh,0f1h	; 9ae9  ................
	defb 081h,0f0h,007h,0f1h,081h,0f0h,004h,0f0h,004h,0fch,004h,0f0h,01bh,0fch,081h,0f0h	; 9af9  ................
	defb 007h,0fch,081h,0f0h,004h,0f0h,004h,0fch,004h,0f0h,01bh,0fch,081h,0f0h,007h,0fch	; 9b09  ................
	defb 081h,0f0h,004h,0f0h,004h,0f6h,004h,0f0h,007h,0f6h,005h,0fch,003h,0f6h,00ch,0fch	; 9b19  ................
	defb 081h,0f0h,007h,0fch,081h,0f0h,004h,0f0h,004h,0fch,004h,0f0h,01bh,0fch,081h,0f0h	; 9b29  ................
	defb 007h,0fch,081h,0f0h,004h,0f0h,004h,0fch,004h,0f0h,006h,0fch,006h,0f6h,002h,0fch	; 9b39  ................
	defb 006h,0f6h,007h,0fch,081h,0f0h,007h,0fch,081h,0f0h,004h,0f0h,004h,0fch,004h,0f0h	; 9b49  ................
	defb 01bh,0fch,081h,0f0h,007h,0fch,081h,0f0h,004h,0f0h,004h,0fch,004h,0f0h,01bh,0fch	; 9b59  ................
	defb 081h,0f0h,007h,0fch,081h,0f0h,004h,0f0h,004h,0fch,004h,0f0h,01bh,0fch,081h,0f0h	; 9b69  ................
	defb 007h,0fch,081h,0f0h,004h,0f0h,004h,0fch,004h,0f0h,00bh,0fch,081h,0f8h,00ch,0fch	; 9b79  ................
	defb 003h,0f8h,081h,0f0h,004h,0fch,003h,0f8h,081h,0f0h,004h,0f0h,004h,0f1h,004h,0f0h	; 9b89  ................
	defb 007h,0f1h,005h,0f8h,003h,0f1h,00ch,0f8h,081h,0f0h,007h,0f8h,081h,0f0h,004h,0f0h	; 9b99  ................
	defb 004h,0f1h,004h,0f0h,007h,0f1h,005h,0f8h,003h,0f1h,00ch,0f8h,081h,0f0h,007h,0f8h	; 9ba9  ................
	defb 081h,0f0h,004h,0f0h,004h,0f1h,004h,0f0h,007h,0f1h,005h,0f8h,003h,0f1h,00ch,0f8h	; 9bb9  ................
	defb 081h,0f0h,007h,0f8h,081h,0f0h,004h,0f0h,004h,0f1h,004h,0f0h,007h,0f1h,005h,0f8h	; 9bc9  ................
	defb 003h,0f1h,00ch,0f8h,081h,0f0h,007h,0f8h,081h,0f0h,004h,0f0h,004h,0f1h,004h,0f0h	; 9bd9  ................
	defb 007h,0f1h,005h,0f8h,003h,0f1h,00ch,0f8h,081h,0f0h,007h,0f8h,081h,0f0h,004h,0f0h	; 9be9  ................
	defb 004h,0f1h,004h,0f0h,007h,0f1h,005h,0f8h,003h,0f1h,00ch,0f8h,081h,0f0h,007h,0f8h	; 9bf9  ................
	defb 081h,0f0h,004h,0f0h,004h,0f1h,004h,0f0h,007h,0f1h,005h,0f8h,003h,0f1h,00ch,0f8h	; 9c09  ................
	defb 081h,0f0h,007h,0f8h,081h,0f0h,004h,0f0h,004h,0f1h,004h,0f0h,007h,0f1h,005h,0f8h	; 9c19  ................
	defb 003h,0f1h,00ch,0f8h,081h,0f0h,007h,0f8h,081h,0f0h,004h,0f0h,004h,0f1h,004h,0f0h	; 9c29  ................
	defb 007h,0f1h,005h,0f8h,003h,0f1h,00ch,0f8h,081h,0f0h,007h,0f8h,081h,0f0h,030h,000h	; 9c39  ..............0.
	defb 000h	; 9c49

; ======================================================================
; CODIGO 0x9c4a..0x9ca3  (89 bytes)
; ======================================================================


L_9C4A:
	di			;9c4a
	push hl			;9c4b
	push de			;9c4c
	push bc			;9c4d
	push af			;9c4e
	ld d,000h		;9c4f
	call L_9C5A		;9c51
	pop af			;9c54
	pop bc			;9c55
	pop de			;9c56
	pop hl			;9c57
	ei			;9c58
	ret			;9c59
L_9C5A:
	ld c,a			;9c5a
	ld b,002h		;9c5b
	ld hl,0e012h		;9c5d
	cp 08dh		;9c60
	jr c,L_9C6B		;9c62
	cp 08dh		;9c64
	jr c,L_9C71		;9c66
	inc b			;9c68
	jr L_9C71		;9c69
L_9C6B:
	and 03fh		;9c6b
	dec b			;9c6d
	ld hl,0e028h		;9c6e
L_9C71:
	dec d			;9c71
	jr z,L_9C7F		;9c72
	ld a,c			;9c74
	cp (hl)			;9c75
	ret c			;9c76
	ret z			;9c77
	cp 0cdh		;9c78
	jr c,L_9C7F		;9c7a
	and 07fh		;9c7c
	ld c,a			;9c7e
L_9C7F:
	and 03fh		;9c7f
	add a,a			;9c81
	ld de,09ca1h		;9c82
	call suma_a_a_de		;9c85
	dec hl			;9c88
	dec hl			;9c89
L_9C8A:
	ld (hl),001h		;9c8a
	inc hl			;9c8c
	ld (hl),001h		;9c8d
	inc hl			;9c8f
	ld (hl),c			;9c90
	inc hl			;9c91
	ld a,(de)			;9c92
	ld (hl),a			;9c93
	inc hl			;9c94
	inc de			;9c95
	ld a,(de)			;9c96
	ld (hl),a			;9c97
	ld a,006h		;9c98
	add a,l			;9c9a
	ld l,a			;9c9b
	ld (hl),000h		;9c9c
	inc hl			;9c9e
	inc de			;9c9f
	djnz L_9C8A		;9ca0
	ret			;9ca2

; ----------------------------------------------------------------------
; DATOS punteros_de_sonido: La tabla de sonidos que 0x9C82 indexa con `ld
;   de,0x9CA1` y el numero de sonido doblado. LA ENTRADA 0 CAE SOBRE EL
;   CODIGO: 0x9CA1 y 0x9CA2 son los dos ultimos bytes de la rutina de arriba
;   (0x10 0xE8 del `djnz` y el 0xC9 del `ret`), asi que el sonido 0 leeria
;   0xC9E8, fuera del cartucho. No se puede pedir, y no lo pide nadie. Las
;   entradas de la 1 a la 33 estan aqui, y las tres ultimas (31, 32 y 33)
;   apuntan al mismo sitio.
;   0x9ca3..0x9ce5  (66 bytes)
DATA_punteros_de_sonido:
	defb 0e6h,09ch	; 9ca3
	defb 002h,09dh	; 9ca5
	defb 0eah,09ch	; 9ca7
	defb 006h,09dh	; 9ca9
	defb 022h,09dh	; 9cab
	defb 03dh,09dh	; 9cad
	defb 035h,09dh	; 9caf
	defb 02ah,09dh	; 9cb1
	defb 045h,09dh	; 9cb3
	defb 01ah,09dh	; 9cb5
	defb 010h,09dh	; 9cb7
	defb 049h,09dh	; 9cb9
	defb 058h,09dh	; 9cbb
	defb 05fh,09dh	; 9cbd
	defb 066h,09dh	; 9cbf
	defb 06dh,09dh	; 9cc1
	defb 083h,09dh	; 9cc3
	defb 096h,09dh	; 9cc5
	defb 097h,09dh	; 9cc7
	defb 0b5h,09dh	; 9cc9
	defb 0d2h,09dh	; 9ccb
	defb 0dah,09dh	; 9ccd
	defb 0e9h,09dh	; 9ccf
	defb 0fbh,09dh	; 9cd1
	defb 006h,09eh	; 9cd3
	defb 025h,09eh	; 9cd5
	defb 04ch,09eh	; 9cd7
	defb 04dh,09eh	; 9cd9
	defb 069h,09eh	; 9cdb
	defb 077h,09eh	; 9cdd
	defb 0e5h,09ch	; 9cdf
	defb 0e5h,09ch	; 9ce1
	defb 0e5h,09ch	; 9ce3

; ----------------------------------------------------------------------
; DATOS datos_de_sonido: Los treinta y tres sonidos, uno detras de otro, tal
;   como los apunta la tabla de arriba.
;   0x9ce5..0x9e86  (417 bytes)
DATA_datos_de_sonido:
	defb 0ffh,021h,0e0h,0aah,0ffh,022h,0e0h,070h,0d0h,070h,021h,0c0h,070h,0b0h,070h,0a0h	; 9ce5  .!...".p.p!.p.p.
	defb 070h,023h,090h,070h,080h,070h,070h,070h,025h,000h,000h,0feh,003h,021h,0e0h,0eeh	; 9cf5  p#.p.ppp%....!..
	defb 0ffh,021h,0e0h,099h,0c0h,099h,0a0h,099h,070h,099h,0ffh,021h,0f1h,033h,0f1h,033h	; 9d05  .!......p..!.3.3
	defb 0d1h,033h,0c1h,033h,0ffh,023h,0e0h,099h,0e0h,088h,0e0h,077h,0ffh,021h,0e0h,0c9h	; 9d15  .3.3.#.....w.!..
	defb 0d0h,0c9h,0a0h,0c9h,0ffh,022h,0d0h,07fh,0c0h,07fh,0b0h,07fh,021h,000h,000h,0ffh	; 9d25  ....."......!...
	defb 022h,0e0h,0e3h,0d0h,0beh,0c0h,08fh,0ffh,021h,0e1h,008h,0d1h,008h,0c1h,008h,0ffh	; 9d35  ".......!.......
	defb 022h,0e0h,0c3h,0ffh,021h,0d2h,090h,0b2h,090h,092h,090h,0d1h,0d0h,0b1h,0d0h,091h	; 9d45  "...!...........
	defb 0d0h,0feh,005h,0d5h,0fch,0e2h,041h,041h,043h,0ffh,0d5h,0fch,0e2h,051h,051h,053h	; 9d55  ......AAC....QQS
	defb 0ffh,0d5h,0fch,0e2h,071h,071h,073h,0ffh,0d5h,0fdh,0e2h,051h,051h,041h,021h,011h	; 9d65  ....qqs....QQA!.
	defb 0e3h,0a1h,091h,071h,050h,040h,050h,040h,050h,040h,050h,040h,057h,0ffh,0d5h,0fch	; 9d75  ...qP@P@P@P@W...
	defb 0e2h,021h,021h,001h,0e3h,0a1h,091h,071h,051h,041h,0c7h,007h,0ffh,0ffh,0ffh,0ffh	; 9d85  .!!....qQA......
	defb 0ffh,0ffh,0d6h,0fdh,0e2h,000h,040h,070h,000h,040h,070h,040h,070h,0e1h,000h,0e2h	; 9d95  ......@p.@p@p...
	defb 040h,070h,0e1h,000h,0e2h,070h,0e1h,000h,040h,0e2h,070h,0e1h,000h,040h,077h,0ffh	; 9da5  @p...p..@.p..@w.
	defb 0d6h,0fch,0e3h,070h,0e2h,000h,040h,0e3h,070h,0e2h,000h,040h,000h,040h,070h,000h	; 9db5  ...p..@.p..@.@p.
	defb 040h,070h,040h,070h,0e1h,000h,0e2h,040h,070h,0e1h,000h,047h,0ffh,0d6h,0fch,0e1h	; 9dc5  @p@p...@p..G....
	defb 0c5h,0c5h,0c5h,007h,0ffh,0d5h,0fch,0e2h,041h,041h,071h,071h,021h,021h,051h,051h	; 9dd5  ........AAqq!!QQ
	defb 043h,023h,003h,0ffh,0d5h,0fbh,0e2h,001h,001h,041h,041h,0e3h,0b1h,0b1h,0e2h,021h	; 9de5  C#.......AA....!
	defb 021h,003h,0e3h,0b3h,073h,0ffh,0d5h,0fbh,0e3h,073h,003h,073h,003h,043h,023h,003h	; 9df5  !...s....s.s.C#.
	defb 0ffh,0d5h,0fch,0e1h,001h,001h,001h,0e2h,0b1h,091h,091h,091h,071h,051h,051h,051h	; 9e05  ............qQQQ
	defb 041h,027h,0b1h,0b1h,0b1h,091h,071h,071h,091h,0b1h,0e1h,003h,0e2h,073h,007h,0ffh	; 9e15  A'....qq.....s..
	defb 0d5h,0fbh,0e3h,001h,071h,041h,071h,001h,091h,051h,071h,001h,091h,051h,071h,0e4h	; 9e25  ....qAq..Qq..Qq.
	defb 0b1h,0e3h,071h,021h,071h,0e4h,0b1h,0e3h,071h,021h,071h,0e4h,0b1h,0e3h,071h,021h	; 9e35  ..q!q...q!q...q!
	defb 071h,001h,071h,041h,071h,007h,0ffh,0ffh,0d3h,0fch,0e2h,033h,031h,051h,073h,033h	; 9e45  q.qAq......31Qs3
	defb 083h,073h,057h,033h,031h,051h,073h,033h,083h,0e1h,003h,037h,0e2h,0a3h,0a1h,081h	; 9e55  .sW31Qs3...7....
	defb 073h,053h,035h,0ffh,0d3h,0fch,0e3h,033h,0cbh,053h,0cbh,033h,0cbh,003h,0cbh,0cfh	; 9e65  sS5....3.S.3....
	defb 035h,0ffh,0d3h,0fch,0e4h,0c7h,0a3h,0cbh,0a3h,0cbh,0a3h,0cbh,083h,0c3h,0afh,0c5h	; 9e75  5...............
	defb 0ffh	; 9e85

; ======================================================================
; CODIGO 0x9e86..0x9fd9  (339 bytes)
; ======================================================================


L_9E86:
	inc hl			;9e86
	ld a,(ix+009h)		;9e87
	inc a			;9e8a
	cp (hl)			;9e8b
	jp z,L_9F2E		;9e8c
	jr c,L_9E92		;9e8f
	dec a			;9e91
L_9E92:
	ex af,af'			;9e92
	ld a,(ix+002h)		;9e93
	push bc			;9e96
	ld d,001h		;9e97
	call L_9C5A		;9e99
	pop bc			;9e9c
	ex af,af'			;9e9d
	ld (ix+009h),a		;9e9e
	ret			;9ea1
L_9EA2:
	ret			;9ea2
L_9EA3:
	ld c,001h		;9ea3
	ld ix,0e010h		;9ea5
	exx			;9ea9
	ld b,003h		;9eaa
	ld de,0000bh		;9eac
L_9EAF:
	exx			;9eaf
	ld a,(ix+002h)		;9eb0
	or a			;9eb3
	call nz,L_9EBF		;9eb4
	inc c			;9eb7
	inc c			;9eb8
	exx			;9eb9
	add ix,de		;9eba
	djnz L_9EAF		;9ebc
	ret			;9ebe
L_9EBF:
	bit 6,a		;9ebf
	ld d,001h		;9ec1
	call z,L_9EA2		;9ec3
	ld a,(ix+002h)		;9ec6
	or a			;9ec9
	jp m,L_9F3E		;9eca
	dec (ix+000h)		;9ecd
	ret nz			;9ed0
L_9ED1:
	ld l,(ix+003h)		;9ed1
	ld h,(ix+004h)		;9ed4
	ld a,(hl)			;9ed7
	cp 0feh		;9ed8
	jr z,L_9E86		;9eda
	jr nc,L_9F2E		;9edc
	bit 7,(ix+002h)		;9ede
	jp nz,L_9F67		;9ee2
	and 0f0h		;9ee5
	cp 020h		;9ee7
	jr nz,L_9EF2		;9ee9
	ld a,(hl)			;9eeb
	and 00fh		;9eec
	ld (ix+001h),a		;9eee
	inc hl			;9ef1
L_9EF2:
	ld a,(hl)			;9ef2
	and 0f0h		;9ef3
	cp 010h		;9ef5
	jr nz,L_9F09		;9ef7
	ld a,(hl)			;9ef9
	and 01fh		;9efa
	ld e,a			;9efc
	ld a,006h		;9efd
	call 00093h		;9eff   ; BIOS WRTPSG - Writes data to PSG-register
	ld d,000h		;9f02
	call L_9EA2		;9f04
	inc hl			;9f07
	ld a,(hl)			;9f08
L_9F09:
	and 0f0h		;9f09
	ld b,a			;9f0b
	xor (hl)			;9f0c
	ld d,a			;9f0d
	inc hl			;9f0e
	ld e,(hl)			;9f0f
	inc hl			;9f10
	ld (ix+003h),l		;9f11
	ld (ix+004h),h		;9f14
	ex de,hl			;9f17
	call L_9FCE		;9f18
	ld a,b			;9f1b
	rrca			;9f1c
	rrca			;9f1d
	rrca			;9f1e
	rrca			;9f1f
L_9F20:
	ld h,a			;9f20
	ld a,(ix+001h)		;9f21
	ld (ix+000h),a		;9f24
	add a,002h		;9f27
	ld (ix+008h),a		;9f29
	jr L_9F5F		;9f2c
L_9F2E:
	xor a			;9f2e
	ld (ix+009h),a		;9f2f
	ld d,001h		;9f32
	call L_9EA2		;9f34
	xor a			;9f37
	ld (ix+002h),a		;9f38
	ld h,a			;9f3b
	jr L_9F5F		;9f3c
L_9F3E:
	dec (ix+000h)		;9f3e
	jr z,L_9ED1		;9f41
	dec (ix+008h)		;9f43
	ld a,(ix+008h)		;9f46
	cp (ix+000h)		;9f49
	jr nz,L_9F53		;9f4c
	cp 002h		;9f4e
	jr c,L_9F56		;9f50
	ret			;9f52
L_9F53:
	dec (ix+008h)		;9f53
L_9F56:
	ld a,(ix+007h)		;9f56
	dec a			;9f59
	ret m			;9f5a
	ld (ix+007h),a		;9f5b
	ld h,a			;9f5e
L_9F5F:
	ld a,c			;9f5f
	rrca			;9f60
	add a,088h		;9f61
	ld e,h			;9f63
	jp 00093h		;9f64   ; BIOS WRTPSG - Writes data to PSG-register
L_9F67:
	and 0f0h		;9f67
	cp 0d0h		;9f69
	ld a,(hl)			;9f6b
	jr nz,L_9F75		;9f6c
	and 00fh		;9f6e
	ld (ix+00ah),a		;9f70
	inc hl			;9f73
	ld a,(hl)			;9f74
L_9F75:
	cp 0f0h		;9f75
	jr c,L_9F80		;9f77
	and 00fh		;9f79
	ld (ix+006h),a		;9f7b
	inc hl			;9f7e
	ld a,(hl)			;9f7f
L_9F80:
	cp 0e0h		;9f80
	jr c,L_9F8B		;9f82
	and 00fh		;9f84
	ld (ix+005h),a		;9f86
	inc hl			;9f89
	ld a,(hl)			;9f8a
L_9F8B:
	and 00fh		;9f8b
	ld b,a			;9f8d
	ld a,(ix+00ah)		;9f8e
	jr z,L_9F98		;9f91
L_9F93:
	add a,(ix+00ah)		;9f93
	djnz L_9F93		;9f96
L_9F98:
	ld (ix+001h),a		;9f98
	ld a,(hl)			;9f9b
	inc hl			;9f9c
	ld (ix+003h),l		;9f9d
	ld (ix+004h),h		;9fa0
	and 0f0h		;9fa3
	rrca			;9fa5
	rrca			;9fa6
	rrca			;9fa7
	rrca			;9fa8
	ld b,a			;9fa9
	sub 00ch		;9faa
	ld (ix+007h),a		;9fac
	jr z,L_9FB7		;9faf
	ld a,(ix+006h)		;9fb1
	ld (ix+007h),a		;9fb4
L_9FB7:
	call L_9F20		;9fb7
	ld a,b			;9fba
	ld hl,09fd9h		;9fbb
	call suma_a_a_hl		;9fbe
	ld l,(hl)			;9fc1
	ld h,000h		;9fc2
	ld a,(ix+005h)		;9fc4
	or a			;9fc7
	jr z,L_9FCE		;9fc8
	ld b,a			;9fca
L_9FCB:
	add hl,hl			;9fcb
	djnz L_9FCB		;9fcc
L_9FCE:
	ld a,c			;9fce
	ld e,h			;9fcf
	call 00093h		;9fd0   ; BIOS WRTPSG - Writes data to PSG-register
	ld a,c			;9fd3
	dec a			;9fd4
	ld e,l			;9fd5
	jp 00093h		;9fd6   ; BIOS WRTPSG - Writes data to PSG-register

; ----------------------------------------------------------------------
; DATOS periodos_de_los_doce_semitonos: Los doce divisores de un semitono:
;   0x6A, 0x64, 0x5F, 0x59, 0x54, 0x50, 0x4B, 0x47, 0x43, 0x3F, 0x3C y 0x38.
;   0x9FBB los indexa con la nota y 0x9FCB los dobla tantas veces como diga
;   (IX+5), o sea que ese registro cuenta octavas HACIA ABAJO: cuanto mas se
;   dobla el periodo, mas grave suena. El resultado va al PSG con WRTPSG.
;   0x9fd9..0x9fe5  (12 bytes)
DATA_periodos_de_los_doce_semitonos:
	defb 06ah,064h,05fh,059h,054h,050h,04bh,047h,043h,03fh,03ch,038h	; 9fd9  jd_YTPKGC?<8

; ----------------------------------------------------------------------
; DATOS relleno_del_final: 8.219 bytes de 0xFF seguidos, de 0x9FE5 a 0xBFFF:
;   el banco entero de 8 KB de la pagina 2 mas 27 bytes. Ni una instruccion
;   del cartucho apunta ahi. El contenido acaba en 0x9FE4, veintisiete bytes
;   antes de la frontera de los 24 KB, o sea que el programa se escribio para
;   caber en 24 KB. Lo que el binario NO dice es que chip llevaba el cartucho:
;   0xFF es lo que devuelve tanto una EPROM sin grabar como un bus sin
;   conectar.
;   0x9fe5..0xc000  (8219 bytes)
DATA_relleno_del_final:
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; 9fe5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; 9ff5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a005  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a015  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a025  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a035  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a045  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a055  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a065  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a075  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a085  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a095  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a0a5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a0b5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a0c5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a0d5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a0e5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a0f5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a105  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a115  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a125  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a135  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a145  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a155  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a165  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a175  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a185  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a195  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a1a5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a1b5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a1c5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a1d5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a1e5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a1f5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a205  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a215  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a225  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a235  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a245  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a255  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a265  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a275  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a285  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a295  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a2a5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a2b5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a2c5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a2d5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a2e5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a2f5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a305  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a315  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a325  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a335  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a345  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a355  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a365  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a375  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a385  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a395  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a3a5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a3b5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a3c5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a3d5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a3e5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a3f5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a405  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a415  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a425  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a435  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a445  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a455  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a465  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a475  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a485  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a495  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a4a5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a4b5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a4c5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a4d5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a4e5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a4f5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a505  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a515  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a525  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a535  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a545  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a555  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a565  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a575  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a585  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a595  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a5a5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a5b5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a5c5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a5d5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a5e5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a5f5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a605  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a615  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a625  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a635  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a645  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a655  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a665  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a675  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a685  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a695  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a6a5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a6b5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a6c5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a6d5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a6e5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a6f5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a705  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a715  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a725  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a735  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a745  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a755  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a765  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a775  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a785  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a795  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a7a5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a7b5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a7c5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a7d5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a7e5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a7f5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a805  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a815  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a825  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a835  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a845  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a855  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a865  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a875  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a885  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a895  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a8a5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a8b5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a8c5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a8d5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a8e5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a8f5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a905  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a915  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a925  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a935  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a945  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a955  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a965  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a975  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a985  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a995  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a9a5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a9b5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a9c5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a9d5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a9e5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; a9f5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; aa05  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; aa15  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; aa25  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; aa35  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; aa45  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; aa55  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; aa65  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; aa75  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; aa85  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; aa95  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; aaa5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; aab5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; aac5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; aad5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; aae5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; aaf5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ab05  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ab15  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ab25  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ab35  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ab45  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ab55  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ab65  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ab75  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ab85  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ab95  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; aba5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; abb5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; abc5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; abd5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; abe5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; abf5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ac05  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ac15  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ac25  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ac35  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ac45  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ac55  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ac65  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ac75  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ac85  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ac95  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; aca5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; acb5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; acc5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; acd5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ace5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; acf5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ad05  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ad15  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ad25  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ad35  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ad45  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ad55  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ad65  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ad75  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ad85  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ad95  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ada5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; adb5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; adc5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; add5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ade5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; adf5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ae05  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ae15  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ae25  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ae35  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ae45  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ae55  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ae65  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ae75  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ae85  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ae95  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; aea5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; aeb5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; aec5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; aed5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; aee5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; aef5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; af05  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; af15  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; af25  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; af35  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; af45  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; af55  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; af65  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; af75  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; af85  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; af95  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; afa5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; afb5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; afc5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; afd5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; afe5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; aff5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b005  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b015  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b025  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b035  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b045  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b055  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b065  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b075  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b085  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b095  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b0a5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b0b5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b0c5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b0d5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b0e5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b0f5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b105  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b115  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b125  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b135  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b145  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b155  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b165  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b175  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b185  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b195  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b1a5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b1b5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b1c5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b1d5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b1e5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b1f5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b205  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b215  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b225  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b235  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b245  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b255  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b265  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b275  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b285  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b295  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b2a5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b2b5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b2c5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b2d5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b2e5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b2f5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b305  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b315  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b325  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b335  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b345  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b355  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b365  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b375  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b385  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b395  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b3a5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b3b5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b3c5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b3d5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b3e5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b3f5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b405  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b415  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b425  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b435  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b445  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b455  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b465  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b475  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b485  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b495  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b4a5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b4b5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b4c5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b4d5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b4e5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b4f5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b505  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b515  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b525  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b535  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b545  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b555  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b565  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b575  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b585  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b595  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b5a5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b5b5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b5c5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b5d5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b5e5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b5f5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b605  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b615  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b625  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b635  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b645  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b655  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b665  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b675  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b685  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b695  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b6a5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b6b5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b6c5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b6d5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b6e5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b6f5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b705  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b715  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b725  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b735  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b745  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b755  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b765  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b775  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b785  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b795  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b7a5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b7b5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b7c5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b7d5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b7e5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b7f5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b805  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b815  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b825  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b835  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b845  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b855  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b865  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b875  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b885  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b895  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b8a5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b8b5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b8c5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b8d5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b8e5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b8f5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b905  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b915  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b925  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b935  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b945  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b955  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b965  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b975  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b985  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b995  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b9a5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b9b5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b9c5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b9d5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b9e5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; b9f5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ba05  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ba15  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ba25  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ba35  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ba45  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ba55  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ba65  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ba75  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ba85  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; ba95  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; baa5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bab5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bac5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bad5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bae5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; baf5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bb05  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bb15  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bb25  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bb35  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bb45  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bb55  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bb65  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bb75  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bb85  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bb95  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bba5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bbb5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bbc5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bbd5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bbe5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bbf5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bc05  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bc15  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bc25  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bc35  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bc45  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bc55  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bc65  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bc75  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bc85  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bc95  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bca5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bcb5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bcc5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bcd5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bce5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bcf5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bd05  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bd15  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bd25  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bd35  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bd45  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bd55  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bd65  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bd75  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bd85  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bd95  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bda5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bdb5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bdc5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bdd5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bde5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bdf5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; be05  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; be15  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; be25  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; be35  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; be45  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; be55  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; be65  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; be75  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; be85  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; be95  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bea5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; beb5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bec5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bed5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bee5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bef5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bf05  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bf15  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bf25  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bf35  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bf45  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bf55  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bf65  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bf75  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bf85  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bf95  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bfa5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bfb5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bfc5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bfd5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bfe5  ................
	defb 0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh,0ffh	; bff5  ...........
