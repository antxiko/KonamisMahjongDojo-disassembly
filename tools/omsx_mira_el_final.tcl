# Vuelca la pantalla tal como esta al final del ciclo del demo (estados 12, 13
# y 14), que es JUSTO por donde entra el modo attract del paso 6.
#
# PARA QUE: el attract se engancha en el `jp vuelve_al_estado_0` de 0x43FD, o
# sea al agotarse la cuenta atras del estado 14. Lo primero que hay que saber
# para escribir la primera diapositiva es CON QUE PANTALLA se entra: que tiles
# hay cargados en cada tercio, que fuente se puede usar y que hay pintado.
# Suponerlo seria justo lo que esta prohibido en esta casa.
#
# COMO: se pone un watchpoint de escritura sobre 0xE000 (el estado del juego) y
# en cada cambio a 12, 13 o 14 se vuelca VRAM + registros del VDP + la pagina
# de RAM. El demo tarda unos 162 s de tiempo de maquina en llegar al rotulo
# END; con `throttle off` y `renderer none` son unos pocos segundos de reloj.
#
# Salida: work/vram_final/<n>_e<estado>_s<submodo>.{vram,vdp,ram} y el log
# work/omsx_mira_el_final.log. Los PNG se montan luego con pantalla.py.
#
# Uso:
#   openmsx -machine Philips_VG_8020 -cart mahjong.rom \
#           -script tools/omsx_mira_el_final.tcl

set ::SALIDA "work/vram_final"
set ::NFOTO 0
set ::VISTOS {}
file mkdir $::SALIDA

set L [open "work/omsx_mira_el_final.log" w]
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
        say [format "foto %s" $base]
    } e]} { say "FALLO en la foto $etiqueta: $e" }
}

# El estado cambia DENTRO de la interrupcion. Se hace la foto un pelin despues,
# con `after time`, para que al manejador del estado le haya dado tiempo a
# pintar lo suyo: si se vuelca en el instante de la escritura, la pantalla
# todavia es la del estado anterior.
proc mira_el_estado {} {
    set e [debug read memory 0xE000]
    if {$e >= 12 && $e <= 14 && [lsearch $::VISTOS $e] < 0} {
        lappend ::VISTOS $e
        say "estado $e alcanzado"
        after time 0.6 [list foto "estado"]
    }
    if {[llength $::VISTOS] >= 3} {
        # los tres vistos: una ultima foto ya con la cuenta del 14 avanzada,
        # que es el fotograma exacto en que el attract tomaria el mando
        after time 2.0 {
            foto "antes_de_volver"
            say "listo"
            after time 0.2 exit
        }
    }
}

debug set_watchpoint write_mem 0xE000 {} {mira_el_estado}

# red de seguridad: si en 400 s de maquina no se ha llegado, se sale igual
after time 400 {
    say "TIEMPO AGOTADO: vistos = $::VISTOS"
    exit
}

say "arrancado, esperando a los estados 12-14"
