import logging
import azure.functions as func
import os
import datetime
import requests
import pandas as pd
import pyodbc
import time
import numpy as np
import json
import traceback

app = func.FunctionApp()

# --- FUNCIÓN DESHABILITADA: HTTP TRIGGER PARA TESTING LOCAL ---
# @app.route(route="run-etl-now", methods=["POST"])
# def EtlExecuteNow(req: func.HttpRequest) -> func.HttpResponse:
#     """Ejecutor manual de cascada ETL. Deshabilitada para deploy limpio en producción.
#     Se puede reactivar comentando @app.route y descommentando la función completa."""
#     return func.HttpResponse("Deshabilitada en producción", status_code=503)

# --- SECCIÓN 1: DISPARADORES (TIMER TRIGGERS) ---
# Orquestación Basada en Estados y Horarios CRON para Producción.

# --- NUEVO MODELO: CASCADA SECUENCIAL (Trigger-to-Trigger) ---
# Solo la primera función tiene TimerTrigger. Las demás se ejecutan en cadena.

# CRON: "0 0,2,12,14,16,18,20,22 * * *" = Cada 2 horas de 8 AM a 10 PM Venezuela (12 PM-2 AM UTC)
# Horarios UTC:      12:00, 14:00, 16:00, 18:00, 20:00, 22:00, 00:00, 02:00 UTC
# Horarios Venezuela (UTC-4): 08:00, 10:00, 12:00, 14:00, 16:00, 18:00, 20:00, 22:00 Venezuela
# Total: 8 ejecuciones/día (8 AM - 10 PM Venezuela)
# Beneficio: Ejecuciones menos frecuentes pero con suficiente cobertura horaria
# [8 MAYO 2026] CRON ACTUALIZADO: CADA 2 HORAS (8 AM-10 PM Venezuela) PARA MEJOR EFICIENCIA
# @app.timer_trigger(schedule="0 12,14,16,18,20,22,0,2 * * *", arg_name="myTimer", run_on_startup=False)
def EtlOrquestadorPrincipal(myTimer: func.TimerRequest) -> None:
    """Función Maestra que inicia la cascada de ejecución."""
    etl = None

    try:
        logging.info("--- [INICIO] CICLO ETL OPTICOLOR (CASCADA) ---")
        etl = GesvisionEtl()

        # === DETECTAR EJECUCIONES DUPLICADAS (Sin bloqueo permanente) ===
        try:
            with pyodbc.connect(etl.conn_str) as conn:
                cursor = conn.cursor()
                # Crear tabla de control si no existe
                cursor.execute("""
                    IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Etl_Running_Lock' AND xtype='U')
                    CREATE TABLE Etl_Running_Lock (
                        is_running INT,
                        last_start DATETIME
                    )
                """)

                # Limpiar locks antiguos (>60 minutos automáticamente)
                cursor.execute("DELETE FROM Etl_Running_Lock WHERE DATEDIFF(minute, last_start, GETUTCDATE()) > 60")

                # Verificar si hay un ciclo YA corriendo
                cursor.execute("SELECT COUNT(*) FROM Etl_Running_Lock WHERE is_running = 1 AND DATEDIFF(minute, last_start, GETUTCDATE()) < 60")
                result = cursor.fetchone()

                if result and result[0] > 0:
                    logging.info("⚠️ Otro ciclo ETL ya está en ejecución. Esta ejecución será ignorada.")
                    return  # Salir sin hacer nada

                # Marcar que ESTE ciclo está corriendo AHORA
                cursor.execute("DELETE FROM Etl_Running_Lock")
                cursor.execute("INSERT INTO Etl_Running_Lock (is_running, last_start) VALUES (1, GETUTCDATE())")
                conn.commit()
        except Exception as lock_error:
            logging.warning(f"⚠️ Error verificando lock (continuando igual): {lock_error}")

        reporte = []
        start_global = time.time()
        inicio_ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        MAX_DURATION_MINS = 24  # Límite de seguridad Azure

        # Notificación de inicio
        etl.notificar_telegram(f"✅ ETL Opticolor iniciado — {inicio_ts}")

        def check_time_limit():
            """Verifica si se excedió el tiempo límite global."""
            elapsed = (time.time() - start_global) / 60
            if elapsed > MAX_DURATION_MINS:
                logging.warning(f"⚠️ [TIMEOUT PREVENTIVO] Tiempo excedido ({elapsed:.1f} min). Deteniendo cascada.")
                return True
            return False

        # --- CASCADA COMPLETA: 18/18 MÓDULOS GESVISION ---
        # [23 ABRIL 2026] ACTIVACIÓN CASCADA NORMALIZADA
        # - VENTAS: 2,573 facturas backfill completado → INCREMENTAL (últimos 10 días)
        # - COBROS: 4,608 cobros backfill completado → INCREMENTAL (últimas 2 horas)
        # - INVENTARIO: 146,707 items backfill completado → INCREMENTAL (sincronización diaria)
        remaining_modules = [
            ('SUCURSALES', etl.sync_dimensions),
            ('EMPLEADOS', etl.sync_employees),
            ('CATEGORIAS', etl.sync_categories),
            ('METODOS_PAGO', etl.sync_payment_methods),
            ('PROVEEDORES', etl.sync_suppliers),
            ('MARCAS_FULL', etl.sync_brands_full),
            ('PRODUCTOS', etl.sync_products),
            ('CLIENTES', etl.sync_customers),
            ('CITAS', etl.sync_appointments),
            ('EXAMENES', etl.sync_exams),
            ('PEDIDOS', etl.sync_orders),
            ('ORDENES_CRISTALES', etl.sync_glasses_orders),
            ('VENTAS', etl.sync_invoices_incremental),
            ('COBROS', etl.sync_collections),
            ('TESORERIA', etl.sync_treasury),
            ('PEDIDOS_LAB', etl.sync_laboratory_orders),
            ('RECEPCIONES_LAB', etl.sync_received_delivery_notes),
            # ✅ 17/17 MÓDULOS EN CASCADA (INVENTARIO SEPARADO EN FUNCIÓN INDEPENDIENTE)
        ]

        for mod_name, mod_func in remaining_modules:
            if check_time_limit(): break
            resultado_modulo = etl.ejecutar_modulo(mod_name, mod_func)
            reporte.append(resultado_modulo)

            # Enviar notificación por cada módulo completado
            if resultado_modulo and resultado_modulo.get('status'):
                status = resultado_modulo.get('status', '⚠️')
                resultado_info = resultado_modulo.get('resultado', '')
                msg = f"{status} {mod_name}"
                if resultado_info:
                    msg += f" → {resultado_info}"
                etl.notificar_telegram(msg, silencioso=False)

        # --- REPORTE FINAL ---
        duration = (time.time() - start_global) / 60
        etl.enviar_resumen_ciclo_telegram(reporte, duration)
        logging.info(f"--- [FIN] CICLO ETL COMPLETADO EN {duration:.2f} MIN ---")

    except Exception as e:
        if etl:
            try:
                duration = (time.time() - start_global) / 60
                logging.error(f"Error crítico en cascada: {e}")
                etl.enviar_resumen_ciclo_telegram(reporte, duration, error_critico=str(e))
            except:
                logging.error(f"Error al enviar reporte: {e}")
        else:
            logging.error(f"Error fatal en cascada (etl no inicializado): {e}")
    finally:
        # Liberar lock cuando termina (éxito o error)
        try:
            if etl and hasattr(etl, 'conn_str') and etl.conn_str:
                # Verificar si estamos en LOCAL o en AZURE
                # En LOCAL, la BD no es accesible, así que saltamos silenciosamente
                try:
                    with pyodbc.connect(etl.conn_str) as conn:
                        cursor = conn.cursor()
                        cursor.execute("UPDATE Etl_Running_Lock SET is_running = 0")
                        conn.commit()
                        logging.info("✅ Lock liberado correctamente")
                except Exception as db_error:
                    # Si hay error de conexión (IM002 = BD no accesible), log silencioso
                    # Esto ocurre en LOCAL cuando no hay acceso a Azure SQL
                    if 'IM002' in str(db_error) or 'No se encuentra' in str(db_error):
                        logging.debug(f"[LOCAL] BD no accesible para liberar lock (esperado en LOCAL): {db_error}")
                    else:
                        logging.warning(f"⚠️ Error al liberar lock: {db_error}")
            else:
                logging.debug("⚠️ No se pudo liberar lock (etl.conn_str no disponible)")
        except Exception as lock_error:
            logging.warning(f"⚠️ Error crítico en finally: {lock_error}")

        if etl and etl.session:
            try:
                etl.session.close()
            except:
                pass


# --- FUNCIÓN TEMPORAL: PRODUCTOS CADA MINUTO (hasta completar carga histórica) ---
# [22 ABRIL 2026] COMENTADO — Carga histórica de 143,860 productos COMPLETADA
# Se restaura EtlOrquestadorPrincipal para cascada completa 8x/día
# @app.timer_trigger(schedule="*/1 * * * *", arg_name="myTimer", run_on_startup=False)
# def EtlProductosRepetitivo(myTimer: func.TimerRequest) -> None:
#     """
#     Ejecutor temporal SOLO PRODUCTOS que se reinicia cada minuto.
#     Una vez completada la carga histórica, comentar esta función.
#     """
#     logging.info("--- [PRODUCTOS-LOOP] Inicio repetitivo (cada minuto) ---")
#     etl = GesvisionEtl()
#     start_time = time.time()
#
#     try:
#         # Verificar si ya completó
#         import pyodbc
#         with pyodbc.connect(etl.conn_str) as conn:
#             cursor = conn.cursor()
#             cursor.execute("SELECT LastValue FROM Etl_Checkpoints WHERE KeyName = 'checkpoint_products_skip'")
#             row = cursor.fetchone()
#             skip_actual = int(row[0]) if row and row[0] else 0
#             cursor.close()
#
#         if skip_actual == 0:
#             # Verificar si hay datos (significa que completó alguna vez)
#             with pyodbc.connect(etl.conn_str) as conn:
#                 cursor = conn.cursor()
#                 cursor.execute("SELECT COUNT(*) FROM Maestro_Productos")
#                 count_productos = cursor.fetchone()[0]
#                 cursor.close()
#
#             if count_productos > 0:
#                 logging.info(f"✅ [PRODUCTOS-LOOP] Carga histórica COMPLETADA ({count_productos:,} productos)")
#                 etl.notificar_telegram(f"✅ PRODUCTOS completado: {count_productos:,} productos en BD")
#                 return
#
#         # Ejecutar sync_products() con timeout de 20 minutos
#         if not etl.token: etl.get_token()
#         total_processed = etl.sync_products()
#
#         elapsed = (time.time() - start_time) / 60
#         logging.info(f"--- [PRODUCTOS-LOOP] Procesados: {total_processed} productos en {elapsed:.1f} min ---")
#
#         # Notificar progreso cada 5 ciclos (~5 minutos)
#         if int(elapsed) % 5 == 0:
#             with pyodbc.connect(etl.conn_str) as conn:
#                 cursor = conn.cursor()
#                 cursor.execute("SELECT COUNT(*) FROM Maestro_Productos")
#                 count_productos = cursor.fetchone()[0]
#                 cursor.close()
#             etl.notificar_telegram(f"[PRODUCTOS-LOOP] Progreso: {count_productos:,} productos cargados")
#
#     except Exception as e:
#         logging.error(f"Error en PRODUCTOS-LOOP: {e}")
#         try:
#             etl.notificar_telegram(f"❌ ERROR PRODUCTOS-LOOP: {str(e)[:200]}")
#         except: pass
#
#     finally:
#         if etl.session: etl.session.close()


# --- FUNCIÓN TEMPORAL: VENTAS CADA MINUTO (Backfill HISTORICAL) ---
# [23 ABRIL 2026] COMENTADA — VENTAS completada, pasando a COBROS
# Con lock en BD para evitar ejecuciones paralelas (solo 1 a la vez, secuencial)
# # @app.timer_trigger(schedule="*/1 * * * *", arg_name="myTimer", run_on_startup=False)
# # def EtlVentasRepetitivo(myTimer: func.TimerRequest) -> None:
# #     """
# #     Ejecutor temporal SOLO VENTAS que se reinicia cada minuto.
# #     Estrategia SECUENCIAL: MAX 24 minutos por ejecución, con lock en BD para evitar paralelismo.
# #     Una ejecución termina → espera al siguiente minuto → comienza la siguiente.
# #     Termina automáticamente cuando API retorna Status 204 (sin más datos).
# #     """
# #     logging.info("--- [VENTAS-LOOP] Inicio repetitivo (cada minuto) ---")
# #     etl = GesvisionEtl()
# #     start_time = time.time()
# #     lock_acquired = False
# #
# #     try:
# #         # Adquirir lock exclusivo en BD (evitar ejecuciones paralelas)
# #         with pyodbc.connect(etl.conn_str) as conn:
# #             cursor = conn.cursor()
# #             try:
# #                 # Intenta adquirir lock (espera máximo 5 segundos)
# #                 cursor.execute("SELECT * FROM Etl_Checkpoints WITH (XLOCK, READPAST) WHERE KeyName = 'lock_ventas_execution' WAITFOR DELAY '00:00:05'")
# #                 lock_acquired = True
# #                 logging.info("   [LOCK] Lock exclusivo adquirido — ejecutando VENTAS secuencialmente")
# #             except Exception as lock_err:
# #                 logging.warning(f"   [LOCK] No se pudo adquirir lock (otra ejecución en progreso): {lock_err}")
# #                 cursor.close()
# #                 return
# #
# #         if not lock_acquired:
# #             logging.warning("   [LOCK] Otra ejecución de VENTAS está en progreso. Saltando esta ronda.")
# #             return
# #
# #         if not etl.token: etl.get_token()
# #         total_processed = etl.sync_invoices_incremental()
# #
# #         elapsed = (time.time() - start_time) / 60
# #         logging.info(f"--- [VENTAS-LOOP] Procesados: {total_processed} facturas en {elapsed:.1f} min ---")
# #
# #         # Notificar progreso solo si se procesaron items
# #         if total_processed > 0:
# #             with pyodbc.connect(etl.conn_str) as conn:
# #                 cursor = conn.cursor()
# #                 cursor.execute("SELECT COUNT(*) FROM Ventas_Cabecera")
# #                 count_ventas = cursor.fetchone()[0]
# #                 cursor.close()
# #             etl.notificar_telegram(f"[VENTAS-LOOP] Progreso: {count_ventas:,} facturas cargadas ({total_processed} en {elapsed:.1f} min)")
# #         else:
# #             logging.info("   [VENTAS-LOOP] ✅ COMPLETADO - No hay más facturas para procesar (status 204)")
# #             etl.notificar_telegram("✅ VENTAS completado - Tabla poblada en su totalidad. Cambiar a cascada normal.")
# #
# #     except Exception as e:
# #         logging.error(f"Error en VENTAS-LOOP: {e}")
# #         try:
# #             etl.notificar_telegram(f"❌ ERROR VENTAS-LOOP: {str(e)[:200]}")
# #         except: pass
# #
# #     finally:
# #         if etl.session: etl.session.close()


# --- FUNCIÓN TEMPORAL: COBROS CADA MINUTO (Backfill HISTORICAL) ---
# [23 ABRIL 2026] DESACTIVADA — COBROS completada, pasando a cascada normal
# Con lock en BD para evitar ejecuciones paralelas (solo 1 a la vez, secuencial)
# # @app.timer_trigger(schedule="*/1 * * * *", arg_name="myTimer", run_on_startup=False)
# # def EtlCobrosRepetitivo(myTimer: func.TimerRequest) -> None:
# #     """
# #     Ejecutor temporal SOLO COBROS que se reinicia cada minuto.
# #     Estrategia SECUENCIAL: MAX 24 minutos por ejecución, con lock en BD para evitar paralelismo.
# #     Una ejecución termina → espera al siguiente minuto → comienza la siguiente.
# #     Termina automáticamente cuando API retorna Status 204 (sin más datos).
# #     """
# #     logging.info("--- [COBROS-LOOP] Inicio repetitivo (cada minuto) ---")
# #     etl = GesvisionEtl()
# #     start_time = time.time()
# #     lock_acquired = False
# #
# #     try:
# #         # Adquirir lock exclusivo en BD (evitar ejecuciones paralelas)
# #         with pyodbc.connect(etl.conn_str) as conn:
# #             cursor = conn.cursor()
# #             try:
# #                 # Intenta adquirir lock (espera máximo 5 segundos)
# #                 cursor.execute("SELECT * FROM Etl_Checkpoints WITH (XLOCK, READPAST) WHERE KeyName = 'lock_cobros_execution' WAITFOR DELAY '00:00:05'")
# #                 lock_acquired = True
# #                 logging.info("   [LOCK] Lock exclusivo adquirido — ejecutando COBROS secuencialmente")
# #             except Exception as lock_err:
# #                 logging.warning(f"   [LOCK] No se pudo adquirir lock (otra ejecución en progreso): {lock_err}")
# #                 cursor.close()
# #                 return
# #
# #         if not lock_acquired:
# #             logging.warning("   [LOCK] Otra ejecución de COBROS está en progreso. Saltando esta ronda.")
# #             return
# #
# #         if not etl.token: etl.get_token()
# #         total_processed, total_amount = etl.sync_collections()
# #
# #         elapsed = (time.time() - start_time) / 60
# #         logging.info(f"--- [COBROS-LOOP] Procesados: {total_processed} cobros en {elapsed:.1f} min (Monto total: ${total_amount:,.2f}) ---")
# #
# #         # Notificar progreso solo si se procesaron items
# #         if total_processed > 0:
# #             with pyodbc.connect(etl.conn_str) as conn:
# #                 cursor = conn.cursor()
# #                 cursor.execute("SELECT COUNT(*) FROM Finanzas_Cobros")
# #                 count_cobros = cursor.fetchone()[0]
# #                 cursor.close()
# #             etl.notificar_telegram(f"[COBROS-LOOP] Progreso: {count_cobros:,} cobros cargados (${total_amount:,.2f}) ({total_processed} en {elapsed:.1f} min)")
# #         else:
# #             logging.info("   [COBROS-LOOP] ✅ COMPLETADO - No hay más cobros para procesar (status 204)")
# #             etl.notificar_telegram("✅ COBROS completado - Tabla poblada en su totalidad. Cambiar a cascada normal.")


# --- FUNCIÓN TEMPORAL: INVENTARIO CADA MINUTO (estrategia PRODUCTOS) ---
# [23 ABRIL 2026] COMENTADA — INVENTARIO completado, ahora ejecuta en cascada principal
# La cascada principal (EtlOrquestadorPrincipal) maneja todos 18 módulos incluyendo INVENTARIO
# # @app.timer_trigger(schedule="*/1 * * * *", arg_name="myTimer", run_on_startup=False)
# # def EtlInventarioRepetitivo(myTimer: func.TimerRequest) -> None:
# #     """
# #     Ejecutor temporal SOLO INVENTARIO que se reinicia cada minuto.
# #     Estrategia SECUENCIAL: MAX 24 minutos por ejecución, con lock en BD para evitar paralelismo.
# #     Una ejecución termina → espera al siguiente minuto → comienza la siguiente.
# #     """
# #     logging.info("--- [INVENTARIO-LOOP] Inicio repetitivo (cada minuto) ---")
# #     etl = GesvisionEtl()
# #     start_time = time.time()
# #     lock_acquired = False
#
# #     try:
# #         # Adquirir lock exclusivo en BD (evitar ejecuciones paralelas)
# #         with pyodbc.connect(etl.conn_str) as conn:
# #             cursor = conn.cursor()
# #             try:
# #                 # Intenta adquirir lock (espera máximo 5 segundos)
# #                 cursor.execute("SELECT * FROM Etl_Checkpoints WITH (XLOCK, READPAST) WHERE KeyName = 'lock_inventory_execution' WAITFOR DELAY '00:00:05'")
# #                 lock_acquired = True
# #                 logging.info("   [LOCK] Lock exclusivo adquirido — ejecutando INVENTARIO secuencialmente")
# #             except Exception as lock_err:
# #                 logging.warning(f"   [LOCK] No se pudo adquirir lock (otra ejecución en progreso): {lock_err}")
# #                 cursor.close()
# #                 return
#
# #         if not lock_acquired:
# #             logging.warning("   [LOCK] Otra ejecución de INVENTARIO está en progreso. Saltando esta ronda.")
# #             return
#
# #         if not etl.token: etl.get_token()
# #         total_processed = etl.sync_inventory()
#
# #         elapsed = (time.time() - start_time) / 60
# #         logging.info(f"--- [INVENTARIO-LOOP] Procesados: {total_processed} items en {elapsed:.1f} min ---")
#
# #         # Notificar progreso solo si se procesaron items
# #         if total_processed > 0:
# #             with pyodbc.connect(etl.conn_str) as conn:
# #                 cursor = conn.cursor()
# #                 cursor.execute("SELECT COUNT(*) FROM Operaciones_Inventario")
# #                 count_inventario = cursor.fetchone()[0]
# #                 cursor.close()
# #             etl.notificar_telegram(f"[INVENTARIO-LOOP] Progreso: {count_inventario:,} items cargados ({total_processed} en {elapsed:.1f} min)")
# #         else:
# #             logging.info("   [INVENTARIO-LOOP] ✅ COMPLETADO - No hay más items para procesar (status 204)")
# #             etl.notificar_telegram("✅ INVENTARIO completado - Tabla poblada en su totalidad")
#
# #     except Exception as e:
# #         logging.error(f"Error en INVENTARIO-LOOP: {e}")
# #         try:
# #             etl.notificar_telegram(f"❌ ERROR INVENTARIO-LOOP: {str(e)[:200]}")
# #         except: pass
#
# #     finally:
# #         if etl.session: etl.session.close()


# --- FUNCIÓN SEPARADA: EtlInventarioSeparado - Ejecuta PRODUCTOS+INVENTARIO cada 2 horas ---
# [08 MAYO 2026] NUEVA ESTRATEGIA: INVENTARIO se ejecuta independientemente cada 2 horas
# para evitar timeout en Azure (30 min) cuando el ETL principal corre en paralelo

# @app.timer_trigger(schedule="30 12,14,16,18,20,22,0,2 * * *", arg_name="myTimer", run_on_startup=False)
def EtlInventarioSeparado(myTimer: func.TimerRequest) -> None:
    """
    Ejecuta PRODUCTOS (2da corrida) + INVENTARIO cada 2 horas.
    Schedule: 0 */2 * * * = Cada 2 horas (00:00, 02:00, 04:00, 06:00, etc UTC)
    En Venezuela (UTC-4): 20:00, 22:00, 00:00, 02:00, 04:00, 06:00, 08:00, 10:00, 12:00, 14:00, 16:00, 18:00

    Razón: Inventario tarda ~25-30 min. El ETL principal tarda ~2 min.
    Si ambos corren juntos, se excede el timeout de Azure (30 min).
    Separándolos, cada uno tiene tiempo suficiente sin presión.
    """

    etl = None
    try:
        logging.info("--- [INICIO] CICLO INVENTARIO SEPARADO (cada 2 horas) ---")
        etl = GesvisionEtl()

        # ===== CONTROL: Verificar si ya hay ciclo de Inventario corriendo =====
        try:
            with pyodbc.connect(etl.conn_str) as conn:
                cursor = conn.cursor()

                # Crear tabla si no existe
                cursor.execute("""
                    IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Etl_Inventory_Lock' AND xtype='U')
                    CREATE TABLE Etl_Inventory_Lock (
                        is_running INT,
                        last_start DATETIME,
                        expires_at DATETIME
                    )
                """)

                # Limpiar locks viejos (>120 minutos)
                cursor.execute("DELETE FROM Etl_Inventory_Lock WHERE DATEDIFF(minute, last_start, GETUTCDATE()) > 120")

                # Verificar si hay ciclo activo
                cursor.execute("SELECT COUNT(*) FROM Etl_Inventory_Lock WHERE is_running = 1 AND expires_at > GETUTCDATE()")
                result = cursor.fetchone()

                if result and result[0] > 0:
                    logging.warning("⚠️ Ciclo Inventario anterior aún está corriendo. Abortando.")
                    etl.notificar_telegram("⚠️ Inventario anterior aún corre. Ciclo actual abortado.")
                    return

                # Crear nuevo lock (válido 120 minutos)
                cursor.execute("DELETE FROM Etl_Inventory_Lock")
                cursor.execute(
                    "INSERT INTO Etl_Inventory_Lock (is_running, last_start, expires_at) VALUES (1, GETUTCDATE(), DATEADD(minute, 120, GETUTCDATE()))"
                )
                conn.commit()
        except Exception as lock_error:
            logging.warning(f"⚠️ Error verificando lock inventario: {lock_error}")

        # Notificación de inicio
        etl.notificar_telegram(f"✅ Ciclo INVENTARIO iniciado — {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')}")

        start_time = time.time()

        # ===== PRODUCTOS (2da corrida - asegura datos frescos antes de Inventario) =====
        logging.info("--- [INVENTARIO] Ejecutando PRODUCTOS (2da corrida) ---")
        try:
            resultado_productos = etl.ejecutar_modulo("PRODUCTOS", etl.sync_products)
            if resultado_productos and resultado_productos.get('status') == '✅':
                logging.info("✅ PRODUCTOS (2da corrida) completado")
            else:
                logging.warning("⚠️ PRODUCTOS (2da corrida) completó con estado incierto")
        except Exception as e:
            logging.error(f"❌ PRODUCTOS (2da corrida) ERROR: {e}")

        # ===== INVENTARIO =====
        logging.info("--- [INVENTARIO] Ejecutando INVENTARIO ---")
        try:
            resultado_inventario = etl.ejecutar_modulo("INVENTARIO", etl.sync_inventory)
            if resultado_inventario and resultado_inventario.get('status') == '✅':
                logging.info("✅ INVENTARIO completado")
            else:
                logging.warning("⚠️ INVENTARIO completó con estado incierto")
        except Exception as e:
            logging.error(f"❌ INVENTARIO ERROR: {e}")

        # ===== FINALIZACIÓN =====
        duration = time.time() - start_time
        logging.info(f"--- [FIN] CICLO INVENTARIO SEPARADO COMPLETADO EN {duration/60:.2f} MIN ---")
        etl.notificar_telegram(f"✅ Ciclo INVENTARIO completado — {datetime.datetime.now().strftime('%Y-%m-%d %H:%M:%S')} — {duration/60:.1f} min")

    except Exception as e:
        logging.error(f"❌ ERROR CRÍTICO EN INVENTARIO SEPARADO: {e}")
        if etl:
            etl.notificar_telegram(f"❌ ERROR INVENTARIO SEPARADO: {str(e)[:100]}")

    finally:
        # Liberar lock
        try:
            if etl and hasattr(etl, 'conn_str') and etl.conn_str:
                with pyodbc.connect(etl.conn_str) as conn:
                    cursor = conn.cursor()
                    cursor.execute("UPDATE Etl_Inventory_Lock SET is_running = 0")
                    conn.commit()
                    logging.info("✅ Lock inventario liberado")
        except Exception as lock_error:
            logging.warning(f"⚠️ Error liberando lock inventario: {lock_error}")

        if etl and etl.session:
            try:
                etl.session.close()
            except:
                pass


# ═══════════════════════════════════════════════════════════════════════════════
# PATRÓN A: CONTROLADOR DE PENDIENTES
# Sistema robusto de orquestación con auto-recuperación
# ═══════════════════════════════════════════════════════════════════════════════

# Configuración de módulos con dependencias
MODULOS_CONFIG = [
    # (orden, nombre, funcion, dependencias)
    (1, 'SUCURSALES', 'sync_dimensions', []),
    (2, 'EMPLEADOS', 'sync_employees', []),
    (3, 'CATEGORIAS', 'sync_categories', []),
    (4, 'METODOS_PAGO', 'sync_payment_methods', []),
    (5, 'PROVEEDORES', 'sync_suppliers', []),
    (6, 'MARCAS_FULL', 'sync_brands_full', []),
    (7, 'CLIENTES', 'sync_customers', []),
    (8, 'CITAS', 'sync_appointments', []),
    (9, 'PRODUCTOS', 'sync_products', ['CATEGORIAS', 'MARCAS_FULL', 'PROVEEDORES']),
    (10, 'EXAMENES', 'sync_exams', ['CLIENTES', 'EMPLEADOS', 'SUCURSALES']),
    (11, 'PEDIDOS', 'sync_orders', ['CLIENTES', 'SUCURSALES']),
    (12, 'ORDENES_CRISTALES', 'sync_glasses_orders', ['PEDIDOS']),
    (13, 'VENTAS', 'sync_invoices_incremental', ['CLIENTES', 'PRODUCTOS', 'EMPLEADOS', 'METODOS_PAGO']),
    (14, 'COBROS', 'sync_collections', ['VENTAS', 'METODOS_PAGO']),
    (15, 'TESORERIA', 'sync_treasury', ['SUCURSALES']),
    (16, 'PEDIDOS_LAB', 'sync_laboratory_orders', ['ORDENES_CRISTALES']),
    (17, 'RECEPCIONES_LAB', 'sync_received_delivery_notes', ['PEDIDOS_LAB']),
    (18, 'INVENTARIO', 'sync_inventory', ['PRODUCTOS', 'SUCURSALES']),
    (19, 'DOLAR_VENTAS', 'sync_dolar_ventas', ['VENTAS']),
    (20, 'DOLAR_TASAS', 'sync_dolar_tasas', ['DOLAR_VENTAS']),
    (21, 'DOLAR_PEDIDOS', 'sync_dolar_pedidos', ['PEDIDOS', 'DOLAR_TASAS']),
    (22, 'DOLAR_INVENTARIO', 'sync_dolar_inventario', ['INVENTARIO', 'DOLAR_TASAS']),
    (23, 'DOLAR_COBROS', 'sync_dolar_cobros', ['DOLAR_VENTAS', 'DOLAR_TASAS']),
]

MODULOS_DEGRADADOS_CONOCIDOS = {
    'RECEPCIONES_LAB': 'HTTP 500 en Gesvision (ParseException de fecha en su backend). '
                        'Reportado al proveedor. Sin ETA de corrección.',
}

HORAS_INICIO_CICLO_UTC = [12, 14, 16, 18, 20, 22, 0, 2]
MAX_DURACION_EJECUCION = 25 * 60  # 25 minutos máximo por ejecución

def detectar_y_marcar_colgados(etl):
    """
    WATCHDOG: Detecta módulos en EJECUTANDO >15 min y los marca FAILED.
    Permite que el ciclo continúe sin quedar bloqueado por Azure Flex scale-in.
    """
    try:
        with pyodbc.connect(etl.conn_str) as conn:
            cursor = conn.cursor()

            # Buscar módulos colgados
            cursor.execute("""
                SELECT id, modulo_nombre, ciclo_id,
                       DATEDIFF(minute, fecha_inicio, GETUTCDATE()) as minutos
                FROM Etl_Pendientes_Modulo
                WHERE estado = 'EJECUTANDO'
                  AND DATEDIFF(minute, fecha_inicio, GETUTCDATE()) > 15
            """)

            colgados = cursor.fetchall()

            if not colgados:
                return

            for row in colgados:
                modulo_id, nombre, ciclo_id, minutos = row

                logging.warning(f"⚠️ WATCHDOG: {nombre} colgado {minutos} min. Marcando FAILED.")

                cursor.execute("""
                    UPDATE Etl_Pendientes_Modulo
                    SET estado = 'FAILED',
                        fecha_fin = GETUTCDATE(),
                        duracion_segundos = DATEDIFF(second, fecha_inicio, GETUTCDATE()),
                        mensaje_error = ?,
                        proximo_intento = DATEADD(minute, 5, GETUTCDATE())
                    WHERE id = ?
                """, f'WATCHDOG: Azure Flex scale-in mato la funcion ({minutos}min sin actualizar)', modulo_id)

                # Notificar Telegram
                try:
                    etl.notificar_telegram(
                        f"WATCHDOG: {nombre} colgado\n"
                        f"{minutos} min sin progreso\n"
                        f"Marcado FAILED - se reintentara"
                    )
                except:
                    pass

            conn.commit()
            logging.info(f"WATCHDOG: {len(colgados)} modulos colgados cerrados")

    except Exception as e:
        logging.error(f"Error en watchdog: {e}")


@app.timer_trigger(schedule="*/30 * * * *", arg_name="myTimer", run_on_startup=False)
def EtlControladorPendientes(myTimer: func.TimerRequest) -> None:
    """
    Controlador de Pendientes - Patrón A

    Se ejecuta cada 30 minutos:
    1. Verifica si hay un ciclo activo o crea uno nuevo
    2. Identifica módulos pendientes considerando dependencias
    3. Ejecuta los pendientes uno por uno con timeout
    4. Marca cada módulo como COMPLETADO o FAILED
    5. Si todos completaron, cierra el ciclo
    """

    etl = None
    start_time = time.time()

    try:
        logging.info("═══════════════════════════════════════════════════════")
        logging.info("[CONTROLADOR] Iniciando ciclo de control de pendientes")
        logging.info("═══════════════════════════════════════════════════════")

        etl = GesvisionEtl()

        # PASO 0: WATCHDOG - Detectar y limpiar módulos colgados de ejecuciones anteriores
        detectar_y_marcar_colgados(etl)

        # PASO 1: Obtener o crear ciclo activo
        ciclo_id = obtener_o_crear_ciclo(etl)

        if not ciclo_id:
            logging.info("[CONTROLADOR] No hay ciclo activo y no es hora de crear uno nuevo")
            return

        logging.info(f"[CONTROLADOR] Ciclo activo: {ciclo_id}")

        # PASO 2+3: Cascada dinámica — recalcula qué se desbloqueó tras cada tanda, en vez de una sola
        # pasada estática (antes: 1 ola por invocación de 30 min; ahora: todas las olas que quepan en
        # MAX_DURACION_EJECUCION, dentro de esta misma invocación).
        MAX_OLAS_POR_INVOCACION = 30  # salvaguarda defensiva; con ~23 módulos, de sobra
        ola = 0
        total_ejecutados_invocacion = 0

        while True:
            ola += 1
            elapsed = time.time() - start_time
            if elapsed > MAX_DURACION_EJECUCION:
                logging.warning(f"⏰ Tiempo límite alcanzado ({elapsed/60:.1f} min) en la ola {ola}. "
                                 f"Módulos restantes en la siguiente invocación.")
                break
            if ola > MAX_OLAS_POR_INVOCACION:
                logging.warning(f"⚠️ Tope de {MAX_OLAS_POR_INVOCACION} olas alcanzado. Deteniendo por seguridad.")
                break

            pendientes = obtener_modulos_ejecutables(etl, ciclo_id)
            if not pendientes:
                if ola == 1:
                    logging.info("[CONTROLADOR] No hay módulos pendientes ejecutables")
                else:
                    logging.info(f"[CONTROLADOR] Ola {ola}: sin más módulos ejecutables. Cascada completa.")
                break

            logging.info(f"[CONTROLADOR] Ola {ola}: {len(pendientes)} módulos ejecutables")

            for modulo_info in pendientes:
                elapsed = time.time() - start_time
                if elapsed > MAX_DURACION_EJECUCION:
                    logging.warning(f"⏰ Tiempo límite alcanzado ({elapsed/60:.1f} min) a mitad de la ola {ola}. "
                                     f"Módulos restantes en la siguiente invocación.")
                    break
                ejecutar_modulo_pendiente(etl, ciclo_id, modulo_info)
                total_ejecutados_invocacion += 1
            else:
                continue  # la ola terminó completa sin cortar por tiempo -> seguir a la siguiente ola
            break  # se cortó por tiempo a mitad de una ola -> salir del while también

        logging.info(f"[CONTROLADOR] Invocación terminada: {total_ejecutados_invocacion} módulos "
                     f"ejecutados en {ola} ola(s), {(time.time()-start_time)/60:.1f} min")

        # PASO 4: Verificar si ciclo completó (sin cambios)
        verificar_y_cerrar_ciclo(etl, ciclo_id)

    except Exception as e:
        logging.error(f"❌ ERROR EN CONTROLADOR: {e}")
        if etl:
            etl.notificar_telegram(f"❌ ERROR CONTROLADOR: {str(e)[:200]}")

    finally:
        if etl and etl.session:
            try:
                etl.session.close()
            except:
                pass


def obtener_o_crear_ciclo(etl):
    """Obtiene el ciclo activo o crea uno nuevo si es la hora apropiada"""

    try:
        with pyodbc.connect(etl.conn_str) as conn:
            cursor = conn.cursor()

            # Buscar ciclo activo
            cursor.execute("""
                SELECT TOP 1 ciclo_id
                FROM Etl_Ciclos
                WHERE estado = 'ACTIVO'
                ORDER BY fecha_inicio DESC
            """)

            row = cursor.fetchone()
            if row:
                return row[0]

            # No hay ciclo activo, verificar si es hora de crear uno
            hora_utc = datetime.datetime.utcnow().hour

            if hora_utc not in HORAS_INICIO_CICLO_UTC:
                return None

            # Verificar que no se haya creado ya un ciclo en esta hora
            cursor.execute("""
                SELECT COUNT(*)
                FROM Etl_Ciclos
                WHERE DATEDIFF(minute, fecha_inicio, GETUTCDATE()) < 30
            """)

            if cursor.fetchone()[0] > 0:
                logging.info("[CONTROLADOR] Ya se creó un ciclo en los últimos 30 min")
                return None

            # Crear nuevo ciclo
            ciclo_id = f"CICLO_{datetime.datetime.utcnow().strftime('%Y%m%d_%H%M%S')}"

            cursor.execute("""
                INSERT INTO Etl_Ciclos (ciclo_id, modulos_total)
                VALUES (?, ?)
            """, ciclo_id, len(MODULOS_CONFIG))

            # Insertar todos los módulos como PENDIENTE
            for orden, nombre, funcion, dependencias in MODULOS_CONFIG:
                deps_str = ','.join(dependencias) if dependencias else None
                cursor.execute("""
                    INSERT INTO Etl_Pendientes_Modulo
                    (ciclo_id, modulo_nombre, funcion_nombre, orden_ejecucion, dependencias, estado)
                    VALUES (?, ?, ?, ?, ?, 'PENDIENTE')
                """, ciclo_id, nombre, funcion, orden, deps_str)

            conn.commit()

            logging.info(f"✅ Nuevo ciclo creado: {ciclo_id} con {len(MODULOS_CONFIG)} módulos")
            etl.notificar_telegram(f"🚀 Nuevo ciclo ETL iniciado: {ciclo_id}")

            return ciclo_id

    except Exception as e:
        logging.error(f"❌ Error obtener/crear ciclo: {e}")
        return None


def obtener_modulos_ejecutables(etl, ciclo_id):
    """
    Retorna lista de módulos pendientes cuyas dependencias YA están COMPLETADAS.
    """

    try:
        with pyodbc.connect(etl.conn_str) as conn:
            cursor = conn.cursor()

            # Obtener módulos completados del ciclo
            cursor.execute("""
                SELECT modulo_nombre
                FROM Etl_Pendientes_Modulo
                WHERE ciclo_id = ? AND estado = 'COMPLETADO'
            """, ciclo_id)

            completados = set([row[0] for row in cursor.fetchall()])

            # Obtener módulos pendientes o failed con intentos disponibles
            cursor.execute("""
                SELECT id, modulo_nombre, funcion_nombre, orden_ejecucion, dependencias, intentos, max_intentos
                FROM Etl_Pendientes_Modulo
                WHERE ciclo_id = ?
                  AND estado IN ('PENDIENTE', 'FAILED')
                  AND intentos < max_intentos
                ORDER BY orden_ejecucion
            """, ciclo_id)

            ejecutables = []
            for row in cursor.fetchall():
                modulo_id, nombre, funcion, orden, deps_str, intentos, max_intentos = row

                # Verificar dependencias
                if deps_str:
                    dependencias = deps_str.split(',')
                    deps_completadas = all(dep in completados for dep in dependencias)
                    if not deps_completadas:
                        continue

                ejecutables.append({
                    'id': modulo_id,
                    'nombre': nombre,
                    'funcion': funcion,
                    'orden': orden,
                    'intentos': intentos
                })

            return ejecutables

    except Exception as e:
        logging.error(f"❌ Error obtener ejecutables: {e}")
        return []


def ejecutar_modulo_pendiente(etl, ciclo_id, modulo_info):
    """Ejecuta un módulo individual y actualiza su estado"""

    nombre = modulo_info['nombre']
    funcion_nombre = modulo_info['funcion']

    try:
        # Marcar como EJECUTANDO
        with pyodbc.connect(etl.conn_str) as conn:
            cursor = conn.cursor()
            cursor.execute("""
                UPDATE Etl_Pendientes_Modulo
                SET estado = 'EJECUTANDO',
                    fecha_inicio = GETUTCDATE(),
                    intentos = intentos + 1
                WHERE id = ?
            """, modulo_info['id'])
            conn.commit()

        logging.info(f"▶️ Ejecutando: {nombre} (intento {modulo_info['intentos'] + 1})")

        # Obtener la función del módulo
        funcion_modulo = getattr(etl, funcion_nombre, None)
        if not funcion_modulo:
            raise Exception(f"Función {funcion_nombre} no encontrada")

        # Ejecutar el módulo
        start = time.time()
        resultado = etl.ejecutar_modulo(nombre, funcion_modulo)
        duracion = time.time() - start

        # Marcar como COMPLETADO (verificar si status comienza con ✅)
        status = resultado.get('status', '') if resultado else ''
        if resultado and status and '✅' in status:
            with pyodbc.connect(etl.conn_str) as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    UPDATE Etl_Pendientes_Modulo
                    SET estado = 'COMPLETADO',
                        fecha_fin = GETUTCDATE(),
                        duracion_segundos = ?,
                        registros_procesados = ?
                    WHERE id = ?
                """, int(duracion), 0, modulo_info['id'])
                conn.commit()

            logging.info(f"✅ {nombre} completado en {duracion:.1f}s")
        else:
            raise Exception(f"Estado incierto: {resultado}")

    except Exception as e:
        # Marcar como FAILED
        try:
            es_degradado_conocido = nombre in MODULOS_DEGRADADOS_CONOCIDOS
            with pyodbc.connect(etl.conn_str) as conn:
                cursor = conn.cursor()
                cursor.execute("""
                    UPDATE Etl_Pendientes_Modulo
                    SET estado = 'FAILED',
                        fecha_fin = GETUTCDATE(),
                        mensaje_error = ?,
                        proximo_intento = DATEADD(minute, 30, GETUTCDATE()),
                        intentos = CASE WHEN ? = 1 THEN max_intentos ELSE intentos END
                    WHERE id = ?
                """, str(e)[:500], 1 if es_degradado_conocido else 0, modulo_info['id'])
                conn.commit()

            logging.error(f"❌ {nombre} FAILED: {e}")
        except Exception as db_error:
            logging.error(f"❌ Error guardar FAILED: {db_error}")


def ejecutar_sps_portal(conn, cursor, ciclo_id, etl):
    """Ejecuta los 5 SPs del portal post-ciclo ETL con manejo individual de errores."""
    sps = [
        "EXEC dbo.sp_Actualizar_Resumen_Ventas",
        "EXEC dbo.sp_Actualizar_Resumen_Inventario",
        "EXEC dbo.sp_Actualizar_Resumen_Clinico",
        "EXEC dbo.sp_Actualizar_Resumen_Recaudo",
        "EXEC dbo.sp_Actualizar_Resumen_Eficiencia"
    ]

    sp_resultados = []

    for sp in sps:
        sp_nombre = sp.split('.')[-1]
        try:
            logging.info(f"[SPs-PORTAL] Ejecutando: {sp_nombre}")
            cursor.execute(sp)
            conn.commit()
            logging.info(f"[SPs-PORTAL] ✅ {sp_nombre} completado")
            sp_resultados.append((sp_nombre, True))
        except Exception as e:
            logging.error(f"[SPs-PORTAL] ❌ {sp_nombre} ERROR: {e}")
            sp_resultados.append((sp_nombre, False))

    # Verificar si todos fallaron
    todos_fallaron = all(not success for _, success in sp_resultados)

    if todos_fallaron:
        msg = f"⚠️ SPs portal fallaron post-ciclo {ciclo_id}"
        logging.error(msg)
        try:
            etl.notificar_telegram(msg)
        except Exception as notify_err:
            logging.error(f"Error notificando fallo de SPs: {notify_err}")
    else:
        exitosos = sum(1 for _, success in sp_resultados if success)
        logging.info(f"[SPs-PORTAL] {exitosos}/{len(sps)} SPs completados exitosamente")


def trigger_sitio_web(ciclo_id):
    """Notifica al portal Next.js que los resúmenes ya se actualizaron, para revalidar su caché.
    Fail-safe: cualquier fallo aquí se registra pero NUNCA interrumpe ni revierte el ETL.
    NOTA: NO ejecuta los SPs de resumen; eso ya lo hace ejecutar_sps_portal() antes de esta llamada.
    """
    token_secreto = os.getenv("REVALIDATE_SECRET_TOKEN")
    if not token_secreto:
        logging.warning("[REVALIDATE] REVALIDATE_SECRET_TOKEN no configurado. Se omite revalidación.")
        return

    url_api = f"https://opticolorkpi.com/api/revalidate?secret={token_secreto}"

    try:
        logging.info(f"[REVALIDATE] Notificando al portal tras ciclo {ciclo_id}...")
        response = requests.post(url_api, timeout=(5, 15))
        if response.status_code == 200:
            logging.info(f"[REVALIDATE] ✅ Portal revalidado OK (ciclo {ciclo_id})")
        elif response.status_code == 401:
            logging.warning("[REVALIDATE] ⚠️ 401: el token del ETL no coincide con el del portal.")
        else:
            logging.warning(f"[REVALIDATE] ⚠️ Respuesta {response.status_code}: {response.text[:200]}")
    except requests.exceptions.Timeout:
        logging.warning("[REVALIDATE] ⚠️ Timeout (no crítico; la petición pudo haberse enviado igual).")
    except Exception as e:
        logging.warning(f"[REVALIDATE] ⚠️ No se pudo conectar con el portal (no crítico): {e}")


def verificar_y_cerrar_ciclo(etl, ciclo_id):
    """Verifica si todos los módulos completaron y cierra el ciclo"""

    try:
        with pyodbc.connect(etl.conn_str) as conn:
            cursor = conn.cursor()

            cursor.execute("""
                SELECT
                    COUNT(*) as total,
                    SUM(CASE WHEN estado = 'COMPLETADO' THEN 1 ELSE 0 END) as completados,
                    SUM(CASE WHEN estado = 'FAILED' AND intentos >= max_intentos THEN 1 ELSE 0 END) as failed_max
                FROM Etl_Pendientes_Modulo
                WHERE ciclo_id = ?
            """, ciclo_id)

            total, completados, failed_max = cursor.fetchone()

            # Si todos están en estado final (completado o failed con max intentos)
            if (completados + failed_max) >= total:
                estado_final = 'COMPLETADO' if failed_max == 0 else 'INCOMPLETO'

                cursor.execute("""
                    UPDATE Etl_Ciclos
                    SET estado = ?,
                        fecha_fin = GETUTCDATE(),
                        modulos_completados = ?,
                        modulos_failed = ?,
                        duracion_minutos = DATEDIFF(minute, fecha_inicio, GETUTCDATE())
                    WHERE ciclo_id = ?
                """, estado_final, completados, failed_max, ciclo_id)
                conn.commit()

                logging.info(f"🎯 Ciclo {ciclo_id} cerrado: {estado_final}")
                logging.info(f"   ✅ Completados: {completados}/{total}")
                logging.info(f"   ❌ Failed: {failed_max}")

                if estado_final == 'COMPLETADO':
                    ejecutar_sps_portal(conn, cursor, ciclo_id, etl)
                    trigger_sitio_web(ciclo_id)
                    etl.notificar_telegram(f"✅ Ciclo {ciclo_id} COMPLETADO\n{completados}/{total} módulos OK")
                else:
                    etl.notificar_telegram(f"⚠️ Ciclo {ciclo_id} INCOMPLETO\n✅ {completados}/{total} OK\n❌ {failed_max} failed")
            else:
                logging.info(f"⏳ Ciclo {ciclo_id} en progreso: {completados}/{total} completados")

    except Exception as e:
        logging.error(f"❌ Error verificar/cerrar ciclo: {e}")


# --- SECCIÓN 2: CLASE DE LÓGICA GesvisionEtl ---

class GesvisionEtl:
    # --- TABLERO DE CONTROL DE CARGA (GRANULAR) ---
    # 'HISTORICAL': Carga masiva/backfill (Fecha fija 2024, Auto-Resume con Count).
    # 'INCREMENTAL': Mantenimiento diario (Últimos 3 días, Skip 0).
    # 'FULL': Barrido completo (Para dimensiones pequeñas).

    LOAD_MODE_CUSTOMERS = 'INCREMENTAL'  # Últimos 10 días (cambios recientes).
    LOAD_MODE_ORDERS    = 'INCREMENTAL'  # Mantenimiento diario post-backfill (2,161 pedidos históricos completados).
    LOAD_MODE_INVOICES  = 'INCREMENTAL'  # ✅ Backfill COMPLETADO (2,573 facturas). Ahora INCREMENTAL (últimos 10 días).
    LOAD_MODE_INVENTORY = 'INCREMENTAL'  # Control de stock — Mantenimiento diario post-backfill (146,707 items completados).
    LOAD_MODE_EXAMS     = 'INCREMENTAL'  # Mantenimiento diario (últimos 10 días post-backfill).
    LOAD_MODE_PRODUCTS  = 'INCREMENTAL'  # Mantenimiento diario post-backfill (143,854 productos cargados).
    LOAD_MODE_CITAS     = 'INCREMENTAL'  # Agenda.
    LOAD_MODE_METODOS_PAGO = 'INCREMENTAL'     # Catálogo pequeño.
    LOAD_MODE_COBROS    = 'INCREMENTAL'  # ✅ Backfill COMPLETADO (4,608 cobros). Ahora INCREMENTAL (últimas 2 horas).
    LOAD_MODE_TREASURY  = 'INCREMENTAL'  # Movimientos de caja/banco.
    LOAD_MODE_LAB       = 'INCREMENTAL'  # Pedidos de laboratorio.
    LOAD_MODE_RECEPCIONES = 'INCREMENTAL' # Carga inicial de recepciones.
    LOAD_MODE_GLASSES_ORDERS = 'INCREMENTAL' # Carga de órdenes de cristales (Historical/Incremental).

    # --- TABLERO DE VERSIÓN DE API POR MÓDULO (Fase 2) ---
    # 'V1'                : solo API v1 (estado actual)
    # 'V1+V2_ENRIQUECE'   : v1 es dueño; v2 solo UPDATE de columnas USD
    # 'V2'                : v2 dueño total (post-validación de paridad)
    API_VERSION_VENTAS = 'V1+V2_ENRIQUECE'

    # Base de la API v2
    BASE_URL_V2 = "https://app.gesvision.com/api/v2"
    LOAD_MODE_DOLAR_VENTAS = 'INCREMENTAL'   # 'HISTORICAL' para el backfill

    API_VERSION_PEDIDOS = 'V1+V2_ENRIQUECE'
    LOAD_MODE_DOLAR_PEDIDOS = 'INCREMENTAL'   # backfill primero; luego 'INCREMENTAL'

    # --- CONSTANTES DE MAPEO CENTRALIZADO PARA MANTENIBILIDAD ---
    # --- CONSTANTES DE MAPEO ACTUALIZADAS ---
    MAP_SUCURSAL = { 'id': 'id_sucursal', 'name': 'nombre_sucursal', 'alias': 'alias_sucursal', 'municipality': 'municipio_raw', 'locality': 'localidad_raw', 'street': 'direccion_raw' }
    MAP_CLIENTE = {
    'id': 'id_cliente', 
    'name': 'nombre', 
    'lastName': 'apellido',
    'birthDate': 'fecha_nacimiento', 
    'genre': 'genero',                # <--- Nuevo campo para segmentación del KPI 1
    'creationDate': 'fecha_creacion_cliente',
    'telefono_principal': 'telefono_principal', 
    'email': 'email',
    'codigo_postal': 'codigo_postal', 
    'ciudad': 'ciudad',
    'idCard': 'cedula'                # <--- Documento de identidad para cruce GHL-Gesvision
    }
    MAP_EMPLEADO = {
            'id': 'id_empleado', 'warehouse': 'id_sucursal', 'type': 'tipo_empleado',
            'nombre_empleado': 'nombre_empleado' # Campo transformado
    }
    MAP_PRODUCTO = {
            'id': 'id_producto', 'description': 'nombre_producto', 'reference': 'referencia',
            'barCode': 'codigo_barras', 'pricePurchase': 'costo_compra', 'priceWithVAT': 'precio_venta',
            'brand': 'id_marca', 'category': 'id_categoria', 'inventoriable': 'es_inventariable',
            'creationDate': 'fecha_creacion', 'lastUpdateDate': 'fecha_ultima_actualizacion',
            'nombre_modelo_padre': 'nombre_modelo_padre',
            'genero_objetivo': 'genero_objetivo',
            'material_marco': 'material_marco',
            'color_comercial': 'color_comercial',
            'tipo_montura': 'tipo_montura',
            'group': 'id_grupo'
    }
    MAP_MARCA = {'id': 'id_marca', 'name': 'nombre_marca', 'code': 'codigo_marca'}
    MAP_CATEGORIA = {
            'id': 'id_categoria',
            'name': 'nombre_categoria',
            'parent': 'id_categoria_padre',
            'enable': 'esta_activo',
            'lastUpdateDate': 'fecha_actualizacion'
    }
    MAP_METODO_PAGO = {
            'id': 'id_metodo_pago',
            'name': 'nombre_metodo',
            'description': 'descripcion',
            'code': 'codigo_interno',
            'useInIncome': 'usa_en_ingresos',
            'useInExpenses': 'usa_en_gastos',
            'enabled': 'es_activo',
            'payType': 'tipo_pago_codigo'
    }
    MAP_PROVEEDOR = {
            'id': 'id_proveedor',
            'name': 'nombre_proveedor',
            'idCard': 'ruc_proveedor',
            'code': 'codigo_interno',
            'email': 'email_contacto',
            'mobile': 'telefono_contacto',
            'countryCode': 'pais',
            'creationDate': 'fecha_creacion_origen'
    }
    MAP_EXAMEN = {
            'id': 'id_examen', 'customer': 'id_cliente', 'warehouse': 'id_sucursal',
            'optometrist': 'id_empleado', 'date': 'fecha_examen', 'observations': 'observaciones',
            'examType': 'tipo_examen'
    }
    MAP_VENTA = {
    'id': 'id_factura', 
    'customer': 'id_cliente', 
    'warehouse': 'id_sucursal',
    'invoiceDate': 'fecha_factura', 
    'totalPay': 'monto_total', 
    'employee': 'id_empleado',      # CAMBIADO: Antes decía 'seller'
    'optometrist': 'id_optometrista' # AGREGADO: Para medir productividad clínica
    }
    MAP_PEDIDO = {
            'id': 'id_pedido', 'number': 'numero_pedido', 'date': 'fecha_pedido',
            'warehouse': 'id_sucursal', 'employee': 'id_empleado', 'customer': 'id_cliente',
            'monto_total': 'monto_total', 'monto_pagado': 'monto_pagado',
            'saldo_pendiente': 'saldo_pendiente', 'estado_pedido': 'estado_pedido',
            'documentStatus': 'id_estado_orden'
    }
    MAP_INVENTARIO = {
            'product': 'id_producto',
            'warehouse': 'id_sucursal',
            'quantity': 'cantidad_disponible',
            'quantityReserved': 'cantidad_reservada',
            'minStock': 'stock_minimo',
            'lastPurchasePrice': 'costo_promedio',
            'lastUpdated': 'fecha_actualizacion'
    }
    MAP_CITAS = {
            'cliente_id': 'id_cliente',
            'startDate': 'fecha_cita_inicio',
            'endDate': 'fecha_cita_fin',
            'meetingType': 'tipo_cita_id',
            'meetingType_name': 'tipo_cita_nombre',
            'details': 'detalles_cita',
            'creationDate': 'fecha_creacion_cita',
            'lastUpdateDate': 'fecha_actualizacion_api',
            'nombre_cliente': 'nombre_cliente'
    }
    MAP_COBROS = {
            'id': 'id_cobro', 'customer': 'id_cliente', 'invoice_id': 'id_factura',
            'order': 'id_pedido', 'warehouse': 'id_sucursal', 'amount': 'monto_cobrado',
            'payType': 'metodo_pago_nombre', 'delivery': 'monto_entrega',
            'moneyExchange': 'monto_cambio', 'date': 'fecha_cobro',
            'createdBy': 'usuario_creacion'
    }
    MAP_TREASURY = {
            'id': 'id_pago_tesoreria', 'warehouse': 'id_sucursal', 'date': 'fecha_movimiento',
            'amount': 'monto', 'description': 'descripcion', 'type': 'tipo_movimiento',
            'payType': 'metodo_pago_nombre', 'paymentAccount': 'id_cuenta_contable',
            'createdBy': 'usuario_creacion'
    }
    MAP_LAB = {
            'id': 'id_pedido_lab', 'glassesOrderId': 'id_pedido_origen',
            'reasonSocialThird': 'proveedor_nombre', 'warehouse': 'id_sucursal',
            'date': 'fecha_solicitud', 'total': 'monto_costo',
            'dateLastChangeFabricationState': 'estatus_proceso',
            'manufacturingDate': 'fecha_fabricacion', 'createdBy': 'usuario_creacion'
    }
    MAP_RECEPCION_LAB = {
            'id_recepcion_linea': 'id_recepcion_linea',
            'id_albaran': 'id_albaran',
            'numero_albaran': 'numero_albaran',
            'id_proveedor': 'id_proveedor',
            'id_pedido_origen': 'id_pedido_origen',
            'fecha_recepcion': 'fecha_recepcion',
            'fecha_recepcion_exacta': 'fecha_recepcion_exacta',
            'costo_linea_recepcion': 'costo_linea_recepcion'
    }
    MAP_ORDENES_CRISTALES = {
            'id': 'id_orden_cristal', 'code': 'codigo_orden', 'number': 'numero_orden',
            'customerId': 'id_cliente', 'warehouseId': 'id_sucursal',
            'issuedOrderId': 'id_pedido_venta', 'receivedOrderId': 'id_pedido_compra',
            'observations': 'observaciones', 'date': 'fecha_creacion',
            'od_tipo_lente': 'od_tipo_lente', 'od_material': 'od_material',
            'od_esfera': 'od_esfera', 'od_cilindro': 'od_cilindro', 'od_eje': 'od_eje', 'od_adicion': 'od_adicion', 'od_altura': 'od_altura',
            'oi_tipo_lente': 'oi_tipo_lente', 'oi_material': 'oi_material',
            'oi_esfera': 'oi_esfera', 'oi_cilindro': 'oi_cilindro', 'oi_eje': 'oi_eje', 'oi_adicion': 'oi_adicion', 'oi_altura': 'oi_altura'
    }

    def __init__(self):
            # --- Gesvision API ---
            self.base_url = os.getenv("GESVISION_BASE_URL", "https://app.gesvision.com/gesmo/rest/api")
            self.user = os.getenv("GESVISION_USER")
            self.password = os.getenv("GESVISION_PASS")
            self.token = None

            # --- Infraestructura ---
            self.conn_str = os.getenv("SQL_AZURE_CONNECTION_STRING")
            self.schema_cache = {}
            self.session = requests.Session()

            # --- RASTREO DE ANOMALÍAS ---
            self.modulos_con_fallo_api = {}  # {modulo: "tipo de error"}
            self.current_module = None

    def get_token(self):
            """Gestiona la autenticación con la API de Gesvision."""
            url = f"{self.base_url}/auth/signin"
            resp = self.session.post(url, json={"username": self.user, "password": self.password}, timeout=(15, 90))
            content = resp.text.strip()
            self.token = content.replace("Bearer ", "").strip() if content.startswith("Bearer ") else content

    def _safe_parse_json(self, resp, endpoint_name="unknown"):
            """Parseo defensivo (Fail-Safe) de respuestas JSON de la API.
            
            Valida que el cuerpo no esté vacío antes de llamar a .json().
            Si el body está vacío o es JSON inválido, retorna [] sin lanzar excepción
            para que el ETL pueda continuar con los siguientes módulos.
            """
            # 1. Validar cuerpo vacío (0 bytes o solo whitespace)
            body_text = resp.text.strip() if resp.text else ""
            if not body_text:
                error_msg = "API Vacía (200 OK)"
                logging.warning(
                    f"⚠️ [FAIL-SAFE] API '{endpoint_name}' respondió HTTP {resp.status_code} "
                    f"pero el cuerpo está vacío (0 bytes). Se asumen 0 registros."
                )
                if self.current_module:
                    self.modulos_con_fallo_api[self.current_module] = error_msg
                return []

            # 2. Intentar parsear JSON con protección contra texto inválido
            try:
                return resp.json()
            except (ValueError, json.JSONDecodeError) as e:
                error_msg = f"JSON Inválido: {str(e)[:50]}"
                logging.warning(
                    f"⚠️ [FAIL-SAFE] API '{endpoint_name}' respondió HTTP {resp.status_code} "
                    f"pero el body no es JSON válido: {e}. Primeros 200 chars: {body_text[:200]}"
                )
                if self.current_module:
                    self.modulos_con_fallo_api[self.current_module] = error_msg
                return []

    def notificar_telegram(self, mensaje, silencioso=False):
            """Envía notificaciones a Telegram con reintentos exponenciales."""
            token = os.getenv("TELEGRAM_BOT_TOKEN")
            chat_id = os.getenv("TELEGRAM_CHAT_ID")
            if not token or not chat_id:
                logging.warning("Credenciales Telegram no configuradas")
                return

            url = f"https://api.telegram.org/bot{token}/sendMessage"
            payload = {
                "chat_id": chat_id,
                "text": mensaje,
                "disable_notification": silencioso
            }

            # Reintentos exponenciales: 1s, 2s, 4s (máximo 3 intentos)
            max_retries = 3
            for attempt in range(max_retries):
                try:
                    logging.info(f"[TELEGRAM] Intento {attempt+1}/{max_retries} — enviando a {chat_id}...")
                    response = requests.post(url, json=payload, timeout=(5, 10))

                    if response.status_code == 200:
                        logging.info(f"[TELEGRAM] ✅ OK — Mensaje enviado en intento {attempt+1}")
                        return  # ÉXITO, salir
                    else:
                        logging.warning(f"[TELEGRAM] Error {response.status_code}: {response.text}")

                except requests.exceptions.Timeout:
                    logging.warning(f"[TELEGRAM] Timeout en intento {attempt+1}")
                except Exception as e:
                    logging.warning(f"[TELEGRAM] Excepción en intento {attempt+1}: {e}")

                # Reintentar con espera exponencial (1s, 2s, 4s)
                if attempt < max_retries - 1:
                    wait_time = 2 ** attempt
                    logging.info(f"[TELEGRAM] Esperando {wait_time}s antes de reintentar...")
                    time.sleep(wait_time)

            # Si llegamos aquí, todos los intentos fallaron
            logging.error(f"[TELEGRAM] ❌ Falló después de {max_retries} intentos. Mensaje NO enviado.")

    def enviar_resumen_ciclo_telegram(self, reporte, duracion_min, error_critico=None):
            """Envía reporte final minimalista al fin del ciclo."""
            try:
                fin_ts = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")

                if error_critico:
                    msg = f"❌ ETL Opticolor error — {fin_ts} — {error_critico}"
                else:
                    modulos_ok = [i for i in reporte if i and i.get('status', '').startswith('✅')]
                    modulos_err = [i for i in reporte if i and i.get('status', '').startswith('❌')]
                    total_registros = sum(i['resultado'] for i in modulos_ok if isinstance(i.get('resultado'), int))

                    if modulos_err:
                        fallas = "\n".join(f"  ❌ {i['modulo']}: {i['resultado']}" for i in modulos_err)
                        msg = f"⚠️ ETL Opticolor — {fin_ts} — {len(modulos_ok)}/{len(reporte)} módulos OK — {duracion_min:.1f} min\nFALLOS:\n{fallas}"
                    else:
                        msg = f"✅ ETL completado — {fin_ts} — {total_registros} registros totales — {duracion_min:.1f} min"

                self.notificar_telegram(msg)
            except Exception as e:
                logging.error(f"Error generando reporte Telegram: {e}")

    def ejecutar_modulo(self, nombre_modulo, funcion_sync):
            """Wrapper para ejecutar un módulo, registrar estado y manejar errores."""
            start_mod = time.time()
            logging.info(f"[MÓDULO {nombre_modulo}] Iniciando...")
            self.registrar_inicio(nombre_modulo)
            self.current_module = nombre_modulo

            try:
                resultado = funcion_sync()
                elapsed_mod = (time.time() - start_mod)
                self.registrar_fin(nombre_modulo, 'COMPLETADO')

                # Enriquecer estatus con resultado si es posible (ej: recuento de registros)
                status_final = '✅'
                if isinstance(resultado, int):
                    status_final = f"✅ ({resultado} registros)"
                elif isinstance(resultado, str) and 'Total:' in resultado:
                    status_final = f"✅ {resultado}"

                logging.info(f"[MÓDULO {nombre_modulo}] Completado en {elapsed_mod:.2f}s — {status_final}")
                return {'modulo': nombre_modulo, 'status': status_final, 'resultado': resultado}
            except Exception as e:
                elapsed_mod = (time.time() - start_mod)
                tb = traceback.extract_tb(e.__traceback__)
                origen = f"{tb[-1].name}:{tb[-1].lineno}" if tb else "?"
                logging.error(f"[MÓDULO {nombre_modulo}] Error después de {elapsed_mod:.2f}s en {origen}: {e}\n{traceback.format_exc()}")
                self.registrar_fin(nombre_modulo, 'ERROR', e)
                es_degradado_conocido = nombre_modulo in MODULOS_DEGRADADOS_CONOCIDOS
                if not es_degradado_conocido:
                    self.notificar_telegram(f"❌ ETL [{nombre_modulo}] FALLÓ en {elapsed_mod:.1f}s\n📍 {origen}\n{str(e)[:300]}")
                else:
                    logging.info(f"   [DEGRADACIÓN CONOCIDA] {nombre_modulo} falló como es esperado "
                                  f"({MODULOS_DEGRADADOS_CONOCIDOS[nombre_modulo]}). Alerta de Telegram omitida.")
                return {'modulo': nombre_modulo, 'status': '❌', 'resultado': f"ERROR: {str(e)[:200]}"}
            finally:
                self.current_module = None

    def registrar_inicio(self, modulo):
            """Marca el inicio de ejecución en la tabla de control."""
            try:
                with pyodbc.connect(self.conn_str) as conn:
                    cursor = conn.cursor()
                    # Asegurar tabla (Idempotente)
                    cursor.execute("""
                        IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Etl_Control_Ejecucion' AND xtype='U')
                        CREATE TABLE Etl_Control_Ejecucion (
                            modulo_nombre VARCHAR(50) PRIMARY KEY,
                            ultimo_estatus VARCHAR(20),
                            fecha_inicio DATETIME,
                            fecha_fin DATETIME,
                            mensaje_error NVARCHAR(MAX)
                        )
                    """)
                    cursor.execute("""
                        MERGE Etl_Control_Ejecucion AS target
                        USING (SELECT ? AS modulo_nombre) AS source
                        ON (target.modulo_nombre = source.modulo_nombre)
                        WHEN MATCHED THEN
                            UPDATE SET ultimo_estatus = 'PROCESANDO', fecha_inicio = GETDATE(), mensaje_error = NULL
                        WHEN NOT MATCHED THEN
                            INSERT (modulo_nombre, ultimo_estatus, fecha_inicio) VALUES (source.modulo_nombre, 'PROCESANDO', GETDATE());
                    """, modulo)
                    conn.commit()
            except Exception as e:
                logging.error(f"Error registrando inicio de {modulo}: {e}")

    def registrar_fin(self, modulo, estatus, error=None):
            """Marca el fin de ejecución."""
            try:
                with pyodbc.connect(self.conn_str) as conn:
                    cursor = conn.cursor()
                    cursor.execute("""
                        UPDATE Etl_Control_Ejecucion
                        SET ultimo_estatus = ?, fecha_fin = GETDATE(), mensaje_error = ?
                        WHERE modulo_nombre = ?
                    """, estatus, str(error)[:500] if error else None, modulo)
                    conn.commit()
            except Exception as e:
                logging.error(f"Error registrando fin de {modulo}: {e}")

    def _verificar_sucursales_pendientes(self):
            """Consulta sucursales sin clasificar y retorna count + top 5."""
            try:
                with pyodbc.connect(self.conn_str) as conn:
                    cursor = conn.cursor()

                    # Obtener conteo total de pendientes
                    cursor.execute("SELECT COUNT(*) FROM Vw_Sucursales_Pendientes_Clasificacion")
                    total = cursor.fetchone()[0]

                    if total == 0:
                        return None

                    # Obtener top 5 pendientes
                    cursor.execute("""
                        SELECT TOP 5 id_sucursal, nombre_sucursal, dias_sin_clasificar
                        FROM Vw_Sucursales_Pendientes_Clasificacion
                        ORDER BY dias_sin_clasificar DESC
                    """)

                    registros = []
                    for row in cursor.fetchall():
                        registros.append({
                            'id_sucursal': row[0],
                            'nombre_sucursal': row[1],
                            'dias_sin_clasificar': row[2]
                        })

                    return {'total': total, 'registros': registros}

            except Exception as e:
                logging.warning(f"⚠️ Error verificando sucursales pendientes: {e}")
                return None

    def _notificar_sucursales_pendientes(self, registros, total):
            """Envía notificación Telegram sobre sucursales pendientes de clasificación."""
            try:
                # Seleccionar emoji según criticidad del total
                if total <= 3:
                    emoji = "⚠️"
                elif total <= 10:
                    emoji = "🟠"
                else:
                    emoji = "🔴"

                msg = f"{emoji} SUCURSALES SIN CLASIFICAR: {total}\n\n"
                msg += "Llegaron de Gesvision sin estado/zona asignada.\n"
                msg += "Campos requeridos: Estado venezolano + Zona gerencial\n"
                msg += "Campos opcionales: Tipo punto de venta, Coordenadas\n\n"
                msg += f"Top pendientes ({total} total):\n"

                for reg in registros:
                    id_suc = reg.get('id_sucursal', '?')
                    nombre = reg.get('nombre_sucursal', 'Sin nombre')
                    dias = reg.get('dias_sin_clasificar', 0)
                    msg += f"• #{id_suc} {nombre} — {dias} días sin clasificar\n"

                msg += "\n📋 Pasos:\n"
                msg += "1. Entra al portal → Admin → Sucursales\n"
                msg += "2. Busca las marcadas como PENDIENTE 🔴\n"
                msg += "3. Asigna Estado + Zona → Guardar\n"
                msg += "\n🔗 https://app-portal-opticolor-prd.livelyglacier-d04261ef.westus3.azurecontainerapps.io/admin/sucursales"

                self.notificar_telegram(msg)
                logging.info(f"Notificación de sucursales pendientes enviada ({total} pendientes, criticidad: {emoji})")

            except Exception as e:
                logging.warning(f"⚠️ Error notificando sucursales pendientes: {e}")


    def predecesor_listo(self, modulo_padre):
            """Verifica si el módulo padre completó exitosamente."""
            if not modulo_padre: return True
            try:
                with pyodbc.connect(self.conn_str) as conn:
                    cursor = conn.cursor()
                    cursor.execute("SELECT ultimo_estatus FROM Etl_Control_Ejecucion WHERE modulo_nombre = ?", modulo_padre)
                    row = cursor.fetchone()
                    if row and row[0] == 'COMPLETADO':
                        return True
                    return False
            except Exception as e:
                logging.error(f"Error verificando predecesor {modulo_padre}: {e}")
                return False

    def get_last_date(self, conn, table_name, date_column):
            """Consulta fecha máxima. Lanza error si falla para proteger la integridad."""
            try:
                with conn.cursor() as cursor:
                    cursor.execute(f"SELECT MAX({date_column}) FROM {table_name}")
                    row = cursor.fetchone()
                    db_last_date = row[0] if row and row[0] else None

                    current_time = datetime.datetime.utcnow()

                    if db_last_date:
                        # FIX: Asegurar que sea datetime para comparación
                        if isinstance(db_last_date, datetime.date) and not isinstance(db_last_date, datetime.datetime):
                            db_last_date = datetime.datetime.combine(db_last_date, datetime.time.min)

                        # Escudo contra Fechas Futuras: Si la fecha de la DB es mayor a la actual,
                        # significa un error de captura o desfase. Ajustamos a 1 hora antes de ahora.
                        if db_last_date > current_time:
                            adjusted_time = current_time - datetime.timedelta(hours=1)
                            logging.warning(f"   [Escudo Fechas Futuras] Fecha {db_last_date} de {table_name} es futura. Ajustando a {adjusted_time} para evitar saltos en la carga incremental.")
                            return adjusted_time
                        else:
                            return db_last_date
                    return datetime.datetime(2025, 1, 1, 0, 0, 0)
            except Exception as e:
                logging.error(f"Fallo de acceso a tabla {table_name} para fecha: {e}")
                raise

    def get_last_id(self, conn, table_name, id_column):
            """Obtiene el ID máximo actual en SQL para carga incremental."""
            try:
                with conn.cursor() as cursor:
                    cursor.execute(f"SELECT MAX({id_column}) FROM {table_name}")
                    row = cursor.fetchone()
                    return row[0] if row and row[0] else 0
            except Exception as e:
                logging.warning(f"No se pudo determinar último ID en {table_name}: {e}")
                return 0

    def _sanitize_sucursal(self, item):
            """Limpia datos de sucursales: mayúsculas, sin caracteres especiales, espacios extras."""
            import unicodedata
            import re

            def clean_text(text):
                if not text or not isinstance(text, str):
                    return text
                text = text.strip()
                text = unicodedata.normalize('NFD', text)
                text = ''.join(c for c in text if unicodedata.category(c) != 'Mn')
                text = text.upper()
                text = re.sub(r'\s+', ' ', text)
                return text

            item['name'] = clean_text(item.get('name'))
            item['alias'] = clean_text(item.get('alias'))
            item['municipality'] = clean_text(item.get('municipality')) if item.get('municipality') not in ['0', '1'] else item.get('municipality')
            item['locality'] = clean_text(item.get('locality')) if item.get('locality') not in ['0', '1'] else item.get('locality')
            item['street'] = clean_text(item.get('street'))
            return item

    def _sanitize_empleado(self, item):
            """Limpia datos de empleados: mayúsculas, sin caracteres especiales."""
            import unicodedata
            import re

            def clean_text(text):
                if not text or not isinstance(text, str):
                    return text
                text = text.strip()
                text = unicodedata.normalize('NFD', text)
                text = ''.join(c for c in text if unicodedata.category(c) != 'Mn')
                text = text.upper()
                text = re.sub(r'\s+', ' ', text)
                return text

            item['name'] = clean_text(item.get('name'))
            item['lastName'] = clean_text(item.get('lastName'))
            item['type'] = clean_text(item.get('type'))
            return item

    def _sanitize_categoria(self, item):
            """Limpia datos de categorías: mayúsculas, sin caracteres especiales."""
            import unicodedata
            import re

            def clean_text(text):
                if not text or not isinstance(text, str):
                    return text
                text = text.strip()
                text = unicodedata.normalize('NFD', text)
                text = ''.join(c for c in text if unicodedata.category(c) != 'Mn')
                text = text.upper()
                text = re.sub(r'\s+', ' ', text)
                return text

            item['name'] = clean_text(item.get('name'))
            return item

    def _sanitize_metodo_pago(self, item):
            """Limpia datos de métodos de pago: mayúsculas, sin caracteres especiales."""
            import unicodedata
            import re

            def clean_text(text):
                if not text or not isinstance(text, str):
                    return text
                text = text.strip()
                text = unicodedata.normalize('NFD', text)
                text = ''.join(c for c in text if unicodedata.category(c) != 'Mn')
                text = text.upper()
                text = re.sub(r'\s+', ' ', text)
                return text

            item['name'] = clean_text(item.get('name'))
            item['description'] = clean_text(item.get('description'))
            item['code'] = clean_text(item.get('code'))
            return item

    def _sanitize_proveedor(self, item):
            """Limpia datos de proveedores: mayúsculas, sin caracteres especiales."""
            import unicodedata
            import re

            def clean_text(text):
                if not text or not isinstance(text, str):
                    return text
                text = text.strip()
                text = unicodedata.normalize('NFD', text)
                text = ''.join(c for c in text if unicodedata.category(c) != 'Mn')
                text = text.upper()
                text = re.sub(r'\s+', ' ', text)
                return text

            item['name'] = clean_text(item.get('name'))
            item['code'] = clean_text(item.get('code'))
            return item

    def _sanitize_marca(self, item):
            """Limpia datos de marcas: mayúsculas, sin caracteres especiales."""
            import unicodedata
            import re

            def clean_text(text):
                if not text or not isinstance(text, str):
                    return text
                text = text.strip()
                text = unicodedata.normalize('NFD', text)
                text = ''.join(c for c in text if unicodedata.category(c) != 'Mn')
                text = text.upper()
                text = re.sub(r'\s+', ' ', text)
                return text

            item['name'] = clean_text(item.get('name'))
            item['code'] = clean_text(item.get('code'))
            return item

    def _sanitize_producto(self, item):
            """Limpia datos de productos: mayúsculas, sin caracteres especiales."""
            import unicodedata
            import re

            def clean_text(text):
                if not text or not isinstance(text, str):
                    return text
                text = text.strip()
                text = unicodedata.normalize('NFD', text)
                text = ''.join(c for c in text if unicodedata.category(c) != 'Mn')
                text = text.upper()
                text = re.sub(r'\s+', ' ', text)
                return text

            item['description'] = clean_text(item.get('description'))
            item['reference'] = clean_text(item.get('reference'))
            item['barCode'] = clean_text(item.get('barCode'))
            item['nombre_modelo_padre'] = clean_text(item.get('nombre_modelo_padre'))
            item['genero_objetivo'] = clean_text(item.get('genero_objetivo'))
            item['material_marco'] = clean_text(item.get('material_marco'))
            item['color_comercial'] = clean_text(item.get('color_comercial'))
            item['tipo_montura'] = clean_text(item.get('tipo_montura'))
            return item

    def _sanitize_cliente(self, item):
            """Limpia datos de clientes: mayúsculas, sin caracteres especiales."""
            import unicodedata
            import re

            def clean_text(text):
                if not text or not isinstance(text, str):
                    return text
                text = text.strip()
                text = unicodedata.normalize('NFD', text)
                text = ''.join(c for c in text if unicodedata.category(c) != 'Mn')
                text = text.upper()
                text = re.sub(r'\s+', ' ', text)
                return text

            item['name'] = clean_text(item.get('name'))
            item['lastName'] = clean_text(item.get('lastName'))
            item['ciudad'] = clean_text(item.get('ciudad'))
            return item

    def _sanitize_cita(self, item):
            """Limpia datos de citas: mayúsculas, sin caracteres especiales."""
            import unicodedata
            import re

            def clean_text(text):
                if not text or not isinstance(text, str):
                    return text
                text = text.strip()
                text = unicodedata.normalize('NFD', text)
                text = ''.join(c for c in text if unicodedata.category(c) != 'Mn')
                text = text.upper()
                text = re.sub(r'\s+', ' ', text)
                return text

            item['meetingType_name'] = clean_text(item.get('meetingType_name'))
            item['details'] = clean_text(item.get('details'))
            item['nombre_cliente'] = clean_text(item.get('nombre_cliente'))
            return item

    def _sanitize_examen(self, item):
            """Limpia datos de exámenes: mayúsculas, sin caracteres especiales."""
            import unicodedata
            import re

            def clean_text(text):
                if not text or not isinstance(text, str):
                    return text
                text = text.strip()
                text = unicodedata.normalize('NFD', text)
                text = ''.join(c for c in text if unicodedata.category(c) != 'Mn')
                text = text.upper()
                text = re.sub(r'\s+', ' ', text)
                return text

            item['tipo_examen'] = clean_text(item.get('tipo_examen'))
            item['observations'] = clean_text(item.get('observations'))
            return item

    def sync_dimensions(self):
            """Sincroniza almacenes/sucursales."""
            if not self.token: self.get_token()
            headers = {"Authorization": f"Bearer {self.token}", "accept": "application/json"}
            resp = self.session.get(f"{self.base_url}/warehouses", headers=headers, timeout=(15, 90))
            if resp.status_code == 200:
                items = self._safe_parse_json(resp, "warehouses")
                if items:
                    items = [self._sanitize_sucursal(item) for item in items]
                    with pyodbc.connect(self.conn_str) as conn:
                        self._process_and_save(conn, items, "Maestro_Sucursales", "id_sucursal", self.MAP_SUCURSAL)
                    logging.info("   -> Catálogo de sucursales actualizado con éxito.")
                return len(items)
            return 0

    def sync_categories(self):
            """Sincroniza categorías de productos (Full Upsert)."""
            if not self.token: self.get_token()
            headers = {"Authorization": f"Bearer {self.token}", "accept": "application/json"}
            
            for retry in range(3):
                try:
                    # Timeout extendido (30 connect, 90 read)
                    resp = self.session.get(f"{self.base_url}/categories", headers=headers, timeout=(15, 90))
                    
                    if resp.status_code == 200:
                        items = self._safe_parse_json(resp, "categories")
                        if items:
                            items = [self._sanitize_categoria(item) for item in items]
                            with pyodbc.connect(self.conn_str) as conn:
                                self._process_and_save(conn, items, "Maestro_Categorias", "id_categoria", self.MAP_CATEGORIA)
                        
                        # Throttling para no saturar el servidor
                        time.sleep(1)
                        return len(items)
                    elif resp.status_code == 204:
                        return 0
                    else:
                        raise Exception(f"API Error {resp.status_code}")
                except Exception as e:
                    wait_time = [5, 10, 15][retry]
                    logging.warning(f"⚠️ Reintentando Categorías ({retry+1}/3) en {wait_time}s: {e}")
                    if retry == 2: raise
                    time.sleep(wait_time)
            return 0

    def sync_payment_methods(self):
            """Sincroniza métodos de pago (Full Upsert)."""
            if not self.token: self.get_token()
            headers = {"Authorization": f"Bearer {self.token}", "accept": "application/json"}
            
            for retry in range(3):
                try:
                    # Timeout extendido (30 connect, 90 read)
                    resp = self.session.get(f"{self.base_url}/paymentMethod", headers=headers, timeout=(15, 90))
                    
                    if resp.status_code == 200:
                        items = self._safe_parse_json(resp, "paymentMethod")
                        if items:
                            items = [self._sanitize_metodo_pago(item) for item in items]
                            with pyodbc.connect(self.conn_str) as conn:
                                self._process_and_save(conn, items, "Maestro_Metodos_Pago", "id_metodo_pago", self.MAP_METODO_PAGO)
                        
                        time.sleep(1)
                        return len(items)
                    elif resp.status_code == 204:
                        return 0
                    else:
                        raise Exception(f"API Error {resp.status_code}")
                except Exception as e:
                    wait_time = [5, 10, 15][retry]
                    logging.warning(f"⚠️ Reintentando Métodos de Pago ({retry+1}/3) en {wait_time}s: {e}")
                    if retry == 2: raise
                    time.sleep(wait_time)
            return 0

    def sync_suppliers(self):
            """Sincroniza proveedores (Full Paginado)."""
            if not self.token: self.get_token()
            headers = {"Authorization": f"Bearer {self.token}", "accept": "application/json"}

            start_time = time.time()
            MAX_EXECUTION_TIME = 24 * 60
            total_processed = 0

            with pyodbc.connect(self.conn_str) as conn:
                skip = 0
                limit = 50
                
                while True:
                    if (time.time() - start_time) > MAX_EXECUTION_TIME:
                        logging.warning("   [TIMEOUT] Límite de tiempo en Proveedores.")
                        break

                    params = {"skip": skip}
                    success_batch = False
                    items = []

                    for retry in range(3):
                        try:
                            resp = self.session.get(f"{self.base_url}/suppliers", headers=headers, params=params, timeout=(15, 90))
                            logging.info(f"   -> [REQ] skip: {skip} | URL: {resp.url}")

                            if resp.status_code == 204:
                                return total_processed

                            items = self._safe_parse_json(resp, "suppliers")
                            logging.info(f"   -> [RES] Status: {resp.status_code} | Count: {len(items)}")
                            
                            success_batch = True
                            break
                        except Exception as e:
                            logging.warning(f"   [!] Reintento {retry+1} en Proveedores (Skip {skip}): {e}")
                            time.sleep(5)

                    if not success_batch:
                        logging.error(f"Fallo definitivo en Proveedores lote {skip}.")
                        break

                    if items:
                        items = [self._sanitize_proveedor(item) for item in items]
                        self._process_and_save(conn, items, "Maestro_Proveedores", "id_proveedor", self.MAP_PROVEEDOR)
                        total_processed += len(items)

                    if not items or len(items) < limit:
                        break

                    skip += limit
                    time.sleep(0.05)
            
            return total_processed

    def sync_customers(self):
            """Sincroniza clientes con estrategia Híbrida (Smart Sync)."""
            if not self.token: self.get_token()
            headers = {"Authorization": f"Bearer {self.token}", "accept": "application/json"}

            start_time = time.time()
            MAX_EXECUTION_TIME = 24 * 60
            total_processed = 0

            # Lógica Smart Sync: Si no forzamos histórico, traemos solo los últimos 1 día
            # Si LOAD_MODE_CUSTOMERS == 'HISTORICAL': Usa skip = COUNT(*) y sin filtro de fecha (carga total profunda).
            # Si LOAD_MODE_CUSTOMERS == 'INCREMENTAL': Usa skip = 0 y fechaInicial = Hace 1 día.
            params_base = {}
            if self.LOAD_MODE_CUSTOMERS == 'INCREMENTAL':
                fecha_inicio = datetime.datetime.now() - datetime.timedelta(days=1)
                params_base["fechaInicial"] = fecha_inicio.strftime("%Y-%m-%d %H:%M:%S")
                logging.info(f"   [Smart Sync] Clientes: Buscando cambios desde {params_base['fechaInicial']}")
            elif self.LOAD_MODE_CUSTOMERS == 'HISTORICAL':
                logging.info("   [Historical Load] Clientes: Descarga completa forzada.")

            with pyodbc.connect(self.conn_str) as conn:
                skip = 0
                limit = 50
                empty_pages = 0
                # --- AUTO-RESUME INTELIGENTE ---
                if self.LOAD_MODE_CUSTOMERS == 'HISTORICAL':
                    try:
                        with conn.cursor() as cursor:
                            cursor.execute("SELECT COUNT(*) FROM Maestro_Clientes")
                            row = cursor.fetchone()
                            total_rows = row[0] if row else 0
                            skip = (total_rows // limit) * limit
                            logging.info(f"   [Auto-Resume] Detectados {total_rows} clientes en SQL. Retomando desde skip {skip}.")
                    except Exception as e:
                        logging.warning(f"   [Auto-Resume] No se pudo calcular skip inicial: {e}")

                while True:
                    if (time.time() - start_time) > MAX_EXECUTION_TIME:
                        logging.warning("   [TIMEOUT PREVENTIVO] Se alcanzó el límite de 24 minutos en Clientes.")
                        return total_processed

                    params = params_base.copy()
                    params["skip"] = skip
                    success_batch = False
                    for retry in range(3):
                        try:
                            resp = self.session.get(f"{self.base_url}/customers", headers=headers, params=params, timeout=(15, 90))
                            logging.info(f"   -> [REQ] skip: {skip} | URL: {resp.url}")

                            if resp.status_code == 204:
                                return total_processed
                            
                            items = []
                            if resp.status_code == 200:
                                items = self._safe_parse_json(resp, "customers")

                            logging.info(f"   -> [RES] Status: {resp.status_code} | Count: {len(items)}")

                            if not items:
                                empty_pages += 1
                                if empty_pages <= 10:
                                    skip += limit
                                    time.sleep(0.05)
                                    success_batch = True
                                    break # Continúa a siguiente iteración del while
                                else:
                                    return total_processed

                            success_batch = True
                            break
                        except Exception as e:
                            logging.warning(f"   [!] Reintento {retry+1} en clientes (Skip {skip}): {e}")
                            time.sleep(5)

                    if not success_batch:
                        logging.error(f"Fallo definitivo en clientes lote {skip}.")
                        break

                    if items:
                        empty_pages = 0
                        items = [self._sanitize_cliente(item) for item in items]
                        self._process_and_save(conn, items, "Maestro_Clientes", "id_cliente", self.MAP_CLIENTE)
                        total_processed += len(items)
                    
                    if not items or len(items) < limit:
                        break

                    skip += limit
                    time.sleep(0.05)
                return total_processed

    def sync_employees(self):
            """Sincroniza empleados con privacidad y paginación."""
            if not self.token: self.get_token()
            headers = {"Authorization": f"Bearer {self.token}", "accept": "application/json"}

            start_time = time.time()
            MAX_EXECUTION_TIME = 24 * 60
            total_processed = 0

            with pyodbc.connect(self.conn_str) as conn:
                skip = 0
                limit = 50
                while True:
                    if (time.time() - start_time) > MAX_EXECUTION_TIME:
                        logging.warning("   [TIMEOUT PREVENTIVO] Se alcanzó el límite de 24 minutos en Empleados.")
                        return total_processed

                    params = {"skip": skip}
                    success_batch = False
                    for retry in range(3):
                        try:
                            resp = self.session.get(f"{self.base_url}/employees", headers=headers, params=params, timeout=(15, 90))
                            logging.info(f"   -> [REQ] skip: {skip} | URL: {resp.url}")
                            
                            if resp.status_code == 204:
                                return total_processed

                            items = self._safe_parse_json(resp, "employees")
                            logging.info(f"   -> [RES] Status: {resp.status_code} | Count: {len(items)}")

                            if items:
                                items = [self._sanitize_empleado(item) for item in items]
                                self._process_and_save(conn, items, "Maestro_Empleados", "id_empleado", self.MAP_EMPLEADO)
                                total_processed += len(items)

                            if not items or len(items) < limit:
                                success_batch = True # Mark success to exit outer loop cleanly via break
                                break

                            skip += limit
                            success_batch = True
                            time.sleep(0.05)
                            break
                        except Exception as e:
                            logging.warning(f"   [!] Reintento {retry+1} en empleados (Skip {skip}): {e}")
                            time.sleep(10)

                    if not items or len(items) < limit:
                        break

                    if not success_batch:
                        logging.error(f"Fallo definitivo en empleados lote {skip}.")
                        break
                return total_processed

    def sync_brands_full(self):
            """
            Descarga forzada y completa de todas las marcas (Full Load).
            Estrategia: Recorrer todo el endpoint paginado para asegurar integridad referencial.
            """
            if not self.token: self.get_token()
            headers = {"Authorization": f"Bearer {self.token}", "accept": "application/json"}
            
            logging.info("--- [INICIO] Sincronización Completa de Marcas (Full Sync) ---")
            
            skip = 0
            limit = 50
            total_procesado = 0
            
            with pyodbc.connect(self.conn_str) as conn:
                while True:
                    try:
                        # Petición a la API sin filtro de fecha
                        params = {'skip': skip}
                        resp = self.session.get(f"{self.base_url}/brands", headers=headers, params=params, timeout=30)
                        
                        # Manejo de fin de datos
                        if resp.status_code == 204: 
                            break
                        if resp.status_code != 200: 
                            logging.warning(f"   [Brands] Status no esperado {resp.status_code} en skip {skip}")
                            break
                        
                        items = self._safe_parse_json(resp, "brands")
                        if not items:
                            break

                        items = [self._sanitize_marca(item) for item in items]
                        # Guardado Inmediato en BD
                        self._process_and_save(conn, items, "Maestro_Marcas", "id_marca", self.MAP_MARCA)
                        conn.commit() # Commit explícito por bloque
                        
                        total_procesado += len(items)
                        logging.info(f"   -> Marcas guardadas: {total_procesado} (Bloque skip {skip})")
                        
                        # Control del bucle
                        if len(items) < limit: 
                            break
                        
                        skip += limit
                        time.sleep(0.1) # Pequeña pausa para no saturar
                        
                    except Exception as e:
                        logging.error(f"   [Error] Fallo en sync_brands_full bloque {skip}: {e}")
                        break
            
            logging.info(f"--- [FIN] Total Marcas Sincronizadas: {total_procesado} ---")
            return total_procesado

    def sync_brands(self, brand_ids_list, conn, known_brands_cache):
            """Sincroniza marcas usando Cache en Memoria para evitar Timeouts."""
            if not brand_ids_list: return

            # 1. Normalizar y Filtrar contra Cache (Velocidad Extrema)
            incoming_ids = set()
            for bid in brand_ids_list:
                try:
                    if bid: incoming_ids.add(int(float(bid)))
                except: pass
            
            # Lo que no está en el cache es lo único que nos importa
            unknown_ids = incoming_ids - known_brands_cache
            if not unknown_ids: return 

            # 2. Doble chequeo contra SQL (por concurrencia)
            placeholders = ','.join('?' * len(unknown_ids))
            with conn.cursor() as cursor:
                cursor.execute(f"SELECT id_marca FROM Maestro_Marcas WHERE id_marca IN ({placeholders})", tuple(unknown_ids))
                existing_in_db = {row[0] for row in cursor.fetchall()}
            
            # Actualizar cache y calcular delta real
            known_brands_cache.update(existing_in_db)
            ids_to_fetch = unknown_ids - existing_in_db

            if not ids_to_fetch: return

            logging.info(f"   [Brands JIT] Descargando {len(ids_to_fetch)} marcas nuevas...")
            headers = {"Authorization": f"Bearer {self.token}", "accept": "application/json"}
            new_brands = []

            for bid in ids_to_fetch:
                try:
                    resp = self.session.get(f"{self.base_url}/brands", headers=headers, params={"brands_id": bid}, timeout=(10, 60))
                    if resp.status_code == 200:
                        data = self._safe_parse_json(resp, "brands")
                        if isinstance(data, list): new_brands.extend(data)
                        elif isinstance(data, dict): new_brands.append(data)
                    # Agregamos al cache (sea éxito o 404) para no reintentar en este ciclo
                    known_brands_cache.add(bid)
                except Exception: pass
                time.sleep(0.05) 

            if new_brands:
                self._process_and_save(conn, new_brands, "Maestro_Marcas", "id_marca", self.MAP_MARCA)
                conn.commit()

    def sync_products(self):
            """Sincroniza productos con Checkpoint para soportar grandes volúmenes sin reiniciar."""
            if not self.token: self.get_token()
            headers = {"Authorization": f"Bearer {self.token}", "accept": "application/json"}

            CHECKPOINT_KEY = 'checkpoint_products_skip'

            with pyodbc.connect(self.conn_str) as conn:
                # --- 1. PRE-CALENTAMIENTO CACHE ---
                logging.info("   [Init] Pre-cargando cache de marcas...")
                known_brands_cache = set()
                try:
                    with conn.cursor() as cursor:
                        cursor.execute("SELECT id_marca FROM Maestro_Marcas")
                        known_brands_cache = {row[0] for row in cursor.fetchall()}
                except: pass

                # --- 2. GESTIÓN DE CHECKPOINT (AUTO-RESUME) ---
                # Si es HISTORICAL, intentamos retomar donde nos quedamos
                if self.LOAD_MODE_PRODUCTS == 'HISTORICAL':
                    last_date = datetime.datetime(2025, 1, 1)
                    skip = self._get_checkpoint(conn, CHECKPOINT_KEY)
                    logging.info(f"   [Historical] Retomando carga masiva desde SKIP: {skip}")
                else:
                    exact_date = self.get_last_date(conn, "Maestro_Productos", "fecha_ultima_actualizacion")
                    last_date = exact_date - datetime.timedelta(days=3)
                    skip = 0
                    # Limpiar checkpoint cuando se cambia a INCREMENTAL
                    self._update_checkpoint(conn, CHECKPOINT_KEY, 0)
                    logging.info(f"   [Incremental] Productos: Búsqueda con buffer 3 días - desde {last_date}")

                limit = 50
                buffer = []
                total_processed = 0

                BUFFER_LIMIT = 200
                start_time = time.time()
                MAX_EXECUTION_TIME = 20 * 60  # 20 minutos para aprovechar ciclo Azure (24 min límite) 

                while True:
                    # --- 3. MANEJO DE TIMEOUT CON GUARDADO DE ESTADO ---
                    if (time.time() - start_time) > MAX_EXECUTION_TIME:
                        logging.warning(f"   [TIMEOUT] Tiempo agotado en skip {skip}. Guardando estado...")
                        
                        # Guardamos buffer pendiente
                        if buffer: 
                            self._process_and_save(conn, buffer, "Maestro_Productos", "id_producto", self.MAP_PRODUCTO)
                        
                        # GUARDAMOS EL PUNTO DE CONTROL PARA LA PRÓXIMA VEZ
                        if self.LOAD_MODE_PRODUCTS == 'HISTORICAL':
                            self._update_checkpoint(conn, CHECKPOINT_KEY, skip)
                            logging.info(f"   [Checkpoint] Progreso guardado. Próxima ejecución iniciará en {skip}.")
                        
                        return total_processed

                    params = {"skip": skip, "fechaInicial": last_date.strftime("%Y-%m-%d %H:%M:%S")}
                    success_batch = False
                    items = []
                    
                    for retry in range(3):
                        try:
                            resp = self.session.get(f"{self.base_url}/products", headers=headers, params=params, timeout=(15, 90))
                            
                            # FIN DE DATOS (204)
                            if resp.status_code == 204:
                                if buffer: self._process_and_save(conn, buffer, "Maestro_Productos", "id_producto", self.MAP_PRODUCTO)
                                # Reiniciamos checkpoint a 0 porque terminamos todo
                                if self.LOAD_MODE_PRODUCTS == 'HISTORICAL':
                                    self._update_checkpoint(conn, CHECKPOINT_KEY, 0)
                                    logging.info("   [Fin] Carga histórica completada. Checkpoint reiniciado a 0.")
                                return total_processed

                            items = self._safe_parse_json(resp, "products")
                            if items:
                                # A. Sincronizar Marcas (JIT)
                                batch_brands = set()
                                for item in items:
                                    b = item.get('brand')
                                    if b:
                                        bid = b.get('id') if isinstance(b, dict) else b
                                        try: batch_brands.add(int(float(bid)))
                                        except: pass
                                
                                if batch_brands:
                                    self.sync_brands(list(batch_brands), conn, known_brands_cache)

                                # B. Parsing Atributos (Blindado)
                                for item in items:
                                    cfields = item.get('customFields', [])
                                    def get_cf(target_def_id):
                                        str_target = str(target_def_id)
                                        for f in cfields:
                                            if str(f.get('customField')) == str_target:
                                                val = f.get('value')
                                                return str(val).strip().upper() if val is not None else None
                                        return None

                                    item['material_marco'] = get_cf(30)
                                    item['genero_objetivo'] = get_cf(40)
                                    item['color_comercial'] = get_cf(32)
                                    item['tipo_montura'] = get_cf(31)
                                    
                                    desc = item.get('description')
                                    item['nombre_modelo_padre'] = str(desc).strip().upper() if desc else None

                                # C. Sanitización
                                items = [self._sanitize_producto(item) for item in items]

                                # D. Buffer
                                current_buffer = buffer + items
                                if len(current_buffer) >= BUFFER_LIMIT:
                                    logging.info(f"   [SQL Write] Guardando bloque (Skip actual: {skip})...")
                                    self._process_and_save(conn, current_buffer, "Maestro_Productos", "id_producto", self.MAP_PRODUCTO)
                                    buffer = []
                                else:
                                    buffer = current_buffer
                                
                                total_processed += len(items)
                            
                            success_batch = True
                            break
                        except Exception as e:
                            logging.warning(f"   [!] Error API batch {skip}: {e}")
                            time.sleep(5)

                    if not success_batch: break
                    
                    # Fin de datos (Página incompleta)
                    if not items or len(items) < 50:
                        if buffer: self._process_and_save(conn, buffer, "Maestro_Productos", "id_producto", self.MAP_PRODUCTO)
                        if self.LOAD_MODE_PRODUCTS == 'HISTORICAL':
                            self._update_checkpoint(conn, CHECKPOINT_KEY, 0)
                            logging.info("   [Fin] Barrido finalizado. Checkpoint reset a 0.")
                        break

                    skip += limit
                    time.sleep(0.01)

                logging.info(f"   [Fin] PRODUCTOS procesados: {total_processed} registros")
                return total_processed

    def sync_exams(self):
            """Sincroniza exámenes con un Barrido Diario Exhaustivo hacia atrás para manejar días de alta densidad."""
            if not self.token: self.get_token()
            headers = {"Authorization": f"Bearer {self.token}", "accept": "application/json"}

            start_time = time.time()
            MAX_EXECUTION_TIME = 24 * 60  # 24 minutos
            total_processed = 0
            CHECKPOINT_KEY = 'Exams_DailySweep_Date' # Checkpoint por día completado

            with pyodbc.connect(self.conn_str) as conn:
                # 1. Determinar Fecha de Inicio y Límite del barrido
                current_day = datetime.datetime.now()

                if self.LOAD_MODE_EXAMS == 'INCREMENTAL':
                    # En modo incremental, barremos los últimos 3 días para asegurar consistencia sin exceso de datos.
                    limit_date = datetime.datetime.now() - datetime.timedelta(days=3)
                    logging.info(f"   [Incremental] Barriendo los últimos 3 días (hasta {limit_date.strftime('%Y-%m-%d')}).")
                else: # HISTORICAL
                    limit_date = datetime.datetime(2025, 1, 1)  # Carga histórica desde 01/01/2025
                    chk_val = self._get_checkpoint(conn, CHECKPOINT_KEY)
                    if chk_val and chk_val != 0:
                        try:
                            # Checkpoint guarda la última fecha completada. Empezamos el día ANTERIOR.
                            last_completed_date = datetime.datetime.strptime(str(chk_val), "%Y-%m-%d")
                            current_day = last_completed_date - datetime.timedelta(days=1)
                            logging.info(f"   [Historical] Retomando barrido desde el día {current_day.strftime('%Y-%m-%d')}")
                        except (ValueError, TypeError):
                            logging.warning(f"   [Historical] Checkpoint inválido '{chk_val}'. Iniciando desde hoy.")
                    else:
                        logging.info(f"   [Historical] Iniciando barrido desde hoy hacia atrás.")

                # Bucle principal que recorre los días hacia atrás
                while current_day.date() >= limit_date.date():
                    if (time.time() - start_time) > MAX_EXECUTION_TIME:
                        logging.warning("   [TIMEOUT] Tiempo límite alcanzado. El progreso del día anterior fue guardado. Saliendo.")
                        break

                    # --- Configuración para el día actual ---
                    day_start_of_day = current_day.replace(hour=0, minute=0, second=0, microsecond=0)
                    
                    if current_day.date() == datetime.datetime.now().date():
                        cursor_final = datetime.datetime.now()
                    else:
                        cursor_final = current_day.replace(hour=23, minute=59, second=59, microsecond=0)
                    
                    logging.info(f"--- Procesando día: {current_day.strftime('%Y-%m-%d')} ---")
                    day_processed_count = 0
                    day_failed = False

                    # --- Sub-bucle de barrido para el día actual ---
                    while True:
                        if (time.time() - start_time) > MAX_EXECUTION_TIME:
                            logging.warning("   [TIMEOUT] Tiempo límite alcanzado durante el barrido del día.")
                            day_failed = True # Marcar como fallido para no guardar checkpoint
                            break

                        if cursor_final < day_start_of_day: break

                        params = {
                            "fechaInicial": day_start_of_day.strftime("%Y-%m-%d %H:%M:%S"),
                            "fechaFinal": cursor_final.strftime("%Y-%m-%d %H:%M:%S")
                        }
                        
                        items = []
                        success_batch = False
                        
                        for retry in range(3):
                            try:
                                resp = self.session.get(f"{self.base_url}/optometricExam", headers=headers, params=params, timeout=(15, 90))
                                
                                if resp.status_code == 200:
                                    items = self._safe_parse_json(resp, "exams")
                                    success_batch = True
                                    break
                                elif resp.status_code == 204:
                                    success_batch = True
                                    break
                                else:
                                    logging.warning(f"   [API Error] Status {resp.status_code} en ventana {params['fechaInicial']} a {params['fechaFinal']}. Reintento {retry+1}/3...")
                                    time.sleep(5)
                            except Exception as e:
                                logging.error(f"   [Exception] Error en petición en ventana {params['fechaInicial']} a {params['fechaFinal']}: {e}. Reintento {retry+1}/3...")
                                time.sleep(10)

                        if not success_batch:
                            logging.error(f"   [Fallo Definitivo] No se pudo obtener datos para la ventana. Abortando día.")
                            day_failed = True
                            break

                        if not items: break

                        items = [self._sanitize_examen(item) for item in items]
                        self._process_and_save(conn, items, "Clinica_Examenes", "id_examen", self.MAP_EXAMEN)
                        count = len(items)
                        day_processed_count += count
                        total_processed += count
                        logging.info(f"   -> Lote procesado: {count} exámenes en ventana hasta {params['fechaFinal']}")

                        if count == 50:
                            last_record_date_str = items[-1]['date']
                            try:
                                last_record_date = datetime.datetime.strptime(last_record_date_str, "%Y-%m-%d %H:%M:%S")
                                cursor_final = last_record_date - datetime.timedelta(seconds=1)
                            except (ValueError, TypeError) as e:
                                logging.error(f"   [Error de Fecha] No se pudo parsear la fecha '{last_record_date_str}': {e}. Abortando día.")
                                day_failed = True
                                break
                        else:
                            break
                        
                        time.sleep(0.1)

                    if not day_failed:
                        logging.info(f"   [Día Completado] {current_day.strftime('%Y-%m-%d')}: {day_processed_count} exámenes en total.")
                        if self.LOAD_MODE_EXAMS == 'HISTORICAL':
                            self._update_checkpoint(conn, CHECKPOINT_KEY, current_day.strftime("%Y-%m-%d"))
                            conn.commit()
                    else:
                        logging.error(f"   [Fallo Día] No se pudo completar el barrido para {current_day.strftime('%Y-%m-%d')}. Deteniendo proceso.")
                        break

                    current_day -= datetime.timedelta(days=1)

                if self.LOAD_MODE_EXAMS == 'HISTORICAL' and not day_failed:
                    self._update_checkpoint(conn, CHECKPOINT_KEY, 0)
                    conn.commit()
                    logging.info("   [Fin Carga Histórica] Barrido completado. Checkpoint reiniciado.")

                return total_processed

    def _sync_exams_by_customer(self, conn, customer_id, headers):
            """Descarga historial completo de exámenes para un cliente específico."""
            # Blindaje de tipo de dato para ID de cliente
            cid_clean = str(int(float(customer_id)))

            resp = self.session.get(f"{self.base_url}/optometricExam", headers=headers, params={"customer": cid_clean}, timeout=(15, 90))
            # logging.info(f"   -> [REQ] URL: {resp.url}") # Silenciado por regla de auditoría
            if resp.status_code == 200:
                items = resp.json()
                if items:
                    self._process_and_save(conn, items, "Clinica_Examenes", "id_examen", self.MAP_EXAMEN)
                    return len(items)
            elif resp.status_code == 204:
                logging.info(f"   [Info] Cliente {cid_clean} sin exámenes (204).")
                return 0
            else:
                raise Exception(f"API Error {resp.status_code}")
            return 0

    def _get_checkpoint(self, conn, key):
            """Lee valor de tabla de control Etl_Checkpoints."""
            try:
                cursor = conn.cursor()
                # Asegurar que tabla existe (Idempotente)
                cursor.execute("""
                    IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Etl_Checkpoints' AND xtype='U')
                    CREATE TABLE Etl_Checkpoints (KeyName VARCHAR(50) PRIMARY KEY, LastValue VARCHAR(50))
                """)
                cursor.execute("SELECT LastValue FROM Etl_Checkpoints WHERE KeyName = ?", key)
                row = cursor.fetchone()
                if row and row[0]:
                    val = row[0]
                    return int(val) if str(val).isdigit() else val
                return 0
            except: return 0

    def _update_checkpoint(self, conn, key, value):
            """Actualiza valor en tabla de control."""
            try:
                cursor = conn.cursor()
                # Upsert simple para SQL Server
                cursor.execute("""
                    MERGE Etl_Checkpoints AS target
                    USING (SELECT ? AS KeyName, ? AS LastValue) AS source
                    ON (target.KeyName = source.KeyName)
                    WHEN MATCHED THEN UPDATE SET LastValue = source.LastValue
                    WHEN NOT MATCHED THEN INSERT (KeyName, LastValue) VALUES (source.KeyName, source.LastValue);
                """, key, str(value))
                conn.commit()
            except Exception as e:
                logging.error(f"Error actualizando checkpoint: {e}")



    def sync_orders(self):
            """Sincroniza pedidos de venta con estrategia Híbrida (Smart Sync) y Checkpoint Explícito."""
            if not self.token: self.get_token()
            headers = {"Authorization": f"Bearer {self.token}", "accept": "application/json"}

            start_time = time.time()
            MAX_EXECUTION_TIME = 24 * 60
            total_processed = 0
            CHECKPOINT_KEY = 'checkpoint_orders_skip'

            params_base = {}
            if self.LOAD_MODE_ORDERS == 'INCREMENTAL':
                fecha_inicio = datetime.datetime.now() - datetime.timedelta(days=1)
                params_base["fechaInicial"] = fecha_inicio.strftime("%Y-%m-%d %H:%M:%S")
                logging.info(f"   [Smart Sync] Pedidos: Buscando cambios desde {params_base['fechaInicial']}")
            elif self.LOAD_MODE_ORDERS == 'HISTORICAL':
                fecha_inicio = datetime.datetime(2025, 1, 1, 0, 0, 0)
                params_base["fechaInicial"] = fecha_inicio.strftime("%Y-%m-%d %H:%M:%S")
                logging.info("   [Historical Load] Pedidos: Descarga completa forzada.")

            skip = 0

            # --- Checkpoint Explícito para HISTORICAL (estilo sync_products) ---
            if self.LOAD_MODE_ORDERS == 'HISTORICAL':
                try:
                    with pyodbc.connect(self.conn_str) as conn:
                        skip = int(self._get_checkpoint(conn, CHECKPOINT_KEY) or 0)
                        logging.info(f"   [Checkpoint] Pedidos: Retomando desde skip {skip}.")
                except Exception as e:
                    logging.warning(f"   [Checkpoint] No se pudo leer checkpoint inicial: {e}. Iniciando desde skip 0.")

            while True:
                if (time.time() - start_time) > MAX_EXECUTION_TIME:
                    logging.warning("   [TIMEOUT PREVENTIVO] Se alcanzó el límite de 24 minutos en Pedidos.")
                    # Guardar checkpoint antes de salir por timeout
                    if self.LOAD_MODE_ORDERS == 'HISTORICAL':
                        try:
                            with pyodbc.connect(self.conn_str) as conn:
                                self._update_checkpoint(conn, CHECKPOINT_KEY, skip)
                                logging.info(f"   [Checkpoint] Guardado skip={skip} antes de timeout.")
                        except Exception as e:
                            logging.error(f"   [Checkpoint] Error guardando checkpoint en timeout: {e}")
                    return total_processed

                params = params_base.copy()
                params["skip"] = skip
                success_batch = False
                items = []

                for retry in range(3):
                    try:
                        resp = self.session.get(f"{self.base_url}/issuedOrders", headers=headers, params=params, timeout=(15, 90))
                        logging.info(f"   -> [REQ] skip: {skip} | URL: {resp.url}")
                        
                        if resp.status_code == 204:
                            # Fin de datos: resetear checkpoint
                            if self.LOAD_MODE_ORDERS == 'HISTORICAL':
                                try:
                                    with pyodbc.connect(self.conn_str) as conn:
                                        self._update_checkpoint(conn, CHECKPOINT_KEY, 0)
                                        logging.info("   [Checkpoint] Histórico completado. Checkpoint reseteado a 0.")
                                except Exception as e:
                                    logging.error(f"   [Checkpoint] Error reseteando checkpoint: {e}")
                            return total_processed

                        items = self._safe_parse_json(resp, "issuedOrders")
                        logging.info(f"   -> [RES] Status: {resp.status_code} | Count: {len(items)}")

                        if items:
                            # --- LÓGICA DE CÁLCULO DE MONTOS (Fix Objetos Anidados) ---
                            for order in items:
                                # 1. Total Pedido (Suma de lineItems)
                                line_items = order.get('lineItems') or []
                                total_val = sum(float(x.get('total') or 0) for x in line_items if x)
                                
                                # 2. Monto Pagado (Suma de payments)
                                payments = order.get('payments') or []
                                paid_val = sum(float(x.get('amount') or 0) for x in payments if x)
                                
                                # 3. Saldo y Estado
                                pending_val = total_val - paid_val
                                status_val = 'PAGADO' if pending_val <= 0.01 else 'PENDIENTE'

                                # Inyección de valores calculados para mapeo directo
                                order['monto_total'] = total_val
                                order['monto_pagado'] = paid_val
                                order['saldo_pendiente'] = pending_val
                                order['estado_pedido'] = status_val

                                # Estado del documento desde la API (entero)
                                order['documentStatus'] = int(order.get('documentStatus') or 0)

                            # Guardado con conexión fresca y reintentos
                            saved = False
                            for db_retry in range(3):
                                try:
                                    with pyodbc.connect(self.conn_str) as conn:
                                        self._process_and_save(conn, items, "Ventas_Pedidos", "id_pedido", self.MAP_PEDIDO)
                                    saved = True
                                    break
                                except Exception as e:
                                    logging.warning(f"   [DB Retry {db_retry+1}] Error guardando pedidos: {e}")
                                    time.sleep(5)
                            
                            if not saved:
                                raise Exception("Fallo definitivo guardando pedidos en BD.")

                            total_processed += len(items)

                        if not items or len(items) < 50:
                            # Fin de datos: resetear checkpoint
                            if self.LOAD_MODE_ORDERS == 'HISTORICAL':
                                try:
                                    with pyodbc.connect(self.conn_str) as conn:
                                        self._update_checkpoint(conn, CHECKPOINT_KEY, 0)
                                        logging.info("   [Checkpoint] Histórico completado. Checkpoint reseteado a 0.")
                                except Exception as e:
                                    logging.error(f"   [Checkpoint] Error reseteando checkpoint: {e}")
                            success_batch = True
                            break

                        skip += 50
                        success_batch = True
                        time.sleep(0.05)
                        break
                    except Exception as e:
                        logging.warning(f"   [!] Reintento {retry+1} en pedidos skip {skip}: {e}")
                        time.sleep(10)
                
                if not items or len(items) < 50:
                    break

                if not success_batch:
                    logging.error(f"Fallo definitivo en pedidos lote {skip}.")
                    break
            return total_processed

    def sync_appointments(self):
            """Sincroniza citas con estrategia de Autocuración Inversa (Optimista)."""
            if not self.token: self.get_token()
            headers = {"Authorization": f"Bearer {self.token}", "accept": "application/json"}

            start_time = time.time()
            MAX_EXECUTION_TIME = 24 * 60

            with pyodbc.connect(self.conn_str) as conn:
                last_date = self.get_last_date(conn, "Marketing_Citas", "fecha_cita_inicio")
                
                # --- FIX: Validación de fecha futura ---
                if last_date > datetime.datetime.now():
                    last_date = datetime.datetime.now() - datetime.timedelta(days=3)
                
                params_base = {"fechaInicial": last_date.strftime("%Y-%m-%d %H:%M:%S")}
                skip = 0
                limit = 50
                total_processed = 0

                while True:
                    if (time.time() - start_time) > MAX_EXECUTION_TIME:
                        logging.warning("   [TIMEOUT] Límite de 25 min alcanzado en Citas. Guardando y saliendo.")
                        break

                    params = params_base.copy()
                    params["skip"] = skip
                    
                    # --- BLOQUE DE REINTENTOS (Exponential Backoff) ---
                    items = []
                    success_batch = False
                    
                    for retry in range(3):
                        try:
                            resp = self.session.get(f"{self.base_url}/eventsClient", headers=headers, params=params, timeout=(15, 90))
                            logging.info(f"   -> [REQ] skip: {skip} | URL: {resp.url}")
                            
                            if resp.status_code == 204:
                                # Salida inmediata si no hay contenido
                                logging.info(f"   -> [RES] Status: 204 | Count: 0")
                                return total_processed
                            
                            items = self._safe_parse_json(resp, "appointments")
                            logging.info(f"   -> [RES] Status: {resp.status_code} | Count: {len(items)}")

                            # Regla de Parada Temprana (User Request)
                            if not items or len(items) < 50:
                                success_batch = True
                                break

                            success_batch = True
                            break
                        except Exception as e:
                            wait_time = (retry + 1) * 5
                            logging.warning(f"⚠️ Reintentando bloque {skip} por timeout ({retry+1}/3): {e}. Esperando {wait_time}s...")
                            time.sleep(wait_time)
                    
                    if not success_batch:
                        logging.error(f"   [!] Error definitivo obteniendo bloque citas {skip}. Deteniendo.")
                        break
                    
                    if items:
                        try:
                            # --- BLINDAJE DE IDs: Limpieza de cliente_id (User Request) ---
                            for item in items:
                                cid = item.get('cliente_id')
                                item['cliente_id'] = int(float(cid)) if cid is not None and str(cid).strip() != '' else 0

                            # --- ESTRATEGIA ANTICIPADA: Verificar clientes faltantes ---
                            # 1. Identificar clientes en el lote
                            batch_client_ids = set()
                            for x in items:
                                batch_client_ids.add(x['cliente_id'])
                            
                            if batch_client_ids:
                                placeholders = ','.join('?' * len(batch_client_ids))
                                with conn.cursor() as cursor:
                                    cursor.execute(f"SELECT id_cliente FROM Maestro_Clientes WHERE id_cliente IN ({placeholders})", tuple(batch_client_ids))
                                    existing = {row[0] for row in cursor.fetchall()}
                                    missing = batch_client_ids - existing
                                
                                if missing:
                                    logging.info(f"   [Autocuración] Detectados {len(missing)} clientes faltantes en bloque {skip}. Rescatando...")
                                    rescued_clients = []
                                    for mid in missing:
                                        try:
                                            if mid == 0: raise Exception("Cliente 0")
                                            c_resp = self.session.get(f"{self.base_url}/customers/{mid}", headers=headers, timeout=(15, 90))
                                            if c_resp.status_code == 200:
                                                rescued_clients.append(c_resp.json())
                                            else:
                                                rescued_clients.append({'id': mid, 'name': f'Cliente {mid}', 'lastName': '(Rescatado Citas)'})
                                        except:
                                            rescued_clients.append({'id': mid, 'name': f'Cliente {mid}', 'lastName': '(Rescatado Citas)'})
                                        time.sleep(0.5)
                                    
                                    if rescued_clients:
                                        self._process_and_save(conn, rescued_clients, "Maestro_Clientes", "id_cliente", self.MAP_CLIENTE)
                                        conn.commit()

                            # 2. Sanitizar citas
                            items = [self._sanitize_cita(item) for item in items]

                            # 3. Insertar citas (Ahora seguro)
                            self._process_and_save(conn, items, "Marketing_Citas", ["id_cliente", "fecha_cita_inicio"], self.MAP_CITAS)
                            total_processed += len(items)
                            
                        except Exception as e:
                            logging.error(f"   [!] Error procesando bloque citas {skip}: {e}")
                            break

                    if not items or len(items) < limit:
                        break

                    skip += limit
                    time.sleep(1)
                
                if total_processed > 0:
                    logging.info(f"✅ Citas: {total_processed} registros nuevos procesados. Total en BD: {skip}")
                return total_processed

    def sync_invoices_incremental(self):
            """Sincronización de facturas agnóstica al orden de la API."""
            if not self.token: self.get_token()
            headers = {"Authorization": f"Bearer {self.token}", "accept": "application/json"}

            # --- CONTROL DE TIEMPO DE EJECUCIÓN ---
            start_time = time.time()
            MAX_EXECUTION_TIME = 24 * 60  # 24 minutos (Safety margin para timeout de Azure)
            total_processed = 0

            with pyodbc.connect(self.conn_str) as conn:
                # === CHECK PREVIO: ¿VENTAS YA COMPLETADA? ===
                if self.LOAD_MODE_INVOICES == 'HISTORICAL':
                    try:
                        with conn.cursor() as cursor:
                            cursor.execute("SELECT LastValue FROM Etl_Checkpoints WHERE KeyName = 'checkpoint_invoices_final_detected'")
                            row = cursor.fetchone()
                            if row and row[0] == '1':
                                logging.info("   ✅ [EARLY EXIT] VENTAS ya está COMPLETADA (checkpoint detectado). Abortando.")
                                return 0
                    except Exception as e:
                        logging.warning(f"   [Checkpoint Check] No se pudo verificar completitud: {e}")

                last_id_sql = self.get_last_id(conn, "Ventas_Cabecera", "id_factura")
                logging.info(f"   [SQL Check] Iniciando sincronización desde ID: {last_id_sql}")

                skip = 0
                buffer = []
                BUFFER_LIMIT = 50 # Reducido drásticamente para evitar desbordamiento de memoria en Ventas

                # Si LOAD_MODE_INVOICES == 'HISTORICAL':
                # fechaInicial = '2024-01-01 00:00:00'.
                # skip = (COUNT(*) // 50) * 50. (Auto-Resume para API descendente).
                # Si LOAD_MODE_INVOICES == 'INCREMENTAL':
                # fechaInicial = Hace 1 día.
                # skip = 0.
                params_base = {}
                if self.LOAD_MODE_INVOICES == 'INCREMENTAL':
                    fecha_inicio = datetime.datetime.now() - datetime.timedelta(days=1)
                    params_base["fechaInicial"] = fecha_inicio.strftime("%Y-%m-%d %H:%M:%S")
                    logging.info(f"   [Smart Sync] Ventas: Buscando cambios desde {params_base['fechaInicial']}")
                elif self.LOAD_MODE_INVOICES == 'HISTORICAL':
                    fecha_inicio = datetime.datetime(2025, 1, 1, 0, 0, 0)
                    params_base["fechaInicial"] = fecha_inicio.strftime("%Y-%m-%d %H:%M:%S")
                    logging.info("   [Historical Load] Ventas: Descarga completa forzada.")

                if self.LOAD_MODE_INVOICES == 'HISTORICAL':
                    try:
                        with conn.cursor() as cursor:
                            cursor.execute("SELECT COUNT(*) FROM Ventas_Cabecera")
                            row = cursor.fetchone()
                            total_rows = row[0] if row else 0
                            skip = (total_rows // 50) * 50
                            logging.info(f"   [Auto-Resume] Detectados {total_rows} facturas en SQL. Retomando desde skip {skip}.")
                    except Exception as e:
                        logging.warning(f"   [Auto-Resume] No se pudo calcular skip inicial: {e}")

                while True:
                    items = []  # Blindaje: inicialización para evitar UnboundLocalError
                    # Check de Timeout Preventivo
                    if (time.time() - start_time) > MAX_EXECUTION_TIME:
                        logging.warning(f"   [TIMEOUT PREVENTIVO] Se alcanzó el límite de 24 minutos. Guardando buffer y deteniendo ejecución.")
                        if buffer:
                            try:
                                self._process_and_save(conn, buffer, "Ventas_Cabecera", "id_factura", self.MAP_VENTA)
                                logging.info(f"   [Final Timeout] Buffer remanente de {len(buffer)} facturas guardado.")
                            except Exception as e:
                                logging.error(f"   [!] Error guardando buffer al salir por timeout: {e}")
                        return total_processed

                    params = params_base.copy()
                    params["skip"] = skip
                    success_batch = False
                    for retry in range(3):
                        try:
                            resp = self.session.get(f"{self.base_url}/issuedInvoices", headers=headers, params=params, timeout=(15, 90))
                            logging.info(f"   -> [REQ] skip: {skip} | URL: {resp.url}")

                            if resp.status_code == 204:
                                # Guardar buffer remanente y salir
                                if buffer:
                                    self._process_and_save(conn, buffer, "Ventas_Cabecera", "id_factura", self.MAP_VENTA)
                                return total_processed

                            items = self._safe_parse_json(resp, "issuedInvoices")
                            logging.info(f"   -> [RES] Status: {resp.status_code} | Count: {len(items)}")

                            # Procesamiento de items
                            if items:
                                current_buffer = buffer + items
                                if len(current_buffer) >= BUFFER_LIMIT:
                                    self._process_and_save(conn, current_buffer, "Ventas_Cabecera", "id_factura", self.MAP_VENTA)
                                    buffer = []
                                else:
                                    buffer = current_buffer
                                
                                total_processed += len(items)
                            
                            # Salida temprana si final de página
                            if not items or len(items) < 50:
                                logging.info(f"   [Fin de Datos] Página incompleta con {len(items)} items. Carga completada.")
                                break

                            skip += 50
                            success_batch = True
                            time.sleep(0.05)
                            break
                        except Exception as e:
                            logging.warning(f"   [!] Error en skip {skip}: {e}. Reintentando...")
                            time.sleep(10)

                    if not items or len(items) < 50:
                        # FIN DE DATOS DETECTADO: Guardar buffer y terminar
                        if buffer:
                            self._process_and_save(conn, buffer, "Ventas_Cabecera", "id_factura", self.MAP_VENTA)

                        # En HISTORICAL, resetear flag de "no completado" para evitar re-intentos
                        if self.LOAD_MODE_INVOICES == 'HISTORICAL':
                            # Guardar checkpoint indicando completitud (ej: skip=-1 = terminado)
                            try:
                                with conn.cursor() as cursor:
                                    cursor.execute("DELETE FROM Etl_Checkpoints WHERE KeyName = 'checkpoint_invoices_final_detected'")
                                    cursor.execute("INSERT INTO Etl_Checkpoints (KeyName, LastValue) VALUES (?, ?)",
                                                 'checkpoint_invoices_final_detected', '1')
                                    conn.commit()
                                logging.info("   [Checkpoint] Marcado como COMPLETADO para evitar re-intentos.")
                            except Exception as e:
                                logging.warning(f"   [Checkpoint] No se pudo marcar completitud: {e}")

                        logging.info(f"   ✅ [VENTAS] CARGA COMPLETADA - Total procesado: {total_processed:,} facturas")
                        break

                    if not success_batch:
                        # Guardar lo que se tenga en buffer por seguridad
                        if buffer:
                            try:
                                self._process_and_save(conn, buffer, "Ventas_Cabecera", "id_factura", self.MAP_VENTA)
                            except: pass
                        break
                return total_processed

    def sync_inventory(self):
            """Sincroniza inventario con paginación global (estrategia Panamá) — sin iteración por warehouse."""
            if not self.token: self.get_token()
            headers = {"Authorization": f"Bearer {self.token}", "accept": "application/json"}

            start_time = time.time()
            MAX_EXECUTION_TIME = 24 * 60  # 24 min (margen Azure 30min - 6min buffer)
            total_processed = 0
            skip = 0
            limit = 50
            empty_pages = 0
            params_base = {}

            with pyodbc.connect(self.conn_str) as conn:
                # === Estrategia híbrida: INCREMENTAL (con fechaInicial) vs HISTORICAL (carga completa) ===
                if self.LOAD_MODE_INVENTORY == 'INCREMENTAL':
                    try:
                        start_date = self.get_last_date(conn, "Operaciones_Inventario", "fecha_actualizacion")
                        params_base["fechaInicial"] = start_date.strftime("%Y-%m-%d %H:%M:%S")
                        logging.info(f"   [INVENTARIO] Buscando cambios desde {start_date.strftime('%Y-%m-%d %H:%M:%S')}")
                    except:
                        logging.info("   [INVENTARIO] Tabla vacía o error, iniciando carga completa.")
                else:
                    logging.info("   [INVENTARIO] Descarga completa forzada (HISTORICAL mode)")

                # === Paginación global con skip (sin warehouse-by-warehouse) ===
                while True:
                    if (time.time() - start_time) > MAX_EXECUTION_TIME:
                        logging.warning(f"   [TIMEOUT] Límite alcanzado. Total procesado hasta ahora: {total_processed:,} items")
                        break

                    params = params_base.copy()
                    params["skip"] = skip

                    items = []
                    success_batch = False

                    for retry in range(3):
                        try:
                            resp = self.session.get(f"{self.base_url}/inventory", headers=headers, params=params, timeout=(15, 90))
                            logging.info(f"   -> [INVENTARIO] skip: {skip} | status: {resp.status_code}")

                            if resp.status_code == 204:
                                success_batch = True
                                break

                            items = self._safe_parse_json(resp, "inventory")
                            logging.info(f"   -> [INVENTARIO] skip: {skip} | status: {resp.status_code} | items: {len(items)}")
                            success_batch = True
                            break
                        except Exception as e:
                            wait = (retry + 1) * 5
                            logging.warning(f"   [!] Reintento {retry+1} INVENTARIO skip {skip}: {e}")
                            time.sleep(wait)

                    if not success_batch:
                        logging.error(f"Fallo definitivo INVENTARIO lote skip {skip}.")
                        break

                    # Procesar items si existen
                    if items:
                        self._process_and_save(conn, items, "Operaciones_Inventario", ["id_producto", "id_sucursal"], self.MAP_INVENTARIO)
                        total_processed += len(items)
                        empty_pages = 0  # Reset contador de páginas vacías

                    # Manejo de páginas vacías: tolera hasta 10 huecos antes de asumir fin
                    if not items:
                        empty_pages += 1
                        if empty_pages <= 10:
                            logging.info(f"   -> [INVENTARIO] Página vacía {empty_pages}/10. Continuando...")
                            skip += limit
                            time.sleep(0.05)
                            continue
                        else:
                            logging.info(f"   -> [INVENTARIO] Fin de datos detectado (10 páginas vacías consecutivas). Total procesado: {total_processed:,} items")
                            break

                    # Fin normal: menos items que el limit
                    if len(items) < limit:
                        logging.info(f"   -> [INVENTARIO] Lote final procesado (menos de {limit} items). Total procesado: {total_processed:,} items")
                        break

                    skip += limit
                    time.sleep(0.05)

            logging.info(f"   ✅ [INVENTARIO] CARGA COMPLETADA - Total procesado: {total_processed:,} items")
            return total_processed

    def sync_collections(self):
            """Sincroniza cobros con estrategia Dual (Historical/Incremental)."""
            if not self.token: self.get_token()
            headers = {"Authorization": f"Bearer {self.token}", "accept": "application/json"}

            start_time = time.time()
            MAX_EXECUTION_TIME = 24 * 60
            total_processed = 0
            total_amount = 0.0

            with pyodbc.connect(self.conn_str) as conn:
                # === CHECK PREVIO: ¿COBROS YA COMPLETADA? ===
                if self.LOAD_MODE_COBROS == 'HISTORICAL':
                    try:
                        with conn.cursor() as cursor:
                            cursor.execute("SELECT LastValue FROM Etl_Checkpoints WHERE KeyName = 'checkpoint_cobros_final_detected'")
                            row = cursor.fetchone()
                            if row and row[0] == '1':
                                logging.info("   ✅ [EARLY EXIT] COBROS ya está COMPLETADA (checkpoint detectado). Abortando.")
                                return 0, 0.0
                    except Exception as e:
                        logging.warning(f"   [Checkpoint Check] No se pudo verificar completitud: {e}")

                skip = 0
                limit = 50
                params_base = {}

                # --- FASE 1: DETERMINAR ESTADO INICIAL (Conexión efímera) ---
                if self.LOAD_MODE_COBROS == 'INCREMENTAL':
                    try:
                        last_date = self.get_last_date(conn, "Finanzas_Cobros", "fecha_cobro")
                        # Margen de seguridad de 2 horas
                        start_date = last_date - datetime.timedelta(hours=2)
                        params_base["fechaInicial"] = start_date.strftime("%Y-%m-%d %H:%M:%S")
                        logging.info(f"   [Incremental] Cobros: Buscando desde {params_base['fechaInicial']}")
                        skip = 0
                    except:
                        logging.info("   [Incremental] Cobros: Tabla vacía o error, iniciando carga completa.")
                else:
                    # --- AUTO-RESUME ---
                    try:
                        with conn.cursor() as cursor:
                            cursor.execute("SELECT COUNT(*) FROM Finanzas_Cobros")
                            row = cursor.fetchone()
                            total_rows = row[0] if row else 0
                            skip = (total_rows // limit) * limit
                            logging.info(f"   [Historical] Cobros: Retomando desde skip {skip} (Total en BD: {total_rows}).")
                    except Exception as e:
                        logging.warning(f"   [Auto-Resume] No se pudo calcular skip inicial: {e}")
                        logging.info("   [Historical] Cobros: Descarga completa por paginación (Skip 0).")

                # --- FASE 2: BUCLE DE EXTRACCIÓN (Conexión por lote) ---
                while True:
                    if (time.time() - start_time) > MAX_EXECUTION_TIME:
                        logging.warning("   [TIMEOUT] Límite de tiempo en Cobros.")
                        break

                    params = params_base.copy()
                    params["skip"] = skip

                    items = []
                    success_batch = False

                    for retry in range(3):
                        try:
                            resp = self.session.get(f"{self.base_url}/collections", headers=headers, params=params, timeout=(15, 90))
                            logging.info(f"   -> [REQ] skip: {skip} | URL: {resp.url}")

                            if resp.status_code == 204:
                                return total_processed, total_amount

                            items = self._safe_parse_json(resp, "collections")
                            logging.info(f"   -> [RES] Status: {resp.status_code} | Count: {len(items)}")

                            success_batch = True
                            break
                        except Exception as e:
                            wait = (retry + 1) * 5
                            logging.warning(f"   [!] Reintento {retry+1} en Cobros (Skip {skip}): {e}")
                            time.sleep(wait)

                    if not success_batch:
                        logging.error(f"Fallo definitivo en Cobros lote {skip}.")
                        break

                    if items:
                        # Calcular monto del lote
                        batch_amount = sum(float(x.get('amount', 0) or 0) for x in items)
                        total_amount += batch_amount

                        # Guardado con conexión fresca y reintentos
                        saved = False
                        for db_retry in range(3):
                            try:
                                with pyodbc.connect(self.conn_str) as db_conn:
                                    logging.info(f"   [DB] Guardando lote cobros {skip} ({len(items)} items)...")
                                    self._process_and_save(db_conn, items, "Finanzas_Cobros", "id_cobro", self.MAP_COBROS)
                                saved = True
                                break
                            except Exception as e:
                                logging.warning(f"   [DB Retry {db_retry+1}] Error guardando cobros: {e}")
                                time.sleep(5)

                        if not saved:
                            raise Exception("Fallo definitivo guardando cobros en BD.")

                        total_processed += len(items)

                    if not items or len(items) < limit:
                        # FIN DE DATOS DETECTADO: Guardar checkpoint y terminar
                        if self.LOAD_MODE_COBROS == 'HISTORICAL':
                            try:
                                with conn.cursor() as cursor:
                                    cursor.execute("DELETE FROM Etl_Checkpoints WHERE KeyName = 'checkpoint_cobros_final_detected'")
                                    cursor.execute("INSERT INTO Etl_Checkpoints (KeyName, LastValue) VALUES (?, ?)",
                                                 'checkpoint_cobros_final_detected', '1')
                                    conn.commit()
                                logging.info("   [Checkpoint] COBROS marcado como COMPLETADO para evitar re-intentos.")
                            except Exception as e:
                                logging.warning(f"   [Checkpoint] No se pudo marcar completitud: {e}")

                        logging.info(f"   ✅ [COBROS] CARGA COMPLETADA - Total procesado: {total_processed:,} cobros por ${total_amount:,.2f}")
                        break

                    skip += limit
                    time.sleep(2) # Throttling aumentado

            return total_processed, total_amount

    def sync_treasury(self):
            """Sincroniza movimientos de tesorería (Pagos/Caja) con estrategia Dual."""
            if not self.token: self.get_token()
            headers = {"Authorization": f"Bearer {self.token}", "accept": "application/json"}

            start_time = time.time()
            MAX_EXECUTION_TIME = 24 * 60
            total_processed = 0
            total_amount = 0.0

            with pyodbc.connect(self.conn_str) as conn:
                skip = 0
                limit = 50
                params_base = {}

                if self.LOAD_MODE_TREASURY == 'INCREMENTAL':
                    try:
                        last_date = self.get_last_date(conn, "Finanzas_Tesoreria", "fecha_movimiento")
                        # Margen de seguridad de 2 horas
                        start_date = last_date - datetime.timedelta(hours=2)
                        params_base["fechaInicial"] = start_date.strftime("%Y-%m-%d %H:%M:%S")
                        logging.info(f"   [Incremental] Tesorería: Buscando desde {params_base['fechaInicial']}")
                    except:
                        logging.info("   [Incremental] Tesorería: Tabla vacía o error, iniciando carga completa.")
                else:
                    # --- AUTO-RESUME ---
                    try:
                        with conn.cursor() as cursor:
                            cursor.execute("SELECT COUNT(*) FROM Finanzas_Tesoreria")
                            row = cursor.fetchone()
                            total_rows = row[0] if row else 0
                            skip = (total_rows // limit) * limit
                            logging.info(f"   [Historical] Tesorería: Retomando desde skip {skip} (Total en BD: {total_rows}).")
                    except Exception as e:
                        logging.warning(f"   [Auto-Resume] No se pudo calcular skip inicial: {e}")
                        logging.info("   [Historical] Tesorería: Descarga completa por paginación (Skip 0).")

                while True:
                    if (time.time() - start_time) > MAX_EXECUTION_TIME:
                        logging.warning("   [TIMEOUT] Límite de tiempo en Tesorería.")
                        break

                    params = params_base.copy()
                    params["skip"] = skip
                    
                    items = []
                    success_batch = False
                    
                    for retry in range(3):
                        try:
                            resp = self.session.get(f"{self.base_url}/payments", headers=headers, params=params, timeout=(15, 90))
                            logging.info(f"   -> [REQ] skip: {skip} | URL: {resp.url}")
                            
                            if resp.status_code == 204:
                                return total_processed, total_amount
                                
                            items = self._safe_parse_json(resp, "payments")
                            logging.info(f"   -> [RES] Status: {resp.status_code} | Count: {len(items)}")
                            
                            success_batch = True
                            break
                        except Exception as e:
                            wait = (retry + 1) * 5
                            logging.warning(f"   [!] Reintento {retry+1} en Tesorería (Skip {skip}): {e}")
                            time.sleep(wait)

                    if not success_batch:
                        logging.error(f"Fallo definitivo en Tesorería lote {skip}.")
                        break

                    if items:
                        # Calcular monto del lote
                        batch_amount = sum(float(x.get('amount', 0) or 0) for x in items)
                        total_amount += batch_amount

                        self._process_and_save(conn, items, "Finanzas_Tesoreria", "id_pago_tesoreria", self.MAP_TREASURY)
                        conn.commit()
                        
                        total_processed += len(items)
                    
                    if not items or len(items) < limit:
                        break
                    
                    skip += limit
                    time.sleep(2)

                return total_processed, total_amount

    def sync_laboratory_orders(self):
            """Sincroniza pedidos de laboratorio (receivedOrders)."""
            if not self.token: self.get_token()
            headers = {"Authorization": f"Bearer {self.token}", "accept": "application/json"}

            start_time = time.time()
            MAX_EXECUTION_TIME = 24 * 60
            total_processed = 0

            with pyodbc.connect(self.conn_str) as conn:
                skip = 0
                limit = 50
                params_base = {}
                
                if self.LOAD_MODE_LAB == 'INCREMENTAL':
                    try:
                        last_date = self.get_last_date(conn, "Operaciones_Pedidos_Laboratorio", "fecha_solicitud")
                        start_date = last_date - datetime.timedelta(hours=2)
                        params_base["fechaInicial"] = start_date.strftime("%Y-%m-%d %H:%M:%S")
                        logging.info(f"   [Incremental] Laboratorio: Buscando desde {params_base['fechaInicial']}")
                        skip = 0
                    except:
                        logging.info("   [Incremental] Laboratorio: Tabla vacía o error, iniciando carga completa.")
                elif self.LOAD_MODE_LAB == 'HISTORICAL':
                    try:
                        with conn.cursor() as cursor:
                            cursor.execute("SELECT COUNT(*) FROM Operaciones_Pedidos_Laboratorio")
                            row = cursor.fetchone()
                            total_rows = row[0] if row else 0
                            skip = (total_rows // limit) * limit
                            logging.info(f"   [Auto-Resume] Laboratorio: Retomando desde skip {skip} (Total en BD: {total_rows}).")
                    except Exception as e:
                        logging.warning(f"   [Auto-Resume] No se pudo calcular skip inicial: {e}")

                while True:
                    if (time.time() - start_time) > MAX_EXECUTION_TIME:
                        logging.warning("   [TIMEOUT] Límite de tiempo en Laboratorio.")
                        break

                    params = params_base.copy()
                    params["skip"] = skip
                    items = []
                    success_batch = False

                    for retry in range(3):
                        try:
                            # Timeout extendido (30, 150) y uso de sesión persistente
                            resp = self.session.get(f"{self.base_url}/receivedOrders", headers=headers, params=params, timeout=(15, 90))
                            logging.info(f"   -> [REQ] skip: {skip} | URL: {resp.url}")
                            
                            if resp.status_code == 204:
                                return total_processed
                            
                            items = self._safe_parse_json(resp, "receivedOrders")
                            logging.info(f"   -> [RES] Status: {resp.status_code} | Count: {len(items)}")
                            
                            success_batch = True
                            break
                        except Exception as e:
                            wait = (retry + 1) * 5
                            logging.warning(f"   [!] Reintento {retry+1} en Laboratorio (Skip {skip}): {e}")
                            time.sleep(wait)

                    if not success_batch:
                        logging.error(f"Fallo definitivo en Laboratorio lote {skip}.")
                        break

                    if items:
                        # JIT Rescue Sucursales
                        warehouse_ids = set()
                        for x in items:
                            # Limpieza de fechas vacías para evitar errores de conversión (Antes del continue)
                            for date_field in ['date', 'dateLastChangeFabricationState', 'manufacturingDate']:
                                if x.get(date_field) == "":
                                    x[date_field] = None

                            w = x.get('warehouse')
                            if not w: continue
                            try:
                                # Soporta tanto objeto {'id': 1} como ID directo 1
                                wid = w.get('id') if isinstance(w, dict) else w
                                if wid: warehouse_ids.add(int(float(wid)))
                            except: pass

                        warehouse_ids.discard(0)
                        
                        if warehouse_ids:
                            placeholders = ','.join('?' * len(warehouse_ids))
                            try:
                                with conn.cursor() as cursor:
                                    cursor.execute(f"SELECT id_sucursal FROM Maestro_Sucursales WHERE id_sucursal IN ({placeholders})", tuple(warehouse_ids))
                                    existing = {row[0] for row in cursor.fetchall()}
                                    missing = warehouse_ids - existing
                                    
                                    if missing:
                                        logging.info(f"   [JIT Rescue] Recuperando {len(missing)} sucursales faltantes...")
                                        dummy_warehouses = []
                                        for mid in missing:
                                            try:
                                                w_resp = self.session.get(f"{self.base_url}/warehouses/{mid}", headers=headers, timeout=(15, 90))
                                                if w_resp.status_code == 200:
                                                    dummy_warehouses.append(self._safe_parse_json(w_resp, "warehouses_rescue"))
                                                else:
                                                    dummy_warehouses.append({'id': mid, 'name': f'Sucursal {mid} (Rescue)'})
                                            except:
                                                dummy_warehouses.append({'id': mid, 'name': f'Sucursal {mid} (Rescue)'})
                                        if dummy_warehouses:
                                            self._process_and_save(conn, dummy_warehouses, "Maestro_Sucursales", "id_sucursal", self.MAP_SUCURSAL)
                            except Exception as e:
                                logging.error(f"Error en JIT Rescue Sucursales: {e}")

                        self._process_and_save(conn, items, "Operaciones_Pedidos_Laboratorio", "id_pedido_lab", self.MAP_LAB)
                        conn.commit()
                        
                        total_processed += len(items)

                    if not items or len(items) < limit:
                        break

                    skip += limit
                    time.sleep(0.5)

                return total_processed

    def sync_glasses_orders(self):
            """Sincroniza órdenes de cristales (Fases: Historical vs Incremental)."""
            # Validación de Predecesor
            if not self.predecesor_listo('PEDIDOS'):
                logging.warning("   [Dependencia] Módulo PEDIDOS no completado. Saltando Órdenes Cristales.")
                return 0

            if not self.token: self.get_token()
            headers = {"Authorization": f"Bearer {self.token}", "accept": "application/json"}

            start_time = time.time()
            MAX_EXECUTION_TIME = 24 * 60
            total_processed = 0
            
            # Definir punto de corte para Histórico (01/01/2025)
            cutoff_date = datetime.datetime(2025, 1, 1)
            
            # Determinar modo
            mode = getattr(self, 'LOAD_MODE_GLASSES_ORDERS', 'INCREMENTAL')

            with pyodbc.connect(self.conn_str) as conn:
                skip = 0
                limit = 50
                params_base = {}
                
                if mode == 'HISTORICAL':
                    # Auto-Resume para carga histórica descendente
                    try:
                        with conn.cursor() as cursor:
                            cursor.execute("SELECT COUNT(*) FROM Operaciones_Ordenes_Cristales")
                            row = cursor.fetchone()
                            total_rows = row[0] if row else 0
                            skip = (total_rows // limit) * limit
                            logging.info(f"   [Historical] Órdenes Cristales: Retomando desde skip {skip} (Total en BD: {total_rows}).")
                    except Exception as e:
                        logging.warning(f"   [Auto-Resume] No se pudo calcular skip inicial: {e}")
                else:
                    # Modo Incremental: Ventana de seguridad de 1 día
                    try:
                        last_date = self.get_last_date(conn, "Operaciones_Ordenes_Cristales", "fecha_creacion")
                        start_date = last_date - datetime.timedelta(days=1)
                        params_base["fechaInicial"] = start_date.strftime("%Y-%m-%d %H:%M:%S")
                        logging.info(f"   [Incremental] Órdenes Cristales: Buscando desde {params_base['fechaInicial']}")
                    except:
                        logging.info("   [Incremental] Tabla vacía o error, iniciando carga completa.")

                while True:
                    if (time.time() - start_time) > MAX_EXECUTION_TIME:
                        logging.warning("   [TIMEOUT] Límite de tiempo en Órdenes Cristales.")
                        break

                    params = params_base.copy()
                    params["skip"] = skip
                    items = []
                    success_batch = False

                    for retry in range(3):
                        try:
                            resp = self.session.get(f"{self.base_url}/glasses-orders", headers=headers, params=params, timeout=(15, 90))
                            logging.info(f"   -> [REQ] skip: {skip} | URL: {resp.url}")

                            if resp.status_code == 204:
                                return total_processed
                            
                            items = self._safe_parse_json(resp, "glasses-orders")
                            logging.info(f"   -> [RES] Status: {resp.status_code} | Count: {len(items)}")
                            success_batch = True
                            break
                        except Exception as e:
                            wait = (retry + 1) * 5
                            logging.warning(f"   [!] Reintento {retry+1} en Órdenes Cristales (Skip {skip}): {e}")
                            time.sleep(wait)

                    if not success_batch:
                        logging.error(f"Fallo definitivo en Órdenes Cristales lote {skip}.")
                        break

                    if items:
                        flat_items = []
                        stop_loading = False

                        # Helper para extracción de IDs
                        def get_obj_id(obj):
                            if isinstance(obj, dict): return obj.get('id')
                            return obj

                        for item in items:
                            # Blindaje de fecha (Audit Fallback)
                            date_val = item.get('date')
                            if not date_val:
                                audit = item.get('audit')
                                if isinstance(audit, dict):
                                    date_val = audit.get('creationDate')

                            # Lógica de filtrado por fecha para modo HISTORICAL
                            if mode == 'HISTORICAL':
                                if date_val:
                                    try:
                                        dt_obj = datetime.datetime.strptime(date_val, "%Y-%m-%d %H:%M:%S")
                                        # Si encontramos un registro anterior a 2025, paramos (porque vienen ordenados DESC)
                                        if dt_obj < cutoff_date:
                                            logging.info(f"   [Cutoff] Fecha {dt_obj} < {cutoff_date}. Fin de carga histórica 2025+.")
                                            stop_loading = True
                                            break
                                    except ValueError: pass

                            # Extracción explícita de campos raíz
                            flat = {
                                'id': item.get('id'),
                                'code': item.get('code'),
                                'number': item.get('number'),
                                'date': date_val,
                                'observations': item.get('observations')
                            }

                            flat['customerId'] = get_obj_id(item.get('customer'))
                            flat['warehouseId'] = get_obj_id(item.get('warehouse'))
                            flat['issuedOrderId'] = get_obj_id(item.get('issuedOrderId'))
                            flat['receivedOrderId'] = get_obj_id(item.get('receivedOrder'))
                            
                            # Datos Ópticos (OD/OI)
                            od = item.get('opticalDataOD') or {}
                            flat['od_tipo_lente'] = od.get('lensType')
                            flat['od_material'] = od.get('lensMaterial')
                            flat['od_esfera'] = od.get('sphere')
                            flat['od_cilindro'] = od.get('cylinder')
                            flat['od_eje'] = od.get('axis')
                            flat['od_adicion'] = od.get('addition')
                            flat['od_altura'] = od.get('height')

                            oi = item.get('opticalDataOI') or {}
                            flat['oi_tipo_lente'] = oi.get('lensType')
                            flat['oi_material'] = oi.get('lensMaterial')
                            flat['oi_esfera'] = oi.get('sphere')
                            flat['oi_cilindro'] = oi.get('cylinder')
                            flat['oi_eje'] = oi.get('axis')
                            flat['oi_adicion'] = oi.get('addition')
                            flat['oi_altura'] = oi.get('height')

                            flat_items.append(flat)

                        if flat_items:
                            self._process_and_save(conn, flat_items, "Operaciones_Ordenes_Cristales", "id_orden_cristal", self.MAP_ORDENES_CRISTALES)
                            total_processed += len(flat_items)

                        if stop_loading:
                            return total_processed

                    if not items or len(items) < limit:
                        break

                    skip += limit
                    time.sleep(0.5)

            return total_processed

    def sync_received_delivery_notes(self):
            """Sincroniza recepciones de laboratorio (Albaranes) con aplanamiento de líneas."""
            if not self.token: self.get_token()
            headers = {"Authorization": f"Bearer {self.token}", "accept": "application/json"}

            start_time = time.time()
            MAX_EXECUTION_TIME = 24 * 60
            total_processed = 0

            with pyodbc.connect(self.conn_str) as conn:
                # 1. Configuración de Modo (Historical vs Incremental)
                params_base = {}
                skip = 0
                limit = 50

                if getattr(self, 'LOAD_MODE_RECEPCIONES', 'INCREMENTAL') == 'HISTORICAL':
                    start_date = datetime.datetime(2025, 1, 1)
                    params_base["fechaInicial"] = start_date.strftime("%Y-%m-%d %H:%M:%S")
                    logging.info(f"   [Historical] Recepciones Lab: Carga completa desde {params_base['fechaInicial']}")
                    
                    # Auto-Resume basado en Albaranes únicos (Headers)
                    try:
                        with conn.cursor() as cursor:
                            # Contamos IDs únicos de albarán porque la tabla está aplanada (líneas)
                            cursor.execute("SELECT COUNT(DISTINCT id_albaran) FROM Operaciones_Recepciones_Lab")
                            row = cursor.fetchone()
                            total_headers = row[0] if row else 0
                            skip = (total_headers // limit) * limit
                            logging.info(f"   [Auto-Resume] Detectados {total_headers} albaranes en SQL. Retomando desde skip {skip}.")
                    except Exception as e:
                        logging.warning(f"   [Auto-Resume] No se pudo calcular skip inicial: {e}")
                else:
                    # Patrón Incremental por defecto (ventana de seguridad 3 días)
                    try:
                        last_date = self.get_last_date(conn, "Operaciones_Recepciones_Lab", "fecha_recepcion")
                        start_date = last_date - datetime.timedelta(days=3)
                    except:
                        start_date = datetime.datetime(2025, 1, 1)
                    
                    params_base = {"fechaInicial": start_date.strftime("%Y-%m-%d %H:%M:%S")}
                    logging.info(f"   [Incremental] Recepciones Lab: Buscando desde {params_base['fechaInicial']}")

                # skip = 0
                # limit = 50

                while True:
                    if (time.time() - start_time) > MAX_EXECUTION_TIME:
                        logging.warning("   [TIMEOUT] Límite de tiempo en Recepciones Lab.")
                        break

                    params = params_base.copy()
                    params["skip"] = skip
                    items = []
                    success_batch = False

                    for retry in range(3):
                        try:
                            resp = self.session.get(f"{self.base_url}/receivedDeliveryNotes", headers=headers, params=params, timeout=(15, 90))
                            logging.info(f"   -> [REQ] skip: {skip} | URL: {resp.url}")

                            if resp.status_code == 204:
                                return total_processed

                            # Guard: errores HTTP deben lanzar excepción para activar reintento con backoff
                            if resp.status_code >= 400:
                                raise Exception(f"HTTP {resp.status_code} de Gesvision: {resp.text[:250]}")

                            items = self._safe_parse_json(resp, "receivedDeliveryNotes")

                            # Guard: la respuesta debe ser lista; dict (error) o string provocan crash aguas abajo
                            if not isinstance(items, list):
                                raise Exception(
                                    f"Respuesta inesperada de receivedDeliveryNotes "
                                    f"(HTTP {resp.status_code}, tipo {type(items).__name__}): {str(items)[:250]}"
                                )

                            logging.info(f"   -> [RES] Status: {resp.status_code} | Count: {len(items)}")
                            success_batch = True
                            break
                        except Exception as e:
                            wait = (retry + 1) * 5
                            logging.warning(f"   [!] Reintento {retry+1} en Recepciones Lab (Skip {skip}): {e}")
                            time.sleep(wait)

                    if not success_batch:
                        raise Exception(f"Fallo definitivo en Recepciones Lab lote {skip} tras 3 reintentos.")

                    if items:
                        # 3. Transformación Compleja (Flattening)
                        flat_items = []
                        for parent in items:
                            line_items = parent.get('lineItems', [])
                            if not line_items: continue

                            # Extract parent fields
                            parent_id = parent.get('id')
                            parent_number = parent.get('number')
                            parent_date = parent.get('deliveryNoteDate')
                            
                            # Customer handling
                            cust = parent.get('customer')
                            cust_id = 0
                            if cust:
                                val = cust.get('id') if isinstance(cust, dict) else cust
                                try:
                                    cust_id = int(float(val))
                                except: pass

                            for item in line_items:
                                # Date conversion (ms timestamp to datetime)
                                ts = item.get('dateFastReception')
                                dt_exact = None
                                if ts:
                                    try:
                                        dt_exact = datetime.datetime.fromtimestamp(ts / 1000.0)
                                    except: pass
                                
                                # Glasses Order ID
                                # Glasses Order ID (CRÍTICO: Extracción robusta y corrección de scope)
                                g_order = item.get('glassesOrderId')
                                if not g_order: continue

                                g_order_id = 0
                                if g_order:
                                    try:
                                        val = g_order.get('id') if isinstance(g_order, dict) else g_order
                                        g_order_id = int(float(val))
                                    except: g_order_id = 0

                                flat_items.append({
                                    'id_recepcion_linea': item.get('id'),
                                    'id_albaran': parent_id,
                                    'numero_albaran': parent_number,
                                    'id_proveedor': cust_id,
                                    'id_pedido_origen': g_order_id,
                                    'fecha_recepcion': parent_date,
                                    'fecha_recepcion_exacta': dt_exact,
                                    'costo_linea_recepcion': item.get('total')
                                })
                        
                        if flat_items:
                            self._process_and_save(conn, flat_items, "Operaciones_Recepciones_Lab", "id_recepcion_linea", self.MAP_RECEPCION_LAB)
                            total_processed += len(flat_items)

                    if not items or len(items) < limit:
                        break

                    skip += limit
                    time.sleep(0.5)

            return total_processed







    def fetch_chronological(self, conn, endpoint, table_name, pk_cols, start_date, end_date, window_minutes, rename_map):
            """Barrido de ventanas temporales para exámenes clínicos."""
            if not self.token: self.get_token()
            headers = {"Authorization": f"Bearer {self.token}", "accept": "application/json"}

            # --- CONTROL DE TIEMPO ---
            start_time_exec = time.time()
            MAX_EXECUTION_TIME = 24 * 60

            if self.LOAD_MODE_EXAMS == 'HISTORICAL':
                current_start = datetime.datetime(2025, 1, 1, 0, 0, 0)
            else:
                current_start = start_date

            while current_start < end_date:
                if (time.time() - start_time_exec) > MAX_EXECUTION_TIME:
                    logging.warning(f"   [TIMEOUT PREVENTIVO] Se alcanzó el límite de 24 minutos en Exámenes. Deteniendo.")
                    return

                current_end = current_start + datetime.timedelta(minutes=window_minutes)
                params = {"fechaInicial": current_start.strftime("%Y-%m-%d %H:%M:%S"), "fechaFinal": current_end.strftime("%Y-%m-%d %H:%M:%S")}

                try:
                    resp = self.session.get(f"{self.base_url}/{endpoint}", headers=headers, params=params, timeout=(15, 90))
                    if resp.status_code == 200 and resp.json():
                        items = resp.json()
                        self._process_and_save(conn, items, table_name, pk_cols, rename_map)
                    else:
                        logging.info(f"   [Sin Datos] Ventana {current_start} a {current_end} vacía.")
                    time.sleep(0.05)
                except Exception as e:
                    logging.warning(f"   [!] Error en ventana temporal: {e}")
                    time.sleep(10)

                current_start = current_end

    def _process_and_save(self, conn, data_list, table_name, pk_cols, rename_map):
            """Transformación: Extracción de objetos y blindaje Booleano para el producto 8204."""
            raw_list = data_list.copy() if table_name == "Ventas_Cabecera" else None

            # --- TRANSFORMACIÓN CLIENTES (Cascada de Rescate) ---
            if table_name == "Maestro_Clientes":
                for item in data_list:
                    # --- NORMALIZACIÓN DE NOMBRES (Regla 4) ---
                    raw_name = item.get('name')
                    if raw_name and isinstance(raw_name, str):
                        item['name'] = raw_name.strip().upper()
                    
                    raw_last = item.get('lastName')
                    if raw_last and isinstance(raw_last, str):
                        item['lastName'] = raw_last.strip().upper()

                    # Teléfono: mobile -> phone -> addresses['phone']
                    mobile = item.get('mobile')
                    phone = item.get('phone')
                    addr = item.get('addresses') if isinstance(item.get('addresses'), dict) else {}

                    item['telefono_principal'] = mobile if mobile else (phone if phone else addr.get('phone'))

                    # Email: email -> addresses['email'] + Normalización (Regla 4)
                    email_root = item.get('email')
                    resolved_email = email_root if email_root else addr.get('email')
                    item['email'] = resolved_email.strip().lower() if resolved_email and isinstance(resolved_email, str) else resolved_email

                    # Ubicación
                    item['codigo_postal'] = addr.get('postCode')
                    # Ciudad: municipality -> province
                    item['ciudad'] = addr.get('municipality') if addr.get('municipality') else addr.get('province')

            # --- TRANSFORMACIÓN EMPLEADOS (Privacidad + Concatenación) ---
            if table_name == "Maestro_Empleados":
                for item in data_list:
                    item['nombre_empleado'] = f"{item.get('name', '')} {item.get('lastName', '')}".strip()

            # --- TRANSFORMACIÓN CITAS (Concatenación de Nombre) ---
            if table_name == "Marketing_Citas":
                for item in data_list:
                    item['nombre_cliente'] = f"{item.get('cliente_name', '')} {item.get('lastName', '')}".strip()
            
            # --- TRANSFORMACIÓN PROVEEDORES ---
            if table_name == "Maestro_Proveedores":
                for item in data_list:
                    if not item.get('name'):
                        item['name'] = f"Proveedor Sin Nombre {item.get('id')}"
                    if not item.get('mobile'):
                        item['mobile'] = item.get('phone')

            with pd.option_context('mode.chained_assignment', None):
                df = pd.DataFrame(data_list)
                if table_name == "Ventas_Pedidos":
                    df = df.copy()

                # --- FIX ERROR 6700: Extraer IDs de Objetos JSON y Forzar Enteros ---
                def extract_safe_id(x):
                    try:
                        val = x.get('id') if isinstance(x, dict) else x
                        # Convertir a float primero para manejar strings como "4.0", luego a int
                        return int(float(val)) if val is not None and str(val).strip() != '' else 0
                    except:
                        return 0

                for complex_col in ['brand', 'category', 'customer', 'warehouse', 'optometrist', 'seller', 'employee', 'parent', 'invoice_id', 'order', 'group']:
                    if complex_col in df.columns:
                        df[complex_col] = df[complex_col].apply(extract_safe_id)

                if rename_map:
                    df = df.rename(columns={k: v for k, v in rename_map.items() if k in df.columns})
                    df = df[[v for v in rename_map.values() if v in df.columns]].copy()

                # --- FIX FECHAS: Lógica Híbrida ISO vs Latino ---
                date_cols = ['fecha_nacimiento', 'fecha_creacion_cliente', 'fecha_creacion',
                            'fecha_ultima_actualizacion', 'fecha_examen', 'fecha_factura', 'fecha_pedido', 'fecha_actualizacion',
                            'fecha_cita_inicio', 'fecha_cita_fin', 'fecha_creacion_cita', 'fecha_actualizacion_api', 'fecha_cobro', 'fecha_movimiento',
                            'fecha_solicitud', 'fecha_fabricacion', 'estatus_proceso', 'fecha_creacion_origen', 'fecha_inicio', 'fecha_fin',
                            'fecha_recepcion', 'fecha_recepcion_exacta']

                # --- LÓGICA HÍBRIDA DE FECHAS (Corrección Definitiva) ---
                # Definimos qué tablas vienen en formato Latino (DD/MM/YYYY)
                tablas_latinas = ["Ventas_Pedidos", "Marketing_Citas", "Maestro_Clientes"]
                
                # Determinamos el modo de lectura: True si es latina, False (ISO) para el resto
                usar_dia_primero = True if table_name in tablas_latinas else False
                with pd.option_context('mode.chained_assignment', None):
                    for c in date_cols:
                        if c in df.columns:
                            # Conversión dinámica según el origen de la tabla
                            df[c] = pd.to_datetime(df[c], dayfirst=usar_dia_primero, errors='coerce').dt.strftime('%Y-%m-%d %H:%M:%S')
                            # Limpieza de nulos para SQL
                            df[c] = df[c].where(df[c].notnull(), None)

                # --- FIX VITAL PARA EL PRODUCTO 8204: Convertir booleanos a 1/0 ---
                if 'es_inventariable' in df.columns:
                    df['es_inventariable'] = df['es_inventariable'].astype(str).str.lower().map({'true': 1, '1': 1, 'false': 0, '0': 0}).fillna(0).astype(int)

                if 'esta_activo' in df.columns:
                    df['esta_activo'] = df['esta_activo'].astype(str).str.lower().map({'true': 1, '1': 1, 'false': 0, '0': 0}).fillna(0).astype(int)

                # --- FIX METODOS PAGO: Convertir booleanos a 1/0 ---
                for col in ['usa_en_ingresos', 'usa_en_gastos', 'es_activo']:
                    if col in df.columns:
                        df[col] = df[col].astype(str).str.lower().map({'true': 1, '1': 1, 'false': 0, '0': 0}).fillna(0).astype(int)
                
                # --- FIX COBROS: Limpieza de Strings (Métodos de Pago) ---
                if table_name == "Finanzas_Cobros" and 'metodo_pago_nombre' in df.columns:
                    df['metodo_pago_nombre'] = df['metodo_pago_nombre'].astype(str).str.strip().str.upper()

                # Blinda IDs
                id_cols = ['id_factura', 'id_cliente', 'id_sucursal', 'id_producto', 'id_marca', 'id_categoria', 'id_empleado', 'id_pedido', 'id_cita', 'id_categoria_padre', 'id_cobro', 'id_pago_tesoreria', 'id_cuenta_contable']
                
                def safe_int_convert(x):
                    try:
                        return int(float(x)) if pd.notnull(x) and str(x).strip() != '' else 0
                    except:
                        return 0

                for c in id_cols:
                    if c in df.columns:
                        # Para Pedidos, permitimos Nulos en FKs si vienen vacíos (integridad flexible)
                        if table_name == "Ventas_Pedidos" and c in ['id_sucursal', 'id_empleado', 'id_cliente']:
                            continue

                        # --- FIX COBROS: Permitir NULL en id_factura (Anticipos) ---
                        if table_name == "Finanzas_Cobros" and c == 'id_factura':
                            df[c] = pd.to_numeric(df[c], errors='coerce')
                            df[c] = df[c].replace(0, np.nan)
                            df[c] = df[c].where(pd.notnull(df[c]), None)
                            continue

                        # Force native int (int(float(x))) para limpiar decimales y formatos
                        df[c] = df[c].apply(safe_int_convert)

                        # Regla de Negocio: Si sucursal es 0, asignar 1 (Matriz/Default) para evitar FK error
                        if c == 'id_sucursal':
                            df[c] = df[c].replace(0, 1)

                # --- INTEGRIDAD DE JERARQUÍA: Categorías ---
                if 'id_categoria_padre' in df.columns:
                    df['id_categoria_padre'] = df['id_categoria_padre'].replace(0, None)

                # --- ESCUDO DE AUTO-REPARACIÓN: EMPLEADOS FALTANTES ---
                if table_name in ["Clinica_Examenes", "Ventas_Cabecera", "Ventas_Pedidos"] and 'id_empleado' in df.columns:
                    unique_ids = df['id_empleado'].unique()
                    unique_ids = [int(x) for x in unique_ids if pd.notnull(x) and x >= 0]
                    if unique_ids:
                        placeholders = ','.join('?' * len(unique_ids))
                        cursor = conn.cursor()
                        try:
                            cursor.execute(f"SELECT id_empleado FROM Maestro_Empleados WHERE id_empleado IN ({placeholders})", tuple(unique_ids))
                            existing = {row[0] for row in cursor.fetchall()}
                            missing = [i for i in unique_ids if i not in existing]
                            if missing:
                                logging.warning(f"   [Integridad] Creando {len(missing)} empleados placeholders.")
                                dummy = []
                                for mid in missing:
                                    # Intentamos recuperar la sucursal del registro actual o usamos 1 por defecto
                                    sucursal = 1
                                    try:
                                        row = df[df['id_empleado'] == mid].iloc[0]
                                        if 'id_sucursal' in row: sucursal = int(row['id_sucursal'])
                                    except: pass

                                    dummy.append({
                                        'id_empleado': mid,
                                        'nombre_empleado': f'Empleado {mid} - Pendiente Sincro',
                                        'id_sucursal': sucursal,
                                        'tipo_empleado': 'OT', # Default para integridad
                                        'fecha_creacion': datetime.datetime.now()
                                    })
                                self.upsert_sql(conn, pd.DataFrame(dummy), "Maestro_Empleados", "id_empleado")
                        except Exception as e:
                            logging.error(f"Error integridad empleados: {e}")
                        finally:
                            cursor.close()

                # --- ESCUDO DE AUTO-REPARACIÓN: CLIENTES FALTANTES (Para Pedidos, Ventas y Cobros) ---
                if table_name in ["Ventas_Pedidos", "Ventas_Cabecera", "Finanzas_Cobros"] and 'id_cliente' in df.columns:
                    unique_ids = df['id_cliente'].unique()
                    unique_ids = [int(x) for x in unique_ids if pd.notnull(x) and x > 0]
                    if unique_ids:
                        placeholders = ','.join('?' * len(unique_ids))
                        cursor = conn.cursor()
                        try:
                            cursor.execute(f"SELECT id_cliente FROM Maestro_Clientes WHERE id_cliente IN ({placeholders})", tuple(unique_ids))
                            existing = {row[0] for row in cursor.fetchall()}
                            missing = [i for i in unique_ids if i not in existing]
                            if missing:
                                logging.warning(f"   [Integridad] Detectados {len(missing)} clientes faltantes. Iniciando Rescate Activo (JIT)...")
                                dummy = []
                                headers = {"Authorization": f"Bearer {self.token}", "accept": "application/json"}

                                for mid in missing:
                                    # Intento de Rescate Activo
                                    try:
                                        resp = self.session.get(f"{self.base_url}/customers/{mid}", headers=headers, timeout=(15, 90))
                                        if resp.status_code == 200:
                                            cust_data = resp.json()
                                            # Aplicar misma lógica de transformación que sync_customers
                                            mobile = cust_data.get('mobile')
                                            phone = cust_data.get('phone')
                                            addr = cust_data.get('addresses') if isinstance(cust_data.get('addresses'), dict) else {}

                                            dummy.append({
                                                'id_cliente': mid,
                                                'nombre': cust_data.get('name'),
                                                'apellido': cust_data.get('lastName'),
                                                'fecha_nacimiento': cust_data.get('birthDate'),
                                                'fecha_creacion_cliente': cust_data.get('creationDate'),
                                                'telefono_principal': mobile if mobile else (phone if phone else addr.get('phone')),
                                                'email': cust_data.get('email') if cust_data.get('email') else addr.get('email'),
                                                'codigo_postal': addr.get('postCode'),
                                                'ciudad': addr.get('municipality') if addr.get('municipality') else addr.get('province')
                                            })
                                            logging.info(f"      -> [Rescate] Cliente {mid} recuperado exitosamente de la API.")
                                            continue
                                    except Exception: pass

                                    # Fallback: Placeholder
                                    dummy.append({
                                        'id_cliente': mid, 'nombre': f'Cliente {mid}', 'apellido': '(Auto-generado)',
                                        'fecha_creacion_cliente': datetime.datetime.now()
                                    })
                                
                                df_dummy = pd.DataFrame(dummy)
                                for c in ['fecha_nacimiento', 'fecha_creacion_cliente']:
                                    if c in df_dummy.columns:
                                        # Punto 2: Blindaje de Fechas - Convertir a Timestamp (upsert_sql maneja la conversión a nativo)
                                        df_dummy[c] = pd.to_datetime(df_dummy[c], dayfirst=True, errors='coerce')
                                self.upsert_sql(conn, df_dummy, "Maestro_Clientes", "id_cliente")
                        except Exception as e:
                            logging.error(f"Error integridad clientes: {e}")
                        finally:
                            cursor.close()

                        # --- BLINDAJE FINAL: Filtrar registros huérfanos si el rescate falló ---
                        if table_name == "Finanzas_Cobros":
                            try:
                                with conn.cursor() as cursor:
                                    cursor.execute(f"SELECT id_cliente FROM Maestro_Clientes WHERE id_cliente IN ({placeholders})", tuple(unique_ids))
                                    final_existing = {row[0] for row in cursor.fetchall()}
                                    
                                # Mantener solo los que existen (Originales + Rescatados)
                                df = df[df['id_cliente'].isin(final_existing)].copy()
                            except Exception as e: logging.warning(f"Fallo en filtrado de integridad final: {e}")

                # --- ESCUDO DE AUTO-REPARACIÓN: SUCURSALES FALTANTES (Para Tesorería) ---
                if table_name == "Finanzas_Tesoreria" and 'id_sucursal' in df.columns:
                    unique_ids = df['id_sucursal'].unique()
                    unique_ids = [int(x) for x in unique_ids if pd.notnull(x) and x > 0]
                    if unique_ids:
                        placeholders = ','.join('?' * len(unique_ids))
                        cursor = conn.cursor()
                        try:
                            cursor.execute(f"SELECT id_sucursal FROM Maestro_Sucursales WHERE id_sucursal IN ({placeholders})", tuple(unique_ids))
                            existing = {row[0] for row in cursor.fetchall()}
                            missing = [i for i in unique_ids if i not in existing]
                            if missing:
                                logging.warning(f"   [Integridad] Detectadas {len(missing)} sucursales faltantes en Tesorería. Iniciando Rescate Activo (JIT)...")
                                dummy_warehouses = []
                                headers = {"Authorization": f"Bearer {self.token}", "accept": "application/json"}

                                for mid in missing:
                                    rescued = False
                                    try:
                                        resp = self.session.get(f"{self.base_url}/warehouses/{mid}", headers=headers, timeout=(15, 90))
                                        if resp.status_code == 200:
                                            w_data = resp.json()
                                            dummy_warehouses.append({
                                                'id_sucursal': mid,
                                                'nombre_sucursal': w_data.get('name')
                                            })
                                            logging.info(f"      -> [Rescate] Sucursal {mid} recuperada de API.")
                                            rescued = True
                                    except Exception: pass

                                    if not rescued:
                                        logging.warning(f"      -> [Fallback] Sucursal {mid} no encontrada en API. Creando placeholder.")
                                        dummy_warehouses.append({
                                            'id_sucursal': mid,
                                            'nombre_sucursal': f"Sucursal {mid} (Auto-generada)"
                                        })
                                
                                if dummy_warehouses:
                                    self.upsert_sql(conn, pd.DataFrame(dummy_warehouses), "Maestro_Sucursales", "id_sucursal")
                        except Exception as e:
                            logging.error(f"Error integridad sucursales (Tesorería): {e}")
                        finally:
                            cursor.close()

                # --- ESCUDO DE AUTO-REPARACIÓN: FACTURAS FALTANTES (Para Cobros) ---
                if table_name == "Finanzas_Cobros" and 'id_factura' in df.columns:
                    unique_ids = df['id_factura'].unique()
                    unique_ids = [int(x) for x in unique_ids if pd.notnull(x) and x > 0]
                    if unique_ids:
                        placeholders = ','.join('?' * len(unique_ids))
                        cursor = conn.cursor()
                        try:
                            cursor.execute(f"SELECT id_factura FROM Ventas_Cabecera WHERE id_factura IN ({placeholders})", tuple(unique_ids))
                            existing = {row[0] for row in cursor.fetchall()}
                            missing = [i for i in unique_ids if i not in existing]
                            if missing:
                                logging.warning(f"   [Integridad] Detectadas {len(missing)} facturas faltantes para cobros. Creando placeholders.")
                                dummy = []
                                for mid in missing:
                                    dummy.append({'id_factura': mid, 'id_cliente': 0, 'id_sucursal': 1, 'fecha_factura': datetime.datetime(2025, 1, 1), 'monto_total': 0, 'id_empleado': 0})
                                self.upsert_sql(conn, pd.DataFrame(dummy), "Ventas_Cabecera", "id_factura")
                        except Exception as e:
                            logging.error(f"Error integridad facturas en cobros: {e}")
                        finally:
                            cursor.close()

                # --- ESCUDO DE AUTO-REPARACIÓN: PRODUCTOS FALTANTES (Para Inventario) ---
                if table_name == "Operaciones_Inventario" and 'id_producto' in df.columns:
                    unique_ids = df['id_producto'].unique()
                    unique_ids = [int(x) for x in unique_ids if pd.notnull(x) and x > 0]
                    if unique_ids:
                        placeholders = ','.join('?' * len(unique_ids))
                        cursor = conn.cursor()
                        try:
                            cursor.execute(f"SELECT id_producto FROM Maestro_Productos WHERE id_producto IN ({placeholders})", tuple(unique_ids))
                            existing = {row[0] for row in cursor.fetchall()}
                            missing = [i for i in unique_ids if i not in existing]
                            if missing:
                                logging.warning(f"   [Integridad] Detectados {len(missing)} productos faltantes en Inventario. Iniciando Rescate Activo (JIT)...")
                                dummy_products = []
                                now = datetime.datetime.now()
                                headers = {"Authorization": f"Bearer {self.token}", "accept": "application/json"}

                                for mid in missing:
                                    rescued = False
                                    try:
                                        resp = self.session.get(f"{self.base_url}/products/{mid}", headers=headers, timeout=(15, 90))
                                        if resp.status_code == 200:
                                            p_data = resp.json()

                                            brand_val = p_data.get('brand')
                                            brand_id = brand_val.get('id') if isinstance(brand_val, dict) else (brand_val if brand_val else 0)

                                            cat_val = p_data.get('category')
                                            cat_id = cat_val.get('id') if isinstance(cat_val, dict) else (cat_val if cat_val else 0)

                                            inv_raw = str(p_data.get('inventoriable', 'false')).lower()
                                            es_inv = 1 if inv_raw in ['true', '1'] else 0

                                            dummy_products.append({
                                                'id_producto': mid,
                                                'nombre_producto': p_data.get('description'),
                                                'referencia': p_data.get('reference'),
                                                'codigo_barras': p_data.get('barCode'),
                                                'costo_compra': p_data.get('pricePurchase', 0),
                                                'precio_venta': p_data.get('priceWithVAT', 0),
                                                'id_marca': brand_id,
                                                'id_categoria': cat_id,
                                                'es_inventariable': es_inv,
                                                'fecha_creacion': p_data.get('creationDate', now),
                                                'fecha_ultima_actualizacion': p_data.get('lastUpdateDate', now)
                                            })
                                            logging.info(f"      -> [Rescate] Producto {mid} recuperado de API.")
                                            rescued = True
                                    except Exception: pass

                                    if not rescued:
                                        logging.warning(f"      -> [Fallback] Producto {mid} no encontrado en API. Creando placeholder.")
                                        dummy_products.append({
                                            'id_producto': mid,
                                            'nombre_producto': f"Producto {mid} (Auto-generado)",
                                            'referencia': 'PENDIENTE',
                                            'codigo_barras': '',
                                            'costo_compra': 0,
                                            'precio_venta': 0,
                                            'id_marca': 0,
                                            'id_categoria': 0,
                                            'es_inventariable': 0,
                                            'fecha_creacion': now,
                                            'fecha_ultima_actualizacion': now
                                        })

                                df_dummy = pd.DataFrame(dummy_products)
                                for c in ['fecha_creacion', 'fecha_ultima_actualizacion']:
                                    if c in df_dummy.columns:
                                        df_dummy[c] = pd.to_datetime(df_dummy[c], dayfirst=True, errors='coerce')

                                self.upsert_sql(conn, df_dummy, "Maestro_Productos", "id_producto")
                        except Exception as e:
                            logging.error(f"Error integridad productos (Inventario): {e}")
                        finally:
                            cursor.close()

                df['fecha_carga_etl'] = datetime.datetime.now()
                pks = [pk_cols] if isinstance(pk_cols, str) else pk_cols
                
                # Validar existencia de PKs antes de dedup para evitar KeyError
                missing_pks = [col for col in pks if col not in df.columns]
                if missing_pks:
                    logging.warning(f"   [Skip] Tabla {table_name}: Faltan columnas PK {missing_pks}. Cols disponibles: {list(df.columns)}")
                    return

                # --- FIX: Gestión de Nulos (NaN y Vacíos a None) ---
                df = df.replace(r'^\s*$', None, regex=True)
                df = df.replace({np.nan: None, float('nan'): None})
                df = df.where(pd.notnull(df), None)

                df = df.drop_duplicates(subset=pks, keep='last').where(pd.notnull(df), None)

            self.upsert_sql(conn, df, table_name, pk_cols)
            if table_name == "Ventas_Cabecera" and raw_list:
                self._extract_sales_details(conn, raw_list)

    def _extract_sales_details(self, conn, invoices_list):
            """Maneja el detalle de facturas con protección contra objetos anidados."""
            details = []
            for inv in invoices_list:
                inv_id = inv.get('id')
                items = inv.get('lineItems', [])
                for item in items:
                    details.append({
                        'id_factura': inv_id, 'id_linea': item.get('id'), 'id_producto': item.get('product'),
                        'cantidad': item.get('quantity'), 'precio_unitario': item.get('unitPrice'),
                        'total_linea': item.get('total')
                    })

            if details:
                df_det = pd.DataFrame(details)
                for field in ['id_factura', 'id_linea', 'id_producto']:
                    df_det[field] = pd.to_numeric(df_det[field], errors='coerce').fillna(0).astype(np.int64)
                for c in ['cantidad', 'precio_unitario', 'total_linea']:
                    df_det[c] = pd.to_numeric(df_det[c], errors='coerce').fillna(0.0)

                # --- FIX INTEGRIDAD REFERENCIAL: Crear productos faltantes ---
                unique_prod_ids = df_det['id_producto'].unique()
                unique_prod_ids = [int(x) for x in unique_prod_ids] # Convertir a int nativo

                if len(unique_prod_ids) > 0:
                    placeholders = ','.join('?' * len(unique_prod_ids))
                    cursor = conn.cursor()
                    try:
                        cursor.execute(f"SELECT id_producto FROM Maestro_Productos WHERE id_producto IN ({placeholders})", tuple(unique_prod_ids))
                        existing_ids = {row[0] for row in cursor.fetchall()}

                        missing_ids = [pid for pid in unique_prod_ids if pid not in existing_ids]

                        if missing_ids:
                            logging.warning(f"   [Integridad] Detectados {len(missing_ids)} productos inexistentes. Iniciando Rescate Activo (JIT)...")
                            dummy_products = []
                            now = datetime.datetime.now()
                            headers = {"Authorization": f"Bearer {self.token}", "accept": "application/json"}

                            for mid in missing_ids:
                                rescued = False
                                try:
                                    resp = self.session.get(f"{self.base_url}/products/{mid}", headers=headers, timeout=(15, 90))
                                    if resp.status_code == 200:
                                        p_data = resp.json()

                                        # Extracción de IDs de objetos anidados
                                        brand_val = p_data.get('brand')
                                        brand_id = brand_val.get('id') if isinstance(brand_val, dict) else (brand_val if brand_val else 0)

                                        cat_val = p_data.get('category')
                                        cat_id = cat_val.get('id') if isinstance(cat_val, dict) else (cat_val if cat_val else 0)

                                        # Conversión booleana
                                        inv_raw = str(p_data.get('inventoriable', 'false')).lower()
                                        es_inv = 1 if inv_raw in ['true', '1'] else 0

                                        dummy_products.append({
                                            'id_producto': mid,
                                            'nombre_producto': p_data.get('description'),
                                            'referencia': p_data.get('reference'),
                                            'codigo_barras': p_data.get('barCode'),
                                            'costo_compra': p_data.get('pricePurchase', 0),
                                            'precio_venta': p_data.get('priceWithVAT', 0),
                                            'id_marca': brand_id,
                                            'id_categoria': cat_id,
                                            'es_inventariable': es_inv,
                                            'fecha_creacion': p_data.get('creationDate', now),
                                            'fecha_ultima_actualizacion': p_data.get('lastUpdateDate', now)
                                        })
                                        logging.info(f"      -> [Rescate] Producto {mid} recuperado de API.")
                                        rescued = True
                                except Exception: pass

                                if not rescued:
                                    logging.warning(f"      -> [Fallback] Producto {mid} no encontrado en API. Creando placeholder.")
                                    dummy_products.append({
                                        'id_producto': mid,
                                        'nombre_producto': f"Producto {mid} (Auto-generado)",
                                        'referencia': 'PENDIENTE',
                                        'codigo_barras': '',
                                        'costo_compra': 0,
                                        'precio_venta': 0,
                                        'id_marca': 0,
                                        'id_categoria': 0,
                                        'es_inventariable': 0,
                                        'fecha_creacion': now,
                                        'fecha_ultima_actualizacion': now
                                    })
                            self.upsert_sql(conn, pd.DataFrame(dummy_products), "Maestro_Productos", "id_producto")
                    except Exception as e:
                        logging.error(f"   [!] Error intentando corregir integridad referencial: {e}")
                    finally:
                        cursor.close()

                df_det['fecha_carga_etl'] = datetime.datetime.now()
                self.upsert_sql(conn, df_det, "Ventas_Detalle", ["id_factura", "id_linea"])

    def upsert_sql(self, conn, df, table_name, pk_cols):
            """CARGA FINAL: Versión simplificada y robusta para SQL Azure."""
            pks = [pk_cols] if isinstance(pk_cols, str) else pk_cols
            cursor = conn.cursor()

            # --- CRITICAL STABILITY FIX: Desactivamos fast_executemany para evitar Crash del Host ---
            cursor.fast_executemany = False

            try:
                if df.empty:
                    return

                if table_name not in self.schema_cache:
                    cursor.execute(f"SELECT TOP 0 * FROM {table_name}")
                    self.schema_cache[table_name] = {c[0]: c[1] for c in cursor.description}

                sql_types = self.schema_cache[table_name]
                cols_to_use = [c for c in df.columns if c in sql_types]

                stg = f"#Stg_{table_name}"
                cursor.execute(f"IF OBJECT_ID('tempdb..{stg}') IS NOT NULL DROP TABLE {stg}")
                cursor.execute(f"SELECT TOP 0 * INTO {stg} FROM {table_name}")

                params = []
                for row_tuple in df[cols_to_use].itertuples(index=False):
                    clean_row = []
                    for col, val in zip(cols_to_use, row_tuple):
                        try:
                            # Conversión estricta a tipos nativos (Protocolo TDS)
                            if val is None or pd.isna(val):
                                clean_row.append(None)
                            elif isinstance(val, bool):
                                clean_row.append(1 if val else 0)
                            elif isinstance(val, pd.Timestamp):
                                clean_row.append(val.to_pydatetime())
                            elif isinstance(val, (datetime.datetime, datetime.date)):
                                clean_row.append(val)
                            elif isinstance(val, np.datetime64):
                                clean_row.append(pd.Timestamp(val).to_pydatetime())
                            elif isinstance(val, (int, np.int64)):
                                clean_row.append(int(val))
                            elif isinstance(val, (float, np.float64)):
                                clean_row.append(float(val))
                            else:
                                clean_row.append(str(val))
                        except:
                            clean_row.append(None)
                    params.append(tuple(clean_row))

                insert_sql = f"INSERT INTO {stg} ({','.join(cols_to_use)}) VALUES ({','.join(['?']*len(cols_to_use))})"

                # Ejecución directa sin lógica de resurrección (Fail Clean)
                cursor.executemany(insert_sql, params)

                # BLOQUE MERGE (Alineado correctamente fuera del try/except de inserción)
                merge_sql = f"MERGE {table_name} AS T USING {stg} AS S ON ({' AND '.join([f'T.{k}=S.{k}' for k in pks])}) "
                
                # --- FIX MERGE CONSTRUCTOR (Punto 3: Error 42000) ---
                update_cols = [c for c in cols_to_use if c not in pks]
                if update_cols:
                    merge_sql += f"WHEN MATCHED THEN UPDATE SET {', '.join([f'T.{c}=S.{c}' for c in update_cols])} "
                
                merge_sql += f"WHEN NOT MATCHED THEN INSERT ({','.join(cols_to_use)}) VALUES ({','.join(['S.'+c for c in cols_to_use])});"

                cursor.execute(merge_sql)
                cursor.execute(f"DROP TABLE {stg}")
                conn.commit()
            except Exception as e:
                logging.error(f"Error en upsert_sql para {table_name}: {e}")
                conn.rollback()
                raise
            finally:
                cursor.close()

    # ====================================================================================================
    # FASE 2 — DOLARIZACIÓN VÍA API v2 (Módulo de ENRIQUECIMIENTO — solo UPDATE, jamás INSERT)
    # ====================================================================================================

    def _get_v2(self, recurso, params=None, retries=3):
            """GET a la API v2 de Gesvision con parseo de envelope {data, totalCount, skip, limit, hasMore}.
            Devuelve (items:list, total_count:int, has_more:bool). Reintentos con backoff 5/10/15s."""
            url = f"{self.BASE_URL_V2}/{recurso}"
            params = params or {}

            for retry in range(retries):
                try:
                    # Headers DENTRO del bucle: si hubo renovación de token en un retry anterior, se usa el nuevo.
                    headers = {"Authorization": f"Bearer {self.token}", "accept": "application/json"}
                    resp = self.session.get(url, headers=headers, params=params, timeout=(15, 90))

                    if resp.status_code == 204:
                        return [], 0, False

                    if resp.status_code == 401:
                        logging.warning(f"   [V2 {recurso}] 401: token expirado. Renovando...")
                        self.get_token()
                        raise Exception("Token renovado — reintento")

                    if resp.status_code >= 400:
                        raise Exception(f"HTTP {resp.status_code} de Gesvision v2 [{recurso}]: {resp.text[:250]}")

                    body = self._safe_parse_json(resp, recurso)

                    if not isinstance(body, dict) or 'data' not in body:
                        raise Exception(
                            f"Envelope inesperado de v2 [{recurso}] "
                            f"(HTTP {resp.status_code}, tipo {type(body).__name__}): {str(body)[:250]}"
                        )

                    items = body.get('data')
                    if not isinstance(items, list):
                        raise Exception(
                            f"Campo 'data' inesperado de v2 [{recurso}] "
                            f"(tipo {type(items).__name__}): {str(items)[:250]}"
                        )

                    total_count = body.get('totalCount', 0)
                    has_more = bool(body.get('hasMore', False))
                    skip_actual = params.get('skip', 0)

                    logging.info(
                        f"   -> [V2 {recurso}] skip:{skip_actual} status:{resp.status_code} "
                        f"count:{len(items)} total:{total_count} hasMore:{has_more}"
                    )
                    return items, total_count, has_more
                except Exception as e:
                    if retry < retries - 1:
                        wait = (retry + 1) * 5
                        logging.warning(f"   [!] Reintento {retry+1} en API v2 [{recurso}]: {e}")
                        time.sleep(wait)
                    else:
                        raise

    def _enrich_sql(self, conn, df, table_name, pk_cols):
            """ENRIQUECIMIENTO: UPDATE-only vía staging + MERGE SIN rama INSERT.

            CRÍTICO: el MERGE contiene ÚNICAMENTE 'WHEN MATCHED THEN UPDATE SET ...'.
            PROHIBIDO agregar 'WHEN NOT MATCHED THEN INSERT'. Si una fila de v2 no existe
            en el DW, simplemente no se actualiza (comportamiento deseado).

            Devuelve (filas_actualizadas, filas_no_encontradas)."""
            pks = [pk_cols] if isinstance(pk_cols, str) else pk_cols
            cursor = conn.cursor()
            cursor.fast_executemany = False

            try:
                if df.empty:
                    return 0, 0

                if table_name not in self.schema_cache:
                    cursor.execute(f"SELECT TOP 0 * FROM {table_name}")
                    self.schema_cache[table_name] = {c[0]: c[1] for c in cursor.description}

                sql_types = self.schema_cache[table_name]
                cols_to_use = [c for c in df.columns if c in sql_types]

                update_cols = [c for c in cols_to_use if c not in pks]
                if not update_cols:
                    return 0, len(df)

                stg = f"#Enr_{table_name}"
                cursor.execute(f"IF OBJECT_ID('tempdb..{stg}') IS NOT NULL DROP TABLE {stg}")
                cursor.execute(f"SELECT TOP 0 * INTO {stg} FROM {table_name}")

                params = []
                for row_tuple in df[cols_to_use].itertuples(index=False):
                    clean_row = []
                    for col, val in zip(cols_to_use, row_tuple):
                        try:
                            # Conversión estricta a tipos nativos (Protocolo TDS) — idéntica a upsert_sql
                            if val is None or pd.isna(val):
                                clean_row.append(None)
                            elif isinstance(val, bool):
                                clean_row.append(1 if val else 0)
                            elif isinstance(val, pd.Timestamp):
                                clean_row.append(val.to_pydatetime())
                            elif isinstance(val, (datetime.datetime, datetime.date)):
                                clean_row.append(val)
                            elif isinstance(val, np.datetime64):
                                clean_row.append(pd.Timestamp(val).to_pydatetime())
                            elif isinstance(val, (int, np.int64)):
                                clean_row.append(int(val))
                            elif isinstance(val, (float, np.float64)):
                                clean_row.append(float(val))
                            else:
                                clean_row.append(str(val))
                        except:
                            clean_row.append(None)
                    params.append(tuple(clean_row))

                insert_sql = f"INSERT INTO {stg} ({','.join(cols_to_use)}) VALUES ({','.join(['?']*len(cols_to_use))})"
                cursor.executemany(insert_sql, params)

                # SOLO WHEN MATCHED — está prohibido agregar WHEN NOT MATCHED THEN INSERT (ver docstring).
                merge_sql = (
                    f"MERGE {table_name} AS T USING {stg} AS S "
                    f"ON ({' AND '.join([f'T.{k}=S.{k}' for k in pks])}) "
                    f"WHEN MATCHED THEN UPDATE SET {', '.join([f'T.{c}=S.{c}' for c in update_cols])};"
                )
                cursor.execute(merge_sql)

                row = cursor.execute("SELECT @@ROWCOUNT AS n").fetchone()
                filas_actualizadas = int(row[0]) if row and row[0] is not None else 0
                filas_no_encontradas = len(df) - filas_actualizadas

                cursor.execute(f"DROP TABLE {stg}")
                conn.commit()
                return filas_actualizadas, filas_no_encontradas
            except Exception as e:
                logging.error(f"Error en _enrich_sql para {table_name}: {e}")
                conn.rollback()
                raise
            finally:
                cursor.close()

    def sync_dolar_ventas(self):
            """Enriquece Ventas_Cabecera y Ventas_Detalle con montos USD desde API v2.
            MODO ENRIQUECIMIENTO: solo UPDATE. No inserta filas. No toca columnas VES."""
            if self.API_VERSION_VENTAS == 'V1':
                logging.info("   [DOLAR_VENTAS] Desactivado (API_VERSION_VENTAS='V1'). Sin acción.")
                return 0

            if not self.token: self.get_token()

            start_time = time.time()
            MAX_EXECUTION_TIME = 24 * 60
            total_actualizado = 0
            total_no_encontrado = 0
            paginas = 0
            CHECKPOINT_KEY = 'checkpoint_dolar_ventas_skip'
            LIMIT = 200

            with pyodbc.connect(self.conn_str) as conn:
                mode = getattr(self, 'LOAD_MODE_DOLAR_VENTAS', 'INCREMENTAL')

                if mode == 'HISTORICAL':
                    params_base = {"sort": "id:asc"}
                    skip = self._get_checkpoint(conn, CHECKPOINT_KEY)
                    skip = skip if isinstance(skip, int) else 0
                    logging.info(f"   [Historical] Dolar Ventas: Retomando desde skip {skip} (checkpoint).")
                else:
                    fecha_inicio = datetime.datetime.utcnow() - datetime.timedelta(days=3)
                    params_base = {"modifiedAfter": fecha_inicio.strftime("%Y-%m-%dT%H:%M:%S") + "-04:00"}
                    skip = 0
                    logging.info(f"   [Incremental] Dolar Ventas: Buscando modificados desde {params_base['modifiedAfter']}")

                while True:
                    # El checkpoint de la página anterior ya quedó guardado al final de la iteración previa
                    # (ver bloque "skip += LIMIT / _update_checkpoint" más abajo) antes de llegar aquí.
                    if (time.time() - start_time) > MAX_EXECUTION_TIME:
                        if mode == 'HISTORICAL':
                            self._update_checkpoint(conn, CHECKPOINT_KEY, skip)
                        logging.warning(f"   [TIMEOUT] Ronda finalizada por límite de 24 min. Checkpoint guardado: skip={skip}. RELANZAR para continuar.")
                        logging.info(
                            f"   [DOLAR_VENTAS] Resumen parcial: {total_actualizado} actualizadas, "
                            f"{total_no_encontrado} no encontradas, {paginas} páginas."
                        )
                        return total_actualizado

                    params = params_base.copy()
                    params["skip"] = skip
                    params["limit"] = LIMIT

                    items, total_count, has_more = self._get_v2("sales-invoices", params)
                    paginas += 1

                    filas = []
                    for item in items:
                        if item.get('id') is None:
                            logging.warning(f"   [!] Item de sales-invoices sin 'id'. Omitido: {str(item)[:150]}")
                            continue

                        exchange_rate = item.get('exchangeRate')
                        total_paid = item.get('totalPaid')
                        outstanding = item.get('outstandingAmount')

                        monto_pagado_usd = None
                        if exchange_rate not in (None, 0) and total_paid is not None:
                            try:
                                if float(exchange_rate) > 0:
                                    monto_pagado_usd = round(float(total_paid) / float(exchange_rate), 2)
                            except (TypeError, ValueError):
                                monto_pagado_usd = None

                        saldo_pendiente_usd = None
                        if exchange_rate not in (None, 0) and outstanding is not None:
                            try:
                                if float(exchange_rate) > 0:
                                    saldo_pendiente_usd = round(float(outstanding) / float(exchange_rate), 2)
                            except (TypeError, ValueError):
                                saldo_pendiente_usd = None

                        fecha_factura_v2 = None
                        doc_date = item.get('documentDate')
                        if doc_date:
                            try:
                                dt_parsed = datetime.datetime.fromisoformat(doc_date)
                                tz_gmt4 = datetime.timezone(datetime.timedelta(hours=-4))
                                fecha_factura_v2 = dt_parsed.astimezone(tz_gmt4).replace(tzinfo=None)
                            except ValueError:
                                logging.warning(f"   [!] documentDate inválido para id {item.get('id')}: {doc_date}")

                        codigo_doc = item.get('code')
                        if codigo_doc:
                            base, sep, num = codigo_doc.rpartition('-')
                            if sep and num.isdigit():
                                codigo_doc = f"{base}/{num}"

                        filas.append({
                            'id_factura': item['id'],
                            'moneda_documento': item.get('currencyCode'),
                            'tasa_cambio': exchange_rate,
                            'monto_total_usd': item.get('totalSystem'),
                            'monto_neto_usd': item.get('netAmountSystem'),
                            'iva_usd': item.get('vatAmountSystem'),
                            'monto_pagado_usd': monto_pagado_usd,
                            'saldo_pendiente_usd': saldo_pendiente_usd,
                            'estado_pago_api': item.get('paymentStatus'),
                            'fecha_factura_v2': fecha_factura_v2,
                            'fecha_sync_v2': datetime.datetime.utcnow(),
                            'codigo_documento_api': codigo_doc,
                            'numero_doc_fiscal_api': item.get('fiscalDocumentNumber'),
                            'estado_entrega_api': item.get('deliveryStatus'),
                            'igtf_ves': item.get('paymentMethodTaxAmount')
                        })

                    if filas:
                        df = pd.DataFrame(filas)
                        df = df.where(pd.notnull(df), None)

                        actualizados, no_encontrados = self._enrich_sql(conn, df, "Ventas_Cabecera", "id_factura")
                        total_actualizado += actualizados
                        total_no_encontrado += no_encontrados

                        ids_pagina = [f['id_factura'] for f in filas]

                        if no_encontrados > 0:
                            logging.warning(f"   [BRECHA] {no_encontrados} facturas de v2 no existen en Ventas_Cabecera (página skip {skip})")
                            with conn.cursor() as cur:
                                placeholders_brecha = ','.join(['?'] * len(ids_pagina))
                                cur.execute(f"SELECT id_factura FROM Ventas_Cabecera WHERE id_factura IN ({placeholders_brecha})", ids_pagina)
                                existentes = {row[0] for row in cur.fetchall()}
                            faltantes = sorted(set(ids_pagina) - existentes)
                            logging.warning(f"   [BRECHA-IDS] {len(faltantes)} ids | Muestra: {faltantes[:10]}")

                        # Derivar detalle SOLO de las facturas de esta página (SQL puro, ids parametrizados)
                        try:
                            with conn.cursor() as cursor:
                                placeholders = ','.join(['?'] * len(ids_pagina))
                                cursor.execute(
                                    f"""
                                    UPDATE d
                                        SET d.total_linea_usd = ROUND(d.total_linea * c.monto_total_usd / c.monto_total, 2)
                                    FROM dbo.Ventas_Detalle d
                                    INNER JOIN dbo.Ventas_Cabecera c ON c.id_factura = d.id_factura
                                    WHERE d.id_factura IN ({placeholders})
                                        AND c.monto_total_usd > 0 AND c.monto_total > 0
                                    """,
                                    ids_pagina
                                )
                                filas_detalle = cursor.rowcount
                            conn.commit()
                            logging.info(f"   -> [DOLAR_VENTAS] Detalle actualizado: {filas_detalle} líneas (skip {skip})")
                        except Exception:
                            conn.rollback()
                            raise

                    if mode == 'HISTORICAL':
                        skip += LIMIT
                        self._update_checkpoint(conn, CHECKPOINT_KEY, skip)
                    else:
                        skip += LIMIT

                    if not has_more:
                        if mode == 'HISTORICAL':
                            self._update_checkpoint(conn, CHECKPOINT_KEY, 0)
                        break

                logging.info(
                    f"   ✅ [DOLAR_VENTAS] Resumen: {total_actualizado} actualizadas, "
                    f"{total_no_encontrado} no encontradas, {paginas} páginas."
                )
                return total_actualizado

    def sync_dolar_tasas(self):
            """Registra la tasa de cambio oficial diaria de Gesvision a partir del campo exchangeRate que el ERP
            estampa en cada factura. Usa la tasa DOMINANTE del día: robusta frente a overrides manuales por
            documento, tasas rezagadas y exchangeRate defectuoso. Idempotente."""
            with pyodbc.connect(self.conn_str) as conn:
                cursor = conn.cursor()
                try:
                    cursor.execute("""
                        MERGE dbo.Param_Tasas_Cambio AS T
                        USING (
                            SELECT fecha, tasa, documentos_base, documentos_dia
                            FROM (
                                SELECT CAST(fecha_factura_v2 AS DATE) AS fecha,
                                       tasa_cambio                    AS tasa,
                                       COUNT(*)                       AS documentos_base,
                                       SUM(COUNT(*)) OVER (PARTITION BY CAST(fecha_factura_v2 AS DATE)) AS documentos_dia,
                                       ROW_NUMBER() OVER (PARTITION BY CAST(fecha_factura_v2 AS DATE)
                                                          ORDER BY COUNT(*) DESC, tasa_cambio DESC)     AS rn
                                FROM dbo.Ventas_Cabecera
                                WHERE monto_total > 0 AND monto_total_usd > 0
                                  AND fecha_factura_v2 IS NOT NULL
                                  AND ABS(monto_total/monto_total_usd - tasa_cambio) <= 1
                                GROUP BY CAST(fecha_factura_v2 AS DATE), tasa_cambio
                            ) x
                            WHERE rn = 1
                        ) AS S ON (T.fecha = S.fecha)
                        WHEN MATCHED THEN UPDATE SET T.tasa = S.tasa, T.documentos_base = S.documentos_base,
                                                     T.documentos_dia = S.documentos_dia,
                                                     T.fecha_carga_etl = SYSUTCDATETIME()
                        WHEN NOT MATCHED THEN INSERT (fecha, tasa, origen, documentos_base, documentos_dia)
                             VALUES (S.fecha, S.tasa, 'GESVISION_FACTURAS_V2', S.documentos_base, S.documentos_dia);
                    """)
                    conn.commit()

                    row = cursor.execute("SELECT COUNT(*), MIN(fecha), MAX(fecha) FROM dbo.Param_Tasas_Cambio").fetchone()
                    n = row[0] if row else 0
                    fecha_min = row[1] if row else None
                    fecha_max = row[2] if row else None
                    logging.info(f"   -> [DOLAR_TASAS] {n} días con tasa | rango {fecha_min} .. {fecha_max}")

                    baja_confianza = cursor.execute("""
                        SELECT fecha, tasa, documentos_base, documentos_dia FROM dbo.Param_Tasas_Cambio
                        WHERE documentos_dia > 0 AND (documentos_base * 1.0 / documentos_dia) < 0.6
                    """).fetchall()
                    for fecha, tasa, base, dia in baja_confianza:
                        logging.warning(f"   [TASA-BAJA-CONFIANZA] {fecha}: tasa {tasa} respaldada por {base}/{dia} facturas")

                    return n
                except Exception as e:
                    logging.error(f"Error en sync_dolar_tasas: {e}")
                    conn.rollback()
                    raise
                finally:
                    cursor.close()

    def sync_dolar_pedidos(self):
            """Enriquece Ventas_Pedidos con campos nativos de la API v2 (code, total, totalPaid, deliveryStatus,
            fecha con zona horaria) y montos USD derivados de la tasa oficial diaria (Param_Tasas_Cambio).
            MODO ENRIQUECIMIENTO: solo UPDATE."""
            if self.API_VERSION_PEDIDOS == 'V1':
                logging.info("   [DOLAR_PEDIDOS] Desactivado (API_VERSION_PEDIDOS='V1'). Sin acción.")
                return 0

            if not self.token: self.get_token()

            start_time = time.time()
            MAX_EXECUTION_TIME = 24 * 60
            total_actualizado = 0
            total_no_encontrado = 0
            paginas = 0
            CHECKPOINT_KEY = 'checkpoint_dolar_pedidos_skip'
            LIMIT = 200

            with pyodbc.connect(self.conn_str) as conn:
                mode = getattr(self, 'LOAD_MODE_DOLAR_PEDIDOS', 'INCREMENTAL')

                if mode == 'HISTORICAL':
                    params_base = {"sort": "id:asc"}
                    skip = self._get_checkpoint(conn, CHECKPOINT_KEY)
                    skip = skip if isinstance(skip, int) else 0
                    logging.info(f"   [Historical] Dolar Pedidos: Retomando desde skip {skip} (checkpoint).")
                else:
                    fecha_inicio = datetime.datetime.utcnow() - datetime.timedelta(days=3)
                    params_base = {"modifiedAfter": fecha_inicio.strftime("%Y-%m-%dT%H:%M:%S") + "-04:00"}
                    skip = 0
                    logging.info(f"   [Incremental] Dolar Pedidos: Buscando modificados desde {params_base['modifiedAfter']}")

                with conn.cursor() as cur_chk:
                    cur_chk.execute("SELECT COUNT(*) FROM dbo.Param_Tasas_Cambio")
                    hay_tasas = cur_chk.fetchone()[0] > 0
                if not hay_tasas:
                    logging.warning(
                        "   [DOLAR_PEDIDOS] Param_Tasas_Cambio está vacía: los montos USD no se calcularán en esta "
                        "corrida. Los campos v2 (code, total, totalPaid, deliveryStatus) sí se enriquecen igual. "
                        "Re-ejecutar este módulo después de DOLAR_TASAS para completar el USD."
                    )

                while True:
                    # El checkpoint de la página anterior ya quedó guardado al final de la iteración previa
                    # (ver bloque "skip += LIMIT / _update_checkpoint" más abajo) antes de llegar aquí.
                    if (time.time() - start_time) > MAX_EXECUTION_TIME:
                        if mode == 'HISTORICAL':
                            self._update_checkpoint(conn, CHECKPOINT_KEY, skip)
                        logging.warning(f"   [TIMEOUT] Ronda finalizada por límite de 24 min. Checkpoint guardado: skip={skip}. RELANZAR para continuar.")
                        logging.info(
                            f"   [DOLAR_PEDIDOS] Resumen parcial: {total_actualizado} actualizados, "
                            f"{total_no_encontrado} no encontrados, {paginas} páginas."
                        )
                        return total_actualizado

                    params = params_base.copy()
                    params["skip"] = skip
                    params["limit"] = LIMIT

                    items, total_count, has_more = self._get_v2("sales-orders", params)
                    paginas += 1

                    filas = []
                    for item in items:
                        if item.get('id') is None:
                            logging.warning(f"   [!] Item de sales-orders sin 'id'. Omitido: {str(item)[:150]}")
                            continue

                        fecha_pedido_v2 = None
                        doc_date = item.get('documentDate')
                        if doc_date:
                            try:
                                dt_parsed = datetime.datetime.fromisoformat(doc_date)
                                tz_gmt4 = datetime.timezone(datetime.timedelta(hours=-4))
                                fecha_pedido_v2 = dt_parsed.astimezone(tz_gmt4).replace(tzinfo=None)
                            except ValueError:
                                logging.warning(f"   [!] documentDate inválido para id {item.get('id')}: {doc_date}")

                        codigo_doc = None
                        serie = item.get('series')
                        numero = item.get('number')
                        if serie and numero is not None:
                            try:
                                codigo_doc = f"{serie}/{int(numero):06d}"
                            except (ValueError, TypeError):
                                codigo_doc = None

                        filas.append({
                            'id_pedido': item['id'],
                            'codigo_documento_api': codigo_doc,
                            'monto_total_api': item.get('total'),
                            'monto_pagado_api': item.get('totalPaid'),
                            'estado_entrega_api': item.get('deliveryStatus'),
                            'fecha_pedido_v2': fecha_pedido_v2,
                            'fecha_sync_v2': datetime.datetime.utcnow()
                        })

                    if filas:
                        df = pd.DataFrame(filas)
                        df = df.where(pd.notnull(df), None)

                        actualizados, no_encontrados = self._enrich_sql(conn, df, "Ventas_Pedidos", "id_pedido")
                        total_actualizado += actualizados
                        total_no_encontrado += no_encontrados

                        ids_pagina = [f['id_pedido'] for f in filas]

                        if no_encontrados > 0:
                            logging.warning(f"   [BRECHA] {no_encontrados} pedidos de v2 no existen en Ventas_Pedidos (página skip {skip})")
                            with conn.cursor() as cur:
                                placeholders_brecha = ','.join(['?'] * len(ids_pagina))
                                cur.execute(f"SELECT id_pedido FROM Ventas_Pedidos WHERE id_pedido IN ({placeholders_brecha})", ids_pagina)
                                existentes = {row[0] for row in cur.fetchall()}
                            faltantes = sorted(set(ids_pagina) - existentes)
                            logging.warning(f"   [BRECHA-IDS] {len(faltantes)} ids | Muestra: {faltantes[:10]}")

                        # Derivar USD con la tasa oficial de la fecha del pedido (SQL puro, ids parametrizados)
                        try:
                            with conn.cursor() as cursor:
                                placeholders = ','.join(['?'] * len(ids_pagina))
                                cursor.execute(
                                    f"""
                                    UPDATE p
                                       SET p.tasa_cambio_aplicada = t.tasa,
                                           p.monto_total_usd      = ROUND(p.monto_total_api / t.tasa, 2),
                                           p.monto_pagado_usd     = ROUND(ISNULL(p.monto_pagado_api,0) / t.tasa, 2),
                                           p.saldo_pendiente_usd  = CASE
                                                                       WHEN (p.monto_total_api - ISNULL(p.monto_pagado_api,0)) < 0 THEN 0
                                                                       ELSE ROUND((p.monto_total_api - ISNULL(p.monto_pagado_api,0)) / t.tasa, 2)
                                                                     END
                                    FROM dbo.Ventas_Pedidos p
                                    CROSS APPLY (SELECT TOP 1 pt.tasa
                                                 FROM dbo.Param_Tasas_Cambio pt
                                                 WHERE pt.fecha <= CAST(p.fecha_pedido_v2 AS DATE)
                                                 ORDER BY pt.fecha DESC) t
                                    WHERE p.id_pedido IN ({placeholders})
                                      AND p.fecha_pedido_v2 IS NOT NULL
                                      AND p.monto_total_api > 0
                                      AND t.tasa > 0
                                    """,
                                    ids_pagina
                                )
                                filas_dolarizadas = cursor.rowcount
                            conn.commit()
                            logging.info(f"   -> [DOLAR_PEDIDOS] Pedidos dolarizados: {filas_dolarizadas} (skip {skip})")
                        except Exception:
                            conn.rollback()
                            raise

                    if mode == 'HISTORICAL':
                        skip += LIMIT
                        self._update_checkpoint(conn, CHECKPOINT_KEY, skip)
                    else:
                        skip += LIMIT

                    if not has_more:
                        if mode == 'HISTORICAL':
                            self._update_checkpoint(conn, CHECKPOINT_KEY, 0)
                        break

                logging.info(
                    f"   ✅ [DOLAR_PEDIDOS] Resumen: {total_actualizado} actualizados, "
                    f"{total_no_encontrado} no encontrados, {paginas} páginas."
                )
                return total_actualizado

    def sync_dolar_inventario(self):
            """Dolariza Operaciones_Inventario con la tasa oficial más reciente (Param_Tasas_Cambio).
            Costo de reposición: costo_promedio_ves / tasa_actual. SQL puro, sin API. Idempotente."""
            with pyodbc.connect(self.conn_str) as conn:
                cursor = conn.cursor()
                try:
                    row_tasa = cursor.execute(
                        "SELECT TOP 1 fecha, tasa FROM dbo.Param_Tasas_Cambio ORDER BY fecha DESC"
                    ).fetchone()

                    if not row_tasa:
                        logging.warning("   [DOLAR_INVENTARIO] Sin tasas registradas, abortando")
                        return 0

                    fecha_tasa, tasa = row_tasa[0], row_tasa[1]

                    cursor.execute(
                        """
                        UPDATE dbo.Operaciones_Inventario
                           SET costo_promedio_usd   = ROUND(costo_promedio / ?, 4),
                               valor_total_usd      = ROUND((cantidad_disponible * costo_promedio) / ?, 2),
                               tasa_cambio_aplicada = ?,
                               fecha_dolarizacion   = SYSUTCDATETIME()
                         WHERE costo_promedio > 0
                           AND cantidad_disponible IS NOT NULL
                        """,
                        tasa, tasa, tasa
                    )
                    filas_actualizadas = cursor.rowcount
                    conn.commit()

                    logging.info(f"   -> [DOLAR_INVENTARIO] {filas_actualizadas} filas dolarizadas | tasa {tasa} ({fecha_tasa})")

                    return filas_actualizadas
                except Exception as e:
                    logging.error(f"Error en sync_dolar_inventario: {e}")
                    conn.rollback()
                    raise
                finally:
                    cursor.close()

    def sync_dolar_cobros(self):
            """Dolariza Finanzas_Cobros. Prioriza la tasa REAL de la factura vinculada (Ventas_Cabecera);
            si el cobro no tiene factura, deriva de la tasa oficial del día (Param_Tasas_Cambio) según
            fecha_cobro. SQL puro, sin API. Idempotente."""
            with pyodbc.connect(self.conn_str) as conn:
                cursor = conn.cursor()
                try:
                    inicio_run = cursor.execute("SELECT SYSUTCDATETIME()").fetchone()[0]

                    cursor.execute("""
                        UPDATE fc
                           SET fc.tasa_cambio_aplicada = COALESCE(vc.tasa_cambio, pt.tasa),
                               fc.monto_cobrado_usd    = ROUND(fc.monto_cobrado / COALESCE(vc.tasa_cambio, pt.tasa), 2),
                               fc.origen_tasa          = CASE WHEN vc.tasa_cambio IS NOT NULL THEN 'FACTURA_REAL'
                                                              ELSE 'DERIVADA_FECHA' END,
                               fc.fecha_dolarizacion   = SYSUTCDATETIME()
                        FROM dbo.Finanzas_Cobros fc
                        LEFT JOIN dbo.Ventas_Cabecera vc ON vc.id_factura = fc.id_factura AND vc.tasa_cambio IS NOT NULL
                        OUTER APPLY (
                            SELECT TOP 1 tasa FROM dbo.Param_Tasas_Cambio
                            WHERE fecha <= CAST(fc.fecha_cobro AS DATE)
                            ORDER BY fecha DESC
                        ) pt
                        WHERE fc.monto_cobrado > 0
                          AND COALESCE(vc.tasa_cambio, pt.tasa) IS NOT NULL
                    """)
                    filas_actualizadas = cursor.rowcount
                    conn.commit()

                    desglose = cursor.execute(
                        "SELECT origen_tasa, COUNT(*) FROM dbo.Finanzas_Cobros WHERE fecha_dolarizacion >= ? GROUP BY origen_tasa",
                        inicio_run
                    ).fetchall()
                    n_factura_real = 0
                    n_derivada = 0
                    for origen, cnt in desglose:
                        if origen == 'FACTURA_REAL':
                            n_factura_real = cnt
                        elif origen == 'DERIVADA_FECHA':
                            n_derivada = cnt

                    logging.info(f"   -> [DOLAR_COBROS] {filas_actualizadas} cobros dolarizados | factura_real: {n_factura_real} | derivada: {n_derivada}")

                    return filas_actualizadas
                except Exception as e:
                    logging.error(f"Error en sync_dolar_cobros: {e}")
                    conn.rollback()
                    raise
                finally:
                    cursor.close()

# ====================================================================================================
# [TESTING LOCAL] Función temporal para probar envío de Telegram - DESHABILITADA 05/05/2026
# ====================================================================================================
# Deshabilitada después de confirmar que Telegram funciona correctamente
# Chat ID actualizado a: -1003693182380 (grupo fue upgradeable a supergrupo)
# Para reactivar, descomenta @app.route y la función TestTelegram
# @app.route(route="test-telegram", methods=["POST"])
# def TestTelegram(req: func.HttpRequest) -> func.HttpResponse:
#     """
#     Función TEMPORAL para probar envío de mensajes a Telegram localmente.
#
#     Uso:
#         POST http://localhost:7071/api/test-telegram
#         Body: {"mensaje": "Tu mensaje aquí"}
#
#     Después de enviar el mensaje, sigue procesando normalmente.
#     """
#     timestamp = datetime.datetime.now().strftime("%Y-%m-%d %H:%M:%S")
#
#     try:
#         # Usar logging en lugar de print para evitar problemas de codificación en Windows
#         logging.info("[TEST TELEGRAM] Iniciando prueba de envio")
#         logging.info(f"Timestamp: {timestamp}")
#
#         # Parsear mensaje del body
#         logging.info("[PASO 1] Parseando mensaje del request...")
#         try:
#             req_body = req.get_json()
#             mensaje_test = req_body.get("mensaje", "Prueba de Telegram - ETL Opticolor funcionando")
#             logging.info(f"Mensaje recibido: {mensaje_test}")
#         except Exception as parse_err:
#             logging.warning(f"No hay JSON, usando mensaje por defecto: {parse_err}")
#             mensaje_test = "Prueba de Telegram - ETL Opticolor funcionando"
#
#         # Verificar variables de entorno
#         logging.info("[PASO 2] Verificando credenciales de Telegram...")
#         token = os.getenv("TELEGRAM_BOT_TOKEN")
#         chat_id = os.getenv("TELEGRAM_CHAT_ID")
#
#         if token:
#             token_display = f"{token[:10]}...{token[-5:]}"
#             logging.info(f"TELEGRAM_BOT_TOKEN configurado: {token_display}")
#         else:
#             logging.error("TELEGRAM_BOT_TOKEN NO CONFIGURADO")
#
#         if chat_id:
#             logging.info(f"TELEGRAM_CHAT_ID configurado: {chat_id}")
#         else:
#             logging.error("TELEGRAM_CHAT_ID NO CONFIGURADO")
#
#         # Crear instancia ETL y enviar mensaje
#         logging.info("[PASO 3] Creando instancia GesvisionEtl...")
#         etl = GesvisionEtl()
#         logging.info("Instancia creada exitosamente")
#
#         logging.info("[PASO 4] Enviando mensaje a Telegram...")
#         etl.notificar_telegram(f"TEST: {mensaje_test}")
#         logging.info(f"Mensaje enviado a Telegram: {mensaje_test}")
#
#         # Respuesta exitosa
#         response_msg = f"OK - Mensaje enviado a Telegram: '{mensaje_test}'\n\nAhora sigue procesando..."
#         logging.info("[TEST COMPLETADO] Telegram funcionando correctamente")
#
#         return func.HttpResponse(response_msg, status_code=200)
#
#     except Exception as e:
#         error_msg = str(e)
#         logging.error(f"Error en TestTelegram: {error_msg}", exc_info=True)
#
#         return func.HttpResponse(
#             f"ERROR: {error_msg}",
#             status_code=500
#         )