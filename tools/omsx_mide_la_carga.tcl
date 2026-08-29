# Cuanto tarda el attract en cargar los tiles que le faltan.
#
# PARA QUE: cargar los honores, los circulos y el dorso y repartirlos a los
# tres tercios se hace DENTRO de la interrupcion, y el estado 14 sigue
# contando por debajo. Si la carga tardase mas que la cuenta atras, el propio
# estado 14 volveria a llamar al attract desde dentro de la carga. Esto mide
# lo que tarda de verdad, en segundos de maquina, en vez de suponerlo.
#
# Uso:
#   openmsx -machine Philips_VG_8020 -cart work/mahjong_en.rom \
#           -script tools/omsx_mide_la_carga.tcl
#
# Las direcciones salen de work/mahjong_en.sym (pasmo), no se escriben a mano.

set ::L [open "work/omsx_mide_la_carga.log" w]
proc say {m} {
    puts $::L [format "t=%9.3f  %s" [machine_info time] $m]
    flush $::L
    puts $m
}

set renderer none
set throttle off

set ::ENTRA 0
set ::VUELTAS 0

# entrada de attract_carga_los_tiles
debug set_bp 0xB8CC {} {
    set ::ENTRA [machine_info time]
    say "entra en attract_carga_los_tiles"
}

# attract_limpia, lo primero que se hace al volver de la carga
debug set_bp 0xB8E7 {} {
    if {$::ENTRA != 0} {
        say [format "sale de la carga: %.3f s de maquina" \
                 [expr {[machine_info time] - $::ENTRA}]]
        set ::ENTRA 0
        incr ::VUELTAS
        if {$::VUELTAS >= 1} {
            say "medido"
            exit 0
        }
    }
}

after time 400 {say "se acabo el tiempo sin llegar a la carga"; exit 1}
