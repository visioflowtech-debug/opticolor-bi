# Script para ejecutar Azure Functions local sin Azurite
# Uso: .\run-local.ps1

Write-Host "🚀 Iniciando Azure Functions ETL Opticolor (Local)" -ForegroundColor Green
Write-Host ""

# Verificar Python
Write-Host "✓ Verificando Python..." -ForegroundColor Cyan
python --version

# Verificar requirements
Write-Host "✓ Verificando dependencias..." -ForegroundColor Cyan
pip list | grep -E "azure-functions|pyodbc|requests"

Write-Host ""
Write-Host "⚠️  IMPORTANTE: Verificar que local.settings.json tenga credenciales correctas:" -ForegroundColor Yellow
Write-Host "   - GESVISION_USER"
Write-Host "   - GESVISION_PASS"
Write-Host "   - SQL_AZURE_CONNECTION_STRING"
Write-Host ""

# Iniciar Functions
Write-Host "🔧 Iniciando Azure Functions Core Tools..." -ForegroundColor Green
Write-Host "   Escuchando en http://localhost:7071" -ForegroundColor Cyan
Write-Host ""

func start --verbose
