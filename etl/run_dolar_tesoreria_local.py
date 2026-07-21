"""Lanzador LOCAL para probar sync_dolar_tesoreria (Fase 2 - dolarización), sin cascada ni func start.

Script simple: un solo UPDATE SQL, sin paginación ni checkpoint (pasada única).

Uso: python run_dolar_tesoreria_local.py

Requiere local.settings.json en esta misma carpeta (mismas variables que usa func start).
ADVERTENCIA: usa las credenciales y la base de datos configuradas en local.settings.json (producción).
"""
import json
import logging
import os
import sys
import time
import traceback

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(message)s")

SETTINGS_PATH = os.path.join(os.path.dirname(os.path.abspath(__file__)), "local.settings.json")

if not os.path.exists(SETTINGS_PATH):
    print("local.settings.json no encontrado — este script debe correr en la carpeta del ETL")
    sys.exit(1)

with open(SETTINGS_PATH, "r", encoding="utf-8") as f:
    settings = json.load(f)

for key, value in settings.get("Values", {}).items():
    os.environ.setdefault(key, value)

# El import va DESPUÉS de cargar las variables de entorno: GesvisionEtl.__init__ lee os.getenv en el momento de instanciar.
from function_app import GesvisionEtl

etl = GesvisionEtl()

try:
    print("=" * 70)
    print("[SEGURO] Prueba local de sync_dolar_tesoreria")
    print("=" * 70)

    start = time.time()
    resultado = etl.sync_dolar_tesoreria()
    elapsed = time.time() - start

    print("=" * 70)
    print(f"[RESULTADO] Movimientos dolarizados: {resultado}")
    print(f"[RESULTADO] Duración: {elapsed:.2f}s")
    print("=" * 70)
except Exception:
    print("=" * 70)
    print("[ERROR] La ejecución falló. Traceback completo:")
    print(traceback.format_exc())
    print("=" * 70)
finally:
    if etl.session:
        etl.session.close()
