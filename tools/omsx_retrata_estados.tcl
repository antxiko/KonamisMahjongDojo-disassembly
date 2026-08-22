# Retrata el demo: una captura de pantalla y un volcado de la RAM del juego en
# CADA estado y submodo por los que pasa el cartucho solo.
#
# POR QUE SIN REPLAY: el demo arranca y se desarrolla sin que nadie toque una
# tecla, asi que es determinista desde el encendido. Eso evita de golpe las dos
# trampas del replay apuntadas en medir-en-el-emulador-msx.md (la deriva de
# `reverse goto` + espera, y el replay que relee la cinta). Aqui basta con
# arrancar la ROM y mirar.
#
# COMO SE EVITA LA CAPTURA NEGRA: renderer encendido a mano (con -script arranca
# sin inicializar) y el ACELERADOR PUESTO, que si no el renderer se salta los
# cuadros. Un PNG negro pesa ~1 KB y uno bueno ~10 KB.
#
# LA CAPTURA VA RETRASADA A PROPOSITO: en el instante en que cambia (0xE000) el
# estado nuevo todavia no ha pintado nada, asi que se pide la foto 1,5 s
# emulados despues. Lo que se retrata es el estado ya dibujado.
#
# OJO CON EL FORMATO DE TCL: los corchetes dentro de una cadena son sustitucion
# de comando. Un `format "[%8.2f]"` sin escapar revienta la proc, el script
# aborta antes de registrar el `exit` y openMSX se queda colgado con el log a
# cero bytes y sin decir ni pio. Costo cuatro arranques el 2026-08-22.
#
# Uso:
#   openmsx -machine Philips_VG_8020 -cart mahjong.rom \
#           -script tools/omsx_retrata_estados.tcl

set ::SALIDA work/estados
file mkdir $::SALIDA
file mkdir $::SALIDA/ram

set L [open "work/omsx_retrata_estados.log" w]
proc say {m} { global L; puts $L [format "t=%8.2f  %s" [machine_info time] $m]; flush $L; puts $m }

set renderer SDLGL-PP
set throttle on

set ::ultimo(estado)  -1
set ::ultimo(submodo) -1
set ::n 0

# Retrata: PNG + volcado de 0xE000-0xE3FF (la zona que INIT borra al arrancar,
# o sea toda la memoria de trabajo del juego). Con los volcados se puede luego
# localizar la mano y el marcador comparandolos entre si.
# OJO: en openMSX 21.0 NO existe `debug save_to_file` (comprobado con
# tools/omsx_probe_dump.tcl: las subordenes son read/read_block/write/...).
# Se vuelca con `debug read_block`, que devuelve la tira de bytes, y se escribe
# a mano con el canal en binario -sin `-translation binary` Windows metaria un
# 0x0D delante de cada 0x0A y el volcado saldria corrupto-.
proc vuelca {ruta desde cuantos} {
    set d [debug read_block memory $desde $cuantos]
    set f [open $ruta w]
    fconfigure $f -translation binary
    puts -nonewline $f $d
    close $f
}

proc retrata {etiqueta} {
    set n [format "%03d" [incr ::n]]
    set base [format "%s_e%02d_s%02d_%s" $n $::ultimo(estado) $::ultimo(submodo) $etiqueta]
    set png [file join $::SALIDA "$base.png"]
    screenshot -raw $png
    vuelca [file join $::SALIDA ram "$base.bin"] 0xE000 1024
    say [format "retrato %-28s  %6d bytes" $base [file size $png]]
}

# Envoltorio: un error dentro de `retrata` NO puede llevarse por delante la
# cadena que la llama. Costo la mitad de las fotos de la partida el 2026-08-22:
# `save_to_file` no existia, reventaba despues de la captura, y el latido -que
# se reprograma a si mismo- murio a la primera sin decir nada.
proc retrata_seguro {etiqueta} {
    if {[catch {retrata $etiqueta} e]} { say "FALLO al retratar $etiqueta: $e" }
}

proc cambio {que dir} {
    set v [debug read memory $dir]
    if {$v == $::ultimo($que)} return
    set ::ultimo($que) $v
    # Al cambiar de estado, el submodo se pone a 0 en la misma rutina (0x4204);
    # se apunta aqui para que la etiqueta del retrato salga coherente.
    if {$que eq "estado"} { set ::ultimo(submodo) [debug read memory 0xE001] }
    say [format "%-7s = %3d   (lo escribe PC=0x%04X)" $que $v [reg pc]]
    after time 1.5 [list retrata_seguro $que]
}

debug set_watchpoint write_mem 0xE000 {} {cambio estado  0xE000}
debug set_watchpoint write_mem 0xE001 {} {cambio submodo 0xE001}

# El estado 11 submodo 2 es la mano jugandose y dura ~104 s: sin esto no habria
# ni una foto de la partida en marcha. Un latido cada 10 s emulados la retrata.
# SE REPROGRAMA LO PRIMERO, antes de hacer nada que pueda fallar: asi la cadena
# sobrevive aunque una foto salga mal.
proc latido {} {
    after time 10 latido
    if {$::ultimo(estado) == 11 && $::ultimo(submodo) == 2} { retrata_seguro mano }
}
after time 10 latido

# Un ciclo completo del demo son ~169 s emulados (medido: vuelve al estado 0 en
# t=168,48 y otra vez en t=337,44). Se deja algo mas para ver el cierre.
after time 175 {
    say "fin del ciclo, saliendo"
    after realtime 1 {exit}
}
