# 🚀 Guía de Configuración Local - ETL Opticolor

## Requisitos Previos

```bash
# Node.js 18+
node --version

# Azure Functions Core Tools 4.x
func --version

# Python 3.9+
python --version

# pip dependencies
pip install -r requirements.txt
```

## Paso 1: Preparar local.settings.json

```bash
# Copiar template a local.settings.json
cp etl/local.settings.template.json etl/local.settings.json
```

Luego editar `etl/local.settings.json` y reemplazar:
- `tu_usuario_api` → Usuario Gesvision API
- `tu_password_api` → Password Gesvision API  
- `tu_connection_string_aqui` → Connection string Azure SQL

```json
{
  "Values": {
    "AzureWebJobsStorage": "UseDevelopmentStorage=true",
    "FUNCTIONS_WORKER_RUNTIME": "python",
    "GESVISION_USER": "usuarioapi_opticolor",
    "GESVISION_PASS": "Usu4r1o_ap1*",
    "SQL_AZURE_CONNECTION_STRING": "Driver={ODBC Driver 18 for SQL Server};Server=tcp:srv-opticolor.database.windows.net,1433;Database=db-opticolor-dw;Uid=admin_opticolor;Pwd=bS6RyEU33MsY8m@;Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"
  }
}
```

## Paso 2: Iniciar Azurite (Storage Emulator)

En una terminal NUEVA:

```bash
# Instalar Azurite si no está
npm install -g azurite

# Iniciar Azurite (escucha en puerto 10000-10002)
azurite --silent --location ./azurite-data
```

Déjalo corriendo. Debería ver:
```
Azurite Blob service is starting at http://127.0.0.1:10000
Azurite Queue service is starting at http://127.0.0.1:10001
Azurite Table service is starting at http://127.0.0.1:10002
```

## Paso 3: Iniciar Azure Functions

En otra terminal NUEVA:

```bash
cd c:\opticolor-bi\etl

# Verificar sintaxis
python -m py_compile function_app.py

# Iniciar Functions local
func start --verbose

# O desde VS Code: Presionar F5
```

Debería ver:
```
Functions:
        EtlOrquestadorPrincipal: timerTrigger

Listening on http://0.0.0.0:7071
```

## Paso 4: Probar Manualmente

En otra terminal:

```bash
# Ejecutar función manualmente (sin esperar al timer)
curl -X POST http://localhost:7071/admin/functions/EtlOrquestadorPrincipal
```

O desde VS Code → Run → "Attach to Python Functions"

## 🔧 Troubleshooting

### Error: "Service request failed. Status: 500"

**Causa:** Azurite no está corriendo o falló.

**Solución:**
1. Verificar que Azurite esté en terminal separada
2. Limpiar datos: `rm -rf azurite-data`
3. Reiniciar: `azurite --silent --location ./azurite-data`

### Error: "Connection to SQL failed"

**Causa:** Credenciales incorrectas en local.settings.json

**Solución:**
1. Verificar SQL_AZURE_CONNECTION_STRING
2. Probar conexión: `sqlcmd -S srv-opticolor.database.windows.net -U admin_opticolor -P [password]`

### Error: "GESVISION_USER not found"

**Causa:** Variable de entorno no está en local.settings.json

**Solución:**
1. Verificar que local.settings.json tenga todas las variables
2. Reiniciar `func start`

## 📝 Notas

- **Azurite**: Emulador local de Azure Storage Blobs/Queues/Tables
- **Functions Runtime**: Interpreta el código Python y ejecuta timers
- **local.settings.json**: NO incluir en git (contiene credenciales)
- **Desarrollo vs Production**: Local usa Azurite + SQL Azure; Azure usa Blob Storage + SQL Azure

## 🚀 Comandos Útiles

```bash
# Ver logs detallados
func start --verbose

# Limpiar completamente
rm -rf azurite-data
rm -rf .venv/__pycache__
rm -rf etl/__pycache__

# Recrear virtual env
python -m venv .venv
.venv\Scripts\activate
pip install -r requirements.txt
```

---

**Última actualización:** 23 Abril 2026
