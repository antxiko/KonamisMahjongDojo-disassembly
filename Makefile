# Konami's Mahjong (Konami, RC-707, 1984) - desensamblado
#
# El orden de las cosas: trazar el flujo -> generar el listado -> comprobar que
# vuelve a dar la ROM byte a byte -> las comprobaciones que el reensamblado NO
# cubre.
#
# La ROM no se distribuye. Hace falta en la raiz como mahjong.rom, y
# `make comprueba` verifica el sha256.

ROM      = mahjong.rom
SHA      = 24cb5bda5f55dcd5ab1343fb61ebac67e8c292f9714ee7a492431e33188b9b40
SRC      = src
WORK     = work
ORG      = 0x4000
TITULO   = KONAMI'S MAHJONG - Konami - MSX1 - cartucho RC-707 de 32 KB en las paginas 1 y 2

all: listado notas verify sanity parche test

$(ROM):
	@echo "=================================================================="
	@echo " Falta $(ROM), y este repositorio NO lo distribuye."
	@echo ""
	@echo " Es Konami's Mahjong (Konami, RC-707) para MSX, 32768 bytes exactos."
	@echo " Ponlo aqui con ese nombre. Para comprobar que es el mismo:"
	@echo "     shasum -a 256 $(ROM)"
	@echo "     $(SHA)"
	@echo ""
	@echo " Sin el se puede leer el listado ya generado en $(SRC)/, y los"
	@echo " tests que no dependen del binario siguen pasando."
	@echo "=================================================================="
	@false

comprueba: $(ROM)
	@echo "$(SHA)  $(ROM)" | shasum -a 256 -c -

# El trazado sigue el flujo desde los puntos de entrada. Los que no se pueden
# deducir estaticamente -ganchos de interrupcion, destinos de saltos
# indirectos- estan declarados en el .entries, cada uno con su justificacion.
$(WORK)/mahjong.trace.json: $(ROM) $(SRC)/mahjong.entries $(SRC)/mahjong.nocode
	@mkdir -p $(WORK)
	python3 tools/z80trace.py $(ROM) $(ORG) $(SRC)/mahjong.entries \
	        $(WORK)/mahjong $(SRC)/mahjong.nocode

trace: $(WORK)/mahjong.trace.json

listado: $(WORK)/mahjong.trace.json $(SRC)/mahjong.notes
	python3 tools/mkasm.py $(ROM) $(ORG) $(WORK)/mahjong.trace.json \
	        $(SRC)/mahjong.notes work/msx.sym $(SRC)/mahjong.asm "$(TITULO)"

# La prueba que decide si el desensamblado es fiable.
verify: $(SRC)/mahjong.asm $(ROM)
	@sh tools/verify_build.sh $(SRC)/mahjong.asm $(ROM) $(ORG)

# Lo que el reensamblado NO puede cazar: que unos datos se esten leyendo como
# codigo. El binario sale identico igual, porque los bytes no cambian; lo unico
# que cambia es lo que decimos de ellos.
sanity: $(WORK)/mahjong.trace.json
	@echo "=================================================================="
	@echo " ningun byte declarado como datos puede salir como codigo"
	@echo "=================================================================="
	@python3 tools/check_trace.py $(WORK)/mahjong.trace.json $(SRC)/mahjong.nocode
	@python3 tools/check_datos_como_codigo.py $(WORK) $(SRC)
	@echo "=================================================================="
	@echo " ningun punto de entrada puede caer dentro de una zona de datos"
	@echo "=================================================================="
	@python3 tools/check_entradas.py $(SRC)/mahjong.entries $(SRC)/mahjong.notes \
	        $(SRC)/mahjong.nocode
	@echo "=================================================================="
	@echo " ni un byte del cartucho sin asignar"
	@echo "=================================================================="
	@python3 tools/presupuesto.py $(WORK) $(SRC)

test:
	@echo "=================================================================="
	@echo " Tests"
	@echo "=================================================================="
	@python3 -m unittest discover -s tests -v

# Los dos fallos que se pierden en silencio al anotar: un comentario anclado a
# una direccion que no es instruccion, y dos comentarios para la misma.
notas: $(SRC)/mahjong.asm
	@echo "=================================================================="
	@echo " ningun comentario suelto ni repetido"
	@echo "=================================================================="
	@python3 tools/valida_notas.py $(SRC)/mahjong.notes $(SRC)/mahjong.asm

densidad:
	@python3 tools/densidad.py $(SRC)/mahjong.asm

# EL PARCHE DE TRADUCCION (paso 4). De las definiciones legibles de
# src/parche_en/ salen los fragmentos; parchea.py los empalma en una copia del
# listado, ensambla y comprueba que FUERA de los bloques tocados la ROM es
# identica a la original; y de la ROM modificada sale el IPS, que es lo unico
# que se distribuye. La ultima linea es la prueba que decide: original +
# parche = modificada, byte a byte.
PARCHE = parche/mahjong_en.ips
ROM_EN = $(WORK)/mahjong_en.rom

parche: $(ROM) $(SRC)/mahjong.asm src/parche_en/parche.txt
	@echo "=================================================================="
	@echo " El parche de traduccion al ingles"
	@echo "=================================================================="
	python3 tools/construye_parche_en.py src/parche_en/parche.txt src/parche_en/fuentes 	        $(SRC)/mahjong.asm $(SRC)/mahjong.notes $(ROM) $(WORK)/parche_en
	python3 tools/parchea.py $(SRC)/mahjong.asm $(WORK)/parche_en $(WORK)/mahjong_en.asm $(ROM)
	cp $(WORK)/mahjong_en.bin $(ROM_EN)
	python3 tools/ips.py make $(ROM) $(ROM_EN) $(PARCHE)
	python3 tools/ips.py check $(ROM) $(PARCHE) $(ROM_EN)

# La ROM traducida en openMSX, para verla con los ojos.
juega_en: $(ROM_EN)
	"C:/Program Files/openMSX/openmsx.exe" -machine Philips_VG_8020 -cart $(ROM_EN)

clean:
	rm -rf $(WORK)/mahjong.trace.json $(WORK)/mahjong.map $(WORK)/png

.PHONY: all comprueba trace listado notas verify sanity test densidad parche juega_en clean
