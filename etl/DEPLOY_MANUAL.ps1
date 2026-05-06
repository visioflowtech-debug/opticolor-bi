# Script para hacer deploy manual del ETL a Azure Functions Flex Consumption
# SIN incluir FUNCTIONS_WORKER_RUNTIME en app settings

param(
    [string]$FunctionAppName = "func-etl-opticolor-prd",
    [string]$ResourceGroup = "rg-opticolor-prd",
    [string]$SettingsFile = "local.settings.json"
)

Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host "📦 DEPLOY ETL a Azure Functions Flex Consumption" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Cyan
Write-Host ""

# 1. Verificar pre-requisitos
Write-Host "✓ Verificando pre-requisitos..." -ForegroundColor Yellow

if (-not (Get-Command az -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Azure CLI no está instalado" -ForegroundColor Red
    exit 1
}

if (-not (Get-Command func -ErrorAction SilentlyContinue)) {
    Write-Host "❌ Azure Functions Core Tools no está instalado" -ForegroundColor Red
    exit 1
}

if (-not (Test-Path $SettingsFile)) {
    Write-Host "❌ No encontrado: $SettingsFile" -ForegroundColor Red
    exit 1
}

Write-Host "  ✅ Azure CLI OK"
Write-Host "  ✅ Functions Core Tools OK"
Write-Host "  ✅ local.settings.json encontrado"
Write-Host ""

# 2. Verificar login a Azure
Write-Host "✓ Verificando login a Azure..." -ForegroundColor Yellow
$currentUser = az account show --query "userDisplayName" -o tsv 2>$null

if (-not $currentUser) {
    Write-Host "⚠️  No hay sesión activa. Iniciando login..." -ForegroundColor Yellow
    az login
} else {
    Write-Host "  ✅ Conectado como: $currentUser" -ForegroundColor Green
}

Write-Host ""

# 3. Preparar app settings (SIN FUNCTIONS_WORKER_RUNTIME)
Write-Host "✓ Preparando app settings para Flex Consumption..." -ForegroundColor Yellow

$localSettings = Get-Content $SettingsFile | ConvertFrom-Json
$appSettings = @()

foreach ($key in $localSettings.Values.PSObject.Properties.Name) {
    $value = $localSettings.Values.$key

    # IMPORTANTE: Omitir FUNCTIONS_WORKER_RUNTIME para Flex Consumption
    if ($key -eq "FUNCTIONS_WORKER_RUNTIME") {
        Write-Host "  ⚠️  Omitiendo: $key (no permitido en Flex Consumption)" -ForegroundColor Yellow
        continue
    }

    $appSettings += "$key=$value"
}

Write-Host "  ✅ $($appSettings.Count) settings preparados" -ForegroundColor Green
Write-Host ""

# 4. Deploy con func
Write-Host "✓ Desplegando con Azure Functions Core Tools..." -ForegroundColor Yellow
Write-Host "  Command: func azure functionapp publish $FunctionAppName" -ForegroundColor Cyan
Write-Host ""

# Nota: NO usar --publish-local-settings aquí
func azure functionapp publish $FunctionAppName

if ($LASTEXITCODE -ne 0) {
    Write-Host "❌ Deploy falló" -ForegroundColor Red
    exit 1
}

Write-Host ""
Write-Host "✅ Deploy completado" -ForegroundColor Green
Write-Host ""

# 5. Aplicar app settings
Write-Host "✓ Actualizando app settings en Azure..." -ForegroundColor Yellow

# Convertir array a formato de Azure CLI
$settingsArg = $appSettings -join " "

az functionapp config appsettings set `
    --name $FunctionAppName `
    --resource-group $ResourceGroup `
    --settings $appSettings

Write-Host "  ✅ App settings actualizados" -ForegroundColor Green
Write-Host ""

# 6. Verificación final
Write-Host "✓ Verificando configuración..." -ForegroundColor Yellow

$hasWorkerRuntime = az functionapp config appsettings list `
    --name $FunctionAppName `
    --resource-group $ResourceGroup `
    --query "[?name=='FUNCTIONS_WORKER_RUNTIME']" | ConvertFrom-Json

if ($hasWorkerRuntime.Count -gt 0) {
    Write-Host "❌ ERROR: FUNCTIONS_WORKER_RUNTIME sigue presente en app settings" -ForegroundColor Red
    Write-Host "   Eliminando..." -ForegroundColor Yellow

    az functionapp config appsettings delete `
        --name $FunctionAppName `
        --resource-group $ResourceGroup `
        --setting-names "FUNCTIONS_WORKER_RUNTIME" `
        --yes

    Write-Host "  ✅ Eliminado" -ForegroundColor Green
} else {
    Write-Host "  ✅ FUNCTIONS_WORKER_RUNTIME NO está en app settings (correcto)" -ForegroundColor Green
}

Write-Host ""

# 7. Resumen
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host "✅ DEPLOY EXITOSO" -ForegroundColor Green
Write-Host "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━" -ForegroundColor Green
Write-Host ""
Write-Host "📋 Detalles:"
Write-Host "  - Function App: $FunctionAppName"
Write-Host "  - Resource Group: $ResourceGroup"
Write-Host "  - App Settings: $($appSettings.Count) variables"
Write-Host "  - FUNCTIONS_WORKER_RUNTIME: Omitido (Flex Consumption)" -ForegroundColor Green
Write-Host ""
Write-Host "🔍 Para verificar logs:"
Write-Host "  az functionapp log tail --name $FunctionAppName --resource-group $ResourceGroup"
Write-Host ""
