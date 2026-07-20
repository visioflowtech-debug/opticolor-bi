"""Lanzador LOCAL para probar sync_dolar_ventas (Fase 2 - dolarización), sin cascada ni func start.

Uso:
  python run_dolar_ventas_local.py               -> modo normal (una ejecución, exige LOAD_MODE_DOLAR_VENTAS='INCREMENTAL')
  python run_dolar_ventas_local.py --historical   -> modo backfill (rondas de hasta 24 min con reanudación por checkpoint)

Requiere local.settings.json en esta misma carpeta (mismas variables que usa func start).
ADVERTENCIA: usa las credenciales y la base de datos configuradas en local.settings.json (producción).
"""
import json
import logging
import os
import sys
import time
import traceback

import pyodbc

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


def leer_checkpoint():
    """Lee el checkpoint actual de Dolar Ventas directo de SQL. Devuelve int o 0."""
    conn = pyodbc.connect(os.environ["SQL_AZURE_CONNECTION_STRING"])
    try:
        cursor = conn.cursor()
        cursor.execute("SELECT LastValue FROM Etl_Checkpoints WHERE KeyName = ?", 'checkpoint_dolar_ventas_skip')
        row = cursor.fetchone()
        if row and row[0] and str(row[0]).isdigit():
            return int(row[0])
        return 0
    finally:
        conn.close()


def run_normal():
    etl = GesvisionEtl()
    try:
        print("=" * 70)
        print("[SEGURO] Prueba local de sync_dolar_ventas")
        print(f"  Modo de carga (LOAD_MODE_DOLAR_VENTAS): {etl.LOAD_MODE_DOLAR_VENTAS}")
        print(f"  Tablero de versión (API_VERSION_VENTAS): {etl.API_VERSION_VENTAS}")
        print("=" * 70)

        assert etl.LOAD_MODE_DOLAR_VENTAS == 'INCREMENTAL', \
            "La primera prueba debe ser INCREMENTAL — aborta si está en HISTORICAL"

        start = time.time()
        resultado = etl.sync_dolar_ventas()
        elapsed = time.time() - start

        print("=" * 70)
        print(f"[RESULTADO] Facturas enriquecidas: {resultado}")
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


def run_historical():
    assert GesvisionEtl.LOAD_MODE_DOLAR_VENTAS == 'HISTORICAL', \
        "--historical requiere LOAD_MODE_DOLAR_VENTAS == 'HISTORICAL' en function_app.py"

    print("⚠️ BACKFILL COMPLETO (~45K facturas). Se ejecutará en rondas de hasta 24 min con reanudación automática por checkpoint.")

    total_general = 0
    rondas_ejecutadas = 0
    inicio_total = time.time()

    for ronda in range(1, 16):
        chk_antes = leer_checkpoint()
        print(f"===== RONDA {ronda} — checkpoint inicial: skip={chk_antes} {'(REANUDANDO)' if chk_antes > 0 else '(desde cero)'} =====")

        etl = GesvisionEtl()
        error_ronda = None
        try:
            resultado = etl.sync_dolar_ventas()
        except Exception:
            error_ronda = traceback.format_exc()
        finally:
            if etl.session:
                try: etl.session.close()
                except: pass

        rondas_ejecutadas += 1

        if error_ronda:
            print("=" * 70)
            print(f"[ERROR] Ronda {ronda} falló. Traceback completo:")
            print(error_ronda)
            print("=" * 70)
            respuesta = input("¿Continuar con la siguiente ronda? El checkpoint garantiza que reintentar es seguro. (s/n): ").strip().lower()
            if respuesta != 's':
                print("Backfill detenido por el usuario.")
                break
            continue

        total_general += resultado
        chk_despues = leer_checkpoint()
        print(f"===== RONDA {ronda} FIN — enriquecidas en la ronda: {resultado} | checkpoint: {chk_despues} =====")

        if chk_despues == 0:
            print("✅ BACKFILL COMPLETADO (checkpoint reseteado a 0 por el módulo).")
            break

        time.sleep(5)
    else:
        print("⚠️ Se alcanzó el máximo de 15 rondas sin completar. Revisar logs.")

    duracion_min = (time.time() - inicio_total) / 60
    print("=" * 70)
    print(f"[RESUMEN BACKFILL] Total facturas enriquecidas: {total_general}")
    print(f"[RESUMEN BACKFILL] Duración total: {duracion_min:.1f} min")
    print(f"[RESUMEN BACKFILL] Rondas ejecutadas: {rondas_ejecutadas}")
    print("=" * 70)


if __name__ == "__main__":
    if "--historical" in sys.argv[1:]:
        run_historical()
    else:
        run_normal()
