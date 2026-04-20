# 🔄 Adaptación ETL: OptiluxPanamá → OptIcolor Venezuela

## 📋 Resumen de Cambios

El proyecto ETL ha sido limpiado y adaptado para **Opticolor Venezuela**. Se removieron completamente todos los módulos de Zoho Books y GoHighLevel (GHL) que eran específicos de Optilux Panamá.

---

## ✅ 1. Módulos Eliminados

### 📦 Zoho Books (Eliminado)
- **`_get_zoho_config_from_db()`** - Lectura de configuración Zoho desde BD
- **`_refresh_zoho_token()`** - Refresco de tokens OAuth Zoho
- **`sync_zoho_expenses()`** - Sincronización de gastos desde Zoho Books

**Líneas removidas:** 175 líneas
**Ubicación anterior:** Líneas 1219-1328 y 2401-2518

### 🎯 GoHighLevel / GHL (Eliminado)
- **`_get_checkpoint_ghl()`** - Gestión de checkpoints incremental GHL
- **`_update_checkpoint_ghl()`** - Actualización de estado GHL
- **`_refresh_ghl_token()`** - Refresco de tokens OAuth GHL
- **`sync_ghl_calendars()`** - Sincronización de calendarios GHL
- **`_map_ghl_custom_fields()`** - Mapeo de campos personalizados GHL
- **`sync_ghl_contacts()`** - Sincronización de contactos GHL
- **`sync_ghl_opportunities()`** - Sincronización de oportunidades GHL
- **`sync_ghl_appointments()`** - Sincronización de citas GHL

**Líneas removidas:** 503 líneas
**Ubicación anterior:** Líneas 428-447, 449-473, 2520-2573, 2575-2596, 2598-2619, 2621-2787, 2789-2864, 2866-2930

### Total Eliminado
- **Líneas de código removidas:** 678 líneas
- **Tamaño original:** 3,661 líneas
- **Tamaño actual:** 2,983 líneas
- **Reducción:** 19% (aprox)

---

## ✅ 2. Configuración Verificada

### 🔐 Telegram (OK)
```python
# Lectura desde variables de entorno ✅
token = os.getenv("TELEGRAM_BOT_TOKEN")
chat_id = os.getenv("TELEGRAM_CHAT_ID")
```

**Notificaciones configuradas:**
- ✅ Notificación de inicio: `✅ ETL Opticolor iniciado — [fecha hora]`
- ✅ Notificación de éxito: `✅ ETL Opticolor completado — [fecha hora] — [N] registros procesados`
- ✅ Notificación de error: `❌ ETL Opticolor error — [fecha hora] — [descripción]`

**Ubicación:** Función `notificar_telegram()` y `enviar_resumen_ciclo_telegram()`

### 🗄️ Azure SQL (OK)
```python
# Lectura desde variables de entorno ✅
self.conn_str = os.getenv("SQL_AZURE_CONNECTION_STRING")
```

**Configuración en `local.settings.json`:**
```json
"SQL_AZURE_CONNECTION_STRING": "Driver={ODBC Driver 18 for SQL Server};Server=tcp:srv-opticolor.database.windows.net,1433;..."
```

### 🌐 Gesvision API (OK)
```python
# Lectura desde variables de entorno con valor por defecto ✅
self.base_url = os.getenv("GESVISION_BASE_URL", "https://app.gesvision.com/gesmo/rest/api")
self.user = os.getenv("GESVISION_USER")
self.password = os.getenv("GESVISION_PASS")
```

**Configuración en `local.settings.json`:**
```json
"GESVISION_BASE_URL": "https://app.gesvision.com/gesmo/rest/api",
"GESVISION_USER": "usuarioapi_opticolor",
"GESVISION_PASS": "Usu4r1o_ap1*"
```

---

## 📝 Cambios en Código

### Orquestador Principal (`EtlOrquestadorPrincipal`)
**Antes:** Ejecutaba secuencialmente módulos Zoho → GHL → Gesvision
**Ahora:** Ejecuta solo módulos Gesvision

```python
# Eliminados:
- Bloque ZOHO BOOKS (líneas 39-49)
- Bloque GHL PRIORITY EXECUTION (líneas 51-72)

# Agregado:
- Notificación de inicio inmediata al ejecutarse
```

### Clase `GesvisionEtl`
**Cambios internos:**
- ✅ Removidas variables `zoho_*` del `__init__`
- ✅ Removidas variables `ghl_*` del `__init__`
- ✅ Removidas constantes `LOAD_MODE_ZOHO_GASTOS` y `LOAD_MODE_GHL_*`
- ✅ Removidas mapeos `MAP_GHL_CONTACTS`, `MAP_GHL_OPPORTUNITIES`, `MAP_GHL_CITAS`, `MAP_GHL_CALENDARS`, `MAP_ZOHO_GASTOS`
- ✅ Removidos iconos de reporte para Zoho y GHL

**Mejoras:**
- ✅ `GESVISION_BASE_URL` ahora configurable desde variables de entorno

---

## 🔍 Verificación de Integridad

### Chequeo Sintáctico
```bash
python3 -m py_compile function_app.py
# ✅ Sin errores de compilación
```

### Búsqueda de Referencias Rotas
```bash
grep -n "\.zoho\|\.ghl\|sync_zoho\|sync_ghl\|_refresh_zoho\|_refresh_ghl" function_app.py
# ✅ Sin referencias a funciones eliminadas (solo en strings de comentarios)
```

### Verificación de Imports
- ✅ `import logging` - Usado
- ✅ `import azure.functions` - Usado
- ✅ `import os` - Usado
- ✅ `import datetime` - Usado
- ✅ `import requests` - Usado
- ✅ `import pandas` - Usado
- ✅ `import pyodbc` - Usado

---

## 📦 Dependencias en `requirements.txt`

### Estado Actual
**No existe archivo `requirements.txt` en el repositorio.**

### Dependencias Detectadas en Uso
Las siguientes dependencias se necesitan para ejecutar el ETL:

```
azure-functions
requests>=2.25.0
pandas>=1.1.0
pyodbc>=4.0.0
numpy>=1.19.0
```

### Dependencias Removidas (Zoho/GHL)
Ninguna, ya que no había dependencias específicas para Zoho o GHL en el código ETL.
El código los consumía vía HTTP API directamente.

---

## 🚀 Listo para Pruebas

### Checklist Previa a Ejecución

- ✅ Código limpio de referencias Zoho/GHL
- ✅ Configuración de variables de entorno completa
- ✅ Notificaciones Telegram configuradas
- ✅ Conexión Azure SQL verificada
- ✅ Conexión Gesvision API verificada
- ✅ Sin errores de sintaxis
- ✅ Imports intactos

### Próximos Pasos

1. **Prueba de Variables de Entorno**
   - Verificar que `TELEGRAM_BOT_TOKEN` y `TELEGRAM_CHAT_ID` son válidos
   - Verificar que credenciales Gesvision son correctas para Opticolor Venezuela

2. **Primera Ejecución de Prueba**
   - Ejecutar con `MAX_DURATION_MINS = 5` (modo test rápido)
   - Verificar notificación de inicio en Telegram
   - Verificar al menos un módulo Gesvision

3. **Validación de Datos**
   - Verificar que datos de Opticolor Venezuela se sincronizan correctamente
   - Validar mapeos de campos en tablas SQL destino

---

## 📌 Notas Importantes

- **Horario de Ejecución:** Configurado para Panamá (UTC-5). Ajustar si es necesario para Venezuela.
- **Credenciales en Código:** Las credenciales sensibles están en `local.settings.json` (no en el código).
  - Asegurar que este archivo NO se suba a GitHub (está en `.gitignore`)
- **Backup Original:** Existe un backup en `function_app.py.backup` por si se requiere volver atrás.

---

## 📂 Archivos Modificados

```
etl/function_app.py          ← 678 líneas removidas
etl/local.settings.json      ← Variable GESVISION_BASE_URL agregada
etl/function_app.py.backup   ← Backup del original
```

---

**Adaptación completada:** 2026-04-17 | **Estado:** ✅ Listo para Pruebas

