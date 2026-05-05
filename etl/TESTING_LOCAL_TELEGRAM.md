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
