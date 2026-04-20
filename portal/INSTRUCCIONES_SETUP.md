# 🎯 OPTICOLOR BI PORTAL — Setup en Tu Laptop

**Autor:** Gerardo Argueta — VisioFlow  
**Fecha:** 20 abril 2026  
**Versión:** 0.1.0-alpha (Semana 2)  
**Stack:** Next.js 16.2.4 + TypeScript + NextAuth.js v5 + Azure SQL + Tailwind + Recharts

---

## 📦 PASO 1: EXTRAE EL ZIP

```bash
# Descarga opticolor-portal-semana2.zip
unzip opticolor-portal-semana2.zip
cd opticolor-portal
```

---

## 🔧 PASO 2: INSTALA DEPENDENCIAS

```bash
npm install
```

**Tiempo estimado:** 2-3 minutos (si npm cache está limpio)

Si hay errores, ejecuta:
```bash
rm -rf node_modules package-lock.json
npm install
```

---

## 🔐 PASO 3: CONFIGURA VARIABLES DE ENTORNO

### 3.1 Genera NEXTAUTH_SECRET

```bash
openssl rand -hex 32
```

Copia el output (ej: `a3f8c2d...`)

### 3.2 Edita `.env.local`

```bash
# En la raíz del proyecto, abre .env.local:

NEXTAUTH_SECRET=<pega_aquí_el_valor_de_arriba>
NEXTAUTH_URL=http://localhost:3000

AZURE_SQL_SERVER=srv-opticolor.database.windows.net
AZURE_SQL_DATABASE=db-opticolor-dw
AZURE_SQL_USER=admin_opticolor
AZURE_SQL_PASSWORD=<pide_la_password_a_Reinaldo>
AZURE_SQL_PORT=1433

NEXT_PUBLIC_API_BASE_URL=http://localhost:3000
```

**⚠️ Importante:**
- **NUNCA** commits `.env.local` a Git
- Las credenciales son sensibles
- Para testing local, `AZURE_SQL_PASSWORD` debe ser real

---

## 🚀 PASO 4: INICIA SERVIDOR DESARROLLO

```bash
npm run dev
```

**Output esperado:**
```
▲ Next.js 16.2.4
- Environments: .env.local

> Ready in 2.5s
> Local: http://localhost:3000
```

---

## 🌐 PASO 5: ABRE EN NAVEGADOR

```bash
open http://localhost:3000
```

**¿Qué verás?**
- Redirect automático a `/auth/login`
- Página de login con logo Opticolor + form email/password

---

## 🔑 CREDENCIALES PARA TESTING

**Estado Actual (Semana 2):**
- ❌ Mock data: **NO hay usuarios precargados**
- ⏳ Esperando: Lista de Reinaldo (Excel con usuarios reales)

**Para testear ahora:**

Necesitas insertar usuario en BD manualmente:

```sql
-- En Azure SQL (ejecutar en Azure Data Studio)

INSERT INTO [dbo].[Seguridad_Usuarios] 
  (email, nombre_completo, password_hash, esta_activo)
VALUES 
  ('test@opticolor.com', 'Test User', 'tu_hash_pbkdf2', 1)

INSERT INTO [dbo].[Seguridad_Usuarios_Roles]
  (id_usuario, id_rol, esta_vigente)
VALUES
  (1, 1, 1)  -- id_rol=1 es SUPER_ADMIN
```

**¿Cómo generar hash PBKDF2?** (Semana 2.2 te doy script Python)

---

## 📊 RUTAS DISPONIBLES

### Autenticación
- `GET /auth/login` — Página de login
- `GET /auth/error?error=...` — Error auth
- `POST /api/auth/signin` — NextAuth signin (interno)

### Dashboards (requieren sesión)
- `GET /dashboard` — **Resumen Comercial** ✅ (con gráficos Recharts)
- `GET /dashboard/eficiencia-ordenes` — Esqueleto
- `GET /dashboard/control-cartera` — Esqueleto
- `GET /dashboard/desempenio-clinico` — Esqueleto
- `GET /dashboard/inventario` — Esqueleto

### APIs Data (requieren sesión)
- `GET /api/data/resumen-comercial` — Mock data
- `GET /api/data/eficiencia-ordenes` — Mock data
- `GET /api/data/control-cartera` — Mock data
- `GET /api/data/desempenio-clinico` — Mock data
- `GET /api/data/inventario` — Mock data

---

## 🧪 TESTING RÁPIDO

### 1. Verificar que arranca sin errores

```bash
npm run dev
# Espera "Ready in X.Xs"
# Ctrl+C para detener
```

### 2. Verificar build production

```bash
npm run build
npm start
```

### 3. Verificar tipos TypeScript

```bash
npx tsc --noEmit
```

---

## 📁 ESTRUCTURA PROYECTO

```
opticolor-portal/
├── app/
│   ├── api/
│   │   ├── auth/[...nextauth]/route.ts      ← NextAuth
│   │   └── data/                            ← 5 endpoints
│   ├── auth/
│   │   ├── login/page.tsx                   ← Login form
│   │   └── error/page.tsx                   ← Error page
│   ├── dashboard/
│   │   ├── layout.tsx                       ← Navbar + Sidebar
│   │   ├── page.tsx                         ← Resumen Comercial
│   │   ├── eficiencia-ordenes/page.tsx
│   │   ├── control-cartera/page.tsx
│   │   ├── desempenio-clinico/page.tsx
│   │   └── inventario/page.tsx
│   ├── layout.tsx                           ← Root layout
│   ├── page.tsx                             ← Redirect /dashboard
│   └── globals.css
├── components/
│   ├── navbar/Navbar.tsx
│   ├── sidebar/Sidebar.tsx
│   └── dashboard/ResumenComercialDashboard.tsx
├── config/
│   └── auth.ts                              ← NextAuth config
├── lib/
│   ├── db.ts                                ← Azure SQL pool
│   └── types.ts                             ← TypeScript interfaces
├── middleware.ts                            ← Protección rutas
├── .env.local                               ← Credenciales (NO commitear)
├── .env.example                             ← Template
├── tailwind.config.ts                       ← Paleta Opticolor
├── tsconfig.json
├── package.json
├── next.config.ts
└── README.md
```

---

## 🎨 PALETA DE COLORES

```css
Primary:    #1A3A6B  (Azul corporativo)
Secondary:  #2B6CB0  (Azul medio)
Accent:     #D4A017  (Dorado)
Foreground: #2D3748  (Gris oscuro)
Background: #FFFFFF  (Blanco)
```

Disponible en 50-900 en `tailwind.config.ts`.

---

## 🐛 TROUBLESHOOTING

### Error: "Cannot find module 'mssql'"
```bash
npm install mssql --save
```

### Error: "AZURE_SQL_PASSWORD is not defined"
```bash
# Verifica .env.local tiene valor real (no vacío)
cat .env.local | grep AZURE_SQL_PASSWORD
```

### Error: "NextAuth secret required"
```bash
# Genera con:
openssl rand -hex 32
# Copia a NEXTAUTH_SECRET en .env.local
```

### Error: "Cannot connect to Azure SQL"
- ✅ Verifica credenciales en .env.local
- ✅ Verifica firewall Azure SQL (Allow Azure services = ON)
- ✅ Verifica BD existe: `db-opticolor-dw`
- ✅ Test manual:
  ```bash
  node -e "
    const sql = require('mssql');
    const config = {
      server: 'srv-opticolor.database.windows.net',
      database: 'db-opticolor-dw',
      authentication: { type: 'default', options: { 
        userName: 'admin_opticolor', password: process.env.AZURE_SQL_PASSWORD 
      }},
      options: { encrypt: true, trustServerCertificate: false }
    };
    new sql.ConnectionPool(config).connect().then(() => console.log('✅ OK')).catch(e => console.error('❌', e));
  "
  ```

### Login no funciona (usuarios no existen)
- Esperando datos de Reinaldo
- Semana 2.2: ejecuta SQL para cargar usuarios

### Gráficos no se ven
- Verifica `/api/data/resumen-comercial` devuelve mock data
- Abre DevTools → Network → revisa response
- Recharts está instalado: `npm list recharts`

---

## 📝 PRÓXIMOS PASOS (Semana 2.2)

Cuando Reinaldo envíe lista de usuarios:

### 1. Cargar usuarios en BD
```sql
INSERT INTO [dbo].[Seguridad_Usuarios] (email, nombre_completo, password_hash, esta_activo)
VALUES (...)
```

### 2. Reemplazar mock data con queries SQL reales
- Editar `/app/api/data/*.ts`
- Descomentar queries SQL
- Aplicar RLS con `Vw_RLS_Sucursales`

### 3. Crear vistas SQL (Dim_*, Fact_*)
- Copiar de Optilux Panamá
- Adaptar a estructura Venezuela

### 4. Testing end-to-end
- Login con cada rol
- Verificar RLS funciona
- Validar gráficos

### 5. Deploy a Azure Container Apps
```bash
npm run build
docker build -t opticolor-portal .
# Push a ACR y deploy en app-portal-opticolor-prd
```

---

## 🆘 SOPORTE

| Problema | Contacto |
|----------|----------|
| Código/Bugs | gerardo@visioflow.tech |
| Credenciales Azure | reinaldo@grupoopticolor.com |
| Data/BD | emartinez@grupoopticolor.com |

---

**Última actualización:** 20 abril 2026, 03:15 UTC-5  
**Status:** ✅ Build exitoso — Listo para `npm run dev`
