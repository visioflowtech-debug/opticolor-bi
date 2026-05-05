# 🚀 Quick Start: Testing Local del Bot de Telegram

## ⚡ En 3 pasos (5 minutos)

### Paso 1️⃣: Configurar credenciales (PowerShell)

```powershell
# Abre PowerShell y ejecuta:
$env:TELEGRAM_BOT_TOKEN = "tu_token_del_bot"
$env:TELEGRAM_CHAT_ID = "tu_chat_id"

# Verifica que esté configurado:
echo $env:TELEGRAM_BOT_TOKEN
echo $env:TELEGRAM_CHAT_ID
```

**¿Dónde obtener estas credenciales?**
- **Bot Token**: @BotFather en Telegram → `/newbot`
- **Chat ID**: @userinfobot en Telegram → muestra tu ID

---

### Paso 2️⃣: Iniciar Azure Functions local (Terminal 1)

```powershell
# En c:\opticolor-bi\etl\

# Opción A: Usar script (recomendado)
.\RUN_TEST_LOCAL.ps1

# Opción B: Manual
func start
```

**Espera a ver en la consola:**
```
Worker process started and initialized.
Host initialized
```

---

### Paso 3️⃣: Enviar test (Terminal 2)

```powershell
# En otra terminal, en c:\opticolor-bi\etl\

# Opción A: Usar script (recomendado)
.\SEND_TEST_REQUEST.ps1

# Opción B: Manual con curl
curl -X POST http://localhost:7071/api/test-telegram `
  -H "Content-Type: application/json" `
  -d '{"mensaje": "Mi mensaje personalizado"}'
```

---

## 📊 Qué debes ver

### En Terminal 1 (consola Azure Functions):

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

### En Terminal 2:

```
✅ RESPUESTA EXITOSA:
════════════════════════════════════════════════════════════
✅ Mensaje enviado a Telegram: '✅ Prueba de Telegram — ETL Opticolor funcionando'

Ahora sigue procesando...
════════════════════════════════════════════════════════════

✅ Verifica tu chat de Telegram para confirmar que el mensaje llegó
```

### En tu chat de Telegram:

```
🧪 TEST: ✅ Prueba de Telegram — ETL Opticolor funcionando
```

---

## ✅ Checklist de Validación

- [ ] `TELEGRAM_BOT_TOKEN` configurado en PowerShell
- [ ] `TELEGRAM_CHAT_ID` configurado en PowerShell
- [ ] `func start` ejecutándose sin errores
- [ ] `SEND_TEST_REQUEST.ps1` retorna ✅ RESPUESTA EXITOSA
- [ ] ✅ Viste el mensaje en tu chat de Telegram
- [ ] 🧪 Los logs en Terminal 1 muestran todos los ✅

---

## 🆘 Si algo no funciona

### ❌ Error: "Cannot find or load the specified module"

```powershell
# Instala Azure Functions Core Tools
npm install -g azure-functions-core-tools@4 --unsafe-perm true
```

### ❌ Error: "TELEGRAM_BOT_TOKEN no está configurado"

```powershell
# Verifica que está configurado:
Write-Host "Token: $env:TELEGRAM_BOT_TOKEN"
Write-Host "Chat: $env:TELEGRAM_CHAT_ID"

# Si está vacío, configúralo nuevamente
$env:TELEGRAM_BOT_TOKEN = "tu_token"
$env:TELEGRAM_CHAT_ID = "tu_chat_id"
```

### ❌ Error: "Could not connect to localhost:7071"

```powershell
# Espera 10 segundos después de ejecutar RUN_TEST_LOCAL.ps1
# Azure Functions toma tiempo en iniciar

# Verifica en la consola que dice "Host initialized"
```

### ❌ El mensaje no llega a Telegram

1. Verifica que el token es válido (prueba en https://api.telegram.org/botTOKEN/getMe)
2. Verifica que el chat_id es correcto (@userinfobot te da el tuyo)
3. Revisa los logs en Terminal 1 para ver exactamente dónde falló

---

## 📝 Modificar el mensaje de prueba

```powershell
# Con script:
.\SEND_TEST_REQUEST.ps1 -Mensaje "Mi mensaje personalizado"

# Con curl:
curl -X POST http://localhost:7071/api/test-telegram `
  -H "Content-Type: application/json" `
  -d '{"mensaje": "Mi mensaje personalizado"}'
```

---

## 🛑 Detener el testing

- Terminal 1: Presiona `Ctrl+C` para detener Azure Functions
- Luego: Descomenta el `@app.timer_trigger` en `function_app.py` para reactivar el ETL

---

## 🔗 Próximos pasos

✅ Cuando confirmes que Telegram funciona:

1. Descomenta `@app.timer_trigger` en `function_app.py` (línea 30)
2. Haz push a `main` para deploy en producción
3. El ETL comenzará a ejecutarse según el CRON (8:30 AM Venezuela)

**Estado actual:**
- ✅ Vista eliminada comentada (líneas 629-634)
- ✅ Timer principal deshabilitado para testing
- ✅ Función test-telegram lista en `localhost:7071`
- ⏳ Esperando confirmación de que Telegram funciona
