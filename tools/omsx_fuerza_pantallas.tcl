# Fuerza las pantallas del parche que el demo NO ensena nunca, y las vuelca.
#
# PARA QUE: el paso 4 tiene traducidos rotulos que solo salen en situaciones
# que la partida grabada no provoca -la caja de mensajes con TSUMO o con NOT
# ALLOWED, los tres avisos de furiten, el chombo y el cartel de la mano nula-.
# Esperar a que salgan solas no vale; aqui se llaman las rutinas que los
# pintan, a pelo, con la mesa ya en pantalla.
#
# COMO, y por que asi:
#   1. El juego vive DENTRO de la interrupcion: el programa principal es un
#      `ei / jr $` en 0x404F y no hace nada mas. Ese bucle es el sitio seguro
#      para meter una llamada, porque no estamos dentro de la rutina de
#      interrupcion ni a medio pintar nada.
#   2. Antes de llamar se LEVANTA EL SEMAFORO DE REENTRADA (0xE005 = 1). La
#      interrupcion lo mira en 0x407B y, si esta puesto, se va por 0x408C sin
#      leer mandos ni mover la maquina de estados: el juego queda congelado y
#      el dibujo forzado no lo pisa nadie. Al terminar se baja y sigue.
#   3. La llamada se hace empujando el PC actual en la pila y saltando a la
#      rutina: cuando haga `ret` vuelve al bucle. Un breakpoint en 0x404F
#      avisa de que ya ha vuelto, y ahi se hace la foto.
#
# Las tres rutinas que se usan, todas del cartucho:
#   0x476F  pinta_uno_de_los_tres_dibujos  (A = 0, 1 o 2)  la caja de mensajes
#   0x409D  el interprete de FORMATO A que PINTA           (HL = la lista)
#   0x468F  el interprete de FORMATO B                     (HL = la lista)
#
# Salida: work/vram_forzado/<n>_<etiqueta>_eXX_sYY.{vram,vdp,ram} y el log
# work/omsx_fuerza_pantallas.log. Los PNG se montan luego con pantalla.py.
#
# Uso:
#   openmsx -machine Philips_VG_8020 -cart work/mahjong_en.rom \
#           -script tools/omsx_fuerza_pantallas.tcl

set ::SALIDA "work/vram_forzado"
set ::NFOTO 0
file mkdir $::SALIDA

set L [open "work/omsx_fuerza_pantallas.log" w]
proc say {m} {
    global L
    puts $L [format "t=%8.2f  %s" [machine_info time] $m]
    flush $L
    puts $m
}

set renderer none
set throttle off

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
        say [format "foto %s" $base]
    } e]} { say "FALLO en la foto $etiqueta: $e" }
}

# EL PLAN. Cada linea: etiqueta rutina HL A.
# El orden importa en dos sitios: el aviso de la fila 11 se deja puesto para
# que PENALTY HAND salga debajo, como sale en el juego; y el cartel de la mano
# nula va el ultimo porque tapa media mesa.
set ::PLAN {
    {mesa_tal_cual        0      0      0}
    {caja_call_tsumo      0x476F 0      0}
    {caja_not_allowed     0x476F 0      2}
    {caja_call_kan        0x476F 0      1}
    {aviso_furiten        0x409D 0x7865 0}
    {aviso_missed_ron     0x409D 0x786F 0}
    {aviso_no_yaku        0x409D 0x7879 0}
    {penalty_hand         0x409D 0x785B 0}
    {draw_game            0x468F @0x76AB 0}
}

# Un HL escrito @0xXXXX no es una direccion sino DONDE ESTA la direccion: se lee
# la palabra que hay ahi. Hace falta para el cartel de la mano nula, que el
# parche saca de su hueco y aparca en la zona libre; leyendo el operando del
# `ld hl` que lo carga (0x76AB) el guion sigue valiendo se mueva donde se mueva.
proc dame_hl {spec} {
    if {[string index $spec 0] eq "@"} {
        set d [expr {[string range $spec 1 end]}]
        return [expr {[debug read memory $d] | ([debug read memory [expr {$d + 1}]] << 8)}]
    }
    return [expr {$spec}]
}

proc paso {} {
    if {[llength $::PLAN] == 0} {
        debug write memory 0xE005 0
        say "plan terminado: semaforo abajo, el juego sigue"
        after time 0.5 mira_el_final
        return
    }
    set e [lindex $::PLAN 0]
    set ::PLAN [lrange $::PLAN 1 end]
    set etiqueta [lindex $e 0]
    set rutina   [expr {[lindex $e 1]}]
    set hl       [dame_hl [lindex $e 2]]
    set a        [expr {[lindex $e 3]}]

    debug write memory 0xE005 1

    if {$rutina == 0} {
        # nada que forzar: solo la foto de como esta la pantalla
        foto $etiqueta
        paso
        return
    }
    set pc [reg PC]
    set sp [expr {([reg SP] - 2) & 0xFFFF}]
    debug write memory $sp [expr {$pc & 0xFF}]
    debug write memory [expr {($sp + 1) & 0xFFFF}] [expr {($pc >> 8) & 0xFF}]
    reg SP $sp
    reg HL $hl
    reg A  $a
    reg PC $rutina
    set ::ETIQ $etiqueta
    set ::BP [debug set_bp 0x404F {} {ha_vuelto}]
    say [format "forzando %-18s rutina 0x%04X  hl 0x%04X  a %d  (vuelve a 0x%04X)" \
             $etiqueta $rutina $hl $a $pc]
}

proc ha_vuelto {} {
    debug remove_bp $::BP
    foto $::ETIQ
    paso
}

# El bucle principal es el sitio seguro: aqui el juego no esta pintando nada.
proc en_el_bucle {} {
    debug remove_bp $::BP0
    paso
}

# Espera a que la mesa este montada del todo (estado 11, submodo 2: el demo
# jugando) antes de tocar nada.
proc espera_la_mesa {} {
    set e0 [debug read memory 0xE000]
    set e1 [debug read memory 0xE001]
    if {$e0 == 11 && $e1 >= 2} {
        say "mesa lista: estado $e0 submodo $e1"
        set ::BP0 [debug set_bp 0x404F {} {en_el_bucle}]
        return
    }
    after time 0.5 espera_la_mesa
}

# Y el rotulo del final: el estado 13 lo pinta en un solo fotograma y el 14 lo
# deja en pantalla unos siete segundos. Aqui no hay que forzar nada, el demo
# llega solo; basta con esperar al estado 14 y hacer la foto.
set ::HECHO_FINAL 0
proc mira_el_final {} {
    if {$::HECHO_FINAL} return
    if {[debug read memory 0xE000] == 14} {
        set ::HECHO_FINAL 1
        after time 2.0 {foto final_end}
        after time 4.0 {foto final_end}
        after time 5.0 {say "fin"; after realtime 1 {exit}}
        return
    }
    after time 0.5 mira_el_final
}

after time 22.0 espera_la_mesa
# red de seguridad: si algo se atasca, se sale igual
after time 400.0 {say "fin por tiempo"; after realtime 1 {exit}}
