# 🚀 Guía de Deploy — ETL Opticolor a Azure Functions Flex Consumption

## 🔴 Problema Identificado

El deploy fallaba porque `FUNCTIONS_WORKER_RUNTIME` se estaba incluyendo en app settings de Azure. **Flex Consumption no permite esta variable en app settings.**

## ✅ Solución Recomendada (Opción 1: GitHub Actions)

### Paso 1: Preparar secretos en GitHub

Ve a: **Settings → Secrets and variables → Actions**

Crea estos secretos:
- `AZURE_STORAGE_CONNECTION_STRING` → Copiar de local.settings.json
- `GESVISION_BASE_URL`
- `GESVISION_USER`
- `GESVISION_PASS`
- `SQL_AZURE_CONNECTION_STRING`
- `TELEGRAM_BOT_TOKEN`
- `TELEGRAM_CHAT_ID`
- `AZURE_CREDENTIALS` → Ejecutar:
  ```bash
  az ad sp create-for-rbac --name "opticolor-ci" --role Owner --scopes /subscriptions/{subscription-id}
  ```
- `AZURE_FUNCTIONAPP_PUBLISH_PROFILE` → Descargar de Azure Portal:
  - Ir a Function App → Download publish profile

### Paso 2: Push a main

```bash
git push origin main
```

El workflow `.github/workflows/deploy-etl.yml` se ejecutará automáticamente.

### Paso 3: Verificar deploy

- Ve a **Actions** en GitHub y confirma que pasó ✅
- O ejecuta:
  ```bash
  az functionapp log tail --name func-etl-opticolor-prd --resource-group rg-opticolor-prd
  ```

---

## 🔧 Opción 2: Deploy Manual Local

Si prefieres hacer deploy desde tu máquina:

### Pre-requisitos
```bash
# Instalar si no tienes
az --version
func --version
```

### Ejecutar deploy

```powershell
cd etl
.\DEPLOY_MANUAL.ps1
```

El script:
- ✅ Verifica pre-requisitos
- ✅ Se conecta a Azure
- ✅ Despliega sin incluir FUNCTIONS_WORKER_RUNTIME
- ✅ Valida la configuración final

---

## 🧹 Opción 3: Limpiar deploy anterior

Si ya se desplegó con la configuración incorrecta:

```bash
# Eliminar FUNCTIONS_WORKER_RUNTIME de app settings
az functionapp config appsettings delete \
  --name func-etl-opticolor-prd \
  --resource-group rg-opticolor-prd \
  --setting-names "FUNCTIONS_WORKER_RUNTIME" \
  --yes

# Verificar que se eliminó
az functionapp config appsettings list \
  --name func-etl-opticolor-prd \
  --resource-group rg-opticolor-prd | grep FUNCTIONS_WORKER_RUNTIME
# (No debe devolver nada)
```

---

## 🔍 Verificación Post-Deploy

```bash
# Ver estado de la función
az functionapp show \
  --name func-etl-opticolor-prd \
  --resource-group rg-opticolor-prd \
  --query "state"

# Ver logs en vivo
az functionapp log tail \
  --name func-etl-opticolor-prd \
  --resource-group rg-opticolor-prd \
  --max-lines 50

# Confirmar que FUNCTIONS_WORKER_RUNTIME NO está en app settings
az functionapp config appsettings list \
  --name func-etl-opticolor-prd \
  --resource-group rg-opticolor-prd \
  --query "[?name=='FUNCTIONS_WORKER_RUNTIME']"
# (Debe estar vacío)
```

---

## 📝 Documentación Técnica

Para más detalles, ver:
- [`etl/DEPLOY_FIX.md`](etl/DEPLOY_FIX.md) — Análisis técnico completo
- [`.github/workflows/deploy-etl.yml`](.github/workflows/deploy-etl.yml) — Workflow de GitHub Actions

---

## ❓ FAQ

**P: ¿Por qué Flex Consumption rechaza FUNCTIONS_WORKER_RUNTIME?**  
R: Flex Consumption detecta automáticamente el runtime desde `requirements.txt`. No es necesario (ni permitido) configurarlo manualmente en app settings.

**P: ¿Dónde debe estar FUNCTIONS_WORKER_RUNTIME entonces?**  
R: En `local.settings.json` para desarrollo local. En Azure, se detecta automáticamente del archivo `requirements.txt` en el deploy.

**P: ¿Qué pasa si elimino local.settings.json?**  
R: NO lo hagas. Ese archivo es necesario para hacer `func start` localmente.

**P: ¿Y si necesito cambiar credenciales después?**  
R: Actualiza el secreto en GitHub, y el próximo push a `main` lo desplegará.

---

## 📋 Checklist Final

- [ ] Secretos creados en GitHub
- [ ] Publish profile descargado
- [ ] Workflow ejecutado exitosamente
- [ ] FUNCTIONS_WORKER_RUNTIME NO en app settings
- [ ] Logs disponibles en `az functionapp log tail`
- [ ] Próximas ejecuciones CRON aparecen en los logs
