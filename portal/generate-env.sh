#!/bin/bash
# Generar valores seguros para .env.local
echo "Generando NEXTAUTH_SECRET..."
SECRET=$(openssl rand -hex 32)
echo "NEXTAUTH_SECRET=$SECRET"
echo ""
echo "Guarda este valor en .env.local y reemplaza YOUR_SECRET_HERE"
