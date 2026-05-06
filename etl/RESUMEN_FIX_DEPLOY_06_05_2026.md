# 📋 RESUMEN: Fix Deploy ETL a Flex Consumption — 06/05/2026

## 🔴 Problema Identificado

**Error:** Deploy fallaba en Azure Functions Flex Consumption

**Causa Raíz:** La variable `FUNCTIONS_WORKER_RUNTIME` estaba siendo incluida en app settings de Azure durante el deploy. **Flex Consumption no permite esta variable en app settings** porque:
- El runtime se detecta automáticamente desde `requirements.txt`
- Configurarlo manualmente en app settings causa conflictos

## ✅ Solución Implementada

### 1. GitHub Actions Workflow (Recomendado)
- **Archivo:** `.github/workflows/deploy-etl.yml`
- **Trigger:** Push a rama `main` en carpeta `etl/`
- **Características:**
  - ✅ NO publica `local.settings.json` a Azure
  - ✅ Construye app settings SOLO desde secretos de GitHub
  - ✅ Omite automáticamente `FUNCTIONS_WORKER_RUNTIME`
  - ✅ Valida Python 3.11 y dependencias

### 2. Script Manual PowerShell
- **Archivo:** `etl/DEPLOY_MANUAL.ps1`
- **Uso:** `.\DEPLOY_MANUAL.ps1`
- **Características:**
  - Verifica pre-requisitos (Azure CLI, func core tools)
  - Lee `local.settings.json` pero FILTRA `FUNCTIONS_WORKER_RUNTIME`
  - Aplica settings seguros a Azure
  - Valida post-deploy que se eliminó la variable

### 3. Documentación Técnica
- **Archivo:** `etl/DEPLOY_FIX.md` — Análisis completo
- **Archivo:** `DEPLOY_ETL_GUIA.md` — Guía de inicio rápido

## 📊 Comparativa: Antes vs Después

| Aspecto | Antes | Después |
|---------|-------|---------|
| Deploy | Manual desde Azure Portal | Automático con GitHub Actions |
| App Settings | Incluía FUNCTIONS_WORKER_RUNTIME ❌ | Omite FUNCTIONS_WORKER_RUNTIME ✅ |
| Credenciales | En local.settings.json | En GitHub Secrets (seguro) |
| local.settings.json | No se usaba | Se filtra, no se publica |
| Reproducibilidad | Manual/error-prone | Automático y consistente |

## 🎯 Próximos Pasos

### Inmediato (Hoy)
1. [ ] Crear secretos en GitHub (8 secretos requeridos)
2. [ ] Descargar publish profile de Azure Portal
3. [ ] Push a `main` para ejecutar workflow
4. [ ] Verificar logs en GitHub Actions

### Validación
```bash
# Confirmar que FUNCTIONS_WORKER_RUNTIME NO está
az functionapp config appsettings list \
  --name func-etl-opticolor-prd \
  --resource-group rg-opticolor-prd | grep FUNCTIONS_WORKER_RUNTIME
# (Debe estar vacío)

# Ver logs de ejecución
az functionapp log tail \
  --name func-etl-opticolor-prd \
  --resource-group rg-opticolor-prd
```

## 📁 Archivos Modificados/Creados

| Archivo | Tipo | Propósito |
|---------|------|----------|
| `.github/workflows/deploy-etl.yml` | Nuevo | Workflow GitHub Actions |
| `etl/DEPLOY_FIX.md` | Nuevo | Documentación técnica |
| `etl/DEPLOY_MANUAL.ps1` | Nuevo | Script deploy manual |
| `DEPLOY_ETL_GUIA.md` | Nuevo | Guía rápida |
| `etl/local.settings.json` | Sin cambios | Se mantiene para dev local |

## 🔑 Secretos Requeridos en GitHub

Ir a: Settings → Secrets and variables → Actions

Crear estos 8 secretos:
1. `AZURE_STORAGE_CONNECTION_STRING`
2. `GESVISION_BASE_URL`
3. `GESVISION_USER`
4. `GESVISION_PASS`
5. `SQL_AZURE_CONNECTION_STRING`
6. `TELEGRAM_BOT_TOKEN`
7. `TELEGRAM_CHAT_ID`
8. `AZURE_CREDENTIALS` (crear con `az ad sp create-for-rbac`)
9. `AZURE_FUNCTIONAPP_PUBLISH_PROFILE` (descargar de Azure Portal)

## 💡 Notas Técnicas

- **local.settings.json:** Se mantiene en repo para desarrollo local (en `.gitignore` para credenciales)
- **Flex Consumption:** Detecta runtime automáticamente de `requirements.txt`
- **GitHub Secrets:** Más seguros que versionar credenciales
- **Workflow:** Se ejecuta automáticamente al push en carpeta `etl/`

## ✨ Beneficios Finales

✅ Deploy completamente automatizado  
✅ Credenciales seguras en GitHub Secrets  
✅ Sin conflictos con Flex Consumption  
✅ Reproducible y consistente  
✅ Logs visibles en GitHub Actions  
✅ Rollback fácil (revertir commit)

---

**Fecha:** 06 de Marzo de 2026  
**Estado:** ✅ LISTO PARA IMPLEMENTAR  
**Próxima Acción:** Configurar secretos en GitHub y ejecutar workflow
