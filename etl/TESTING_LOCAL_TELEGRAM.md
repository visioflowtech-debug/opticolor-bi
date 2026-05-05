# 🧪 Testing Local: Telegram ETL Opticolor

## Opción 1: Script Python Directo (Sin Azure Functions)

### 📋 Requisitos
- Python 3.8+
- Variables de entorno configuradas

### 🚀 Ejecución

```bash
# 1. Navegar al directorio
cd c:\opticolor-bi\etl

# 2. Configurar variables de entorno (PowerShell)
$env:TELEGRAM_BOT_TOKEN = "tu_token_aqui"
$env:TELEGRAM_CHAT_ID = "tu_chat_id_aqui"

# 3. Ejecutar script de testing
python test_telegram.py
```

**Salida esperada:**
```
✅ Credenciales Telegram configuradas

Enviando 3 mensajes de prueba...

  [1/3] Enviando: 🧪 TEST 1: Mensaje simple — 2026-05-05 14:30:00...
      ✅ OK
  [2/3] Enviando: ✅ TEST 2: ETL Opticolor iniciado — 2026-05-05 14:30:05...
      ✅ OK
  [3/3] Enviando: 📊 TEST 3: Módulo PRODUCTOS completado — 143,860 registros — 2026-05-05 14:30:10...
      ✅ OK

======================================================================
Resultados: 3/3 mensajes enviados

✅ TEST EXITOSO — Telegram está configurado correctamente
```

---

## 🎯 OPCIÓN RECOMENDADA: Función HTTP en Azure Functions (Desarrollo Local)

### ⚡ Ejecución Rápida (PowerShell)

**Terminal 1 - Iniciar servidor:**
```powershell
# En c:\opticolor-bi\etl\
.\RUN_TEST_LOCAL.ps1

# O manualmente:
$env:TELEGRAM_BOT_TOKEN = "tu_token"
$env:TELEGRAM_CHAT_ID = "tu_chat_id"
func start
```

**Terminal 2 - Enviar test:**
```powershell
# En c:\opticolor-bi\etl\
.\SEND_TEST_REQUEST.ps1 -Mensaje "Mi mensaje personalizado"

# O simple:
.\SEND_TEST_REQUEST.ps1
```

**Salida esperada en Terminal 1 (consola Azure Functions):**
```
🧪 [TEST TELEGRAM] Iniciando prueba de envío — 2026-05-05 14:30:00
════════════════════════════════════════════════════════════

📝 [PASO 1] Parseando mensaje del request...
   ✅ Mensaje recibido: ✅ Prueba de Telegram — ETL Opticolor funcionando

🔐 [PASO 2] Verificando credenciales de Telegram...
   ✅ TELEGRAM_BOT_TOKEN configurado: 123456...xxxxx
   ✅ TELEGRAM_CHAT_ID configurado: -1001234567890

🤖 [PASO 3] Creando instancia GesvisionEtl...
   ✅ Instancia creada exitosamente

📤 [PASO 4] Enviando mensaje a Telegram...
   ✅ Mensaje enviado correctamente

════════════════════════════════════════════════════════════
✅ [TEST COMPLETADO] 2026-05-05 14:30:00
════════════════════════════════════════════════════════════
```

---

## Opción 2: Función HTTP en Azure Functions (Desarrollo Local)

### 📋 Requisitos
- Azure Functions Core Tools instaladas
- Variables en `local.settings.json`

### 🔧 Configuración local

```bash
# 1. Instalar dependencias
pip install -r requirements.txt

# 2. Configurar local.settings.json
```

Contenido de `local.settings.json`:
```json
{
  "IsEncrypted": false,
  "Values": {
    "AzureWebJobsStorage": "DefaultEndpointsProtocol=https;AccountName=...;AccountKey=...",
    "FUNCTIONS_WORKER_RUNTIME": "python",
    "TELEGRAM_BOT_TOKEN": "tu_token_aqui",
    "TELEGRAM_CHAT_ID": "tu_chat_id_aqui",
    "SQL_SERVER": "tu_servidor.database.windows.net",
    "SQL_DATABASE": "opticolor_bi",
    "SQL_USER": "usuario",
    "SQL_PASSWORD": "contraseña"
  }
}
```

### 🚀 Ejecución

```bash
# 1. Iniciar el runtime local
func start

# 2. En otra terminal, ejecutar el test HTTP
curl -X POST http://localhost:7071/api/test-telegram \
  -H "Content-Type: application/json" \
  -d '{"mensaje": "Test desde desarrollo local"}'
```

**Salida esperada:**
```json
{
  "status": "✅ Mensaje enviado a Telegram: 'Test desde desarrollo local'\n\nAhora sigue procesando..."
}
```

---

## 📊 Logs en Consola

### Dónde Ver los Logs

**En Terminal 1 (Azure Functions):**
```
[timestamp] Information: 🧪 [TEST TELEGRAM] Iniciando prueba de envío — 2026-05-05 14:30:00
[timestamp] Information:    ✅ Mensaje recibido: ✅ Prueba de Telegram...
[timestamp] Information:    Instancia GesvisionEtl creada
[timestamp] Information:    Mensaje enviado a Telegram: ✅ Prueba de Telegram...
[timestamp] Information: ✅ [TEST COMPLETADO] Telegram funcionando correctamente
```

### Qué Significan los Emojis

| Emoji | Significado | Acción |
|-------|-------------|--------|
| 🧪 | Test iniciado | Esperando |
| 📝 | Parseando mensaje | Normal |
| 🔐 | Verificando credenciales | Crítico si falla |
| 🤖 | Creando instancia | Normal |
| 📤 | Enviando a Telegram | Crítico si falla |
| ✅ | Éxito | Todo OK |
| ❌ | Error | Revisar variables |
| ⚠️ | Advertencia | Usar defaults |

---

## 🔍 Troubleshooting

### ❌ "Variables de entorno no configuradas"
**Solución:**
```bash
# PowerShell
$env:TELEGRAM_BOT_TOKEN = "..."
$env:TELEGRAM_CHAT_ID = "..."

# Bash
export TELEGRAM_BOT_TOKEN="..."
export TELEGRAM_CHAT_ID="..."
```

### ❌ "Error de conexión a Telegram"
- Verificar token válido en https://t.me/botfather
- Verificar chat_id correcto (usar @userinfobot para obtenerlo)
- Revisar firewall/proxy

### ❌ "Timeout en Azure Functions local"
- Aumentar timeout en `host.json`
- Revisar logs: `func start --verbose`

---

## 📝 Función HTTP Disponible

```
POST /api/test-telegram
Content-Type: application/json

Body (opcional):
{
  "mensaje": "Tu mensaje personalizado aquí"
}

Response:
{
  "status": "✅ Mensaje enviado a Telegram: '...'"
}
```

---

## ✅ Checklist de Validación

- [ ] Variables de entorno configuradas
- [ ] Script `test_telegram.py` ejecutado sin errores
- [ ] Mensaje recibido en el chat de Telegram
- [ ] Función HTTP responde correctamente en `localhost:7071`
- [ ] ETL sigue procesando módulos después del test

---

## 🔗 Referencias
- [Azure Functions Python Documentation](https://docs.microsoft.com/en-us/azure/azure-functions/functions-reference-python)
- [Telegram Bot API](https://core.telegram.org/bots/api)
- [Azure Functions Core Tools](https://docs.microsoft.com/en-us/azure/azure-functions/functions-run-local)
