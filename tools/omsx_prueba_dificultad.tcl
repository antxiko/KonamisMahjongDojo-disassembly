# ¿SE PIERDE LA DIFICULTAD QUE ELIGE EL JUGADOR?
#
# Leyendo el listado, 0x4ABC guarda en 0xE002 el valor de la tecla pulsada
# (0x40 con la 1, 0x60 con la 2, 0x50 con la 3) y salta al estado 8, que es la
# pantalla de dificultad. Al agotarse esa pantalla, 0x4400 escribe 0x50 en
# 0xE002 SIN mirar lo que habia. Si eso es lo que pasa de verdad, las tres
# teclas acaban jugando la misma dificultad.
#
# No se deduce del listado: se mide. Se arranca en frio, se pulsa UNA tecla y
# se apunta 0xE002 y 0xE040 (la dificultad ya convertida, que es lo que lee el
# estado 11) antes y despues de la pantalla.
#
# Las trampas ya conocidas y como se esquivan aqui:
#   - nada de corchetes dentro de un `format`: cuelgan el emulador en silencio;
#   - la cadena que se reprograma lo hace LO PRIMERO y con `catch` alrededor;
#   - se lee la RAM con lecturas sincronas, sin esperas de por medio.
#
# Uso:
#   echo 1 > work/tecla.txt
#   openmsx -machine Philips_VG_8020 -cart mahjong.rom \
#           -script tools/omsx_prueba_dificultad.tcl
#
# LA TECLA VA EN UN FICHERO, y no por los dos caminos que parecen mas
# naturales y NO funcionan:
#   - detras del -script: openMSX se lo come como si fuera otro fichero que
#     cargar, aborta la linea de ordenes y sale con 1 sin escribir nada;
#   - en $::argv o en una variable de entorno: openMSX no las rellena, el
#     script se queda con el valor por defecto y NO protesta. Se caza mirando
#     QUE log se acaba de escribir; el codigo de salida es 0 igual.

set TECLA 1
catch {
    set f [open "work/tecla.txt" r]
    set TECLA [string trim [read $f]]
    close $f
}

set L [open "work/omsx_prueba_dificultad_$TECLA.log" w]
proc say {m} {
    global L
    puts $L [format "t=%8.2f  %s" [machine_info time] $m]
    flush $L
    puts $m
}

set renderer none
set throttle off

say "prueba con la tecla $TECLA"

# La fila 0 de la matriz son las teclas 0 a 7; el bit 1 es la tecla '1'.
proc pulsa {tecla} {
    set bit [expr {1 << $tecla}]
    keymatrixdown 0 $bit
    after time 0.30 [list keymatrixup 0 $bit]
}

proc mira {etiqueta} {
    set e0   [debug read memory 0xE000]
    set e1   [debug read memory 0xE001]
    set e2   [debug read memory 0xE002]
    set e40  [debug read memory 0xE040]
    set e1bb [debug read memory 0xE1BB]
    set e33d [debug read memory 0xE33D]
    say [format "%-14s estado=%2d submodo=%2d  0xE002=0x%02X  0xE040=0x%02X  0xE1BB=%3d  0xE33D=%3d" \
             $etiqueta $e0 $e1 $e2 $e40 $e1bb $e33d]
}

# Muestreo continuo: reprograma PRIMERO, trabaja despues y dentro de un catch.
set ::vueltas 0
proc latido {} {
    incr ::vueltas
    if {$::vueltas < 200} { after time 0.25 latido }
    if {[catch {
        set e0  [debug read memory 0xE000]
        set e2  [debug read memory 0xE002]
        set e40 [debug read memory 0xE040]
        set e1bb [debug read memory 0xE1BB]
        set clave "$e0/$e2/$e40/$e1bb"
        if {![info exists ::ultimo] || $clave ne $::ultimo} {
            set ::ultimo $clave
            mira "cambio"
        }
    } err]} { say "FALLO en el latido: $err" }
}

# El demo tarda unos segundos en arrancar; se pulsa con el titulo ya puesto.
after time 12 {
    mira "antes"
    pulsa $::TECLA
    say "pulsada la tecla $::TECLA"
    latido
}

after time 45 {
    mira "al final"
    say "fin"
    exit
}
