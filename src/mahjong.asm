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
	in a,(c)		;405e   ; el byte, del puerto que 0x470F dejo en C'
	exx			;4060
	ei			;4061   ; ei: 0x470F entro con di
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
	call mueve_el_sonido		;4075   ; el sonido va SIEMPRE, aunque el fotograma anterior no haya terminado
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
	call borra_el_marcador_y_las_variables		;4168   ; pone a cero el marcador y las 622 variables que le siguen
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
; CIERRA EL BUCLE DEL JUEGO: pone el estado a 0 y el submodo a 0. Medido en el demo con volcados en cada cambio de estado: se pasa por aqui en t=169,48, t=338,44 y t=509,00 s, o sea vueltas de 168,96 y 170,56 s. No todas duran lo mismo.
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
	set 0,(hl)		;41da   ; bit 0 de 0xE1A8: empieza el reparto; 0x4F25 lo baja cuando termina
	ld a,(0e04ch)		;41dc   ; el viento de la ronda
	or a			;41df
	jr z,L_41E8		;41e0   ; en la ronda del este, la espera sale de los honba
	ld hl,0e04dh		;41e2
	xor (hl)			;41e5   ; si el viento de la ronda es el del que reparte, la espera es la larga
	jr z,L_41F0		;41e6
L_41E8:
	ld a,(0e04bh)		;41e8
	inc a			;41eb
	cp 006h		;41ec   ; la espera son honba+1 fotogramas mientras no llegue a 6
	jr c,L_41FC		;41ee
L_41F0:
	ld a,040h		;41f0   ; y 64 fotogramas en cuanto llega. CORRIGE la lectura anterior, que tomaba este `cp 6` por el cierre de la partida: 0x41FC solo guarda A en 0xE004, que es la cuenta atras de fotogramas del estado
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
	call pide_un_sonido		;4236
	jr $-39		;4239   ; y al submodo 1
submodo_1_del_estado_11:
	call reparte_y_pinta_las_manos		;423b   ; SUBMODO 1 DEL ESTADO 11: reparte y espera a que termine el reparto
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
	call furiten_tras_el_riichi		;4276   ; bit 0 de 0xE1CD
L_4279:
	ld a,(0e1cdh)		;4279
	and 060h		;427c   ; los bits 5 y 6 de 0xE1CD son los que llevan a cantar jugada
	jr z,L_42A8		;427e
L_4280:
	call penaliza		;4280
	jr L_4288		;4283
L_4285:
	call cierra_la_mano_sin_ganador		;4285
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
	call evalua_y_decide_la_jugada		;42a8   ; salida normal: al submodo 3
	jp espera_32_y_avanza_de_submodo		;42ab

; ----------------------------------------------------------------------
; SUBMODO 3 DEL ESTADO 11: destapa la mano y prepara el recuento. Vuelve a pintar la mesa mientras baja el reloj, y cuando se agota monta las direcciones de la lista de nombres de jugada (0xE317 y 0xE319) y se va al submodo 4 o al 5 segun haya algo que pagar.
; ----------------------------------------------------------------------
submodo_3_del_estado_11:
	call pinta_una_franja_del_tapete		;42ae   ; sigue pintando la mesa hasta que el reloj se agote
	ret p			;42b1
	call monta_la_pantalla_del_recuento		;42b2
	ld a,(0e302h)		;42b5   ; bit 1 de 0xE302
	bit 1,a		;42b8
	jr nz,L_42C1		;42ba
	ld a,093h		;42bc   ; sonido 0x93
	call pide_un_sonido		;42be
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
	call canta_la_jugada		;430b
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
	call replica_patrones_y_colores_en_los_tercios		;43b3
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
	call pide_un_sonido		;43dd   ; sonido 0x99
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
	call borra_el_marcador_y_las_variables		;4405   ; borra el marcador y las 622 variables de detras
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
	call carga_las_fuentes_del_menu		;4425   ; pinta la mesa
	call suelta_el_texto_de_golpe		;4428   ; y el texto de las tres dificultades
	ld a,050h		;442b
	ld (0e004h),a		;442d   ; 80 fotogramas de parpadeo
	ld a,09ch		;4430   ; sonido 0x9C, el de empezar partida
	call pide_un_sonido		;4432
	jp avanza_de_submodo		;4435
L_4438:
	ld hl,0e004h		;4438   ; cada fotograma mientras dure el parpadeo
	dec (hl)			;443b
	jr z,cierra_la_pantalla_de_dificultad		;443c   ; agotado: por 0x4400 al estado 9
	ld a,(hl)			;443e
	and 008h		;443f   ; bit 3 del reloj: ocho fotogramas si y ocho no
	jp nz,suelta_el_texto_de_golpe		;4441   ; en los "si", el texto entero repintado
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

; ----------------------------------------------------------------------
; Lo que el estado 8 pinta antes del texto (0x4425): la fuente grande de 0x83B1 a los patrones 0x2600 (tiles 0xC0-0xEF) con colores 0x70; la misma fuente en blanco en los tiles 0x10-0x3F y replicada en los tres tercios (0x4674); los patrones de 0x85D5 a 0x2500 (tiles 0xA0-0xF5); y por ultimo 752 bytes de color 0xC0 desde 0x0500, los tiles 0xA0-0xFD, que pisan el 0x70 de antes: en el menu la fuente grande sale con el color 0xC0.
; ----------------------------------------------------------------------
carga_las_fuentes_del_menu:
	ld hl,083b1h		;4472   ; la fuente grande, 384 bytes
	ld de,06600h		;4475   ; a los patrones 0x2600: tiles 0xC0-0xEF
	ld bc,00180h		;4478
	call copia_a_la_vram		;447b
	ld de,l4600h		;447e   ; sus colores, 0x0600
	ld bc,00180h		;4481
	ld a,070h		;4484   ; 0x70
	call rellena_la_vram		;4486
	call carga_la_fuente_grande_en_los_tiles_10_3f		;4489   ; y la misma fuente en blanco en los tiles 0x10-0x3F, replicada
	ld hl,085d5h		;448c   ; los patrones del titulo, a 0x2500
	call pinta_lista_formato_b		;448f
	ld de,04500h		;4492   ; colores desde 0x0500: tiles 0xA0-0xFD
	ld bc,002f0h		;4495   ; 752 bytes
	ld a,0c0h		;4498   ; 0xC0
L_449A:
	call escribe_en_vram		;449a   ; byte a byte, 240 y luego dos vueltas de 256
	inc de			;449d
	dec c			;449e
	jr nz,L_449A		;449f
	djnz L_449A		;44a1
	ret			;44a3

; ----------------------------------------------------------------------
; Pone a cero 622 bytes desde 0xE047: el marcador del 1 y todas las variables de la partida que vienen detras, hasta 0xE2B4. El del 2 (0xE044) no entra, pero su byte bajo siempre vale cero porque los puntos van de cien en cien. Lo llaman 0x4168 (arranca el demo) y 0x4405 (sale la pantalla de dificultad).
; ----------------------------------------------------------------------
borra_el_marcador_y_las_variables:
	ld hl,0e047h		;44a4
	ld bc,0026eh		;44a7   ; 622 bytes
	ld d,h			;44aa
	ld e,l			;44ab
	inc e			;44ac
	ld (hl),000h		;44ad   ; a cero
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

; ----------------------------------------------------------------------
; La cifra baja de (HL) como tile 0x10-0x19, salvo el cero, que va en blanco (tile 0x01). Es la cifra de las centenas de los fu (0x735C): no se pinta el cero de delante.
; ----------------------------------------------------------------------
pinta_la_cifra_baja_o_blanco:
	ld a,(hl)			;459c
	and 00fh		;459d   ; la cifra baja
	or 010h		;459f   ; tile 0x10 + cifra
	cp 010h		;45a1   ; el cero
	jr nz,L_45A7		;45a3
	ld a,001h		;45a5   ; en blanco
L_45A7:
	jp escribe_en_vram		;45a7

; ----------------------------------------------------------------------
; Las dieciocho lineas del texto (0x45B4) de una vez, no una por cuadro: repite mientras vuelva con acarreo. Al llegar a la linea 18, 0x45DA pinta ademas los rotulos del menu de 0x8531 y sigue devolviendo acarreo hasta la vuelta 52, que son 34 vueltas vacias. Lo llama 0x4428, la pantalla de dificultad.
; ----------------------------------------------------------------------
suelta_el_texto_de_golpe:
	xor a			;45aa
	ld (0e00ah),a		;45ab   ; la linea, a cero
L_45AE:
	call suelta_una_linea_de_texto		;45ae
	jr c,L_45AE		;45b1   ; mientras queden
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
	push af			;45da   ; de la 18 en adelante
	ld hl,08531h		;45db
	call z,L_409D		;45de   ; justo en la 18, los rotulos del menu
	pop af			;45e1
	cp 034h		;45e2   ; acarreo hasta la 52: vueltas vacias
	ret			;45e4

; ----------------------------------------------------------------------
; Resta A de DE. La contraria de 0x4068, para las rutinas que suben por la VRAM en vez de bajar.
; ----------------------------------------------------------------------
resta_a_de_de:
	ld b,a			;45e5
	ld a,e			;45e6
	sub b			;45e7
	ld e,a			;45e8
	ret nc			;45e9   ; sin acarreo D no cambia
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
	dec bc			;4600   ; BC bytes
	ld a,b			;4601
	or c			;4602
	jr nz,L_45FA		;4603
	ei			;4605
	ret			;4606
L_4607:
	ld a,(hl)			;4607
	inc hl			;4608
	jr L_45F9		;4609

; ----------------------------------------------------------------------
; BC bytes desde HL a la VRAM que apunta DE, por el puerto de datos que 0x470F dejo en C'. Es la copia de bloques del cartucho: sprites, fuentes, atributos.
; ----------------------------------------------------------------------
copia_a_la_vram:
	di			;460b
	call prepara_escritura_vram		;460c   ; arma la direccion y deja el puerto en C'
L_460F:
	ld a,(hl)			;460f
	exx			;4610
	out (c),a		;4611   ; el byte, al puerto
	exx			;4613
	inc hl			;4614
	dec bc			;4615
	ld a,b			;4616
	or c			;4617   ; hasta que BC se agote
	jr nz,L_460F		;4618
	ei			;461a
	ret			;461b

; ----------------------------------------------------------------------
; Al reves que 0x460B: BC bytes de la VRAM DE a HL. El push/pop de HL entre lecturas es la espera que pide el VDP. Lo usa 0x7066 para traerse los seis tiles de una ficha.
; ----------------------------------------------------------------------
copia_de_la_vram:
	di			;461c
	call prepara_lectura_vram		;461d
L_4620:
	exx			;4620
	in a,(c)		;4621   ; el byte, del puerto
	exx			;4623
	ld (hl),a			;4624
	inc hl			;4625
	dec bc			;4626
	ld a,b			;4627
	or c			;4628
	push hl			;4629   ; push/pop: la espera entre lecturas
	pop hl			;462a
	jr nz,L_4620		;462b
	ei			;462d
	ret			;462e

; ----------------------------------------------------------------------
; Como 0x461C pero para colores: cada byte cuyo nibble bajo -el fondo- sea cero se cambia a 1, negro. Lo usa 0x707E para traerse los colores de una ficha sin que el fondo se vea a traves.
; ----------------------------------------------------------------------
copia_de_la_vram_sin_fondo_transparente:
	call prepara_lectura_vram		;462f
L_4632:
	exx			;4632
	in a,(c)		;4633
	exx			;4635
	ld d,a			;4636
	and 00fh		;4637   ; el fondo, nibble bajo
	jr nz,L_463C		;4639
	inc d			;463b   ; transparente: a negro
L_463C:
	ld a,d			;463c
	ld (hl),a			;463d   ; el byte, ya corregido, a la RAM
	inc hl			;463e
	dec bc			;463f
	ld a,b			;4640
	or c			;4641   ; hasta que BC se agote
	push hl			;4642
	pop hl			;4643   ; push/pop: la espera entre lecturas
	jr nz,L_4632		;4644
	ei			;4646
	ret			;4647

; ----------------------------------------------------------------------
; BC bytes de la VRAM DE a la VRAM HL, byte a byte, leyendo y escribiendo con las dos rutinas de 0x405A y 0x4051.
; ----------------------------------------------------------------------
copia_dentro_de_la_vram:
	call lee_de_vram		;4648   ; lee uno
	ex de,hl			;464b
	call escribe_en_vram		;464c   ; y lo escribe
	ex de,hl			;464f
	inc hl			;4650
	inc de			;4651
	dec bc			;4652
	ld a,c			;4653
	or b			;4654
	jr nz,copia_dentro_de_la_vram		;4655
	ret			;4657

; ----------------------------------------------------------------------
; Copia los 2 KB de patrones del primer tercio (0x2000) al segundo (0x2800) y del segundo al tercero (0x3000).
; ----------------------------------------------------------------------
replica_los_patrones_en_los_tercios:
	ld de,02000h		;4658
	ld hl,02800h		;465b
L_465E:
	ld bc,00800h		;465e   ; 2 KB
	call copia_dentro_de_la_vram		;4661
	ld bc,00800h		;4664   ; y otros 2 KB al tercio siguiente
	jr copia_dentro_de_la_vram		;4667

; ----------------------------------------------------------------------
; Los patrones por 0x4658 y luego los colores: 0x0000 a 0x0800 y a 0x1000. Lo llaman 0x43B3, 0x468C y 0x4B72.
; ----------------------------------------------------------------------
replica_patrones_y_colores_en_los_tercios:
	call replica_los_patrones_en_los_tercios		;4669
	ld de,00000h		;466c   ; ahora los colores
	ld hl,00800h		;466f
	jr L_465E		;4672

; ----------------------------------------------------------------------
; La fuente grande de 0x83B1 en los tiles 0x10-0x3F: sus 384 bytes de color a 0x0080 con el byte A (0xF0 desde aqui, blanco sobre transparente; 0xF1 desde 0x4C51, blanco sobre negro) y sus patrones a 0x2080, y luego replica los tres tercios. Es la fuente con la que se escriben los marcadores y los contadores.
; ----------------------------------------------------------------------
carga_la_fuente_grande_en_los_tiles_10_3f:
	ld a,0f0h		;4674   ; 0xF0: blanco sobre transparente
L_4676:
	ld de,00080h		;4676   ; colores desde 0x0080, tiles 0x10-0x3F
	ld bc,00180h		;4679
	call rellena_la_vram		;467c
	ld hl,083b1h		;467f   ; la fuente
	ld a,020h		;4682   ; a 0x2080: los mismos tiles, patrones
	add a,d			;4684
	ld d,a			;4685
	ld bc,00180h		;4686
	call copia_a_la_vram		;4689
	jp replica_patrones_y_colores_en_los_tercios		;468c   ; y a los tres tercios

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
	call descomprime_para_el_volcado_girado		;46b7   ; rellena el trozo de 0xE2E5 antes de volcarlo
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
	call descomprime_para_el_volcado_girado		;46e2   ; rellena el trozo de 0xE2E5 antes de volcar la columna
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
	ld de,06000h		;46fa   ; 0x6000, que en la VRAM de 16 KB es 0x2000: los patrones
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
; Devuelve en A el primer tile del dibujo de la ficha cuyo codigo entra en A, leyendo la tabla de 0x4735: una fila por palo y otra para los honores, todas bajando de seis en seis porque cada ficha son seis tiles. Quien pinta fichas (0x6F74, 0x7053) pasa por aqui.
; ----------------------------------------------------------------------
primer_tile_de_la_ficha:
	push hl			;472b
	ld hl,04735h		;472c
	call suma_a_a_hl		;472f   ; indexa la tabla con A
	ld a,(hl)			;4732
	pop hl			;4733
	ret			;4734

; ----------------------------------------------------------------------
; DATOS primer_tile_de_cada_ficha: Cuatro filas de 16 bytes con diez valores
;   utiles cada una, que bajan de seis en seis: 0xFA..0xC4, 0x88..0x58,
;   0xBE..0x8E y 0x52..0x28. La lee 0x472C indexando con el CODIGO DE FICHA
;   (palo en el nibble alto, numero en el bajo), asi que cada fila es un palo
;   -0, 1, 2- y la cuarta son los honores. El valor es el PRIMER TILE del
;   dibujo de la ficha, que son seis tiles seguidos, dos de ancho por tres de
;   alto (0x6F72); por eso bajan de seis en seis. En la fila de los honores el
;   indice 8 (codigo 0x38) es el dorso de la ficha y el 9 (0x39) el hueco
;   vacio. CORRIGE la lectura anterior, que las tomaba por cuatro
;   orientaciones de la mesa.
;   0x4735..0x476f  (58 bytes)
DATA_primer_tile_de_cada_ficha:
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
	call pide_un_sonido		;4788
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



; ----------------------------------------------------------------------
; EL FURITEN DE RIICHI: cruza las esperas del 1 (0xE1F5) contra los descartes de la maquina POSTERIORES al riichi del 1. El primero es el numero 0xE1CC (el descarte con el que declaro), uno mas si reparte el 2; la cuenta es lo que la maquina ha descartado desde entonces, y en una mano sin ganador (bit 2 de 0xE302) uno mas. Si no hay ninguno, nada. Si hay coincidencia, 0x4865 vuelve aqui: bit 5 de 0xE1CD y 0xE1AC = 1, el castigo; si no la hay, 0x486B se come el retorno y sale directo al que llamo. El `ld hl,0xE233` del principio no se usa: 0x481E lo pisa. Lo llaman 0x76CC (fin de mano) y, con las dificultades 2 y 3, el furiten del turno.
; ----------------------------------------------------------------------
furiten_tras_el_riichi:
	ld hl,0e233h		;47fb   ; no se usa: 0x481E pisa HL
	ld de,0e172h		;47fe   ; el rio de la maquina
	ld a,(0e1cch)		;4801   ; desde el descarte del riichi
	ld c,a			;4804
	ld a,(0e04dh)		;4805
	rra			;4808   ; reparte el 2: uno mas
	jr nc,L_480C		;4809
	inc c			;480b
L_480C:
	ld a,c			;480c
	call suma_a_a_de		;480d   ; el primer descarte posterior
	ld a,(0e1bfh)		;4810
	sub c			;4813   ; cuantos lleva desde entonces
	ret z			;4814   ; ninguno: nada que cruzar
	ld c,a			;4815
	ld a,(0e302h)		;4816
	bit 2,a		;4819   ; bit 2 de 0xE302: sin ganador, uno mas
	jr z,L_481E		;481b
	inc c			;481d
L_481E:
	ld hl,0e1f5h		;481e   ; las esperas del 1
	ld (0e203h),de		;4821   ; contra esa parte del rio
	call L_4865		;4825   ; el cruce: si no encuentra nada, sale dos niveles arriba
	ld hl,0e1cdh		;4828
	set 5,(hl)		;482b   ; bit 5 de 0xE1CD: FURITEN DE RIICHI
	ld hl,0e1ach		;482d
	ld (hl),001h		;4830   ; 0xE1AC = 1: el castigo
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
	call pinta_una_ficha		;48bf
	ld a,001h		;48c2
	call pide_un_sonido		;48c4   ; sonido 1 en cada paso: el tecleo del recuento
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



; ----------------------------------------------------------------------
; LA AYUDA DE LA DIFICULTAD 1: con la tecla 1 (bit 0 de 0xE040) y el 1 en riichi (bit 0 de 0xE1CD), devuelve acarreo si la ficha A es una de sus esperas (0xE1F5, hasta el cero final). Lo usan 0x52C0 (no le deja descartar una ficha con la que gana) y 0x55F9 (le avisa de que el descarte de la maquina le da ron). En las otras dificultades nunca avisa.
; ----------------------------------------------------------------------
avisa_si_es_espera_en_amachua:
	ld c,a			;49c6
	ld a,(0e040h)		;49c7
	rra			;49ca   ; bit 0 de 0xE040: solo con la tecla 1
	ret nc			;49cb
	ld a,(0e1cdh)		;49cc
	rra			;49cf   ; bit 0 de 0xE1CD: y en riichi
	ret nc			;49d0
	ld a,c			;49d1
	ld hl,0e1f5h		;49d2
	ld b,00dh		;49d5   ; trece esperas como mucho
L_49D7:
	inc (hl)			;49d7
	dec (hl)			;49d8
	jr z,L_49E1		;49d9   ; el cero del final: no esta
	cp (hl)			;49db
	jr z,L_49E3		;49dc   ; esta
	inc hl			;49de
	djnz L_49D7		;49df
L_49E1:
	or a			;49e1   ; sin acarreo: no
	ret			;49e2
L_49E3:
	scf			;49e3   ; acarreo: es una espera
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
	call pide_un_sonido		;49f1
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
	call pide_un_sonido		;4adc
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
; Prepara la caida del rotulo del principio: diecisiete pasos en 0xE00A, la altura a cero en 0xE00E, los patrones del bloque de 0x4BB0 descomprimidos en 0x2200 y los colores de al lado rellenos a 0xF0. Cada paso lo da 0x4B75.
; ----------------------------------------------------------------------
monta_el_rotulo_que_baja:
	ld a,011h		;4b50   ; diecisiete pasos de caida
	ld (0e00ah),a		;4b52
	ld hl,00000h		;4b55   ; y empieza arriba del todo
	ld (0e00eh),hl		;4b58
	ld hl,04bb0h		;4b5b   ; los patrones, en formato B sin cabecera de destino
	ld de,06200h		;4b5e
	call L_4693		;4b61
	ld de,00200h		;4b64   ; y los colores del mismo tercio, con el byte fijo 0xF0
	ld bc,000d0h		;4b67
	ld a,0f0h		;4b6a
	call rellena_la_vram		;4b6c
	call replica_los_patrones_en_los_tercios		;4b6f
	jp replica_patrones_y_colores_en_los_tercios		;4b72

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
; DATOS patrones_del_menu_200: Formato B SIN cabecera de destino: 0x4B5B llama
;   a la entrada 0x4693 (tres bytes dentro de 0x468F, saltandose el `ld
;   e,(hl)/ld d,(hl)` que lee el destino) con DE=0x6200 puesto a mano, o sea
;   que este bloque son solo ORDENES, sin los dos bytes de VRAM delante.
;   Descomprime a 208 bytes en los patrones 0x2200. Justo detras, 0x4B64
;   rellena los colores 0x0200 con el byte fijo 0xF0 repetido 208 veces (`ld
;   de,0x0200 / ld bc,0xD0 / ld a,0xF0 / call 0x45F6`): mismo tercio, mismo
;   tamano, color fijo en vez de comprimido.
;   0x4bb0..0x4c43  (147 bytes)
DATA_patrones_del_menu_200:
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
	call pinta_el_tablero		;4c66
	call pinta_la_barra_de_arriba		;4c69
	call pinta_el_marcador_de_la_mano		;4c6c
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
	call pide_un_sonido		;4ca8
	xor a			;4cab
	ld (0e127h),a		;4cac   ; la marca se gasta al sonar
L_4CAF:
	ld hl,04cf2h		;4caf
	call pinta_lista_formato_b		;4cb2
	jp pinta_las_dos_manos_del_tablero		;4cb5

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



; ----------------------------------------------------------------------
; EL SUBMODO 1 DEL ESTADO 11, cada cuadro: una fase del reparto (0x4D91) y las dos manos pintadas. Mientras el bit 0 de 0xE1A8 siga puesto -reparto en curso- se vuelve; al bajar, la mano de la maquina pasa de 0xE21C, donde la armo 0x78CE, a 0xE14C, su sitio de juego.
; ----------------------------------------------------------------------
reparte_y_pinta_las_manos:
	call despacha_el_reparto		;4d58   ; una fase del reparto
	call pinta_la_mano_del_jugador_1		;4d5b
	call pinta_la_mano_del_jugador_2		;4d5e
	ld a,(0e1a8h)		;4d61
	rra			;4d64   ; bit 0 de 0xE1A8: reparto en curso
	ret c			;4d65
	ld hl,0e21ch		;4d66   ; terminado: la mano de la maquina, de 0xE21C a 0xE14C
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
	call construye_la_mano_de_la_maquina		;4da6
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
	call pide_un_sonido		;4dfe   ; sonido 7: el golpe de la ficha en la mesa
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
	call pide_un_sonido		;4e84   ; sonido 1: la ficha colocandose
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
	call pinta_los_indicadores_y_la_marca_a		;4ed0
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
	rra			;4f67   ; bit 0 de 0xE1A8: reparto en curso
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
	call carga_las_variables_del_que_juega		;5004   ; y a jugar
	ld a,(0e206h)		;5007
	rra			;500a
	jr c,L_5013		;500b
	call mueve_el_cursor_del_menu		;500d
	call elige_en_el_menu		;5010
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
	jp z,espera_y_cierra_la_mano		;502c
	or a			;502f
	jp nz,la_maquina_decide_si_canta		;5030
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
	call analiza_la_mano		;505b
	ld a,(0e302h)		;505e
	rra			;5061   ; bit 0 de 0xE302
	jr c,L_50A4		;5062
	ld a,(0e206h)		;5064
	rra			;5067
	jp c,espera_y_cierra_la_mano		;5068
	ld hl,0e1cch		;506b
	ld a,(0e1beh)		;506e
	inc a			;5071
	cp (hl)			;5072   ; comparar con 0xE1CC
	jr nz,L_5079		;5073
	xor a			;5075
	ld (0e1cdh),a		;5076   ; no cuadra: se olvida lo apuntado
L_5079:
	ld a,040h		;5079   ; 0x40: gano el 1; se va a destapar la mano de la maquina
	ld (0e1a9h),a		;507b   ; 0x40 en 0xE1A9
	ld a,(0e1beh)		;507e
	cp 00ah		;5081   ; diez fichas
	jp nc,destapa_la_mano_de_la_maquina		;5083   ; con diez o mas se destapa tal cual
	call sortea_el_descarte_de_la_maquina		;5086   ; con menos, se sortea una ficha
	ld a,(0e208h)		;5089
	push af			;508c
	dec a			;508d
	ld hl,0e14ch		;508e
	call suma_a_a_hl		;5091
	ld a,(0e22bh)		;5094
	ld (hl),a			;5097   ; que pisa el penultimo hueco de la mano de la maquina antes de destaparla
	pop af			;5098
	inc a			;5099
	ld b,a			;509a
	ld hl,0e14ch		;509b
	call L_4F9B		;509e   ; y se reordena la mano con lo nuevo
	jp destapa_la_mano_de_la_maquina		;50a1
L_50A4:
	call limpia_el_analisis		;50a4

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
	jp nc,fase_1_elige_el_descarte		;50bf
	rra			;50c2   ; bit 2
	jp nc,fase_2_riichi_y_furiten		;50c3
	rra			;50c6   ; bit 3
	jp nc,fase_3_ordena_la_mano		;50c7
	rra			;50ca   ; bit 4
	jp nc,fase_4_el_descarte_al_rio		;50cb
	rra			;50ce   ; bit 5
	jp nc,fase_5_roba_la_maquina		;50cf
	rra			;50d2   ; bit 6
	jp nc,fase_6_descarta_la_maquina		;50d3
	rra			;50d6   ; bit 7
	jp nc,fase_7_tras_el_descarte_de_la_maquina		;50d7
	jp agota_la_mano		;50da   ; los ocho puestos

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
	ld (0e1d1h),a		;5136   ; 0xE1D1 = 1 si reparte el 1: el que reparte empieza con la decimocuarta ficha en la mano, como recien robada; 0xE22A es lo mismo para el 2
	or a			;5139
	jr nz,prepara_la_mesa_de_la_mano		;513a
	ld a,03fh		;513c
	ld (0e1aah),a		;513e   ; 0x3F: las seis fases de la mano por hacer
	call sortea_hasta_que_no_sea_espera		;5141

; ----------------------------------------------------------------------
; La segunda mitad del arranque de la mano (cae desde 0x50DD): borra los 118 bytes de 0xE240-0xE2B5 -las figuras guardadas de los dos jugadores-, carga los 22 atributos de sprite de 0x51F4 en 0xE0A8 (los dos del cursor, los palos de riichi, la marca de la robada), manda los patrones de sprite de 0x524C a la VRAM, esconde los sprites 4 a 21 (Y = 0xE0) escribiendo 0x5204 en 0x3B10, pone el reloj 0xE052 a cero y da por hecha la fase 0 (bit 0 de 0xE1AA). Si reparte el 2, 0x513E ya habia puesto 0xE1AA = 0x3F, asi que la fase siguiente es la 6: la maquina descarta primero.
; ----------------------------------------------------------------------
prepara_la_mesa_de_la_mano:
	ld hl,0e240h		;5144   ; 0xE240-0xE2B5: las figuras guardadas de los dos, a cero
	ld de,0e241h		;5147
	ld (hl),000h		;514a
	ld bc,00076h		;514c   ; 118 bytes de trabajo a cero
	ldir		;514f
	ld hl,051f4h		;5151   ; los 22 atributos de sprite de 0x51F4, a 0xE0A8
	ld de,0e0a8h		;5154
	ld bc,00058h		;5157
	ldir		;515a
	ld hl,0524ch		;515c
	call pinta_lista_formato_b		;515f   ; los patrones de sprite, a 0x1800
	ld hl,05204h		;5162   ; los sprites 4 a 21 escondidos en Y = 0xE0, a 0x3B10
	ld de,03b10h		;5165
	ld bc,00048h		;5168
	call copia_a_la_vram		;516b
	ld hl,00000h		;516e   ; el reloj de la fase, a cero
	ld (0e052h),hl		;5171
	ld hl,0e1aah		;5174
	set 0,(hl)		;5177   ; fase 0 hecha
	ret			;5179

; ----------------------------------------------------------------------
; EL CAMBIO DE JUGADOR, ida: copia a las variables COMPARTIDAS del turno las del jugador que toca. Primero siempre las del 1 (cursor 0xE1C2 a 0xE209, hueco de la robada 0xE1C3 a 0xE20A, ultimo hueco 0xE1CE a 0xE20B, marca de tsumo 0xE1D1 a 0xE22C, riichi y esperas 0xE1CD a 0xE33E) y, si el bit 0 de 0xE206 dice que juega el 2, encima las suyas (0xE207, 0xE208, 0xE20C, 0xE22A, 0xE1AE). Asi el menu, las llamadas y el motor trabajan con una sola copia sin saber de quien es. La vuelta es 0x51BC. Lo llaman 0x5004 (cada turno) y 0x582E (la maquina usando el menu).
; ----------------------------------------------------------------------
carga_las_variables_del_que_juega:
	ld a,(0e1c2h)		;517a   ; el cursor del 1
	ld (0e209h),a		;517d
	ld a,(0e1c3h)		;5180   ; el hueco de su ficha robada
	ld (0e20ah),a		;5183
	ld a,(0e1ceh)		;5186   ; el ultimo hueco antes de las figuras
	ld (0e20bh),a		;5189
	ld a,(0e1d1h)		;518c   ; su marca de tsumo
	ld (0e22ch),a		;518f
	ld a,(0e1cdh)		;5192   ; su riichi y sus esperas
	ld (0e33eh),a		;5195
	ld a,(0e206h)		;5198
	rra			;519b   ; bit 0 de 0xE206: juega el 2
	ret nc			;519c
	ld a,(0e207h)		;519d   ; y si es el 2, las suyas encima
	ld (0e209h),a		;51a0
	ld a,(0e208h)		;51a3
	ld (0e20ah),a		;51a6
	ld a,(0e20ch)		;51a9
	ld (0e20bh),a		;51ac
	ld a,(0e22ah)		;51af   ; la marca de tsumo del 2, 0xE22A
	ld (0e22ch),a		;51b2
	ld a,(0e1aeh)		;51b5   ; y su riichi, 0xE1AE
	ld (0e33eh),a		;51b8
	ret			;51bb

; ----------------------------------------------------------------------
; EL CAMBIO DE JUGADOR, vuelta: devuelve las variables compartidas a las del jugador que toca, al reves que 0x517A: al 1 (0x51C2) o al 2 (0x51DB). Lo llaman 0x5287, 0x55D3 y 0x5834, siempre justo despues de 0x663C, el despachador de llamadas, que es quien las cambia.
; ----------------------------------------------------------------------
guarda_las_variables_del_que_juega:
	ld a,(0e206h)		;51bc
	rra			;51bf   ; bit 0 de 0xE206: juega el 2
	jr c,L_51DB		;51c0
	ld a,(0e209h)		;51c2   ; al 1: cursor, hueco de la robada, ultimo hueco y riichi/esperas
	ld (0e1c2h),a		;51c5
	ld a,(0e20ah)		;51c8
	ld (0e1c3h),a		;51cb
	ld a,(0e20bh)		;51ce
	ld (0e1ceh),a		;51d1
	ld a,(0e33eh)		;51d4
	ld (0e1cdh),a		;51d7
	ret			;51da
L_51DB:
	ld a,(0e209h)		;51db   ; al 2: lo mismo en las suyas
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



; ----------------------------------------------------------------------
; FASE 1 DEL TURNO DEL JUGADOR 1: ELEGIR EL DESCARTE (bit 1 de 0xE1AA). Cada cuadro: el dibujo 1 del rincon, el despachador de llamadas de 0x663C por si ha pedido riichi, pon, chi o kan en el menu, y la vuelta de las variables. Si 0xE1AA sale a 0xFF de ahi es que ha hecho kan: roba la de reposicion por 0x5603. En las dificultades 2 y 3 (bits 1 y 2 de 0xE040) corre un reloj: a los 420 cuadros suena el 8 y a los 600 el descarte sale solo, el que tenga el cursor. Si no, espera al flanco de la tecla (bit 0 de 0xE23A). Con la ficha elegida (0xE1BC = la del cursor 0xE1C2), 0x49C6 puede avisar -dificultad 1, en riichi, la ficha es una espera- y entonces el dibujo 2 y no pasa; si no, bit 1 puesto y a la fase 2. Mientras tanto 0x52D1 mueve el cursor.
; ----------------------------------------------------------------------
fase_1_elige_el_descarte:
	ld a,001h		;527f   ; el dibujo 1 del rincon
	call pinta_uno_de_los_tres_dibujos		;5281
	call despacha_la_llamada		;5284   ; riichi, pon, chi o kan, si los ha pedido en el menu
	call guarda_las_variables_del_que_juega		;5287   ; y las variables de vuelta a las del 1
	ld a,(0e1aah)		;528a
	cp 0ffh		;528d   ; 0xFF: ha hecho kan, roba la de reposicion
	jp z,roba_el_jugador_1		;528f
	ld a,(0e040h)		;5292
	rra			;5295
	rra			;5296   ; bits 1 y 2 de 0xE040: dificultades 2 y 3, con reloj
	jr nc,L_52AD		;5297
	ld hl,001a4h		;5299   ; 420 cuadros
	call resta_el_reloj_a_hl		;529c
	jr nc,L_52AD		;529f   ; aun no
	ld a,008h		;52a1
	call pide_un_sonido		;52a3   ; sonido 8: el aviso
	ld hl,00258h		;52a6   ; 600 cuadros: el descarte sale solo
	sbc hl,de		;52a9
	jr c,L_52B3		;52ab
L_52AD:
	ld a,(0e23ah)		;52ad
	rra			;52b0   ; bit 0 de 0xE23A: flanco de la tecla
	jr nc,mueve_el_cursor_de_la_mano		;52b1
L_52B3:
	ld a,(0e1c2h)		;52b3   ; la ficha del cursor
	ld hl,0e13ah		;52b6
	call suma_a_a_hl		;52b9
	ld a,(hl)			;52bc
	ld (0e1bch),a		;52bd   ; 0xE1BC = la ficha elegida
	call avisa_si_es_espera_en_amachua		;52c0   ; el aviso de la dificultad 1: es una espera
	jr nc,L_52CA		;52c3
	ld a,002h		;52c5
	jp pinta_uno_de_los_tres_dibujos		;52c7   ; el dibujo 2, y no pasa
L_52CA:
	ld hl,0e1aah		;52ca
	set 1,(hl)		;52cd   ; fase 1 hecha
	jr L_5334		;52cf   ; y el cursor pintado

; ----------------------------------------------------------------------
; El cursor sobre la mano del 1, cada ocho cuadros. En riichi con esperas (0xE1CD = 0x81) el cursor se clava en la ficha robada (0xE1C3): solo se puede descartar esa. Si no, el bit 2 de 0xE009 lo baja un hueco y el bit 3 lo sube, dando la vuelta por los extremos, con el sonido 5. Luego 0x5324 pone la X de los dos sprites del cursor (0xE0A9 y 0xE0AD) con la tabla de multiplos de 16 y 0x5334 los manda a 0x3B00, con los sprites 2 y 3 escondidos.
; ----------------------------------------------------------------------
mueve_el_cursor_de_la_mano:
	ld a,(0e003h)		;52d1
	and 007h		;52d4   ; cada ocho cuadros
	ret nz			;52d6
	ld a,(0e1cdh)		;52d7
	cp 081h		;52da   ; 0x81: en riichi y con esperas, el cursor se clava en la robada
	jr nz,L_52E6		;52dc
	ld a,(0e1c3h)		;52de
	ld (0e1c2h),a		;52e1
	jr L_5324		;52e4
L_52E6:
	ld hl,0e009h		;52e6
	bit 2,(hl)		;52e9   ; bit 2 de 0xE009: un hueco hacia abajo
	jr z,L_5305		;52eb
	ld a,005h		;52ed
	call pide_un_sonido		;52ef   ; sonido 5
	ld a,(0e1c2h)		;52f2
	dec a			;52f5   ; cursor - 1
	ld (0e1c2h),a		;52f6
	or a			;52f9
	jp p,L_5324		;52fa   ; por debajo de cero: a la robada, la ultima
	ld a,(0e1c3h)		;52fd
	ld (0e1c2h),a		;5300
	jr L_5324		;5303
L_5305:
	ld hl,0e009h		;5305
	bit 3,(hl)		;5308   ; bit 3 de 0xE009: un hueco hacia arriba
	jr z,L_5324		;530a
	ld a,005h		;530c
	call pide_un_sonido		;530e
	ld a,(0e1c2h)		;5311
	inc a			;5314   ; cursor + 1
	ld hl,0e1c3h		;5315
	ld (0e1c2h),a		;5318
	cp (hl)			;531b   ; pasa de la robada: al cero
	jr c,L_5324		;531c
	jr z,L_5324		;531e
	xor a			;5320
	ld (0e1c2h),a		;5321
L_5324:
	ld a,(0e1c2h)		;5324
	ld hl,05350h		;5327   ; la X: multiplos de 16
	call suma_a_a_hl		;532a
	ld a,(hl)			;532d
	ld (0e0a9h),a		;532e   ; los dos sprites del cursor
	ld (0e0adh),a		;5331
L_5334:
	ld a,0e0h		;5334
	ld de,03b08h		;5336   ; los sprites 2 y 3 escondidos en Y = 0xE0
	call escribe_en_vram		;5339
	ld a,0e0h		;533c
	ld de,03b0ch		;533e
	call escribe_en_vram		;5341
	ld hl,0e0a8h		;5344
	ld de,03b00h		;5347   ; y los atributos de los cuatro primeros, a 0x3B00
	ld bc,00008h		;534a
	jp copia_a_la_vram		;534d

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



; ----------------------------------------------------------------------
; FASE 2: LA COMPROBACION DEL RIICHI (bit 2 de 0xE1AA), cada cuatro cuadros. Si el 1 no ha pedido riichi (bit 0 de 0xE1CD) o ya hay furiten marcado (bit 6), la ficha se quita sin mas por 0x53C7. Con riichi pedido, se calculan las esperas de la mano que queda (0x66E7) y sin ninguna (bit 7) se rechaza por 0x5378. Con esperas, en la dificultad 1 (bit 0 de 0xE040) se mira el furiten -la ficha que descarta es una de sus esperas, o alguna espera esta en su rio- y tambien se rechaza; en las 2 y 3 no se mira y se paga: 0x53B8, mil puntos a la mesa. Luego 0x53C7 saca la ficha de la mano, repinta y, con riichi, pone el palo como sprite sobre el descarte.
; ----------------------------------------------------------------------
fase_2_riichi_y_furiten:
	ld a,(0e003h)		;535e
	and 003h		;5361   ; cada cuatro cuadros
	ret nz			;5363
	ld a,(0e1cdh)		;5364
	rra			;5367   ; bit 0 de 0xE1CD: ha pedido riichi
	jr nc,quita_el_descarte_de_la_mano		;5368
	bit 6,a		;536a
	jr nz,quita_el_descarte_de_la_mano		;536c   ; bit 6: ya hay furiten marcado, no se mira mas
	call L_66E7		;536e   ; las esperas de lo que queda
	ld a,(0e1cdh)		;5371
	sla a		;5374   ; bit 7 al acarreo: tiene esperas
	jr c,L_539A		;5376
rechaza_el_riichi:
	ld a,002h		;5378   ; SE RECHAZA EL RIICHI: el dibujo 2
	call pinta_uno_de_los_tres_dibujos		;537a
	ld b,004h		;537d
	ld de,03b10h		;537f   ; los cuatro sprites del cursor escondidos
L_5382:
	ld a,0e0h		;5382
	push de			;5384
	call escribe_en_vram		;5385
	pop de			;5388
	ld a,004h		;5389
	call suma_a_a_de		;538b
	djnz L_5382		;538e
	xor a			;5390
	ld (0e1cdh),a		;5391   ; 0xE1CD a cero: riichi y esperas olvidados
	ld hl,0e1aah		;5394
	res 1,(hl)		;5397   ; y vuelta a la fase 1
	ret			;5399
L_539A:
	ld a,(0e040h)		;539a
	rra			;539d   ; bit 0 de 0xE040: solo la dificultad 1 mira el furiten
	jr nc,paga_el_riichi_el_1		;539e
	ld a,(0e1bch)		;53a0
	ld hl,0e1f5h		;53a3
	ld b,00dh		;53a6
	call busca_en_la_mano		;53a8   ; la ficha que descarta, en la lista de esperas 0xE1F5
	cp (hl)			;53ab
	jr z,rechaza_el_riichi		;53ac   ; esta: furiten, se rechaza
	call busca_en_las_dos_listas		;53ae   ; las esperas contra su rio
	ld a,(0e1cdh)		;53b1
	and 040h		;53b4   ; bit 6: coincidencia, furiten
	jr nz,rechaza_el_riichi		;53b6
paga_el_riichi_el_1:
	ld de,01000h		;53b8   ; EL RIICHI DEL JUGADOR 1: mil puntos
	call cobra_mil_el_de_e047		;53bb
	ld a,(0e04ah)		;53be
	add a,001h		;53c1   ; y un palo mas en la mesa, en BCD
	daa			;53c3
	ld (0e04ah),a		;53c4
quita_el_descarte_de_la_mano:
	ld a,(0e1c2h)		;53c7   ; el hueco del cursor
	ld hl,0e13ah		;53ca
	call suma_a_a_hl		;53cd
	ld (hl),039h		;53d0   ; 0x39: se vacia
	call pinta_la_mano_del_jugador_1		;53d2
	ld a,(0e1cdh)		;53d5
	rra			;53d8   ; sin riichi, listo
	jr nc,L_5402		;53d9
	ld hl,0e0d8h		;53db
	ld (hl),090h		;53de   ; el palo de riichi como sprite: fila 0x90, primera fila del rio
	ld a,(0e1cch)		;53e0
	cp 00ah		;53e3   ; del descarte 10 en adelante
	jr c,L_53EB		;53e5
	sub 00ah		;53e7
	ld (hl),0a8h		;53e9   ; la segunda fila, 0xA8
L_53EB:
	ld hl,05350h		;53eb   ; la X del descarte
	call suma_a_a_hl		;53ee
	ld a,(hl)			;53f1
	ld hl,0e0d9h		;53f2
	ld (hl),a			;53f5
	ld hl,0e0d8h		;53f6
	ld de,03b30h		;53f9   ; el sprite 12, a 0x3B30
	ld bc,00004h		;53fc
	call copia_a_la_vram		;53ff
L_5402:
	xor a			;5402
	ld (0e1cfh),a		;5403   ; 0xE1CF a cero: la marca del rinshan
	ld hl,0e1aah		;5406
	set 2,(hl)		;5409   ; fase 2 hecha
	ret			;540b

; ----------------------------------------------------------------------
; FASE 3 (bit 3 de 0xE1AA), cada ocho cuadros: ordena los catorce huecos del 1 con 0x4F9B -el hueco vacio 0x39 cae al final-, repinta la mano y esconde los dos sprites del cursor.
; ----------------------------------------------------------------------
fase_3_ordena_la_mano:
	ld a,(0e003h)		;540c
	and 007h		;540f   ; cada ocho cuadros
	ret nz			;5411
	ld a,(0e1c3h)		;5412
	inc a			;5415   ; catorce huecos
	ld b,a			;5416
	ld hl,0e13ah		;5417
	call L_4F9B		;541a   ; ordenados: el 0x39 vacio cae al final
	call pinta_la_mano_del_jugador_1		;541d
	ld a,0e0h		;5420
	ld de,03b00h		;5422   ; los dos sprites del cursor escondidos
	call escribe_en_vram		;5425
	ld a,0e0h		;5428
	ld de,03b04h		;542a
	call escribe_en_vram		;542d
	ld hl,0e1aah		;5430
	set 3,(hl)		;5433   ; fase 3 hecha
	ret			;5435

; ----------------------------------------------------------------------
; FASE 4 (bit 4 de 0xE1AA), cada ocho cuadros: la ficha elegida (0xE1BC) va al rio del 1 (0xE15E, indice 0xE1BE) con el sonido 6, y se baja la marca de tsumo. Es la unica fase que la escribe.
; ----------------------------------------------------------------------
fase_4_el_descarte_al_rio:
	ld a,(0e003h)		;5436
	and 007h		;5439   ; cada ocho cuadros
	ret nz			;543b
	ld hl,0e1d1h		;543c
	res 0,(hl)		;543f   ; el 1 descarta: bit 0 de 0xE1D1 a cero, ya no tiene ficha robada; si ahora gana es RON
	ld a,006h		;5441
	call pide_un_sonido		;5443   ; sonido 6
	ld hl,0e1beh		;5446
	inc (hl)			;5449   ; un descarte mas
	ld a,(0e1beh)		;544a
	ld hl,0e15eh		;544d
	call suma_a_a_hl		;5450   ; su hueco en el rio
	ld a,(0e1bch)		;5453
	ld (hl),a			;5456   ; la ficha
	call pinta_el_rio_del_jugador_1		;5457
	ld hl,0e1aah		;545a
	set 4,(hl)		;545d   ; fase 4 hecha
	ret			;545f

; ----------------------------------------------------------------------
; FASE 5: EL TURNO DE LA MAQUINA, PRIMERA MITAD (bit 5 de 0xE1AA), cada ocho cuadros. Cambia las figuras: guarda las del 1 (0xE2B6-0xE2F0 a 0xE240) y trae las del 2 (0xE27B). 0x567B mira si el descarte del 1 le da RON. Si no hay nada en marcha (0xE1A9) ni el 1 ha pedido agari (bit 0 de 0xE1C7): con el 1 dentro de su tope de descartes (0xE1C0) la maquina ROBA (0x549D: marca de tsumo, 0x5A2B sortea, al hueco 0xE208), una de cada cuatro veces intenta un KAN por el menu (0x5828 con 0xE20D = 0x10), luego 0x577A decide riichi, pon o chi, y por fin la mano se pinta boca abajo (0x551D esconde, 0x54C4 pinta, 0x54C7 devuelve) con la robada otra vez en su hueco. Si el 1 ya paso el tope, 0x563D devuelve las figuras y la mano se da por agotada (0x5654).
; ----------------------------------------------------------------------
fase_5_roba_la_maquina:
	ld a,(0e003h)		;5460
	and 007h		;5463   ; cada ocho cuadros
	ret nz			;5465
	ld hl,0e2b6h		;5466   ; las figuras del 1, guardadas en 0xE240
	ld de,0e240h		;5469
	ld bc,0003bh		;546c
	ldir		;546f
	ld hl,0e27bh		;5471   ; y las del 2, a la zona de trabajo
	ld de,0e2b6h		;5474
	ld bc,0003bh		;5477
	ldir		;547a
	call mira_si_la_maquina_gana		;547c   ; el descarte del 1 le da ron?
	ld a,(0e1a9h)		;547f
	or a			;5482   ; 0xE1A9: algo en marcha, se espera
	ret nz			;5483
	ld a,(0e1c7h)		;5484
	rra			;5487   ; bit 0 de 0xE1C7: el 1 ha pedido agari
	ret c			;5488
	ld hl,0e1beh		;5489
	ld a,(0e1c0h)		;548c   ; 0xE1C0: el tope de descartes del 1
	cp (hl)			;548f
	jr nc,L_549D		;5490   ; dentro del tope: la maquina roba
	call devuelve_las_figuras_del_1		;5492   ; pasado el tope: las figuras de vuelta
	ld hl,0e1aah		;5495
	res 4,(hl)		;5498
	jp agota_la_mano		;549a   ; y la mano se agota
L_549D:
	ld a,001h		;549d
	ld (0e22ah),a		;549f   ; el 2 va a robar: 0xE22A = 1, su marca de tsumo
	call sortea_el_descarte_a_e22b		;54a2   ; sortea la ficha
	call pon_a_en_la_robada_del_2		;54a5   ; al hueco de la robada, 0xE208
	ld a,(0e064h)		;54a8
	and 003h		;54ab   ; una de cada cuatro veces
	jr nz,L_54BE		;54ad
	ld a,010h		;54af
	ld (0e20dh),a		;54b1   ; 0x10: kan
	call la_maquina_usa_el_menu		;54b4   ; lo intenta por el menu
	ld a,c			;54b7
	rra			;54b8
	jr c,L_54BE		;54b9   ; bit 0 de C: hecho
	call L_5820		;54bb   ; sin kan: las esperas de nuevo
L_54BE:
	call la_maquina_declara_riichi_o_llama		;54be   ; riichi, pon o chi
	call esconde_la_mano_del_2		;54c1   ; la mano escondida
	call pinta_la_mano_del_jugador_2		;54c4   ; pintada boca abajo
	ld hl,0e21ch		;54c7
	ld de,0e14ch		;54ca
	call L_5535		;54cd   ; y de vuelta, 0xE208 fichas
	ldir		;54d0
	ld a,(0e22bh)		;54d2
	call pon_a_en_la_robada_del_2		;54d5   ; la robada otra vez en su hueco
	ld hl,0e1aah		;54d8
	set 5,(hl)		;54db   ; fase 5 hecha
	ret			;54dd

; ----------------------------------------------------------------------
; Escribe A en el hueco de la ficha robada del 2 (0xE14C + 0xE208).
; ----------------------------------------------------------------------
pon_a_en_la_robada_del_2:
	push af			;54de
	ld a,(0e208h)		;54df   ; el hueco de la robada del 2
	ld hl,0e14ch		;54e2
	call suma_a_a_hl		;54e5
	pop af			;54e8
	ld (hl),a			;54e9   ; la ficha
	ret			;54ea

; ----------------------------------------------------------------------
; FASE 6: EL DESCARTE DE LA MAQUINA (bit 6 de 0xE1AA), en dos tiempos marcados por el bit 2 de 0xE1C4. El primero, a los 32 cuadros: 0x567B mira si la robada le da TSUMO; si no hay nada en marcha ni agari pedido, esconde la mano (0x551D), 0x553C elige QUE HUECO SE VE VACIO -que es teatro: la ficha que descarta no sale de la mano- y la pinta boca abajo. El segundo, 16 cuadros despues (0x556C): devuelve al monton la copia de la robada, SORTEA EL DESCARTE por 0x598F, lo pone en el rio del 2 (0xE172, indice 0xE1BF) con el sonido 6, baja la marca de tsumo, reinicia el reloj y da la fase por hecha.
; ----------------------------------------------------------------------
fase_6_descarta_la_maquina:
	ld hl,0e1c4h		;54eb
	bit 2,(hl)		;54ee   ; bit 2 de 0xE1C4: segundo tiempo
	jp nz,el_descarte_de_la_maquina_al_rio		;54f0
	ld a,(0e003h)		;54f3
	and 01fh		;54f6   ; cada 32 cuadros
	ret nz			;54f8
	set 2,(hl)		;54f9   ; primer tiempo hecho
	call mira_si_la_maquina_gana		;54fb   ; la robada le da tsumo?
	ld a,(0e1a9h)		;54fe
	or a			;5501   ; algo en marcha
	ret nz			;5502
	ld a,(0e1c7h)		;5503
	rra			;5506   ; el 1 ha pedido agari
	ret c			;5507
	call esconde_la_mano_del_2		;5508   ; la mano escondida
	call elige_el_hueco_que_se_ve_vacio		;550b   ; y el hueco que se vera vacio

; ----------------------------------------------------------------------
; Pinta la mano del 2 tal como esta en 0xE14C -que en ese momento son los reversos que puso 0x551D- y devuelve la de verdad desde 0xE21C.
; ----------------------------------------------------------------------
pinta_la_mano_del_2_boca_abajo:
	call pinta_la_mano_del_jugador_2		;550e   ; pintada boca abajo
	ld hl,0e21ch		;5511
	ld de,0e14ch		;5514
	call L_5535		;5517   ; y de vuelta
	ldir		;551a
	ret			;551c

; ----------------------------------------------------------------------
; Guarda la mano de verdad del 2 (0xE14C, 0xE208 fichas) en 0xE21C y pone en su sitio los reversos de 0x4FB1, uno mas que fichas. Lo que se pinta despues son reversos; 0x550E la devuelve.
; ----------------------------------------------------------------------
esconde_la_mano_del_2:
	ld hl,0e14ch		;551d
	ld de,0e21ch		;5520
	call L_5535		;5523   ; 0xE208 fichas, a 0xE21C
	ldir		;5526
	ld hl,04fb1h		;5528   ; los reversos de 0x4FB1
	ld de,0e14ch		;552b
	call L_5535		;552e
	inc c			;5531   ; una mas: la robada
	ldir		;5532
	ret			;5534
L_5535:
	ld b,000h		;5535   ; BC = 0xE208, el tamano de la mano del 2
	ld a,(0e208h)		;5537
	ld c,a			;553a
	ret			;553b

; ----------------------------------------------------------------------
; TEATRO: que hueco de la mano boca abajo se muestra vacio, para que parezca que el descarte salio de ahi. En riichi (bit 0 de 0xE1AE) siempre el de la robada, como haria una persona; tambien a partir del descarte 0xE33D. Antes de eso, del descarte 8 en adelante, un hueco al azar (0x48CE) si el bit 0 de la semilla esta puesto y la robada si no; en los siete primeros, al reves. El descarte de verdad lo sortea 0x598F y no tiene nada que ver con el hueco.
; ----------------------------------------------------------------------
elige_el_hueco_que_se_ve_vacio:
	ld a,(0e1aeh)		;553c
	rra			;553f   ; bit 0 de 0xE1AE: en riichi, siempre la robada
	jr c,L_5567		;5540
	ld hl,0e33dh		;5542
	ld a,(0e1bfh)		;5545
	cp (hl)			;5548   ; del descarte 0xE33D en adelante, la robada
	jr nc,L_5567		;5549
	cp 008h		;554b
	jr nc,L_5561		;554d   ; del 8 en adelante, por 0x5561
	ld a,(0e064h)		;554f
	rra			;5552   ; antes: bit 0 de la semilla, la robada
	jr c,L_5567		;5553
L_5555:
	call saca_un_numero_menor_que_h		;5555   ; un hueco al azar
	ld hl,0e14ch		;5558
	call suma_a_a_hl		;555b
	ld (hl),039h		;555e   ; 0x39: se ve vacio
	ret			;5560
L_5561:
	ld a,(0e064h)		;5561
	rra			;5564   ; bit 0 de la semilla: al azar
	jr c,L_5555		;5565
L_5567:
	ld a,039h		;5567   ; la robada, 0x39 en 0xE208
	jp pon_a_en_la_robada_del_2		;5569
el_descarte_de_la_maquina_al_rio:
	ld a,(0e003h)		;556c
	and 00fh		;556f   ; cada 16 cuadros
	ret nz			;5571
	res 2,(hl)		;5572   ; los dos tiempos hechos
	call devuelve_la_copia_de_e22b		;5574   ; la copia de la robada vuelve al monton: ese hueco se pisa cada turno
	call sortea_hasta_que_no_sea_espera		;5577   ; EL DESCARTE: sorteado, y que no sea una espera
	xor a			;557a
	ld (0e22ah),a		;557b   ; el 2 descarta: 0xE22A a cero
	ld a,006h		;557e
	call pide_un_sonido		;5580   ; sonido 6
	ld hl,0e1bfh		;5583
	inc (hl)			;5586   ; un descarte mas del 2
	ld a,(0e1bfh)		;5587
	ld hl,0e172h		;558a
	call suma_a_a_hl		;558d   ; su hueco en el rio
	ld a,(0e22bh)		;5590
	ld (hl),a			;5593   ; la ficha sorteada
	call pinta_el_rio_del_jugador_2		;5594
	ld hl,00000h		;5597
	ld (0e052h),hl		;559a   ; el reloj a cero
	ld hl,0e1aah		;559d
	set 6,(hl)		;55a0   ; fase 6 hecha

; ----------------------------------------------------------------------
; FASE 7 (bit 7 de 0xE1AA): lo que pasa entre el descarte de la maquina y el robo del 1. La primera vez (bit 1 de 0xE1C4) repinta la mano del 2 boca abajo sin la robada y devuelve las figuras del 1 (0x563D). Si el 2 ha pasado su tope de descartes (0xE1C1), a los 420 cuadros la mano se agota (0x5654). Si no: el dibujo 0, el despachador de llamadas -pon, chi, kan o ron del 1 sobre ese descarte- y la vuelta de las variables; 0xE1AA = 1 es que ha hecho llamada y vuelve a la fase 1 (0x5630), 0xFF que roba de reposicion (0x5603). En las dificultades 2 y 3 se roba solo a los 720 cuadros; en la 1 hay que pulsar (bit 0 de 0xE23A). Antes de robar, 0x49C6 avisa si el descarte de la maquina es una espera del 1 en riichi (dificultad 1): el dibujo 2 y se queda esperando el agari.
; ----------------------------------------------------------------------
fase_7_tras_el_descarte_de_la_maquina:
	ld hl,0e1c4h		;55a2
	bit 1,(hl)		;55a5   ; bit 1 de 0xE1C4: primera vez ya hecha
	jr nz,L_55B9		;55a7
	set 1,(hl)		;55a9   ; primera vez
	call esconde_la_mano_del_2		;55ab   ; la mano del 2 escondida
	ld a,039h		;55ae
	call pon_a_en_la_robada_del_2		;55b0   ; sin la robada
	call pinta_la_mano_del_2_boca_abajo		;55b3   ; pintada y de vuelta
	call devuelve_las_figuras_del_1		;55b6   ; las figuras del 1, de vuelta
L_55B9:
	ld hl,0e1bfh		;55b9
	ld a,(0e1c1h)		;55bc   ; 0xE1C1: el tope de descartes del 2
	cp (hl)			;55bf
	jr nc,L_55CC		;55c0   ; dentro del tope
	ld hl,001a4h		;55c2   ; pasado el tope: 420 cuadros
	call resta_el_reloj_a_hl		;55c5
	ret nc			;55c8   ; aun no
	jp agota_la_mano		;55c9   ; y la mano se agota
L_55CC:
	xor a			;55cc
	call pinta_uno_de_los_tres_dibujos		;55cd   ; el dibujo 0
	call despacha_la_llamada		;55d0   ; pon, chi, kan o ron sobre el descarte de la maquina
	call guarda_las_variables_del_que_juega		;55d3   ; las variables de vuelta
	ld a,(0e1aah)		;55d6
	cp 001h		;55d9   ; 1: hubo llamada, a la fase 1
	jp z,L_5630		;55db
	cp 0ffh		;55de   ; 0xFF: kan, roba de reposicion
	jr z,roba_el_jugador_1		;55e0
	ld a,(0e040h)		;55e2
	rra			;55e5
	rra			;55e6   ; dificultades 2 y 3
	jr nc,L_55F1		;55e7
	ld hl,002d0h		;55e9   ; 720 cuadros y roba solo
	call resta_el_reloj_a_hl		;55ec
	jr c,L_55F6		;55ef
L_55F1:
	ld a,(0e23ah)		;55f1
	rra			;55f4   ; bit 0 de 0xE23A: hay que pulsar
	ret nc			;55f5
L_55F6:
	ld a,(0e22bh)		;55f6   ; el descarte de la maquina
	call avisa_si_es_espera_en_amachua		;55f9   ; es una espera del 1 en riichi, dificultad 1?
	jr nc,roba_el_jugador_1		;55fc   ; no: roba
	ld a,002h		;55fe
	jp pinta_uno_de_los_tres_dibujos		;5600   ; si: el dibujo 2, y espera al agari

; ----------------------------------------------------------------------
; EL ROBO DEL JUGADOR 1: reloj a cero, sonido 7, marca de tsumo, 0x4F64 sortea la ficha y va al hueco 0xE1C3 de la mano de 0xE13A; se pinta, el cursor se pone en la robada y 0xE1AA = 1: fase 1, a elegir el descarte. Tambien es la ficha de reposicion tras un kan (0x528F, 0x55E0).
; ----------------------------------------------------------------------
roba_el_jugador_1:
	ld hl,00000h		;5603
	ld (0e052h),hl		;5606   ; el reloj a cero
	ld a,007h		;5609
	call pide_un_sonido		;560b   ; sonido 7
	ld hl,0e1d1h		;560e
	set 0,(hl)		;5611   ; el 1 va a robar: bit 0 de 0xE1D1 puesto; si gana con esa ficha es TSUMO
	call reparte_una_ficha		;5613   ; la ficha
	push af			;5616
	ld a,(0e1c3h)		;5617
	ld hl,0e13ah		;561a
	call suma_a_a_hl		;561d   ; al hueco de la robada, en la mano
	pop af			;5620
	ld (hl),a			;5621
	call pinta_la_mano_del_jugador_1		;5622
	ld hl,0e1aah		;5625
	ld a,(0e1c3h)		;5628
	ld (0e1c2h),a		;562b   ; el cursor sobre la robada
	ld (hl),001h		;562e   ; 0xE1AA = 1: solo la fase 0 hecha, a elegir el descarte
L_5630:
	ld hl,0e1c4h		;5630
	res 1,(hl)		;5633   ; bit 1 de 0xE1C4 abajo: la fase 7 volvera a empezar de cero
	ret			;5635

; ----------------------------------------------------------------------
; HL = HL - 0xE052, con el acarreo que traiga: acarreo a la salida cuando el reloj de la fase ha pasado de HL. Es como se miden los 420, 600 y 720 cuadros de las fases 1 y 7.
; ----------------------------------------------------------------------
resta_el_reloj_a_hl:
	ld de,(0e052h)		;5636   ; el reloj de la fase
	sbc hl,de		;563a   ; acarreo: ya ha pasado
	ret			;563c

; ----------------------------------------------------------------------
; Al reves que 0x5466: las figuras del 2 a 0xE27B y las guardadas del 1 (0xE240) a la zona de trabajo 0xE2B6.
; ----------------------------------------------------------------------
devuelve_las_figuras_del_1:
	ld hl,0e2b6h		;563d   ; las del 2, guardadas
	ld de,0e27bh		;5640
	ld bc,0003bh		;5643
	ldir		;5646
	ld hl,0e240h		;5648   ; las del 1, de vuelta
	ld de,0e2b6h		;564b
	ld bc,0003bh		;564e
	ldir		;5651
	ret			;5653

; ----------------------------------------------------------------------
; La mano se acaba sin ganador por agotarse los descartes: 0xE1A9 = 0x80 y a destapar la mano de la maquina (0x56F7). Llegan 0x50DA (las ocho fases hechas), 0x549A y 0x55C9 (los topes de descartes).
; ----------------------------------------------------------------------
agota_la_mano:
	ld a,080h		;5654   ; 0x80: agotada
	ld (0e1a9h),a		;5656
	jp destapa_la_mano_de_la_maquina		;5659
L_565C:
	ld hl,0e302h		;565c
	set 2,(hl)		;565f   ; bit 2 de 0xE302: sin ganador

; ----------------------------------------------------------------------
; 0xE1A9 = 0xFF y unos 180 cuadros del reloj con la mano de la maquina a la vista; luego baja el bit 1 de 0xE1A8 y pone 0xE1A9 y 0xE1AA a cero: el turno se ha acabado y el submodo 2 sigue por 0x424B con lo que diga 0xE302.
; ----------------------------------------------------------------------
espera_y_cierra_la_mano:
	ld a,0ffh		;5661
	ld (0e1a9h),a		;5663   ; 0xFF: cerrando
	ld de,(0e052h)		;5666
	ld hl,000b4h		;566a   ; 180 cuadros
	sbc hl,de		;566d
	ret nc			;566f   ; aun no
	ld hl,0e1a8h		;5670
	xor a			;5673
	res 1,(hl)		;5674   ; bit 1 de 0xE1A8 abajo
	inc hl			;5676
	ld (hl),a			;5677   ; 0xE1A9 y 0xE1AA a cero: fin del turno
	inc hl			;5678
	ld (hl),a			;5679
	ret			;567a

; ----------------------------------------------------------------------
; LA MAQUINA MIRA SI GANA. En modo defensa (bit 0 de 0xE340) ni lo intenta. La ficha es la robada (0xE22B) si ya paso la fase 5 -tsumo- y el descarte del 1 (0xE1BC) si no -ron-. Si no esta entre sus esperas (0xE20E, por 0x576E) no hay nada. Si esta, 0xE1BA la guarda y se mira el turno: antes del descarte 0xE33D la maquina NO GANA TODAVIA: con ron lo deja pasar y con tsumo sortea otra robada que no sea espera (0x598F). Tampoco gana justo en su turno de riichi (0xE1BB). Si no, 0xE1A9 = 1 y 0x56B6 decide si canta.
; ----------------------------------------------------------------------
mira_si_la_maquina_gana:
	ld a,(0e340h)		;567b
	rra			;567e   ; bit 0 de 0xE340: en defensa no se gana
	ret c			;567f
	ld a,(0e22bh)		;5680   ; la robada
	ld hl,0e1aah		;5683
	bit 5,(hl)		;5686   ; bit 5 de 0xE1AA: fase 5 hecha, es tsumo
	jr nz,L_568D		;5688
	ld a,(0e1bch)		;568a   ; o el descarte del 1: ron
L_568D:
	call busca_en_las_esperas_del_2		;568d   ; entre sus esperas?
	cp (hl)			;5690
	ret nz			;5691   ; no
	ld (0e1bah),a		;5692   ; 0xE1BA: la ficha que gana
	ld a,(0e1bfh)		;5695
	inc a			;5698
	ld hl,0e33dh		;5699
	cp (hl)			;569c   ; antes del descarte 0xE33D no gana
	jr nc,L_56A8		;569d
	ld hl,0e1aah		;569f
	bit 5,(hl)		;56a2   ; con ron lo deja pasar
	ret z			;56a4
	jp sortea_hasta_que_no_sea_espera		;56a5   ; con tsumo, otra robada que no sea espera
L_56A8:
	ld hl,0e1bbh		;56a8
	ld a,(0e1bfh)		;56ab
	inc a			;56ae
	cp (hl)			;56af   ; justo en el turno del riichi tampoco
	ret z			;56b0
	ld a,001h		;56b1
	ld (0e1a9h),a		;56b3   ; 0xE1A9 = 1: va a cantar

; ----------------------------------------------------------------------
; Con 0xE1A9 = 1 cuenta los han de su mano (0x575A) y canta con dos o mas, o con uno si hay menos de 5 honba; si no llega, limpia y se queda como estaba (0xE1A9 = 0). Con cualquier otro valor de 0xE1A9 (0x40 gano el 1, 0x80 agotada, 3 cantando) sigue destapando la mano (0x571C). Llega desde 0x5030 con A = 0xE1A9.
; ----------------------------------------------------------------------
la_maquina_decide_si_canta:
	cp 001h		;56b6   ; 1: decidir
	jr nz,destapa_una_ficha		;56b8
	call cuenta_los_han_de_la_maquina		;56ba   ; los han
	cp 002h		;56bd   ; dos o mas: canta
	jr nc,la_maquina_canta		;56bf
	rra			;56c1
	jr nc,L_56CB		;56c2   ; cero: no
	ld a,(0e04bh)		;56c4
	cp 005h		;56c7   ; uno vale solo con menos de 5 honba
	jr c,la_maquina_canta		;56c9
L_56CB:
	call limpia_el_analisis		;56cb
	xor a			;56ce
	ld (0e1a9h),a		;56cf   ; 0xE1A9 a cero: sigue jugando
limpia_la_lista_de_jugadas:
	xor a			;56d2   ; la lista de jugadas y los han, a cero
	ld hl,0e305h		;56d3
	ld de,0e306h		;56d6
	ld (hl),a			;56d9
	ld bc,00011h		;56da
	ldir		;56dd
	ld (0e1d1h),a		;56df   ; y 0xE1D1 a cero: la marca del 1, que 0x56EE y 0x5764 pisan con la del 2 al evaluar la mano de la maquina
	ret			;56e2
la_maquina_canta:
	ld a,090h		;56e3
	call pide_un_sonido		;56e5   ; sonido 0x90: la maquina canta
	call limpia_la_lista_de_jugadas		;56e8
	ld a,(0e22ah)		;56eb
	ld (0e1d1h),a		;56ee   ; la marca de tsumo de la maquina, en 0xE1D1, que es lo que lee el evaluador
	rra			;56f1   ; con tsumo
	jr nc,destapa_la_mano_de_la_maquina		;56f2
	call L_5754		;56f4   ; la ficha que gana, al hueco de la robada

; ----------------------------------------------------------------------
; Prepara el destape: copia la mano del 2 (catorce bytes de 0xE14C) a 0xE12B, apunta cuantas (0xE129 = 0xE208 + 1), pone el indice 0xE1B7 a cero, vacia 0xE14C y sube el bit 1 de 0xE1A9. Desde ahi 0x571C la va destapando ficha a ficha, una cada ocho cuadros.
; ----------------------------------------------------------------------
destapa_la_mano_de_la_maquina:
	ld hl,0e14ch		;56f7   ; la mano, a 0xE12B
	ld de,0e12bh		;56fa
	ld bc,0000eh		;56fd
	ldir		;5700
	ld a,(0e208h)		;5702
	inc a			;5705
	ld (0e129h),a		;5706   ; cuantas fichas
	ld b,a			;5709
	xor a			;570a
	ld (0e1b7h),a		;570b   ; el indice, a cero
	ld hl,0e14ch		;570e
L_5711:
	ld (hl),a			;5711   ; la mano visible, vacia
	inc hl			;5712
	djnz L_5711		;5713
	ld hl,0e1a9h		;5715
	set 1,(hl)		;5718   ; bit 1 de 0xE1A9: destapando
	jr L_5740		;571a   ; y se pinta vacia

; ----------------------------------------------------------------------
; Cada ocho cuadros devuelve una ficha de 0xE12B a 0xE14C y repinta; cuando el indice llega a la cuenta, reloj a cero y, con el bit 7 de 0xE1A9 (agotada), 0x565C marca sin ganador; en todo caso 0x5661 cierra tras tres segundos.
; ----------------------------------------------------------------------
destapa_una_ficha:
	ld a,(0e003h)		;571c
	and 007h		;571f   ; cada ocho cuadros
	ret nz			;5721
	ld hl,0e129h		;5722
	ld a,(0e1b7h)		;5725
	cp (hl)			;5728   ; todas destapadas?
	jr z,L_5743		;5729
	ld hl,0e12bh		;572b
	call suma_a_a_hl		;572e   ; la que toca, de 0xE12B
	ld a,(0e1b7h)		;5731
	ld de,0e14ch		;5734
	call suma_a_a_de		;5737
	ld a,(hl)			;573a
	ld (de),a			;573b   ; a la mano visible
	ld hl,0e1b7h		;573c
	inc (hl)			;573f   ; una mas
L_5740:
	jp pinta_la_mano_del_jugador_2		;5740
L_5743:
	ld hl,00000h		;5743
	ld (0e052h),hl		;5746   ; reloj a cero
	ld a,(0e1a9h)		;5749
	rla			;574c   ; bit 7: agotada, sin ganador
	jp c,L_565C		;574d
	rla			;5750   ; lo demas: a cerrar
	jp espera_y_cierra_la_mano		;5751
L_5754:
	ld a,(0e1bah)		;5754   ; la ficha que gana, al hueco de la robada
	jp pon_a_en_la_robada_del_2		;5757

; ----------------------------------------------------------------------
; Analiza la mano del 2 (0x5F3E), pone los han a cero, le da al evaluador su marca de tsumo (0xE22A en 0xE1D1) y pasa los detectores (0x7B3F). Devuelve los han en A. Lo llama 0x56BA.
; ----------------------------------------------------------------------
cuenta_los_han_de_la_maquina:
	call analiza_la_mano		;575a   ; la mano completa? y sus figuras
	xor a			;575d
	ld (0e316h),a		;575e   ; los han a cero
	ld a,(0e22ah)		;5761
	ld (0e1d1h),a		;5764   ; el evaluador lee 0xE1D1: se le pone la marca de tsumo del 2
	call evalua_las_jugadas		;5767   ; los detectores
	ld a,(0e316h)		;576a   ; los han
	ret			;576d

; ----------------------------------------------------------------------
; Busca A en la lista de esperas del 2 (0xE20E, catorce huecos): Z y HL en la coincidencia; si no esta, HL se queda en el ultimo hueco y NZ. Lo usan 0x568D, 0x585E y 0x5995.
; ----------------------------------------------------------------------
busca_en_las_esperas_del_2:
	ld b,00eh		;576e   ; catorce huecos
	ld hl,0e20eh		;5770
L_5773:
	cp (hl)			;5773
	ret z			;5774   ; esta
	inc hl			;5775
	djnz L_5773		;5776
	dec hl			;5778
	ret			;5779

; ----------------------------------------------------------------------
; RIICHI, PON O CHI DE LA MAQUINA, en la fase 5 tras robar. Riichi si no esta en defensa (0xE340), tiene esperas (0xE20E), la mano esta cerrada (0xE2B6 = 0), con 5 honba o mas su plan lo permite (0xE058), es exactamente su turno de riichi (0xE1BF + 1 = 0xE1BB) y no es el 19: paga mil por 0x5F31, sube el palo de la mesa, pone el palo como sprite sobre ese descarte (sprite 13, fila 0x2C o 0x14, columna invertida porque su rio va de derecha a izquierda), marca 0xE1AE = 1 y pasa por el menu con la opcion 2. Si no hay riichi (0x57EF): con los bits 1, 2 o 5 del plan intenta PON (opcion 4) y con los bits 1 o 2 CHI (opcion 8), por el menu; tras una llamada borra sus esperas y las recalcula (0x5820).
; ----------------------------------------------------------------------
la_maquina_declara_riichi_o_llama:
	ld a,(0e340h)		;577a
	rra			;577d   ; en defensa, nada
	jr c,L_57EF		;577e
	ld a,(0e20eh)		;5780
	or a			;5783   ; sin esperas, nada
	jr z,L_57EF		;5784
	ld a,(0e2b6h)		;5786
	or a			;5789   ; mano abierta, nada
	jr nz,L_57EF		;578a
	ld a,(0e04bh)		;578c
	cp 005h		;578f   ; con 5 honba o mas
	jr c,L_579A		;5791
	ld a,(0e058h)		;5793
	and 0feh		;5796   ; el plan tiene que permitirlo
	jr z,L_57EF		;5798
L_579A:
	ld a,(0e1bfh)		;579a   ; EL RIICHI DE LA MAQUINA: su descarte siguiente
	inc a			;579d
	ld hl,0e1bbh		;579e
	cp (hl)			;57a1   ; tiene que ser justo 0xE1BB
	jr nz,L_57EF		;57a2
	cp 013h		;57a4
	jr z,L_57EF		;57a6   ; y no el 19
	ld de,01000h		;57a8
	call cobra_mil_el_de_e044		;57ab   ; mil puntos
	ld a,(0e04ah)		;57ae
	add a,001h		;57b1   ; un palo mas en la mesa
	daa			;57b3
	ld (0e04ah),a		;57b4
	ld a,(0e1bbh)		;57b7
	ld hl,0e0dch		;57ba
	ld (hl),02ch		;57bd   ; el palo como sprite: fila 0x2C, primera fila de su rio
	cp 00ah		;57bf
	jr c,L_57C7		;57c1   ; del descarte 10 en adelante
	sub 00ah		;57c3
	ld (hl),014h		;57c5   ; la segunda fila, 0x14
L_57C7:
	sub 00eh		;57c7
	xor 0ffh		;57c9   ; la columna invertida: su rio va de derecha a izquierda
	ld hl,05350h		;57cb
	call suma_a_a_hl		;57ce
	ld a,(hl)			;57d1
	ld hl,0e0ddh		;57d2
	ld (hl),a			;57d5   ; la X
	ld a,001h		;57d6
	ld (0e1aeh),a		;57d8   ; 0xE1AE = 1: en riichi
	ld a,002h		;57db
	ld (0e20dh),a		;57dd   ; la opcion 2 del menu: riichi
	ld hl,0e0dch		;57e0
	ld de,03b34h		;57e3   ; el sprite 13, a 0x3B34
	ld bc,00004h		;57e6
	call copia_a_la_vram		;57e9
	jp la_maquina_usa_el_menu		;57ec   ; y por el menu
L_57EF:
	ld a,(0e058h)		;57ef
	and 026h		;57f2   ; bits 1, 2 y 5 del plan: pon
	jr z,L_5802		;57f4
	ld a,004h		;57f6
	ld (0e20dh),a		;57f8   ; la opcion 4
	call la_maquina_usa_el_menu		;57fb
	ld a,c			;57fe
	rra			;57ff   ; bit 0 de C: hecho
	jr nc,L_5813		;5800
L_5802:
	ld a,(0e058h)		;5802
	and 006h		;5805   ; bits 1 y 2: chi
	ret z			;5807
	ld a,008h		;5808
	ld (0e20dh),a		;580a   ; la opcion 8
	call la_maquina_usa_el_menu		;580d
	ld a,c			;5810
	rra			;5811
	ret c			;5812   ; hecho
L_5813:
	ld hl,0e20eh		;5813   ; las esperas, borradas
	ld (hl),000h		;5816
	ld de,0e20fh		;5818
	ld bc,0000dh		;581b
	ldir		;581e
L_5820:
	call L_66E7		;5820   ; y recalculadas
	xor a			;5823
	ld (0e205h),a		;5824
	ret			;5827

; ----------------------------------------------------------------------
; La maquina pasa por el mismo despachador de llamadas que la persona (0x663C): la opcion en 0xE1C7 (desde 0xE20D), sus variables cargadas (0x517A), la llamada, las variables de vuelta (0x51BC) y 0xE1C7 limpio. Devuelve en C lo que dejo el despachador: bit 0, hecha.
; ----------------------------------------------------------------------
la_maquina_usa_el_menu:
	ld a,(0e20dh)		;5828   ; la opcion, como si la hubiera elegido en el menu
	ld (0e1c7h),a		;582b
	call carga_las_variables_del_que_juega		;582e   ; sus variables
	call despacha_la_llamada		;5831   ; la llamada
	call guarda_las_variables_del_que_juega		;5834   ; y de vuelta
	xor a			;5837
	ld (0e1c7h),a		;5838   ; la opcion, limpia
	ret			;583b

; ----------------------------------------------------------------------
; EL DESCARTE DE LA MAQUINA NO SALE DE SU MANO: se sortea del muro, y este filtro lo hace parecer humano. En el demo no sortea (bit 6 de 0xE002). En la dificultad 1 vale cualquiera. En las otras dos, hasta el descarte 12: si es su turno de riichi o mas, con un plan de palo (bits 1 y 2 de 0xE058) y antes del noveno, rechaza las de SU palo (0xE059); sin plan de palo, en los cuatro primeros solo suelta HONORES, del cuarto al septimo solo unos, doses, ochos y nueves, y luego cualquiera; antes del turno de riichi, rechaza las que sean una de SUS ESPERAS. Del descarte 12 en adelante (0x58AA): en riichi cualquiera; en el 15 decide si se defiende (0x59EB) y en el 18 se defiende si la semilla es par; en defensa suelta una ficha segura de su mano (0x5A10); si no, cuenta el rio del 1 por palos (0x58D6) y rechaza el palo que el 1 menos ha soltado. Cada ficha rechazada vuelve al monton (0x59A4) y se sortea otra.
; ----------------------------------------------------------------------
sortea_el_descarte_de_la_maquina:
	ld hl,0e002h		;583c
	bit 6,(hl)		;583f   ; en el demo no se sortea
	ret z			;5841
	call reparte_una_ficha		;5842   ; la candidata
	ld (0e22bh),a		;5845
	ld a,(0e040h)		;5848
	rra			;584b   ; dificultad 1: vale cualquiera
	ret c			;584c
	ld a,(0e1bfh)		;584d
	cp 00ch		;5850   ; del descarte 12 en adelante, por 0x58AA
	jr nc,L_58AA		;5852
	inc a			;5854
	ld hl,0e33dh		;5855
	cp (hl)			;5858   ; ya en su turno de riichi?
	jr nc,L_5865		;5859
	ld a,(0e22bh)		;585b
	call busca_en_las_esperas_del_2		;585e   ; antes: si es una de sus esperas
	cp (hl)			;5861
	jr z,L_587C		;5862   ; se rechaza
	ret			;5864
L_5865:
	ld a,(0e058h)		;5865
	and 006h		;5868   ; bits 1 y 2 del plan: va a un palo
	jr z,L_5884		;586a
	ld a,(0e1bfh)		;586c
	cp 009h		;586f   ; del noveno en adelante, cualquiera
	ret nc			;5871
	ld a,(0e22bh)		;5872
	and 0f0h		;5875
	ld hl,0e059h		;5877
	xor (hl)			;587a   ; de su palo: se rechaza
	ret nz			;587b
L_587C:
	ld a,(0e22bh)		;587c   ; la rechazada vuelve al monton y otra
	call devuelve_una_copia_al_monton		;587f
	jr sortea_el_descarte_de_la_maquina		;5882
L_5884:
	ld a,(0e1bfh)		;5884
	cp 004h		;5887   ; los cuatro primeros descartes
	jr nc,L_5896		;5889
	ld a,(0e22bh)		;588b
	and 0f0h		;588e
	cp 030h		;5890   ; solo honores
	jr z,L_58A9		;5892
	jr L_587C		;5894   ; lo demas se rechaza
L_5896:
	cp 008h		;5896
	jr nc,L_58A9		;5898   ; del octavo en adelante, cualquiera
	ld a,(0e22bh)		;589a
	and 00fh		;589d
	cp 008h		;589f   ; del 4 al 7: 8 y 9 valen
	jr nc,L_58A9		;58a1
	cp 003h		;58a3   ; 1 y 2 tambien
	jr c,L_58A9		;58a5
	jr L_587C		;58a7   ; del 3 al 7 se rechaza
L_58A9:
	ret			;58a9
L_58AA:
	ld a,(0e1aeh)		;58aa
	rra			;58ad   ; en riichi, cualquiera
	ret c			;58ae
	ld a,(0e1bfh)		;58af
	cp 00fh		;58b2   ; en el descarte 15 decide si se defiende
	jr nz,L_58BA		;58b4
	call decide_si_la_maquina_se_defiende		;58b6
	ret			;58b9
L_58BA:
	ld a,(0e1bfh)		;58ba
	cp 012h		;58bd   ; en el 18
	jr nz,L_58CC		;58bf
	ld a,(0e064h)		;58c1
	rra			;58c4   ; con la semilla par
	jr c,L_58CC		;58c5
	ld a,001h		;58c7
	ld (0e340h),a		;58c9   ; a la defensa
L_58CC:
	ld a,(0e340h)		;58cc
	rra			;58cf   ; bit 0 de 0xE340: en defensa
	jr nc,cuenta_el_rio_del_1_por_palos		;58d0
	call suelta_una_ficha_segura		;58d2   ; una ficha segura de la mano
	ret			;58d5

; ----------------------------------------------------------------------
; Cuenta los descartes del 1 por palos en 0xE341-0xE344 (palo 0, 1, 2 y honores) y los terminales -unos y nueves, sin contar el este- en 0xE345; cada cuenta por debajo de dos levanta su bit en 0xE346. El primer bit puesto dice que palo NO soltar: el que el 1 menos ha descartado es el que se esta guardando. 0xE347 lleva ese palo y la candidata se rechaza mientras sea de el. El bit 4 (terminales) va a 0x595C, que esta MAL ESCRITO: el jr nz tras el cp 1 devuelve antes de mirar el 9, asi que nunca rechaza nada.
; ----------------------------------------------------------------------
cuenta_el_rio_del_1_por_palos:
	ld hl,0e341h		;58d6   ; las seis cuentas, a cero
	ld de,0e342h		;58d9
	ld (hl),000h		;58dc
	ld bc,00006h		;58de
	ldir		;58e1
	ld a,(0e1beh)		;58e3   ; tantos como descartes del 1
	ld b,a			;58e6
	ld de,0e15eh		;58e7
L_58EA:
	ld a,(de)			;58ea
	and 0f0h		;58eb   ; el palo
	jr nz,L_58F5		;58ed
	ld hl,0e341h		;58ef   ; palo 0
	inc (hl)			;58f2
	jr L_5911		;58f3
L_58F5:
	cp 010h		;58f5
	jr nz,L_58FF		;58f7
	ld hl,0e342h		;58f9   ; palo 1
	inc (hl)			;58fc
	jr L_5911		;58fd
L_58FF:
	cp 020h		;58ff
	jr nz,L_5909		;5901
	ld hl,0e343h		;5903   ; palo 2
	inc (hl)			;5906
	jr L_5911		;5907
L_5909:
	cp 030h		;5909
	jr nz,L_5911		;590b
	ld hl,0e344h		;590d   ; honores
	inc (hl)			;5910
L_5911:
	ld a,(de)			;5911
	cp 031h		;5912   ; el este no cuenta como terminal
	jr z,L_5924		;5914
	and 00fh		;5916
	cp 001h		;5918   ; los unos
	jr z,L_5920		;591a
	cp 009h		;591c   ; y los nueves
	jr nz,L_5924		;591e
L_5920:
	ld hl,0e345h		;5920
	inc (hl)			;5923   ; un terminal mas
L_5924:
	inc de			;5924
	djnz L_58EA		;5925   ; el rio entero
	ld c,001h		;5927   ; el bit 0, para el primer contador
	ld hl,0e341h		;5929
	ld de,0e346h		;592c
	ld b,005h		;592f   ; cinco contadores
L_5931:
	ld a,(hl)			;5931
	cp 002h		;5932   ; menos de dos: bit puesto
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
	bit 0,(hl)		;5942   ; palo 0 poco soltado: no se suelta
	jr nz,L_5971		;5944
	ld a,010h		;5946
	bit 1,(hl)		;5948   ; palo 1
	jr nz,L_5971		;594a
	ld a,020h		;594c
	bit 2,(hl)		;594e   ; palo 2
	jr nz,L_5971		;5950
	ld a,030h		;5952
	bit 3,(hl)		;5954   ; honores
	jr nz,L_5971		;5956
	bit 4,(hl)		;5958   ; terminales
	jr z,L_5987		;595a
L_595C:
	ld a,(0e22bh)		;595c   ; ERRATA: con un 1 sale por el jr nz del cp 9, con lo demas por el primero; nunca llega al sorteo
	and 00fh		;595f
	cp 001h		;5961
	jr nz,L_5987		;5963
	cp 009h		;5965
	jr nz,L_5987		;5967
	call devuelve_la_copia_de_e22b		;5969
	call sortea_el_descarte_a_e22b		;596c
	jr L_595C		;596f
L_5971:
	ld (0e347h),a		;5971   ; 0xE347: el palo que no se suelta
	ld a,(0e22bh)		;5974
	and 0f0h		;5977
	ld hl,0e347h		;5979
	xor (hl)			;597c   ; la candidata es de ese palo
	jr nz,L_5987		;597d
	call devuelve_la_copia_de_e22b		;597f   ; vuelve al monton
	call sortea_el_descarte_a_e22b		;5982   ; y otra
	jr L_5971		;5985
L_5987:
	ret			;5987
devuelve_la_copia_de_e22b:
	ld a,(0e22bh)		;5988   ; la ficha sorteada, de vuelta al monton
	call devuelve_una_copia_al_monton		;598b
	ret			;598e

; ----------------------------------------------------------------------
; Sortea el descarte de la maquina (0x583C) y, mientras sea una de sus esperas (0x576E), lo devuelve al monton y sortea otro: la maquina nunca suelta una ficha que le sirva. Lo llaman 0x5141 (cuando reparte el 2, su primer descarte), 0x5577 (cada descarte) y 0x56A5 (una robada que ganaria antes de tiempo).
; ----------------------------------------------------------------------
sortea_hasta_que_no_sea_espera:
	call sortea_el_descarte_de_la_maquina		;598f   ; el descarte candidato
	ld a,(0e22bh)		;5992
	call busca_en_las_esperas_del_2		;5995   ; es una de sus esperas?
	cp (hl)			;5998
	jr nz,L_59A3		;5999   ; no: vale
	ld a,(0e22bh)		;599b
	call devuelve_una_copia_al_monton		;599e   ; si: al monton y otro
	jr sortea_hasta_que_no_sea_espera		;59a1
L_59A3:
	ret			;59a3

; ----------------------------------------------------------------------
; Una copia menos repartida del tipo de la ficha A en la tabla de 0xE186 (la que 0x4F8A sube al repartir): por la tabla inversa de 0x59B3 saca el indice 0..33 y baja el contador. Es lo que hace que una ficha sorteada y rechazada, o la robada que la maquina pisa cada turno, pueda volver a salir.
; ----------------------------------------------------------------------
devuelve_una_copia_al_monton:
	ld hl,059b3h		;59a4   ; el indice 0..33 por la tabla inversa
	call suma_a_a_hl		;59a7
	ld a,(hl)			;59aa
	ld hl,0e186h		;59ab
	call suma_a_a_hl		;59ae   ; su contador de copias repartidas
	dec (hl)			;59b1   ; una menos
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



; ----------------------------------------------------------------------
; En el descarte 15: 0xE340 = 1 (defensa) si el 1 esta en riichi con esperas (0xE1CD = 0x81) y ademas su turno de riichi es tardio (0xE33D de 15 en adelante), o el 1 ha soltado pocos honores o terminales (bits 3 y 4 de 0xE346), o el plan no tiene bits altos (0xE058 & 0xF8). Si no, 0. En defensa la maquina ni gana ni declara riichi (0x567E, 0x577D).
; ----------------------------------------------------------------------
decide_si_la_maquina_se_defiende:
	ld a,(0e1cdh)		;59eb
	cp 081h		;59ee   ; 0x81: el 1 en riichi y con esperas
	jr nz,L_5A07		;59f0
	ld a,(0e33dh)		;59f2
	cp 00fh		;59f5   ; turno de riichi tardio: defensa
	jr nc,L_5A0A		;59f7
	ld a,(0e346h)		;59f9
	and 018h		;59fc   ; pocos honores o terminales soltados: defensa
	jr nz,L_5A0A		;59fe
	ld a,(0e058h)		;5a00
	and 0f8h		;5a03   ; plan sin bits altos: defensa
	jr z,L_5A0A		;5a05
L_5A07:
	xor a			;5a07   ; no hay que defenderse
	jr L_5A0C		;5a08
L_5A0A:
	ld a,001h		;5a0a   ; 1: defensa
L_5A0C:
	ld (0e340h),a		;5a0c
	ret			;5a0f

; ----------------------------------------------------------------------
; EN DEFENSA: busca en la mano del 2 una ficha que ya este en el rio del 1 -segura, por furiten- y la suelta de verdad: 0xE22B = esa, en su hueco entra una sorteada nueva y la mano se reordena. Si no hay ninguna, 0x5A2B sortea el descarte como siempre.
; ----------------------------------------------------------------------
suelta_una_ficha_segura:
	ld a,(0e208h)		;5a10   ; las fichas de su mano
	ld b,a			;5a13
	ld de,0e14ch		;5a14
L_5A17:
	push bc			;5a17
	ld a,(0e1beh)		;5a18   ; contra todo el rio del 1
	inc a			;5a1b
	ld b,a			;5a1c
	ld hl,0e15eh		;5a1d
L_5A20:
	ld a,(de)			;5a20
	cp (hl)			;5a21   ; esta en el rio: segura
	jr z,L_5A32		;5a22
	inc hl			;5a24
	djnz L_5A20		;5a25
	inc de			;5a27
	pop bc			;5a28
	djnz L_5A17		;5a29
sortea_el_descarte_a_e22b:
	call reparte_una_ficha		;5a2b   ; sin ninguna segura: una sorteada
	ld (0e22bh),a		;5a2e
	ret			;5a31
L_5A32:
	pop bc			;5a32
	ld (0e22bh),a		;5a33   ; la segura, al descarte
	call reparte_una_ficha		;5a36   ; y una nueva en su hueco
	ld (de),a			;5a39
	ld a,(0e208h)		;5a3a
	inc a			;5a3d
	ld b,a			;5a3e
	ld hl,0e14ch		;5a3f
	call L_4F9B		;5a42   ; la mano reordenada
	ret			;5a45

; ----------------------------------------------------------------------
; EL SUBMODO 3 ARRANCA AQUI (0x42B2): la fuente katakana, la barra de arriba, la cabecera del recuento (0x7097), el marcador de la mano (0x5A67) y la marca del riichi del ganador (0xE1CD para el 1, 0xE1AE para el 2): 0x7018 sin riichi, 0x701E con el.
; ----------------------------------------------------------------------
monta_la_pantalla_del_recuento:
	call pinta_la_fuente_katakana		;5a46   ; la fuente katakana
	call pinta_la_barra_de_arriba		;5a49
	call monta_la_cabecera_del_recuento		;5a4c   ; la cabecera: la mano ganadora
	call pinta_el_marcador_de_la_mano		;5a4f   ; ronda y reparto
	ld a,(0e302h)		;5a52
	bit 1,a		;5a55   ; bit 1 de 0xE302: gana el 2
	ld de,0e1cdh		;5a57   ; el riichi del 1
	jr z,L_5A5F		;5a5a
	ld de,0e1aeh		;5a5c   ; o el del 2
L_5A5F:
	ld a,(de)			;5a5f
	rra			;5a60   ; bit 0: en riichi
	jp nc,pinta_la_marca_a		;5a61   ; sin riichi, la marca a
	jp pinta_la_marca_b		;5a64   ; con riichi, la marca b

; ----------------------------------------------------------------------
; El panel de la ronda: la lista de 0x5A8E y luego uno de los cuatro contadores segun el bit 0 de 0xE04C (este/sur) y el de 0xE04D (reparte el 1 o el 2): 0x5AB6 y 0x5AC4 en el este, 0x5AD2 y 0x5AE0 en el sur. Lo llaman 0x4C6C y 0x5A4F.
; ----------------------------------------------------------------------
pinta_el_marcador_de_la_mano:
	ld hl,05a8eh		;5a67
	call L_409D		;5a6a   ; el panel
	ld hl,0e04ch		;5a6d
	ld a,(hl)			;5a70
	inc hl			;5a71
	rra			;5a72   ; bit 0 de 0xE04C: sur
	jr nc,L_5A81		;5a73
	ld a,(hl)			;5a75
	rra			;5a76   ; bit 0 de 0xE04D: reparte el 2
	ld hl,05ad2h		;5a77   ; sur, reparte el 1
	jr nc,L_5A8B		;5a7a
	ld hl,05ae0h		;5a7c   ; sur, reparte el 2
	jr L_5A8B		;5a7f
L_5A81:
	ld a,(hl)			;5a81
	rra			;5a82   ; este: reparte el 2?
	ld hl,05ab6h		;5a83   ; este, reparte el 1
	jr nc,L_5A8B		;5a86
	ld hl,05ac4h		;5a88   ; este, reparte el 2
L_5A8B:
	jp L_409D		;5a8b

; ----------------------------------------------------------------------
; DATOS panel_de_la_ronda: Formato A desde 0x5A6A: EL PANEL FIJO DE LA BARRA,
;   seis destinos: 局 (kyoku, la mano; tiles CC D2 / CD D3 en las filas 10-11,
;   columna 14), ドラ (dora: D8 DE) dos veces en la fila 10 (columnas 17 y 20),
;   ウラ (ura: D9 DE) en la fila 9 encima de la segunda, y 本場 (honba: 72 7E 7F /
;   73 78 84 85 / 79 8A 8B) en las filas 12-14, columnas 12-15. El viento y el
;   numero de la mano los pone al lado uno de los cuatro contadores de 0x5AB6.
;   Leido dibujando la VRAM (tools/pantalla.py sobre los volcados de
;   tools/omsx_vuelca_vram.tcl).
;   0x5a8e..0x5ab6  (40 bytes)
DATA_panel_de_la_ronda:
	defb 034h,039h,0d9h,0deh,0feh,04eh,039h,0cch,0d2h,001h,0d8h,0deh,001h,0d8h,0deh,0feh	; 5a8e  49...N9.........
	defb 06eh,039h,0cdh,0d3h,0feh,08dh,039h,072h,07eh,07fh,0feh,0ach,039h,073h,078h,084h	; 5a9e  n9....9r~...9sx.
	defb 085h,0feh,0cdh,039h,079h,08ah,08bh,0ffh	; 5aae  ...9y...

; ----------------------------------------------------------------------
; DATOS indicador_este_1: Formato A: 東一 (este, primera mano) en dos kanji de
;   16x16, tiles A8 AE 9C A2 / A9 AF 9D A3 en las filas 10-11, columna 10; con
;   el 局 del panel de 0x5A8E forma 東一局. Lo elige 0x5A67 con 0xE04C (ronda: bit
;   0 = sur) y 0xE04D (bit 0 = reparte el 2).
;   0x5ab6..0x5ac4  (14 bytes)
DATA_indicador_este_1:
	defb 04ah,039h,0a8h,0aeh,09ch,0a2h,0feh,06ah,039h,0a9h,0afh,09dh,0a3h,0ffh	; 5ab6  J9.....j9.....

; ----------------------------------------------------------------------
; DATOS indicador_este_2: Formato A: 東二 (este, segunda mano: reparte el 2),
;   tiles A8 AE 90 96 / A9 AF 91 97 en el mismo sitio.
;   0x5ac4..0x5ad2  (14 bytes)
DATA_indicador_este_2:
	defb 04ah,039h,0a8h,0aeh,090h,096h,0feh,06ah,039h,0a9h,0afh,091h,097h,0ffh	; 5ac4  J9.....j9.....

; ----------------------------------------------------------------------
; DATOS indicador_sur_1: Formato A: 南一 (sur, primera mano), tiles B4 BA 9C A2
;   / B5 BB 9D A3.
;   0x5ad2..0x5ae0  (14 bytes)
DATA_indicador_sur_1:
	defb 04ah,039h,0b4h,0bah,09ch,0a2h,0feh,06ah,039h,0b5h,0bbh,09dh,0a3h,0ffh	; 5ad2  J9.....j9.....

; ----------------------------------------------------------------------
; DATOS indicador_sur_2: Formato A: 南二 (sur, segunda mano, la ultima de la
;   partida: la que enciende オーラス en 0x4C92), tiles B4 BA 90 96 / B5 BB 91 97.
;   0x5ae0..0x5aee  (14 bytes)
DATA_indicador_sur_2:
	defb 04ah,039h,0b4h,0bah,090h,096h,0feh,06ah,039h,0b5h,0bbh,091h,097h,0ffh	; 5ae0  J9.....j9.....

; ======================================================================
; CODIGO 0x5aee..0x5c97  (425 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; EL DESPACHADOR DEL RECUENTO, el submodo 5. Los bits de 0xE1C8 dicen por donde va, y 0x5B51 los va desplazando a la derecha al acabar cada paso, asi que el orden es de arriba abajo: bit 4 las figuras y sus fu (0x7176), bit 3 la espera y la base (0x72B8), bit 2 la suma de fu (0x7320), bit 1 el total (0x7356) y bit 0 las jugadas y el pago (0x5B01).
; ----------------------------------------------------------------------
canta_la_jugada:
	ld a,(0e1c8h)		;5aee
	rra			;5af1   ; bit 0: las jugadas y el pago
	jr c,escribe_las_jugadas_y_paga		;5af2
	rra			;5af4
	jp c,escribe_el_total_de_fu		;5af5   ; bit 1: el total de fu
	rra			;5af8
	jr c,suma_los_fu_del_recuento		;5af9   ; bit 2: la suma de fu
	rra			;5afb
	jr c,espera_y_base_del_recuento		;5afc   ; bit 3: la espera y los fu de base
	rra			;5afe
	jr c,figuras_del_recuento		;5aff   ; bit 4: las figuras

; ----------------------------------------------------------------------
; Escribe un nombre por llamada (0x70BF) y, cuando el bit 2 de 0xE1A8 cae, CALCULA EL PAGO. Cuenta en 0xE127 los yakuman de la lista (indices 1-11); si hay alguno, 0x5B57 paga tantas manos maximas como haya. Si no: de 5 han en adelante, la mano limite por 0x5B6B; con menos, la fila de los fu (0x5C5A) en la tabla del que reparte o del otro (0xE04E), y en ella la columna del han. 100 fu o mas se pagan como 8 han.
; ----------------------------------------------------------------------
escribe_las_jugadas_y_paga:
	call escribe_una_jugada		;5b01   ; un nombre por llamada
	ld a,(0e1a8h)		;5b04
	bit 2,a		;5b07   ; hasta que esten todos escritos
	ret nz			;5b09
	ld hl,0e127h		;5b0a
	ld (hl),000h		;5b0d   ; la cuenta de yakuman
	ld de,0e305h		;5b0f
	ld b,020h		;5b12
L_5B14:
	ld a,(de)			;5b14
	dec a			;5b15
	cp 00bh		;5b16   ; indices 1 a 11: yakuman
	jr nc,L_5B1E		;5b18
	inc (hl)			;5b1a
	inc de			;5b1b
	djnz L_5B14		;5b1c
L_5B1E:
	ld a,(hl)			;5b1e
	or a			;5b1f
	jr nz,paga_los_yakuman		;5b20   ; alguno: mano maxima
	ld a,(0e316h)		;5b22
	cp 005h		;5b25   ; de 5 han en adelante, mano limite
	jp nc,paga_la_mano_limite		;5b27
	call fila_de_los_fu		;5b2a   ; la fila de los fu
	cp 008h		;5b2d   ; 8, cien fu o mas: se paga como 8 han
	jp z,paga_la_mano_limite		;5b2f
	ld a,(0e04eh)		;5b32
	rra			;5b35   ; bit 0 de 0xE04E: gana el que no reparte
	ld hl,05c97h		;5b36   ; la tabla del que reparte
	jr nc,L_5B3E		;5b39
	ld hl,05ca9h		;5b3b   ; o la del otro
L_5B3E:
	call entra_en_la_tabla		;5b3e   ; la fila y la columna
	jr carga_el_pago		;5b41
suma_los_fu_del_recuento:
	jp suma_los_fu		;5b43
espera_y_base_del_recuento:
	call limpia_el_borrador		;5b46
	call pinta_la_espera_y_los_fu_base		;5b49
	jr siguiente_paso_del_recuento		;5b4c
figuras_del_recuento:
	jp pinta_una_figura_y_sus_fu		;5b4e

; ----------------------------------------------------------------------
; Desplaza 0xE1C8 un bit a la derecha: el paso siguiente del recuento.
; ----------------------------------------------------------------------
siguiente_paso_del_recuento:
	ld hl,0e1c8h		;5b51
	srl (hl)		;5b54
	ret			;5b56

; ----------------------------------------------------------------------
; Tantas manos maximas como yakuman: 0xE1B3 = cuantos, y (cuantos-1)*2 entra en la tabla del que reparte (0x5D6F: 48.000, 96.000...) o del otro (0x5D79: 32.000, 64.000...).
; ----------------------------------------------------------------------
paga_los_yakuman:
	ld (0e1b3h),a		;5b57   ; 0xE1B3 = cuantos yakuman
	dec a			;5b5a
	add a,a			;5b5b
	ld hl,0e04eh		;5b5c
	bit 0,(hl)		;5b5f   ; bit 0 de 0xE04E
	ld hl,05d6fh		;5b61   ; la tabla del que reparte
	jr z,carga_el_pago		;5b64
	ld hl,05d79h		;5b66   ; o la del otro
	jr carga_el_pago		;5b69

; ----------------------------------------------------------------------
; De 5 han en adelante: se recortan a 13, se les quitan 4 (0xE1B4 = 1 a 9) y con eso se entra en los topes de 0x5D4B (reparte: 12.000, 18.000, 18.000, 24.000, 24.000, 24.000, 36.000 x3) o de 0x5D5D. Mangan, haneman, baiman y sanbaiman.
; ----------------------------------------------------------------------
paga_la_mano_limite:
	cp 00dh		;5b6b
	jr c,L_5B71		;5b6d   ; 13 como mucho
	ld a,00dh		;5b6f
L_5B71:
	sub 004h		;5b71   ; menos cuatro: 1 a 9
	ld (0e1b4h),a		;5b73   ; 0xE1B4 = el escalon de la mano limite
	dec a			;5b76
	add a,a			;5b77
	ld hl,0e04eh		;5b78
	bit 0,(hl)		;5b7b
	ld hl,05d4bh		;5b7d   ; la tabla del que reparte
	jr z,carga_el_pago		;5b80
	ld hl,05d5dh		;5b82   ; o la del otro

; ----------------------------------------------------------------------
; Lee la palabra que toca (0x5C7F le suma 300 por honba), la deja en los dos pendientes de 0x5DF9 -0xE1B1, lo que paga el perdedor, y 0xE1E4, lo que cobra el ganador- y la pinta en 0x38E8. Si es TSUMO (bit 0 de 0xE1D1) vuelve a sacarla de las tablas "al robar" -0x5DEF para los yakuman, 0x5DDD para la mano limite y 0x5D83 para el resto, con 100 por honba- y la deja SOLO en 0xE1B1: el perdedor paga la parte de un jugador y el ganador cobra la cifra entera del ron. La pantalla del recuento imprime las dos, HARAI (lo pagado) y TOKUTEN (lo cobrado). Medido en el demo: 6.000 y 18.000.
; ----------------------------------------------------------------------
carga_el_pago:
	call lee_el_pago_con_honba		;5b85   ; la palabra, mas 300 por honba
	ld (0e1b1h),de		;5b88   ; los dos pendientes del pago
	ld (0e1e4h),de		;5b8c
	ld de,038e8h		;5b90   ; 0x38E8: donde se pinta
	ld hl,0e1e5h		;5b93
	ld b,003h		;5b96   ; tres bytes: seis cifras
	call pinta_un_numero_bcd		;5b98
	ld a,(0e1d1h)		;5b9b
	rra			;5b9e   ; con ron, los dos pendientes iguales: se paga lo que se cobra
	ret nc			;5b9f
	ld a,(0e1b3h)		;5ba0
	or a			;5ba3   ; tsumo con yakuman: por 0x5BCD
	jr nz,L_5BCD		;5ba4
	ld a,(0e1b4h)		;5ba6
	or a			;5ba9   ; tsumo con mano limite: por 0x5BD4
	jr nz,L_5BD4		;5baa
	call fila_de_los_fu		;5bac   ; la fila de los fu otra vez
	ld hl,05d83h		;5baf   ; la tabla del tsumo
	call entra_en_la_tabla		;5bb2
L_5BB5:
	call suma_a_a_hl		;5bb5   ; la palabra
	ld e,(hl)			;5bb8
	inc hl			;5bb9
	ld d,(hl)			;5bba
	ld a,(0e04bh)		;5bbb   ; mas 100 por honba
	add a,e			;5bbe
	daa			;5bbf   ; en BCD
	ld e,a			;5bc0
	jr nc,L_5BC8		;5bc1
	ld a,d			;5bc3
	add a,001h		;5bc4
	daa			;5bc6
	ld d,a			;5bc7
L_5BC8:
	ld (0e1b1h),de		;5bc8   ; solo el pendiente del perdedor; el ganador sigue cobrando lo de 0xE1E4
	ret			;5bcc
L_5BCD:
	dec a			;5bcd
	add a,a			;5bce
	ld hl,05defh		;5bcf   ; tsumo con yakuman: 16.000, 32.000...
	jr L_5BD9		;5bd2
L_5BD4:
	dec a			;5bd4
	add a,a			;5bd5
	ld hl,05dddh		;5bd6   ; tsumo con mano limite: 4.000, 6.000, 6.000, 8.000...
L_5BD9:
	jr L_5BB5		;5bd9

; ----------------------------------------------------------------------
; EL TIPO DE ESPERA, primera parte. Con la ficha que cierra (0xE1E8) en un extremo de alguna escalera: si el otro extremo es un uno o un nueve la escalera es 1-2-3 o 7-8-9 y la espera era de borde, PENCHAN (bit 2 de 0xE1D2, 2 fu); si no, RYANMEN (bit 0, 0 fu), y con una sola escalera ryanmen basta. Con un honor no hay nada que mirar.
; ----------------------------------------------------------------------
espera_ryanmen_o_penchan:
	ld a,(0e1e8h)		;5bdb
	ld c,a			;5bde   ; la ficha que cierra
	cp 030h		;5bdf
	ret nc			;5be1   ; un honor no esta en ninguna escalera
	ld a,(0e2c8h)		;5be2
	or a			;5be5
	ret z			;5be6   ; sin escaleras
	ld b,a			;5be7
	ld de,0e2b7h		;5be8
L_5BEB:
	ld a,(de)			;5beb
	ld h,a			;5bec
	inc de			;5bed
	inc de			;5bee
	cp c			;5bef   ; es la primera de la escalera?
	ld a,(de)			;5bf0
	jr z,L_5C0F		;5bf1
	cp c			;5bf3   ; o la tercera?
	jr nz,L_5C00		;5bf4
	ld a,h			;5bf6
	and 00fh		;5bf7
	dec a			;5bf9   ; la escalera empieza en 1: espera de borde
	jr nz,L_5C15		;5bfa
L_5BFC:
	ld hl,0e127h		;5bfc   ; una espera de borde mas
	inc (hl)			;5bff
L_5C00:
	inc de			;5c00
	inc de			;5c01
	djnz L_5BEB		;5c02
	ld a,(0e127h)		;5c04
	or a			;5c07   ; ninguna
	ret z			;5c08
	ld hl,0e1d2h		;5c09
	set 2,(hl)		;5c0c   ; bit 2: PENCHAN
	ret			;5c0e
L_5C0F:
	and 00fh		;5c0f
	cp 009h		;5c11   ; la escalera acaba en 9: espera de borde
	jr z,L_5BFC		;5c13
L_5C15:
	ld hl,0e1d2h		;5c15
	set 0,(hl)		;5c18   ; bit 0: RYANMEN, y ya esta
	ret			;5c1a

; ----------------------------------------------------------------------
; Segunda parte, si la primera no dijo nada: la ficha que cierra es la de EN MEDIO de alguna escalera, KANCHAN (bit 1 de 0xE1D2, 2 fu).
; ----------------------------------------------------------------------
espera_kanchan:
	ld a,(0e1d2h)		;5c1b
	or a			;5c1e   ; ya hay espera
	ret nz			;5c1f
	ld a,(0e1e8h)		;5c20
	ld c,a			;5c23
	cp 030h		;5c24
	ret nc			;5c26
	ld a,(0e2c8h)		;5c27
	or a			;5c2a
	ret z			;5c2b
	ld b,a			;5c2c
	ld de,0e2b8h		;5c2d   ; la ficha de en medio de cada escalera
L_5C30:
	ld a,(de)			;5c30
	cp c			;5c31   ; la de en medio es la que cierra?
	jr z,L_5C3C		;5c32
	ld a,004h		;5c34   ; cuatro bytes por escalera
	call suma_a_a_de		;5c36
	djnz L_5C30		;5c39
	ret			;5c3b
L_5C3C:
	ld hl,0e1d2h		;5c3c
	set 1,(hl)		;5c3f   ; bit 1: KANCHAN
	ret			;5c41

; ----------------------------------------------------------------------
; Tercera parte: la ficha que cierra es la pareja, TANKI (bit 3, 2 fu), o no, y entonces cerro un trio: SHANPON (bit 4, 0 fu).
; ----------------------------------------------------------------------
espera_tanki_o_shanpon:
	ld a,(0e1d2h)		;5c42
	or a			;5c45
	ret nz			;5c46
	ld a,(0e1e8h)		;5c47
	ld c,a			;5c4a
	ld a,(0e300h)		;5c4b
	cp c			;5c4e   ; es la pareja?
	ld hl,0e1d2h		;5c4f
	jr z,L_5C57		;5c52
	set 4,(hl)		;5c54   ; bit 4: SHANPON
	ret			;5c56
L_5C57:
	set 3,(hl)		;5c57   ; bit 3: TANKI
	ret			;5c59

; ----------------------------------------------------------------------
; La fila de la tabla de pago a partir de los fu de 0xE1E1/0xE1E2: con el byte alto a cero, la decena menos dos (20 = 0, 30 = 1, hasta 90 = 7); con 100 o mas, 8.
; ----------------------------------------------------------------------
fila_de_los_fu:
	ld de,(0e1e1h)		;5c5a
	ld a,d			;5c5e
	or a			;5c5f   ; cien fu o mas
	jr z,L_5C65		;5c60
	ld a,008h		;5c62   ; fila 8
	ret			;5c64
L_5C65:
	srl e		;5c65   ; la decena
	srl e		;5c67
	srl e		;5c69
	srl e		;5c6b
	dec e			;5c6d   ; menos dos: 20 fu es la fila 0
	dec e			;5c6e
	ret			;5c6f

; ----------------------------------------------------------------------
; Con E = fila y HL = tabla de punteros, deja HL en la fila y A = (han-1)*2, la columna. Cae en 0x5C7F.
; ----------------------------------------------------------------------
entra_en_la_tabla:
	ld a,e			;5c70
	add a,a			;5c71   ; dos bytes por puntero
	call suma_a_a_hl		;5c72
	ld e,(hl)			;5c75
	inc hl			;5c76
	ld d,(hl)			;5c77
	ex de,hl			;5c78
	ld a,(0e316h)		;5c79   ; los han
	dec a			;5c7c
	add a,a			;5c7d   ; menos uno, por dos: la columna
	ret			;5c7e

; ----------------------------------------------------------------------
; Lee la palabra de HL+A y le suma TRES VECES los honba de 0xE04B, en BCD: 300 puntos por honba, en centenas.
; ----------------------------------------------------------------------
lee_el_pago_con_honba:
	call suma_a_a_hl		;5c7f
	ld e,(hl)			;5c82
	inc hl			;5c83
	ld d,(hl)			;5c84
	ld a,(0e04bh)		;5c85   ; los honba
	ld c,a			;5c88
	add a,a			;5c89   ; por dos
	daa			;5c8a
	adc a,c			;5c8b   ; mas uno: por tres
	daa			;5c8c
	adc a,e			;5c8d   ; y a la palabra, en BCD
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
; EL PAGO, cien puntos por fotograma, Y EL CIERRE DE LA MANO. Lleva DOS pendientes en paralelo, contadores BCD de dos bytes que cuentan PASOS DE CIEN (los 0x0120 y 0x0080 que carga 0x4290 son 12.000 y 8.000): 0xE1B1 es lo que PAGA el perdedor y 0xE1E4 lo que COBRA el ganador, y no tienen por que coincidir. Con ron son iguales; con tsumo 0x5B9B deja en 0xE1B1 la parte de un solo jugador y en 0xE1E4 la cifra entera del ron, asi que el ganador cobra mas de lo que el otro paga. MEDIDO en el demo (volcados 040 y 042 del paso 2): 0xE1B1 = 0x0060 y 0xE1E4 = 0x0180, 6.000 pagados y 18.000 cobrados, y los marcadores acaban en 23.000 y 48.000: por eso no suman 60.000. Cada fotograma mueve cien y baja el pendiente con 0x5F18; quien cobra y quien paga sale de 0xE302, 0xE1AC y 0xE1AD; el segundo pendiente ademas suena cada cuatro fotogramas, el tintineo del recuento. Cuando los dos llegan a cero (0x5E70) viene el resto: en el demo (bit 6 de 0xE002 a cero) directo a 0x5F00, fin de partida; con persona, los palos de riichi de la mesa (0xE04A) van al ganador de mil en mil, uno cada 32 fotogramas, pero SOLO si estaba en riichi (bit 0 de 0xE1CD el 1, de 0xE1AE el 2) o si es el 1 ganando en la mano que cierra la partida (sur y reparte el 2); si no, se quedan en la mesa. Luego 0x5ED0 decide reparto, honba y ronda: gana el que reparte, un honba mas y sigue; gana el otro, honba a cero y cambia el reparto (0x77F7) o, si ya repartia el 2, la ronda; y si la ronda era la del sur, bit 4 de 0xE1A8, se acabo la partida. 0xE062, las manos seguidas sin ganar el 1, sube si gana el 2 y vuelve a cero si gana el 1.
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
	jr nc,L_5E1D		;5e0c   ; sin el bit 1 gano el jugador 1: paga el 2
	jr L_5E22		;5e0e
L_5E10:
	ld a,(0e1ach)		;5e10
	and 0c0h		;5e13
	jr nz,L_5E22		;5e15   ; con castigo (bits 7 y 6 de 0xE1AC) paga siempre el 1
	ld a,(0e1adh)		;5e17
	rra			;5e1a
	jr nc,L_5E22		;5e1b   ; bit 0 de 0xE1AD: el 1 esta en tenpai y cobra, paga el 2
L_5E1D:
	call resta_del_marcador_de_e044		;5e1d   ; paga el jugador 2, el de 0xE044
	jr L_5E25		;5e20
L_5E22:
	call resta_del_marcador_de_e047		;5e22   ; paga el jugador 1, el de 0xE047
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
	call pide_un_sonido		;5e3e   ; sonido 2: el tintineo de las fichas de puntos
L_5E41:
	ld de,00100h		;5e41
	ld a,(0e302h)		;5e44   ; lo mismo que arriba: quien cobra
	bit 2,a		;5e47   ; bit 2: sin ganador, el tenpai
	jr nz,L_5E51		;5e49
	rra			;5e4b
	rra			;5e4c
	jr nc,L_5E5E		;5e4d   ; sin el bit 1 cobra el 1
	jr L_5E63		;5e4f
L_5E51:
	ld a,(0e1ach)		;5e51
	and 0c0h		;5e54   ; con castigo cobra el 2
	jr nz,L_5E63		;5e56
	ld a,(0e1adh)		;5e58
	rra			;5e5b   ; bit 0 de 0xE1AD: el 1 en tenpai, cobra el
	jr nc,L_5E63		;5e5c
L_5E5E:
	call suma_al_marcador_de_e047		;5e5e   ; y cobra el jugador 1, el de 0xE047
	jr L_5E66		;5e61
L_5E63:
	call suma_al_marcador_de_e044		;5e63   ; o el 2, el de 0xE044
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
	and 005h		;5e7b   ; bits 0 o 2 de 0xE302, sin ganador: no hay palos que cobrar
	jr nz,L_5ED0		;5e7d
	ld hl,0e04ah		;5e7f
	ld a,(hl)			;5e82
	or a			;5e83   ; 0xE04A: los palos de riichi que hay en la mesa; ninguno, a 0x5ED0
	jr z,L_5ED0		;5e84
	ld a,(0e003h)		;5e86
	and 01fh		;5e89   ; uno cada 32 fotogramas
	ret nz			;5e8b
	ld a,(0e302h)		;5e8c
	bit 1,a		;5e8f   ; bit 1 de 0xE302: ha ganado el 2
	jr nz,L_5EA4		;5e91
	ld a,(0e04ch)		;5e93
	rra			;5e96   ; bit 0 de 0xE04C: ronda del sur
	jr nc,L_5E9F		;5e97
	ld a,(0e04dh)		;5e99
	rra			;5e9c   ; y reparte el 2: la mano que cierra la partida, el 1 se lleva los palos este o no en riichi
	jr c,L_5EAA		;5e9d
L_5E9F:
	ld a,(0e1cdh)		;5e9f   ; el 1: bit 0 de 0xE1CD, su riichi
	jr L_5EA7		;5ea2
L_5EA4:
	ld a,(0e1aeh)		;5ea4   ; el 2: bit 0 de 0xE1AE, el suyo
L_5EA7:
	rra			;5ea7
	jr nc,L_5ED0		;5ea8   ; sin riichi, los palos se quedan en la mesa
L_5EAA:
	ld a,(hl)			;5eaa
	sub 001h		;5eab   ; un palo menos, en BCD
	daa			;5ead
	ld (hl),a			;5eae
	call pinta_el_contador_de_e04a		;5eaf   ; y el contador repintado
	ld a,002h		;5eb2
	call pide_un_sonido		;5eb4   ; sonido 2
	ld b,00ah		;5eb7   ; diez veces cien: los mil puntos del palo
L_5EB9:
	push bc			;5eb9
	ld de,00100h		;5eba
	ld a,(0e302h)		;5ebd
	bit 1,a		;5ec0   ; al marcador del ganador: 0xE047 el 1, 0xE044 el 2
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
	and 005h		;5ed3   ; sin ganador no hay nada que decidir aqui: reparto y honba los movio 0x77CD
	jr nz,L_5F12		;5ed5
	ld a,(0e302h)		;5ed7
	rra			;5eda
	rra			;5edb   ; el bit 1 al acarreo: quien ha ganado
	ld hl,0e062h		;5edc
	jr nc,L_5EF2		;5edf
	inc (hl)			;5ee1   ; gana el 2: una mano mas sin ganar el 1
	ld a,(0e04dh)		;5ee2
	rra			;5ee5   ; bit 0 de 0xE04D: reparte el 2
	jr c,L_5F0F		;5ee6
	ld hl,0e04bh		;5ee8
	ld (hl),000h		;5eeb   ; repartia el 1: honba a cero
	call cambia_el_reparto		;5eed   ; y el reparto pasa al 2
	jr L_5F12		;5ef0
L_5EF2:
	ld (hl),000h		;5ef2   ; gana el 1: 0xE062 a cero, y con el la siembra de 0x48E1
	ld a,(0e04dh)		;5ef4
	rra			;5ef7   ; repartia el 1: un honba mas
	jr nc,L_5F0F		;5ef8
	ld a,(0e04ch)		;5efa
	rra			;5efd   ; repartia el 2 en el este: cambia la ronda
	jr nc,L_5F05		;5efe
L_5F00:
	ld hl,0e1a8h		;5f00
	set 4,(hl)		;5f03   ; en el sur: bit 4 de 0xE1A8, FIN DE LA PARTIDA; el demo entra aqui directo desde 0x5E75
L_5F05:
	ld hl,0e04bh		;5f05
	ld (hl),000h		;5f08   ; honba a cero
	call cambia_la_ronda		;5f0a   ; y la ronda cambia, con el reparto
	jr L_5F12		;5f0d
L_5F0F:
	call suma_un_honba		;5f0f   ; el que reparte ha ganado: un honba mas y sigue repartiendo
L_5F12:
	ld hl,0e1a8h		;5f12
	res 3,(hl)		;5f15   ; bit 3 de 0xE1A8: el pago ha terminado
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
	ld de,00100h		;5f27   ; cien
	call resta_del_marcador_de_e047		;5f2a
	pop bc			;5f2d
	djnz L_5F26		;5f2e   ; diez veces
	ret			;5f30

; ----------------------------------------------------------------------
; La gemela de 0x5F24 para el marcador de 0xE044: diez vueltas de cien puntos.
; ----------------------------------------------------------------------
cobra_mil_el_de_e044:
	ld b,00ah		;5f31
L_5F33:
	push bc			;5f33
	ld de,00100h		;5f34   ; cien
	call resta_del_marcador_de_e044		;5f37
	pop bc			;5f3a
	djnz L_5F33		;5f3b   ; diez veces
	ret			;5f3d

; ----------------------------------------------------------------------
; LA PUERTA DEL ANALISIS. Monta la copia ordenada de la mano en 0xE2F1 (0x5F4C), limpia las marcas y cae en el motor (0x6038 sigue en 0x6042). Al volver, el bit 0 de 0xE302 puesto significa que la mano NO esta completa; si esta limpio, 0x656D la reagrupa por figuras para el recuento. La llaman 0x505B (el jugador ha pedido agari en el menu) y 0x575A (la maquina se pregunta si ha ganado).
; ----------------------------------------------------------------------
analiza_la_mano:
	call monta_la_copia_para_el_analisis		;5f3e   ; la copia de trabajo, ordenada, en 0xE2F1
	call limpia_y_descompone		;5f41   ; limpia las marcas y cae en el motor de 0x6042
	ld a,(0e302h)		;5f44
	rra			;5f47   ; bit 0 de 0xE302 puesto: no hay descomposicion, la mano no esta completa
	ret c			;5f48
	jp reagrupa_la_mano_por_figuras		;5f49   ; completa: se reagrupa por figuras

; ----------------------------------------------------------------------
; Prepara la copia con la que trabaja el motor. Elige las variables del jugador que toca (bit 0 de 0xE206: 0 el jugador 1, 1 el 2), copia las figuras ya declaradas, limpia 0xE2F1-0xE32A, y decide de donde sale la ficha que cierra la mano: si 0xE22C esta a cero es RON y la ficha es el ultimo descarte del rival, que se mete en el hueco de la mano y se apunta en 0xE347; si no, es propia (TSUMO) y ya esta en la mano. Luego ordena las 0xE20A+1 fichas.
; ----------------------------------------------------------------------
monta_la_copia_para_el_analisis:
	ld a,(0e206h)		;5f4c   ; bit 0 de 0xE206: de quien es la mano
	rra			;5f4f
	ld a,(0e1d1h)		;5f50   ; 0xE1D1 o 0xE22A: la ficha que cierra es propia (tsumo) o del rival (ron)
	ld (0e22ch),a		;5f53
	ld a,(0e1c3h)		;5f56   ; 0xE1C3 o 0xE208: el hueco de la ficha que cierra
	ld (0e20ah),a		;5f59
	jr nc,L_5F6A		;5f5c   ; bit 0 a cero: las del jugador 1; si no, las del 2
	ld a,(0e208h)		;5f5e
	ld (0e20ah),a		;5f61
	ld a,(0e22ah)		;5f64
	ld (0e22ch),a		;5f67
L_5F6A:
	ld de,0e2feh		;5f6a   ; las figuras declaradas, tres fichas cada una, se copian a 0xE2FE hacia atras
	ld hl,0e2bah		;5f6d
	ld bc,00403h		;5f70   ; cuatro registros de cuatro bytes
	call copia_o_borra_los_registros		;5f73
	ld hl,0e2cch		;5f76
	ld bc,00403h		;5f79
	call copia_o_borra_los_registros		;5f7c
	call borra_los_cuartetos_sobrantes		;5f7f   ; y los registros de cuarteto que sobren, a cero
	ld hl,0e2f1h		;5f82   ; limpia 0xE2F1-0xE32A, la copia de trabajo, de un tiron
	ld de,0e2f2h		;5f85
	ld bc,00039h		;5f88
	ld (hl),000h		;5f8b
	ldir		;5f8d
	xor a			;5f8f   ; 0xE347 = 0: de momento no hay ficha de ron
	ld (0e347h),a		;5f90
	ld a,(0e20ah)		;5f93   ; el hueco de la ficha que cierra, en la mano de 0xE32B
	ld hl,0e32bh		;5f96
	call suma_a_a_hl		;5f99
	ld c,(hl)			;5f9c
	ld a,(0e22ch)		;5f9d   ; 0xE22C distinto de cero: la ficha es propia y ya esta en la mano
	or a			;5fa0
	jr nz,L_5FC7		;5fa1
	ld a,(0e206h)		;5fa3   ; RON: la ficha es el ultimo descarte del rival
	rra			;5fa6
	ld hl,0e172h		;5fa7   ; los descartes del rival y cuantos lleva (0xE172/0xE1BF o 0xE15E/0xE1BE)
	ld a,(0e1bfh)		;5faa
	jr nc,L_5FB5		;5fad
	ld hl,0e15eh		;5faf
	ld a,(0e1beh)		;5fb2
L_5FB5:
	call suma_a_a_hl		;5fb5
	ld c,(hl)			;5fb8   ; el ultimo descarte del rival
	ld hl,0e32bh		;5fb9
	ld a,(0e20ah)		;5fbc
	call suma_a_a_hl		;5fbf
	ld (hl),c			;5fc2   ; se mete en el hueco de la mano
	ld a,c			;5fc3
	ld (0e347h),a		;5fc4   ; y se apunta en 0xE347 como la ficha de ron
L_5FC7:
	ld hl,0e1e8h		;5fc7   ; 0xE1E8 = la ficha que cierra, que es la que mira el tipo de espera (0x5BDB)
	ld (hl),c			;5fca
	ld hl,0e32bh		;5fcb   ; copia las 0xE20A+1 fichas a 0xE2F1
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
	call L_4F9B		;5fe2   ; y las ordena de menor a mayor
	ld a,(0e347h)		;5fe5
	ld de,0e2f1h		;5fe8
	ld hl,0e2f2h		;5feb
	call L_6E6F		;5fee   ; busca cuatro iguales seguidas (vuelve con C=3 si las hay)
	ld a,c			;5ff1
	cp 003h		;5ff2   ; con cuatro iguales en la mano se borra la marca de ficha de ron
	ret nz			;5ff4
	xor a			;5ff5
	ld (0e347h),a		;5ff6
	ret			;5ff9

; ----------------------------------------------------------------------
; Recorre B registros de C+1 bytes empezando por HL, que apunta a la MARCA (el ultimo byte de cada uno): con la marca a cero borra las C fichas del registro; con la marca puesta las copia a DE hacia atras. Es lo que separa las figuras DECLARADAS, que se conservan, de las que el motor apunto por su cuenta en el analisis anterior.
; ----------------------------------------------------------------------
copia_o_borra_los_registros:
	push bc			;5ffa
	push hl			;5ffb
	xor a			;5ffc
	cp (hl)			;5ffd   ; la marca del registro
	jr nz,L_6008		;5ffe   ; puesta: figura declarada, se conserva y se copia
	dec hl			;6000
	ld b,c			;6001
L_6002:
	ld (hl),a			;6002   ; a cero: sus C fichas se borran
	dec hl			;6003
	djnz L_6002		;6004
	jr L_6010		;6006
L_6008:
	dec hl			;6008
	ld b,c			;6009
L_600A:
	ld a,(hl)			;600a   ; la copia va hacia atras, ficha a ficha
	ld (de),a			;600b
	dec hl			;600c
	dec de			;600d
	djnz L_600A		;600e
L_6010:
	pop hl			;6010
	pop bc			;6011
	ld a,l			;6012   ; al registro siguiente, C+1 bytes mas alla
	add a,c			;6013
	inc a			;6014
	ld l,a			;6015
	djnz copia_o_borra_los_registros		;6016
	ret			;6018

; ----------------------------------------------------------------------
; Deja a cero los registros de cuarteto que no esten en uso: 0xE2F0 dice cuantos hay, cada uno son cinco bytes desde 0xE2DB, y se borran los que faltan hasta cuatro.
; ----------------------------------------------------------------------
borra_los_cuartetos_sobrantes:
	ld a,(0e2f0h)		;6019   ; cuantos cuartetos hay
	ld c,a			;601c
	add a,a			;601d   ; por cinco: cuatro fichas y la marca
	add a,a			;601e
	add a,c			;601f
	ld hl,0e2dbh		;6020
	call suma_a_a_hl		;6023
	ld a,004h		;6026   ; los que faltan hasta cuatro
	sub c			;6028
	or a			;6029
	ret z			;602a
	ld b,a			;602b
L_602C:
	push bc			;602c
	ld b,005h		;602d   ; cinco bytes a cero cada uno
L_602F:
	ld (hl),000h		;602f
	inc hl			;6031
	djnz L_602F		;6032   ; los cinco bytes del registro
	pop bc			;6034
	djnz L_602C		;6035
	ret			;6037

; ----------------------------------------------------------------------
; LA ENTRADA NORMAL DEL MOTOR: pone a cero la pila de alternativas (0xE237), sus banderas (0xE239) y la clase de mano (0xE205) y CAE en 0x6042. La usan 0x5F3E y el calculo de esperas (0x6754): "call 0x6038 y mirar el bit 0 de 0xE302" es la pregunta "esta completa esta mano?".
; ----------------------------------------------------------------------
limpia_y_descompone:
	xor a			;6038
	ld (0e237h),a		;6039   ; 0xE237: cuantas copias hay guardadas para volver atras
	ld (0e239h),a		;603c   ; 0xE239: que rama probar al volver
	ld (0e205h),a		;603f   ; 0xE205: 0 normal, 1 siete parejas, 2 trece huerfanos

; ----------------------------------------------------------------------
; EL MOTOR. Mira la ficha del cursor (DE) y la siguiente (HL) y reparte: iguales -> 0x6072 (trio o pareja); la siguiente es la ficha mas uno -> escalera si la tercera es la ficha mas dos (0x6159), y si la tercera es otra copia de la mas uno, el caso enredado de 0x6216; ni igual ni seguida -> la ficha esta suelta y solo puede ser trece huerfanos (0x651D). Cada rama apunta su figura y vuelve a 0x6091, que decide si sigue.
; ----------------------------------------------------------------------
motor_de_descomposicion:
	ld hl,0e2f1h		;6042   ; DE = la ficha del cursor
	ld a,(0e304h)		;6045
	ld de,0e2f1h		;6048
	call suma_a_a_de		;604b
	ld l,e			;604e   ; HL = la siguiente
	inc l			;604f
	ld a,(de)			;6050
	cp (hl)			;6051   ; iguales: trio o pareja, por 0x6072
	jr z,L_6072		;6052
	ld a,(de)			;6054
	sub (hl)			;6055
	cp 0ffh		;6056   ; 0xFF: la siguiente es la ficha mas uno, candidata a escalera
	jr nz,L_606D		;6058   ; ni igual ni seguida: ficha suelta, solo vale para trece huerfanos
	call es_la_ficha_mas_dos		;605a   ; la tercera es la ficha mas dos: escalera hecha
	jr nz,L_6064		;605d
	call apunta_una_escalera		;605f   ; se apunta
	jr sigue_o_termina		;6062
L_6064:
	cp 0ffh		;6064   ; 0xFF: x, x+1, x+1: hay que mirar mas lejos
	jr nz,vuelta_atras		;6066   ; cualquier otra cosa no cuadra: vuelta atras
	call caso_x_x1_x1		;6068
	jr sigue_o_termina		;606b
L_606D:
	call prueba_trece_huerfanos		;606d
	jr sigue_o_termina		;6070
L_6072:
	inc hl			;6072   ; la tercera ficha
	cp (hl)			;6073
	jr nz,L_6084		;6074   ; dos iguales y la tercera distinta: pareja mas algo
	inc hl			;6076
	cp (hl)			;6077   ; tres iguales: si la cuarta tambien, por 0x62D7
	jr z,L_607F		;6078
	call caso_trio		;607a   ; tres iguales y la cuarta distinta: trio, con sus dudas
	jr sigue_o_termina		;607d
L_607F:
	call caso_cuatro_iguales		;607f
	jr sigue_o_termina		;6082
L_6084:
	sub (hl)			;6084
	cp 0ffh		;6085   ; pareja y luego la ficha mas uno: por 0x6376
	jr z,L_608E		;6087
	call prueba_siete_parejas		;6089   ; pareja y luego otra cosa: candidata a siete parejas
	jr sigue_o_termina		;608c
L_608E:
	call caso_pareja_y_siguiente		;608e

; ----------------------------------------------------------------------
; Lo que pasa despues de colocar una figura. Si el motor ya dijo que no (0xE302 = 1), vuelta atras. Si el cursor no ha llegado a la penultima ficha, otra vuelta por 0x6042; si quedan exactamente dos, tienen que ser la pareja (0x61DA); y si no queda ninguna, la mano esta completa (0x60B4).
; ----------------------------------------------------------------------
sigue_o_termina:
	ld a,(0e20ah)		;6091   ; 0xE20A+1 fichas en total
	ld b,a			;6094
	ld c,a			;6095
	inc b			;6096
	dec c			;6097
	ld a,(0e302h)		;6098
	dec a			;609b   ; 0xE302 = 1: el motor ya ha dicho que no hay descomposicion
	jr z,vuelta_atras		;609c
	ld a,(0e304h)		;609e
	cp c			;60a1
	jp c,motor_de_descomposicion		;60a2   ; el cursor aun no llega al final: sigue descomponiendo
	cp b			;60a5   ; el cursor esta en el final: mano completa
	jr z,mano_completa		;60a6
	ld a,(0e304h)		;60a8
	ld de,0e2f1h		;60ab
	call suma_a_a_de		;60ae
	call apunta_la_pareja		;60b1   ; quedan dos fichas y tienen que ser la pareja

; ----------------------------------------------------------------------
; LA SALIDA BUENA. 0xE303 cuenta las parejas de escaleras iguales apuntadas por 0x6386: con dos (ryanpeikou) el acarreo lo saca a 0xE205; pero si la mano ya era siete parejas (bit 0 de 0xE205) se olvidan las escaleras dobles. Copia el turno de 0xE206 al bit 1 de 0xE302 y deja el cursor al final.
; ----------------------------------------------------------------------
mano_completa:
	ld a,(0e303h)		;60b4   ; 0xE303: cuantas parejas de escaleras iguales
	rra			;60b7
	rra			;60b8   ; el segundo rra saca al acarreo si van dos o mas
	jr nc,L_60BE		;60b9
	ld (0e205h),a		;60bb
L_60BE:
	ld a,(0e205h)		;60be
	rra			;60c1   ; bit 0 de 0xE205: siete parejas
	jr nc,L_60C8		;60c2
	xor a			;60c4
	ld (0e303h),a		;60c5   ; siete parejas manda: fuera las escaleras dobles
L_60C8:
	ld hl,0e302h		;60c8
	res 1,(hl)		;60cb   ; bit 1 de 0xE302 = de quien es la mano, copiado de 0xE206
	ld a,(0e206h)		;60cd
	rra			;60d0
	jr nc,L_60D5		;60d1
	set 1,(hl)		;60d3
L_60D5:
	ld a,(0e20ah)		;60d5   ; el cursor, al final
	inc a			;60d8
	ld (0e304h),a		;60d9
	ret			;60dc
L_60DD:
	jp motor_de_descomposicion		;60dd

; ----------------------------------------------------------------------
; LA VUELTA ATRAS. Si ya se vio que la mano son siete parejas, vale como completa. Si no hay copia guardada (0xE237 a cero), NO HAY DESCOMPOSICION: 0xE302 = 1 y se limpia por 0x67AE. Si la hay, se restaura y se prueba la rama que dejo apuntada 0xE239: bit 0 la de 0x63C1 (dos escaleras dobles), bit 1 la de 0x6386 mas uno, y sin bits, tomar el grupo como trio (0x6185).
; ----------------------------------------------------------------------
vuelta_atras:
	ld a,(0e205h)		;60e0
	rra			;60e3   ; bit 0 de 0xE205: la mano son siete parejas y vale
	jr c,mano_completa		;60e4
	xor a			;60e6
	ld hl,0e237h		;60e7
	cp (hl)			;60ea   ; sin copia que restaurar
	jr nz,L_60F5		;60eb
	ld a,001h		;60ed   ; 0xE302 = 1: NO HAY DESCOMPOSICION, la mano no esta completa
	ld (0e302h),a		;60ef
	jp limpia_las_figuras		;60f2
L_60F5:
	dec (hl)			;60f5   ; una copia menos
	ld hl,0e239h		;60f6
	bit 0,(hl)		;60f9   ; bit 0: la rama de las dos escaleras dobles
	jr z,L_6108		;60fb
	res 0,(hl)		;60fd
	call restaura_la_copia		;60ff   ; restaura la copia y deja DE en el cursor
	call L_63C1		;6102
	jp L_60DD		;6105
L_6108:
	bit 1,(hl)		;6108   ; bit 1: la rama de 0x6386
	jr z,L_6121		;610a
	res 0,(hl)		;610c
	call restaura_la_copia		;610e
	call apunta_dos_escaleras_iguales		;6111
	ld a,(de)			;6114
	push af			;6115
	ld a,006h		;6116   ; seis fichas mas alla
	call suma_a_a_de		;6118
	pop af			;611b
	inc a			;611c
	ld (de),a			;611d   ; se le suma uno a esa ficha, y otra vuelta
	jp L_60DD		;611e
L_6121:
	call restaura_la_copia		;6121   ; sin bits: el grupo va de trio
	call apunta_un_trio		;6124
	jp L_60DD		;6127

; ----------------------------------------------------------------------
; Vuelve a cargar la copia guardada por 0x62A5: la mano con su cursor (20 bytes a 0xE2F1) y las figuras (38 bytes a 0xE2B6). Del hueco 0 (0xE36E/0xE101) si ya no queda profundidad, del hueco 1 (0xE094/0xE06E) si aun queda una. Sale con DE en el cursor.
; ----------------------------------------------------------------------
restaura_la_copia:
	ld hl,0e237h		;612a
	ld a,(hl)			;612d   ; la profundidad que queda
	ld hl,0e36eh		;612e
	or a			;6131
	jr z,L_6137		;6132
	ld hl,0e094h		;6134   ; el hueco 1
L_6137:
	ld de,0e2f1h		;6137
	ld bc,00014h		;613a   ; veinte bytes: la mano y 0xE300-0xE304
	ldir		;613d
	ld hl,0e101h		;613f
	or a			;6142
	jr z,L_6148		;6143
	ld hl,0e06eh		;6145   ; el hueco 1, para las figuras
L_6148:
	ld de,0e2b6h		;6148
	ld bc,00026h		;614b   ; treinta y ocho bytes: los registros de figuras
	ldir		;614e
	ld a,(0e304h)		;6150   ; DE = el cursor
	ld de,0e2f1h		;6153
	jp suma_a_a_de		;6156

; ----------------------------------------------------------------------
; Apunta la escalera que empieza en la ficha de DE: la ficha, la ficha mas uno y la ficha mas dos en el registro siguiente de 0xE2B7, sube 0xE2C8 y adelanta el cursor tres. Un honor (0x31 en adelante) no forma escalera: vuelta atras. Con el cursor ya en 14 no hay nada que apuntar.
; ----------------------------------------------------------------------
apunta_una_escalera:
	ld a,(0e304h)		;6159
	cp 00eh		;615c   ; cursor en el final: nada que apuntar
	ret z			;615e
	ld a,(de)			;615f
	cp 031h		;6160   ; un honor no forma escalera
	jp nc,vuelta_atras		;6162
	ld hl,0e2c8h		;6165   ; una escalera mas
	inc (hl)			;6168
	ld a,(0e304h)		;6169
	add a,003h		;616c   ; el cursor salta tres fichas
	ld (0e304h),a		;616e
	ld hl,0e2b7h		;6171
	ld a,(0e2c8h)		;6174
	dec a			;6177
	add a,a			;6178   ; cuatro bytes por registro
	add a,a			;6179
	add a,l			;617a
	ld l,a			;617b
	ld b,003h		;617c
	ld a,(de)			;617e
L_617F:
	ld (hl),a			;617f   ; la ficha, la ficha mas uno y la ficha mas dos
	inc a			;6180
	inc hl			;6181
	djnz L_617F		;6182
	ret			;6184

; ----------------------------------------------------------------------
; Apunta el trio de la ficha de DE en el registro siguiente de 0xE2C9, sube 0xE2DA y adelanta el cursor tres. Y UNA REGLA DEL MAHJONG DE VERDAD: si el trio se cierra con la ficha de RON (0xE347) se marca como ABIERTO (marca 1 y 0xE2D9++), que es lo que despues le quita fu (0x71BC) y lo deja fuera de los trios ocultos (0x7DD9).
; ----------------------------------------------------------------------
apunta_un_trio:
	ld a,(0e304h)		;6185
	cp 00eh		;6188   ; cursor en el final: nada que apuntar
	ret z			;618a
	ld hl,0e2dah		;618b
	inc (hl)			;618e   ; un trio mas
	ld a,(0e304h)		;618f
	add a,003h		;6192   ; el cursor salta tres fichas
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
	ld (hl),a			;61a5   ; las tres copias
	inc hl			;61a6
	inc de			;61a7
	djnz L_61A5		;61a8
	push hl			;61aa
	ld hl,0e347h		;61ab
	cp (hl)			;61ae   ; es la ficha de ron?
	pop hl			;61af
	ret nz			;61b0
	ld a,001h		;61b1   ; marca 1: un trio cerrado con la ficha del rival cuenta como ABIERTO
	ld (hl),a			;61b3
	ld hl,0e2d9h		;61b4
	inc (hl)			;61b7   ; y uno mas entre los trios abiertos
	ret			;61b8

; ----------------------------------------------------------------------
; Apunta cuatro copias de la ficha de DE como cuarteto en 0xE2DB (cinco bytes por registro), sube 0xE2F0 y adelanta el cursor cuatro. Solo lo llama el kan (0x6D97). La entrada de 0x61C5 escribe sin tocar el cursor, y 0x6EEC la usa para deshacer un kan.
; ----------------------------------------------------------------------
apunta_un_cuarteto:
	ld hl,0e2f0h		;61b9
	inc (hl)			;61bc
	ld a,(0e304h)		;61bd
	add a,004h		;61c0   ; el cursor salta cuatro fichas
	ld (0e304h),a		;61c2
L_61C5:
	ld hl,0e2dbh		;61c5   ; los registros de cuarteto, cinco bytes cada uno
	ld a,(0e2f0h)		;61c8
	dec a			;61cb
	ld c,a			;61cc
	add a,a			;61cd   ; por cinco: cuatro fichas y la marca
	add a,a			;61ce
	add a,c			;61cf
	add a,l			;61d0
	ld l,a			;61d1
	ld b,004h		;61d2
	ld a,(de)			;61d4
L_61D5:
	ld (hl),a			;61d5   ; las cuatro copias
	inc hl			;61d6
	djnz L_61D5		;61d7
	ret			;61d9

; ----------------------------------------------------------------------
; Toma las dos fichas de DE como LA PAREJA (0xE300 y 0xE301) si son iguales y aun no habia pareja. Si ya la habia o no son iguales, vuelta atras. Adelanta el cursor dos.
; ----------------------------------------------------------------------
apunta_la_pareja:
	ld a,(0e304h)		;61da
	cp 00eh		;61dd
	ret z			;61df
	ld a,(0e300h)		;61e0   ; ya hay pareja: dos no caben
	or a			;61e3
	jp nz,vuelta_atras		;61e4
	ld a,(de)			;61e7
	ld h,d			;61e8
	ld l,e			;61e9
	inc hl			;61ea
	cp (hl)			;61eb   ; la siguiente tiene que ser igual
	jp nz,vuelta_atras		;61ec
	ld (0e300h),a		;61ef   ; la pareja, en 0xE300 y 0xE301
	ld (0e301h),a		;61f2
	inc de			;61f5
	inc de			;61f6
	ld a,(0e304h)		;61f7
	add a,002h		;61fa   ; el cursor salta dos fichas
	ld (0e304h),a		;61fc
	ret			;61ff

; ----------------------------------------------------------------------
; Adelanta HL y devuelve la ficha de DE menos la de HL. Las tres entradas de abajo comparan el resultado con -1, -2 y -3: "la que sigue es la ficha mas uno, mas dos o mas tres". Todo el arbol del motor esta escrito con estas tres preguntas encadenadas.
; ----------------------------------------------------------------------
resta_la_siguiente:
	inc hl			;6200
	ld a,(de)			;6201
	sub (hl)			;6202
	ret			;6203
es_la_ficha_mas_uno:
	call resta_la_siguiente		;6204
	cp 0ffh		;6207   ; 0xFF: la que sigue es la ficha mas uno
	ret			;6209
es_la_ficha_mas_dos:
	call resta_la_siguiente		;620a
	cp 0feh		;620d   ; 0xFE: la ficha mas dos
	ret			;620f
es_la_ficha_mas_tres:
	call resta_la_siguiente		;6210
	cp 0fdh		;6213   ; 0xFD: la ficha mas tres
	ret			;6215

; ----------------------------------------------------------------------
; El caso x, x+1, x+1: dos copias de la ficha siguiente. Mira hasta ocho fichas mas alla para separar las lecturas posibles: tres escaleras encadenadas (x, x+1 y otra vez x+1, en 0x623E), escalera y pareja (0x628E), escalera y trio (0x6287), escalera y luego un grupo que puede ir de pareja o de trio (0x6295) y las mezclas de en medio. Cada rama apunta sus figuras y vuelve a 0x6091.
; ----------------------------------------------------------------------
caso_x_x1_x1:
	call es_la_ficha_mas_dos		;6216
	jr z,L_624D		;6219   ; la cuarta es x+2: por 0x624D
	cp 0ffh		;621b
	jp nz,vuelta_atras		;621d   ; si tampoco es x+1, nada cuadra
	call es_la_ficha_mas_uno		;6220   ; tres copias de x+1: la quinta decide
	jr z,L_626D		;6223   ; cuatro copias de x+1: por 0x626D
	cp 0feh		;6225
	jp nz,vuelta_atras		;6227
	call es_la_ficha_mas_dos		;622a   ; x+2, x+2, x+3, x+3 detras: tres escaleras
	jr nz,L_628E		;622d
	call es_la_ficha_mas_dos		;622f
	jr nz,L_628E		;6232
	call es_la_ficha_mas_tres		;6234
	jr nz,L_628E		;6237
	call es_la_ficha_mas_tres		;6239
	jr nz,L_628E		;623c
	call apunta_una_escalera		;623e   ; la escalera de x
	inc de			;6241
	call apunta_una_escalera		;6242   ; y dos veces la de x+1
	call apunta_una_escalera		;6245
	ld hl,0e303h		;6248
	inc (hl)			;624b   ; una pareja de escaleras iguales mas
	ret			;624c
L_624D:
	call es_la_ficha_mas_dos		;624d
	jp nz,vuelta_atras		;6250   ; x, x+1, x+1, x+2: la quinta tiene que ser otro x+2
	call es_la_ficha_mas_tres		;6253
	jr nz,L_625F		;6256   ; con x+3 detras son dos escaleras, x y x+1
	call apunta_una_escalera		;6258
	inc de			;625b
	jp apunta_una_escalera		;625c
L_625F:
	cp 0feh		;625f
	jp nz,vuelta_atras		;6261   ; y si no, escalera de x y se reescribe el resto para seguir ordenado
	call apunta_una_escalera		;6264
	inc de			;6267
	inc de			;6268
	ld a,(de)			;6269
	inc de			;626a
	ld (de),a			;626b
	ret			;626c
L_626D:
	call es_la_ficha_mas_dos		;626d
	jp nz,vuelta_atras		;6270   ; cuatro copias de x+1: detras tiene que venir x+2
	call es_la_ficha_mas_dos		;6273
	jr nz,L_6283		;6276
L_6278:
	dec hl			;6278   ; se reescribe la ficha para que la escalera salga de x
	dec hl			;6279
	ld a,(hl)			;627a
	inc hl			;627b
	ld (hl),a			;627c
	call apunta_una_escalera		;627d   ; escalera, y el resto puede ir de pareja o de trio
	inc de			;6280
	jr prueba_pareja_o_trio		;6281
L_6283:
	cp 0fdh		;6283
	jr z,L_6278		;6285
L_6287:
	call apunta_una_escalera		;6287   ; escalera de x y trio de x+1
	inc de			;628a
	jp apunta_un_trio		;628b
L_628E:
	call apunta_una_escalera		;628e   ; escalera de x y pareja de x+1
	inc de			;6291
	jp apunta_la_pareja		;6292

; ----------------------------------------------------------------------
; El grupo de DE puede ir de pareja o de trio. Si ya hay pareja, no hay duda: trio. Si no, GUARDA COPIA y lo prueba como pareja, dejando el trio como la rama que 0x60E0 probara si esta falla.
; ----------------------------------------------------------------------
prueba_pareja_o_trio:
	ld a,(0e300h)		;6295
	or a			;6298   ; ya hay pareja: el grupo va de trio
	jp nz,apunta_un_trio		;6299
	call guarda_una_copia		;629c   ; guarda copia para poder volver atras
	call apunta_la_pareja		;629f   ; y lo prueba como pareja
	jp L_60DD		;62a2

; ----------------------------------------------------------------------
; Guarda el estado del analisis para poder volver atras: sube 0xE237 y copia la mano con su cursor (20 bytes desde 0xE2F1) y las figuras (38 desde 0xE2B6) al hueco 0 (0xE36E/0xE101) si la profundidad es 1 o al hueco 1 (0xE094/0xE06E) si es 2. Sale con DE en el cursor.
; ----------------------------------------------------------------------
guarda_una_copia:
	ld hl,0e237h		;62a5
	inc (hl)			;62a8   ; un nivel mas de profundidad
	ld a,(hl)			;62a9
	ld hl,0e2f1h		;62aa
	ld de,0e36eh		;62ad
	cp 001h		;62b0   ; el primer nivel va al hueco 0
	jr z,L_62B7		;62b2
	ld de,0e094h		;62b4   ; el segundo, al hueco 1
L_62B7:
	ld bc,00014h		;62b7   ; veinte bytes: la mano y 0xE300-0xE304
	ldir		;62ba
	ld hl,0e2b6h		;62bc
	ld de,0e101h		;62bf
	cp 001h		;62c2
	jr z,L_62C9		;62c4
	ld de,0e06eh		;62c6
L_62C9:
	ld bc,00026h		;62c9   ; treinta y ocho: las figuras
	ldir		;62cc
	ld a,(0e304h)		;62ce   ; DE = el cursor
	ld de,0e2f1h		;62d1
	jp suma_a_a_de		;62d4

; ----------------------------------------------------------------------
; Cuatro copias seguidas de la misma ficha. En la mano cerrada un cuarteto no existe (los kan se declaran), asi que es trio mas pareja o trio mas escalera segun lo que venga detras: x+1 y x+2 dan trio y escalera (0x62E7); mas copias de x+1 y x+2 abren las ramas de 0x62F4.
; ----------------------------------------------------------------------
caso_cuatro_iguales:
	call es_la_ficha_mas_uno		;62d7
	jp nz,vuelta_atras		;62da   ; detras tiene que venir x+1
	call es_la_ficha_mas_uno		;62dd
	jr z,L_62ED		;62e0   ; dos x+1: por 0x62ED
	cp 0feh		;62e2
	jp nz,vuelta_atras		;62e4   ; un x+1 y luego tiene que venir x+2
L_62E7:
	call apunta_un_trio		;62e7   ; trio de x y escalera de x
	jp apunta_una_escalera		;62ea
L_62ED:
	call es_la_ficha_mas_uno		;62ed
	jr z,L_62F4		;62f0   ; tres x+1: por 0x62F4
	jr prueba_pareja_o_trio		;62f2   ; dos x+1 y otra cosa: trio, y el resto de pareja o trio
L_62F4:
	call es_la_ficha_mas_uno		;62f4
	jr z,L_6332		;62f7   ; cuatro x+1: por 0x6332
	cp 0feh		;62f9
	jp nz,vuelta_atras		;62fb   ; tres x+1 y luego tiene que venir x+2
	call es_la_ficha_mas_dos		;62fe
	jr z,L_630A		;6301   ; dos x+2: por 0x630A
	call L_62E7		;6303   ; trio, escalera, y la pareja detras
	inc de			;6306
	jp apunta_la_pareja		;6307
L_630A:
	call es_la_ficha_mas_dos		;630a
	jr nz,L_635B		;630d   ; la ficha mas dos otra vez, o por 0x635B
	call es_la_ficha_mas_tres		;630f
	jr nz,L_6327		;6312
	call apunta_la_pareja		;6314   ; pareja de x, y tres escaleras
	call apunta_una_escalera		;6317
	call apunta_una_escalera		;631a
	inc de			;631d
	inc de			;631e
	call apunta_una_escalera		;631f
	ld hl,0e303h		;6322
	inc (hl)			;6325   ; una pareja de escaleras iguales mas
	ret			;6326
L_6327:
	cp 0feh		;6327
	jp nz,vuelta_atras		;6329   ; y si no es x+3, tiene que ser otro x+2
	call L_636D		;632c   ; trio, escalera, pareja, y un trio mas
	jp apunta_un_trio		;632f
L_6332:
	call es_la_ficha_mas_dos		;6332
	jp nz,vuelta_atras		;6335   ; cuatro x y cuatro x+1: tiene que venir x+2
	call es_la_ficha_mas_dos		;6338
	jr z,L_6344		;633b   ; dos x+2: por 0x6344
	call L_62E7		;633d   ; trio, escalera, y otro trio
	inc de			;6340
	jp apunta_un_trio		;6341
L_6344:
	call es_la_ficha_mas_dos		;6344
	jp nz,apunta_un_trio		;6347   ; solo dos x+2: trio de x y a seguir
	call es_la_ficha_mas_dos		;634a
	jp nz,apunta_un_trio		;634d
	call L_62E7		;6350   ; trio, escalera, y dos trios mas
	inc de			;6353
	inc de			;6354
	call apunta_un_trio		;6355
	jp apunta_un_trio		;6358
L_635B:
	cp 0fdh		;635b
	jp nz,vuelta_atras		;635d   ; aqui tiene que venir x+3
	call resta_la_siguiente		;6360
	cp 0fch		;6363   ; y x+4 detras
	jr nz,L_636D		;6365
	call L_636D		;6367
	jp apunta_una_escalera		;636a
L_636D:
	call L_62E7		;636d   ; trio de x, escalera de x, y pareja
	inc de			;6370
	call apunta_la_pareja		;6371
	inc de			;6374
	ret			;6375

; ----------------------------------------------------------------------
; El caso x, x, x+1: pareja seguida de la ficha mas uno. Con x+1 y x+2 dobles son DOS ESCALERAS IGUALES (0x6386, el iipeikou); con una sola copia de cada, pareja y escalera; y con mas copias de x+1 se abren las dudas de 0x63A2, que son las que dejan una rama apuntada en 0xE239 para la vuelta atras.
; ----------------------------------------------------------------------
caso_pareja_y_siguiente:
	call es_la_ficha_mas_uno		;6376
	jr nz,L_6391		;6379   ; una sola x+1: por 0x6391
	call es_la_ficha_mas_dos		;637b
	jr nz,caso_pareja_y_dos_siguientes		;637e   ; x+1 doble y luego no viene x+2: por 0x63A2
	call es_la_ficha_mas_dos		;6380
	jp nz,vuelta_atras		;6383   ; y tiene que venir x+2 doble

; ----------------------------------------------------------------------
; Apunta DOS veces la misma escalera desde DE y sube 0xE303. Es la figura del iipeikou: dos escaleras identicas; dos de estas son el ryanpeikou.
; ----------------------------------------------------------------------
apunta_dos_escaleras_iguales:
	call apunta_una_escalera		;6386
	call apunta_una_escalera		;6389
	ld hl,0e303h		;638c   ; una pareja de escaleras iguales mas
	inc (hl)			;638f
	ret			;6390
L_6391:
	cp 0feh		;6391
	jp nz,vuelta_atras		;6393   ; tras x, x, x+1 tiene que venir x+2
	call es_la_ficha_mas_tres		;6396
	jp nz,apunta_la_pareja		;6399   ; sin x+3 detras: pareja de x y escalera
	call apunta_la_pareja		;639c   ; pareja de x, y escalera de x+1
	jp apunta_una_escalera		;639f

; ----------------------------------------------------------------------
; El caso x, x, x+1, x+1: aqui el motor no puede saber a ciegas si va de pareja mas escalera o de dos escaleras, asi que mira mas lejos y, en los casos que siguen siendo ambiguos, GUARDA COPIA y apunta en 0xE239 la rama alternativa antes de tirar por una.
; ----------------------------------------------------------------------
caso_pareja_y_dos_siguientes:
	cp 0ffh		;63a2
	jp nz,prueba_siete_parejas		;63a4   ; si la quinta no es otro x+1, candidata a siete parejas
	call es_la_ficha_mas_uno		;63a7
	jr nz,L_63DD		;63aa   ; sin un cuarto x+1: por 0x63DD
	call es_la_ficha_mas_dos		;63ac
	jp nz,vuelta_atras		;63af
	call es_la_ficha_mas_dos		;63b2
	jp nz,apunta_la_pareja		;63b5
	call es_la_ficha_mas_dos		;63b8   ; tres x+2, o x+3 detras: ambiguo, por 0x63C9
	jr z,L_63C9		;63bb
	cp 0fdh		;63bd
	jr z,L_63C9		;63bf   ; x+3 detras: tambien ambiguo
L_63C1:
	call apunta_dos_escaleras_iguales		;63c1   ; dos escaleras iguales y detras la pareja
	inc de			;63c4
	inc de			;63c5
	jp apunta_la_pareja		;63c6
L_63C9:
	ld hl,0e239h		;63c9
	set 0,(hl)		;63cc   ; bit 0 de 0xE239: si falla, se probaran las dos escaleras iguales
L_63CE:
	call guarda_una_copia		;63ce   ; guarda copia y va de pareja mas trio
	call L_63D7		;63d1
	jp L_60DD		;63d4
L_63D7:
	call apunta_la_pareja		;63d7   ; pareja de x y trio de x+1
	jp apunta_un_trio		;63da
L_63DD:
	cp 0feh		;63dd
	jr nz,L_63D7		;63df   ; sin x+2 detras: pareja y trio
	call es_la_ficha_mas_dos		;63e1
	jr nz,L_63D7		;63e4   ; un solo x+2: pareja y trio
	call es_la_ficha_mas_dos		;63e6
	jr nz,L_63D7		;63e9
	ld hl,0e239h		;63eb
	set 1,(hl)		;63ee   ; bit 1 de 0xE239: la rama alternativa de 0x6386
	jr L_63CE		;63f0

; ----------------------------------------------------------------------
; El caso x, x, x, y con y distinta: tres iguales. Si y no es x+1 va de trio sin mas. Si lo es, la ambiguedad clasica: trio de x o pareja de x mas escalera de x, y el motor la resuelve mirando cuantas copias de x+1, x+2, x+3... siguen; en la tira mas larga (0x6403-0x6424, hasta x+6) distingue trio mas escaleras de pareja mas escaleras.
; ----------------------------------------------------------------------
caso_trio:
	sub (hl)			;63f2
	cp 0ffh		;63f3   ; la cuarta no es x+1: trio y punto
	jp nz,apunta_un_trio		;63f5
	call es_la_ficha_mas_dos		;63f8
	jp nz,L_647D		;63fb   ; sin x+2 en la quinta: por 0x647D
	call es_la_ficha_mas_tres		;63fe
	jr nz,L_6441		;6401   ; sin x+3 en la sexta: por 0x6441
	call resta_la_siguiente		;6403
	cp 0fch		;6406   ; x+1, x+2, x+3 seguidos: la tira larga
	jr nz,L_643B		;6408
	call resta_la_siguiente		;640a
	cp 0fbh		;640d
	jr nz,L_643B		;640f
	call resta_la_siguiente		;6411
	cp 0fah		;6414
	jr nz,L_6430		;6416   ; sin x+6: pareja y dos escaleras
	call resta_la_siguiente		;6418
	cp 0f9h		;641b
	jr nz,L_642B		;641d   ; sin x+7: trio y dos escaleras
	call resta_la_siguiente		;641f
	cp 0f8h		;6422
	jr nz,L_642B		;6424
	call L_6430		;6426   ; hasta x+8 seguidos: pareja de x y tres escaleras
	jr L_6436		;6429
L_642B:
	call L_643B		;642b   ; trio y dos escaleras
	jr L_6436		;642e
L_6430:
	call apunta_la_pareja		;6430   ; pareja de x y escalera de x
	call apunta_una_escalera		;6433
L_6436:
	call L_64F3		;6436   ; y una escalera mas, tres fichas mas alla
	jr L_643E		;6439
L_643B:
	call apunta_un_trio		;643b   ; trio de x
L_643E:
	jp apunta_una_escalera		;643e   ; y escalera detras
L_6441:
	cp 0feh		;6441
	jr nz,L_6477		;6443   ; la sexta no es x+2: pareja y escalera, por 0x6477
	call es_la_ficha_mas_dos		;6445
	jr nz,L_646F		;6448   ; sin un tercer x+2: por 0x646F
	call es_la_ficha_mas_tres		;644a
	jr nz,L_6455		;644d   ; x+3 en la octava: trio de x, escalera de x+1 y pareja de x+2
	call apunta_un_trio		;644f
	jp L_628E		;6452   ; pareja de x+3 detras
L_6455:
	cp 0feh		;6455
	jr nz,L_646F		;6457   ; si la octava no es otro x+2: por 0x646F
	call es_la_ficha_mas_tres		;6459
	jr nz,L_6464		;645c   ; sin x+3 detras: pareja de x, escalera de x y trio de x+2
	call apunta_un_trio		;645e   ; con x+3: trio de x
	jp L_6287		;6461   ; escalera de x+1 y trio de x+2
L_6464:
	call apunta_la_pareja		;6464   ; pareja de x, escalera de x y trio de x+2
	call apunta_una_escalera		;6467
	inc de			;646a
	inc de			;646b
	jp apunta_un_trio		;646c
L_646F:
	cp 0fdh		;646f
	jp nz,vuelta_atras		;6471   ; aqui tiene que venir x+3
	jp prueba_pareja_o_trio		;6474   ; y el grupo de x puede ir de pareja o de trio
L_6477:
	call apunta_la_pareja		;6477   ; pareja de x y escalera de x
	jp apunta_una_escalera		;647a
L_647D:
	cp 0ffh		;647d
	jp nz,vuelta_atras		;647f   ; la quinta tiene que ser otro x+1
	call es_la_ficha_mas_uno		;6482
	jr nz,L_6496		;6485   ; sin un tercer x+1: por 0x6496
	call es_la_ficha_mas_uno		;6487
	jr z,L_64A1		;648a   ; cuatro x+1: por 0x64A1
	cp 0feh		;648c
	jr z,L_64B8		;648e   ; tres x+1 y luego x+2: por 0x64B8
	call apunta_un_trio		;6490   ; dos trios seguidos, x y x+1
	jp apunta_un_trio		;6493
L_6496:
	cp 0feh		;6496
	jp z,prueba_pareja_o_trio		;6498   ; dos x+1 y luego x+2: el grupo de x va de pareja o de trio
	call apunta_un_trio		;649b   ; trio de x y pareja de x+1
	jp apunta_la_pareja		;649e
L_64A1:
	call es_la_ficha_mas_dos		;64a1
	jp nz,vuelta_atras		;64a4   ; aqui tiene que venir x+2
	call es_la_ficha_mas_tres		;64a7
	jr z,L_64C5		;64aa   ; con x+3 detras: por 0x64C5
	cp 0feh		;64ac
	jp z,prueba_pareja_o_trio		;64ae   ; x+2 doble: pareja o trio
L_64B1:
	call L_6477		;64b1   ; pareja de x, escalera de x, y trio
	inc de			;64b4
	jp apunta_un_trio		;64b5
L_64B8:
	call es_la_ficha_mas_dos		;64b8
	jp nz,apunta_un_trio		;64bb   ; sin x+3: trio de x
	cp 0fdh		;64be
	jp nz,prueba_pareja_o_trio		;64c0   ; si no viene x+3, pareja o trio
	jr L_64B1		;64c3
L_64C5:
	call resta_la_siguiente		;64c5
	cp 0fch		;64c8   ; con x+4 detras: por 0x64D2
	jr z,L_64D2		;64ca
L_64CC:
	call apunta_un_trio		;64cc   ; trio de x, trio de x+1 y escalera de x+2
	jp L_643B		;64cf
L_64D2:
	call resta_la_siguiente		;64d2
	cp 0fbh		;64d5   ; sin x+5: por 0x64E6
	jr nz,L_64E6		;64d7
	call resta_la_siguiente		;64d9
	cp 0fah		;64dc   ; con x+6: por 0x64ED
	jr z,L_64ED		;64de
	call L_64B1		;64e0   ; pareja, escalera, trio y otra escalera
	jp L_6436		;64e3
L_64E6:
	cp 0fch		;64e6
	jp nz,vuelta_atras		;64e8   ; sin otro x+4, nada cuadra
	jr L_64CC		;64eb
L_64ED:
	call apunta_un_trio		;64ed   ; trio de x, trio y dos escaleras
	jp L_642B		;64f0
L_64F3:
	ld a,e			;64f3   ; DE salta tres fichas
	add a,003h		;64f4
	ld e,a			;64f6
	ret			;64f7

; ----------------------------------------------------------------------
; SIETE PAREJAS (chiitoitsu). Con la mano cerrada (0xE2B6 a cero) comprueba que las catorce fichas de 0xE2F1 vayan de dos en dos y que ninguna pareja se repita: cuatro iguales NO valen como dos parejas. Si cuadra, 0xE205 = 1. Luego sigue por la pareja como si nada: la descomposicion normal fallara, y 0x60E0 dara la mano por buena gracias a esa marca.
; ----------------------------------------------------------------------
prueba_siete_parejas:
	push de			;64f8
	ld a,(0e2b6h)		;64f9   ; con figuras declaradas no hay siete parejas
	or a			;64fc
	jr nz,L_6519		;64fd
	ld hl,0e2f1h		;64ff
	ld de,0e2f2h		;6502
	ld b,007h		;6505   ; siete parejas que mirar
L_6507:
	ld a,(de)			;6507
	cp (hl)			;6508   ; las dos de cada pareja iguales
	jr nz,L_6519		;6509
	inc hl			;650b
	inc hl			;650c
	cp (hl)			;650d   ; y distintas de la pareja siguiente: cuatro iguales no valen
	jr z,L_6519		;650e
	inc de			;6510
	inc de			;6511
	djnz L_6507		;6512
	ld a,001h		;6514   ; 0xE205 = 1: SIETE PAREJAS
	ld (0e205h),a		;6516
L_6519:
	pop de			;6519
	jp apunta_la_pareja		;651a   ; y a seguir por la pareja, que es lo que toca en cualquier caso

; ----------------------------------------------------------------------
; TRECE HUERFANOS (kokushi musou), y el unico sitio donde una ficha suelta no es un fallo. Con la mano cerrada busca la unica pareja, la apunta en 0xE300, quita una de las dos (0x39), reordena para que el hueco caiga al final, y compara las trece que quedan una a una con la tabla de 0x6560: el uno y el nueve de cada palo y los siete honores. Si cuadra, 0xE205 = 2 y a 0x60B4 directo.
; ----------------------------------------------------------------------
prueba_trece_huerfanos:
	ld a,(0e2b6h)		;651d   ; con figuras declaradas no hay trece huerfanos
	or a			;6520
	jp nz,vuelta_atras		;6521
	ld de,0e2f1h		;6524
	ld hl,0e2f2h		;6527
	ld b,00dh		;652a   ; trece comparaciones con la siguiente
L_652C:
	ld a,(de)			;652c
	cp (hl)			;652d
	jr z,L_6537		;652e   ; dos iguales seguidas: la pareja
	inc de			;6530
	inc hl			;6531
	djnz L_652C		;6532
	jp vuelta_atras		;6534   ; sin pareja no es kokushi
L_6537:
	ld a,(hl)			;6537
	ld (0e300h),a		;6538   ; la pareja
	ld (0e301h),a		;653b
	ld a,039h		;653e   ; una de las dos se quita de la mano
	ld (hl),a			;6540
	ld hl,0e2f1h		;6541
	call L_4F99		;6544   ; y se reordena para que el hueco caiga al final
	ld b,00dh		;6547
	ld hl,06560h		;6549   ; la tabla de los trece
	ld de,0e2f1h		;654c
L_654F:
	ld a,(de)			;654f
	cp (hl)			;6550
	jp nz,vuelta_atras		;6551   ; una que no cuadre y no es kokushi
	inc de			;6554
	inc hl			;6555
	djnz L_654F		;6556
	ld a,002h		;6558   ; 0xE205 = 2: TRECE HUERFANOS
	ld (0e205h),a		;655a
	jp mano_completa		;655d

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



; ----------------------------------------------------------------------
; Deja en 0xE2F1 la mano ordenada POR FIGURAS para el recuento: las escaleras (0xE2B7), los trios (0xE2C9), tres de las cuatro fichas de cada cuarteto (0xE2DB) y la pareja (0xE300), y la vuelve a ordenar de menor a mayor. Solo si 0xE305 esta a cero, o sea si aun no hay jugadas apuntadas.
; ----------------------------------------------------------------------
reagrupa_la_mano_por_figuras:
	ld a,(0e305h)		;656d   ; con jugadas ya apuntadas no se toca
	or a			;6570
	ret nz			;6571
	ld de,0e2f1h		;6572
	ld a,(0e2c8h)		;6575   ; las escaleras, tres fichas cada una
	or a			;6578
	jr z,L_6582		;6579
	ld hl,0e2b7h		;657b
	ld b,a			;657e
	call copia_tres_de_cada_registro		;657f
L_6582:
	ld a,(0e2dah)		;6582   ; los trios
	or a			;6585
	jr z,L_658F		;6586
	ld hl,0e2c9h		;6588
	ld b,a			;658b
	call copia_tres_de_cada_registro		;658c
L_658F:
	ld a,(0e2f0h)		;658f   ; los cuartetos, tres de sus cuatro fichas
	or a			;6592
	jr z,L_65A4		;6593
	ld hl,0e2dbh		;6595
	ld b,a			;6598
L_6599:
	push bc			;6599
	ld bc,00003h		;659a
	ldir		;659d
	inc hl			;659f   ; saltando la cuarta y la marca
	inc hl			;65a0
	pop bc			;65a1
	djnz L_6599		;65a2
L_65A4:
	ld hl,0e300h		;65a4   ; y la pareja
	ld bc,00002h		;65a7
	ldir		;65aa
	ld hl,0e2f1h		;65ac
	jp L_4F99		;65af   ; otra vez ordenada de menor a mayor
copia_tres_de_cada_registro:
	push bc			;65b2
	ld bc,00003h		;65b3   ; tres fichas
	ldir		;65b6
	inc hl			;65b8   ; y se salta la marca
	pop bc			;65b9
	djnz copia_tres_de_cada_registro		;65ba
	ret			;65bc

; ----------------------------------------------------------------------
; El cursor del menu de llamadas: un tile 0xEA en la columna de la derecha, cuya direccion de VRAM vive en 0xE1C5. Arriba o abajo (bits 0 y 1 de 0xE009, solo en el flanco) suenan el 4, borran el tile viejo con el blanco (0x01) y lo pintan una fila mas arriba o mas abajo, 0x20 bytes de VRAM. Da la vuelta entre las filas de byte bajo 0x39 y 0xF9 saltando 0xA0, o sea cinco entradas.
; ----------------------------------------------------------------------
mueve_el_cursor_del_menu:
	ld a,(0e009h)		;65bd
	and 003h		;65c0   ; bits 0 y 1: arriba y abajo
	ret z			;65c2
	ld c,a			;65c3
	ld a,(0e008h)		;65c4
	and 003h		;65c7
	xor c			;65c9   ; solo el flanco: si ya estaba pulsada, nada
	ret z			;65ca
	ld b,a			;65cb
	ld a,004h		;65cc   ; sonido 4
	call pide_un_sonido		;65ce
	ld hl,(0e1c5h)		;65d1   ; donde esta el cursor
	ld d,h			;65d4
	ld e,l			;65d5
	ld a,001h		;65d6
	call escribe_en_vram		;65d8   ; tile 1, el blanco, borra el viejo
	ex de,hl			;65db
	ld a,b			;65dc
	rra			;65dd   ; bit 0: arriba
	jr c,L_65F9		;65de
	ld a,020h		;65e0   ; abajo: una fila mas
	call suma_a_a_de		;65e2
	ld a,e			;65e5
	cp 0f9h		;65e6   ; pasada la ultima entrada, cinco filas arriba
	jr nz,L_65EF		;65e8
	ld a,0a0h		;65ea
	call resta_a_de_de		;65ec
L_65EF:
	ld h,d			;65ef
	ld l,e			;65f0
	ld (0e1c5h),hl		;65f1   ; la posicion nueva
	ld a,0eah		;65f4   ; tile 0xEA: el cursor
	jp escribe_en_vram		;65f6
L_65F9:
	ld a,020h		;65f9   ; arriba: una fila menos
	call resta_a_de_de		;65fb
	ld a,e			;65fe
	cp 039h		;65ff   ; pasada la primera, cinco filas abajo
	jr nz,L_65EF		;6601
	ld a,0a0h		;6603
	call suma_a_a_de		;6605
	jr L_65EF		;6608

; ----------------------------------------------------------------------
; SELECT (bit 5 de 0xE009, en el flanco) elige la entrada donde esta el cursor, y la entrada se codifica por bits en 0xE1C7 segun la fila: 0x5x = 1 (agari), 0x7x = 2 (riichi), 0x9x = 4 (pon, 0x680B), 0xBx = 8 (chi, 0x692F) y la de abajo del todo 0x10 (kan). 0x663C despacha los cuatro ultimos; el agari lo mira 0x5036 dentro del turno.
; ----------------------------------------------------------------------
elige_en_el_menu:
	ld hl,(0e1c5h)		;660a
	ld a,l			;660d   ; la fila del cursor, por la parte alta del byte bajo
	and 0f0h		;660e
	ld h,001h		;6610   ; fila 0x5x: 1, agari
	cp 050h		;6612
	jr z,L_662A		;6614
	ld h,002h		;6616   ; 0x7x: 2, riichi
	cp 070h		;6618
	jr z,L_662A		;661a
	ld h,004h		;661c   ; 0x9x: 4, pon
	cp 090h		;661e
	jr z,L_662A		;6620
	ld h,008h		;6622   ; 0xBx: 8, chi
	cp 0b0h		;6624
	jr z,L_662A		;6626
	ld h,010h		;6628   ; y la ultima, 0x10, kan
L_662A:
	ld a,(0e009h)		;662a
	and 020h		;662d   ; bit 5: SELECT
	ret z			;662f
	ld c,a			;6630
	ld a,(0e008h)		;6631
	and 020h		;6634   ; solo el flanco
	ret nz			;6636
	ld a,h			;6637
	ld (0e1c7h),a		;6638   ; la llamada elegida, en 0xE1C7
	ret			;663b

; ----------------------------------------------------------------------
; Reparte la llamada de 0xE1C7 por bits: 2 riichi (0x6653), 4 pon (0x680B), 8 chi (0x692F), 0x10 kan (0x6C12). El bit 0, agari, no pasa por aqui. Lo llaman tres sitios del turno: 0x5284, 0x55D0 y 0x5831.
; ----------------------------------------------------------------------
despacha_la_llamada:
	ld hl,0e1c7h		;663c
	bit 1,(hl)		;663f   ; bit 1: riichi
	jr nz,declara_riichi		;6641
	bit 2,(hl)		;6643   ; bit 2: pon
	jp nz,hace_pon		;6645
	bit 3,(hl)		;6648   ; bit 3: chi
	jp nz,hace_chi		;664a
	bit 4,(hl)		;664d   ; bit 4: kan
	jp nz,hace_kan		;664f
	ret			;6652

; ----------------------------------------------------------------------
; RIICHI, y lo que le pide el cartucho. Al jugador 1 (bit 0 de 0xE206 a cero): que no vaya por el descarte 18 (0xE1BE = 0x12) y que no este ya en riichi (bit 0 de 0xE33E). A los dos: que la mano este CERRADA (0xE2B6 a cero, ninguna llamada) y que acabe de robar (bit 0 de 0xE22C). Si algo falla, el dibujo 2 del rincon y nada mas. Si pasa: bit 0 de 0xE33E, el palo de riichi como sprite (patrones 0x78/0x88/0x98/0x88 en 0xE0B8 para el 1, 0x18/0x28/0x38/0x28 en 0xE0C8 para el 2), 0xE1CC apunta CON QUE DESCARTE se declara (de ahi salen el doble riichi y el ippatsu de 0x7BAF) y suena el 10. Los mil puntos del palo no se cobran aqui (la cuenta de palos, 0xE04A, la tocan 0x53B8 y 0x579A).
; ----------------------------------------------------------------------
declara_riichi:
	ld a,(0e206h)		;6653
	rra			;6656   ; bit 0 de 0xE206: la maquina se salta las dos primeras comprobaciones
	jr c,L_6666		;6657
	ld a,(0e1beh)		;6659
	cp 012h		;665c   ; descarte 18: ya no se puede declarar
	jr z,rechaza_la_llamada		;665e
	ld a,(0e33eh)		;6660
	rra			;6663   ; bit 0 de 0xE33E: ya esta en riichi
	jr c,rechaza_la_llamada		;6664
L_6666:
	ld a,(0e2b6h)		;6666
	or a			;6669   ; con alguna llamada hecha la mano no esta cerrada: no hay riichi
	jr nz,rechaza_la_llamada		;666a
	ld a,(0e22ch)		;666c
	rra			;666f   ; y hay que acabar de robar
	jr nc,rechaza_la_llamada		;6670
	ld hl,0e33eh		;6672
	set 0,(hl)		;6675   ; EN RIICHI: bit 0 de 0xE33E
	ld a,078h		;6677   ; el palo de riichi del jugador 1, cuatro patrones de sprite
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
	ld a,018h		;6694   ; y el del jugador 2
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
	inc a			;66b4   ; 0xE1CC = el numero del descarte con el que se declara
	ld (0e1cch),a		;66b5
L_66B8:
	ld a,00ah		;66b8
	call pide_un_sonido		;66ba   ; sonido 10
	ld hl,0e0b8h		;66bd
	ld de,03b10h		;66c0   ; los atributos del sprite, a 0x3B10 o 0x3B20
	ld a,(0e206h)		;66c3
	rra			;66c6
	jr nc,L_66CF		;66c7
	ld hl,0e0c8h		;66c9
	ld de,03b20h		;66cc
L_66CF:
	ld bc,00010h		;66cf
	call copia_a_la_vram		;66d2
L_66D5:
	xor a			;66d5
	ld (0e1c7h),a		;66d6   ; la llamada queda atendida
	ret			;66d9

; ----------------------------------------------------------------------
; La llamada no vale: el dibujo 2 del rincon (el unico que suena) y 0xE1C7 a cero.
; ----------------------------------------------------------------------
rechaza_la_llamada:
	ld a,002h		;66da
	call pinta_uno_de_los_tres_dibujos		;66dc
	jr L_66D5		;66df

; ----------------------------------------------------------------------
; LAS ESPERAS: que fichas completan la mano. Para cada uno de los 34 tipos (o para una sola, la de (0xE382), si entra con C = 0xFF) mete la ficha en el hueco 0xE209 de una copia de la mano, la ordena y pregunta al motor (0x6038). Si la mano queda completa, el tipo se apunta en la lista de esperas del jugador: 0xE1F5 para el 1, 0xE20E para el 2, terminada en cero, con la cuenta en 0xE128. Si el jugador 1 tiene alguna, bit 7 de 0xE1CD: esta en tenpai. Las tres entradas: 0x66E1 fija el hueco en la ficha robada (0xE20A), 0x66E7 recorre los 34 tipos, 0x66EB entra con B y C puestos desde fuera.
; ----------------------------------------------------------------------
calcula_las_esperas:
	ld a,(0e20ah)		;66e1   ; el hueco donde se prueba cada ficha: el de la robada
	ld (0e209h),a		;66e4
L_66E7:
	ld c,000h		;66e7
	ld b,022h		;66e9   ; los 34 tipos de ficha, B cuenta hacia abajo
L_66EB:
	xor a			;66eb
	ld (0e128h),a		;66ec   ; ninguna espera todavia
	ld (0e347h),a		;66ef   ; y sin ficha de ron
	push bc			;66f2
	ld hl,0e1f5h		;66f3   ; la lista de esperas del jugador 1
	ld de,0e1f6h		;66f6
	ld a,(0e206h)		;66f9
	rra			;66fc
	jr nc,L_6705		;66fd
	ld hl,0e20eh		;66ff   ; o la del 2
	ld de,0e20fh		;6702
L_6705:
	ld (hl),000h		;6705   ; se vacia: un cero y trece detras
	ld bc,0000dh		;6707
	ldir		;670a
	pop bc			;670c
L_670D:
	push bc			;670d
	ld hl,0e2bah		;670e   ; las figuras que apunto el analisis anterior, fuera
	call borra_las_figuras_sueltas		;6711
	ld hl,0e2cch		;6714
	call borra_las_figuras_sueltas		;6717
	ld hl,0e2f1h		;671a   ; la copia de trabajo, limpia
	ld de,0e2f2h		;671d
	ld bc,00013h		;6720
	ld (hl),000h		;6723
	ldir		;6725
	ld hl,0e32bh		;6727   ; la mano, 0xE20A+1 fichas
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
	call suma_a_a_de		;6740   ; el hueco donde va la ficha a probar
	ld hl,(0e382h)		;6743   ; con C = 0xFF se prueba una sola ficha, la de (0xE382)
	ld a,c			;6746
	cp 0ffh		;6747
	jr z,L_6754		;6749
	ld a,b			;674b
	sub 001h		;674c
	ld hl,04fbfh		;674e   ; si no, el tipo B-1 de la tabla de los 34
	call suma_a_a_hl		;6751
L_6754:
	ld a,(hl)			;6754   ; la ficha a probar, al hueco
	ld (de),a			;6755
	ld (0e129h),a		;6756
	push bc			;6759
	ld hl,0e2f1h		;675a
	ld a,(0e12ah)		;675d
	ld b,a			;6760
	call L_4F9B		;6761   ; ordenada
	call limpia_y_descompone		;6764   ; y al motor: esta completa?
	pop bc			;6767
	ld a,(0e302h)		;6768
	rra			;676b   ; bit 0 de 0xE302: no lo esta
	jr c,L_678B		;676c
	ld a,(0e206h)		;676e
	rra			;6771
	ld hl,0e1f5h		;6772   ; la lista de esperas que toca
	jr nc,L_677A		;6775
	ld hl,0e20eh		;6777
L_677A:
	ld a,(0e128h)		;677a
	call suma_a_a_hl		;677d
	ld a,(0e129h)		;6780
	ld (hl),a			;6783   ; una espera mas
	ld a,(0e128h)		;6784
	inc a			;6787
	ld (0e128h),a		;6788
L_678B:
	djnz L_670D		;678b   ; el tipo siguiente
	ld a,(0e128h)		;678d
	or a			;6790
	jr z,L_679E		;6791   ; sin esperas no hay tenpai
	ld a,(0e206h)		;6793
	rra			;6796
	jr c,L_679E		;6797
	ld hl,0e1cdh		;6799
	set 7,(hl)		;679c   ; bit 7 de 0xE1CD: el jugador 1 esta en tenpai
L_679E:
	ld a,c			;679e
	or a			;679f   ; con C distinto de cero se sale sin limpiar
	ret nz			;67a0

; ----------------------------------------------------------------------
; Deja la copia de trabajo (0xE2F1) a cero y sigue en 0x67AE.
; ----------------------------------------------------------------------
limpia_el_analisis:
	ld hl,0e2f1h		;67a1
	ld de,0e2f2h		;67a4
	ld bc,00013h		;67a7
	ld (hl),000h		;67aa
	ldir		;67ac

; ----------------------------------------------------------------------
; Borra las figuras que el motor apunto por su cuenta (marca 0) y deja las declaradas (marca 1); repone las cuentas de 0xE2C8 y 0xE2DA a lo declarado (0xE2C7 y 0xE2D9), y si habia un trio marcado con la ficha de ron, 0x67E6 lo quita tambien. Es lo que se hace tras cada pregunta al motor, y a donde salta 0x60E0 cuando no hay descomposicion.
; ----------------------------------------------------------------------
limpia_las_figuras:
	ld hl,0e2bah		;67ae   ; las escaleras
	call borra_las_figuras_sueltas		;67b1
	ld hl,0e2cch		;67b4   ; los trios
	call borra_las_figuras_sueltas		;67b7
	call quita_el_trio_del_ron		;67ba   ; y el trio de la ficha de ron, si lo hubo
	xor a			;67bd
	ld (0e347h),a		;67be   ; sin ficha de ron
	ret			;67c1
borra_las_figuras_sueltas:
	ld bc,00403h		;67c2   ; cuatro registros de tres fichas y marca
L_67C5:
	push bc			;67c5
	push hl			;67c6
	xor a			;67c7
	cp (hl)			;67c8   ; la marca
	jr nz,L_67D1		;67c9   ; puesta: figura declarada, se queda
	dec hl			;67cb
	ld b,c			;67cc
L_67CD:
	ld (hl),a			;67cd   ; a cero: se borran sus fichas
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
	ld a,(0e2c7h)		;67d9   ; escaleras: quedan las declaradas
	ld (0e2c8h),a		;67dc
	ld a,(0e2d9h)		;67df   ; y trios igual
	ld (0e2dah),a		;67e2
	ret			;67e5

; ----------------------------------------------------------------------
; Busca en 0xE2C9 el trio hecho con la ficha de ron (0xE347) y lo borra, restando uno a los trios abiertos (0xE2D9) y al total (0xE2DA). Ese trio lleva marca 1 y 0x67C2 no lo tocaria.
; ----------------------------------------------------------------------
quita_el_trio_del_ron:
	ld b,004h		;67e6
	ld a,(0e347h)		;67e8   ; la ficha de ron
	or a			;67eb   ; sin ella no hay nada que quitar
	ret z			;67ec
	ld hl,0e2c9h		;67ed
L_67F0:
	cp (hl)			;67f0   ; el trio de esa ficha
	jr z,L_67FD		;67f1
	push af			;67f3
	ld a,004h		;67f4
	call suma_a_a_hl		;67f6
	pop af			;67f9
	djnz L_67F0		;67fa
	ret			;67fc
L_67FD:
	ld b,004h		;67fd
	xor a			;67ff   ; cuatro bytes a cero
L_6800:
	ld (hl),a			;6800
	inc hl			;6801
	djnz L_6800		;6802
	ld hl,0e2d9h		;6804
	dec (hl)			;6807   ; un trio abierto menos
	inc hl			;6808
	dec (hl)			;6809   ; y uno menos en total
	ret			;680a

; ----------------------------------------------------------------------
; PON: robar el ultimo descarte del rival para hacer trio con dos copias de la mano. No vale en riichi (bit 0 de 0xE33E), ni en la fase 1 de la mano (0xE1AA = 1), ni sin descarte (0x39). Al jugador 1 le basta con las dos copias; a la maquina (bit 0 de 0xE206) el codigo le pide mas: que no tenga delante la ficha menos uno (0x684A), que tenga TRES copias (0x6868) y que detras no venga la ficha mas uno (0x686E). Las copias se cambian por 0x39, el descarte robado tambien, se reordena, y el trio va detras de la parte cerrada (0xE20B baja cuatro) y a 0xE2C9 con marca 1: figura ABIERTA (0xE2D9++ y 0xE2B6++). Sonido 11, y la fase vuelve a 1: toca descartar.
; ----------------------------------------------------------------------
hace_pon:
	ld a,(0e33eh)		;680b
	rra			;680e   ; en riichi no se puede hacer pon
	jp c,rechaza_pon		;680f
	ld a,(0e1aah)		;6812
	dec a			;6815   ; fase 1 de la mano: tampoco
	jp z,rechaza_pon		;6816
	ld a,(0e206h)		;6819
	rra			;681c   ; los descartes del rival
	ld a,(0e1bfh)		;681d
	ld hl,0e172h		;6820
	jr nc,L_682B		;6823
	ld a,(0e1beh)		;6825
	ld hl,0e15eh		;6828
L_682B:
	call suma_a_a_hl		;682b
	ld a,(hl)			;682e
	cp 039h		;682f   ; 0x39: no hay descarte
	jp z,rechaza_pon		;6831
	ld (0e128h),a		;6834   ; la ficha del pon
	ex de,hl			;6837
	ld a,(0e128h)		;6838
	ld hl,0e32bh		;683b
	call busca_en_la_mano		;683e   ; la primera copia en la mano
	ld a,(0e206h)		;6841
	rra			;6844   ; la maquina mira ademas la ficha de delante
	jr nc,L_6851		;6845
	ld a,(0e128h)		;6847
	dec a			;684a
	dec hl			;684b
	cp (hl)			;684c
	jp z,rechaza_pon		;684d   ; si es la ficha menos uno, no hace pon
	inc hl			;6850
L_6851:
	ld a,(0e128h)		;6851
	cp (hl)			;6854
	jp nz,rechaza_pon		;6855   ; hacen falta dos copias en la mano
	inc hl			;6858
	cp (hl)			;6859
	jp nz,rechaza_pon		;685a
	ld a,(0e206h)		;685d
	rra			;6860   ; la maquina pide una tercera
	jr nc,L_6875		;6861
	ld a,(0e128h)		;6863
	inc hl			;6866
	cp (hl)			;6867
	jp nz,L_68FC		;6868   ; sin tercera copia, se cancela sin ruido
	inc a			;686b
	inc hl			;686c
	cp (hl)			;686d
	jp z,L_68FC		;686e   ; y si detras viene la ficha mas uno, tampoco
	dec hl			;6871
	ld (hl),039h		;6872   ; la tercera copia sale de la mano
	dec hl			;6874
L_6875:
	ld a,039h		;6875   ; 0x39 en las dos copias
	ld (hl),a			;6877
	dec hl			;6878
	ld (hl),a			;6879
	ex de,hl			;687a
	ld (hl),a			;687b   ; y en el descarte robado, que desaparece del rio
	call pinta_el_rio_del_jugador_2		;687c   ; repinta el rio del rival
	ld a,(0e206h)		;687f
	rra			;6882
	jr nc,L_6888		;6883
	call pinta_el_rio_del_jugador_1		;6885   ; y el propio, si es la maquina
L_6888:
	ld a,(0e20ah)		;6888
	inc a			;688b
	ld b,a			;688c
	ld hl,0e32bh		;688d
	call L_4F9B		;6890   ; reordena la mano
	ld a,(0e20bh)		;6893
	sub 004h		;6896   ; el limite de la parte cerrada baja cuatro
	cp 00ch		;6898
	jr nz,L_689D		;689a
	dec a			;689c
L_689D:
	ld (0e20bh),a		;689d   ; 0xE20B: el ultimo hueco antes de las figuras
	inc a			;68a0
	ld hl,0e32bh		;68a1
	call suma_a_a_hl		;68a4
	ld a,(0e128h)		;68a7   ; las tres copias, justo detras
	ld (hl),a			;68aa
	inc hl			;68ab
	ld (hl),a			;68ac
	inc hl			;68ad
	ld (hl),a			;68ae
	ex de,hl			;68af
	call apunta_un_trio		;68b0   ; y a la lista de trios
	inc (hl)			;68b3   ; con marca 1: ABIERTO
	ld hl,0e2d9h		;68b4
	inc (hl)			;68b7   ; un trio abierto mas
	ld hl,0e2b6h		;68b8
	inc (hl)			;68bb   ; y una llamada mas: la mano ya no esta cerrada
	call apunta_la_ficha_robada		;68bc   ; la ficha robada, a la lista del jugador
	ld a,(0e206h)		;68bf
	rra			;68c2
	jr nc,L_68CA		;68c3
	call devuelve_la_mano_al_jugador_2		;68c5   ; la mano vuelve al jugador 2
	jr cierra_la_llamada		;68c8
L_68CA:
	call devuelve_la_mano_al_jugador_1		;68ca   ; o al 1, y se repinta
	call pinta_la_mano_del_jugador_1		;68cd

; ----------------------------------------------------------------------
; Remate del pon y del kan: la parte cerrada tiene tres fichas menos (0xE209 y 0xE20A bajan tres), el jugador 1 pasa a la fase 1 (0xE1AA = 1: descartar), sonido 11 y C = 0: la llamada se ha hecho.
; ----------------------------------------------------------------------
cierra_la_llamada:
	ld a,(0e20ah)		;68d0
	sub 003h		;68d3   ; tres fichas menos en la parte cerrada
	ld (0e209h),a		;68d5
	ld (0e20ah),a		;68d8
	ld a,(0e206h)		;68db
	rra			;68de
	jr c,L_68E6		;68df   ; la maquina no toca la fase
	ld a,001h		;68e1
	ld (0e1aah),a		;68e3   ; fase 1: toca descartar
L_68E6:
	ld a,00bh		;68e6
	call pide_un_sonido		;68e8   ; sonido 11
	ld c,000h		;68eb   ; C = 0: hecha
	jr L_68FC		;68ed
rechaza_pon:
	ld c,001h		;68ef   ; C = 1: no se ha hecho
	ld a,(0e206h)		;68f1
	rra			;68f4
	jr c,L_68FC		;68f5   ; a la maquina no se le pinta el aviso
	ld a,002h		;68f7
	call pinta_uno_de_los_tres_dibujos		;68f9   ; el dibujo 2, que suena
L_68FC:
	jp L_66D5		;68fc

; ----------------------------------------------------------------------
; Copia los 18 bytes de la mano de trabajo (0xE32B) a la del jugador 1 (0xE13A).
; ----------------------------------------------------------------------
devuelve_la_mano_al_jugador_1:
	ld hl,0e32bh		;68ff
	ld de,0e13ah		;6902
	ld bc,00012h		;6905
	ldir		;6908
	ret			;690a

; ----------------------------------------------------------------------
; La gemela para el jugador 2: 0xE32B a 0xE14C.
; ----------------------------------------------------------------------
devuelve_la_mano_al_jugador_2:
	ld hl,0e32bh		;690b
	ld de,0e14ch		;690e
	ld bc,00012h		;6911
	ldir		;6914
	ret			;6916

; ----------------------------------------------------------------------
; Apunta la ficha que se acaba de robar al rival (0xE128) en la lista del jugador: 0xE22D para el 1 y 0xE232 para el 2, una cuenta y hasta cuatro fichas. La del 2 (0xE233) es la que 0x4833 cruza con las esperas del 1 para el furiten: son descartes del 1 que ya no estan en su rio.
; ----------------------------------------------------------------------
apunta_la_ficha_robada:
	ld hl,0e22dh		;6917
	ld a,(0e206h)		;691a
	rra			;691d   ; bit 0 de 0xE206: la lista del 2
	jr nc,L_6923		;691e
	ld hl,0e232h		;6920
L_6923:
	ld a,(hl)			;6923
	ld d,a			;6924
	inc (hl)			;6925   ; una mas
	inc hl			;6926
	call suma_a_a_hl		;6927
	ld a,(0e128h)		;692a
	ld (hl),a			;692d   ; la ficha
	ret			;692e

; ----------------------------------------------------------------------
; CHI: robar el ultimo descarte del rival para hacer escalera. No en la fase 1 ni en riichi. La primera vez (bit 0 de 0xE1AB a cero) busca en la mano las tres escaleras posibles -ficha-2 con ficha-1, ficha-1 con ficha+1, ficha+1 con ficha+2- y apunta cada una que encuentra: los dos huecos de la mano en 0xE1E9 (0x6C02) y la ficha por la que empieza en 0xE1F1 (0x6BF5). Un honor (0x31 o mas) no se puede chi. Sin ninguna, se rechaza; con una, se ejecuta (0x6AA2); con dos o tres, el jugador elige (0x69F9).
; ----------------------------------------------------------------------
hace_chi:
	ld a,(0e1aah)		;692f
	dec a			;6932   ; fase 1: no
	jp z,rechaza_chi		;6933
	ld a,(0e33eh)		;6936
	rra			;6939   ; en riichi tampoco
	jp c,rechaza_chi		;693a
	ld hl,0e1abh		;693d
	bit 0,(hl)		;6940   ; bit 0 de 0xE1AB: las opciones ya estan buscadas
	jp z,L_694B		;6942
	bit 1,(hl)		;6945   ; bit 1: el jugador esta eligiendo
	jp z,elige_la_escalera		;6947
	ret			;694a
L_694B:
	ld a,0ffh		;694b   ; 0xFF: ninguna opcion aun
	ld (0e1efh),a		;694d
	ld a,(0e206h)		;6950
	rra			;6953   ; los descartes del rival
	ld a,(0e1bfh)		;6954
	ld hl,0e172h		;6957
	jr nc,L_6962		;695a
	ld a,(0e1beh)		;695c
	ld hl,0e15eh		;695f
L_6962:
	call suma_a_a_hl		;6962
	ld a,(hl)			;6965
	cp 031h		;6966   ; un honor no forma escalera
	jp nc,rechaza_chi		;6968
	ld (0e128h),a		;696b   ; la ficha del chi
	ld (0e129h),hl		;696e   ; y donde esta en el rio
	ld c,000h		;6971
	ld a,(0e128h)		;6973
	dec a			;6976   ; la ficha menos uno
	ld hl,0e32bh		;6977
	call busca_en_la_mano		;697a   ; la busca en la mano
	cp (hl)			;697d   ; no esta
	jr nz,L_69A1		;697e
	ld c,001h		;6980
	ld (0e12bh),hl		;6982
	dec a			;6985   ; y la ficha menos dos
	ld hl,0e32bh		;6986
	call busca_en_la_mano		;6989
	cp (hl)			;698c
	jr nz,L_69A1		;698d
	call apunta_un_hueco_de_la_opcion		;698f   ; primera opcion: menos dos, menos uno, ficha
	ld hl,(0e12bh)		;6992
	call apunta_un_hueco_de_la_opcion		;6995
	ld a,(0e128h)		;6998
	dec a			;699b
	dec a			;699c
	ld b,a			;699d
	call apunta_la_primera_ficha_de_la_opcion		;699e
L_69A1:
	ld a,(0e128h)		;69a1
	inc a			;69a4   ; la ficha mas uno
	ld hl,0e32bh		;69a5
	call busca_en_la_mano		;69a8
	cp (hl)			;69ab
	jr nz,L_69E5		;69ac
	ld (0e12dh),hl		;69ae
	ld a,c			;69b1
	cp 001h		;69b2
	jr nz,L_69C7		;69b4
	call apunta_un_hueco_de_la_opcion		;69b6   ; segunda: menos uno, ficha, mas uno
	ld hl,(0e12bh)		;69b9
	call apunta_un_hueco_de_la_opcion		;69bc
	ld a,(0e128h)		;69bf
	dec a			;69c2
	ld b,a			;69c3
	call apunta_la_primera_ficha_de_la_opcion		;69c4
L_69C7:
	ld a,(0e128h)		;69c7
	inc a			;69ca
	inc a			;69cb   ; la ficha mas dos
	ld hl,0e32bh		;69cc
	call busca_en_la_mano		;69cf
	cp (hl)			;69d2
	jr nz,L_69E5		;69d3
	call apunta_un_hueco_de_la_opcion		;69d5   ; tercera: ficha, mas uno, mas dos
	ld hl,(0e12dh)		;69d8
	call apunta_un_hueco_de_la_opcion		;69db
	ld a,(0e128h)		;69de
	ld b,a			;69e1
	call apunta_la_primera_ficha_de_la_opcion		;69e2
L_69E5:
	ld a,(0e1efh)		;69e5
	cp 0ffh		;69e8   ; sin opciones: se rechaza
	jp z,rechaza_chi		;69ea
	sra a		;69ed   ; 0xE1EF pasa de 2n-1 a n-1: opciones menos una
	ld (0e1efh),a		;69ef
	cp 001h		;69f2
	jr nc,elige_la_escalera		;69f4   ; con dos o mas, a elegir
	jp ejecuta_el_chi		;69f6   ; con una, se ejecuta

; ----------------------------------------------------------------------
; El jugador elige entre las dos o tres escaleras posibles: bit 1 de 0xE1AB mientras dura, la elegida en 0xE1F0; izquierda y derecha (bits 2 y 3 de 0xE009) la cambian cada 16 fotogramas con sonido 5, y los dos huecos de la mano se marcan con un par de sprites (0xE0A8, X de la tabla de 0x5350). Espacio (bit 4, en el flanco) la confirma y ejecuta. La maquina no elige: con mas de una opcion cancela la llamada.
; ----------------------------------------------------------------------
elige_la_escalera:
	ld a,(0e206h)		;69f9
	rra			;69fc
	jp c,cancela_la_eleccion		;69fd   ; la maquina no elige: cancela
	ld hl,0e1abh		;6a00
	set 1,(hl)		;6a03   ; bit 1: eligiendo
	ld hl,0e1c4h		;6a05
	ld a,(0e009h)		;6a08
	and 010h		;6a0b   ; bit 4: espacio
	jr nz,L_6A13		;6a0d
	res 0,(hl)		;6a0f
	jr L_6A21		;6a11
L_6A13:
	bit 0,(hl)		;6a13
	jr nz,L_6A21		;6a15
	set 0,(hl)		;6a17   ; el flanco del espacio, en 0xE1C4
	ld a,006h		;6a19
	call pide_un_sonido		;6a1b   ; sonido 6
	jp ejecuta_el_chi		;6a1e   ; y se ejecuta la elegida
L_6A21:
	ld a,(0e003h)		;6a21
	and 00fh		;6a24   ; cada 16 fotogramas
	ret nz			;6a26
	ld hl,0e009h		;6a27
	bit 2,(hl)		;6a2a   ; bit 2: izquierda
	jr z,L_6A46		;6a2c
	ld a,005h		;6a2e
	call pide_un_sonido		;6a30   ; sonido 5
	ld a,(0e1f0h)		;6a33
	dec a			;6a36
	ld (0e1f0h),a		;6a37
	or a			;6a3a
	jp p,L_6A65		;6a3b   ; la anterior, o la ultima si se pasa
	ld a,(0e1efh)		;6a3e
	ld (0e1f0h),a		;6a41
	jr L_6A65		;6a44
L_6A46:
	ld hl,0e009h		;6a46
	bit 3,(hl)		;6a49   ; bit 3: derecha
	jr z,L_6A65		;6a4b
	ld a,005h		;6a4d
	call pide_un_sonido		;6a4f
	ld a,(0e1f0h)		;6a52
	inc a			;6a55
	ld hl,0e1efh		;6a56
	ld (0e1f0h),a		;6a59
	cp (hl)			;6a5c   ; la siguiente, o la primera si se pasa
	jr c,L_6A65		;6a5d
	jr z,L_6A65		;6a5f
	xor a			;6a61
	ld (0e1f0h),a		;6a62
L_6A65:
	ld a,(0e1f0h)		;6a65
	sla a		;6a68   ; dos huecos por opcion
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
	ld hl,05350h		;6a7b   ; la X de cada hueco, de la tabla de 0x5350
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
	ld de,03b00h		;6a99   ; los atributos de los sprites, a 0x3B00
	ld bc,00010h		;6a9c
	jp copia_a_la_vram		;6a9f

; ----------------------------------------------------------------------
; Ejecuta la escalera elegida (0xE1F0): quita de la mano los dos huecos apuntados en 0xE1E9 y el descarte del rio del rival (0x39 en los tres), reordena, y pone la escalera entera -tres seguidas desde la ficha de 0xE1F1- detras de la parte cerrada (0xE20B baja cuatro). La apunta en 0xE2B7 con marca 1 (0xE2C7++, 0xE2B6++), marca la ficha robada con un sprite (0xE0E0 para el 1, 0xE0F0 para el 2) y cierra por 0x6BA7 igual que el pon.
; ----------------------------------------------------------------------
ejecuta_el_chi:
	ld a,(0e206h)		;6aa2
	rra			;6aa5   ; la maquina quita ademas la ficha de su mano de trabajo
	jr nc,L_6AB7		;6aa6
	ld a,(0e128h)		;6aa8
	ld hl,0e32bh		;6aab
	call busca_en_la_mano		;6aae
	cp (hl)			;6ab1
	jp nz,cancela_la_eleccion		;6ab2   ; si no la tiene, cancela
	ld (hl),039h		;6ab5
L_6AB7:
	ld a,(0e1f0h)		;6ab7
	sla a		;6aba   ; dos huecos por opcion
	ld hl,0e1e9h		;6abc
	call suma_a_a_hl		;6abf
	ld b,(hl)			;6ac2
	inc hl			;6ac3
	ld c,(hl)			;6ac4
	ld hl,0e32bh		;6ac5
	ld l,b			;6ac8
	ld (hl),039h		;6ac9   ; 0x39 en los dos huecos
	ld l,c			;6acb
	ld (hl),039h		;6acc
	ld de,(0e129h)		;6ace
	ld a,039h		;6ad2
	ld (de),a			;6ad4   ; y en el descarte robado
	call pinta_el_rio_del_jugador_2		;6ad5   ; repinta el rio del rival
	ld a,(0e206h)		;6ad8
	rra			;6adb
	jr nc,L_6AE1		;6adc
	call pinta_el_rio_del_jugador_1		;6ade
L_6AE1:
	ld a,(0e20ah)		;6ae1
	inc a			;6ae4
	ld b,a			;6ae5
	ld hl,0e32bh		;6ae6
	call L_4F9B		;6ae9   ; reordena
	ld a,(0e20bh)		;6aec
	sub 004h		;6aef   ; el limite de la parte cerrada baja cuatro
	cp 00ch		;6af1
	jr nz,L_6AF6		;6af3
	dec a			;6af5
L_6AF6:
	ld (0e20bh),a		;6af6
	inc a			;6af9
	ld hl,0e32bh		;6afa
	call suma_a_a_hl		;6afd
	ld a,(0e1f0h)		;6b00   ; la ficha por la que empieza la escalera
	ld de,0e1f1h		;6b03
	call suma_a_a_de		;6b06
	ld a,(de)			;6b09
	ld (hl),a			;6b0a   ; las tres seguidas, detras de la parte cerrada
	inc a			;6b0b
	inc hl			;6b0c
	ld (hl),a			;6b0d
	inc a			;6b0e
	inc hl			;6b0f
	ld (hl),a			;6b10
	push de			;6b11
	call apunta_la_ficha_robada		;6b12   ; la ficha robada, a la lista del jugador
	ld a,(0e20bh)		;6b15
	add a,004h		;6b18
	ld b,a			;6b1a
	dec a			;6b1b
	ld hl,0e32bh		;6b1c
	call suma_a_a_hl		;6b1f
	ld a,(0e128h)		;6b22
L_6B25:
	cp (hl)			;6b25   ; busca la robada dentro de la escalera
	jr z,L_6B2B		;6b26
	dec hl			;6b28
	djnz L_6B25		;6b29
L_6B2B:
	dec b			;6b2b
	ld a,d			;6b2c
	rla			;6b2d
	rla			;6b2e
	ld d,a			;6b2f
	ld a,(0e206h)		;6b30   ; bit 0: los sprites del 2 (0xE0F0) o del 1 (0xE0E0)
	rra			;6b33
	ld a,d			;6b34
	jr c,L_6B59		;6b35
	ld hl,0e0e0h		;6b37
	call suma_a_a_hl		;6b3a
	ld (hl),0bch		;6b3d   ; patron 0xBC: la marca de ficha robada del jugador 1
	ld a,b			;6b3f
	cp 00eh		;6b40   ; de la ficha 14 en adelante es la segunda fila de figuras
	jr c,L_6B48		;6b42
	sub 004h		;6b44
	ld (hl),0a8h		;6b46   ; patron 0xA8 para la segunda fila
L_6B48:
	ld hl,05350h		;6b48
	call suma_a_a_hl		;6b4b   ; la X, de la tabla de 0x5350
	ld a,d			;6b4e
	ld de,0e0e1h		;6b4f
	call suma_a_a_de		;6b52
	ld a,(hl)			;6b55
	ld (de),a			;6b56
	jr L_6B7D		;6b57
L_6B59:
	ld hl,0e0f0h		;6b59
	call suma_a_a_hl		;6b5c
	ld (hl),0ffh		;6b5f   ; patron 0xFF para el jugador 2
	ld a,b			;6b61
	cp 00eh		;6b62
	jr c,L_6B6A		;6b64
	sub 004h		;6b66
	ld (hl),017h		;6b68   ; y 0x17 para su segunda fila
L_6B6A:
	sub 00eh		;6b6a
	xor 0ffh		;6b6c
	ld hl,05350h		;6b6e   ; la X, contada desde el otro lado
	call suma_a_a_hl		;6b71
	ld a,d			;6b74
	ld de,0e0f1h		;6b75
	call suma_a_a_de		;6b78
	ld a,(hl)			;6b7b
	ld (de),a			;6b7c
L_6B7D:
	ld hl,0e0e0h		;6b7d
	ld de,03b38h		;6b80   ; los atributos, a 0x3B38
	ld bc,00020h		;6b83
	call copia_a_la_vram		;6b86
	pop de			;6b89
	call apunta_una_escalera		;6b8a   ; la escalera, a la lista
	inc (hl)			;6b8d   ; con marca 1: ABIERTA
	ld hl,0e2c7h		;6b8e
	inc (hl)			;6b91   ; una escalera abierta mas
	ld hl,0e2b6h		;6b92
	inc (hl)			;6b95   ; y una llamada mas: la mano ya no esta cerrada
	ld a,(0e206h)		;6b96
	rra			;6b99
	jr c,L_6BA4		;6b9a
	call devuelve_la_mano_al_jugador_1		;6b9c   ; la mano vuelve al jugador 1, y se repinta
	call pinta_la_mano_del_jugador_1		;6b9f
	jr cierra_el_chi		;6ba2
L_6BA4:
	call devuelve_la_mano_al_jugador_2		;6ba4   ; o al 2
cierra_el_chi:
	ld a,(0e20ah)		;6ba7
	sub 003h		;6baa   ; tres fichas menos en la parte cerrada
	ld (0e209h),a		;6bac
	ld (0e20ah),a		;6baf
	ld a,(0e206h)		;6bb2
	rra			;6bb5
	jr c,L_6BBD		;6bb6
	ld a,001h		;6bb8
	ld (0e1aah),a		;6bba   ; fase 1: toca descartar
L_6BBD:
	ld a,00bh		;6bbd
	call pide_un_sonido		;6bbf   ; sonido 11
	ld c,000h		;6bc2
	jr cancela_la_eleccion		;6bc4
rechaza_chi:
	ld c,001h		;6bc6   ; C = 1: no se ha hecho
	ld a,(0e206h)		;6bc8
	rra			;6bcb
	jr c,cancela_la_eleccion		;6bcc
	ld a,002h		;6bce
	call pinta_uno_de_los_tres_dibujos		;6bd0   ; el dibujo 2

; ----------------------------------------------------------------------
; Deja la eleccion de chi a cero: 0xE1AB, 0xE1C7, los once bytes de opciones (0xE1E9-0xE1F3) y los cuatro sprites de 0x3B00, que se mandan a Y=0xE0, fuera de la pantalla.
; ----------------------------------------------------------------------
cancela_la_eleccion:
	xor a			;6bd3
	ld (0e1abh),a		;6bd4
	ld (0e1c7h),a		;6bd7
	xor a			;6bda
	ld b,00bh		;6bdb   ; once bytes: las opciones
	ld hl,0e1e9h		;6bdd
L_6BE0:
	ld (hl),a			;6be0
	inc hl			;6be1
	djnz L_6BE0		;6be2
	ld b,004h		;6be4
L_6BE6:
	ld a,0e0h		;6be6   ; Y=0xE0: el sprite desaparece
	ld de,03b00h		;6be8
	call escribe_en_vram		;6beb
	ld a,e			;6bee
	add a,004h		;6bef
	ld e,a			;6bf1
	djnz L_6BE6		;6bf2
	ret			;6bf4
apunta_la_primera_ficha_de_la_opcion:
	ld a,(0e1efh)		;6bf5
	sra a		;6bf8   ; la mitad de 0xE1EF: el numero de opcion
	ld hl,0e1f1h		;6bfa
	call suma_a_a_hl		;6bfd
	ld (hl),b			;6c00
	ret			;6c01
apunta_un_hueco_de_la_opcion:
	ld b,l			;6c02
	ld hl,0e1efh		;6c03
	inc (hl)			;6c06   ; dos huecos por opcion
	ld a,(0e1efh)		;6c07
	ld hl,0e1e9h		;6c0a
	call suma_a_a_hl		;6c0d
	ld (hl),b			;6c10
	ret			;6c11

; ----------------------------------------------------------------------
; KAN, en sus tres formas. Guarda copia de la mano en 0xE348 por si hay que deshacer. Con 0xE22C a cero la ficha es el ultimo descarte del rival (DAIMINKAN, abierto; no vale en riichi); si no, es la recien robada, la de 0xE209. Con tres copias en la mano (0x6C5F) se quitan esas tres -y la robada, o el descarte-; sin ellas (0x6CCA) se buscan cuatro iguales seguidas en la parte cerrada (0x6E69, ankan) o un pon ya declarado de esa ficha (0x6CE7, SHOUMINKAN, 0xE12B = 1). Luego 0x6D64 apunta el cuarteto, 0x6DB9 reordena y pinta, y 0x6DED decide si hay que comprobar las esperas.
; ----------------------------------------------------------------------
hace_kan:
	ld hl,0e32bh		;6c12   ; copia de la mano, por si hay que deshacer
	ld de,0e348h		;6c15
	ld bc,00012h		;6c18
	ldir		;6c1b
	ld a,(0e22ch)		;6c1d
	or a			;6c20   ; 0xE22C a cero: la ficha es el descarte del rival
	jr nz,L_6C41		;6c21
	ld a,(0e33eh)		;6c23
	rra			;6c26
	jp c,rechaza_kan		;6c27   ; en riichi no se roba para kan
	ld a,(0e206h)		;6c2a
	rra			;6c2d
	ld a,(0e1bfh)		;6c2e   ; los descartes del rival
	ld hl,0e172h		;6c31
	jr nc,L_6C3C		;6c34
	ld a,(0e1beh)		;6c36
	ld hl,0e15eh		;6c39
L_6C3C:
	call suma_a_a_hl		;6c3c
	jr L_6C4A		;6c3f
L_6C41:
	ld a,(0e209h)		;6c41   ; con ficha propia es la recien robada, en 0xE209
	ld hl,0e32bh		;6c44
	call suma_a_a_hl		;6c47
L_6C4A:
	ld a,(hl)			;6c4a
	cp 039h		;6c4b   ; 0x39: no hay ficha
	jp z,L_6E5A		;6c4d
	ld (0e128h),a		;6c50   ; la ficha del kan
	ld (0e129h),hl		;6c53
	ld a,(0e128h)		;6c56
	ld hl,0e32bh		;6c59
	call busca_en_la_mano		;6c5c   ; su primera copia en la mano
	ld a,(0e128h)		;6c5f
	cp (hl)			;6c62
	jr nz,L_6CCA		;6c63   ; tres copias seguidas, o por 0x6CCA
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
	cp l			;6c77   ; si las tres empiezan en el hueco de la robada, por 0x6CCA
	jr z,L_6CCA		;6c78
	push hl			;6c7a
	ld c,000h		;6c7b
	ld a,c			;6c7d
	ld (0e12bh),a		;6c7e   ; 0xE12B = 0: kan normal
	ld a,(0e22ch)		;6c81
	or a			;6c84
	jr z,L_6CC6		;6c85   ; con el descarte del rival, las tres se quitan y listo
	ld hl,0e20ah		;6c87
	ld a,(0e209h)		;6c8a
	cp (hl)			;6c8d
	jr z,L_6CC6		;6c8e   ; la robada es una de las tres
	ld a,(0e128h)		;6c90
	pop hl			;6c93
	inc hl			;6c94
	cp (hl)			;6c95   ; una cuarta copia detras: se quitan las cuatro
	jr z,L_6CB0		;6c96
	dec hl			;6c98
	ex de,hl			;6c99
	ld a,(0e20ah)		;6c9a
	ld hl,0e32bh		;6c9d
	call suma_a_a_hl		;6ca0
	ld a,(0e128h)		;6ca3
	cp (hl)			;6ca6   ; la robada del final de la mano tiene que ser la misma ficha
	jr nz,L_6CCA		;6ca7
	ld (0e129h),hl		;6ca9   ; y es la que se quita aparte
	ex de,hl			;6cac
	jp quita_las_copias		;6cad
L_6CB0:
	push hl			;6cb0
	ld a,(0e209h)		;6cb1
	ld hl,0e32bh		;6cb4
	call suma_a_a_hl		;6cb7   ; la cuarta copia es la robada
	ld (0e129h),hl		;6cba
	ld c,001h		;6cbd   ; C = 1: cuatro huecos que quitar
	ld hl,(0e129h)		;6cbf
	ld a,(hl)			;6cc2
	ld (0e128h),a		;6cc3
L_6CC6:
	pop hl			;6cc6
	jp quita_las_copias		;6cc7
L_6CCA:
	ld a,(0e22ch)		;6cca
	rra			;6ccd   ; sin ficha propia no hay mas kan que probar
	jp nc,rechaza_kan		;6cce
	call busca_cuatro_iguales		;6cd1   ; busca cuatro iguales seguidas en la parte cerrada
	ld a,c			;6cd4
	cp 003h		;6cd5   ; C = 3: las hay
	jr nz,L_6CE7		;6cd7
	ld a,(hl)			;6cd9
	ld (0e128h),a		;6cda
	ld (0e129h),hl		;6cdd
	ld a,002h		;6ce0
	ld (0e12bh),a		;6ce2   ; 0xE12B = 2: kan cerrado con cuatro de la mano
	jr quita_las_copias		;6ce5
L_6CE7:
	ld a,(0e22ch)		;6ce7
	rra			;6cea
	jp nc,rechaza_kan		;6ceb   ; con la ficha del rival no hay kan anadido
	ld hl,0e20bh		;6cee
	ld a,012h		;6cf1   ; las figuras declaradas van de 0xE20B a 18
	sub (hl)			;6cf3
	or a			;6cf4
	jp z,rechaza_kan		;6cf5   ; ninguna declarada
	ld b,a			;6cf8
	ld hl,0e32bh		;6cf9
	ld a,(0e20bh)		;6cfc
	call suma_a_a_hl		;6cff
	ld a,(0e128h)		;6d02
L_6D05:
	cp (hl)			;6d05   ; busca la ficha entre las figuras
	jr z,L_6D0E		;6d06
	inc hl			;6d08
	djnz L_6D05		;6d09
	jp rechaza_kan		;6d0b   ; no esta
L_6D0E:
	inc hl			;6d0e
	cp (hl)			;6d0f
	jp nz,rechaza_kan		;6d10   ; y tiene que ser un trio: dos copias mas
	inc hl			;6d13
	cp (hl)			;6d14
	jp nz,rechaza_kan		;6d15
	dec hl			;6d18
	dec hl			;6d19
	dec hl			;6d1a
	ld (hl),a			;6d1b   ; la ficha, delante del trio: ya son cuatro
	ld hl,0e2c9h		;6d1c
	ld b,004h		;6d1f
L_6D21:
	cp (hl)			;6d21   ; el trio, en la lista de 0xE2C9
	jr z,L_6D2A		;6d22
	ld a,l			;6d24
	add a,002h		;6d25
	ld l,a			;6d27
	djnz L_6D21		;6d28
L_6D2A:
	ex de,hl			;6d2a
	ld hl,0e2c9h		;6d2b
	ld a,(0e2dah)		;6d2e   ; el primer registro libre
	add a,a			;6d31
	add a,a			;6d32
	add a,l			;6d33
	ld l,a			;6d34
	push hl			;6d35
	ld bc,00004h		;6d36
	ldir		;6d39   ; copia el trio al hueco libre y luego lo borra: solo lo quita si era el ultimo
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
	dec (hl)			;6d47   ; un trio abierto menos
	ld hl,0e304h		;6d48
	dec (hl)			;6d4b   ; el cursor, uno menos
	ld hl,0e2dah		;6d4c
	dec (hl)			;6d4f   ; y un trio menos
	ld a,001h		;6d50
	ld (0e12bh),a		;6d52   ; 0xE12B = 1: KAN ANADIDO sobre un pon
	jr apunta_el_cuarteto		;6d55

; ----------------------------------------------------------------------
; Cambia por 0x39 las tres copias que acaban en HL, o cuatro si C no es cero.
; ----------------------------------------------------------------------
quita_las_copias:
	ld b,039h		;6d57
	ld (hl),b			;6d59   ; las tres copias, hacia atras
	dec hl			;6d5a
	ld (hl),b			;6d5b
	dec hl			;6d5c
	ld (hl),b			;6d5d
	ld a,c			;6d5e
	or a			;6d5f   ; C distinto de cero: hay una cuarta
	jr z,apunta_el_cuarteto		;6d60
	dec hl			;6d62
	ld (hl),b			;6d63

; ----------------------------------------------------------------------
; Quita la ficha que cierra el kan (del rio del rival si viene de fuera, de la mano si es propia), baja el limite de la parte cerrada (salvo en el kan anadido) y apunta el cuarteto en 0xE2DB por 0x61B9. La marca: ABIERTO (1) con el descarte del rival o en el kan anadido, CERRADO (0) con cuatro de la mano. El abierto cuenta como llamada (0xE2B6++, salvo el anadido, que ya contaba) y sube 0xE2EF, los kan abiertos.
; ----------------------------------------------------------------------
apunta_el_cuarteto:
	ld hl,(0e129h)		;6d64
	ld a,(0e22ch)		;6d67   ; con ficha propia no hay rio que tocar
	or a			;6d6a
	jr nz,L_6D7D		;6d6b
	ld (hl),039h		;6d6d   ; el descarte robado desaparece del rio
	call pinta_el_rio_del_jugador_2		;6d6f   ; y se repinta
	ld a,(0e206h)		;6d72
	rra			;6d75
	jr nc,L_6D7B		;6d76
	call pinta_el_rio_del_jugador_1		;6d78
L_6D7B:
	jr L_6D7F		;6d7b
L_6D7D:
	ld (hl),039h		;6d7d   ; la ficha robada, fuera de la mano
L_6D7F:
	ld a,(0e12bh)		;6d7f
	cp 001h		;6d82   ; el kan anadido no mueve la parte cerrada
	jr z,L_6D93		;6d84
	ld a,(0e20bh)		;6d86
	sub 004h		;6d89   ; los demas: el limite baja cuatro
	cp 00ch		;6d8b
	jr nz,L_6D90		;6d8d
	dec a			;6d8f
L_6D90:
	ld (0e20bh),a		;6d90
L_6D93:
	ld hl,0e128h		;6d93
	ex de,hl			;6d96
	call apunta_un_cuarteto		;6d97   ; el cuarteto, a la lista de 0xE2DB
	ld a,(0e22ch)		;6d9a
	or a			;6d9d   ; con el descarte del rival siempre es abierto
	jr z,L_6DA6		;6d9e
	ld a,(0e12bh)		;6da0
	dec a			;6da3
	jr nz,coloca_el_cuarteto		;6da4   ; 0xE12B = 2, cuatro de la mano: CERRADO, sin marca
L_6DA6:
	inc (hl)			;6da6   ; marca 1: ABIERTO
	ld a,(0e22ch)		;6da7
	cp 001h		;6daa   ; el kan anadido ya contaba como llamada
	jr z,coloca_el_cuarteto		;6dac
	ld hl,0e2b6h		;6dae
	inc (hl)			;6db1   ; una llamada mas
	ld hl,0e2efh		;6db2
	inc (hl)			;6db5   ; y un kan abierto mas, 0xE2EF
	call apunta_la_ficha_robada		;6db6   ; la ficha robada, a la lista del jugador

; ----------------------------------------------------------------------
; Reordena la mano y escribe las cuatro fichas del kan detras de la parte cerrada, salvo en el kan anadido, que ya estaba escrito. Si el kan es cerrado, las dos de fuera se escriben como 0x38, el DORSO: asi es como se ve un ankan.
; ----------------------------------------------------------------------
coloca_el_cuarteto:
	ld a,(0e20ah)		;6db9
	ld b,a			;6dbc
	ld a,(0e22ch)		;6dbd
	or a			;6dc0
	jr z,L_6DC4		;6dc1
	inc b			;6dc3   ; con ficha propia hay una mas que ordenar
L_6DC4:
	ld hl,0e32bh		;6dc4
	call L_4F9B		;6dc7   ; reordena
	ld a,(0e12bh)		;6dca
	dec a			;6dcd
	jr z,remata_el_kan		;6dce   ; el kan anadido no se vuelve a escribir
	ld a,(0e20bh)		;6dd0
	ld hl,0e32bh		;6dd3
	call suma_a_a_hl		;6dd6   ; las cuatro, detras de la parte cerrada
	ld a,(0e128h)		;6dd9
	ld b,a			;6ddc
	ld c,a			;6ddd
	ld a,(0e22ch)		;6dde
	or a			;6de1
	jr z,L_6DE6		;6de2
	ld c,038h		;6de4   ; 0x38: las dos de fuera BOCA ABAJO si el kan es cerrado
L_6DE6:
	ld (hl),c			;6de6   ; dorso o ficha, ficha, ficha, dorso o ficha
	inc hl			;6de7
	ld (hl),b			;6de8
	inc hl			;6de9
	ld (hl),b			;6dea
	inc hl			;6deb
	ld (hl),c			;6dec

; ----------------------------------------------------------------------
; Guarda 0xE209/0xE20A por si hay que deshacer, quita tres fichas de la parte cerrada (cuatro fuera y una de reposicion que vendra) y, si es la maquina o el jugador esta en riichi, comprueba que las esperas no cambien (0x6E87); si cambian, se rechaza. Al final la mano vuelve al jugador, la fase pasa a 0xFF (robar la ficha de reposicion), suena el 11 y 0xE1CF = 1 marca esa ficha para el rinshan kaihou.
; ----------------------------------------------------------------------
remata_el_kan:
	ld a,(0e209h)		;6ded   ; guarda hueco e indice por si hay que deshacer
	ld (0e12ch),a		;6df0
	ld a,(0e20ah)		;6df3
	ld (0e12dh),a		;6df6
	ld a,(0e12bh)		;6df9
	dec a			;6dfc   ; el kan anadido no cambia la parte cerrada
	jr z,L_6E20		;6dfd
	ld a,(0e20ah)		;6dff
	sub 003h		;6e02   ; los demas: tres fichas menos, cuatro fuera y una de reposicion
	ld (0e209h),a		;6e04
	ld (0e20ah),a		;6e07
	ld b,000h		;6e0a
	ld a,(0e206h)		;6e0c
	rra			;6e0f   ; la maquina siempre comprueba las esperas
	jr c,L_6E18		;6e10
	ld a,(0e33eh)		;6e12
	rra			;6e15   ; el jugador solo en riichi
	jr nc,L_6E1B		;6e16
L_6E18:
	call comprueba_que_las_esperas_no_cambien		;6e18   ; comprueba que las esperas no cambien
L_6E1B:
	ld a,b			;6e1b
	dec a			;6e1c
	jp z,rechaza_kan		;6e1d   ; han cambiado: se rechaza
L_6E20:
	ld a,(0e206h)		;6e20
	rra			;6e23
	jr c,L_6E2E		;6e24
	call devuelve_la_mano_al_jugador_1		;6e26   ; la mano vuelve al jugador 1
	call pinta_la_mano_del_jugador_1		;6e29
	jr L_6E31		;6e2c
L_6E2E:
	call devuelve_la_mano_al_jugador_2		;6e2e   ; o al 2
L_6E31:
	ld c,000h		;6e31
	ld a,(0e206h)		;6e33
	rra			;6e36
	jr c,L_6E5A		;6e37
	ld a,0ffh		;6e39
	ld (0e1aah),a		;6e3b   ; fase 0xFF: hay que robar la ficha de reposicion
	ld a,00bh		;6e3e
	call pide_un_sonido		;6e40   ; sonido 11
	ld a,001h		;6e43
	ld (0e1cfh),a		;6e45   ; 0xE1CF = 1: la ficha siguiente es la de reposicion, el rinshan
	call para_un_momento		;6e48   ; y una pausa a pelo
	jr L_6E5A		;6e4b
rechaza_kan:
	ld c,001h		;6e4d   ; C = 1: no se ha hecho
	ld a,(0e206h)		;6e4f
	rra			;6e52
	jr c,L_6E5A		;6e53
	ld a,002h		;6e55
	call pinta_uno_de_los_tres_dibujos		;6e57   ; el dibujo 2
L_6E5A:
	jp L_66D5		;6e5a

; ----------------------------------------------------------------------
; Devuelve en HL el primer hueco de la mano (desde HL, 0xE20A fichas) que tiene la ficha A; si no esta, HL se queda en el ultimo. La usan pon, chi, kan y la IA (0x53A8).
; ----------------------------------------------------------------------
busca_en_la_mano:
	push hl			;6e5d
	ld hl,0e20ah		;6e5e
	ld b,(hl)			;6e61   ; cuantas fichas mirar
	pop hl			;6e62
L_6E63:
	cp (hl)			;6e63
	ret z			;6e64   ; encontrada
	inc hl			;6e65
	djnz L_6E63		;6e66
	ret			;6e68

; ----------------------------------------------------------------------
; Cuenta iguales seguidas en la mano de 0xE32B (o, por 0x6E6F, en la que digan DE y HL): C sube con cada ficha igual a la anterior y vuelve a cero al cambiar. En cuanto llega a 3 -cuatro fichas iguales- vuelve con HL en la cuarta; si no las hay, C queda por debajo de 3.
; ----------------------------------------------------------------------
busca_cuatro_iguales:
	ld de,0e32bh		;6e69
	ld hl,0e32ch		;6e6c
L_6E6F:
	ld c,000h		;6e6f   ; C cuenta las iguales seguidas
	ld a,(0e20ah)		;6e71
	ld b,a			;6e74
L_6E75:
	ld a,(de)			;6e75
	cp (hl)			;6e76   ; igual que la anterior
	jr nz,L_6E7C		;6e77
	inc c			;6e79
	jr L_6E7E		;6e7a
L_6E7C:
	ld c,000h		;6e7c   ; distinta: la cuenta vuelve a cero
L_6E7E:
	ld a,c			;6e7e
	cp 003h		;6e7f   ; tres iguales seguidas son cuatro fichas
	ret z			;6e81
	inc hl			;6e82
	inc de			;6e83
	djnz L_6E75		;6e84
	ret			;6e86

; ----------------------------------------------------------------------
; LA REGLA DEL KAN EN RIICHI. Guarda las esperas de antes (12 bytes a 0xE12E), las recalcula con la mano ya sin el kan (0x66E7) y las compara. Iguales: B = 0 y el kan vale. Distintas: lo DESHACE -repone las esperas, la mano de 0xE348, 0xE209/0xE20A, quita el cuarteto (0xE2F0--, registro a cero)- y vuelve con B = 1 para que 0x6E1B lo rechace.
; ----------------------------------------------------------------------
comprueba_que_las_esperas_no_cambien:
	ld a,(0e206h)		;6e87
	rra			;6e8a
	push af			;6e8b
	ld hl,0e1f5h		;6e8c   ; las esperas del jugador 1
	jr nc,L_6E94		;6e8f
	ld hl,0e20eh		;6e91   ; o del 2
L_6E94:
	ld de,0e12eh		;6e94
	ld bc,0000ch		;6e97   ; doce bytes
	ldir		;6e9a
	call L_66E7		;6e9c   ; y se recalculan con la mano de despues del kan
	pop af			;6e9f
	ld hl,0e1f5h		;6ea0
	jr nc,L_6EA8		;6ea3
	ld hl,0e20eh		;6ea5
L_6EA8:
	ld de,0e12eh		;6ea8
	ld b,00ch		;6eab   ; doce esperas que comparar
L_6EAD:
	ld a,(de)			;6ead
	cp (hl)			;6eae
	jr nz,L_6EB6		;6eaf   ; una distinta: a deshacer
	inc hl			;6eb1
	inc de			;6eb2
	djnz L_6EAD		;6eb3
	ret			;6eb5   ; iguales: el kan vale
L_6EB6:
	ld a,(0e206h)		;6eb6
	rra			;6eb9   ; bit 0 de 0xE206: las esperas del 2
	ld hl,0e12eh		;6eba
	ld de,0e1f5h		;6ebd
	jr nc,L_6EC5		;6ec0
	ld de,0e20eh		;6ec2
L_6EC5:
	ld bc,0000ch		;6ec5   ; las esperas de antes, de vuelta
	ldir		;6ec8
	ld hl,0e348h		;6eca
	ld de,0e32bh		;6ecd   ; la mano de antes
	ld bc,00012h		;6ed0
	ldir		;6ed3
	ld a,(0e12ch)		;6ed5
	ld (0e209h),a		;6ed8
	ld a,(0e12dh)		;6edb
	ld (0e20ah),a		;6ede
	ld hl,0e2f0h		;6ee1
	dec (hl)			;6ee4   ; un cuarteto menos
	xor a			;6ee5
	ld (0e128h),a		;6ee6
	ld de,0e128h		;6ee9
	call L_61C5		;6eec   ; y su registro a cero
	ld (hl),000h		;6eef
	ld b,001h		;6ef1   ; B = 1: el kan no vale
	ret			;6ef3

; ----------------------------------------------------------------------
; Para el recuento, la mano ganadora se pinta en el sitio del jugador 1: si gano el 2 (bit 1 de 0xE302), 0x5754 la destapa y se copia entera sobre 0xE13A; si gano el 1, se le mete la ficha que cierra (0xE1E8) en el hueco de la robada (0xE1C3). Y a pintarla.
; ----------------------------------------------------------------------
pinta_la_mano_ganadora_abajo:
	ld a,(0e302h)		;6ef4
	rra			;6ef7
	rra			;6ef8   ; bit 1 de 0xE302: gano el jugador 2
	jr nc,L_6F0C		;6ef9
	call L_5754		;6efb
	ld hl,0e14ch		;6efe   ; su mano, copiada sobre la del 1
	ld de,0e13ah		;6f01
	ld bc,00012h		;6f04
	ldir		;6f07
	jp pinta_la_mano_del_jugador_1		;6f09
L_6F0C:
	ld de,0e1e8h		;6f0c   ; la ficha que cierra
	ld a,(0e1c3h)		;6f0f   ; al hueco de la robada del jugador 1
	ld hl,0e13ah		;6f12
	call suma_a_a_hl		;6f15
	ld a,(de)			;6f18
	ld (hl),a			;6f19
	jr pinta_la_mano_del_jugador_1		;6f1a

; ----------------------------------------------------------------------
; Tres entradas que pintan un tile suelto en la fila 11: 0x6F1C el 0x0A en 0x3971, 0x6F23 el 0x22 en 0x3974 y 0x6F27 el 0x1A en el mismo sitio. 0x7018 y 0x701E las combinan de dos en dos para el recuento.
; ----------------------------------------------------------------------
pinta_el_tile_de_0x3971:
	ld a,00ah		;6f1c
	ld de,03971h		;6f1e
	jr L_6F78		;6f21
pinta_el_tile_0x22_en_0x3974:
	ld a,022h		;6f23
	jr L_6F29		;6f25
pinta_el_tile_0x1a_en_0x3974:
	ld a,01ah		;6f27
L_6F29:
	ld de,03974h		;6f29
	jr L_6F78		;6f2c

; ----------------------------------------------------------------------
; La mano del jugador 1, abajo: catorce fichas desde 0xE13A en la fila 21 (0x3AA2), y los cuatro huecos de figuras declaradas en la fila 18 (0x3A56).
; ----------------------------------------------------------------------
pinta_la_mano_del_jugador_1:
	ld hl,0e13ah		;6f2e
	ld de,03aa2h		;6f31   ; fila 21, columna 2: la mano
	call pinta_una_fila_de_fichas		;6f34
	ld de,03a56h		;6f37   ; fila 18: las figuras declaradas, cuatro huecos
	ld c,004h		;6f3a
	jr L_6FA5		;6f3c

; ----------------------------------------------------------------------
; La mano del jugador 2, arriba: catorce desde 0xE14C en la fila 0 (0x381C) y de derecha a izquierda, mas sus figuras en la fila 3 (0x3868).
; ----------------------------------------------------------------------
pinta_la_mano_del_jugador_2:
	ld hl,0e14ch		;6f3e
	ld de,0381ch		;6f41   ; fila 0, columna 28, y de derecha a izquierda
	call pinta_una_fila_de_fichas_hacia_la_izquierda		;6f44
	ld de,03868h		;6f47   ; fila 3: las figuras
	ld c,004h		;6f4a
	jr L_6FB4		;6f4c

; ----------------------------------------------------------------------
; Los descartes del jugador 1 (0xE15E): dos filas de diez, la primera en 0x39E2 (fila 15) y la segunda en 0x3A42 (fila 18).
; ----------------------------------------------------------------------
pinta_el_rio_del_jugador_1:
	ld hl,0e15eh		;6f4e
	ld de,039e2h		;6f51
	ld c,00ah		;6f54   ; diez por fila
	call L_6FA5		;6f56
	ld de,03a42h		;6f59   ; la segunda fila
	ld c,00ah		;6f5c
	jr L_6FA5		;6f5e

; ----------------------------------------------------------------------
; Los descartes del jugador 2 (0xE172): dos filas de diez en 0x38DC (fila 6) y 0x387C (fila 3), de derecha a izquierda.
; ----------------------------------------------------------------------
pinta_el_rio_del_jugador_2:
	ld hl,0e172h		;6f60
	ld de,038dch		;6f63
	ld c,00ah		;6f66   ; diez por fila
	call L_6FB4		;6f68
	ld de,0387ch		;6f6b   ; la segunda fila
	ld c,00ah		;6f6e
	jr L_6FB4		;6f70

; ----------------------------------------------------------------------
; Pinta una ficha: entra por 0x6F72 con HL en el codigo, por 0x6F74 con A = codigo (lo pasa por la tabla de 0x4735 para sacar el tile) o por 0x6F78 con el tile ya en A. Son tres filas de dos tiles seguidos -A y A+1, luego A+2 y A+3, luego A+4 y A+5-, bajando 0x20 por fila; el tile 0 se queda en 0. Escribe al puerto con las interrupciones quitadas.
; ----------------------------------------------------------------------
pinta_una_ficha:
	di			;6f72
	ld a,(hl)			;6f73
L_6F74:
	di			;6f74
	call primer_tile_de_la_ficha		;6f75   ; del codigo de ficha al primer tile de su dibujo
L_6F78:
	di			;6f78
	ld (0e127h),a		;6f79
	ld b,003h		;6f7c   ; tres filas de dos tiles
L_6F7E:
	call prepara_escritura_vram		;6f7e
	ld a,(0e127h)		;6f81
	exx			;6f84
	out (c),a		;6f85   ; el tile de la izquierda
	exx			;6f87
	or a			;6f88   ; el 0 se queda en 0
	jr z,L_6F8C		;6f89
	inc a			;6f8b   ; el de la derecha es el siguiente
L_6F8C:
	call L_6FA2		;6f8c   ; un call a un ret pelado: una pausa entre los dos bytes
	exx			;6f8f
	out (c),a		;6f90
	exx			;6f92
	or a			;6f93
	jr z,L_6F97		;6f94
	inc a			;6f96
L_6F97:
	ld (0e127h),a		;6f97
	ld a,020h		;6f9a   ; una fila mas abajo
	call suma_a_a_de		;6f9c
	djnz L_6F7E		;6f9f
	ei			;6fa1
L_6FA2:
	ret			;6fa2

; ----------------------------------------------------------------------
; Pinta C fichas seguidas desde HL (catorce por 0x6FA3), cada una con su dibujo de 2x3 tiles y avanzando dos columnas: la resta de 0x5E deshace las tres filas de 0x20 y suma dos. Es la mano del jugador 1 y los dos rios.
; ----------------------------------------------------------------------
pinta_una_fila_de_fichas:
	ld c,00eh		;6fa3   ; catorce fichas: una mano entera
L_6FA5:
	call pinta_una_ficha		;6fa5
	ld a,05eh		;6fa8   ; 0x5E: tres filas arriba y dos columnas a la derecha
	call resta_a_de_de		;6faa
	inc hl			;6fad
	dec c			;6fae
	jr nz,L_6FA5		;6faf
	ret			;6fb1

; ----------------------------------------------------------------------
; La gemela de 0x6FA3 para la mano de arriba: resta 0x62, tres filas arriba y dos columnas a la IZQUIERDA. La mano del jugador 2 se pinta de derecha a izquierda.
; ----------------------------------------------------------------------
pinta_una_fila_de_fichas_hacia_la_izquierda:
	ld c,00eh		;6fb2   ; catorce fichas
L_6FB4:
	call pinta_una_ficha		;6fb4
	ld a,062h		;6fb7   ; 0x62: tres filas arriba y dos columnas a la izquierda
	call resta_a_de_de		;6fb9
	inc hl			;6fbc
	dec c			;6fbd
	jr nz,L_6FB4		;6fbe
	ret			;6fc0

; ----------------------------------------------------------------------
; Los bloques del tablero: 0x8AD7 y 0x90D4 en formato B, los 56 bytes de 0x8A9F tal cual a 0x2818 y el bloque de 0x90CF. Lo llama 0x4C66 al montar la mano.
; ----------------------------------------------------------------------
pinta_el_tablero:
	ld hl,08ad7h		;6fc1   ; el primer bloque del tablero
	call pinta_lista_formato_b		;6fc4
	ld hl,090d4h		;6fc7
	call pinta_lista_formato_b		;6fca
	ld hl,08a9fh		;6fcd
	ld de,02818h		;6fd0   ; 56 bytes sin comprimir a 0x2818
	ld bc,00038h		;6fd3
	call copia_a_la_vram		;6fd6
	ld hl,090cfh		;6fd9
	jp pinta_lista_formato_b		;6fdc

; ----------------------------------------------------------------------
; Monta las dos manos dibujadas del tablero: la de enfrente GIRADA (0x46B1 leyendo desde 0x93AA) a 0x2140 y la de este lado (0x46DC desde 0x9A05) a 0x0140, mas los bloques 0x92E3, 0x9343, 0x99F4 y 0x99F9.
; ----------------------------------------------------------------------
pinta_las_dos_manos_del_tablero:
	ld hl,093aah		;6fdf   ; el bloque de 0x9343, entrando por 0x93AA
	ld (0e05bh),hl		;6fe2
	ld de,02140h		;6fe5   ; 0x2140: la mano de enfrente, girada
	call pinta_la_mano_del_espejo		;6fe8
	ld hl,09a05h		;6feb
	ld de,00140h		;6fee   ; 0x0140: la de este lado
	ld (0e05bh),hl		;6ff1
	call vuelca_la_mano_de_este_lado		;6ff4
	ld hl,092e3h		;6ff7
	ld de,03020h		;6ffa
	ld bc,00060h		;6ffd
	call copia_a_la_vram		;7000
	ld hl,09343h		;7003
	call pinta_lista_formato_b		;7006
	ld hl,099f4h		;7009
	call pinta_lista_formato_b		;700c
	ld hl,099f9h		;700f
	jp pinta_lista_formato_b		;7012

; ----------------------------------------------------------------------
; Pinta los dos indicadores (0x7024) y cae en 0x7018.
; ----------------------------------------------------------------------
pinta_los_indicadores_y_la_marca_a:
	call pinta_los_dos_indicadores		;7015
pinta_la_marca_a:
	call pinta_el_tile_de_0x3971		;7018
	jp pinta_el_tile_0x22_en_0x3974		;701b
pinta_la_marca_b:
	call pinta_el_tile_de_0x3971		;701e
	jp pinta_el_tile_0x1a_en_0x3974		;7021

; ----------------------------------------------------------------------
; Pinta en grande las dos fichas de 0xE1D3 y 0xE1D4: 48 bytes cada una, los patrones a 0x2850 y 0x28D0 por 0x461C y los colores a 0x0850 y 0x08D0 por 0x462F. 0xE1D3 es el INDICADOR DE DORA y 0xE1D4 el del URA-DORA: lo dice 0x81A9, que es quien los cuenta (el ura solo con riichi). Las dos se pintan igual.
; ----------------------------------------------------------------------
pinta_los_dos_indicadores:
	ld a,(0e1d3h)		;7024   ; el indicador de dora
	ld de,02850h		;7027
	ld hl,03000h		;702a
	call L_7053		;702d
	ld a,(0e1d4h)		;7030   ; y el de ura-dora
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
	push de			;7053   ; el primer tile del dibujo de la ficha
	call primer_tile_de_la_ficha		;7054
	ex de,hl			;7057
	ld l,a			;7058
	ld h,000h		;7059
	add hl,hl			;705b   ; por ocho: donde estan sus patrones
	add hl,hl			;705c
	add hl,hl			;705d
	add hl,de			;705e
	ex de,hl			;705f
	ld bc,00030h		;7060   ; 48 bytes: seis tiles de ocho
	ld hl,0e2b6h		;7063
	call copia_de_la_vram		;7066
	jr L_7081		;7069
L_706B:
	push de			;706b
	call primer_tile_de_la_ficha		;706c   ; lo mismo para los colores
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
	call copia_de_la_vram_sin_fondo_transparente		;707e   ; 48 bytes de colores, por 0x462F
L_7081:
	pop de			;7081
	ld hl,0e2b6h		;7082
	ld bc,00030h		;7085
	jp copia_a_la_vram		;7088

; ----------------------------------------------------------------------
; Los dos bloques de 0x8832 y 0x8A78: los patrones de la fuente katakana (tiles 0x30-0x7F, a 0x2180) y sus colores (0x0180). Lo llama 0x5A46 al montar el recuento, que es donde se escriben los nombres de las jugadas.
; ----------------------------------------------------------------------
pinta_la_fuente_katakana:
	ld hl,08832h		;708b
	call pinta_lista_formato_b		;708e
	ld hl,08a78h		;7091
	jp pinta_lista_formato_b		;7094

; ----------------------------------------------------------------------
; La cabecera del recuento: la mano ganadora abajo (0x6EF4), el dibujo de 0x7376, y 0xE04E = si el ganador NO es el que reparte (el bit 1 de 0xE302 contra 0xE04D): 0 si reparte, 1 si no. Es lo que elige entre las dos tablas de pago (0x5B36) y entre los rotulos 0x7404 y 0x7416.
; ----------------------------------------------------------------------
monta_la_cabecera_del_recuento:
	call pinta_la_mano_ganadora_abajo		;7097
	ld hl,07376h		;709a   ; el dibujo de la cabecera
	call pinta_lista_formato_b		;709d
	ld a,(0e04dh)		;70a0   ; quien reparte
	ld c,a			;70a3
	ld a,(0e302h)		;70a4
	rra			;70a7   ; bit 1 de 0xE302: quien ha ganado
	and 001h		;70a8
	xor c			;70aa
	ld a,000h		;70ab   ; 0xE04E = 0: el ganador es el que reparte
	ld (0e04eh),a		;70ad
	ld hl,07404h		;70b0
	jr z,L_70BC		;70b3
	inc a			;70b5
	ld (0e04eh),a		;70b6   ; 0xE04E = 1: el ganador es el otro
	ld hl,07416h		;70b9   ; y su rotulo
L_70BC:
	jp L_409D		;70bc

; ----------------------------------------------------------------------
; Escribe UN nombre de jugada por llamada, de la lista de 0xE305 (0xE319 apunta al siguiente y 0xE315 dice cuantos quedan), en la fila de VRAM de 0xE317, que baja 0x20 cada vez. Si la jugada es un yakuman (indice 1-11) y la siguiente no lo es, se corta ahi: con yakuman no se escribe nada mas. Luego, once celdas a la derecha del nombre, pinta el numero que toque con 0x457E: los yakuhai (0x22) llevan su cuenta en 0xE1D6, los dora (0x26) la suya en 0xE1D7, y con la mano CERRADA las jugadas que valen mas cerradas se sobreescriben: chinitsu (0x11) pasa a 6, honitsu y junchan (0x15 y 0x17) a 3, ittsu, sanshoku y chanta (0x1F-0x21) a 2. El han abierto va escrito dentro del nombre, en su ultimo tile.
; ----------------------------------------------------------------------
escribe_una_jugada:
	ld a,(0e315h)		;70bf   ; cuantas jugadas quedan por escribir
	and a			;70c2
	jp z,escribe_el_total_de_han		;70c3   ; ninguna: al total
	dec a			;70c6
	ld (0e315h),a		;70c7
	ld hl,(0e319h)		;70ca
	ld a,(hl)			;70cd
	ex de,hl			;70ce
	cp 00ch		;70cf   ; indice 12 en adelante: jugada normal
	jr nc,L_70E0		;70d1
	inc de			;70d3
	ld a,(de)			;70d4
	dec de			;70d5
	cp 00ch		;70d6   ; la siguiente es normal: esta se escribe y se sigue
	ld a,(de)			;70d8
	jr c,L_70E0		;70d9
	ld hl,0e315h		;70db
	ld (hl),000h		;70de   ; la siguiente es un yakuman: esta es la ultima
L_70E0:
	inc de			;70e0
	ld (0e319h),de		;70e1
	push af			;70e5
	add a,a			;70e6   ; dos bytes por puntero
	ld hl,07642h		;70e7   ; la tabla de punteros de 0x7642
	call suma_a_a_hl		;70ea
	ld e,(hl)			;70ed
	inc hl			;70ee
	ld d,(hl)			;70ef
	ex de,hl			;70f0
	ld de,(0e317h)		;70f1   ; donde va escrito
	push de			;70f5
	ld c,0ffh		;70f6
	call L_40A3		;70f8   ; pinta el nombre por la puerta de formato A que no borra
	pop de			;70fb
	pop af			;70fc
	push de			;70fd
	cp 022h		;70fe   ; 0x22, yakuhai: su cuenta
	jr nz,L_7107		;7100
	ld hl,0e1d6h		;7102
	jr L_7143		;7105
L_7107:
	cp 026h		;7107   ; 0x26, dora: la suya
	jr nz,L_7110		;7109
	ld hl,0e1d7h		;710b
	jr L_7143		;710e
L_7110:
	ld c,a			;7110
	ld a,(0e2b6h)		;7111   ; con alguna llamada la mano esta abierta: el han va como esta escrito
	or a			;7114
	jr nz,L_714B		;7115
	ld a,c			;7117
	cp 011h		;7118   ; 0x11, chinitsu: 6 cerrado
	jr nz,L_7123		;711a
	ld hl,0e127h		;711c
	ld (hl),006h		;711f   ; el 6
	jr L_7143		;7121
L_7123:
	cp 015h		;7123   ; 0x15 y 0x17, honitsu y junchan
	jr c,L_7136		;7125
	cp 018h		;7127
	jr nc,L_7136		;7129
	cp 016h		;712b   ; el 0x16 de en medio, toitoi, se queda como esta
	jr z,L_7136		;712d
	ld hl,0e127h		;712f
	ld (hl),003h		;7132   ; 3 cerrado
	jr L_7143		;7134
L_7136:
	cp 01fh		;7136   ; 0x1F-0x21: ittsu, sanshoku y chanta
	jr c,L_714B		;7138
	cp 022h		;713a
	jr nc,L_714B		;713c
	ld hl,0e127h		;713e
	ld (hl),002h		;7141   ; 2 cerrado
L_7143:
	ld a,00bh		;7143   ; once celdas a la derecha del nombre
	call suma_a_a_de		;7145
	call L_457E		;7148   ; y el numero, dos cifras
L_714B:
	pop de			;714b
	ld a,020h		;714c   ; la fila siguiente, para el nombre que venga
	call suma_a_a_de		;714e
	ld (0e317h),de		;7151
	ret			;7155

; ----------------------------------------------------------------------
; Cuando no quedan nombres: si la jugada mas alta no es yakuman (0xE305 de 12 en adelante) escribe el total de han de 0xE316 en 0x386C, pasado a BCD con un daa. Y baja el bit 2 de 0xE1A8: la jugada esta cantada y el submodo 5 puede seguir.
; ----------------------------------------------------------------------
escribe_el_total_de_han:
	ld a,(0e305h)		;7156
	cp 00ch		;7159   ; con yakuman no hay total que escribir
	jr c,L_7170		;715b
	ld hl,0e316h		;715d
	ld a,(hl)			;7160
	add a,000h		;7161   ; a BCD
	daa			;7163
	ld (0e127h),a		;7164
	ld hl,0e127h		;7167
	ld de,0386ch		;716a   ; 0x386C, donde va el total
	call L_457E		;716d
L_7170:
	ld hl,0e1a8h		;7170
	res 2,(hl)		;7173   ; bit 2 de 0xE1A8 abajo: la jugada esta cantada
	ret			;7175

; ----------------------------------------------------------------------
; EL RECUENTO DE FU, figura a figura, una cada 64 fotogramas y con sonido 9. 0xE1D8 cuenta las filas que quedan y la tabla de 0x7690 dice en que fila de VRAM va cada una. Primero los trios (0xE2C9, contados en 0xE1D9): se pinta y su fu va a la lista de 0xE322: 2 si es de fichas de en medio y abierto, 4 cerrado; 4 si es de terminales u honores y abierto, 8 cerrado. Luego los cuartetos (0x71DD): 8/16 y 16/32, con los dos dorsos pintados encima si es cerrado. Luego las escaleras (0x724C): 0 fu. Y al final la pareja (0x727A): 2 fu si es de dragon, de viento de la ronda (0x31 + 0xE04C) o de viento del asiento (0x31 + 0xE04D, el del que reparte, sea quien sea el ganador), y 4 si es los dos vientos. Todo en BCD, que es lo que suma 0x7320.
; ----------------------------------------------------------------------
pinta_una_figura_y_sus_fu:
	ld a,(0e003h)		;7176
	and 03fh		;7179   ; una figura cada 64 fotogramas
	ret nz			;717b
	ld a,009h		;717c   ; sonido 9
	call pide_un_sonido		;717e
	ld hl,0e1d8h		;7181
	dec (hl)			;7184   ; una fila menos
	ld a,(hl)			;7185
	ld hl,07690h		;7186   ; la fila de VRAM de esta figura
	add a,a			;7189
	call suma_a_a_hl		;718a
	ld e,(hl)			;718d
	inc hl			;718e
	ld d,(hl)			;718f
	ld a,(0e1d8h)		;7190
	or a			;7193   ; sin filas: la pareja
	jp z,L_727A		;7194
	ld a,(0e2dah)		;7197   ; cuantos trios
	or a			;719a
	ld c,a			;719b
	jr z,L_71DD		;719c
	ld a,(0e1d9h)		;719e
	cp c			;71a1   ; todos pintados: a los cuartetos
	jr z,L_71DD		;71a2
	inc a			;71a4
	ld (0e1d9h),a		;71a5
	ld hl,0e2c5h		;71a8   ; el registro del trio
	sla a		;71ab
	sla a		;71ad
	call suma_a_a_hl		;71af
	ld c,003h		;71b2
	call L_6FA5		;71b4   ; sus tres fichas
	ld c,(hl)			;71b7   ; la marca: abierto o cerrado
	ex de,hl			;71b8
	dec de			;71b9
	ld b,002h		;71ba
	ld a,(de)			;71bc
	cp 030h		;71bd   ; un honor
	jr nc,L_71D3		;71bf
	and 00fh		;71c1
	cp 001h		;71c3   ; o un uno
	jr z,L_71D3		;71c5
	cp 009h		;71c7   ; o un nueve: por 0x71D3
	jr z,L_71D3		;71c9
	ld a,c			;71cb
	rra			;71cc   ; abierto: 2 fu
	jr c,L_723E		;71cd
	ld b,004h		;71cf   ; cerrado: 4
	jr L_723E		;71d1
L_71D3:
	ld b,004h		;71d3   ; terminal u honor: 4 abierto
	ld a,c			;71d5
	rra			;71d6
	jr c,L_723E		;71d7
	ld b,008h		;71d9   ; 8 cerrado
	jr L_723E		;71db
L_71DD:
	ld a,(0e2f0h)		;71dd   ; cuantos cuartetos
	or a			;71e0
	ld c,a			;71e1
	jr z,L_724C		;71e2
	ld a,(0e1dah)		;71e4
	cp c			;71e7   ; todos pintados: a las escaleras
	jr z,L_724C		;71e8
	inc a			;71ea
	ld (0e1dah),a		;71eb
	ld hl,0e2d6h		;71ee
	ld b,a			;71f1
	sla a		;71f2   ; por cinco
	sla a		;71f4
	add a,b			;71f6
	call suma_a_a_hl		;71f7
	ld c,004h		;71fa   ; cuatro fichas
	dec de			;71fc
	dec de			;71fd
	push de			;71fe
	call L_6FA5		;71ff
	pop de			;7202
	ld c,(hl)			;7203
	ld a,(hl)			;7204
	rra			;7205   ; marca a cero: cerrado
	jr c,L_721B		;7206
	push hl			;7208
	push de			;7209
	ld a,038h		;720a   ; el dorso encima de la primera
	call L_6F74		;720c
	pop de			;720f
	ld a,006h		;7210
	call suma_a_a_de		;7212
	ld a,038h		;7215   ; y de la ultima
	call L_6F74		;7217
	pop hl			;721a
L_721B:
	ex de,hl			;721b
	dec de			;721c
	ld b,008h		;721d   ; 8 fu: cuarteto abierto de fichas de en medio
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
	ld b,016h		;7232   ; 16 cerrado
	jr L_723E		;7234
L_7236:
	ld b,016h		;7236   ; terminal u honor: 16 abierto
	ld a,c			;7238
	rra			;7239
	jr c,L_723E		;723a
	ld b,032h		;723c   ; 32 cerrado
L_723E:
	ld de,0e322h		;723e   ; la lista de fu, 0xE322, con la cuenta en 0xE32A
	ld hl,0e32ah		;7241
	ld a,(hl)			;7244
	call suma_a_a_de		;7245
	ld a,b			;7248
	ld (de),a			;7249
	inc (hl)			;724a
	ret			;724b
L_724C:
	ld a,(0e2c8h)		;724c   ; cuantas escaleras
	or a			;724f
	ld c,a			;7250
	jr z,L_727A		;7251
	ld a,(0e1dbh)		;7253
	cp c			;7256
	jr z,L_727A		;7257   ; todas pintadas: a la pareja
	inc a			;7259
	ld (0e1dbh),a		;725a
	ld hl,0e2b3h		;725d
	sla a		;7260
	sla a		;7262
	call suma_a_a_hl		;7264
	ld c,003h		;7267
	call L_6FA5		;7269   ; sus tres fichas
	ld de,0e322h		;726c
	ld hl,0e32ah		;726f
	ld a,(hl)			;7272
	call suma_a_a_de		;7273
	xor a			;7276   ; 0 fu
	ld (de),a			;7277
	inc (hl)			;7278
	ret			;7279
L_727A:
	ld b,012h		;727a   ; la mano de abajo se vacia, 0x39 en los 18 huecos
	ld hl,0e13ah		;727c
	ld a,039h		;727f
	push de			;7281
L_7282:
	ld (hl),a			;7282
	inc hl			;7283
	djnz L_7282		;7284
	call pinta_la_mano_del_jugador_1		;7286   ; y se repinta
	pop de			;7289
	ld hl,0e300h		;728a
	ld c,002h		;728d
	call L_6FA5		;728f   ; la pareja, dos fichas
	ex de,hl			;7292
	dec de			;7293
	ld b,000h		;7294
	ld a,(de)			;7296
	ld c,a			;7297
	cp 035h		;7298   ; 0x35 en adelante, un dragon: 2 fu
	jr nc,L_72B0		;729a
	ld hl,0e04ch		;729c   ; el viento de la ronda, 0x31 + 0xE04C
	ld a,(hl)			;729f
	add a,031h		;72a0
	cp c			;72a2
	jr nz,L_72A7		;72a3
	inc b			;72a5   ; 2 fu
	inc b			;72a6
L_72A7:
	ld hl,0e04dh		;72a7   ; el viento del asiento, 0x31 + 0xE04D
	ld a,(hl)			;72aa
	add a,031h		;72ab
	cp c			;72ad
	jr nz,L_72B2		;72ae
L_72B0:
	inc b			;72b0   ; 2 fu, y 4 si es los dos
	inc b			;72b1
L_72B2:
	call L_723E		;72b2
	jp siguiente_paso_del_recuento		;72b5   ; y al paso siguiente del recuento

; ----------------------------------------------------------------------
; El tipo de espera y los fu de base. 0xE1D2 (que calculo 0x5BDB al evaluar la mano) elige el rotulo y sus fu, que van a la sexta entrada de la lista (0xE327): bit 0 ryanmen, 0x7428, 2; bit 1 kanchan, 0x742F, 4; bit 2 penchan, 0x7436, 4; bit 3 tanki, 0x743D, 4; sin bits, shanpon, 0x7444, 2. Esos valores llevan dentro los 2 fu del tsumo: con RON (bit 0 de 0xE1D1 a cero) se restan 2 y sale el rotulo 0x744E en vez del 0x744B. Quedan 0/2/2/2/0, los del riichi de cuatro. Luego los marcos de 0x7451 y la base: 20 fu, o 30 con la mano cerrada y ron.
; ----------------------------------------------------------------------
pinta_la_espera_y_los_fu_base:
	ld c,0ffh		;72b8
	ld a,(0e1d2h)		;72ba
	rra			;72bd   ; bit 0: ryanmen
	jr c,L_72CE		;72be
	rra			;72c0   ; bit 1: kanchan
	jr c,L_72D5		;72c1
	rra			;72c3   ; bit 2: penchan
	jr c,L_72DA		;72c4
	rra			;72c6   ; bit 3: tanki
	jr c,L_72DF		;72c7
	ld hl,07444h		;72c9   ; sin bits: shanpon
	jr L_72D1		;72cc
L_72CE:
	ld hl,07428h		;72ce
L_72D1:
	ld b,002h		;72d1   ; 2 fu, con el tsumo dentro
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
	ld b,004h		;72e2   ; 4 fu
L_72E4:
	ex de,hl			;72e4
	ld hl,0e327h		;72e5
	ld (hl),b			;72e8   ; a la sexta entrada de la lista
	ld hl,0e32ah		;72e9
	inc (hl)			;72ec   ; una entrada mas
	ex de,hl			;72ed
	ld de,03acfh		;72ee   ; 0x3ACF: donde va el rotulo de la espera
	call L_40A3		;72f1
	ld a,(0e1d1h)		;72f4
	rra			;72f7   ; bit 0 de 0xE1D1: tsumo
	ld hl,0744bh		;72f8   ; el rotulo del tsumo
	jr c,L_7305		;72fb
	ld hl,0e327h		;72fd
	dec (hl)			;7300   ; ron: los 2 fu del tsumo se quitan
	dec (hl)			;7301
	ld hl,0744eh		;7302   ; y el rotulo del ron
L_7305:
	call L_40A3		;7305
	ld hl,07451h		;7308   ; los seis marcos
	call L_409D		;730b
	ld a,(0e2b6h)		;730e
	or a			;7311
	ld hl,0e1e1h		;7312
	ld (hl),020h		;7315   ; 20 fu de base
	ret nz			;7317   ; con alguna llamada se queda en 20
	ld a,(0e1d1h)		;7318
	or a			;731b
	ret nz			;731c   ; con tsumo tambien
	ld (hl),030h		;731d   ; cerrada y ron: 30
	ret			;731f

; ----------------------------------------------------------------------
; Suma en BCD, entrada a entrada, la lista de fu de 0xE322 sobre 0xE1E1/0xE1E2, escribiendo cada una en la fila que dice la tabla de 0x769A. Una entrada por llamada; cuando 0xE32A llega a cero, al total (0x7356).
; ----------------------------------------------------------------------
suma_los_fu:
	ld hl,0769ah		;7320
	ld a,(0e32ah)		;7323   ; cuantas entradas quedan
	or a			;7326
	jr z,escribe_el_total_de_fu		;7327   ; ninguna: al total
	dec a			;7329
	ld (0e32ah),a		;732a
	add a,a			;732d
	call suma_a_a_hl		;732e   ; la fila de VRAM de esta entrada
	ld e,(hl)			;7331
	inc hl			;7332
	ld d,(hl)			;7333
	ld hl,0e1d8h		;7334
	inc (hl)			;7337
	ld a,(hl)			;7338
	ld hl,0e321h		;7339
	call suma_a_a_hl		;733c   ; la entrada, contando desde 0xE322
	ld a,(0e1e1h)		;733f
	ld c,(hl)			;7342
	add a,c			;7343
	daa			;7344   ; en BCD
	ld (0e1e1h),a		;7345
	jr nc,L_7353		;7348   ; con acarreo, el byte alto
	ld a,(0e1e2h)		;734a
	add a,001h		;734d
	daa			;734f
	ld (0e1e2h),a		;7350
L_7353:
	jp L_457E		;7353   ; y se escribe

; ----------------------------------------------------------------------
; El total de fu, REDONDEADO HACIA ARRIBA A LA DECENA: si la cifra de las unidades no es cero se suman 10 y se tiran las unidades. Se escribe en 0x382B/0x382C y se pasa al paso siguiente del recuento.
; ----------------------------------------------------------------------
escribe_el_total_de_fu:
	ld hl,0e1e2h		;7356
	ld de,0382bh		;7359   ; el byte alto, en 0x382B
	call pinta_la_cifra_baja_o_blanco		;735c
	ld hl,0e1e1h		;735f
	ld a,(hl)			;7362
	and 00fh		;7363   ; las unidades
	ld a,(hl)			;7365
	jr z,L_736A		;7366   ; a cero: no hay que redondear
	add a,010h		;7368   ; diez mas
L_736A:
	and 0f0h		;736a   ; y sin unidades: redondeado a la decena de arriba
	ld (hl),a			;736c
	ld de,0382ch		;736d   ; el byte bajo, en 0x382C
	call L_457E		;7370
	jp siguiente_paso_del_recuento		;7373

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
; DATOS kanji_del_que_reparte: Formato A: los nueve tiles 0x70-0x78 de la
;   fuente katakana, tres por fila en las filas 1, 2 y 3, columna 3: un
;   caracter de 24x24. Lo pinta 0x70B0 cuando el ganador ES el que reparte
;   (0xE04E = 0). SUPOSICION por el uso: el kanji de oya, el que reparte.
;   0x7404..0x7416  (18 bytes)
DATA_kanji_del_que_reparte:
	defb 023h,038h,070h,071h,072h,0feh,043h,038h,073h,074h,075h,0feh,063h,038h,076h,077h	; 7404  #8pqr.C8stu.c8vw
	defb 078h,0ffh	; 7414

; ----------------------------------------------------------------------
; DATOS kanji_del_que_no_reparte: Formato A: los tiles 0x79-0x7F en el mismo
;   sitio, el caracter de 24x24 que 0x70B9 elige cuando el ganador NO es el
;   que reparte (0xE04E = 1). SUPOSICION por el uso: el kanji de ko, el hijo.
;   0x7416..0x7428  (18 bytes)
DATA_kanji_del_que_no_reparte:
	defb 023h,038h,079h,07ah,07bh,0feh,043h,038h,07ch,07dh,07eh,0feh,063h,038h,001h,07fh	; 7416  #8yz{.C8|}~.c8..
	defb 001h,0ffh	; 7426

; ----------------------------------------------------------------------
; DATOS rotulos_de_la_espera: Siete tiras de numeros de tile terminadas en
;   0xFF, de la fuente de trozos (tiles 0x0C-0x27) y no de la katakana, asi
;   que no se leen letra a letra. Las cinco primeras son el TIPO DE ESPERA que
;   elige 0x72B8 por los bits de 0xE1D2: 0x7428 ryanmen (bit 0), 0x742F
;   kanchan (bit 1), 0x7436 penchan (bit 2), 0x743D tanki (bit 3) y 0x7444
;   shanpon (sin bits). Las dos ultimas, de dos tiles, son la marca del TSUMO
;   (0x744B) y la del RON (0x744E), que 0x72F4 elige por el bit 0 de 0xE1D1.
;   0x7428..0x7451  (41 bytes)
DATA_rotulos_de_la_espera:
	defb 00ch,00dh,00eh,00fh,00eh,001h,0ffh,01ah,00eh,01bh,00dh,00eh,001h,0ffh,01ch,025h	; 7428  ...............%
	defb 00eh,01bh,00dh,00eh,0ffh,01dh,00eh,01eh,001h,001h,001h,0ffh,01fh,00dh,020h,024h	; 7438  .............. $
	defb 00eh,001h,0ffh,021h,022h,0ffh,023h,00eh,0ffh	; 7448  ...!".#..

; ----------------------------------------------------------------------
; DATOS marcos_de_los_fu: Formato A desde 0x730B: el mismo marco de cuatro
;   celdas -tile 0x26, dos blancos, tile 0x27- en seis sitios de las filas 16,
;   19 y 22, columnas 10 y 22. Son los huecos donde 0x7320 escribe los fu de
;   cada figura del recuento.
;   0x7451..0x747b  (42 bytes)
DATA_marcos_de_los_fu:
	defb 00ah,03ah,026h,001h,001h,027h,0feh,016h,03ah,026h,001h,001h,027h,0feh,06ah,03ah	; 7451  .:&..'..:&..'.j:
	defb 026h,001h,001h,027h,0feh,076h,03ah,026h,001h,001h,027h,0feh,0cah,03ah,026h,001h	; 7461  &..'.v:&..'..:&.
	defb 001h,027h,0feh,0d7h,03ah,026h,001h,001h,027h,0ffh	; 7471  .'..:&..'.

; ----------------------------------------------------------------------
; DATOS nombres_de_las_jugadas: LOS 39 NOMBRES DE JUGADA, en la fuente
;   katakana de 0x8832 (tiles 0x30-0x7F: 0x30-0x5D son ア a ン en orden gojuon,
;   0x5E y 0x5F el dakuten y el handakuten como tile aparte, 0x60 el punto,
;   0x61 el alargamiento, 0x63-0x66 las pequenas ッ ャ ュ ョ), cada registro
;   terminado en 0xFF y el 0 vacio. Leidos tile a tile, y el indice es el que
;   usa 0x82E6 al apuntar la jugada: 1 テンホー tenhou, 2 チーホー chiihou (y tambien
;   el renhou de 0x82E3), 3 コクシムソウ kokushi musou, 4 ツーイーソウ tsuuiisou, 5 ダイスウシー
;   daisuushii, 6 ダイサンゲン daisangen, 7 チューレンポートー chuuren poutou, 8 チンロートウ
;   chinroutou, 9 リューイーソウ ryuuiisou, 10 スーアンコウ suuankou, 11 スーカンツ suukantsu; y
;   del 12 en adelante, con su han ABIERTO como ultimo tile (0x11 = 1, 0x12 =
;   2, 0x13 = 3, 0x15 = 5): 12 ダブルリーチ 2, 13 リーチ 1, 14 リーチソク 2 (riichi con
;   ippatsu, que el cartucho llama soku), 15 ダブルリーチソク 3, 16 メンゼン ツモ 1, 17 チンイツ
;   5, 18 リャンペイコウ 3, 19 サンシキドウコウ 3, 20 チートイ 2, 21 ホンイツ 2, 22 トイトイ 2, 23 ジュンチャン
;   2, 24 サンアンコウ 2, 25 サンカンツ 2, 26 ショウサンゲン 2, 27 ホンロートウ 2, 28 ピンフ 1, 29 タンヤオ
;   1, 30 イーペーコウ 1, 31 イッツウ 1, 32 サンシキ 1, 33 チャンタ 1, 34 ヤクハイ 1, 35 ハイテイ ツモ 2,
;   36 ハイテイ フリコミ 1, 37 リンシャンカイホウ 1 y 38 ドラ・ウラドラ sin numero. Los del 12 al 37
;   van rellenos con blancos (0x01) hasta diez celdas y luego 0x00, 0x01 y el
;   han. Los indices 1-11 son los yakuman: 0x70BF corta la lista al llegar a
;   uno y 0x5B01 los cuenta para pagar la mano limite.
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
; DATOS filas_de_las_figuras_del_recuento: Once palabras con direcciones de
;   VRAM (fila de nombres), de 0x39E4 a 0x3AA6. 0x7186 la indexa con (0xE1D8)
;   doblado para saber en que fila pinta cada figura del recuento; el mismo
;   bloque, desde su quinta entrada (0x769A), lo vuelve a indexar 0x7320 con
;   (0xE32A) doblado para escribir los fu de cada una.
;   0x7690..0x76a6  (22 bytes)
DATA_filas_de_las_figuras_del_recuento:
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



; ----------------------------------------------------------------------
; LA MANO ACABA SIN GANADOR (la llama el submodo 2 cuando 0xE302 trae el bit 2). Sube 0xE062 -manos seguidas sin ganar el jugador 1, lo que dispara la siembra de 0x48E1-, pinta el panel de 0x782C y recalcula las esperas del 1. En las dificultades 2 y 3 (bits 1 y 2 de 0xE040), si el 1 estaba en riichi (bit 0 de 0xE1CD) comprueba el furiten (0x47FB y 0x4833) y, si lo hay, 0x76D9 lo castiga. Si no, 0x7713 mira quien esta en tenpai.
; ----------------------------------------------------------------------
cierra_la_mano_sin_ganador:
	ld hl,0e062h		;76a6
	inc (hl)			;76a9   ; una mano mas sin ganar el jugador 1
	ld hl,0782ch		;76aa   ; el panel del final
	call pinta_lista_formato_b		;76ad
	xor a			;76b0
	ld (0e206h),a		;76b1   ; el jugador 1 como jugador actual
	ld a,(0e302h)		;76b4
	push af			;76b7
	call calcula_las_esperas		;76b8   ; sus esperas, de nuevo
	pop af			;76bb
	ld (0e302h),a		;76bc
	ld a,(0e040h)		;76bf
	and 006h		;76c2   ; solo en las dificultades 2 y 3
	jr z,mira_quien_esta_en_tenpai		;76c4
	ld a,(0e1cdh)		;76c6
	rra			;76c9   ; y solo si el 1 estaba en riichi
	jr nc,mira_quien_esta_en_tenpai		;76ca
	call furiten_tras_el_riichi		;76cc   ; furiten tras el riichi
	call busca_en_las_dos_listas		;76cf   ; y furiten sobre el propio rio
	ld a,(0e1cdh)		;76d2
	and 060h		;76d5   ; bits 5 y 6 de 0xE1CD: hay furiten
	jr z,mira_quien_esta_en_tenpai		;76d7

; ----------------------------------------------------------------------
; LA PENALIZACION, y la paga siempre el jugador 1: 0xE302 = 5 (sin ganador y con castigo), bit 7 de 0xE1AC si el 1 es el que reparte o bit 6 si no -que 0x428B convierte en 12.000 u 8.000, la mano limite del que reparte o del otro- y 0xE1AD = 2, como si solo el 2 estuviera en tenpai. Pinta el aviso de la fila 11 que dice 0xE1AC & 7 (tabla de 0x7853) y el rotulo de la fila 12, suena el 0x90 y sigue por 0x77CD. Se llega desde el furiten (0x4279, 0x76D5) y desde cantar sin jugada (0x7B08).
; ----------------------------------------------------------------------
penaliza:
	ld hl,0e302h		;76d9
	ld (hl),005h		;76dc   ; 0xE302 = 5: sin ganador, y con castigo
	ld hl,0e1ach		;76de
	set 7,(hl)		;76e1   ; bit 7: paga el que reparte
	ld a,(0e04dh)		;76e3
	rra			;76e6   ; si reparte el 2
	jr nc,L_76ED		;76e7
	res 7,(hl)		;76e9
	set 6,(hl)		;76eb   ; bit 6: paga el que no reparte
L_76ED:
	ld hl,0e1adh		;76ed
	ld (hl),002h		;76f0   ; 0xE1AD = 2: como si solo el 2 estuviera en tenpai
	ld a,(0e1ach)		;76f2
	and 007h		;76f5   ; los tres bits bajos eligen el aviso
	add a,a			;76f7
	ld hl,07853h		;76f8   ; la tabla de punteros de 0x7853
	call suma_a_a_hl		;76fb
	ld e,(hl)			;76fe
	inc hl			;76ff
	ld d,(hl)			;7700
	ex de,hl			;7701
	call L_409D		;7702   ; el aviso de la fila 11
	ld hl,0785bh		;7705   ; y el rotulo de la fila 12
	call L_409D		;7708
	ld a,090h		;770b
	call pide_un_sonido		;770d   ; sonido 0x90
	jp paga_el_tenpai_y_pasa_la_mano		;7710

; ----------------------------------------------------------------------
; QUIEN ESTA EN TENPAI al acabarse la mano, y lo que se le pide. Sonido 0x96. Con menos de 5 honba (0xE04B) al jugador 1 le basta el bit 7 de 0xE1CD, tener esperas. De 5 honba en adelante CADA ESPERA tiene que valer: se copian a 0xE348 y, una a una, se mete en la mano (0x66EB con C = 0xFF), se evaluan las jugadas con 0xE302 = 4 (0x7AF8) y hace falta que vuelva con acarreo, 3 han o mas; una que no llegue y no hay tenpai. El resultado va al bit 0 de 0xE1AD. Luego 0x7761 hace lo mismo con el 2.
; ----------------------------------------------------------------------
mira_quien_esta_en_tenpai:
	ld a,096h		;7713   ; sonido 0x96
	call pide_un_sonido		;7715
	ld a,(0e04bh)		;7718
	cp 005h		;771b   ; menos de 5 honba: basta con tener esperas
	jr c,L_7756		;771d
	call copia_las_esperas_a_e348		;771f   ; las esperas del 1, copiadas a 0xE348
	ld a,(0e1c3h)		;7722   ; el hueco de la robada
	ld (0e20ah),a		;7725
	ld (0e209h),a		;7728
	ld a,(de)			;772b
	or a			;772c   ; sin esperas no hay tenpai
	jr z,mira_si_el_2_esta_en_tenpai		;772d
L_772F:
	ld (0e382h),de		;772f   ; la espera que se prueba
	ld c,0ffh		;7733   ; C = 0xFF: solo esa ficha
	ld b,001h		;7735
	push de			;7737
	call L_66EB		;7738   ; se mete en la mano y se analiza
	ld a,004h		;773b
	ld (0e302h),a		;773d   ; 0xE302 = 4: sin ganador
	call evalua_y_decide_la_jugada		;7740   ; las jugadas de esa mano
	push af			;7743
	call limpia_el_analisis		;7744   ; y se limpia
	xor a			;7747
	ld (0e316h),a		;7748   ; los han a cero para la siguiente
	pop af			;774b
	pop de			;774c
	inc de			;774d
	jr nc,mira_si_el_2_esta_en_tenpai		;774e   ; sin acarreo la espera no vale: no hay tenpai
	ld a,(de)			;7750
	or a			;7751
	jr nz,L_772F		;7752   ; la espera siguiente
	jr L_775C		;7754
L_7756:
	ld a,(0e1cdh)		;7756
	rla			;7759   ; bit 7 de 0xE1CD: tiene esperas
	jr nc,mira_si_el_2_esta_en_tenpai		;775a
L_775C:
	ld hl,0e1adh		;775c
	set 0,(hl)		;775f   ; bit 0 de 0xE1AD: EL JUGADOR 1 ESTA EN TENPAI

; ----------------------------------------------------------------------
; Lo mismo para el jugador 2: carga sus figuras (59 bytes de 0xE27B a 0xE2B6) y su mano (0xE14C) en la zona de trabajo, calcula sus esperas y, con 5 honba o mas, exige que cada espera valga por 0x7796 (con 0xE302 = 6: el 2, sin ganador). El resultado, al bit 1 de 0xE1AD.
; ----------------------------------------------------------------------
mira_si_el_2_esta_en_tenpai:
	ld hl,0e1cdh		;7761
	res 7,(hl)		;7764   ; el bit 7 se limpia: ahora toca el 2
	ld a,(0e208h)		;7766   ; el hueco de la robada del 2
	ld (0e209h),a		;7769
	ld (0e20ah),a		;776c
	ld hl,0e27bh		;776f   ; sus figuras, 59 bytes
	ld de,0e2b6h		;7772
	ld bc,0003bh		;7775
	ldir		;7778
	ld hl,0e14ch		;777a   ; y su mano
	ld de,0e32bh		;777d
	ld bc,0000eh		;7780
	ldir		;7783
	call calcula_las_esperas		;7785   ; sus esperas
	ld a,(0e04bh)		;7788
	cp 005h		;778b   ; menos de 5 honba
	jr c,L_77C2		;778d
	call copia_las_esperas_a_e348		;778f   ; las esperas, copiadas
	ld a,(de)			;7792
	or a			;7793   ; sin esperas
	jr z,paga_el_tenpai_y_pasa_la_mano		;7794
L_7796:
	ld (0e382h),de		;7796
	ld c,0ffh		;779a
	ld b,001h		;779c
	push de			;779e
	call L_66EB		;779f
	ld a,006h		;77a2
	ld (0e302h),a		;77a4   ; 0xE302 = 6: el 2, sin ganador
	call evalua_y_decide_la_jugada		;77a7   ; las jugadas
	ld a,004h		;77aa
	ld (0e302h),a		;77ac
	push af			;77af
	call limpia_el_analisis		;77b0
	xor a			;77b3
	ld (0e316h),a		;77b4
	pop af			;77b7
	pop de			;77b8
	inc de			;77b9
	jr nc,paga_el_tenpai_y_pasa_la_mano		;77ba   ; sin acarreo no hay tenpai
	ld a,(de)			;77bc
	or a			;77bd
	jr nz,L_7796		;77be
	jr L_77C8		;77c0
L_77C2:
	ld a,(0e1cdh)		;77c2
	rla			;77c5   ; bit 7: tiene esperas
	jr nc,paga_el_tenpai_y_pasa_la_mano		;77c6
L_77C8:
	ld hl,0e1adh		;77c8
	set 1,(hl)		;77cb   ; bit 1 de 0xE1AD: EL 2 ESTA EN TENPAI

; ----------------------------------------------------------------------
; EL CIERRE DE LA MANO SIN GANADOR. 0xE302 = 4 y un honba mas (0xE04B, en BCD). Con los dos en tenpai (0xE1AD = 3) no se paga ni se mueve nada. Con uno solo, 0x7814 carga 1.500 puntos y 0x5DF9 los mueve del que no esta al que esta. Y el reparto: si reparte el 1 (0xE04D a cero) y esta en tenpai, sigue; si no, en la ronda del este pasa al 2 (0x77F7) y en la del sur SE QUEDA. Si reparte el 2 y esta en tenpai, sigue; si no, en el este cambian ronda y reparto (0x77EF) y en el sur se queda tambien.
; ----------------------------------------------------------------------
paga_el_tenpai_y_pasa_la_mano:
	ld a,004h		;77cd
	ld (0e302h),a		;77cf   ; 0xE302 = 4: sin ganador
	call suma_un_honba		;77d2   ; un honba mas
	ld a,(0e1adh)		;77d5
	cp 003h		;77d8   ; los dos en tenpai: nadie paga y nada cambia
	ret z			;77da
	or a			;77db
	call nz,carga_el_pago_del_tenpai		;77dc   ; uno solo: 1.500 puntos
	ld c,a			;77df
	ld a,(0e04dh)		;77e0
	rra			;77e3   ; bit 0 de 0xE04D: reparte el 2
	jr nc,pasa_el_reparto_si_toca		;77e4
	ld a,c			;77e6
	rra			;77e7   ; bit 1 de 0xE1AD: el 2 esta en tenpai y sigue repartiendo
	rra			;77e8
	ret c			;77e9
	ld a,(0e04ch)		;77ea
	rra			;77ed   ; en la ronda del sur el reparto no cambia
	ret c			;77ee

; ----------------------------------------------------------------------
; Cambia la ronda (0xE04C: 0 este, 1 sur) y cae en 0x77F7, que cambia quien reparte (0xE04D: 0 el jugador 1, 1 el 2). Los dos son bits que se invierten. Ronda y reparto solo avanzan asi: este-1, este-2, sur-1, sur-2, y de ahi no se pasa: la partida se cierra por 0x5F00.
; ----------------------------------------------------------------------
cambia_la_ronda:
	ld a,(0e04ch)		;77ef   ; del este al sur
	xor 001h		;77f2   ; xor 1: la otra ronda
	ld (0e04ch),a		;77f4
cambia_el_reparto:
	ld a,(0e04dh)		;77f7   ; y reparte el otro
	xor 001h		;77fa   ; xor 1: reparte el otro
	ld (0e04dh),a		;77fc
	ret			;77ff
pasa_el_reparto_si_toca:
	ld a,c			;7800
	rra			;7801   ; bit 0: el 1 esta en tenpai y sigue repartiendo
	ret c			;7802
	ld a,(0e04ch)		;7803
	rra			;7806   ; en el este pasa al 2; en el sur se queda
	jr nc,cambia_el_reparto		;7807
	ret			;7809

; ----------------------------------------------------------------------
; Un honba mas, en BCD (0xE04B). Sube con cada mano sin ganador y con cada mano que gana el que reparte (0x5F0F), y vuelve a cero cuando cambia el reparto (0x5EEB, 0x5F08). 0x5C7F lo convierte en 300 puntos por honba en el ron y 0x5BB5 en 100 en el tsumo, y a partir de 5 exige jugadas de mas (0x7B11, 0x771B).
; ----------------------------------------------------------------------
suma_un_honba:
	ld a,(0e04bh)		;780a
	add a,001h		;780d
	daa			;780f   ; en BCD
	ld (0e04bh),a		;7810
	ret			;7813

; ----------------------------------------------------------------------
; 0x0015 en pasos de cien, 1.500 puntos, en los dos pendientes de 0x5DF9: lo que paga el que no esta en tenpai al que si lo esta.
; ----------------------------------------------------------------------
carga_el_pago_del_tenpai:
	ld hl,00015h		;7814
	ld (0e1b1h),hl		;7817
	ld (0e1e4h),hl		;781a
	ret			;781d

; ----------------------------------------------------------------------
; Copia las doce esperas del jugador 1 (0xE1F5) a 0xE348 y deja DE apuntando alli.
; ----------------------------------------------------------------------
copia_las_esperas_a_e348:
	ld hl,0e1f5h		;781e
	ld de,0e348h		;7821
	push de			;7824
	ld bc,0000ch		;7825   ; doce esperas
	ldir		;7828
	pop de			;782a
	ret			;782b

; ----------------------------------------------------------------------
; DATOS cartel_de_ryuukyoku: Formato B desde 0x76AD: cinco destinos entre las
;   filas 9 y 13, columnas 17-24: una caja en blanco con 流局 (ryuukyoku, la
;   mano sin ganador) en dos kanji de 16x16, tiles C0 C6 / C1 C7 y CC D2 / CD
;   D3 en las filas 11-12. Leido dibujando los tiles del tercio central.
;   0x782c..0x7853  (39 bytes)
DATA_cartel_de_ryuukyoku:
	defb 034h,079h,002h,001h,080h,051h,079h,007h,001h,080h,071h,079h,088h,001h,0c0h,0c6h	; 782c  4y...Qy...qy....
	defb 001h,0cch,0d2h,001h,001h,080h,091h,079h,088h,001h,0c1h,0c7h,001h,0cdh,0d3h,001h	; 783c  .......y........
	defb 001h,080h,0b1h,079h,007h,001h,000h	; 784c

; ----------------------------------------------------------------------
; DATOS punteros_de_los_avisos_del_final: Cuatro palabras -0x7865, 0x786F,
;   0x7879 y otra vez 0x7879- que 0x76F8 indexa con (0xE1AC & 7) doblado para
;   elegir el aviso de la fila 11 cuando la mano acaba con penalizacion
;   (0x76D9). CORRIGE la lectura anterior, que lo tomaba por un rotulo de
;   quince tiles.
;   0x7853..0x785b  (8 bytes)
DATA_punteros_de_los_avisos_del_final:
	defb 065h,078h	; 7853
	defb 06fh,078h	; 7855
	defb 079h,078h	; 7857
	defb 079h,078h	; 7859

; ----------------------------------------------------------------------
; DATOS rotulo_de_la_fila_12: Formato A desde 0x7705: siete tiles en la fila
;   12, columna 2, que salen debajo del aviso de la fila 11 cuando la mano
;   acaba con penalizacion.
;   0x785b..0x7865  (10 bytes)
DATA_rotulo_de_la_fila_12:
	defb 082h,039h,002h,002h,0f1h,049h,0f0h,0f7h,0e4h,0ffh	; 785b  .9...I....

; ----------------------------------------------------------------------
; DATOS tres_avisos_de_la_fila_11: Tres listas de formato A de diez bytes, las
;   tres al mismo destino 0x3962 (fila 11, columna 2), apuntadas por la tabla
;   de 0x7853: el aviso 0 para 0xE1AC = 0 (furiten sobre el propio rio,
;   0x4833), el 1 para 0xE1AC = 1 (furiten tras el riichi, 0x47FB) y el 2 para
;   0xE1AC = 2 y 3 (sin jugada al cantar, 0x7B08).
;   0x7865..0x7883  (30 bytes)
DATA_tres_avisos_de_la_fila_11:
	defb 062h,039h,002h,004h,0f6h,06dh,0f0h,002h,002h,0ffh,062h,039h,002h,005h,003h,0fdh	; 7865  b9...m....b9....
	defb 0e4h,006h,002h,0ffh,062h,039h,002h,007h,008h,009h,006h,002h,002h,0ffh	; 7875  ....b9........

; ======================================================================
; CODIGO 0x7883..0x7aea  (615 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; El lector de formato B sin destino: desde (0xE05B) saca ordenes a 0xE2B6 hasta juntar 0x30 bytes (0xE05A los cuenta), y deja el puntero donde se quedo para la tanda siguiente. Es lo que alimenta a 0x46B1 y 0x46DC, columna a columna.
; ----------------------------------------------------------------------
descomprime_para_el_volcado_girado:
	ld hl,(0e05bh)		;7883
	ld de,0e2b6h		;7886
L_7889:
	ld a,(hl)			;7889   ; los siete bits bajos son la cuenta
	and 07fh		;788a
	ld c,a			;788c
	ld a,(hl)			;788d
	inc hl			;788e
	ret z			;788f   ; byte cero: se acabo
	ld b,000h		;7890
	cp c			;7892
	push af			;7893
	call nz,copia_literal_al_volcado		;7894   ; con el bit 7 puesto, copia literal
	pop af			;7897
	call z,repite_un_byte_al_volcado		;7898   ; sin el, repite un byte
	ld a,(0e05ah)		;789b
	cp 030h		;789e   ; 0x30 bytes: una columna entera
	jr nz,L_7889		;78a0
	xor a			;78a2
	ld (0e05ah),a		;78a3
	ld (0e05bh),hl		;78a6   ; y el puntero se guarda para la columna siguiente
	ret			;78a9
copia_literal_al_volcado:
	ld a,(hl)			;78aa
	ld (de),a			;78ab   ; al volcado
	push hl			;78ac
	ld hl,0e05ah		;78ad   ; uno mas en la tanda
	inc (hl)			;78b0
	pop hl			;78b1
	inc hl			;78b2
	inc de			;78b3
	dec bc			;78b4
	ld a,b			;78b5
	or c			;78b6
	jr nz,copia_literal_al_volcado		;78b7
	ret			;78b9
repite_un_byte_al_volcado:
	ld a,(hl)			;78ba
	inc hl			;78bb
	push hl			;78bc
	push af			;78bd
L_78BE:
	pop af			;78be
	ld (de),a			;78bf   ; el mismo byte, repetido
	ld hl,0e05ah		;78c0   ; uno mas en la tanda
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

; ----------------------------------------------------------------------
; LA MANO DE LA MAQUINA NO SE ROBA: SE CONSTRUYE. Es lo primero que hace el reparto (0x4DA6) y llena 0xE21C con catorce fichas a medida. En el demo copia la mano fija de 0x7AEA y la ordena. En partida decide un PLAN en 0xE058 -segun si el 2 va en numeros rojos (0xE100), si esta por debajo de 10.000 (0xE046), los honba y un sorteo-, elige un palo (0xE059) y un objetivo 0xE057: cuantas fichas van en TRIOS (0x7992); el resto van en ESCALERAS del mismo palo (0x79D5) o en PAREJAS (0x7A27), y una pareja al final (0x7A69). Cada ficha que coloca la descuenta de los contadores de 0xE186, como si la hubiera robado. Y al final (0x7A93) QUITA UNA: la maquina empieza a una ficha de la mano completa.
; ----------------------------------------------------------------------
construye_la_mano_de_la_maquina:
	ld a,(0e002h)		;78ce
	bit 6,a		;78d1   ; bit 6 de 0xE002: hay partida
	jr nz,L_78E8		;78d3
	ld hl,0e058h		;78d5
	ld (hl),081h		;78d8   ; en el demo el plan es 0x81
	ld de,0e21ch		;78da
	ld hl,07aeah		;78dd   ; la mano fija de 0x7AEA
	ld bc,0000eh		;78e0
	ldir		;78e3
	jp L_7AAF		;78e5   ; y ordenada
L_78E8:
	ld hl,0e056h		;78e8
	ld (hl),000h		;78eb   ; 0xE056: fichas colocadas
	inc hl			;78ed
	ld (hl),000h		;78ee   ; 0xE057: cuantas van en trios
	ld hl,0e058h		;78f0
	ld (hl),000h		;78f3   ; 0xE058: el plan
	ld a,(0e100h)		;78f5
	rla			;78f8   ; bits 7 y 6 de 0xE100: el 2 va en numeros rojos
	rla			;78f9
	ld (hl),004h		;78fa   ; plan 4
	jr c,L_7944		;78fc
	ld a,(0e046h)		;78fe   ; 0xE046: el byte alto del marcador del 2
	or a			;7901
	ld (hl),002h		;7902   ; a cero, por debajo de 10.000: plan 2
	jr z,L_7944		;7904
	ld a,(0e04bh)		;7906
	cp 005h		;7909   ; con 5 honba o mas
	jr c,L_7938		;790b
	ld c,a			;790d
	ld a,(0e04dh)		;790e
	rra			;7911
	jr nc,L_7919		;7912
	ld a,c			;7914
	cp 008h		;7915   ; y con 8 si reparte el 2
	jr nc,L_7938		;7917
L_7919:
	call numero_al_azar		;7919   ; un sorteo
	cp 021h		;791c   ; 33: plan 4
	ld hl,0e058h		;791e
	ld (hl),004h		;7921
	jr z,L_7950		;7923
	sra (hl)		;7925   ; si no, plan 2
	cp 019h		;7927   ; de 25 para arriba, a elegir palo
	jr nc,L_7950		;7929
	cp 00fh		;792b   ; de 15 a 24, parejas
	jp nc,coloca_parejas		;792d
	ld (hl),001h		;7930   ; plan 1
	cp 008h		;7932   ; de 8 a 14, doce fichas en trios
	jr nc,L_7987		;7934
	ld (hl),002h		;7936   ; por debajo, plan 2
L_7938:
	call numero_al_azar		;7938
	ld hl,0e058h		;793b
	cp 01eh		;793e   ; otro sorteo: 30 o mas, a elegir palo
	jr nc,L_7944		;7940
	sra (hl)		;7942   ; si no, el plan se parte
L_7944:
	call numero_al_azar		;7944
	cp 021h		;7947   ; 33: plan 9
	jr c,L_7950		;7949
	ld hl,0e058h		;794b
	ld (hl),009h		;794e
L_7950:
	call numero_al_azar		;7950
	ld hl,04fbfh		;7953   ; un tipo de ficha al azar
	call suma_a_a_hl		;7956
	ld a,(hl)			;7959
	cp 030h		;795a   ; un honor no vale de palo: otra
	jr nc,L_7944		;795c
	and 0f0h		;795e
	ld (0e059h),a		;7960   ; 0xE059: EL PALO de la mano
	call numero_al_azar		;7963
	cp 021h		;7966   ; otro sorteo: 33, doce fichas en trios
	jr z,L_7987		;7968
	cp 020h		;796a   ; 32, nueve
	jr z,L_7983		;796c
	cp 01fh		;796e   ; 31, parejas
	jp z,coloca_parejas		;7970
	cp 017h		;7973   ; de 23 a 30, escaleras
	jr nc,coloca_escaleras		;7975
	cp 008h		;7977   ; de 8 a 22, tres
	jr nc,L_797F		;7979
	ld a,006h		;797b   ; por debajo, seis
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
	set 5,(hl)		;798c   ; bit 5 del plan
L_798E:
	ld hl,0e057h		;798e   ; 0xE057 = cuantas fichas van en trios
	ld (hl),a			;7991

; ----------------------------------------------------------------------
; Trios hasta llegar a 0xE057: una ficha que cuadre con el plan (0x7AB8) y con menos de dos copias gastadas; con el bit 3 del plan, solo terminales y honores. Tres copias, contadas en 0xE186 y escritas seguidas en 0xE21C. Con doce fichas en trios, a la pareja; si no, a las escaleras.
; ----------------------------------------------------------------------
coloca_trios:
	call saca_una_ficha_del_plan		;7992   ; una ficha que cuadre con el plan
	call apunta_al_contador_de_la_ficha		;7995   ; sus copias gastadas
	ld a,(hl)			;7998
	cp 002h		;7999   ; con dos o mas, otra
	jr nc,coloca_trios		;799b
	ld a,(0e058h)		;799d
	bit 3,a		;79a0   ; bit 3 del plan: solo terminales y honores
	jr z,L_79B3		;79a2
	ld a,c			;79a4
	cp 030h		;79a5
	jr nc,L_79B3		;79a7
	and 00fh		;79a9
	cp 001h		;79ab
	jr z,L_79B3		;79ad
	cp 009h		;79af
	jr nz,coloca_trios		;79b1
L_79B3:
	ex de,hl			;79b3
	inc (hl)			;79b4   ; tres copias gastadas
	inc (hl)			;79b5
	inc (hl)			;79b6
	ld hl,(0e054h)		;79b7
	ld (hl),c			;79ba   ; las tres, seguidas
	inc hl			;79bb
	ld (hl),c			;79bc
	inc hl			;79bd
	ld (hl),c			;79be
	inc hl			;79bf
	ld (0e054h),hl		;79c0
	ld hl,0e056h		;79c3
	inc (hl)			;79c6   ; tres fichas mas
	inc (hl)			;79c7
	inc (hl)			;79c8
	ld a,(hl)			;79c9
	ld hl,0e057h		;79ca
	cp (hl)			;79cd   ; hasta el objetivo
	jr nz,coloca_trios		;79ce
	cp 00ch		;79d0   ; doce en trios: a la pareja
	jp z,coloca_la_pareja		;79d2

; ----------------------------------------------------------------------
; Escaleras del palo hasta doce fichas: una ficha de numero 1 a 7 con menos de cuatro copias gastadas en ella y en las dos siguientes; con el bit 3 del plan, solo las que empiezan en 1 o en 7, las que tocan terminal. Las tres, seguidas, y sus copias descontadas.
; ----------------------------------------------------------------------
coloca_escaleras:
	call saca_una_ficha_del_plan		;79d5
	ld a,b			;79d8
	cp 030h		;79d9   ; un honor no vale
	jr nc,coloca_escaleras		;79db
	and 00fh		;79dd
	cp 008h		;79df   ; del 8 para arriba no caben dos encima
	jr nc,coloca_escaleras		;79e1
	call apunta_al_contador_de_la_ficha		;79e3
	ld b,003h		;79e6
L_79E8:
	ld a,(hl)			;79e8
	cp 004h		;79e9   ; cuatro copias gastadas: otra
	jr nc,coloca_escaleras		;79eb
	inc hl			;79ed
	djnz L_79E8		;79ee
	ld a,(0e058h)		;79f0
	bit 3,a		;79f3   ; bit 3 del plan: solo 1-2-3 y 7-8-9
	jr z,L_7A02		;79f5
	ld a,c			;79f7
	and 00fh		;79f8
	cp 001h		;79fa
	jr z,L_7A02		;79fc
	cp 007h		;79fe
	jr nz,coloca_escaleras		;7a00
L_7A02:
	ex de,hl			;7a02
	inc (hl)			;7a03   ; una copia mas gastada de cada una de las tres
	inc hl			;7a04
	inc (hl)			;7a05
	inc hl			;7a06
	inc (hl)			;7a07
	ld hl,(0e054h)		;7a08
	ld (hl),c			;7a0b   ; la ficha y las dos siguientes
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
	cp 00ch		;7a1d   ; doce: a la pareja
	jr nz,coloca_escaleras		;7a1f
	xor a			;7a21
	ld (0e056h),a		;7a22
	jr coloca_la_pareja		;7a25

; ----------------------------------------------------------------------
; Seis parejas (fichas con menos de dos copias gastadas; con el bit 3, solo terminales y honores) y el bit 7 del plan puesto: la mano va de siete parejas.
; ----------------------------------------------------------------------
coloca_parejas:
	call saca_una_ficha_del_plan		;7a27
	call apunta_al_contador_de_la_ficha		;7a2a
	ld a,(hl)			;7a2d
	cp 002h		;7a2e   ; con dos o mas copias gastadas, otra
	jr nc,coloca_parejas		;7a30
	ld a,(0e058h)		;7a32
	bit 3,a		;7a35   ; bit 3: solo terminales y honores
	jr z,L_7A48		;7a37
	ld a,c			;7a39
	cp 030h		;7a3a
	jr nc,L_7A48		;7a3c
	and 00fh		;7a3e
	cp 001h		;7a40
	jr z,L_7A48		;7a42
	cp 009h		;7a44
	jr nz,coloca_parejas		;7a46
L_7A48:
	inc (hl)			;7a48   ; dos copias
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
	cp 00ch		;7a5c   ; doce fichas: seis parejas
	jr nz,coloca_parejas		;7a5e
	xor a			;7a60
	ld (0e056h),a		;7a61
	ld hl,0e058h		;7a64
	set 7,(hl)		;7a67   ; bit 7 del plan: siete parejas

; ----------------------------------------------------------------------
; La pareja del final: una ficha con menos de dos copias gastadas (terminal u honor con el bit 3), dos copias en los huecos 12 y 13. Y cae en 0x7A93.
; ----------------------------------------------------------------------
coloca_la_pareja:
	call saca_una_ficha_del_plan		;7a69
	call apunta_al_contador_de_la_ficha		;7a6c
	ld a,(hl)			;7a6f
	cp 002h		;7a70   ; con dos o mas gastadas, otra
	jr nc,coloca_la_pareja		;7a72
	ld a,(0e058h)		;7a74
	bit 3,a		;7a77
	jr z,L_7A8A		;7a79
	ld a,c			;7a7b
	cp 030h		;7a7c   ; un honor pasa
	jr nc,L_7A8A		;7a7e
	and 00fh		;7a80
	cp 001h		;7a82
	jr z,L_7A8A		;7a84
	cp 009h		;7a86
	jr nz,coloca_la_pareja		;7a88
L_7A8A:
	ex de,hl			;7a8a
	inc (hl)			;7a8b   ; dos copias
	inc (hl)			;7a8c
	ld hl,(0e054h)		;7a8d   ; los huecos 12 y 13
	ld (hl),c			;7a90
	inc hl			;7a91
	ld (hl),c			;7a92

; ----------------------------------------------------------------------
; LA FICHA QUE FALTA. Sortea un hueco por debajo de 14; con la tecla 3 (bit 1 de 0xE040) el hueco es SIEMPRE el 11, y con las otras dos lo es solo si el sorteo da 12 o 13. Escribe 0x39 ahi -la mano se queda a una ficha- y la ordena por 0x7AAF, que ademas apunta 0xE054 al principio.
; ----------------------------------------------------------------------
quita_una_ficha:
	call numero_al_azar		;7a93
	cp 00eh		;7a96   ; un hueco por debajo de 14
	jr nc,quita_una_ficha		;7a98
	ld hl,0e040h		;7a9a
	bit 1,(hl)		;7a9d   ; bit 1 de 0xE040: la tecla 3
	jr nz,L_7AA5		;7a9f
	cp 00ch		;7aa1   ; 12 o 13 caen en el 11
	jr nc,L_7AA7		;7aa3
L_7AA5:
	ld a,00bh		;7aa5   ; el hueco 11
L_7AA7:
	ld hl,0e21ch		;7aa7
	call suma_a_a_hl		;7aaa
	ld (hl),039h		;7aad   ; 0x39: la ficha que falta
L_7AAF:
	ld hl,0e21ch		;7aaf
	ld (0e054h),hl		;7ab2   ; 0xE054 apunta al principio
	jp L_4F99		;7ab5   ; y ordenada

; ----------------------------------------------------------------------
; Una ficha al azar que cuadre con el plan de 0xE058: con el bit 0 vale cualquiera; con el bit 1 valen los honores; y si no, tiene que ser del palo de 0xE059. Sale con C = indice y B = codigo.
; ----------------------------------------------------------------------
saca_una_ficha_del_plan:
	call numero_al_azar		;7ab8
	ld c,a			;7abb   ; el indice
	ld de,04fbfh		;7abc
	call suma_a_a_de		;7abf
	ld a,(de)			;7ac2   ; y el codigo
	ld b,a			;7ac3
	and 0f0h		;7ac4
	ld d,a			;7ac6
	ld a,(0e058h)		;7ac7
	rra			;7aca   ; bit 0 del plan: cualquiera vale
	ret c			;7acb
	rra			;7acc   ; bit 1: un honor vale
	jr nc,L_7AD3		;7acd
	ld a,d			;7acf
	cp 030h		;7ad0
	ret z			;7ad2
L_7AD3:
	ld a,(0e059h)		;7ad3
	cp d			;7ad6   ; o del palo elegido
	ret z			;7ad7
	jr saca_una_ficha_del_plan		;7ad8   ; y si no, otra

; ----------------------------------------------------------------------
; Deja HL y DE en el contador de copias de 0xE186 del indice C, y pasa el codigo de B a C.
; ----------------------------------------------------------------------
apunta_al_contador_de_la_ficha:
	ld a,c			;7ada
	ld c,b			;7adb
	ld hl,0e186h		;7adc   ; los contadores de copias
	call suma_a_a_hl		;7adf
	ld d,h			;7ae2
	ld e,l			;7ae3
	ret			;7ae4

; ----------------------------------------------------------------------
; Un numero de 0 a 33 en A, de 0x4F2B.
; ----------------------------------------------------------------------
numero_al_azar:
	call saca_un_numero_al_azar		;7ae5
	ld a,h			;7ae8
	ret			;7ae9

; ----------------------------------------------------------------------
; DATOS mano_de_la_maquina_en_el_demo: LA MANO DEL JUGADOR 2 EN EL DEMO:
;   catorce bytes que 0x78DD copia a 0xE21C sin sortear nada, y que 0x4DA9
;   pasa a la mano de trabajo. Seis parejas (0x08, 0x17, 0x25, 0x33, 0x13 y
;   0x21), un sur (0x32) y un 0x39, el hueco vacio, que al ordenar cae al
;   final: trece fichas, siete parejas a falta de la del sur. En el demo no
;   pasa por 0x7AAD, que solo corre con partida, asi que el hueco es este y no
;   el de indice 11. CORRIGE la nota anterior, que lo tomaba por un ejemplo
;   con dos huecos.
;   0x7aea..0x7af8  (14 bytes)
DATA_mano_de_la_maquina_en_el_demo:
	defb 032h,039h,008h,008h,017h,017h,025h,025h,033h,033h,013h,013h,021h,021h	; 7aea  29....%%33..!!

; ======================================================================
; CODIGO 0x7af8..0x7cd5  (477 bytes)
; ======================================================================



; ----------------------------------------------------------------------
; Evalua las jugadas (0x7B3F) y decide. Con 0xE302 en "sin ganador" (bit 2) devuelve el acarreo puesto si hay 3 han o mas: es la pregunta del tenpai de 0x7740. Si no hay NINGUNA jugada (0xE305 a cero), 0xE1AC = 3 y sale a lo bruto -pop del retorno- hacia 0x4280: cantar sin jugada se castiga. Con 5 honba o mas ordena la lista y, si la mejor no es yakuman y solo hay UN han, castiga tambien: dos han minimo, contados antes de los dora. Luego anade los dora (0x81A9) y ordena la lista de jugadas de menor indice a mayor, que es de mas valor a menos.
; ----------------------------------------------------------------------
evalua_y_decide_la_jugada:
	call evalua_las_jugadas		;7af8   ; todas las jugadas de la mano
	ld a,(0e302h)		;7afb
	bit 2,a		;7afe   ; bit 2 de 0xE302: se pregunta por un tenpai, no por una mano ganada
	jr nz,L_7B38		;7b00
	ld a,(0e305h)		;7b02
	or a			;7b05   ; ninguna jugada
	jr nz,L_7B11		;7b06
L_7B08:
	ld hl,0e1ach		;7b08
	ld (hl),003h		;7b0b   ; 0xE1AC = 3: sin jugada
	pop hl			;7b0d   ; se come el retorno
	jp L_4280		;7b0e   ; y al castigo
L_7B11:
	ld a,(0e04bh)		;7b11
	cp 005h		;7b14   ; con menos de 5 honba vale con una jugada
	jr c,L_7B28		;7b16
	call L_7B2E		;7b18   ; ordena para ver la mejor
	ld a,(0e305h)		;7b1b
	cp 00ch		;7b1e   ; un yakuman vale siempre
	jr c,L_7B28		;7b20
	ld a,(0e316h)		;7b22
	dec a			;7b25   ; un solo han: no vale, DOS HAN MINIMO
	jr z,L_7B08		;7b26
L_7B28:
	call dora		;7b28   ; los dora, que no cuentan para el minimo
	call limpia_el_borrador		;7b2b   ; y el borrador limpio
L_7B2E:
	ld hl,0e305h		;7b2e   ; la lista de jugadas, ordenada por indice
	ld a,(0e315h)		;7b31
	ld b,a			;7b34
	jp L_4F9B		;7b35
L_7B38:
	ld a,(0e316h)		;7b38
	cp 003h		;7b3b   ; acarreo = 3 han o mas
	ccf			;7b3d
	ret			;7b3e

; ----------------------------------------------------------------------
; EL EVALUADOR DE JUGADAS. Limpia 0xE1D2 y el borrador, saca el tipo de espera (0x5BDB, 0x5C1B, 0x5C42) y pasa por los detectores uno a uno; 0x82F9 limpia el borrador entre grupos. El kokushi (bit 1 de 0xE205) corta en seco: solo el. Lo llaman 0x7AF8 (la decision) y 0x5767 (la maquina, para saber si su mano tiene jugada antes de cantar).
; ----------------------------------------------------------------------
evalua_las_jugadas:
	xor a			;7b3f
	ld (0e1d2h),a		;7b40   ; 0xE1D2: el tipo de espera, a cero
	ld (0e127h),a		;7b43
	call espera_ryanmen_o_penchan		;7b46   ; ryanmen o penchan
	call espera_kanchan		;7b49   ; kanchan
	call espera_tanki_o_shanpon		;7b4c   ; tanki o shanpon
	ld a,(0e205h)		;7b4f
	bit 1,a		;7b52   ; bit 1 de 0xE205: trece huerfanos
	ld bc,00003h		;7b54   ; indice 3, yakuman
	jp nz,L_7BF9		;7b57   ; y nada mas
	rra			;7b5a   ; bit 0: siete parejas
	ld bc,00214h		;7b5b   ; 2 han, indice 20
	call c,apunta_la_jugada		;7b5e
	call haitei_y_houtei		;7b61   ; haitei y houtei
	call menzen_tsumo		;7b64   ; menzen tsumo
	call limpia_el_borrador		;7b67
	call toitoi_y_los_trios_ocultos		;7b6a   ; toitoi, sanankou, suuankou y sanshoku doukou
	call tanyao		;7b6d   ; tanyao
	call chinitsu_y_tsuuiisou		;7b70   ; chinitsu y tsuuiisou
	call honitsu		;7b73   ; honitsu
	call riichi_del_jugador_1		;7b76   ; el riichi del jugador 1
	call riichi_del_jugador_2		;7b79   ; y el del 2
	call limpia_el_borrador		;7b7c
	call ittsu_sanshoku_y_pinfu		;7b7f   ; ittsu, sanshoku doujun y pinfu
	call iipeikou_y_ryanpeikou		;7b82   ; iipeikou y ryanpeikou
	call sankantsu_y_suukantsu		;7b85   ; sankantsu y suukantsu
	call rinshan_kaihou		;7b88   ; rinshan kaihou
	call limpia_el_borrador		;7b8b
	call chuuren_poutou		;7b8e   ; chuuren poutou
	call honroutou		;7b91   ; honroutou
	call limpia_el_borrador		;7b94
	call chanta_y_junchan		;7b97   ; chanta y junchan
	call daisuushii		;7b9a   ; daisuushii
	call yakuhai		;7b9d   ; yakuhai
	call ryuuiisou		;7ba0   ; ryuuiisou
	call limpia_el_borrador		;7ba3
	call shousangen_y_daisangen		;7ba6   ; shousangen y daisangen
	call chinroutou		;7ba9   ; chinroutou
	jp tenhou_chiihou_y_renhou		;7bac   ; y tenhou, chiihou y renhou

; ----------------------------------------------------------------------
; Las cuatro jugadas del riichi del jugador 1 (bit 1 de 0xE302 a cero). Con el bit 0 de 0xE1CD (en riichi): si se declaro con el descarte 0 (0xE1CC) es DOBLE RIICHI (bit 1); si el descarte de ahora es el de la declaracion (0xE1BE = 0xE1CC) la mano se ha cerrado en la primera vuelta: IPPATSU (bit 2). De los tres bits sale la jugada: 1 riichi (indice 13, 1 han), 3 doble (12, 2), 5 riichi con ippatsu (14, 2), 7 doble con ippatsu (15, 3).
; ----------------------------------------------------------------------
riichi_del_jugador_1:
	ld a,(0e302h)		;7baf
	bit 1,a		;7bb2   ; bit 1 de 0xE302: esta es del jugador 1
	ret nz			;7bb4
	ld hl,0e1cdh		;7bb5
	ld a,(hl)			;7bb8
	rra			;7bb9   ; bit 0 de 0xE1CD: en riichi
	ret nc			;7bba
	ld a,(0e1cch)		;7bbb
	or a			;7bbe   ; declarado con el descarte 0: DOBLE RIICHI
	jr nz,L_7BC3		;7bbf
	set 1,(hl)		;7bc1
L_7BC3:
	ld c,a			;7bc3
	ld de,0e15eh		;7bc4
	call suma_a_a_de		;7bc7
	ld a,(de)			;7bca
	cp 039h		;7bcb   ; sin descarte despues del riichi
	jr z,L_7BD7		;7bcd
	ld a,(0e1beh)		;7bcf
	cp c			;7bd2   ; el descarte de ahora es el de la declaracion: IPPATSU
	jr nz,L_7BD7		;7bd3
	set 2,(hl)		;7bd5
L_7BD7:
	ld a,(hl)			;7bd7
	and 007h		;7bd8   ; los tres bits
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
	ld bc,0030fh		;7be7   ; doble riichi con ippatsu: 3 han, indice 15
	jr L_7BEF		;7bea
L_7BEC:
	ld bc,0010dh		;7bec   ; riichi: 1 han, indice 13
L_7BEF:
	jr L_7BF4		;7bef
L_7BF1:
	ld bc,0020ch		;7bf1   ; doble riichi: 2 han, indice 12
L_7BF4:
	jr L_7BF9		;7bf4
L_7BF6:
	ld bc,0020eh		;7bf6   ; riichi con ippatsu: 2 han, indice 14
L_7BF9:
	jp apunta_la_jugada		;7bf9

; ----------------------------------------------------------------------
; Lo mismo para el jugador 2, con 0xE1AE (su riichi), 0xE1BB (el descarte con el que lo declaro), 0xE172 y 0xE1BF.
; ----------------------------------------------------------------------
riichi_del_jugador_2:
	ld a,(0e302h)		;7bfc
	bit 1,a		;7bff   ; esta es del jugador 2
	ret z			;7c01
	ld hl,0e1aeh		;7c02
	ld a,(hl)			;7c05
	rra			;7c06   ; bit 0 de 0xE1AE: en riichi
	ret nc			;7c07
	ld a,(0e1bbh)		;7c08
	or a			;7c0b   ; 0xE1BB, el descarte de su riichi: 0 es doble
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
	cp c			;7c1f   ; IPPATSU
	jr nz,L_7C24		;7c20
	set 2,(hl)		;7c22
L_7C24:
	ld a,(hl)			;7c24
	and 007h		;7c25   ; los tres bits, igual que en 0x7BD7
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
	ld bc,0030fh		;7c34   ; 3 han
	jr L_7C3C		;7c37
L_7C39:
	ld bc,0010dh		;7c39   ; 1 han
L_7C3C:
	jr L_7C41		;7c3c
L_7C3E:
	ld bc,0020ch		;7c3e   ; 2 han
L_7C41:
	jr L_7C46		;7c41
L_7C43:
	ld bc,0020eh		;7c43   ; 2 han
L_7C46:
	jr L_7BF9		;7c46

; ----------------------------------------------------------------------
; LA ULTIMA FICHA. Cuenta los descartes: los del que reparte (0xE1BE o 0xE1BF, segun 0xE04D) tienen que llegar a 20 -19 con tsumo-, o los del otro a uno menos y ser ron. Con tsumo es HAITEI (indice 35, 2 han: lleva dentro el han del tsumo, y 0xE1D0 = 1 le dice a 0x8290 que no lo sume otra vez); con ron, HOUTEI (indice 36, 1 han).
; ----------------------------------------------------------------------
haitei_y_houtei:
	ld a,(0e04dh)		;7c48
	rra			;7c4b   ; bit 0 de 0xE04D: reparte el 2
	ld hl,0e1beh		;7c4c
	ld de,0e1bfh		;7c4f
	jr nc,L_7C55		;7c52
	ex de,hl			;7c54   ; HL = descartes del que reparte, DE = del otro
L_7C55:
	ld a,(0e1d1h)		;7c55
	ld b,a			;7c58
	rra			;7c59   ; bit 0 de 0xE1D1: tsumo
	ld c,014h		;7c5a   ; 20 descartes, o 19 con tsumo
	jr nc,L_7C5F		;7c5c
	dec c			;7c5e
L_7C5F:
	ld a,(hl)			;7c5f
	cp c			;7c60
	jr nc,L_7C6A		;7c61   ; el que reparte ha llegado: ultima ficha
	ld a,(de)			;7c63
	dec c			;7c64
	cp c			;7c65
	ret c			;7c66   ; el otro no llega a uno menos: no es la ultima
	ld a,b			;7c67
	rra			;7c68
	ret c			;7c69   ; con tsumo tampoco
L_7C6A:
	ld a,b			;7c6a
	ld bc,00124h		;7c6b   ; houtei: 1 han, indice 36
	rra			;7c6e
	jr nc,L_7C79		;7c6f
	ld bc,00223h		;7c71   ; haitei: 2 han, indice 35, con el tsumo dentro
	ld hl,0e1d0h		;7c74
	ld (hl),001h		;7c77   ; 0xE1D0 = 1: que 0x8290 no sume el tsumo otra vez
L_7C79:
	jp apunta_la_jugada		;7c79

; ----------------------------------------------------------------------
; Tres jugadas de escaleras. Con tres o mas: ITTSU (0x7CC4: 1-2-3, 4-5-6 y 7-8-9 del mismo palo; indice 31, 1 han abierto y 2 cerrado) y SANSHOKU DOUJUN (0x7D17: la misma escalera en los tres palos; indice 32, 1 y 2). Con las CUATRO y la mano cerrada, PINFU (indice 28, 1 han) si es RON, la pareja no es de dragon ni del viento de la ronda ni del asiento (el del que reparte, invertido para el 2), y la espera es ryanmen (bit 0 de 0xE1D2). El cartucho NO da pinfu con tsumo.
; ----------------------------------------------------------------------
ittsu_sanshoku_y_pinfu:
	ld a,(0e2c8h)		;7c7c
	cp 003h		;7c7f   ; menos de tres escaleras: nada
	ret c			;7c81
	call busca_el_ittsu		;7c82   ; ittsu
	call limpia_el_borrador		;7c85
	call busca_el_sanshoku		;7c88   ; sanshoku doujun
	ld a,(0e2c8h)		;7c8b
	cp 004h		;7c8e   ; pinfu solo con cuatro escaleras
	ret nz			;7c90
	ld a,(0e2b6h)		;7c91
	or a			;7c94   ; y mano cerrada
	ret nz			;7c95
	ld a,(0e1d1h)		;7c96
	or a			;7c99   ; y RON: con tsumo no hay pinfu
	ret nz			;7c9a
	ld a,(0e300h)		;7c9b
	cp 035h		;7c9e   ; pareja de dragon: no
	ret nc			;7ca0
	sub 031h		;7ca1   ; viento menos 0x31
	ld hl,0e04ch		;7ca3
	cp (hl)			;7ca6   ; el de la ronda: no
	ret z			;7ca7
	ld c,a			;7ca8
	ld a,(0e302h)		;7ca9
	bit 1,a		;7cac   ; bit 1 de 0xE302: el jugador
	ld hl,0e04dh		;7cae
	ld a,(hl)			;7cb1
	jr z,L_7CB6		;7cb2
	xor 001h		;7cb4   ; el asiento del 2 es el contrario del que reparte
L_7CB6:
	cp c			;7cb6
	ret z			;7cb7   ; el del asiento: no
	ld hl,0e1d2h		;7cb8
	bit 0,(hl)		;7cbb   ; bit 0 de 0xE1D2: ryanmen
	ret z			;7cbd
	ld bc,0011ch		;7cbe   ; PINFU: 1 han, indice 28
	jp apunta_la_jugada		;7cc1

; ----------------------------------------------------------------------
; Por cada palo, las tres escaleras de la tabla de 0x7CD5 (1, 4 y 7): 0x7CDE las cuenta en 0xE127 y da la jugada si estan las tres.
; ----------------------------------------------------------------------
busca_el_ittsu:
	ld hl,07cd5h		;7cc4
	ld b,003h		;7cc7   ; tres palos
L_7CC9:
	push bc			;7cc9
	xor a			;7cca
	ld (0e127h),a		;7ccb   ; la cuenta de escaleras encontradas, a cero
	call cuenta_las_tres_escaleras		;7cce
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


cuenta_las_tres_escaleras:
	ld c,003h		;7cde   ; las tres de un palo
L_7CE0:
	call esta_la_escalera		;7ce0
	inc hl			;7ce3
	dec c			;7ce4
	jr nz,L_7CE0		;7ce5
	ld a,(0e127h)		;7ce7
	cp 003h		;7cea   ; menos de tres: no es ittsu
	ret c			;7cec
	ld a,(0e2b6h)		;7ced
	or a			;7cf0
	ld bc,0011fh		;7cf1   ; ITTSU: 1 han abierto, indice 31
	jr nz,L_7CF8		;7cf4
	ld b,002h		;7cf6   ; 2 cerrado
L_7CF8:
	call apunta_la_jugada		;7cf8
	pop bc			;7cfb   ; se come dos retornos: ya no hay que mirar mas palos
	pop bc			;7cfc
	ret			;7cfd

; ----------------------------------------------------------------------
; Busca la escalera que empieza en (HL) entre las de 0xE2B7 y, si esta, sube 0xE127.
; ----------------------------------------------------------------------
esta_la_escalera:
	ld de,0e2b7h		;7cfe
	ld b,004h		;7d01
L_7D03:
	ld a,(de)			;7d03
	cp (hl)			;7d04
	jr nz,L_7D0F		;7d05   ; no es esta
	ld a,(0e127h)		;7d07
	inc a			;7d0a   ; encontrada: una mas
	ld (0e127h),a		;7d0b
	ret			;7d0e
L_7D0F:
	ld a,004h		;7d0f
	call suma_a_a_de		;7d11
	djnz L_7D03		;7d14
	ret			;7d16

; ----------------------------------------------------------------------
; SANSHOKU DOUJUN: apunta en 0xE127 las escaleras del palo 0 (nibble alto a cero) y 0x7D4A mira si la misma esta en el palo 1 (+0x10) y en el 2 (+0x20). Indice 32: 1 han abierto, 2 cerrado.
; ----------------------------------------------------------------------
busca_el_sanshoku:
	ld a,(0e2c8h)		;7d17
	ld b,a			;7d1a
	ld hl,0e2b7h		;7d1b
	ld de,0e127h		;7d1e
	ld c,000h		;7d21
L_7D23:
	ld a,(hl)			;7d23
	and 0f0h		;7d24   ; solo las del palo 0
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
	or a			;7d34   ; ninguna
	ret z			;7d35
	cp 003h		;7d36   ; con tres del palo 0 no queda sitio para los otros
	ret nc			;7d38
	call la_misma_en_los_otros_palos		;7d39
	ld a,(0e2b6h)		;7d3c
	or a			;7d3f
	ld bc,00120h		;7d40   ; 1 han abierto, indice 32
	jr nz,L_7D47		;7d43
	ld b,002h		;7d45   ; 2 cerrado
L_7D47:
	jp apunta_la_jugada		;7d47
la_misma_en_los_otros_palos:
	ld de,0e127h		;7d4a
	ld c,002h		;7d4d   ; dos candidatas como mucho
L_7D4F:
	ld a,(0e2c8h)		;7d4f
	or a			;7d52
	ret z			;7d53
	ld b,a			;7d54
	ld hl,0e2b7h		;7d55
L_7D58:
	ld a,(de)			;7d58
	add a,010h		;7d59   ; la misma escalera un palo mas arriba
	cp (hl)			;7d5b
	jr z,L_7D6B		;7d5c
	ld a,004h		;7d5e
	call suma_a_a_hl		;7d60
	djnz L_7D58		;7d63
	inc de			;7d65
	dec c			;7d66
	jr nz,L_7D4F		;7d67
	pop hl			;7d69   ; no esta: se come el retorno, no hay sanshoku
	ret			;7d6a
L_7D6B:
	ld (de),a			;7d6b   ; encontrada en el palo 1: ahora el 2
	ld a,(0e2c8h)		;7d6c
	or a			;7d6f
	ret z			;7d70
	ld b,a			;7d71
	ld hl,0e2b7h		;7d72
L_7D75:
	ld a,(de)			;7d75
	add a,010h		;7d76   ; y un palo mas
	cp (hl)			;7d78
	ret z			;7d79
	ld a,004h		;7d7a
	call suma_a_a_hl		;7d7c
	djnz L_7D75		;7d7f
	pop hl			;7d81
	ret			;7d82

; ----------------------------------------------------------------------
; Solo con la mano cerrada: 0xE303, las parejas de escaleras iguales que apunto el motor. Una es IIPEIKOU (indice 30, 1 han); dos, RYANPEIKOU (indice 18, 3 han).
; ----------------------------------------------------------------------
iipeikou_y_ryanpeikou:
	ld a,(0e2b6h)		;7d83
	or a			;7d86   ; con llamadas no hay
	ret nz			;7d87
	ld a,(0e303h)		;7d88
	or a			;7d8b   ; ninguna pareja de escaleras
	ret z			;7d8c
	dec a			;7d8d
	ld bc,0011eh		;7d8e   ; iipeikou: 1 han, indice 30
	jr z,L_7D96		;7d91
	ld bc,00312h		;7d93   ; ryanpeikou: 3 han, indice 18
L_7D96:
	jr L_7D47		;7d96

; ----------------------------------------------------------------------
; Tres cuartetos, SANKANTSU (indice 25, 2 han); cuatro, SUUKANTSU (indice 11, yakuman).
; ----------------------------------------------------------------------
sankantsu_y_suukantsu:
	ld a,(0e2f0h)		;7d98
	cp 003h		;7d9b   ; menos de tres
	ret c			;7d9d
	cp 004h		;7d9e
	ld bc,0000bh		;7da0   ; cuatro: yakuman, indice 11
	jr z,L_7DA8		;7da3
	ld bc,00219h		;7da5   ; tres: 2 han, indice 25
L_7DA8:
	jp apunta_la_jugada		;7da8

; ----------------------------------------------------------------------
; Con tres o mas trios y cuartetos. Primero 0x7DE7 mira el sanshoku doukou. Con cuatro, TOITOI (indice 22, 2 han, y 0xE1E0 = 1 para el daisuushii), y segun cuantos esten abiertos (0xE2D9 mas los kan abiertos de 0xE2EF): ninguno, SUUANKOU (indice 10, yakuman); uno, SANANKOU (indice 24, 2 han). Con tres justos y ninguno abierto, sanankou tambien. El trio cerrado con la ficha de ron cuenta como abierto (0x6185).
; ----------------------------------------------------------------------
toitoi_y_los_trios_ocultos:
	ld a,(0e2dah)		;7dab   ; trios mas cuartetos
	ld hl,0e2f0h		;7dae
	add a,(hl)			;7db1
	cp 003h		;7db2
	ret c			;7db4   ; menos de tres
	push af			;7db5
	call busca_el_sanshoku_doukou		;7db6   ; el sanshoku doukou, de paso
	pop af			;7db9
	jr z,L_7DD9		;7dba   ; tres justos
	ld bc,00216h		;7dbc   ; TOITOI: 2 han, indice 22
	ld hl,0e1e0h		;7dbf
	ld (hl),001h		;7dc2   ; 0xE1E0 = 1, para el daisuushii
	call apunta_la_jugada		;7dc4
	ld a,(0e2d9h)		;7dc7   ; los abiertos: trios mas kan
	ld hl,0e2efh		;7dca
	add a,(hl)			;7dcd
	cp 002h		;7dce   ; dos o mas abiertos: nada mas
	ret nc			;7dd0
	or a			;7dd1
	ld bc,0000ah		;7dd2   ; ninguno abierto: SUUANKOU, yakuman, indice 10
	jr z,L_7DE4		;7dd5
	jr L_7DE1		;7dd7
L_7DD9:
	ld a,(0e2d9h)		;7dd9   ; con tres: ninguno abierto
	ld hl,0e2efh		;7ddc
	add a,(hl)			;7ddf
	ret nz			;7de0
L_7DE1:
	ld bc,00218h		;7de1   ; SANANKOU: 2 han, indice 24
L_7DE4:
	jp apunta_la_jugada		;7de4

; ----------------------------------------------------------------------
; SANSHOKU DOUKOU: los trios y cuartetos del palo 0 van a 0xE128 (0x7E9F), y 0x7E22 busca el mismo numero en el palo 1 y en el 2, entre trios y cuartetos. Indice 19 y 3 HAN: aqui el cartucho da uno mas que el riichi de cuatro, donde son dos.
; ----------------------------------------------------------------------
busca_el_sanshoku_doukou:
	ld a,(0e2dah)		;7de7
	or a			;7dea   ; sin trios
	jr z,L_7DFE		;7deb
	ld b,a			;7ded
	ld hl,0e2c9h		;7dee
	ld de,0e128h		;7df1
	ld c,000h		;7df4
	ld a,004h		;7df6   ; registros de cuatro bytes
	ld (0e127h),a		;7df8
	call apunta_los_del_palo_0		;7dfb
L_7DFE:
	ld a,(0e2f0h)		;7dfe
	or a			;7e01   ; sin cuartetos
	jr z,L_7E12		;7e02
	ld b,a			;7e04
	ld hl,0e2dbh		;7e05
	ld c,000h		;7e08
	ld a,005h		;7e0a   ; de cinco
	ld (0e127h),a		;7e0c
	call apunta_los_del_palo_0		;7e0f
L_7E12:
	ld a,c			;7e12
	or a			;7e13   ; ninguno del palo 0
	ret z			;7e14
	cp 003h		;7e15   ; tres del palo 0: no cabe
	ret nc			;7e17
	ld c,a			;7e18
	call el_mismo_trio_en_los_otros_palos		;7e19
	ld bc,00313h		;7e1c   ; 3 han, indice 19
	jp apunta_la_jugada		;7e1f
el_mismo_trio_en_los_otros_palos:
	ld de,0e128h		;7e22
	ld c,002h		;7e25   ; dos candidatos
L_7E27:
	ld a,(0e2dah)		;7e27
	or a			;7e2a
	jr z,L_7E42		;7e2b
	ld b,a			;7e2d
	ld hl,0e2c9h		;7e2e
L_7E31:
	ld a,(de)			;7e31
	add a,010h		;7e32   ; un palo mas arriba
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
	add a,010h		;7e52   ; un palo mas arriba, entre los cuartetos
	cp (hl)			;7e54
	jr z,L_7E64		;7e55
	ld a,005h		;7e57   ; cinco bytes por cuarteto
	call suma_a_a_hl		;7e59
	djnz L_7E51		;7e5c
	inc de			;7e5e
	dec c			;7e5f
	jr nz,L_7E47		;7e60
	jr L_7E9D		;7e62
L_7E64:
	ld (de),a			;7e64   ; encontrado en el palo 1: ahora el 2
	ld c,002h		;7e65
L_7E67:
	ld a,(0e2dah)		;7e67
	or a			;7e6a
	jr z,L_7E81		;7e6b
	ld b,a			;7e6d
	ld hl,0e2c9h		;7e6e
L_7E71:
	ld a,(de)			;7e71
	add a,010h		;7e72   ; y en el palo 2, entre los trios
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
	add a,010h		;7e8e   ; o entre los cuartetos
	cp (hl)			;7e90
	ret z			;7e91
	ld a,005h		;7e92
	call suma_a_a_hl		;7e94
	djnz L_7E8D		;7e97
	inc de			;7e99
	dec c			;7e9a
	jr nz,L_7E83		;7e9b
L_7E9D:
	pop hl			;7e9d   ; no esta: se come el retorno
	ret			;7e9e
apunta_los_del_palo_0:
	ld a,(hl)			;7e9f
	and 0f0h		;7ea0   ; nibble alto a cero: palo 0
	jr nz,L_7EA8		;7ea2
	ld a,(hl)			;7ea4
	ld (de),a			;7ea5
	inc de			;7ea6
	inc c			;7ea7
L_7EA8:
	ld a,(0e127h)		;7ea8   ; al registro siguiente
	call suma_a_a_hl		;7eab
	djnz apunta_los_del_palo_0		;7eae
	ret			;7eb0

; ----------------------------------------------------------------------
; RINSHAN KAIHOU: la ficha que cierra es la de reposicion de un kan (0xE1CF, que puso 0x6E45) y es tsumo. Indice 37, 1 han.
; ----------------------------------------------------------------------
rinshan_kaihou:
	ld a,(0e1cfh)		;7eb1
	rra			;7eb4   ; bit 0 de 0xE1CF: la ficha de reposicion
	ret nc			;7eb5
	ld a,(0e1d1h)		;7eb6
	rra			;7eb9   ; y tsumo
	ret nc			;7eba
	ld bc,00125h		;7ebb   ; 1 han, indice 37
	jp apunta_la_jugada		;7ebe

; ----------------------------------------------------------------------
; TANYAO: ninguna de las catorce fichas es honor, uno ni nueve. Indice 29, 1 han, y 0xE1DD = 1. No mira 0xE2B6: el tanyao abierto vale.
; ----------------------------------------------------------------------
tanyao:
	ld b,00eh		;7ec1
	ld de,0e2f1h		;7ec3
L_7EC6:
	ld a,(de)			;7ec6
	cp 030h		;7ec7   ; un honor: no
	ret nc			;7ec9
	and 00fh		;7eca
	cp 001h		;7ecc   ; un uno: no
	ret z			;7ece
	cp 009h		;7ecf   ; un nueve: no
	ret z			;7ed1
	inc de			;7ed2
	djnz L_7EC6		;7ed3
	ld bc,0011dh		;7ed5   ; 1 han, indice 29
	ld hl,0e1ddh		;7ed8
	ld (hl),001h		;7edb
	jp apunta_la_jugada		;7edd

; ----------------------------------------------------------------------
; Las catorce fichas con el mismo nibble alto. Si es 0x30 es TSUUIISOU, todo honores (indice 4, yakuman); si no, CHINITSU (indice 17, 5 han abierto y 6 cerrado) y 0xE1DE = 1, que es lo que le abre la puerta al chuuren y se la cierra al honitsu.
; ----------------------------------------------------------------------
chinitsu_y_tsuuiisou:
	ld b,00eh		;7ee0
	ld de,0e2f1h		;7ee2
	ld a,(de)			;7ee5
	and 0f0h		;7ee6   ; el palo de la primera
	ld c,a			;7ee8
L_7EE9:
	ld a,(de)			;7ee9
	and 0f0h		;7eea
	cp c			;7eec
	ret nz			;7eed   ; una de otro palo: no
	inc de			;7eee
	djnz L_7EE9		;7eef
	ld a,c			;7ef1
	cp 030h		;7ef2   ; 0x30: todo honores
	ld bc,00004h		;7ef4   ; yakuman, indice 4
	jr z,L_7F09		;7ef7
	ld a,(0e2b6h)		;7ef9
	or a			;7efc
	ld bc,00511h		;7efd   ; 5 han abierto, indice 17
	jr nz,L_7F04		;7f00
	ld b,006h		;7f02   ; 6 cerrado
L_7F04:
	ld hl,0e1deh		;7f04
	ld (hl),001h		;7f07   ; 0xE1DE = 1: un solo palo
L_7F09:
	jp apunta_la_jugada		;7f09

; ----------------------------------------------------------------------
; CHUUREN POUTOU: mano cerrada de un solo palo (0xE1DE) con tres unos, tres nueves y del dos al ocho al menos una. Cuenta las fichas por numero en 0xE128-0xE130 sumando el CODIGO a 0xE127, y eso solo cabe si el palo es el 0: con el palo 1 o el 2 el cp de 0x7F1A la descarta. Solo se detecta en el primer palo. Indice 7, yakuman.
; ----------------------------------------------------------------------
chuuren_poutou:
	ld a,(0e205h)		;7f0c
	rra			;7f0f   ; siete parejas: no
	ret c			;7f10
	ld a,(0e1deh)		;7f11
	rra			;7f14   ; sin un solo palo: no
	ret nc			;7f15
	ld de,0e2f1h		;7f16
	ld a,(de)			;7f19
	cp 00ah		;7f1a   ; solo el palo 0: los codigos 0x11 y 0x21 no pasan
	ret nc			;7f1c
	ld a,(0e2b6h)		;7f1d
	or a			;7f20   ; y cerrada
	ret nz			;7f21
	ld b,00eh		;7f22
	ld hl,0e127h		;7f24
L_7F27:
	push hl			;7f27
	ld a,(de)			;7f28
	call suma_a_a_hl		;7f29
	inc (hl)			;7f2c   ; una ficha mas de ese numero
	pop hl			;7f2d
	inc de			;7f2e
	djnz L_7F27		;7f2f
	ld hl,0e128h		;7f31
	ld a,(hl)			;7f34
	cp 003h		;7f35   ; menos de tres unos
	ret c			;7f37
	inc hl			;7f38
	ld bc,00700h		;7f39   ; del dos al ocho
L_7F3C:
	ld a,(hl)			;7f3c
	or c			;7f3d
	ret z			;7f3e   ; uno que falte y no es
	inc hl			;7f3f
	djnz L_7F3C		;7f40
	ld a,(hl)			;7f42
	cp 003h		;7f43   ; menos de tres nueves
	ret c			;7f45
	ld bc,00007h		;7f46   ; yakuman, indice 7
	jp apunta_la_jugada		;7f49

; ----------------------------------------------------------------------
; CHANTA y JUNCHAN. Si ya es honroutou (0xE238) no hay nada que mirar. Cuenta los honores en 0xE127: la pareja tiene que ser honor o terminal; cada escalera, 1-2-3 o 7-8-9; cada trio y cuarteto, terminal u honor. Con siete parejas (0x7FF7), las siete de terminal u honor. Con algun honor, CHANTA (indice 33, 1 han abierto y 2 cerrado); sin ninguno, JUNCHAN (indice 23, 2 y 3).
; ----------------------------------------------------------------------
chanta_y_junchan:
	ld a,(0e238h)		;7f4c
	rra			;7f4f   ; honroutou: no
	ret c			;7f50
	xor a			;7f51
	ld (0e127h),a		;7f52   ; la cuenta de honores
	ld a,(0e205h)		;7f55
	rra			;7f58
	jp c,siete_parejas_de_terminal_u_honor		;7f59   ; siete parejas: por 0x7FF7
	ld a,(0e300h)		;7f5c
	cp 030h		;7f5f   ; la pareja, honor
	jr c,L_7F69		;7f61
	ld hl,0e127h		;7f63
	inc (hl)			;7f66
	jr L_7F72		;7f67
L_7F69:
	and 00fh		;7f69
	cp 009h		;7f6b   ; o nueve
	jr z,L_7F72		;7f6d
	cp 001h		;7f6f   ; o uno, y si no, nada
	ret nz			;7f71
L_7F72:
	ld a,(0e2c8h)		;7f72
	or a			;7f75   ; sin escaleras
	jr z,L_7F9F		;7f76
	add a,a			;7f78   ; dos comprobaciones por escalera
	ld b,a			;7f79
	ld de,0e2b7h		;7f7a
L_7F7D:
	ld a,(de)			;7f7d
	cp 030h		;7f7e
	jr c,L_7F85		;7f80   ; empieza en honor
	inc (hl)			;7f82
	jr L_7F94		;7f83
L_7F85:
	and 00fh		;7f85
	cp 009h		;7f87   ; empieza en nueve
	jr z,L_7F94		;7f89
	cp 001h		;7f8b   ; o en uno
	jr z,L_7F94		;7f8d
	ld a,b			;7f8f
	rra			;7f90   ; si era la segunda comprobacion, no cuadra
	ret c			;7f91
	jr L_7F9B		;7f92
L_7F94:
	ld a,b			;7f94
	rra			;7f95
	jr c,L_7F9B		;7f96
	dec b			;7f98   ; la escalera vale: a la siguiente
	inc de			;7f99
	inc de			;7f9a
L_7F9B:
	inc de			;7f9b   ; la tercera ficha
	inc de			;7f9c
	djnz L_7F7D		;7f9d
L_7F9F:
	ld a,(0e2dah)		;7f9f
	or a			;7fa2
	jr z,L_7FAE		;7fa3
	ld b,a			;7fa5
	ld de,0e2c9h		;7fa6
	ld c,004h		;7fa9   ; registros de cuatro: los trios
	call todos_de_terminal_u_honor		;7fab
L_7FAE:
	ld a,(0e2f0h)		;7fae
	or a			;7fb1
	jr z,L_7FBD		;7fb2
	ld b,a			;7fb4
	ld de,0e2dbh		;7fb5
	ld c,005h		;7fb8   ; de cinco: los cuartetos
	call todos_de_terminal_u_honor		;7fba
L_7FBD:
	ld a,(hl)			;7fbd
	or a			;7fbe   ; sin honores: junchan
	jr z,L_7FCE		;7fbf
	ld a,(0e2b6h)		;7fc1
	or a			;7fc4
	ld bc,00121h		;7fc5   ; chanta: 1 han abierto, indice 33
	jr nz,L_7FCC		;7fc8
	ld b,002h		;7fca   ; 2 cerrado
L_7FCC:
	jr L_7FD9		;7fcc
L_7FCE:
	ld a,(0e2b6h)		;7fce
	or a			;7fd1
	ld bc,00217h		;7fd2   ; junchan: 2 han abierto, indice 23
	jr nz,L_7FD9		;7fd5
	ld b,003h		;7fd7   ; 3 cerrado
L_7FD9:
	jp apunta_la_jugada		;7fd9
todos_de_terminal_u_honor:
	ld a,(de)			;7fdc
	cp 030h		;7fdd   ; un honor cuenta
	jr c,L_7FE4		;7fdf
	inc (hl)			;7fe1
	jr L_7FF0		;7fe2
L_7FE4:
	and 00fh		;7fe4
	cp 009h		;7fe6   ; nueve
	jr z,L_7FF0		;7fe8
	cp 001h		;7fea   ; o uno
	jr z,L_7FF0		;7fec
	pop de			;7fee   ; ni una cosa ni otra: se come el retorno
	ret			;7fef
L_7FF0:
	ld a,c			;7ff0
	call suma_a_a_de		;7ff1
	djnz todos_de_terminal_u_honor		;7ff4
	ret			;7ff6
siete_parejas_de_terminal_u_honor:
	ld hl,0e127h		;7ff7
	ld de,0e2f1h		;7ffa
	ld b,007h		;7ffd   ; siete parejas
L_7FFF:
	ld a,(de)			;7fff
	cp 030h		;8000   ; honor
	jr c,L_8007		;8002
	inc (hl)			;8004
	jr L_8010		;8005
L_8007:
	and 00fh		;8007
	cp 009h		;8009   ; nueve
	jr z,L_8010		;800b
	cp 001h		;800d   ; o uno, y si no, nada
	ret nz			;800f
L_8010:
	inc de			;8010
	inc de			;8011
	djnz L_7FFF		;8012
	jr L_7FBD		;8014

; ----------------------------------------------------------------------
; DAISUUSHII: con toitoi (0xE1E0) y todos los trios y cuartetos de VIENTO (honor con numero menor que 5). Indice 5, yakuman.
; ----------------------------------------------------------------------
daisuushii:
	ld a,(0e1e0h)		;8016
	rra			;8019   ; sin toitoi no
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
	or a			;802d   ; sin cuartetos
	jr z,L_8039		;802e
	ld b,a			;8030
	ld de,0e2dbh		;8031
	ld c,005h		;8034
	call L_803F		;8036
L_8039:
	ld bc,00005h		;8039   ; yakuman, indice 5
	jp apunta_la_jugada		;803c
L_803F:
	ld a,(de)			;803f
	cp 030h		;8040   ; no es honor: no
	jr c,L_8051		;8042
	and 00fh		;8044
	cp 005h		;8046   ; un dragon: no
	jr nc,L_8051		;8048
	ld a,c			;804a
	call suma_a_a_de		;804b
	djnz L_803F		;804e
	ret			;8050
L_8051:
	pop de			;8051
	ret			;8052

; ----------------------------------------------------------------------
; YAKUHAI: cuenta en C los trios y cuartetos de dragon, de viento de la ronda (L = 0x31 + 0xE04C) y de viento del asiento (H = 0x31 + el asiento del jugador: el del que reparte, invertido para el 2). El viento que es de la ronda y del asiento cuenta dos. Indice 34 con C han, y la cuenta en 0xE1D6 para escribirla.
; ----------------------------------------------------------------------
yakuhai:
	ld a,(0e205h)		;8053
	rra			;8056   ; siete parejas: no
	ret c			;8057
	ld a,(0e04ch)		;8058
	add a,031h		;805b   ; L = el viento de la ronda
	ld l,a			;805d
	ld a,(0e302h)		;805e
	bit 1,a		;8061   ; bit 1 de 0xE302: el jugador
	ld a,(0e04dh)		;8063
	jr z,L_806B		;8066
	cpl			;8068   ; el asiento del 2, el contrario
	and 001h		;8069
L_806B:
	add a,031h		;806b   ; H = el viento del asiento
	ld h,a			;806d
	ld c,000h		;806e   ; la cuenta
	ld a,(0e2dah)		;8070
	or a			;8073
	jr z,L_8082		;8074
	ld b,a			;8076
	ld de,0e2c9h		;8077
	ld a,004h		;807a   ; de cuatro bytes
	ld (0e127h),a		;807c
	call cuenta_los_yakuhai		;807f
L_8082:
	ld a,(0e2f0h)		;8082
	or a			;8085
	jr z,L_8094		;8086
	ld b,a			;8088
	ld de,0e2dbh		;8089
	ld a,005h		;808c   ; de cinco
	ld (0e127h),a		;808e
	call cuenta_los_yakuhai		;8091
L_8094:
	ld hl,0e1d6h		;8094
	ld a,c			;8097
	or a			;8098   ; ninguno
	ret z			;8099
	ld (hl),c			;809a   ; 0xE1D6 = la cuenta, para escribirla
	ld b,c			;809b
	ld c,022h		;809c   ; tantos han como yakuhai, indice 34
	jp apunta_la_jugada		;809e
cuenta_los_yakuhai:
	ld a,(de)			;80a1
	cp h			;80a2   ; el del asiento
	jr nz,L_80A6		;80a3
	inc c			;80a5
L_80A6:
	cp l			;80a6   ; el de la ronda
	jr nz,L_80AA		;80a7
	inc c			;80a9
L_80AA:
	cp 035h		;80aa
	jr c,L_80B3		;80ac   ; un dragon
	cp 038h		;80ae
	jr nc,L_80B3		;80b0
	inc c			;80b2
L_80B3:
	ld a,(0e127h)		;80b3
	call suma_a_a_de		;80b6
	djnz cuenta_los_yakuhai		;80b9
	ret			;80bb

; ----------------------------------------------------------------------
; HONITSU: un palo mas honores. Si ya era chinitsu (0xE1DE) no. Salta los honores del principio, se queda con el palo de la primera ficha que no lo sea, y todas las demas tienen que ser de ese palo u honores. Indice 21, 2 han abierto y 3 cerrado; 0xE1DC = 1.
; ----------------------------------------------------------------------
honitsu:
	ld a,(0e1deh)		;80bc
	rra			;80bf   ; chinitsu ya: no
	ret c			;80c0
	ld b,00eh		;80c1
	ld de,0e2f1h		;80c3
L_80C6:
	ld a,(de)			;80c6
	and 0f0h		;80c7
	cp 030h		;80c9   ; los honores del principio se saltan
	jr nz,L_80D0		;80cb
	inc de			;80cd
	djnz L_80C6		;80ce
L_80D0:
	ld b,00eh		;80d0
	ld c,a			;80d2   ; el palo
L_80D3:
	ld a,(de)			;80d3
	and 0f0h		;80d4
	cp c			;80d6
	jr z,L_80DC		;80d7
	cp 030h		;80d9   ; ni del palo ni honor: no
	ret nz			;80db
L_80DC:
	inc de			;80dc
	djnz L_80D3		;80dd
	ld a,(0e2b6h)		;80df
	or a			;80e2
	ld bc,00215h		;80e3   ; 2 han abierto, indice 21
	jr nz,L_80EA		;80e6
	ld b,003h		;80e8   ; 3 cerrado
L_80EA:
	ld hl,0e1dch		;80ea
	ld (hl),001h		;80ed
	jp apunta_la_jugada		;80ef

; ----------------------------------------------------------------------
; HONROUTOU: sin escaleras, y todas las fichas honor, uno o nueve. Indice 27, 2 han, y 0xE238 = 1 para que el chanta no lo cuente otra vez.
; ----------------------------------------------------------------------
honroutou:
	ld a,(0e2c8h)		;80f2
	or a			;80f5   ; con escaleras no
	ret nz			;80f6
	ld b,00eh		;80f7
	ld de,0e2f1h		;80f9
L_80FC:
	ld a,(de)			;80fc
	cp 030h		;80fd   ; honor
	jr nc,L_810A		;80ff
	and 00fh		;8101
	cp 001h		;8103   ; uno
	jr z,L_810A		;8105
	cp 009h		;8107   ; o nueve
	ret nz			;8109
L_810A:
	inc de			;810a
	djnz L_80FC		;810b
	ld hl,0e238h		;810d
	ld (hl),001h		;8110   ; 0xE238 = 1: honroutou
	ld bc,0021bh		;8112   ; 2 han, indice 27
	jp apunta_la_jugada		;8115

; ----------------------------------------------------------------------
; RYUUIISOU, todo verde: solo el dragon verde (0x36) y los bambues 2, 3, 4, 6 y 8 (0x22, 0x23, 0x24, 0x26, 0x28). Es lo que dice que el palo 2 son los BAMBUES y el 0x36 el dragon verde. Indice 9, yakuman.
; ----------------------------------------------------------------------
ryuuiisou:
	ld b,00eh		;8118
	ld de,0e2f1h		;811a
L_811D:
	ld a,(de)			;811d
	cp 036h		;811e   ; 0x36, el dragon verde
	jr z,L_8135		;8120
	cp 022h		;8122   ; bambu 2
	jr z,L_8135		;8124
	cp 023h		;8126
	jr z,L_8135		;8128
	cp 024h		;812a
	jr z,L_8135		;812c
	cp 026h		;812e
	jr z,L_8135		;8130
	cp 028h		;8132   ; y el 8
	ret nz			;8134   ; cualquier otra: no
L_8135:
	inc de			;8135
	djnz L_811D		;8136
	ld bc,00009h		;8138   ; yakuman, indice 9
	jp apunta_la_jugada		;813b

; ----------------------------------------------------------------------
; Cuenta los trios y cuartetos de dragon (0x35-0x37). Tres: DAISANGEN (indice 6, yakuman). Dos y la pareja de dragon: SHOUSANGEN (indice 26, 2 han).
; ----------------------------------------------------------------------
shousangen_y_daisangen:
	ld hl,0e127h		;813e
	ld (hl),000h		;8141   ; la cuenta de dragones, a cero
	ld a,(0e2dah)		;8143
	or a			;8146
	jr z,L_8152		;8147
	ld b,a			;8149
	ld de,0e2c9h		;814a
	ld c,004h		;814d
	call cuenta_los_dragones		;814f
L_8152:
	ld a,(0e2f0h)		;8152
	or a			;8155   ; sin cuartetos
	jr z,L_8161		;8156
	ld b,a			;8158
	ld de,0e2dbh		;8159
	ld c,005h		;815c
	call cuenta_los_dragones		;815e
L_8161:
	ld a,(hl)			;8161
	cp 002h		;8162   ; menos de dos
	ret c			;8164
	jr z,L_816C		;8165
	ld bc,00006h		;8167   ; tres: daisangen, yakuman, indice 6
	jr L_8178		;816a
L_816C:
	ld a,(0e300h)		;816c
	cp 035h		;816f   ; la pareja tiene que ser de dragon
	ret c			;8171
	cp 038h		;8172
	ret nc			;8174
	ld bc,0021ah		;8175   ; shousangen: 2 han, indice 26
L_8178:
	jp apunta_la_jugada		;8178
cuenta_los_dragones:
	ld a,(de)			;817b
	cp 035h		;817c   ; 0x35 a 0x37
	jr c,L_8185		;817e
	cp 038h		;8180
	jr nc,L_8185		;8182
	inc (hl)			;8184   ; uno mas
L_8185:
	ld a,c			;8185
	call suma_a_a_de		;8186
	djnz cuenta_los_dragones		;8189
	ret			;818b

; ----------------------------------------------------------------------
; CHINROUTOU: sin escaleras y todas las fichas con numero 1 o 9. Pero mira solo el nibble bajo, y el este (0x31) pasa como si fuera un uno: un honroutou con trio del este cuenta tambien como chinroutou. Indice 8, yakuman.
; ----------------------------------------------------------------------
chinroutou:
	ld a,(0e2c8h)		;818c
	or a			;818f   ; con escaleras no
	ret nz			;8190
	ld b,00eh		;8191
	ld de,0e2f1h		;8193
L_8196:
	ld a,(de)			;8196
	and 00fh		;8197   ; solo el numero: el 0x31 pasa por un uno
	cp 001h		;8199
	jr z,L_81A0		;819b
	cp 009h		;819d
	ret nz			;819f
L_81A0:
	inc de			;81a0
	djnz L_8196		;81a1
	ld bc,00008h		;81a3   ; yakuman, indice 8
L_81A6:
	jp apunta_la_jugada		;81a6

; ----------------------------------------------------------------------
; LOS DORA. El indicador es 0xE1D3 y el del ura-dora 0xE1D4, que solo cuenta con riichi (bit 0 de 0xE1CD o de 0xE1AE). 0x8270 pasa del indicador al dora y 0x8210 cuenta las copias en escaleras, trios (tres), cuartetos (cuatro) y la pareja (dos); con siete parejas, 0x8202 las cuenta en la mano. Indice 38 con tantos han como dora, y la cuenta en 0xE1D7.
; ----------------------------------------------------------------------
dora:
	ld hl,0e127h		;81a9
	ld (hl),000h		;81ac
	ld a,(0e205h)		;81ae   ; siete parejas: se cuentan en la mano
	rra			;81b1
	jr c,L_81DD		;81b2
	ld a,(0e302h)		;81b4
	bit 1,a		;81b7   ; bit 1 de 0xE302: el jugador
	ld de,0e1cdh		;81b9
	jr z,L_81C1		;81bc
	ld de,0e1aeh		;81be
L_81C1:
	ld a,(de)			;81c1
	rra			;81c2   ; en riichi: el ura-dora cuenta
	ld a,(0e1d4h)		;81c3   ; el indicador del ura-dora
	ld c,a			;81c6
	call c,cuenta_el_dora_en_las_figuras		;81c7
	ld a,(0e1d3h)		;81ca   ; el indicador del dora
	ld c,a			;81cd
	call cuenta_el_dora_en_las_figuras		;81ce
L_81D1:
	ld a,(hl)			;81d1
	or a			;81d2   ; ningun dora
	ret z			;81d3
	ld hl,0e1d7h		;81d4   ; 0xE1D7 = la cuenta
	ld (hl),a			;81d7
	ld b,a			;81d8
	ld c,026h		;81d9   ; tantos han como dora, indice 38
	jr L_81A6		;81db
L_81DD:
	ld a,(0e302h)		;81dd
	bit 1,a		;81e0
	ld de,0e1cdh		;81e2
	jr z,L_81EA		;81e5
	ld de,0e1aeh		;81e7
L_81EA:
	ld a,(0e1d4h)		;81ea   ; el ura, en siete parejas
	ld c,a			;81ed
	call del_indicador_al_dora		;81ee
	ld a,(de)			;81f1
	rra			;81f2   ; solo con riichi
	call c,cuenta_el_dora_en_la_mano		;81f3
	ld a,(0e1d3h)		;81f6   ; y el dora
	ld c,a			;81f9
	call del_indicador_al_dora		;81fa
	call cuenta_el_dora_en_la_mano		;81fd
	jr L_81D1		;8200
cuenta_el_dora_en_la_mano:
	ld de,0e2f1h		;8202
	ld b,00eh		;8205
L_8207:
	ld a,(de)			;8207
	cp c			;8208   ; una copia
	jr nz,L_820C		;8209
	inc (hl)			;820b
L_820C:
	inc de			;820c
	djnz L_8207		;820d
	ret			;820f
cuenta_el_dora_en_las_figuras:
	call del_indicador_al_dora		;8210   ; del indicador al dora
	ld a,(0e2c8h)		;8213
	or a			;8216   ; sin escaleras
	jr z,L_822C		;8217
	ld b,a			;8219
	ld de,0e2b7h		;821a
L_821D:
	call cuenta_en_escalera		;821d   ; las tres fichas de cada escalera
	inc de			;8220
	call cuenta_en_escalera		;8221
	inc de			;8224
	call cuenta_en_escalera		;8225
	inc de			;8228
	inc de			;8229
	djnz L_821D		;822a
L_822C:
	ld a,(0e2dah)		;822c
	or a			;822f
	jr z,L_823E		;8230
	ld b,a			;8232
	ld de,0e2c9h		;8233
	ld a,004h		;8236   ; un trio son tres
	ld (0e128h),a		;8238
	call cuenta_en_trios_o_cuartetos		;823b
L_823E:
	ld a,(0e2f0h)		;823e
	or a			;8241
	jr z,L_8250		;8242
	ld b,a			;8244
	ld de,0e2dbh		;8245
	ld a,005h		;8248   ; un cuarteto, cuatro
	ld (0e128h),a		;824a
	call cuenta_en_trios_o_cuartetos		;824d
L_8250:
	ld a,(0e300h)		;8250
	cp c			;8253   ; y la pareja
	ret nz			;8254
	inc (hl)			;8255   ; dos
	inc (hl)			;8256
	ret			;8257
cuenta_en_trios_o_cuartetos:
	ld a,(de)			;8258
	cp c			;8259
	jr nz,L_8262		;825a
	ld a,(0e128h)		;825c
	dec a			;825f   ; tres o cuatro copias
	add a,(hl)			;8260
	ld (hl),a			;8261
L_8262:
	ld a,(0e128h)		;8262
	call suma_a_a_de		;8265
	djnz cuenta_en_trios_o_cuartetos		;8268
	ret			;826a
cuenta_en_escalera:
	ld a,(de)			;826b
	cp c			;826c
	ret nz			;826d
	inc (hl)			;826e   ; una copia
	ret			;826f

; ----------------------------------------------------------------------
; El dora es el siguiente del indicador: dentro del palo, del nueve vuelve al uno; entre los vientos, del norte (0x34) al este (0x31); entre los dragones, del rojo (0x37) al blanco (0x35).
; ----------------------------------------------------------------------
del_indicador_al_dora:
	cp 030h		;8270
	jr c,L_8284		;8272
	cp 034h		;8274   ; el norte
	jr nz,L_827C		;8276
	ld a,030h		;8278   ; vuelve al este
	jr L_828D		;827a
L_827C:
	cp 037h		;827c   ; el rojo
	jr nz,L_828D		;827e
	ld a,034h		;8280   ; vuelve al blanco
	jr L_828D		;8282
L_8284:
	and 00fh		;8284
	cp 009h		;8286   ; el nueve
	ld a,c			;8288
	jr nz,L_828D		;8289
	and 0f0h		;828b   ; vuelve al uno del palo
L_828D:
	inc a			;828d   ; el siguiente
	ld c,a			;828e
	ret			;828f

; ----------------------------------------------------------------------
; MENZEN TSUMO: mano cerrada y tsumo, salvo que el haitei ya lo lleve dentro (0xE1D0). Indice 16, 1 han.
; ----------------------------------------------------------------------
menzen_tsumo:
	ld a,(0e1d0h)		;8290
	or a			;8293   ; el haitei ya lo cuenta
	ret nz			;8294
	ld a,(0e2b6h)		;8295
	or a			;8298   ; con llamadas no
	ret nz			;8299
	ld a,(0e1d1h)		;829a
	rra			;829d   ; y tsumo
	ret nc			;829e
	ld bc,00110h		;829f   ; 1 han, indice 16
	jr apunta_la_jugada		;82a2

; ----------------------------------------------------------------------
; Las manos de la primera vuelta. Con tsumo: si el OTRO aun no ha descartado (su cuenta en 0xFF), TENHOU (indice 1) si gana el que reparte y CHIIHOU (indice 2) si gana el otro. Con ron: si el que reparte acaba de hacer su primer descarte (cuenta 0) y lo gana el otro, RENHOU, que el cartucho apunta con el indice 2, el mismo del chiihou. Todos yakuman.
; ----------------------------------------------------------------------
tenhou_chiihou_y_renhou:
	ld a,(0e1d1h)		;82a4
	rra			;82a7   ; bit 0 de 0xE1D1: tsumo
	ld a,(0e04dh)		;82a8
	ld c,a			;82ab
	jr nc,L_82BC		;82ac
	rra			;82ae   ; bit 0 de 0xE04D: reparte el 2
	ld a,(0e1bfh)		;82af
	jr nc,L_82B7		;82b2
	ld a,(0e1beh)		;82b4
L_82B7:
	cp 0ffh		;82b7   ; 0xFF: el otro no ha descartado
	ret nz			;82b9
	jr L_82D7		;82ba
L_82BC:
	rra			;82bc
	jr nc,L_82CA		;82bd   ; reparte el 1
	ld a,(0e302h)		;82bf
	bit 1,a		;82c2
	ret nz			;82c4   ; con ron lo gana el que no reparte
	ld a,(0e1bfh)		;82c5
	jr L_82D3		;82c8
L_82CA:
	ld a,(0e302h)		;82ca
	bit 1,a		;82cd
	ret z			;82cf
	ld a,(0e1beh)		;82d0
L_82D3:
	or a			;82d3
	ret nz			;82d4   ; y es el primer descarte del que reparte
	jr L_82E3		;82d5
L_82D7:
	ld a,(0e302h)		;82d7
	rra			;82da
	and 001h		;82db
	xor c			;82dd   ; el ganador contra el que reparte
	ld bc,00001h		;82de   ; tenhou, indice 1
	jr z,apunta_la_jugada		;82e1
L_82E3:
	ld bc,00002h		;82e3   ; chiihou o renhou, indice 2

; ----------------------------------------------------------------------
; APUNTA UNA JUGADA: sube 0xE315, escribe el indice C detras del ultimo (la lista empieza en 0xE305) y suma los B han a 0xE316. Es a donde van a parar todos los detectores.
; ----------------------------------------------------------------------
apunta_la_jugada:
	ld hl,0e315h		;82e6
	inc (hl)			;82e9   ; una jugada mas
	ld a,(hl)			;82ea
	ld hl,0e304h		;82eb   ; 0xE304 + la cuenta: el hueco siguiente de la lista de 0xE305
	call suma_a_a_hl		;82ee
	ld (hl),c			;82f1   ; el indice
	ld hl,0e316h		;82f2
	ld a,(hl)			;82f5
	add a,b			;82f6   ; y los han
	ld (hl),a			;82f7
	ret			;82f8

; ----------------------------------------------------------------------
; Los 19 bytes de 0xE127 a 0xE139 a cero: el borrador con el que cuentan los detectores.
; ----------------------------------------------------------------------
limpia_el_borrador:
	ld hl,0e127h		;82f9
	ld (hl),000h		;82fc
	ld de,0e128h		;82fe
	ld bc,00012h		;8301   ; diecinueve bytes
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
	sub e			;839f   ; el byte bajo
	daa			;83a0   ; daa: la resta tambien es DECIMAL
	ld (hl),a			;83a1
	ld e,a			;83a2
	inc hl			;83a3
	ld a,(hl)			;83a4
	sbc a,d			;83a5   ; el medio, con el acarreo
	daa			;83a6
	ld (hl),a			;83a7
	ld d,a			;83a8
	inc hl			;83a9
	ld a,(hl)			;83aa
	ret nc			;83ab   ; sin acarreo el alto no cambia
	sub 001h		;83ac
	daa			;83ae
	ld (hl),a			;83af
	ret			;83b0

; ----------------------------------------------------------------------
; DATOS fuente_grande: Los 48 patrones de 8x8 de los tiles 0xC0-0xEF:
;   0xC0-0xC9 son los diez digitos, 0xCA es el circulo del copyright, 0xD0 es
;   el guion, 0xD1-0xEA son la A a la Z y el resto son trazos japoneses.
;   0x4472 la copia entera a los colores 0x0600 y 0x448C a los patrones
;   0x2600: el mismo bloque a las dos tablas.
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
; DATOS patrones_del_titulo_500: Formato B desde 0x448F: 432 bytes a los
;   patrones 0x2500.
;   0x85d5..0x86d6  (257 bytes)
DATA_patrones_del_titulo_500:
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
; DATOS patrones_del_final_080: Formato B desde 0x43AA, EN EL ESTADO 13: 264
;   bytes a los patrones 0x2080, los tiles 0x10-0x30 de la pantalla del FINAL:
;   0x10-0x21 son los dos kanji de 24x24 del 終局 (shuukyoku, fin de la partida)
;   que pinta 0x8598, y 0x22-0x30 el marco y las fichas del muro de la caja de
;   0x87B4. CORRIGE el nombre anterior ("del titulo"): se comprobo volcando la
;   VRAM en el estado 14 con tools/omsx_vuelca_vram.tcl; los rotulos de la
;   espera (0x7428) NO salen de aqui sino de los tiles del tercio de abajo.
;   0x86d6..0x8799  (195 bytes)
DATA_patrones_del_final_080:
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
; DATOS colores_del_final_080: Formato B desde 0x43B0: los 264 bytes de
;   colores que hacen pareja con el bloque de arriba, a 0x0080: el dorado del
;   終局 y el rosa del muro.
;   0x8799..0x87b4  (27 bytes)
DATA_colores_del_final_080:
	defb 080h,040h,048h,0b1h,048h,0b1h,030h,0c0h,081h,096h,007h,09fh,008h,096h,008h,09fh	; 8799  .@H.H.0.........
	defb 008h,096h,006h,09fh,00ah,096h,010h,0c0h,008h,030h,000h	; 87a9  .........0.

; ----------------------------------------------------------------------
; DATOS nombres_del_final: Formato B desde 0x43B9: catorce destinos, las filas
;   5 a 18 de la columna 6: LA CAJA del final de la partida, veinte celdas de
;   ancho, con el marco 0x22-0x2F y el interior a 0x30 (verde); el estado 14
;   pinta encima el muro de fichas y el 終局. Antes se llamaba "del titulo" y no
;   lo es: lo pinta el estado 12 (0x43B9), no el titulo.
;   0x87b4..0x8832  (126 bytes)
DATA_nombres_del_final:
	defb 0a6h,078h,081h,022h,012h,026h,081h,023h,080h,0c6h,078h,081h,02eh,012h,030h,081h	; 87b4  .x.".&.#..x...0.
	defb 02fh,080h,0e6h,078h,081h,02eh,012h,030h,081h,02fh,080h,006h,079h,081h,02eh,012h	; 87c4  /..x...0./..y...
	defb 030h,081h,02fh,080h,026h,079h,081h,02eh,012h,030h,081h,02fh,080h,046h,079h,081h	; 87d4  0./.&y...0./.Fy.
	defb 02eh,012h,030h,081h,02fh,080h,066h,079h,081h,02eh,012h,030h,081h,02fh,080h,086h	; 87e4  ..0./.fy...0./..
	defb 079h,081h,02eh,012h,030h,081h,02fh,080h,0a6h,079h,081h,02eh,012h,030h,081h,02fh	; 87f4  y...0./..y...0./
	defb 080h,0c6h,079h,081h,02eh,012h,030h,081h,02fh,080h,0e6h,079h,081h,02eh,012h,030h	; 8804  ..y...0./..y...0
	defb 081h,02fh,080h,006h,07ah,081h,02eh,012h,030h,081h,02fh,080h,026h,07ah,081h,02eh	; 8814  ./..z...0./.&z..
	defb 012h,030h,081h,02fh,080h,046h,07ah,081h,024h,012h,027h,081h,025h,000h	; 8824  .0./.Fz.$.'.%.

; ----------------------------------------------------------------------
; DATOS fuente_katakana: Formato B desde 0x708E: 640 bytes a los patrones
;   0x2180, o sea LOS TILES 0x30-0x7F: LA FUENTE KATAKANA con la que se
;   escriben los nombres de las jugadas. 0x30-0x5D son ア a ン en orden gojuon,
;   0x5E y 0x5F el dakuten y el handakuten como tile aparte, 0x60 el punto,
;   0x61 el alargamiento, 0x63-0x66 las pequenas ッ ャ ュ ョ, y de 0x70 en
;   adelante los trozos de los dos kanji de 3x3 del recuento. Descomprimida en
;   work/fuente_katakana_patrones.bin.
;   0x8832..0x8a78  (582 bytes)
DATA_fuente_katakana:
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
; DATOS colores_de_la_fuente_katakana: Formato B desde 0x7094: 640 bytes a los
;   colores 0x0180, para los tiles 0x30-0x7F. NO son todos iguales, y ahi hay
;   un hallazgo: 0x30-0x66 y 0x70-0x7F van a 0xF1 (blanco sobre negro),
;   0x6A-0x6E a 0xF1 con la ultima fila a 0x00, y los tiles 0x67, 0x68, 0x69 y
;   0x6F -las lineas con las que 0x7376 dibuja la rejilla de cajas de la
;   cabecera del recuento- van a 0x10, que es NEGRO SOBRE TRANSPARENTE: LA
;   REJILLA SE PINTA Y NO SE VE. Medido descomprimiendo el bloque y contra la
;   VRAM del recuento (tools/pantalla.py sobre los volcados). Es lo que habia
;   en work/fuente_katakana.bin, tomado por la fuente.
;   0x8a78..0x8a9f  (39 bytes)
DATA_colores_de_la_fuente_katakana:
	defb 080h,041h,078h,0f1h,078h,0f1h,078h,0f1h,050h,0f1h,018h,010h,007h,0f1h,081h,000h	; 8a78  .Ax.x.x.P.......
	defb 007h,0f1h,081h,000h,007h,0f1h,081h,000h,007h,0f1h,081h,000h,007h,0f1h,081h,000h	; 8a88  ................
	defb 008h,010h,078h,0f1h,008h,0f1h,000h	; 8a98

; ----------------------------------------------------------------------
; DATOS patrones_sueltos_2818: Los 56 bytes que 0x6FCD copia tal cual, sin
;   pasar por ningun interprete, a los patrones 0x2818: los tiles 3 a 9 del
;   segundo tercio.
;   0x8a9f..0x8ad7  (56 bytes)
DATA_patrones_sueltos_2818:
	defb 004h,004h,004h,004h,004h,008h,010h,000h	; 8a9f  ........
	defb 07eh,002h,002h,002h,002h,004h,018h,000h	; 8aa7  ~.......
	defb 000h,03ch,000h,03ch,000h,03ch,002h,000h	; 8aaf  .<.<.<..
	defb 000h,060h,002h,062h,002h,004h,078h,000h	; 8ab7  .`.b..x.
	defb 010h,010h,07eh,012h,014h,010h,010h,000h	; 8abf  ..~.....
	defb 03eh,022h,042h,002h,004h,008h,030h,000h	; 8ac7  >"B...0.
	defb 008h,008h,07eh,008h,008h,010h,020h,000h	; 8acf  ..~... .

; ----------------------------------------------------------------------
; DATOS patrones_del_tablero_900: Formato B desde 0x6FC4: 1792 bytes a los
;   patrones 0x2900.
;   0x8ad7..0x90cf  (1528 bytes)
DATA_patrones_del_tablero_900:
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
; DATOS colores_sueltos_818: Formato B desde 0x6FDC: 56 bytes a los colores
;   0x0818, la pareja del bloque de 0x8A9F.
;   0x90cf..0x90d4  (5 bytes)
DATA_colores_sueltos_818:
	defb 018h,048h,038h,017h,000h	; 90cf

; ----------------------------------------------------------------------
; DATOS colores_del_tablero_900: Formato B desde 0x6FCA: los 1792 bytes de
;   colores de la pareja, a 0x0900.
;   0x90d4..0x92e3  (527 bytes)
DATA_colores_del_tablero_900:
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
; DATOS patrones_sin_comprimir_3020: Los 96 bytes que 0x6FF7 copia tal cual a
;   los patrones 0x3020.
;   0x92e3..0x9343  (96 bytes)
DATA_patrones_sin_comprimir_3020:
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
; DATOS patrones_del_tercio_de_abajo: Formato B. Se lee DOS VECES y de dos
;   maneras: 0x7003 lo pasa entero por 0x468F a los patrones 0x30D0 (1840
;   bytes de salida), y 0x6FDF entra por 0x93AA, 103 bytes mas adelante,
;   saltandose el prologo, para sacar por 0x7883 los 1728 bytes -36 tandas de
;   48- que 0x46B1 vuelca GIRADOS. La diferencia son 112 bytes exactos, y los
;   dos caminos acaban en el mismo 0x99F3.
;   0x9343..0x99f4  (1713 bytes)
DATA_patrones_del_tercio_de_abajo:
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
; DATOS colores_sueltos_020: Formato B desde 0x700C: 96 bytes a los colores
;   0x0020.
;   0x99f4..0x99f9  (5 bytes)
DATA_colores_sueltos_020:
	defb 020h,050h,060h,0f1h,000h	; 99f4

; ----------------------------------------------------------------------
; DATOS colores_del_tercio_de_abajo: Formato B, la pareja del bloque de
;   patrones. 0x700F lo pasa entero a los colores 0x10D0, y 0x6FEB entra por
;   0x9A05 -12 bytes mas adelante- para el mismo volcado girado, esta vez por
;   0x46DC. Otra vez 1840 bytes por un camino y 1728 por el otro, y los dos
;   acaban en 0x9C49.
;   0x99f9..0x9c4a  (593 bytes)
DATA_colores_del_tercio_de_abajo:
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



; ----------------------------------------------------------------------
; LA PUERTA DEL SONIDO: A = el numero de sonido. Con las interrupciones cerradas y los registros a salvo, 0x9C5A lo arranca con D = 0, que es "respetar la prioridad". Lo llaman 31 sitios del cartucho: 0x01 el tecleo del recuento, 0x02 el tintineo de los puntos, 0x05 el cursor, 0x06 el descarte, 0x07 el robo, 0x08 el aviso del reloj, 0x90 la maquina canta, 0x96 el tenpai, 0x9C empezar partida, 0x9F silencio.
; ----------------------------------------------------------------------
pide_un_sonido:
	di			;9c4a
	push hl			;9c4b
	push de			;9c4c
	push bc			;9c4d
	push af			;9c4e
	ld d,000h		;9c4f   ; D = 0: con prioridad
	call arranca_el_sonido		;9c51   ; arranca
	pop af			;9c54
	pop bc			;9c55
	pop de			;9c56
	pop hl			;9c57
	ei			;9c58
	ret			;9c59

; ----------------------------------------------------------------------
; Elige canal y prioridad. Los numeros por debajo de 0x8D son EFECTOS y van a un solo canal, el tercero (0xE026, con su numero en 0xE028), recortados a seis bits; de 0x8D en adelante son MUSICA a tres canales desde el primero (0xE010). Con D = 0 solo entra si su numero es MAYOR que el que suena en ese canal (0xE012 o 0xE028): el numero es la prioridad. De 0xCD en adelante se le quita el bit 7. Luego 0x9C7F busca sus punteros en la tabla de 0x9CA1, dos bytes por sonido, y 0x9C8A carga los canales.
; ----------------------------------------------------------------------
arranca_el_sonido:
	ld c,a			;9c5a
	ld b,002h		;9c5b   ; B = 2, y sube o baja segun
	ld hl,0e012h		;9c5d   ; el numero que suena en el canal 1
	cp 08dh		;9c60   ; por debajo de 0x8D: efecto
	jr c,L_9C6B		;9c62
	cp 08dh		;9c64   ; aqui nunca hay acarreo: sobra
	jr c,L_9C71		;9c66
	inc b			;9c68   ; musica: tres canales
	jr L_9C71		;9c69
L_9C6B:
	and 03fh		;9c6b   ; el efecto, a seis bits
	dec b			;9c6d   ; un solo canal
	ld hl,0e028h		;9c6e   ; el tercero
L_9C71:
	dec d			;9c71   ; D = 1: sin mirar la prioridad
	jr z,L_9C7F		;9c72
	ld a,c			;9c74
	cp (hl)			;9c75   ; el que suena en ese canal
	ret c			;9c76   ; uno mayor: se ignora
	ret z			;9c77   ; el mismo: tambien
	cp 0cdh		;9c78   ; de 0xCD en adelante, sin el bit 7
	jr c,L_9C7F		;9c7a
	and 07fh		;9c7c
	ld c,a			;9c7e
L_9C7F:
	and 03fh		;9c7f   ; seis bits, por dos: la tabla de punteros
	add a,a			;9c81
	ld de,09ca1h		;9c82   ; 0x9CA1, dos bytes por sonido
	call suma_a_a_de		;9c85
	dec hl			;9c88   ; al principio del canal
	dec hl			;9c89

; ----------------------------------------------------------------------
; Por cada canal (B): el contador y la duracion a 1 para que la primera orden se lea ya en el cuadro siguiente, el numero del sonido, el puntero de la tabla, y la unidad de duracion (+10) a cero. Once bytes por canal: +0 contador, +1 duracion, +2 numero (bit 7: musica), +3/+4 puntero, +5 octava, +6 volumen de la nota, +7 volumen que va bajando, +8 contador del volumen, +9 repeticiones, +10 unidad.
; ----------------------------------------------------------------------
carga_los_canales:
	ld (hl),001h		;9c8a   ; contador a 1
	inc hl			;9c8c
	ld (hl),001h		;9c8d   ; duracion a 1
	inc hl			;9c8f
	ld (hl),c			;9c90   ; el numero
	inc hl			;9c91
	ld a,(de)			;9c92   ; el puntero, byte bajo
	ld (hl),a			;9c93
	inc hl			;9c94
	inc de			;9c95
	ld a,(de)			;9c96   ; y alto
	ld (hl),a			;9c97
	ld a,006h		;9c98   ; +10: la unidad, a cero
	add a,l			;9c9a
	ld l,a			;9c9b
	ld (hl),000h		;9c9c
	inc hl			;9c9e   ; y al canal siguiente, con el puntero siguiente
	inc de			;9c9f
	djnz carga_los_canales		;9ca0
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



; ----------------------------------------------------------------------
; La orden 0xFE n: repetir. Lleva la cuenta en +9; cuando llega a n, 0x9F2E apaga el canal. Si no, vuelve a arrancar el mismo sonido (+2) por 0x9C5A con D = 1, sin mirar la prioridad, y guarda la cuenta.
; ----------------------------------------------------------------------
repite_el_sonido:
	inc hl			;9e86
	ld a,(ix+009h)		;9e87   ; las veces que va
	inc a			;9e8a
	cp (hl)			;9e8b   ; ya son las que pide: se acaba
	jp z,apaga_el_canal		;9e8c
	jr c,L_9E92		;9e8f
	dec a			;9e91
L_9E92:
	ex af,af'			;9e92
	ld a,(ix+002h)		;9e93   ; el mismo sonido
	push bc			;9e96
	ld d,001h		;9e97   ; D = 1: sin prioridad
	call arranca_el_sonido		;9e99
	pop bc			;9e9c
	ex af,af'			;9e9d
	ld (ix+009h),a		;9e9e   ; la cuenta, guardada
	ret			;9ea1

; ----------------------------------------------------------------------
; Un `ret` suelto al que llaman 0x9EC3, 0x9F04 y 0x9F34: lo que hubiera aqui se quito y quedaron las llamadas.
; ----------------------------------------------------------------------
no_hace_nada:
	ret			;9ea2

; ----------------------------------------------------------------------
; EL DRIVER, un paso por cuadro desde la interrupcion (0x4075): recorre los tres canales de once bytes desde 0xE010 (IX) con C = 1, 3, 5 -el registro de tono de cada canal- y mueve los que tengan sonido (+2 distinto de cero).
; ----------------------------------------------------------------------
mueve_el_sonido:
	ld c,001h		;9ea3   ; C = 1: el registro de tono del canal 1
	ld ix,0e010h		;9ea5   ; el primer canal
	exx			;9ea9
	ld b,003h		;9eaa   ; tres canales
	ld de,0000bh		;9eac   ; de once bytes
L_9EAF:
	exx			;9eaf
	ld a,(ix+002h)		;9eb0
	or a			;9eb3   ; sin sonido, nada
	call nz,mueve_un_canal		;9eb4
	inc c			;9eb7
	inc c			;9eb8   ; C + 2: el registro del canal siguiente
	exx			;9eb9
	add ix,de		;9eba
	djnz L_9EAF		;9ebc
	ret			;9ebe

; ----------------------------------------------------------------------
; Un canal: con el bit 7 del numero -musica- la nota en curso va por 0x9F3E, con su volumen bajando; si no, baja el contador y, al llegar a cero, 0x9ED1 lee la orden siguiente.
; ----------------------------------------------------------------------
mueve_un_canal:
	bit 6,a		;9ebf
	ld d,001h		;9ec1
	call z,no_hace_nada		;9ec3   ; no hace nada (0x9EA2)
	ld a,(ix+002h)		;9ec6
	or a			;9ec9
	jp m,sigue_la_nota		;9eca   ; bit 7: musica, la nota sigue por 0x9F3E
	dec (ix+000h)		;9ecd   ; el contador
	ret nz			;9ed0   ; aun no

; ----------------------------------------------------------------------
; La orden siguiente del sonido (+3/+4): 0xFE es repetir (0x9E86), 0xFF es el final (0x9F2E); con musica (bit 7) la nota se lee en 0x9F67. Un efecto: 0x2n fija la duracion n, 0x1n manda el ruido n al registro 6 del PSG, y luego 0x9F09 lee el volumen y el periodo.
; ----------------------------------------------------------------------
lee_la_orden_siguiente:
	ld l,(ix+003h)		;9ed1   ; el puntero
	ld h,(ix+004h)		;9ed4
	ld a,(hl)			;9ed7
	cp 0feh		;9ed8   ; 0xFE: repetir
	jr z,repite_el_sonido		;9eda
	jr nc,apaga_el_canal		;9edc   ; 0xFF: se acabo
	bit 7,(ix+002h)		;9ede
	jp nz,lee_una_nota_de_musica		;9ee2   ; musica: la nota, por 0x9F67
	and 0f0h		;9ee5
	cp 020h		;9ee7   ; 0x2n: la duracion
	jr nz,L_9EF2		;9ee9
	ld a,(hl)			;9eeb
	and 00fh		;9eec   ; n
	ld (ix+001h),a		;9eee
	inc hl			;9ef1
L_9EF2:
	ld a,(hl)			;9ef2
	and 0f0h		;9ef3
	cp 010h		;9ef5   ; 0x1n: ruido
	jr nz,lee_un_efecto		;9ef7
	ld a,(hl)			;9ef9
	and 01fh		;9efa   ; n, al registro 6 del PSG
	ld e,a			;9efc
	ld a,006h		;9efd
	call 00093h		;9eff   ; BIOS WRTPSG - Writes data to PSG-register
	ld d,000h		;9f02
	call no_hace_nada		;9f04   ; no hace nada (0x9EA2)
	inc hl			;9f07
	ld a,(hl)			;9f08

; ----------------------------------------------------------------------
; El efecto: nibble alto el VOLUMEN, nibble bajo y el byte siguiente el PERIODO (doce bits), y el puntero avanza dos. 0x9FCE escribe el periodo en el PSG y 0x9F20 arma los contadores y escribe el volumen.
; ----------------------------------------------------------------------
lee_un_efecto:
	and 0f0h		;9f09
	ld b,a			;9f0b   ; el volumen, en B
	xor (hl)			;9f0c
	ld d,a			;9f0d   ; el periodo, byte alto
	inc hl			;9f0e
	ld e,(hl)			;9f0f   ; y bajo
	inc hl			;9f10
	ld (ix+003h),l		;9f11   ; el puntero, avanzado
	ld (ix+004h),h		;9f14
	ex de,hl			;9f17
	call escribe_el_periodo		;9f18   ; el periodo al PSG
	ld a,b			;9f1b
	rrca			;9f1c   ; el volumen, a los cuatro bits bajos
	rrca			;9f1d
	rrca			;9f1e
	rrca			;9f1f

; ----------------------------------------------------------------------
; Con H = volumen: el contador (+0) a la duracion (+1), el contador del volumen (+8) a dos mas, y el volumen al PSG por 0x9F5F.
; ----------------------------------------------------------------------
arma_los_contadores:
	ld h,a			;9f20
	ld a,(ix+001h)		;9f21   ; la duracion
	ld (ix+000h),a		;9f24
	add a,002h		;9f27   ; dos mas para el contador del volumen
	ld (ix+008h),a		;9f29
	jr escribe_el_volumen		;9f2c

; ----------------------------------------------------------------------
; Fin del sonido: repeticiones a cero, numero a cero (canal libre) y volumen cero al PSG.
; ----------------------------------------------------------------------
apaga_el_canal:
	xor a			;9f2e
	ld (ix+009h),a		;9f2f   ; repeticiones a cero
	ld d,001h		;9f32
	call no_hace_nada		;9f34   ; no hace nada (0x9EA2)
	xor a			;9f37
	ld (ix+002h),a		;9f38   ; canal libre
	ld h,a			;9f3b   ; volumen cero
	jr escribe_el_volumen		;9f3c

; ----------------------------------------------------------------------
; La nota de musica en curso: baja el contador y al llegar a cero lee la siguiente. Mientras, el contador del volumen (+8) baja mas deprisa que el de la nota y cuando lo alcanza -o baja de dos- 0x9F56 resta uno al volumen (+7) y lo escribe: es la caida del volumen de cada nota.
; ----------------------------------------------------------------------
sigue_la_nota:
	dec (ix+000h)		;9f3e
	jr z,lee_la_orden_siguiente		;9f41   ; se acabo la nota: la siguiente
	dec (ix+008h)		;9f43
	ld a,(ix+008h)		;9f46
	cp (ix+000h)		;9f49   ; el contador del volumen alcanza al de la nota
	jr nz,L_9F53		;9f4c
	cp 002h		;9f4e   ; por debajo de dos, baja el volumen
	jr c,L_9F56		;9f50
	ret			;9f52
L_9F53:
	dec (ix+008h)		;9f53   ; y si no, baja otro paso
L_9F56:
	ld a,(ix+007h)		;9f56
	dec a			;9f59   ; un paso menos de volumen
	ret m			;9f5a   ; ya en cero: nada
	ld (ix+007h),a		;9f5b
	ld h,a			;9f5e

; ----------------------------------------------------------------------
; H al registro de volumen del canal: 8, 9 o 10, que sale de C (1, 3, 5) por 0x88 + C/2.
; ----------------------------------------------------------------------
escribe_el_volumen:
	ld a,c			;9f5f
	rrca			;9f60
	add a,088h		;9f61   ; 0x88 + C/2: el registro 8, 9 o 10
	ld e,h			;9f63
	jp 00093h		;9f64   ; BIOS WRTPSG - Writes data to PSG-register

; ----------------------------------------------------------------------
; Una nota de musica, con hasta tres prefijos: 0xDn fija la unidad de duracion (+10), 0xFn el volumen de la nota (+6), 0xEn la octava (+5). Luego el byte de la nota: nibble bajo n, duracion (n + 1) por la unidad; nibble alto la nota, 0 a 11 en la tabla de semitonos de 0x9FD9, y 12 es SILENCIO (volumen cero). El periodo de la tabla se dobla tantas veces como diga la octava (0x9FCB) y va al PSG por 0x9FCE.
; ----------------------------------------------------------------------
lee_una_nota_de_musica:
	and 0f0h		;9f67
	cp 0d0h		;9f69   ; 0xDn: la unidad de duracion
	ld a,(hl)			;9f6b
	jr nz,L_9F75		;9f6c
	and 00fh		;9f6e
	ld (ix+00ah),a		;9f70   ; n
	inc hl			;9f73
	ld a,(hl)			;9f74
L_9F75:
	cp 0f0h		;9f75   ; 0xFn: el volumen de la nota
	jr c,L_9F80		;9f77
	and 00fh		;9f79
	ld (ix+006h),a		;9f7b   ; n
	inc hl			;9f7e
	ld a,(hl)			;9f7f
L_9F80:
	cp 0e0h		;9f80   ; 0xEn: la octava
	jr c,L_9F8B		;9f82
	and 00fh		;9f84
	ld (ix+005h),a		;9f86   ; n
	inc hl			;9f89
	ld a,(hl)			;9f8a
L_9F8B:
	and 00fh		;9f8b   ; la duracion: (n + 1) por la unidad
	ld b,a			;9f8d
	ld a,(ix+00ah)		;9f8e
	jr z,L_9F98		;9f91   ; n = 0: la unidad sola
L_9F93:
	add a,(ix+00ah)		;9f93   ; n unidades mas
	djnz L_9F93		;9f96
L_9F98:
	ld (ix+001h),a		;9f98   ; la duracion de la nota
	ld a,(hl)			;9f9b
	inc hl			;9f9c
	ld (ix+003h),l		;9f9d   ; el puntero, avanzado
	ld (ix+004h),h		;9fa0
	and 0f0h		;9fa3   ; la nota, nibble alto
	rrca			;9fa5
	rrca			;9fa6
	rrca			;9fa7
	rrca			;9fa8
	ld b,a			;9fa9
	sub 00ch		;9faa   ; 12: silencio
	ld (ix+007h),a		;9fac   ; volumen cero
	jr z,L_9FB7		;9faf
	ld a,(ix+006h)		;9fb1   ; si no, el volumen de la nota
	ld (ix+007h),a		;9fb4
L_9FB7:
	call arma_los_contadores		;9fb7   ; contadores y volumen
	ld a,b			;9fba
	ld hl,09fd9h		;9fbb   ; el semitono, de la tabla de 0x9FD9
	call suma_a_a_hl		;9fbe
	ld l,(hl)			;9fc1
	ld h,000h		;9fc2
	ld a,(ix+005h)		;9fc4
	or a			;9fc7   ; sin octava, tal cual
	jr z,escribe_el_periodo		;9fc8
	ld b,a			;9fca
L_9FCB:
	add hl,hl			;9fcb   ; doblado por cada octava
	djnz L_9FCB		;9fcc

; ----------------------------------------------------------------------
; HL al par de registros de tono del canal: C (1, 3 o 5) el byte alto y C - 1 el bajo.
; ----------------------------------------------------------------------
escribe_el_periodo:
	ld a,c			;9fce
	ld e,h			;9fcf
	call 00093h		;9fd0   ; BIOS WRTPSG - Writes data to PSG-register | el byte alto del periodo
	ld a,c			;9fd3
	dec a			;9fd4
	ld e,l			;9fd5
	jp 00093h		;9fd6   ; BIOS WRTPSG - Writes data to PSG-register | y el bajo, al registro anterior

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
