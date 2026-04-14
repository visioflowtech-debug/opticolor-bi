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

app = func.FunctionApp()
# --- SECCIÓN 1: DISPARADORES (TIMER TRIGGERS) ---
# Orquestación Basada en Estados y Horarios CRON para Producción.

# --- NUEVO MODELO: CASCADA SECUENCIAL (Trigger-to-Trigger) ---
# Solo la primera función tiene TimerTrigger. Las demás se ejecutan en cadena.

# Horarios Panama (UTC-5): 07:50, 09:50, 11:50, 13:50, 15:50, 17:50, 19:50, 21:50
# Equivalente UTC (+5h):   12:50, 14:50, 16:50, 18:50, 20:50, 22:50, 00:50, 02:50
@app.timer_trigger(schedule="0 50 0,2,12,14,16,18,20,22 * * *", arg_name="myTimer", run_on_startup=False)
def EtlOrquestadorPrincipal(myTimer: func.TimerRequest) -> None:
    """Función Maestra que inicia la cascada de ejecución."""
    logging.info("--- [INICIO] CICLO ETL OPTILUX (CASCADA) ---")
    etl = GesvisionEtl()
    reporte = []
    start_global = time.time()
    MAX_DURATION_MINS = 24  # Límite de seguridad Azure
    
    def check_time_limit():
        """Verifica si se excedió el tiempo límite global."""
        elapsed = (time.time() - start_global) / 60
        if elapsed > MAX_DURATION_MINS:
            logging.warning(f"⚠️ [TIMEOUT PREVENTIVO] Tiempo excedido ({elapsed:.1f} min). Deteniendo cascada.")
            return True
        return False

    try:
        # --- 1. ZOHO BOOKS (PRIORIDAD ACTUAL) ---
        try:
            logging.info("--- [INICIO] MÓDULO: ZOHO_AUTH ---")
            etl._refresh_zoho_token()
            reporte.append({'modulo': 'ZOHO_AUTH', 'status': '✅ (Token Renovado)'})
            
            if not check_time_limit():
                reporte.append(etl.ejecutar_modulo('ZOHO_GASTOS', etl.sync_zoho_expenses))
        except Exception as e:
            logging.error(f"Fallo crítico en Zoho: {e}")
            reporte.append({'modulo': 'ZOHO_AUTH', 'status': '❌ (Fallo de Autenticación)'})

        # --- GHL PRIORITY EXECUTION (Safety First) ---
        GHL_SAFE_LIMIT = MAX_DURATION_MINS - 5
        ghl_modules = [
            ('GHL_AUTH', lambda: etl._refresh_ghl_token()),
            ('GHL_CALENDARIOS', etl.sync_ghl_calendars),
            ('GHL_CONTACTOS', lambda: etl.sync_ghl_contacts(start_global, GHL_SAFE_LIMIT)),
            ('GHL_OPPORTUNITIES', lambda: etl.sync_ghl_opportunities(start_global, max_mins=GHL_SAFE_LIMIT)),
            ('GHL_CITAS', lambda: etl.sync_ghl_appointments(start_global, max_mins=GHL_SAFE_LIMIT))
        ]

        for mod_name, mod_func in ghl_modules:
            if check_time_limit(): break
            
            if mod_name == 'GHL_AUTH':
                try:
                    logging.info("--- [INICIO] MÓDULO: GHL_AUTH ---")
                    mod_func()
                    reporte.append({'modulo': 'GHL_AUTH', 'status': '✅ Conexión Ok'})
                except Exception as e:
                    reporte.append({'modulo': 'GHL_AUTH', 'status': '❌ Fallo'})
            else:
                reporte.append(etl.ejecutar_modulo(mod_name, mod_func))

        # --- GESVISION (Remaining Modules) ---
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
            ('COBROS', lambda: f"{etl.sync_collections()[0]} (Total: {etl.sync_collections()[1]})"),
            ('TESORERIA', lambda: f"{etl.sync_treasury()[0]} (Total: {etl.sync_treasury()[1]})"),
            ('PEDIDOS_LAB', etl.sync_laboratory_orders),
            ('RECEPCIONES_LAB', etl.sync_received_delivery_notes),
            ('INVENTARIO', etl.sync_inventory)
        ]

        for mod_name, mod_func in remaining_modules:
            if check_time_limit(): break
            reporte.append(etl.ejecutar_modulo(mod_name, mod_func))

        # --- REPORTE FINAL ---
        duration = (time.time() - start_global) / 60
        etl.enviar_resumen_ciclo_telegram(reporte, duration)
        logging.info(f"--- [FIN] CICLO ETL COMPLETADO EN {duration:.2f} MIN ---")

    except Exception as e:
        duration = (time.time() - start_global) / 60
        logging.error(f"Error crítico en cascada: {e}")
        etl.enviar_resumen_ciclo_telegram(reporte, duration, error_critico=str(e))
    finally:
        if etl.session: etl.session.close()


# --- SECCIÓN 2: CLASE DE LÓGICA GesvisionEtl ---

class GesvisionEtl:
        # --- TABLERO DE CONTROL DE CARGA (GRANULAR) ---
        # 'HISTORICAL': Carga masiva/backfill (Fecha fija 2024, Auto-Resume con Count).
        # 'INCREMENTAL': Mantenimiento diario (Últimos 3 días, Skip 0).
        # 'FULL': Barrido completo (Para dimensiones pequeñas).

        LOAD_MODE_CUSTOMERS = 'INCREMENTAL'  # Ya tenemos la base masiva.
        LOAD_MODE_ORDERS    = 'INCREMENTAL'  # Mantenimiento diario.
        LOAD_MODE_INVOICES  = 'INCREMENTAL'  # Mantenimiento diario.
        LOAD_MODE_INVENTORY = 'INCREMENTAL'  # Control de stock.
        LOAD_MODE_EXAMS     = 'INCREMENTAL'  # Mantenimiento diario (Scanner Adaptativo).
        LOAD_MODE_PRODUCTS  = 'INCREMENTAL'  # Catálogo.
        LOAD_MODE_CITAS     = 'INCREMENTAL'  # Agenda.
        LOAD_MODE_METODOS_PAGO = 'INCREMENTAL'     # Catálogo pequeño.
        LOAD_MODE_COBROS    = 'INCREMENTAL'  # Dual Load (Historical/Incremental).
        LOAD_MODE_TREASURY  = 'INCREMENTAL'  # Movimientos de caja/banco.
        LOAD_MODE_LAB       = 'INCREMENTAL'  # Pedidos de laboratorio.
        LOAD_MODE_RECEPCIONES = 'INCREMENTAL' # Carga inicial de recepciones.
        LOAD_MODE_GLASSES_ORDERS = 'INCREMENTAL' # Carga de órdenes de cristales (Historical/Incremental).
        LOAD_MODE_ZOHO_GASTOS = 'INCREMENTAL'
        
        # --- GHL LOAD MODES ---
        LOAD_MODE_GHL_CONTACTS = 'INCREMENTAL'
        LOAD_MODE_GHL_OPPORTUNITIES = 'INCREMENTAL'
        LOAD_MODE_GHL_CITAS = 'INCREMENTAL'

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
        
        # --- GHL MAPPINGS ---
        MAP_GHL_CONTACTS = {
            'id': 'id_contacto_ghl', 
            'locationId': 'location_id',   # <-- Agregado
            'firstName': 'nombre', 
            'lastName': 'apellido',
            'email': 'email', 
            'phone': 'telefono', 
            'source': 'origen_source',
            'dateAdded': 'fecha_creacion_ghl',
            'type': 'tipo_contacto',        # <-- Corregido
            'dateUpdated': 'fecha_actualizacion_ghl', 
            'dateOfBirth': 'fecha_nacimiento',
            'city': 'ciudad', 
            'state': 'estado', 
            'country': 'pais',
            'utm_source': 'utm_source', 
            'utm_medium': 'utm_medium',
            'tags_concatenados': 'tags_concatenados', # <-- Corregido
            'genero': 'genero', 
            'profesion': 'profesion', 
            'sucursal_nombre': 'sucursal_nombre', 
            'doctor_asignado': 'doctor_asignado', 
            'estatus_paciente': 'estatus_paciente'
        }
        MAP_GHL_OPPORTUNITIES = {
            'id': 'id_oportunidad_ghl', 
            'contactId': 'id_contacto_ghl',
            'name': 'nombre_oportunidad', 
            'monetaryValue': 'monto_valor',
            'status': 'estado_oportunidad', 
            'pipelineId': 'id_pipeline',
            'pipelineStageId': 'id_etapa_pipeline', 
            'createdAt': 'fecha_creacion',
            'updatedAt': 'fecha_actualizacion', 
            'lastStatusChangeAt': 'fecha_ultimo_cambio_estado', 
            'lastStageChangeAt': 'fecha_ultimo_cambio_etapa',
            'source': 'origen_oportunidad'
        }
        MAP_GHL_CITAS = {
            'id': 'id_cita_ghl', 
            'contactId': 'id_contacto_ghl',
            'calendarId': 'id_calendario', 
            'title': 'titulo_cita',
            'appointmentStatus': 'estado_cita', # 'confirmed', 'showed', etc.
            'startTime': 'fecha_inicio',
            'endTime': 'fecha_fin',
            'assignedUserId': 'id_usuario_asignado',
            'groupId': 'id_grupo_calendario',
            'dateAdded': 'fecha_creacion',
            'notes': 'notas_cita'
        }
        MAP_GHL_CALENDARS = {'id': 'id_calendario', 'name': 'nombre_calendario', 'description': 'descripcion'}

        # 4. Mapeo: Asegurar que last_modified_time esté presente para la lógica incremental.
        MAP_ZOHO_GASTOS = {
            'expense_id': 'id_gasto_zoho', 
            'date': 'fecha_gasto', 
            'amount': 'monto', 
            'vendor_name': 'proveedor', 
            'account_name': 'cuenta_contable', 
            'status': 'estatus_pago',
            'description': 'descripcion',  # <-- Agregado por solicitud
            'last_modified_time': 'last_modified_time'
        }

        def __init__(self):
            # --- Gesvision API ---
            self.base_url = "https://app.gesvision.com/gesmo/rest/api"
            self.user = os.getenv("GESVISION_USER")
            self.password = os.getenv("GESVISION_PASS")
            self.token = None

            # --- Zoho Books API ---
            self.zoho_client_id = os.getenv("ZOHO_CLIENT_ID")
            self.zoho_client_secret = os.getenv("ZOHO_CLIENT_SECRET")
            self.zoho_access_token = None
            self.zoho_org_id = None

            # --- GoHighLevel API ---
            self.ghl_base_url = "https://services.leadconnectorhq.com"
            self.ghl_access_token = None
            self.ghl_location_id = None

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
            """Envía notificaciones a Telegram sin interrumpir el flujo principal."""
            try:
                token = os.getenv("TELEGRAM_BOT_TOKEN")
                chat_id = os.getenv("TELEGRAM_CHAT_ID")
                if not token or not chat_id: return

                url = f"https://api.telegram.org/bot{token}/sendMessage"
                payload = {
                    "chat_id": chat_id,
                    "text": mensaje,
                    "disable_notification": silencioso
                }
                requests.post(url, json=payload, timeout=5)
            except Exception as e:
                logging.warning(f"Fallo envío Telegram: {e}")

        def enviar_resumen_ciclo_telegram(self, reporte, duracion_min, error_critico=None):
            """Envía un reporte consolidado al final del ciclo."""
            try:
                msg = f"📊 REPORTE ETL OPTILUX\n\n"
                
                # Iconos por módulo
                iconos = {
                    'ZOHO_AUTH': '🔑',
                    'SUCURSALES': '🏢', 'EMPLEADOS': '👔', 'CATEGORIAS': '🏷️', 'METODOS_PAGO': '💳',
                    'PROVEEDORES': '🚚', 'MARCAS_FULL': '🏷️', 'PRODUCTOS': '📦', 'CLIENTES': '👥',
                    'CITAS': '📅', 'EXAMENES': '👁️',
                    'PEDIDOS': '📝', 'ORDENES_CRISTALES': '眼镜', 'VENTAS': '🛒', 'COBROS': '💰', 'TESORERIA': '🏦',
                    'PEDIDOS_LAB': '🧪', 'INVENTARIO': '📊', 'PROVEEDORES': '🚚',
                    'RECEPCIONES_LAB': '📥',
                    'ZOHO_GASTOS': '🧾',
                    'GHL_CONTACTS': '👥', 'GHL_OPPORTUNITIES': '💎', 'GHL_CITAS': '📅', 'GHL_CALENDARIOS': '🗓️'
                }

                for item in reporte:
                    mod = item['modulo']
                    ico = iconos.get(mod, '🔹')
                    status = item['status']
                    
                    # Lógica de Anomalías API
                    if mod in self.modulos_con_fallo_api:
                        ico = '🟠'
                        desc_error = self.modulos_con_fallo_api[mod]
                        linea = f"{ico} {mod}: {desc_error}"
                    else:
                        # Formato compacto estándar
                        linea = f"{ico} {mod}: {status}"
                    
                    msg += linea + "\n"

                msg += f"\n⏱️ *Tiempo Total Ciclo:* {duracion_min:.1f} min."
                
                if error_critico:
                    msg += f"\n\n❌ *ERROR CRÍTICO:* La cascada se detuvo.\n{error_critico}"

                self.notificar_telegram(msg)
            except Exception as e:
                logging.error(f"Error generando reporte Telegram: {e}")

        def ejecutar_modulo(self, nombre_modulo, funcion_sync):
            """Wrapper para ejecutar un módulo, registrar estado y manejar errores."""
            logging.info(f"--- [INICIO] MÓDULO: {nombre_modulo} ---")
            self.registrar_inicio(nombre_modulo)
            self.current_module = nombre_modulo
            
            try:
                resultado = funcion_sync()
                self.registrar_fin(nombre_modulo, 'COMPLETADO')
                logging.info(f"--- [FIN] MÓDULO: {nombre_modulo} ---")
                
                # Enriquecer estatus con resultado si es posible (ej: recuento de registros)
                status_final = '✅'
                if isinstance(resultado, int):
                    status_final = f"✅ ({resultado} registros)"
                elif isinstance(resultado, str) and 'Total:' in resultado:
                    status_final = f"✅ {resultado}"
                
                return {'modulo': nombre_modulo, 'status': status_final, 'resultado': resultado}
            except Exception as e:
                logging.error(f"Error en {nombre_modulo}: {e}")
                self.registrar_fin(nombre_modulo, 'ERROR', e)
                # Re-lanzar excepción para detener la cascada
                raise Exception(f"Fallo en {nombre_modulo}: {str(e)}")
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


        def _get_checkpoint_ghl(self, key):
            """Versión exclusiva para GHL: Obtiene checkpoint sin requerir una conexión externa."""
            try:
                with pyodbc.connect(self.conn_str) as conn:
                    cursor = conn.cursor()
                    # Si no existe, se crea con el schema solicitado por el usuario
                    cursor.execute("""
                        IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Etl_Checkpoints' AND xtype='U')
                        CREATE TABLE Etl_Checkpoints (
                            KeyName VARCHAR(100) PRIMARY KEY,
                            LastValue NVARCHAR(MAX),
                            updated_at DATETIME DEFAULT GETDATE()
                        )
                    """)
                    cursor.execute("SELECT LastValue FROM Etl_Checkpoints WHERE KeyName = ?", key)
                    row = cursor.fetchone()
                    return row[0] if row else None
            except Exception as e:
                logging.warning(f"⚠️ Error leyendo checkpoint GHL {key}: {e}")
                return None

        def _update_checkpoint_ghl(self, key, value):
            """Versión exclusiva para GHL: Guarda checkpoint sin requerir una conexión externa."""
            try:
                with pyodbc.connect(self.conn_str) as conn:
                    cursor = conn.cursor()
                    # Aseguramos existencia (redundante pero seguro) - SIN updated_at
                    cursor.execute("""
                        IF NOT EXISTS (SELECT * FROM sysobjects WHERE name='Etl_Checkpoints' AND xtype='U')
                        CREATE TABLE Etl_Checkpoints (
                            KeyName VARCHAR(100) PRIMARY KEY,
                            LastValue NVARCHAR(MAX)
                        )
                    """)
                    cursor.execute("""
                        MERGE Etl_Checkpoints AS target
                        USING (SELECT ? AS KeyName, ? AS LastValue) AS source
                        ON (target.KeyName = source.KeyName)
                        WHEN MATCHED THEN
                            UPDATE SET LastValue = source.LastValue
                        WHEN NOT MATCHED THEN
                            INSERT (KeyName, LastValue) VALUES (source.KeyName, source.LastValue);
                    """, key, str(value))
                    conn.commit()
            except Exception as e:
                logging.error(f"⚠️ Error guardando checkpoint GHL {key}: {e}")

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

                    current_time = datetime.datetime.now()

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

        def sync_dimensions(self):
            """Sincroniza almacenes/sucursales."""
            if not self.token: self.get_token()
            headers = {"Authorization": f"Bearer {self.token}", "accept": "application/json"}
            resp = self.session.get(f"{self.base_url}/warehouses", headers=headers, timeout=(15, 90))
            if resp.status_code == 200:
                items = self._safe_parse_json(resp, "warehouses")
                if items:
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

            # Lógica Smart Sync: Si no forzamos histórico, traemos solo los últimos 3 días
            # Si LOAD_MODE_CUSTOMERS == 'HISTORICAL': Usa skip = COUNT(*) y sin filtro de fecha (carga total profunda).
            # Si LOAD_MODE_CUSTOMERS == 'INCREMENTAL': Usa skip = 0 y fechaInicial = Hace 3 días.
            params_base = {}
            if self.LOAD_MODE_CUSTOMERS == 'INCREMENTAL':
                fecha_inicio = datetime.datetime.now() - datetime.timedelta(days=10)
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
                    last_date = datetime.datetime(2020, 1, 1)
                    skip = self._get_checkpoint(conn, CHECKPOINT_KEY)
                    logging.info(f"   [Historical] Retomando carga masiva desde SKIP: {skip}")
                else:
                    last_date = self.get_last_date(conn, "Maestro_Productos", "fecha_ultima_actualizacion")
                    skip = 0
                    logging.info(f"   [Incremental] Buscando cambios desde: {last_date}")

                limit = 50
                buffer = []
                total_processed = 0
                
                BUFFER_LIMIT = 200 
                start_time = time.time()
                MAX_EXECUTION_TIME = 9 * 60 

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

                                # C. Buffer
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
                limit_date = datetime.datetime(2025, 1, 1)
                limit_date = datetime.datetime(2025, 12, 1, 0, 0, 0)
                limit_date = datetime.datetime(2025, 12, 1) # Límite para la carga histórica.
                current_day = datetime.datetime.now()

                if self.LOAD_MODE_EXAMS == 'INCREMENTAL':
                    # En modo incremental, siempre barremos los últimos 10 días para asegurar consistencia.
                    limit_date = datetime.datetime.now() - datetime.timedelta(days=10)
                    logging.info(f"   [Incremental] Barriendo los últimos 10 días (hasta {limit_date.strftime('%Y-%m-%d')}).")
                else: # HISTORICAL
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

        def _get_zoho_config_from_db(self):
            """
            Obtiene la configuración de Zoho (refresh_token, org_id) desde la base de datos.
            Usa zoho_tokens.json como fallback si la base de datos falla.
            """
            logging.info("   [Auth] Obteniendo configuración de Zoho desde la base de datos...")
            try:
                with pyodbc.connect(self.conn_str) as conn:
                    cursor = conn.cursor()
                    cursor.execute("SELECT refresh_token, organization_id FROM Etl_Zoho_Auth WHERE Id = 1")
                    row = cursor.fetchone()
                    if row and row.refresh_token and row.organization_id:
                        logging.info("   [Auth] Configuración de Zoho obtenida de SQL Azure.")
                        return {'refresh_token': row.refresh_token, 'organization_id': row.organization_id}
            except Exception as e:
                logging.warning(f"   [Auth] No se pudo leer la configuración de Zoho desde la BD: {e}. Intentando fallback a JSON.")

            # --- Fallback a zoho_tokens.json ---
            logging.warning("   [Auth] Fallback: Intentando leer zoho_tokens.json.")
            token_path = os.path.join(os.getcwd(), 'zoho_tokens.json')
            try:
                with open(token_path, 'r') as f:
                    tokens = json.load(f)
                refresh_token = tokens.get('refresh_token')
                org_id = tokens.get('organization_id')
                if not refresh_token or not org_id:
                    raise ValueError("Faltan 'refresh_token' u 'organization_id' en zoho_tokens.json")
                logging.info("   [Auth] Configuración de Zoho obtenida desde zoho_tokens.json (fallback).")
                return {'refresh_token': refresh_token, 'organization_id': org_id}
            except (FileNotFoundError, json.JSONDecodeError, ValueError) as e:
                error_msg = f"Error crítico de autenticación. Falló la BD y el archivo de fallback zoho_tokens.json: {e}"
                logging.error(error_msg)
                self.notificar_telegram(f"❌ ERROR ZOHO AUTH: {error_msg}")
                raise Exception(error_msg)

        def _refresh_zoho_token(self):
            """
            Refresca el token de acceso de Zoho Books, actualizando la base de datos y el estado de la clase.
            Utiliza un sistema de reintentos y notifica en caso de fallo crítico.
            """
            logging.info("   [Auth] Iniciando proceso de refresco de token de Zoho Books...")

            # 1. Obtener configuración (refresh_token y org_id) desde la fuente de verdad (DB con fallback a JSON)
            try:
                zoho_config = self._get_zoho_config_from_db()
                refresh_token = zoho_config['refresh_token']
                self.zoho_org_id = zoho_config['organization_id'] # Actualizar org_id en la instancia
            except Exception as e:
                # _get_zoho_config_from_db ya notifica y eleva la excepción, no es necesario duplicar.
                raise e

            # 2. Preparar y ejecutar la petición de refresco con reintentos
            url = "https://accounts.zoho.com/oauth/v2/token"
            # FIX: Usar self.zoho_client_id/secret que vienen de os.getenv
            payload = {
                'refresh_token': refresh_token,
                'client_id': self.zoho_client_id, 
                'client_secret': self.zoho_client_secret,
                'grant_type': 'refresh_token'
            }
            for retry in range(3):
                try:
                    resp = self.session.post(url, data=payload, timeout=(15, 90))
                    resp.raise_for_status()  # Lanza HTTPError para 4xx/5xx
                    new_token_data = resp.json()
                    new_access_token = new_token_data.get('access_token')

                    if not new_access_token:
                        raise ValueError("La respuesta de Zoho no contiene 'access_token'")

                    # 3. Actualización Atómica: Base de datos, archivo de fallback y estado de la clase
                    logging.info("   [Auth] Token de Zoho refrescado exitosamente. Actualizando persistencia...")

                    # 3.1. Actualizar Base de Datos (Fuente Primaria)
                    with pyodbc.connect(self.conn_str) as conn:
                        cursor = conn.cursor()
                        cursor.execute("UPDATE Etl_Zoho_Auth SET access_token = ?, last_update = GETDATE() WHERE Id = 1", new_access_token)
                        conn.commit()
                    logging.info("   [Auth] Base de datos actualizada con el nuevo access_token.")

                    # 3.2. Actualizar/Crear archivo JSON (Fuente Secundaria/Fallback, escritura opcional)
                    token_path = os.path.join(os.getcwd(), 'zoho_tokens.json')
                    try:
                        # Se usa 'w' para crear el archivo si no existe o sobrescribirlo.
                        # Esto resuelve el error de 'r+' en un archivo inexistente.
                        json_content = {
                            'refresh_token': refresh_token,
                            'organization_id': self.zoho_org_id,
                            'access_token': new_access_token
                        }
                        with open(token_path, 'w') as f:
                            json.dump(json_content, f, indent=4)
                        logging.info("   [Auth] Archivo de respaldo zoho_tokens.json actualizado/creado.")
                    except (IOError, OSError) as e:
                        # Comportamiento esperado en entornos de solo lectura (Azure).
                        logging.warning(f"   [Auth] No se pudo escribir el archivo de respaldo zoho_tokens.json (opcional, no crítico): {e}")

                    # 3.3. Actualizar estado de la instancia y retornar
                    self.zoho_access_token = new_access_token
                    return new_access_token

                except (requests.exceptions.RequestException, ValueError, pyodbc.Error) as e:
                    wait_time = (retry + 1) * 5
                    logging.warning(f"   [Auth] Fallo al refrescar/guardar token de Zoho (intento {retry+1}/3): {e}. Reintentando en {wait_time}s...")
                    if retry == 2:
                        error_msg = f"No se pudo refrescar el token de Zoho después de 3 intentos: {e}"
                        logging.error(error_msg)
                        self.notificar_telegram(f"❌ ERROR CRÍTICO ZOHO AUTH: {error_msg}")
                        raise Exception(error_msg)
                    time.sleep(wait_time)

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
                fecha_inicio = datetime.datetime.now() - datetime.timedelta(days=10)
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
                    last_date = datetime.datetime.now() - datetime.timedelta(days=10)
                
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

                            # 2. Insertar citas (Ahora seguro)
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
                last_id_sql = self.get_last_id(conn, "Ventas_Cabecera", "id_factura")
                logging.info(f"   [SQL Check] Iniciando sincronización desde ID: {last_id_sql}")

                skip = 0
                buffer = []
                BUFFER_LIMIT = 50 # Reducido drásticamente para evitar desbordamiento de memoria en Ventas

                # Si LOAD_MODE_INVOICES == 'HISTORICAL':
                # fechaInicial = '2024-01-01 00:00:00'.
                # skip = (COUNT(*) // 50) * 50. (Auto-Resume para API descendente).
                # Si LOAD_MODE_INVOICES == 'INCREMENTAL':
                # fechaInicial = Hace 3 días.
                # skip = 0.
                params_base = {}
                if self.LOAD_MODE_INVOICES == 'INCREMENTAL':
                    fecha_inicio = datetime.datetime.now() - datetime.timedelta(days=10)
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
                                break

                            skip += 50
                            success_batch = True
                            time.sleep(0.05)
                            break
                        except Exception as e:
                            logging.warning(f"   [!] Error en skip {skip}: {e}. Reintentando...")
                            time.sleep(10)
                    
                    if not items or len(items) < 50:
                        if buffer: self._process_and_save(conn, buffer, "Ventas_Cabecera", "id_factura", self.MAP_VENTA)
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
            """Sincroniza niveles de inventario con estrategia Híbrida."""
            if not self.token: self.get_token()
            headers = {"Authorization": f"Bearer {self.token}", "accept": "application/json"}

            start_time = time.time()
            MAX_EXECUTION_TIME = 24 * 60
            total_processed = 0

            with pyodbc.connect(self.conn_str) as conn:
                # Estrategia de Fechas
                params_base = {}
                skip = 0

                if self.LOAD_MODE_INVENTORY == 'HISTORICAL':
                    try:
                        with conn.cursor() as cursor:
                            cursor.execute("SELECT COUNT(*) FROM Operaciones_Inventario")
                            row = cursor.fetchone()
                            total_rows = row[0] if row else 0
                            skip = (total_rows // 50) * 50
                            logging.info(f"   [Historical Load] Inventario: Retomando carga histórica desde skip {skip} (Total en BD: {total_rows}).")
                    except Exception as e:
                        logging.warning(f"   [Auto-Resume] No se pudo calcular skip inicial: {e}")
                else:
                    start_date = self.get_last_date(conn, "Operaciones_Inventario", "fecha_actualizacion")
                    params_base["fechaInicial"] = start_date.strftime("%Y-%m-%d %H:%M:%S")
                    logging.info(f"   [Smart Sync] Inventario: Buscando cambios desde {start_date}")

                limit = 50
                empty_pages = 0

                while True:
                    if (time.time() - start_time) > MAX_EXECUTION_TIME:
                        logging.warning("   [TIMEOUT PREVENTIVO] Se alcanzó el límite de 24 minutos en Inventario.")
                        return total_processed

                    params = params_base.copy()
                    params["skip"] = skip

                    success_batch = False
                    items = []
                    for retry in range(3):
                        try:
                            resp = self.session.get(f"{self.base_url}/inventory", headers=headers, params=params, timeout=(15, 90))
                            logging.info(f"   -> [REQ] skip: {skip} | URL: {resp.url}")

                            if resp.status_code == 204:
                                # Salida inmediata
                                logging.info(f"   -> [RES] Status: 204 | Count: 0")
                                return total_processed

                            items = self._safe_parse_json(resp, "inventory")
                            logging.info(f"   -> [RES] Status: {resp.status_code} | Count: {len(items)}")

                            # Lógica de detección de huecos
                            if not items:
                                empty_pages += 1
                                if empty_pages <= 10:
                                    logging.warning(f"⚠️ Hueco detectado ({empty_pages}/10). Saltando...")
                                    skip += limit
                                    time.sleep(0.05)
                                    success_batch = True
                                    break # Salir del retry, continuar loop outer con siguiente skip
                                else:
                                    return total_processed

                            success_batch = True
                            break
                        except Exception as e:
                            logging.warning(f"   [!] Reintento {retry+1} en inventario (Skip {skip}): {e}")
                            time.sleep(5)

                    if not success_batch:
                        logging.error(f"Fallo definitivo en inventario lote {skip}.")
                        break
                    
                    if items:
                        empty_pages = 0
                        self._process_and_save(conn, items, "Operaciones_Inventario", ["id_producto", "id_sucursal"], self.MAP_INVENTARIO)
                        total_processed += len(items)
                        
                    if not items or len(items) < limit:
                        break
                    
                    skip += limit
                    time.sleep(0.05)
                return total_processed

        def sync_collections(self):
            """Sincroniza cobros con estrategia Dual (Historical/Incremental)."""
            if not self.token: self.get_token()
            headers = {"Authorization": f"Bearer {self.token}", "accept": "application/json"}

            start_time = time.time()
            MAX_EXECUTION_TIME = 24 * 60
            total_processed = 0
            total_amount = 0.0

            skip = 0
            limit = 50
            params_base = {}

            # --- FASE 1: DETERMINAR ESTADO INICIAL (Conexión efímera) ---
            try:
                with pyodbc.connect(self.conn_str) as conn:
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
            except Exception as e:
                logging.error(f"Error de conexión inicial en Cobros: {e}")

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
                            with pyodbc.connect(self.conn_str) as conn:
                                logging.info(f"   [DB] Guardando lote cobros {skip} ({len(items)} items)...")
                                self._process_and_save(conn, items, "Finanzas_Cobros", "id_cobro", self.MAP_COBROS)
                            saved = True
                            break
                        except Exception as e:
                            logging.warning(f"   [DB Retry {db_retry+1}] Error guardando cobros: {e}")
                            time.sleep(5)
                    
                    if not saved:
                        raise Exception("Fallo definitivo guardando cobros en BD.")

                    total_processed += len(items)
                
                if not items or len(items) < limit:
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
                    # Modo Incremental: Ventana de seguridad de 2 días
                    try:
                        last_date = self.get_last_date(conn, "Operaciones_Ordenes_Cristales", "fecha_creacion")
                        start_date = last_date - datetime.timedelta(days=2)
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
                    # Patrón Incremental por defecto
                    try:
                        last_date = self.get_last_date(conn, "Operaciones_Recepciones_Lab", "fecha_recepcion")
                        start_date = last_date - datetime.timedelta(days=2)
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
                            
                            items = self._safe_parse_json(resp, "receivedDeliveryNotes")
                            logging.info(f"   -> [RES] Status: {resp.status_code} | Count: {len(items)}")
                            success_batch = True
                            break
                        except Exception as e:
                            wait = (retry + 1) * 5
                            logging.warning(f"   [!] Reintento {retry+1} en Recepciones Lab (Skip {skip}): {e}")
                            time.sleep(wait)

                    if not success_batch:
                        logging.error(f"Fallo definitivo en Recepciones Lab lote {skip}.")
                        break

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

        def sync_zoho_expenses(self):
            """
            Sincroniza los gastos desde Zoho Books de forma incremental o histórica,
            manejando paginación y grandes volúmenes de datos de forma robusta.
            """
            if not self.zoho_access_token or not self.zoho_org_id:
                logging.warning("   [Zoho Gastos] Token de acceso u Org ID de Zoho no disponibles. Saltando módulo.")
                return 0
            
            total_processed = 0
            buffer = []
            BUFFER_SIZE = 200  # Batching: Optimizado a 200 para reducir latencia y evitar timeouts en ODBC
            
            with pyodbc.connect(self.conn_str) as conn:
                # Lógica de Fecha (Incremental vs Histórica)
                date_start_param = '2025-01-01'  # Default para carga histórica
                cutoff_date = datetime.datetime(2025, 1, 1)

                if self.LOAD_MODE_ZOHO_GASTOS == 'INCREMENTAL':
                    try:
                        last_date_dt = self.get_last_date(conn, "Zoho_Gastos", "fecha_gasto")

                        # Regla de negocio: La fecha de inicio nunca debe ser anterior a 2025.
                        if last_date_dt < cutoff_date:
                            logging.info(f"   [Zoho Gastos] MAX de SQL es anterior a 2025. Forzando inicio a {cutoff_date.strftime('%Y-%m-%d')}")
                            last_date_dt = cutoff_date

                        date_start_param = last_date_dt.strftime('%Y-%m-%d')
                        logging.info(f"   [Zoho Gastos] Modo INCREMENTAL. Buscando desde: {date_start_param}")
                    except pyodbc.ProgrammingError:
                        logging.warning(f"   [Zoho Gastos] Tabla Zoho_Gastos no existe. Usando fecha base: {date_start_param}")
                else:  # HISTORICAL
                    logging.info(f"   [Zoho Gastos] Modo HISTORICAL. Iniciando carga desde: {date_start_param}")

                # Configuración de Parámetros
                headers = {"Authorization": f"Zoho-oauthtoken {self.zoho_access_token}"}
                base_url = "https://www.zohoapis.com/books/v3/expenses"
                base_params = {
                    'organization_id': self.zoho_org_id,
                    'per_page': 200,
                    'date_start': date_start_param,
                    'sort_column': 'date',
                    'sort_order': 'A'
                }

                page = 1
                while True:
                    params = base_params.copy()
                    params['page'] = page
                    
                    try:
                        resp = self.session.get(base_url, headers=headers, params=params, timeout=(15, 90))
                    except Exception as e:
                         logging.error(f"   [Zoho Gastos] Error de conexión en pág {page}: {e}")
                         break

                    # Manejo de Errores: Log detallado y raise si la API falla
                    if resp.status_code != 200:
                        logging.error(f"   [Zoho Gastos] Error API {resp.status_code}: {resp.text}")
                        # No raise, break para intentar salvar lo que haya
                        break
                    
                    data = resp.json()
                    expenses = data.get('expenses', [])
                    
                    if not expenses:
                        logging.info(f"   [Zoho Gastos] No se encontraron más gastos en la página {page}.")
                        break
                        
                    logging.info(f"   [Zoho Gastos] Procesando página {page}, {len(expenses)} gastos encontrados.")
                    
                    # --- PROCESAMIENTO ROBUSTO Y LIMPIEZA ---
                    clean_batch = []
                    for exp in expenses:
                        # Extracción segura del monto (Priorizando bcy_total por solicitud)
                        raw_amount = exp.get('bcy_total') or exp.get('total') or exp.get('amount') or 0
                        
                        # Limpieza de tipos para evitar errores de pyodbc
                        clean_obj = {
                            'expense_id': str(exp.get('expense_id', '')),
                            'date': str(exp.get('date', '')),
                            'amount': float(raw_amount),
                            'vendor_name': str(exp.get('vendor_name', '') or ''),
                            'account_name': str(exp.get('account_name', '') or ''),
                            'status': str(exp.get('status', '')),
                            'description': str(exp.get('description', '') or ''),
                            'last_modified_time': str(exp.get('last_modified_time', ''))
                        }
                        clean_batch.append(clean_obj)

                    buffer.extend(clean_batch)
                    
                    # Manejo de Datos y Memoria (Batching Optimizado)
                    if len(buffer) >= BUFFER_SIZE:
                        logging.info(f"   [Zoho Gastos] Buffer lleno ({len(buffer)}). Guardando en BD...")
                        logging.info(f"   [Zoho Debug] Ejemplo de gasto a guardar: {buffer[0]}")
                        
                        self._process_and_save(conn, buffer, "Zoho_Gastos", "id_gasto_zoho", self.MAP_ZOHO_GASTOS)
                        total_processed += len(buffer)
                        buffer = []

                    # Paginación Robusta: Maneja page_context como dict o list
                    has_more = data.get('page_context', {}).get('has_more_page') if isinstance(data.get('page_context'), dict) else data.get('page_context', [{}])[0].get('has_more_page', False)

                    if not has_more:
                        break
                        
                    page += 1
                    time.sleep(0.5)  # API rate limiting

                # Guardar el buffer residual
                if buffer:
                    logging.info(f"   [Zoho Gastos] Guardando buffer residual de {len(buffer)} registros.")
                    logging.info(f"   [Zoho Debug] Ejemplo de gasto residual: {buffer[0]}")
                    self._process_and_save(conn, buffer, "Zoho_Gastos", "id_gasto_zoho", self.MAP_ZOHO_GASTOS)
                    total_processed += len(buffer)
                        
            return total_processed

        def _refresh_ghl_token(self):
            """Refresca el token de GoHighLevel usando la tabla Etl_GHL_Auth."""
            logging.info("--- [INICIO] MÓDULO: GHL_AUTH ---")
            self.notificar_telegram("🔑 GHL: Iniciando validación y renovación de tokens...")

            if self.ghl_access_token:
                return

            logging.info("   [GHL Auth] Iniciando refresco de token...")
            try:
                with pyodbc.connect(self.conn_str) as conn:
                    cursor = conn.cursor()
                    cursor.execute("SELECT client_id, client_secret, refresh_token, location_id FROM Etl_GHL_Auth WHERE app_name = 'Optilux_ETL'")
                    row = cursor.fetchone()
                    if not row:
                        raise Exception("No se encontraron credenciales GHL en Etl_GHL_Auth")
                    
                    client_id, client_secret, refresh_token, location_id = row.client_id, row.client_secret, row.refresh_token, row.location_id
                    self.ghl_location_id = location_id

                    url = f"{self.ghl_base_url}/oauth/token"
                    payload = {
                        'client_id': client_id,
                        'client_secret': client_secret,
                        'grant_type': 'refresh_token',
                        'refresh_token': refresh_token
                    }
                    headers = {'Content-Type': 'application/x-www-form-urlencoded'}
                    
                    resp = self.session.post(url, data=payload, headers=headers, timeout=(15, 90))
                    if resp.status_code != 200:
                        raise Exception(f"Error GHL Token API: {resp.text}")
                    
                    data = resp.json()
                    new_access = data.get('access_token')
                    new_refresh = data.get('refresh_token')
                    
                    if not new_access or not new_refresh:
                        raise Exception("Respuesta GHL inválida (faltan tokens)")

                    cursor.execute("""
                        UPDATE Etl_GHL_Auth 
                        SET access_token = ?, refresh_token = ?, last_update = GETDATE() 
                        WHERE app_name = 'Optilux_ETL'
                    """, new_access, new_refresh)
                    conn.commit() # Commit inmediato para persistencia atómica
                    
                    self.ghl_access_token = new_access
                    logging.info("✅ GHL_AUTH: Tokens persistidos correctamente en SQL.")

            except Exception as e:
                self.notificar_telegram("❌ ERROR CRÍTICO GHL: Token de refresco inválido o expirado. Se requiere intervención manual.")
                logging.error(f"   [GHL Auth] Error crítico: {e}")
                raise

        def sync_ghl_calendars(self):
            """Sincroniza calendarios de GHL."""
            if not self.ghl_access_token: self._refresh_ghl_token()
            headers = {"Authorization": f"Bearer {self.ghl_access_token}", "Version": "2021-07-28", "Accept": "application/json"}
            
            url = f"{self.ghl_base_url}/calendars/"
            params = {'locationId': self.ghl_location_id}
            
            try:
                resp = self.session.get(url, headers=headers, params=params, timeout=(15, 90))
                if resp.status_code == 200:
                    data = resp.json()
                    items = data.get('calendars', [])
                    if items:
                        with pyodbc.connect(self.conn_str) as conn:
                            self._process_and_save(conn, items, "GHL_Calendarios", "id_calendario", self.MAP_GHL_CALENDARS)
                        return len(items)
                else:
                    logging.warning(f"   [GHL Calendars] Error {resp.status_code}: {resp.text}")
            except Exception as e:
                logging.error(f"   [GHL Calendars] Excepción: {e}")
            return 0

        def _map_ghl_custom_fields(self, contact_item):
            """Helper para aplanar Custom Fields por ID (Re-Ingeniería ETL)."""
            cfs = contact_item.get('customFields', [])
            mapped = {}
            # Mapa de IDs estricto
            field_map = {
                'zfo5is9ScCBVJR7kuZUV': 'genero',
                'g5wELa7M1kQVksTjL6Xl': 'profesion',
                'VFm0aOTrAWbmUYNKAnuT': 'sucursal_nombre',
                'MGIZC3QsJ0wG1hKuHVP2': 'doctor_asignado',
                'VaXKU8PDTnN9Mb5LPPGL': 'estatus_paciente'
            }
            
            for cf in cfs:
                fid = cf.get('id')
                if fid in field_map:
                    val = cf.get('value')
                    # Unir listas (checkboxes)
                    if isinstance(val, list):
                        val = ", ".join([str(v) for v in val])
                    mapped[field_map[fid]] = val
            return mapped

        def sync_ghl_contacts(self, start_global=None, max_duration_mins=24):
            """Sincroniza contactos de GHL (Adjusted: Incremental Stop on First Exists)."""
            if not self.ghl_access_token: self._refresh_ghl_token()
            headers = {"Authorization": f"Bearer {self.ghl_access_token}", "Version": "2021-07-28", "Accept": "application/json"}
            
            total_processed = 0
            
            # --- LEER CHECKPOINTS ---
            start_after = self._get_checkpoint_ghl('GHL_Contacts_NextAfter')
            start_after_id = self._get_checkpoint_ghl('GHL_Contacts_NextAfterId')
            
            # Tratamiento de '0' como None y Blindaje
            if start_after in ['0', 0, 'None', None, ''] : start_after = None
            if start_after_id in ['0', 0, 'None', None, '']: start_after_id = None
            
            if start_after: 
                start_after = int(start_after) if str(start_after).isdigit() else None
            
            # --- AUTO-HEALING HIGH-WATER MARK (Escudo de Auto-Recuperación) ---
            # Si no hay checkpoint y estamos en modo incremental, intentamos recuperar la última fecha de la BD.
            if not start_after and (self.LOAD_MODE_GHL_CONTACTS == 'INCREMENTAL'):
                try:
                    with pyodbc.connect(self.conn_str) as conn:
                        with conn.cursor() as cursor:
                            # SELECT TOP 1 fecha_creacion_ghl FROM GHL_Contactos ORDER BY fecha_creacion_ghl DESC
                            cursor.execute("SELECT TOP 1 fecha_creacion_ghl FROM GHL_Contactos ORDER BY fecha_creacion_ghl DESC")
                            row = cursor.fetchone()
                            if row and row[0]:
                                last_date = row[0]
                                # Convertir datetime a timestamp ms
                                if isinstance(last_date, str):
                                    last_date = pd.to_datetime(last_date).to_pydatetime()
                                start_after = int(last_date.timestamp() * 1000)
                                logging.info(f"   [Auto-Healing] Checkpoint recuperado de BD: {last_date} -> {start_after}")
                except Exception as e:
                    logging.warning(f"   [Auto-Healing] Fallo al recuperar High-Water Mark: {e}")

            # --- LOGICA INCREMENTAL ---
            # Si hay checkpoints guardados, asumimos modo RESUME o HISTORICAL en curso.
            # Si NO hay checkpoints (start_after es None) y estamos en modo INCREMENTAL, activamos 'Stop on Exists'.
            is_incremental_mode = (self.LOAD_MODE_GHL_CONTACTS == 'INCREMENTAL')
            
            with pyodbc.connect(self.conn_str) as conn:
                logging.info(f"   [GHL Contacts] Inicio (Resume: {start_after}, Incr: {is_incremental_mode})...")
                
                while True:
                    # 1. Safety Timer Check
                    if start_global and (time.time() - start_global) / 60 > max_duration_mins:
                        logging.warning(f"   [GHL Contacts] 🛑 TIEMPO EXCEDIDO. Guardando estado.")
                        break

                    url = f"{self.ghl_base_url}/contacts/"
                    params = {'locationId': self.ghl_location_id, 'limit': 100}
                    if start_after: params['startAfter'] = start_after
                    if start_after_id: params['startAfterId'] = start_after_id
                    
                    try:
                        resp = self.session.get(url, headers=headers, params=params, timeout=(15, 90))
                        if resp.status_code != 200:
                            logging.error(f"   [GHL Contacts] Error {resp.status_code}: {resp.text}")
                            break
                            
                        data = resp.json()
                        items = data.get('contacts', [])
                        
                        if not items: 
                            # Si termina la lista, limpiamos checkpoints
                            logging.info("   [GHL Contacts] Fin de lista. Limpiando checkpoints.")
                            self._update_checkpoint_ghl('GHL_Contacts_NextAfter', '')
                            self._update_checkpoint_ghl('GHL_Contacts_NextAfterId', '')
                            break

                        # 2. Incremental Stop Logic (Critical Optimization)
                        # Si estamos en modo incremental y el PRIMER item del lote ya existe,
                        # asumimos que todo lo anterior ya fue cargado (GHL ordena por updated/created desc por defecto? 
                        # OJO: GHL contacts default sort id dateAdded desc. 
                        # Si bajamos desde el más reciente (sin startAfter?), el cursor va hacia atrás? No, cursor va forward.
                        # GHL v2 con searchAfter va en orden de creación/id ascendente usualmente.
                        # Si el objetivo es 'solo lo nuevo', el cursor debe persistir.
                        # PERO si se quiere 'parar si ya existe', implica que estamos escaneando y encontramos algo viejo.
                        # Si GHL entrega Ascendente (Oldest first), 'Stop on exits' funciona si barremos desde el final?
                        # ACTUALLY: El prompt pide: "si el primer registro del lote ya existe... haz un break".
                        # Esto asume que estamos recibiendo registros que PODRIAN ya estar.
                        if is_incremental_mode and items:
                            first_id = items[0].get('id')
                            if first_id:
                                with conn.cursor() as cursor:
                                    cursor.execute("SELECT COUNT(1) FROM GHL_Contactos WHERE id_contacto_ghl = ?", first_id)
                                    if cursor.fetchone()[0] > 0:
                                        logging.info(f"   [GHL Contacts] 🛑 Registro {first_id} ya existe. Deteniendo incremental.")
                                        break

                        # --- ENRIQUECIMIENTO ---
                        for item in items:
                            # Agrega esta línea para capturar el ID de la sucursal
                            item['locationId'] = self.ghl_location_id  

                            # --- NORMALIZACIÓN DE TELÉFONOS Y CORREOS (Regla 2) ---
                            raw_phone = item.get('phone')
                            if raw_phone and isinstance(raw_phone, str):
                                item['phone'] = raw_phone.replace('+507', '').replace(' ', '').replace('-', '')
                            
                            raw_email = item.get('email')
                            if raw_email and isinstance(raw_email, str):
                                item['email'] = raw_email.strip().lower()
                            
                            # --- ESTÉTICA DE NOMBRES (Regla 3) ---
                            raw_fn = item.get('firstName')
                            if raw_fn and isinstance(raw_fn, str):
                                item['firstName'] = raw_fn.strip().upper()
                            
                            raw_ln = item.get('lastName')
                            if raw_ln and isinstance(raw_ln, str):
                                item['lastName'] = raw_ln.strip().upper()

                            # Flattening Root
                            # Fields: city, state, country, type, dateOfBirth, dateUpdated are usually at root or location level
                            # Verifica si vienen en root
                            # ... (Standard mapping takes care if keys match MAP dict)
                            
                            # Flattening Attribution
                            attrs = item.get('attributions', [])
                            if attrs and isinstance(attrs, list):
                                first = next((a for a in attrs if a.get('isFirst') is True), None)
                                if first:
                                    item['utm_source'] = first.get('utmSessionSource')
                                    item['utm_medium'] = first.get('medium')
                            
                            # Flattening Tags
                            tags = item.get('tags', [])
                            if tags and isinstance(tags, list):
                                item['tags_concatenados'] = ", ".join([str(t) for t in tags])
                            else:
                                item['tags_concatenados'] = None
                            
                            # Flattening Custom Fields
                            cf_data = self._map_ghl_custom_fields(item)
                            item.update(cf_data)
                            
                            # Clean Nulls
                            for k, v in item.items():
                                if v == "" or v is None: item[k] = None
                        
                        self._process_and_save(conn, items, "GHL_Contactos", "id_contacto_ghl", self.MAP_GHL_CONTACTS)
                        total_processed += len(items)
                        
                        # --- CURSORS ---
                        meta = data.get('meta', {})
                        next_start_after = meta.get('startAfter')
                        next_start_after_id = meta.get('startAfterId')
                        
                        if next_start_after and next_start_after_id:
                            self._update_checkpoint_ghl('GHL_Contacts_NextAfter', str(next_start_after))
                            self._update_checkpoint_ghl('GHL_Contacts_NextAfterId', next_start_after_id)
                        
                        logging.info(f"   -> [GHL Contacts] Lote +{len(items)}. Checkpoint guardado.")
                        
                        if not next_start_after or not next_start_after_id or len(items) < 100:
                            break
                        
                        start_after = next_start_after
                        start_after_id = next_start_after_id
                        time.sleep(0.1)
                    except Exception as e:
                        logging.error(f"   [GHL Contacts] Excepción: {e}")
                        break
            return total_processed

        def sync_ghl_opportunities(self, start_global=None, max_mins=24):
            """Sincroniza oportunidades con lógica de checkpoints e incremental."""
            if not self.ghl_access_token: self._refresh_ghl_token()
            headers = {"Authorization": f"Bearer {self.ghl_access_token}", "Version": "2021-07-28", "Accept": "application/json"}
            
            start_after = self._get_checkpoint_ghl('GHL_Opps_NextAfter')
            logging.info(f"   [GHL Opps] Checkpoint inicial: '{start_after}'") # LOG INYECTADO
            if start_after in ['0', 0, 'None', None, '']: start_after = None
            
            total_processed = 0
            with pyodbc.connect(self.conn_str) as conn:
                while True:
                    # Check de tiempo (Azure 24 min)
                    if start_global and (time.time() - start_global) / 60 > max_mins:
                        logging.warning("⚠️ [GHL Opps] Tiempo límite alcanzado. Guardando estado.")
                        break

                    url = f"{self.ghl_base_url}/opportunities/search"
                    params = {'location_id': self.ghl_location_id, 'limit': 100}
                    if start_after: params['startAfter'] = start_after
                    
                    logging.info(f"   [GHL Opps] Solicitando API con params: {params}") # LOG INYECTADO

                    resp = self.session.get(url, headers=headers, params=params, timeout=60)
                    if resp.status_code != 200: 
                        logging.error(f"   [GHL Opps] Error API Status: {resp.status_code}") # LOG ERROR
                        break
                    
                    data = resp.json()
                    items = data.get('opportunities', [])
                    logging.info(f"   [GHL Opps] Respuesta API: {resp.status_code} - Registros: {len(items)}") # LOG INYECTADO

                    if not items: break

                    # Lógica Stop on Exists
                    if self.LOAD_MODE_GHL_OPPORTUNITIES == 'INCREMENTAL' and not start_after:
                        with conn.cursor() as cursor:
                            cursor.execute("SELECT COUNT(1) FROM GHL_Oportunidades WHERE id_oportunidad_ghl = ?", items[0].get('id'))
                            if cursor.fetchone()[0] > 0:
                                logging.info("✅ Oportunidades al día.")
                                break

                    # Transformar fechas ISO
                    for item in items:
                        for f in ['createdAt', 'updatedAt', 'lastStatusChangeAt', 'lastStageChangeAt']:
                            if item.get(f) and pd.notnull(item[f]):
                                try:
                                    item[f] = pd.to_datetime(item[f], errors='coerce').strftime('%Y-%m-%d %H:%M:%S')
                                except: item[f] = None

                    logging.info("   [GHL Opps] Iniciando MERGE en SQL...") # LOG INYECTADO
                    try: # TRY-EXCEPT ESPECIFICO
                        self._process_and_save(conn, items, "GHL_Oportunidades", "id_oportunidad_ghl", self.MAP_GHL_OPPORTUNITIES)
                        logging.info("   [GHL Opps] MERGE completado.") # LOG INYECTADO
                    except Exception as e:
                        logging.error(f"❌ ERROR DE SQL EN GHL_OPPORTUNITIES: {e}")
                        break

                    total_processed += len(items)
                    
                    # Logica de Loop Infinito Fix - VALIDACION ESTRICTA
                    new_start_after = data.get('meta', {}).get('startAfter')
                    
                    if not new_start_after:
                        self._update_checkpoint_ghl('GHL_Opps_NextAfter', '')
                        logging.info("   [GHL Opps] Fin del ciclo (cursor vacío).")
                        break
                    
                    # SI EL CURSOR ES IGUAL AL ANTERIOR, ROMPER
                    if str(new_start_after) == str(start_after):
                         logging.warning(f"   [GHL Opps] Cursor repetido {new_start_after}. Rompiendo bucle infinito.")
                         break

                    start_after = str(new_start_after)
                    self._update_checkpoint_ghl('GHL_Opps_NextAfter', start_after)
            return total_processed

        def sync_ghl_appointments(self, start_global=None, max_mins=24):
            """Sincroniza citas iterando sucursal por sucursal (Versión Optimizada + Incremental por Calendario)."""
            if not self.ghl_access_token: self._refresh_ghl_token()
            headers = {"Authorization": f"Bearer {self.ghl_access_token}", "Version": "2021-07-28", "Accept": "application/json"}
            
            total = 0
            end_ms = int((datetime.datetime.now() + datetime.timedelta(days=90)).timestamp() * 1000)

            with pyodbc.connect(self.conn_str) as conn:
                cursor = conn.cursor()
                cursor.execute("SELECT id_calendario, nombre_calendario FROM GHL_Calendarios")
                calendars = cursor.fetchall()
                logging.info(f"   [GHL Citas] Calendarios encontrados: {len(calendars)}")
                
                for cal_id, cal_name in calendars:
                    if start_global and (time.time() - start_global) / 60 > max_mins:
                        logging.warning(f"⚠️ [GHL Citas] Tiempo límite alcanzado antes de procesar {cal_name}")
                        break

                    # --- LÓGICA INCREMENTAL POR SUCRSAl (High Water Mark Granular) ---
                    start_dt = datetime.datetime(2025, 1, 1) # Default
                    try:
                        if self.LOAD_MODE_GHL_CITAS == 'INCREMENTAL':
                            cursor.execute("SELECT MAX(fecha_creacion) FROM GHL_Citas WHERE id_calendario = ?", cal_id)
                            row = cursor.fetchone()
                            last_date = row[0] if row else None
                            
                            if last_date and isinstance(last_date, datetime.datetime) and last_date > start_dt:
                                start_dt = last_date - datetime.timedelta(hours=2) # Safety Margin 2h
                                logging.info(f"   [GHL Citas] {cal_name}: Buscando desde {start_dt}")
                            else:
                                logging.info(f"   [GHL Citas] {cal_name}: Carga completa/inicial (2025).")
                    except Exception as e:
                        logging.warning(f"   [GHL Citas] ⚠️ Error calculando fecha incremental para {cal_name}: {e}")

                    start_ms = int(start_dt.timestamp() * 1000)
                    
                    logging.info(f"   [GHL Citas] --> Procesando sucursal: {cal_name}")
                    url = f"{self.ghl_base_url}/calendars/events"
                    params = {'locationId': self.ghl_location_id, 'calendarId': cal_id, 'startTime': start_ms, 'endTime': end_ms}
                    
                    try:
                        resp = self.session.get(url, headers=headers, params=params, timeout=60)
                        if resp.status_code == 200:
                            events = resp.json().get('events', [])
                            logging.info(f"   [GHL Citas] API respondió con {len(events)} eventos.")
                            
                            if events:
                                for ev in events:
                                    for f in ['startTime', 'endTime', 'dateAdded']:
                                        if ev.get(f) and pd.notnull(ev[f]):
                                            try:
                                                ev[f] = pd.to_datetime(ev[f], errors='coerce').strftime('%Y-%m-%d %H:%M:%S')
                                            except: ev[f] = None
                                
                                logging.info(f"   [GHL Citas] Iniciando MERGE en SQL para {cal_name}...")
                                t_start_sql = time.time()
                                self._process_and_save(conn, events, "GHL_Citas", "id_cita_ghl", self.MAP_GHL_CITAS)
                                logging.info(f"   [GHL Citas] MERGE completado en {time.time() - t_start_sql:.2f} segundos")
                                total += len(events)
                        else:
                            logging.error(f"   [GHL Citas] Error API en {cal_name}: {resp.status_code}")
                    except Exception as e:
                        logging.error(f"Error procesando calendario {cal_name}: {e}")
            return total
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
            finally:
                cursor.close()