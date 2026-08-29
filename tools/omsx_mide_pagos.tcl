# Mide la TABLA DE PAGO del cartucho llamando a la rutina que la lee.
#
# PARA QUE: el manual (docs/reglas_del_cartucho.md) afirma dos cosas que solo
# se habian comprobado a mano leyendo el binario: que 20 fu con 1 han paga
# CERO, y que con tsumo el que paga y el que cobra no se llevan la misma
# cifra. Aqui se hacen medir al propio cartucho: se le pone en la RAM el fu, el
# han, quien gana y si es tsumo, se llama a la rutina de pago y se leen los dos
# pendientes que deja.
#
# COMO: igual que tools/omsx_fuerza_pantallas.tcl -bucle principal en 0x404F,
# semaforo de reentrada 0xE005 a 1 para congelar el juego, PC empujado en la
# pila-. La rutina que se llama es 0x5B22, que es el trozo de
# escribe_las_jugadas_y_paga que va DESPUES del recuento de yakuman:
#   0xE1E1/0xE1E2  los fu en BCD (0x0020 = 20 fu)   -> fila_de_los_fu (0x5C5A)
#   0xE316         los han                          -> entra_en_la_tabla (0x5C70)
#   0xE04E bit 0   0 = gana el que reparte, 1 = el otro
#   0xE1D1 bit 0   1 = tsumo
#   0xE04B         los honba
# y deja en 0xE1B1 lo que paga el perdedor y en 0xE1E4 lo que cobra el ganador,
# los dos en BCD y en centenas (0x0015 = 1.500 puntos).
#
# Salida: work/omsx_mide_pagos.log
#
# Uso:
#   openmsx -machine Philips_VG_8020 -cart mahjong.rom \
#           -script tools/omsx_mide_pagos.tcl

set L [open "work/omsx_mide_pagos.log" w]
proc say {m} {
    global L
    puts $L $m
    flush $L
    puts $m
}

set renderer none
set throttle off

proc pon {dir val} { debug write memory $dir $val }
proc lee16 {dir} {
    return [expr {[debug read memory $dir] | ([debug read memory [expr {$dir + 1}]] << 8)}]
}
# Un BCD de centenas a puntos: 0x0015 -> 1500
proc puntos {bcd} {
    set d 0
    for {set i 3} {$i >= 0} {incr i -1} {
        set d [expr {$d * 10 + (($bcd >> ($i * 4)) & 0xF)}]
    }
    return [expr {$d * 100}]
}

# EL PLAN: cada caso es {tabla fu han tsumo honba}
set ::CASOS {}
foreach tabla {0 1} {
    foreach tsumo {0 1} {
        foreach fu {0x20 0x30 0x40 0x50 0x60 0x70 0x80 0x90 0x100} {
            foreach han {1 2 3 4} {
                lappend ::CASOS [list $tabla $fu $han $tsumo 0]
            }
        }
    }
}
# y unos cuantos con honba, para ver los +300 del ron y los +100 del tsumo
lappend ::CASOS {0 0x30 1 0 1} {0 0x30 1 0 3} {0 0x30 1 1 1} {0 0x30 1 1 3}

# Y LOS PALOS DE RIICHI DE LA MESA (0xE04A). La rutina es 0x5E70 y decide si
# el ganador se los lleva: {etiqueta e302 e04c e04d e1cd e1ae}
#   0xE302  0 = gana el 1, 2 = gana el 2
#   0xE04C  bit 0: ronda del sur     0xE04D  bit 0: reparte el 2
#   0xE1CD  bit 0: el 1 iba en riichi   0xE1AE  bit 0: el 2 iba en riichi
set ::PALOS {
    {gana-1-sin-riichi        0 0 0 0 0}
    {gana-1-con-riichi        0 0 0 1 0}
    {gana-2-sin-riichi        2 0 0 0 0}
    {gana-2-con-riichi        2 0 0 0 1}
    {gana-1-sin-riichi-cierre 0 1 1 0 0}
    {gana-2-sin-riichi-cierre 2 1 1 0 0}
}

proc paso_palos {} {
    if {[llength $::PALOS] == 0} {
        debug write memory 0xE005 0
        say "fin del plan"
        after realtime 1 {exit}
        return
    }
    set c [lindex $::PALOS 0]
    set ::PALOS [lrange $::PALOS 1 end]
    lassign $c etiqueta e302 e04c e04d e1cd e1ae
    set ::PALO $c
    debug write memory 0xE005 1
    pon 0xE002 0x50
    pon 0xE302 $e302
    pon 0xE04C $e04c
    pon 0xE04D $e04d
    pon 0xE1CD $e1cd
    pon 0xE1AE $e1ae
    pon 0xE04A 1
    pon 0xE003 0
    foreach dir {0xE044 0xE045 0xE046 0xE047 0xE048 0xE049} { pon $dir 0 }
    set pc [reg PC]
    set sp [expr {([reg SP] - 2) & 0xFFFF}]
    debug write memory $sp [expr {$pc & 0xFF}]
    debug write memory [expr {($sp + 1) & 0xFFFF}] [expr {($pc >> 8) & 0xFF}]
    reg SP $sp
    reg PC 0x5E70
    set ::BP [debug set_bp 0x404F {} {ha_vuelto_palos}]
}

proc marcador {dir} {
    set t 0
    for {set i 2} {$i >= 0} {incr i -1} {
        set b [debug read memory [expr {$dir + $i}]]
        set t [expr {$t * 100 + (($b >> 4) & 0xF) * 10 + ($b & 0xF)}]
    }
    return $t
}

proc ha_vuelto_palos {} {
    debug remove_bp $::BP
    lassign $::PALO etiqueta
    say [format "palos  %-26s 0xE04A queda en %d   marcador 1 %+d   marcador 2 %+d"              $etiqueta [debug read memory 0xE04A] [marcador 0xE047] [marcador 0xE044]]
    paso_palos
}

proc paso {} {
    if {[llength $::CASOS] == 0} {
        say "--- los palos de riichi (0x5E70) ---"
        paso_palos
        return
    }
    set c [lindex $::CASOS 0]
    set ::CASOS [lrange $::CASOS 1 end]
    lassign $c tabla fu han tsumo honba
    set ::CASO $c

    debug write memory 0xE005 1
    pon 0xE1E1 [expr {$fu & 0xFF}]
    pon 0xE1E2 [expr {($fu >> 8) & 0xFF}]
    pon 0xE316 $han
    pon 0xE04E $tabla
    pon 0xE1D1 $tsumo
    pon 0xE04B $honba
    pon 0xE1B3 0
    pon 0xE1B4 0
    pon 0xE1B1 0 ; pon 0xE1B2 0
    pon 0xE1E4 0 ; pon 0xE1E5 0

    set pc [reg PC]
    set sp [expr {([reg SP] - 2) & 0xFFFF}]
    debug write memory $sp [expr {$pc & 0xFF}]
    debug write memory [expr {($sp + 1) & 0xFFFF}] [expr {($pc >> 8) & 0xFF}]
    reg SP $sp
    reg PC 0x5B22
    set ::BP [debug set_bp 0x404F {} {ha_vuelto}]
}

proc ha_vuelto {} {
    debug remove_bp $::BP
    lassign $::CASO tabla fu han tsumo honba
    set paga  [lee16 0xE1B1]
    set cobra [lee16 0xE1E4]
    say [format "%-8s fu %3d  han %d  %-5s honba %d   paga %6d   cobra %6d   (bcd %04X / %04X)" \
             [expr {$tabla == 0 ? "reparte" : "el otro"}] \
             [expr {(($fu >> 8) & 0xFF) * 100 + ((($fu >> 4) & 0xF) * 10) + ($fu & 0xF)}] $han \
             [expr {$tsumo ? "tsumo" : "ron"}] $honba \
             [puntos $paga] [puntos $cobra] $paga $cobra]
    paso
}

proc en_el_bucle {} {
    debug remove_bp $::BP0
    say "empieza la medida"
    paso
}

# Con el titulo ya montado sobra: la rutina no depende de la pantalla.
after time 8.0 {
    say "tablas: 0x5C97 (gana el que reparte), 0x5CA9 (gana el otro), 0x5D83 (al robar)"
    set ::BP0 [debug set_bp 0x404F {} {en_el_bucle}]
}
after time 120.0 {say "fin por tiempo"; after realtime 1 {exit}}
