# 🚀 Guía: Ejecutar ETL en VS Code (Sin Azurite)

## Problema Actual

Azurite (Storage Emulator) está causando error 500 al iniciar. **Solución: No lo necesitamos en local.**

## ✅ Solución: Ejecutar Sin Azurite

### Paso 1: Abrir Carpeta en VS Code

```bash
File → Open Folder → c:\opticolor-bi
```

### Paso 2: Terminal Integrada en VS Code

```
Ctrl + ` (o View → Terminal)
```

### Paso 3: Navegar a la carpeta ETL

```powershell
cd etl
```

### Paso 4: Iniciar Azure Functions (SIN Azurite)

**Opción A: Desde PowerShell (Recomendado)**

```powershell
.\run-local.ps1
```

**Opción B: Comando directo**

```bash
func start --verbose
```

### Paso 5: Ver Función Ejecutándose

Debería ver en terminal:

```
Functions:

        EtlOrquestadorPrincipal: timerTrigger

For detailed output, run func with --verbose flag.
[12:00:00] Host lock lease acquired by instance ID...
[12:00:00] Worker process started and initialized.
```

✅ **Listo!** Sin errores de Azurite.

## 🧪 Probar Función Manualmente

En otra terminal de VS Code (Ctrl + `):

```powershell
# Opción 1: Curl (si tienes curl instalado)
curl -X POST http://localhost:7071/admin/functions/EtlOrquestadorPrincipal

# Opción 2: PowerShell
Invoke-WebRequest -Method POST -Uri "http://localhost:7071/admin/functions/EtlOrquestadorPrincipal"
```

O usar **VS Code Extension → Azure Functions → Run Function**

## 🔍 Configuración Verificada

✅ `local.settings.json`:
- `AzureWebJobsStorage` = `""` (vacío, sin Azurite)
- `GESVISION_USER` = credenciales reales
- `SQL_AZURE_CONNECTION_STRING` = conexión a Azure SQL real

✅ `function_app.py`:
- Sin lock global (eliminado)
- Cascada completa (18 módulos)
- Ventanas de tiempo optimizadas (3 días)

## 📝 Archivos Importantes

- `.vscode/launch.json` — Configuración debug VS Code
- `run-local.ps1` — Script para ejecutar fácilmente
- `SETUP_LOCAL.md` — Guía detallada si necesitas más

## ⚠️ Si Aún Falla

1. **Limpiar caché Python:**
   ```powershell
   rm -r __pycache__
   rm -r .venv/__pycache__
   ```

2. **Reiniciar VS Code:**
   - Cerrar completamente VS Code
   - Abrir de nuevo

3. **Verificar credenciales en `local.settings.json`:**
   - GESVISION_USER debe ser correcto
   - SQL_AZURE_CONNECTION_STRING debe ser válida

4. **Ver logs detallados:**
   ```powershell
   func start --verbose --log-level debug
   ```

---

**¡Ahora debería funcionar sin problemas!**
