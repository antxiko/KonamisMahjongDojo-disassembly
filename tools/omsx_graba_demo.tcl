# Graba un replay del demo/attract entero, sin tocar ninguna tecla.
#
# El titulo tarda ~12 s en aparecer y el demo arranca solo entre el s 12 y
# el 22 (comprobado con omsx_demo.tcl, 2026-08-22). Se deja correr 150 s
# reales -de sobra para una mano completa con su resultado- y se vuelca el
# replay para poder revisarlo luego con reverse goto / reverse loadreplay.
#
# Uso:
#   openmsx -machine Philips_VG_8020 -cart mahjong.rom -script tools/omsx_graba_demo.tcl

set L [open "work/omsx_graba_demo.log" w]
proc say {m} { global L; puts $L [format "\[%8.2f\] %s" [machine_info time] $m]; flush $L; puts $m }

set renderer SDLGL-PP
set throttle on

reverse start
say "grabando, reverse arrancado"

proc fin {} {
    global
    file mkdir work/replays
    reverse savereplay work/replays/demo.omr
    say "replay guardado en work/replays/demo.omr"
    after realtime 1 {exit}
}

after realtime 150 fin
