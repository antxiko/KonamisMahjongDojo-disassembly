# Vuelca la VRAM entera (y los registros del VDP) en los instantes que diga un
# GUION, pulsando teclas por el camino.
#
# PARA QUE: las imagenes de la web son capturas, y una captura hecha a mano no
# se puede repetir. Esto la repite: openMSX arranca el cartucho con `renderer
# none`, el guion dice en que segundo emulado volcar, y tools/pantalla.py monta
# el PNG desde el volcado. El demo se juega solo y es determinista desde el
# encendido, asi que la pasada A no pulsa nada; la B pulsa dos teclas en
# instantes fijos.
#
# EL GUION VA EN UN FICHERO (work/web/guion.txt), porque a un -script de
# openMSX no se le pueden pasar argumentos.
# Una orden por linea, con el instante EMULADO en segundos:
#     12.0  key  0 1      pulsa la tecla de la fila 0, bit 1 (la '1') 0,3 s
#     13.5  vram titulo   vuelca VRAM + VDP + RAM con la etiqueta "titulo"
#     0     auto          ademas, una foto tras cada cambio de estado/submodo
#     0     out  work/web/vramb   directorio de salida
#     #  las lineas con almohadilla se ignoran
# Salida: <dir>/<n>_<etiqueta>_eXX_sYY.{vram,vdp,ram} y
# work/web/omsx_capturas.log
#
# Las trampas ya pagadas y como se esquivan: nada de corchetes dentro de un
# `format`; cada foto envuelta en `catch`; `debug read_block` con el canal en
# binario (no existe save_to_file); el fin del script se programa DESPUES de
# leer el guion, con el ultimo instante mas uno.
#
# Lo lanza tools/capturas_web.py; a mano seria:
#   openmsx -machine Philips_VG_8020 -cart mahjong.rom \
#           -script tools/omsx_capturas_web.tcl

set ::GUION  "work/web/guion.txt"
set ::SALIDA "work/web/vram"
set ::NFOTO 0
file mkdir $::SALIDA

set L [open "work/web/omsx_capturas.log" w]
proc say {m} {
    global L
    puts $L [format "t=%8.2f  %s" [machine_info time] $m]
    flush $L
    puts $m
}

set renderer none
set throttle off

# Los nombres de los depurables, apuntados por si cambian de version.
catch { say "depurables: [debug list]" }

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
        say [format "foto %-24s (VDP regs: %d)" $base $nreg]
    } e]} { say "FALLO en la foto $etiqueta: $e" }
}

proc pulsa {fila bit} {
    set m [expr {1 << $bit}]
    keymatrixdown $fila $m
    after time 0.30 [list keymatrixup $fila $m]
    say "tecla fila $fila bit $bit"
}

set f [open $::GUION r]
set tmax 0
set n 0
while {[gets $f linea] >= 0} {
    set linea [string trim $linea]
    if {$linea eq "" || [string index $linea 0] eq "#"} continue
    set t   [lindex $linea 0]
    set que [lindex $linea 1]
    if {$que eq "key"}  { after time $t [list pulsa [lindex $linea 2] [lindex $linea 3]]; incr n }
    if {$que eq "vram"} { after time $t [list foto [lindex $linea 2]]; incr n }
    if {$que eq "auto"} { set ::AUTO 1; incr n }
    if {$que eq "out"}  { set ::SALIDA [lindex $linea 2]; file mkdir $::SALIDA; incr n }
    if {$t > $tmax} { set tmax $t }
}
close $f
say "guion: $n ordenes, la ultima en t=$tmax"

# `auto`: ademas del guion, una foto un segundo despues de CADA cambio de
# estado (0xE000) o de submodo (0xE001), que es cuando la pantalla nueva ya
# esta pintada. Es lo que hacia omsx_retrata_estados.tcl con los PNG.
if {[info exists ::AUTO]} {
    set ::ultimo(estado)  -1
    set ::ultimo(submodo) -1
    proc cambio {que dir} {
        set v [debug read memory $dir]
        if {$v == $::ultimo($que)} return
        set ::ultimo($que) $v
        if {$que eq "estado"} { set ::ultimo(submodo) [debug read memory 0xE001] }
        after time 1.0 [list foto auto]
    }
    debug set_watchpoint write_mem 0xE000 {} {cambio estado  0xE000}
    debug set_watchpoint write_mem 0xE001 {} {cambio submodo 0xE001}
    say "modo auto: foto en cada cambio de estado o submodo"
}

after time [expr {$tmax + 1}] {
    say "fin"
    after realtime 1 {exit}
}
