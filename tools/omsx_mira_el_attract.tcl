# Retrata el MODO ATTRACT del paso 6 corriendo en su sitio.
#
# PARA QUE: el attract se engancha al final del estado 14, o sea al cerrarse el
# ciclo del demo. La unica prueba que vale es verlo salir SOLO, en su momento,
# sin forzar nada: que aparezca cada diapositiva, que pase a la siguiente y que
# al acabarse vuelva al estado 0 y el demo siga como si nada.
#
# COMO: un watchpoint sobre 0xE001 -que durante el estado 14 es el contador de
# diapositiva- dispara una foto por cada una. El attract recarga 0xE004 y hace
# `ret`, asi que el juego sigue en el estado 14 y el watchpoint vuelve a saltar
# a la diapositiva siguiente. Otro watchpoint sobre 0xE000 avisa de la vuelta
# al estado 0, que es la prueba de que el ciclo no se ha roto.
#
# La foto se toma un poco DESPUES de la escritura: el attract incrementa el
# contador antes de pintar, asi que en el instante del watchpoint la pantalla
# todavia esta en negro.
#
# Salida: work/vram_attract/<n>_diapo<k>.{vram,vdp,ram} y el log
# work/omsx_mira_el_attract.log.
#
# Uso:
#   openmsx -machine Philips_VG_8020 -cart work/mahjong_en.rom \
#           -script tools/omsx_mira_el_attract.tcl

set ::SALIDA "work/vram_attract"
set ::NFOTO 0
set ::VUELTAS 0
file mkdir $::SALIDA

set L [open "work/omsx_mira_el_attract.log" w]
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
        set base [format "%03d_%s_e%02d_s%02d" [incr ::NFOTO] $etiqueta $e0 $e1]
        vuelca [file join $::SALIDA "$base.vram"] VRAM 0 16384
        set nreg [debug size "VDP regs"]
        vuelca [file join $::SALIDA "$base.vdp"] "VDP regs" 0 $nreg
        vuelca [file join $::SALIDA "$base.ram"] memory 0xE000 1024
        say "foto $base"
    } e]} { say "FALLO en la foto $etiqueta: $e" }
}

# Solo interesa el submodo mientras el estado sea 14: en el resto de la partida
# 0xE001 es un submodo de verdad y cambia constantemente.
proc mira_el_submodo {} {
    if {[debug read memory 0xE000] != 14} { return }
    set k [debug read memory 0xE001]
    say "attract: diapositiva $k"
    after time 0.4 [list foto "diapo$k"]
}

# El estado 0 tambien se escribe al ARRANCAR el cartucho, asi que la vuelta
# solo cuenta si antes se ha visto alguna diapositiva.
proc mira_el_estado {} {
    set e [debug read memory 0xE000]
    if {$e == 0 && $::NFOTO > 0} {
        incr ::VUELTAS
        say "vuelta al estado 0: el ciclo del demo sigue despues del attract"
        after time 1.0 {
            say "listo: el attract salio entero y el demo continuo"
            exit
        }
    }
}

debug set_watchpoint write_mem 0xE001 {} {mira_el_submodo}
debug set_watchpoint write_mem 0xE000 {} {mira_el_estado}

after time 400 {
    say "TIEMPO AGOTADO: fotos = $::NFOTO, vueltas = $::VUELTAS"
    exit
}

say "arrancado, esperando al final del ciclo del demo"
