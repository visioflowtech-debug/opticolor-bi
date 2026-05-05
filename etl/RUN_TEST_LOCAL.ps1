# 🧪 Script para ejecutar test local de Telegram
# Uso: .\RUN_TEST_LOCAL.ps1

Write-Host "`n" -ForegroundColor Cyan
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  🧪 TEST LOCAL: TELEGRAM BOT — OPTICOLOR ETL                  ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

# Variables de entorno (CAMBIAR CON TUS CREDENCIALES)
$TELEGRAM_BOT_TOKEN = "tu_token_aqui"
$TELEGRAM_CHAT_ID = "tu_chat_id_aqui"

# Verificar si ya están configuradas en el sistema
if ($env:TELEGRAM_BOT_TOKEN) {
    Write-Host "`n✅ TELEGRAM_BOT_TOKEN ya está configurado en el sistema" -ForegroundColor Green
    $TELEGRAM_BOT_TOKEN = $env:TELEGRAM_BOT_TOKEN
} else {
    Write-Host "`n⚠️  TELEGRAM_BOT_TOKEN no está configurado" -ForegroundColor Yellow
    Write-Host "   Por favor, configúralo:" -ForegroundColor Yellow
    Write-Host "   `$env:TELEGRAM_BOT_TOKEN = 'tu_token'" -ForegroundColor Yellow
}

if ($env:TELEGRAM_CHAT_ID) {
    Write-Host "✅ TELEGRAM_CHAT_ID ya está configurado en el sistema" -ForegroundColor Green
    $TELEGRAM_CHAT_ID = $env:TELEGRAM_CHAT_ID
} else {
    Write-Host "⚠️  TELEGRAM_CHAT_ID no está configurado" -ForegroundColor Yellow
    Write-Host "   Por favor, configúralo:" -ForegroundColor Yellow
    Write-Host "   `$env:TELEGRAM_CHAT_ID = 'tu_chat_id'" -ForegroundColor Yellow
}

# Configurar variables de entorno
Write-Host "`n📝 [PASO 1] Configurando variables de entorno..." -ForegroundColor Blue
$env:TELEGRAM_BOT_TOKEN = $TELEGRAM_BOT_TOKEN
$env:TELEGRAM_CHAT_ID = $TELEGRAM_CHAT_ID
Write-Host "   ✅ Variables configuradas" -ForegroundColor Green

# Verificar que estamos en el directorio correcto
Write-Host "`n📂 [PASO 2] Verificando ubicación..." -ForegroundColor Blue
$ETLS_DIR = (Get-Location).Path
if ($ETLS_DIR -like "*\etl") {
    Write-Host "   ✅ Ubicación correcta: $ETLS_DIR" -ForegroundColor Green
} else {
    Write-Host "   ⚠️  Recomendación: Ejecutar desde c:\opticolor-bi\etl" -ForegroundColor Yellow
}

# Iniciar Azure Functions local
Write-Host "`n🚀 [PASO 3] Iniciando Azure Functions Core Tools..." -ForegroundColor Blue
Write-Host "   Esperando que el runtime esté listo..." -ForegroundColor Cyan
Write-Host "   (Abre otra terminal para enviar requests mientras esto corre)" -ForegroundColor Cyan
Write-Host "`n   Endpoint: http://localhost:7071/api/test-telegram" -ForegroundColor Yellow
Write-Host "   Método: POST" -ForegroundColor Yellow
Write-Host "`n   Ejemplo con curl:" -ForegroundColor Yellow
Write-Host "   curl -X POST http://localhost:7071/api/test-telegram -H `"Content-Type: application/json`" -d '{`"mensaje`": `"Prueba de Telegram`"}'`n" -ForegroundColor Yellow

Write-Host "════════════════════════════════════════════════════════════════`n" -ForegroundColor Cyan

# Ejecutar func start
func start
