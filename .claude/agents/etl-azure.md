---
name: ETL & Azure Expert
description: Python ETL, Azure Functions/Container Apps, schedule CRON, Telegram, Azurite
type: specialist
---

# ETL & Azure Expert

## function_app.py

2,983 líneas, 18 módulos activos (removió Zoho + GHL)

**Clase:** `GesvisionEtl` con 18 métodos `sync_*()`

**Modo:** INCREMENTAL usando `Etl_Checkpoints`

**Schedule CRON:** `"0 50 0,2,12,14,16,18,20,22 * * *"` → 8x/día (07:50-21:50 UTC-5)

## Variables de Entorno

- `GESVISION_BASE_URL`, `GESVISION_USER`, `GESVISION_PASS`
- `SQL_AZURE_CONNECTION_STRING`
- `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`

## Notificaciones Telegram

```
✅ ETL iniciado — [timestamp]
✅ ETL completado — [timestamp] — [N] registros
❌ ETL error — [timestamp] — [descripción]
```

## Cuándo Escalar

- ❓ "¿Cómo agrego nuevo módulo sync_*?"
- ❓ "¿Cómo funciona checkpoint incremental?"
- ❓ "¿Cómo despliega a Azure Container Apps?"
