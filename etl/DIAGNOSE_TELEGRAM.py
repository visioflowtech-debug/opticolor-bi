#!/usr/bin/env python3
"""
🔍 Diagnóstico de configuración de Telegram
Verifica que el token y chat_id sean válidos
"""

import os
import requests
import json

print("\n" + "="*80)
print("DIAGNOSTICO: CONFIGURACION TELEGRAM")
print("="*80 + "\n")

# 1. Obtener credenciales
token = os.getenv("TELEGRAM_BOT_TOKEN")
chat_id = os.getenv("TELEGRAM_CHAT_ID")

print("[1] Credenciales configuradas:")
if token:
    print(f"    Token: {token[:10]}...{token[-5:]} [OK]")
else:
    print("    Token: NO CONFIGURADO [ERROR]")

if chat_id:
    print(f"    Chat ID: {chat_id} [OK]")
else:
    print("    Chat ID: NO CONFIGURADO [ERROR]")

# 2. Validar token con Telegram
print("\n[2] Validando token con Telegram API...")
if token:
    try:
        url = f"https://api.telegram.org/bot{token}/getMe"
        resp = requests.get(url, timeout=10)
        data = resp.json()

        if data.get("ok"):
            bot_info = data.get("result", {})
            print(f"    Bot name: {bot_info.get('first_name')} [OK]")
            print(f"    Bot username: @{bot_info.get('username')} [OK]")
            print(f"    Bot ID: {bot_info.get('id')} [OK]")
        else:
            print(f"    Error: {data.get('description')} [ERROR]")
    except Exception as e:
        print(f"    Excepcion: {e} [ERROR]")
else:
    print("    No hay token para validar [SKIP]")

# 3. Probar envío
print("\n[3] Intentando enviar mensaje de prueba...")
if token and chat_id:
    try:
        url = f"https://api.telegram.org/bot{token}/sendMessage"
        payload = {
            "chat_id": chat_id,
            "text": "DIAGNOSTICO: Mensaje de prueba desde opticolor-bi"
        }

        print(f"    URL: {url[:50]}...")
        print(f"    Chat ID: {chat_id}")
        print(f"    Enviando...")

        resp = requests.post(url, json=payload, timeout=10)
        data = resp.json()

        if data.get("ok"):
            msg_id = data.get("result", {}).get("message_id")
            print(f"    EXITO: Mensaje enviado (ID: {msg_id}) [OK]")
        else:
            error_desc = data.get("description", "Error desconocido")
            print(f"    ERROR: {error_desc}")
            print(f"    Respuesta completa: {json.dumps(data, indent=2)}")

    except Exception as e:
        print(f"    Excepcion: {e} [ERROR]")
else:
    print("    Faltan credenciales [SKIP]")

print("\n" + "="*80)
print("RESUMEN:")
print("="*80)
print("""
Si ves [OK] en todo:
  1. El bot está válido
  2. El chat_id es correcto
  3. El mensaje debería haber llegado

Si ves [ERROR]:
  1. Token inválido → Obtén uno nuevo de @BotFather
  2. Chat ID inválido → Usa @userinfobot para obtenerlo
  3. Bot no en grupo → Agrégalo manualmente
  4. Permisos → Asegúrate que el bot pueda enviar mensajes
""")
print("="*80 + "\n")
