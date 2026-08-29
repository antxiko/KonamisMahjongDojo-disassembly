# Comprueba que el modo attract SE ABANDONA al pulsar una tecla.
#
# PARA QUE: el diseno del paso 6 afirma que el attract es interrumpible sin
# escribir una linea para ello, porque el estado 14 ya ha apagado el bit 6 de
# 0xE002 antes de llamarnos y eso deja viva la puerta del teclado
# (`arranca_la_partida`, 0x4ABC), que escribe 8 y 0 de una tacada en
# 0xE000/0xE001. Es una afirmacion sobre el comportamiento, asi que hay que
# MEDIRLA: se pulsa una tecla a mitad del pase y se mira que pasa.
#
# COMO: se espera a que el attract este pintando (estado 14 con el submodo ya
# por encima de 1, o sea con un par de diapositivas vistas) y entonces se
# mantiene pulsada la tecla 1 unos fotogramas. Si el diseno es bueno, el juego
# tiene que saltar al estado 8 -que es el arranque de la partida- y NO volver
# a la diapositiva siguiente.
#
# Salida: work/omsx_corta_el_attract.log y una foto de como queda la pantalla.
#
# Uso:
#   openmsx -machine Philips_VG_8020 -cart work/mahjong_en.rom \
#           -script tools/omsx_corta_el_attract.tcl

set ::SALIDA "work/vram_corte"
set ::PULSADO 0
set ::LISTO 0
file mkdir $::SALIDA

set L [open "work/omsx_corta_el_attract.log" w]
proc say {m} {
    global L
    puts $L [format "t=%8.2f  %s" [machine_info time] $m]
    flush $L
    puts $m
}

set renderer none
set throttle off

proc vuelca {ruta dbg desde cuantos} {
    set d [debug read_block $dbg $desde $cuantos]
    set f [open $ruta w]
    fconfigure $f -translation binary
    puts -nonewline $f $d
    close $f
}

proc foto {etiqueta} {
    if {[catch {
        set e0 [debug read memory 0xE000]
        set e1 [debug read memory 0xE001]
        set base [format "%s_e%02d_s%02d" $etiqueta $e0 $e1]
        vuelca [file join $::SALIDA "$base.vram"] VRAM 0 16384
        set nreg [debug size "VDP regs"]
        vuelca [file join $::SALIDA "$base.vdp"] "VDP regs" 0 $nreg
        say "foto $base"
    } e]} { say "FALLO en la foto $etiqueta: $e" }
}

proc mira {} {
    set e0 [debug read memory 0xE000]
    set e1 [debug read memory 0xE001]

    if {!$::PULSADO && $e0 == 14 && $e1 >= 2} {
        set ::PULSADO 1
        say "el attract va por la diapositiva $e1: se pulsa la tecla 1"
        foto "antes_de_pulsar"
        # la tecla 1 esta en la fila 0 de la matriz, bit 1
        type_via_keyboard "1"
        return
    }
    if {$::PULSADO && !$::LISTO && $e0 == 8} {
        set ::LISTO 1
        say "ESTADO 8: la tecla corto el attract y arranco la partida"
        after time 2.0 {
            foto "ya_en_partida"
            say "estado al final: [debug read memory 0xE000]"
            after time 0.2 exit
        }
    }
}

debug set_watchpoint write_mem 0xE000 {} {mira}
debug set_watchpoint write_mem 0xE001 {} {mira}

after time 400 {
    say "TIEMPO AGOTADO: pulsado=$::PULSADO listo=$::LISTO"
    say "estado 0xE000 = [debug read memory 0xE000]"
    exit
}

say "arrancado, esperando a que el attract este a mitad de pase"
