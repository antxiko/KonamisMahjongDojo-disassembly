# ¿La partida del demo es LA MISMA en cada vuelta del ciclo?
#
# PARA QUE: el modo attract sale justo detras del demo, asi que el tutorial
# puede comentar la mano que el jugador acaba de ver. Pero eso solo vale si la
# mano es siempre la misma: si el cartucho sortea otra en la segunda vuelta,
# cualquier cifra que se escriba en el tutorial es falsa a partir de ahi.
# El paso 2 midio que dos ARRANCADAS EN FRIO dan trazas identicas; lo que aqui
# se mide es otra cosa: dos VUELTAS SEGUIDAS del mismo encendido.
#
# COMO: el recuento es el estado 11 submodo 7 (0x421D, novena tabla). Cada vez
# que se entra ahi se vuelca 0xE000-0xE3FF entero y se anotan los marcadores
# (0xE044 el jugador 2, 0xE047 el 1; BCD de tres bytes, byte bajo primero) y
# los dos bits de tsumo (0xE1D1 y 0xE22A). Se dejan correr DOS vueltas y se
# comparan los volcados byte a byte.
#
# Salida: work/vram_demo/recuento_<n>.ram y work/omsx_repite_la_demo.log
#
# Uso:
#   openmsx -machine Philips_VG_8020 -cart work/mahjong_en.rom \
#           -script tools/omsx_repite_la_demo.tcl

set ::SALIDA "work/vram_demo"
set ::N 0
file mkdir $::SALIDA

set ::L [open "work/omsx_repite_la_demo.log" w]
proc say {m} {
    puts $::L [format "t=%9.3f  %s" [machine_info time] $m]
    flush $::L
    puts $m
}

set renderer none
set throttle off

# Un marcador: tres bytes BCD, byte bajo primero, en decimal.
proc bcd3 {dir} {
    set n 0
    for {set k 2} {$k >= 0} {incr k -1} {
        set b [debug read memory [expr {$dir + $k}]]
        set n [expr {$n * 100 + (($b >> 4) * 10) + ($b & 15)}]
    }
    return $n
}

proc vuelca {ruta desde cuantos} {
    set d [debug read_block memory $desde $cuantos]
    set f [open $ruta w]
    fconfigure $f -translation binary
    puts -nonewline $f $d
    close $f
}

proc mira {} {
    if {[debug read memory 0xE000] != 11} { return }
    if {[debug read memory 0xE001] != 7} { return }
    incr ::N
    vuelca [file join $::SALIDA "recuento_$::N.ram"] 0xE000 1024
    say [format "recuento %d: marcador 1 = %d, marcador 2 = %d, tsumo1 = %02X, tsumo2 = %02X, ronda = %02X" \
             $::N [bcd3 0xE047] [bcd3 0xE044] \
             [debug read memory 0xE1D1] [debug read memory 0xE22A] \
             [debug read memory 0xE04D]]
    if {$::N >= 2} {
        say "dos recuentos volcados"
        after time 1.0 {exit 0}
    }
}

debug set_watchpoint write_mem 0xE001 {} {mira}

after time 420 {
    say "TIEMPO AGOTADO: recuentos vistos = $::N"
    exit 1
}
