# Sonda: averigua COMO se vuelca un trozo de memoria a fichero en este openMSX.
# Se prueban las candidatas y se apunta cual funciona y cual da error, en vez de
# suponerlo. Escribe el resultado en work/omsx_probe_dump.log.

set L [open "work/omsx_probe_dump.log" w]
proc say {m} { global L; puts $L $m; flush $L }

say "version: [openmsx_info version]"

if {[catch {debug list} e]} { say "debug list -> ERROR: $e" } else { say "debuggables: $e" }

# Candidata A: save_to_file con offset y tamano (la que se uso y fallo).
if {[catch {debug save_to_file memory 0xE000 1024 work/_probe_a.bin} e]} {
    say "A) debug save_to_file memory 0xE000 1024 f -> ERROR: $e"
} else { say "A) OK, [file size work/_probe_a.bin] bytes" }

# Candidata B: save_to_file del debuggable entero.
if {[catch {debug save_to_file memory work/_probe_b.bin} e]} {
    say "B) debug save_to_file memory f -> ERROR: $e"
} else { say "B) OK, [file size work/_probe_b.bin] bytes" }

# Candidata C: read_block, que devuelve la tira de bytes para escribirla a mano.
if {[catch {set d [debug read_block memory 0xE000 1024]} e]} {
    say "C) debug read_block -> ERROR: $e"
} else {
    set f [open work/_probe_c.bin w]
    fconfigure $f -translation binary
    puts -nonewline $f $d
    close $f
    say "C) OK, [file size work/_probe_c.bin] bytes"
}

after realtime 1 {exit}
