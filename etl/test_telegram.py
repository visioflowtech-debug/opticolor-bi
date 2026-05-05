#!/usr/bin/env python3
"""
🧪 Script de Testing Local para Telegram
Prueba el envío de mensajes sin ejecutar el ETL completo
"""

import os
import sys
import requests
import json
from datetime import datetime

# Colores para output
GREEN = '\033[92m'
RED = '\033[91m'
YELLOW = '\033[93m'
BLUE = '\033[94m'
RESET = '\033[0m'

def test_telegram_local():
    """Prueba envío de Telegram localmente."""

    print(f"\n{BLUE}{'='*70}")
    print(f"🧪 TEST LOCAL: TELEGRAM ETL OPTICOLOR")
    print(f"{'='*70}{RESET}\n")

    # Verificar variables de entorno
    token = os.getenv("TELEGRAM_BOT_TOKEN")
    chat_id = os.getenv("TELEGRAM_CHAT_ID")

    if not token or not chat_id:
        print(f"{RED}❌ Variables de entorno no configuradas:{RESET}")
        print(f"   • TELEGRAM_BOT_TOKEN: {token or 'NO CONFIGURADO'}")
        print(f"   • TELEGRAM_CHAT_ID: {chat_id or 'NO CONFIGURADO'}")
        print(f"\n{YELLOW}Configurar antes de ejecutar:{RESET}")
        print(f"   export TELEGRAM_BOT_TOKEN='tu_token'")
        print(f"   export TELEGRAM_CHAT_ID='tu_chat_id'\n")
        return False

    print(f"{GREEN}✅ Credenciales Telegram configuradas{RESET}\n")

    # Preparar mensajes de prueba
    timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
    messages = [
        f"🧪 TEST 1: Mensaje simple — {timestamp}",
        f"✅ TEST 2: ETL Opticolor iniciado — {timestamp}",
        f"📊 TEST 3: Módulo PRODUCTOS completado — 143,860 registros — {timestamp}",
    ]

    url = f"https://api.telegram.org/bot{token}/sendMessage"

    print(f"{BLUE}Enviando {len(messages)} mensajes de prueba...{RESET}\n")

    success_count = 0
    for i, msg in enumerate(messages, 1):
        try:
            payload = {
                "chat_id": chat_id,
                "text": msg,
                "disable_notification": False
            }

            print(f"  [{i}/{len(messages)}] Enviando: {msg[:50]}...")
            response = requests.post(url, json=payload, timeout=(10, 30))

            if response.status_code == 200:
                print(f"      {GREEN}✅ OK{RESET}")
                success_count += 1
            else:
                print(f"      {RED}❌ Error {response.status_code}{RESET}")
                print(f"      Respuesta: {response.text[:100]}")

        except Exception as e:
            print(f"      {RED}❌ Excepción: {str(e)[:100]}{RESET}")

    print(f"\n{BLUE}{'='*70}{RESET}")
    print(f"{GREEN if success_count == len(messages) else YELLOW}Resultados: {success_count}/{len(messages)} mensajes enviados{RESET}\n")

    if success_count == len(messages):
        print(f"{GREEN}✅ TEST EXITOSO — Telegram está configurado correctamente{RESET}\n")
        return True
    else:
        print(f"{RED}❌ TEST FALLIDO — Revisar configuración de Telegram{RESET}\n")
        return False

if __name__ == "__main__":
    success = test_telegram_local()
    sys.exit(0 if success else 1)
