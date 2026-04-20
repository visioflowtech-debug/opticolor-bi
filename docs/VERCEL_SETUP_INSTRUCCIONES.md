# 🚀 Vercel Deploy — Instrucciones Paso a Paso

**Fecha:** 20 de abril de 2026  
**Estado:** Todo preparado, solo necesita configuración en Vercel dashboard  
**Repositorio:** https://github.com/visioflowtech-debug/opticolor-bi

---

## CHECKLIST PRE-DEPLOY ✅

- ✅ Código committeado a GitHub (main branch)
- ✅ `vercel.json` creado (detecta portal/ como root)
- ✅ `.env.production` preparado con variables
- ✅ `package.json` en portal/ con scripts correctos
- ✅ Build testéado localmente (`npm run build` exitoso)
- ✅ README.md con instrucciones

---

## PASOS PARA CREAR APP EN VERCEL

### 1. LOGIN A VERCEL
```
https://vercel.com/login
(usa tu cuenta existente de Vercel)
```

### 2. CREAR NUEVO PROYECTO
- Click: **"Add New..."** → **"Project"**
- O directamente: https://vercel.com/new

### 3. IMPORTAR REPOSITORIO
- Busca: `opticolor-bi` 
- Selecciona: `visioflowtech-debug/opticolor-bi`
- Click: **"Import"**

### 4. CONFIGURACIÓN DE BUILD (VERCEL DETECTA AUTOMÁTICAMENTE)
Debería verse así:
```
Framework: Next.js ✅
Build Command: npm run build ✅
Output Directory: .next ✅
Development Command: npm run dev
```

Si dice "Package.json not found in root" → Vercel detectó `vercel.json` ✅

### 5. VARIABLES DE ENTORNO
En **Environment Variables**, agregar:

```
NEXTAUTH_SECRET = opticolor-bi-secret-prod-2026-semana2
NEXTAUTH_URL = https://opticolor-bi.vercel.app
```

(Opcional por ahora — SQL no está conectado en Semana 2):
```
AZURE_SQL_SERVER = srv-opticolor.database.windows.net
AZURE_SQL_DATABASE = db-opticolor-dw
AZURE_SQL_USER = admin_opticolor
AZURE_SQL_PASSWORD = (cuando llegue de Opticolor)
```

### 6. DEPLOY
- Click: **"Deploy"**
- ESPERA 2-3 min (Vercel compila `npm run build`)
- Ver logs en real-time

### 7. SUCCESS ✅
Recibirás URL tipo:
```
https://opticolor-bi-xyzabc.vercel.app
```

Vercel te dará opción de usar dominio personalizado:
```
https://opticolor-bi.vercel.app (sugerido)
```

---

## TESTING DESPUÉS DEL DEPLOY

### 1. ACCEDER AL PORTAL
```
https://opticolor-bi.vercel.app
```

### 2. FLUJO DE TESTING
1. **Redirección:** Debería ir a `/dashboard` automáticamente
2. **Navbar:** Ver logo + info usuario + botón logout
3. **Sidebar:** 5 links (Resumen Comercial, Eficiencia, etc.)
4. **Dashboard:** 5 cards con KPIs + LineChart de Recharts
5. **Login:** Navega a `/auth/login` 
   - Ingresa cualquier email/password
   - Debería aceptar (mock NextAuth)
6. **Colores:** Verificar paleta Opticolor (#1A3A6B azul, #D4A017 dorado)

### 3. SI ALGO FALLA
- Ve a **Project Settings** → **Logs**
- Busca "Build failed" o "Runtime error"
- Vercel muestra stack trace completo

---

## CONFIGURACIÓN AUTOMÁTICA FUTURA (Semana 2.2)

Una vez que lleguen datos de Opticolor:

### En Vercel Dashboard:
1. **Project Settings** → **Environment Variables**
2. Actualizar:
   - `NEXTAUTH_SECRET` (generar nuevo secure)
   - `AZURE_SQL_PASSWORD` (credenciales reales)
   - Agregar `GESVISION_API_KEY` (cuando ETL esté ready)

### Deploy automático:
Cada push a `main` → Vercel redeploya automáticamente ✅

---

## ROLLBACK SI NECESARIO

Si algo sale mal:
1. **Vercel Dashboard** → **Deployments**
2. Busca último deployment exitoso
3. Click 3 puntitos → **Promote to Production**
4. Vuelve a versión anterior en <30 segundos

---

## TROUBLESHOOTING

| Problema | Solución |
|----------|----------|
| "Cannot find portal/package.json" | Vercel no leyó `vercel.json`. Espera 30s y redeploy. |
| Build fails with "Module not found" | Falta instalar dependencias. Vercel reinstala con `npm install`. |
| "NEXTAUTH_SECRET not set" | Agregar en Environment Variables (paso 5 arriba). |
| 500 error en dashboard | Mock auth da error. Ir a `/auth/login` sin credenciales reales. |

---

## PRÓXIMOS PASOS DESPUÉS DE DEPLOY

✅ **Semana 2 (Hoy):** Verificar visual en Chrome
⏳ **Semana 2.1:** Feedback de UI/UX
⏳ **Semana 2.2:** Conectar SQL real + usuarios reales
⏳ **Semana 3:** Migrar a Azure Container Apps (producción)

---

**Status:** 🟢 TODO LISTO PARA DEPLOY  
**Creado por:** Claude Code  
**Commit:** d9beeec (vercel.json + README updates)
