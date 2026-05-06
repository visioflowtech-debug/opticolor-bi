# 🔧 FIX: Deploy ETL a Azure Functions Flex Consumption

## ❌ Problema
El deploy fallaba porque `FUNCTIONS_WORKER_RUNTIME` estaba siendo enviado a Azure App Settings durante el deploy. **Flex Consumption NO permite esta variable en app settings.**

## ✅ Solución

### Opción 1: Usar el nuevo workflow de GitHub Actions (Recomendado)
Se ha creado `.github/workflows/deploy-etl.yml` que:
- ✅ NO publica `local.settings.json` a Azure
- ✅ Construye app settings solo desde secretos de GitHub
- ✅ Omite `FUNCTIONS_WORKER_RUNTIME` de app settings
- ✅ Usa `azure/functions-action@v1.5.1`

**Pasos:**
1. Agregar secretos en GitHub → Settings → Secrets and variables:
   - `AZURE_STORAGE_CONNECTION_STRING`
   - `GESVISION_BASE_URL`
   - `GESVISION_USER`
   - `GESVISION_PASS`
   - `SQL_AZURE_CONNECTION_STRING`
   - `TELEGRAM_BOT_TOKEN`
   - `TELEGRAM_CHAT_ID`
   - `AZURE_CREDENTIALS` (para login)
   - `AZURE_FUNCTIONAPP_PUBLISH_PROFILE` (descargado de Azure Portal)

2. Push a rama `main` en la carpeta `etl/`
3. El workflow se ejecutará automáticamente

### Opción 2: Deploy manual con Azure CLI (Si prefieres no usar GitHub Actions)

```bash
# 1. Crear archivo temporal con settings seguros (SIN FUNCTIONS_WORKER_RUNTIME)
cat > /tmp/appsettings.json <<'EOF'
{
  "AzureWebJobsStorage": "...",
  "GESVISION_BASE_URL": "...",
  "GESVISION_USER": "...",
  "GESVISION_PASS": "...",
  "SQL_AZURE_CONNECTION_STRING": "...",
  "TELEGRAM_BOT_TOKEN": "...",
  "TELEGRAM_CHAT_ID": "...",
  "AzureFunctionsJobHost__logging__logLevel__default": "Error",
  "AzureWebJobs.EtlOrquestadorPrincipal.Disabled": "false"
}
EOF

# 2. Deploy CON ADVERTENCIA: --publish-local-settings NO debe estar presente
cd etl/
func azure functionapp publish func-etl-opticolor-prd

# 3. Aplicar app settings desde archivo (sin FUNCTIONS_WORKER_RUNTIME)
az functionapp config appsettings set \
  --name func-etl-opticolor-prd \
  --resource-group rg-opticolor-prd \
  --settings @/tmp/appsettings.json
```

### Opción 3: Limpiar App Settings existentes (Si el deploy ya falló)

Si la función ya fue desplegada pero con configuración incorrecta:

```bash
# Eliminar FUNCTIONS_WORKER_RUNTIME si existe
az functionapp config appsettings delete \
  --name func-etl-opticolor-prd \
  --resource-group rg-opticolor-prd \
  --setting-names FUNCTIONS_WORKER_RUNTIME

# Verificar que se eliminó
az functionapp config appsettings list \
  --name func-etl-opticolor-prd \
  --resource-group rg-opticolor-prd \
  --query "[?name=='FUNCTIONS_WORKER_RUNTIME']"
```

## 📋 Verificación Post-Deploy

```bash
# Verificar que FUNCTIONS_WORKER_RUNTIME NO está en app settings
az functionapp config appsettings list \
  --name func-etl-opticolor-prd \
  --resource-group rg-opticolor-prd | grep FUNCTIONS_WORKER_RUNTIME

# Si no devuelve nada, ✅ CORRECTO

# Verificar que la función está activa
az functionapp show \
  --name func-etl-opticolor-prd \
  --resource-group rg-opticolor-prd \
  --query "state"
```

## 🔍 ¿Por qué sucedió?

1. **Azure Functions Core Tools** — Por defecto, `func publish` incluye TODAS las variables de `local.settings.json`
2. **Flex Consumption** — No permite configurar el runtime como app setting (se detecta automáticamente de requirements.txt)
3. **Solución** — El workflow construye app settings desde secretos, omitiendo FUNCTIONS_WORKER_RUNTIME

## 📝 Notas Importantes

- ✅ `local.settings.json` se mantiene en el repositorio para desarrollo local
- ✅ `.gitignore` debe contener `local.settings.json` para no exponerse credenciales
- ✅ App settings en Azure se configuran desde GitHub Secrets
- ✅ El runtime se detecta de `requirements.txt` (Python)
