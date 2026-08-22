# Identifica QUE estados recorre el demo/attract, reproduciendo el replay
# grabado por omsx_graba_demo.tcl.
#
# El despachador de 0x40ED usa (0xE000) como indice -el estado del juego- y las
# otras cuatro tablas usan (0xE001) -el submodo dentro del estado-. Aqui se
# vigilan los dos con watchpoints de escritura y se apunta CADA CAMBIO con su
# instante y el PC que lo escribio.
#
# DEDUPLICADO A PROPOSITO: un watchpoint de escritura dispara en cada escritura
# aunque el valor no cambie, y estas variables se reescriben cada cuadro. Solo
# se apunta cuando el valor es DISTINTO del ultimo apuntado; asi el log es la
# SECUENCIA de estados por la que pasa el demo, que es lo que se busca.
#
# OJO CON EL FORMATO: los corchetes dentro de una cadena de Tcl son sustitucion
# de comando. Un `format "[%8.2f]"` sin escapar revienta la proc en su primera
# llamada, el script aborta antes de registrar el `exit`, y openMSX se queda
# COLGADO con el log a cero bytes y sin ningun mensaje de error. Costo cuatro
# arranques el 2026-08-22. Por eso aqui el formato no lleva corchetes.
#
# Uso:
#   openmsx -machine Philips_VG_8020 -cart mahjong.rom \
#           -script tools/omsx_estado_demo.tcl

set L [open "work/omsx_estado_demo.log" w]
proc say {m} { global L; puts $L [format "t=%8.2f  %s" [machine_info time] $m]; flush $L; puts $m }

set renderer SDLGL-PP
set throttle off

# Ultimo valor apuntado de cada variable, para no repetir.
set ::ultimo(estado)  -1
set ::ultimo(submodo) -1

proc cambio {que dir} {
    set v [debug read memory $dir]
    if {$v == $::ultimo($que)} return
    set ::ultimo($que) $v
    say [format "%-7s = %3d   (lo escribe PC=0x%04X)" $que $v [reg pc]]
}

if {[catch {reverse loadreplay -viewonly [file normalize "work/replays/demo.omr"]} e]} {
    say "ERROR en loadreplay: $e"
    after realtime 1 {exit}
    return
}
say "replay cargado; vigilando 0xE000 (estado) y 0xE001 (submodo)"

debug set_watchpoint write_mem 0xE000 {} {cambio estado  0xE000}
debug set_watchpoint write_mem 0xE001 {} {cambio submodo 0xE001}

# La ventana entera del replay son 150 s emulados.
after time 148 {
    say "fin de la ventana"
    after realtime 1 {exit}
}
