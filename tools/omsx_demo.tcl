# Comprueba si hay modo attract/demo: arranca el cartucho y NO TOCA NADA,
# solo va capturando la pantalla a intervalos. Si el titulo cambia solo -pasa
# a una partida de ejemplo, a un menu distinto, a otra pantalla- hay demo.
#
# Uso:
#   openmsx -machine Philips_VG_8020 -cart mahjong.rom -script tools/omsx_demo.tcl

set SALIDA work/gfx
file mkdir $SALIDA
set L [open "work/omsx_demo.log" w]
proc say {m} { global L; puts $L [format "\[%8.2f\] %s" [machine_info time] $m]; flush $L; puts $m }

set renderer SDLGL-PP
set throttle on

proc captura {nombre} {
    global SALIDA
    set f [file join $SALIDA $nombre]
    screenshot -raw $f
    set n [file size $f]
    say [format "%-24s %6d bytes" $nombre $n]
}

# Sin pulsar ninguna tecla en ningun momento: si algo cambia, es el juego solo.
proc paso {n tope} {
    captura [format "demo_%02d.png" $n]
    if {$n >= $tope} {
        say "fin de la sonda, saliendo"
        after realtime 1 {exit}
        return
    }
    after realtime 5 [list paso [expr {$n + 1}] $tope]
}

say "arrancando la sonda: 16 capturas cada 5 s (80 s reales)"
after realtime 2 {paso 0 15}
