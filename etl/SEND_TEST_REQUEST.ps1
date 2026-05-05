# 🧪 Script para enviar requests de test a Telegram
# Uso: .\SEND_TEST_REQUEST.ps1

param(
    [string]$Mensaje = "✅ Prueba de Telegram — ETL Opticolor funcionando"
)

Write-Host "`n" -ForegroundColor Cyan
Write-Host "╔════════════════════════════════════════════════════════════════╗" -ForegroundColor Cyan
Write-Host "║  📤 ENVIANDO TEST REQUEST A TELEGRAM                          ║" -ForegroundColor Cyan
Write-Host "╚════════════════════════════════════════════════════════════════╝" -ForegroundColor Cyan

$URL = "http://localhost:7071/api/test-telegram"

Write-Host "`n📍 Detalles de la Request:" -ForegroundColor Blue
Write-Host "   URL: $URL" -ForegroundColor White
Write-Host "   Método: POST" -ForegroundColor White
Write-Host "   Mensaje: $Mensaje" -ForegroundColor Cyan

Write-Host "`n⏳ Enviando..." -ForegroundColor Yellow

try {
    $response = Invoke-WebRequest -Uri $URL `
        -Method POST `
        -ContentType "application/json" `
        -Body @{mensaje = $Mensaje} | ConvertTo-Json

    Write-Host "`n✅ RESPUESTA EXITOSA:" -ForegroundColor Green
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Green
    Write-Host $response -ForegroundColor White
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Green

    Write-Host "`n✅ Verifica tu chat de Telegram para confirmar que el mensaje llegó" -ForegroundColor Green

} catch {
    Write-Host "`n❌ ERROR EN LA REQUEST:" -ForegroundColor Red
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "Error: $_" -ForegroundColor White
    Write-Host "════════════════════════════════════════════════════════════════" -ForegroundColor Red
    Write-Host "`n💡 Soluciones:" -ForegroundColor Yellow
    Write-Host "   1. Verifica que Azure Functions está corriendo (.\RUN_TEST_LOCAL.ps1)" -ForegroundColor Yellow
    Write-Host "   2. Espera 5-10 segundos después de ejecutar RUN_TEST_LOCAL.ps1" -ForegroundColor Yellow
    Write-Host "   3. Verifica que las variables de entorno están configuradas" -ForegroundColor Yellow
}

Write-Host "`n"
