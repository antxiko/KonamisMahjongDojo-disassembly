#!/usr/bin/env python3
"""Comprobaciones sobre el listado generado.

Ninguna de estas necesita el cartucho: se hacen sobre src/mahjong.asm y
src/mahjong.notes. De momento solo cubren el paso 1 (el desensamblado); no hay
docs/ todavia porque el paso 2 (documentar la partida) no se ha hecho, y sin
esa base no se escribe la web.
"""
import os
import re
import unittest

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ASM = os.path.join(RAIZ, "src", "mahjong.asm")
NOTES = os.path.join(RAIZ, "src", "mahjong.notes")

ORG, FIN = 0x4000, 0xC000        # 32 KB: paginas 1 y 2, 0x4000-0xBFFF

# Lo que imprime `make sanity`. Si esta cifra se mueve sin que el commit lo
# explique, algo ha cambiado el trazado o las notas sin que nadie se entere.
CODIGO, DATOS = 15432, 17336


def asm():
    with open(ASM, encoding="utf-8") as f:
        return f.read()


def notas():
    with open(NOTES, encoding="utf-8") as f:
        return f.read()


class TestListado(unittest.TestCase):
    def test_no_hay_datos_sin_identificar(self):
        """Ni un `DATOS sin identificar` debe quedar en el listado."""
        self.assertNotIn("DATOS sin identificar", asm())

    def test_las_cifras_de_sanity_no_se_mueven_solas(self):
        """Espejo de lo que imprime presupuesto.py; si cambia, hay que revisar
        por que y actualizar esta constante a proposito, no sin darse cuenta."""
        import subprocess
        import sys
        r = subprocess.run(
            [sys.executable, os.path.join(RAIZ, "tools", "presupuesto.py"),
             os.path.join(RAIZ, "work"), os.path.join(RAIZ, "src")],
            capture_output=True, text=True, cwd=RAIZ)
        m_c = re.search(r"codigo trazado\s+(\d+)", r.stdout)
        m_d = re.search(r"datos identificados\s+(\d+)", r.stdout)
        self.assertIsNotNone(m_c, r.stdout)
        self.assertIsNotNone(m_d, r.stdout)
        self.assertEqual(int(m_c.group(1)), CODIGO)
        self.assertEqual(int(m_d.group(1)), DATOS)
        self.assertEqual(int(m_c.group(1)) + int(m_d.group(1)), FIN - ORG)

    def test_los_bloques_d_del_cartucho_no_se_solapan_sin_avisar(self):
        """Los rangos D dentro de 0x4000-0xBFFF no se pisan, salvo los dos
        casos ya documentados donde dos rotulos COMPARTEN los mismos bytes
        (rotulo_largo y rotulo_corto, en 0x7853 y 0x785B: el corto entra por
        en medio del largo, y las notas lo explican en la linea)."""
        SOLAPES_DOCUMENTADOS = {(0x7853, 0x785B)}
        rangos = []
        for ln in notas().splitlines():
            m = re.match(r"^D\s+0x([0-9A-Fa-f]+)\s+0x([0-9A-Fa-f]+)", ln)
            if m:
                a, b = int(m.group(1), 16), int(m.group(2), 16)
                if ORG <= a < FIN:
                    rangos.append((a, b))
        rangos.sort()
        for (a1, b1), (a2, b2) in zip(rangos, rangos[1:]):
            if (a1, a2) in SOLAPES_DOCUMENTADOS:
                continue
            self.assertLessEqual(b1, a2,
                                  "0x%04X-0x%04X se solapa con 0x%04X-0x%04X "
                                  "sin estar en SOLAPES_DOCUMENTADOS"
                                  % (a1, b1, a2, b2))


if __name__ == "__main__":
    unittest.main()
