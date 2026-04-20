# 🎨 Opticolor BI Portal — Next.js 16 + shadcn/ui

**Estado:** Semana 2 — ✅ Fresh clone template arhamkhnz + Lógica Opticolor integrada  
**Cliente:** OPTI-COLOR #2, C.A. — Venezuela  
**Stack:** Next.js 16 + React 19 + TypeScript + shadcn/ui (55 componentes) + Tailwind v4 + NextAuth v5  
**Deploy:** https://opticolor-bi.vercel.app  

---

## 🚀 Características Actuales

✅ **Sidebar colapsable** — Desktop y mobile responsive  
✅ **Dark/Light mode** — 3 presets de tema (Tangerine, Neo Brutalism, Soft Pop)  
✅ **55 componentes shadcn/ui** — Card, Table, Button, Badge, Chart, etc.  
✅ **5 Informes Opticolor** — Rutas generadas, páginas placeholder  
✅ **API Routes** — 5 endpoints con mock data (`/api/data/*`)  
✅ **NextAuth v5 config** — Estructura lista para integración  
✅ **TypeScript types** — Interfaces de dominio definidas  
✅ **Build exitoso** — Sin errores TypeScript  

---

## 📁 Estructura de Carpetas

```
portal/
├── src/
│   ├── app/
│   │   ├── (main)/           # Layout principal con sidebar
│   │   │   ├── dashboard/
│   │   │   │   ├── resumen-comercial/
│   │   │   │   ├── eficiencia-ordenes/
│   │   │   │   ├── control-cartera/
│   │   │   │   ├── desempenio-clinico/
│   │   │   │   └── inventario/
│   │   │   ├── auth/         # Autenticación (v1, v2)
│   │   │   └── api/          # Rutas API
│   │   ├── (external)/       # Layout sin sidebar
│   │   └── globals.css
│   ├── components/
│   │   ├── admin-panel/      # Sidebar, navbar, layout
│   │   └── ui/               # 55 componentes shadcn
│   ├── config/
│   │   └── auth.ts           # NextAuth config (skeleton)
│   ├── lib/
│   │   ├── types.ts          # Interfaces Opticolor
│   │   └── utils.ts
│   ├── navigation/
│   │   └── sidebar-items.ts  # Menu de navegación (Informes + Admin)
│   ├── stores/
│   │   └── preferences/      # Zustand (tema, sidebar, etc)
│   └── styles/
│       └── presets/          # Temas personalizados
├── .env.local                # Desarrollo
├── .env.production           # Producción (Vercel)
├── components.json           # shadcn config
├── package.json
├── tsconfig.json
└── README.md (este archivo)
```

---

## 📊 Los 5 Informes

| Informe | URL | Estado |
|---------|-----|--------|
| **Resumen Comercial** | `/dashboard/resumen-comercial` | 🔧 Placeholder |
| **Eficiencia de Órdenes** | `/dashboard/eficiencia-ordenes` | 🔧 Placeholder |
| **Control de Cartera** | `/dashboard/control-cartera` | 🔧 Placeholder |
| **Desempeño Clínico** | `/dashboard/desempenio-clinico` | 🔧 Placeholder |
| **Inventario** | `/dashboard/inventario` | 🔧 Placeholder |

**Próximos pasos (Semana 2.2):**
- Conectar a SQL real (Fact_Ventas, Fact_Ordenes, etc.)
- Implementar componentes de visualización (Recharts, TanStack Table)
- Aplicar Row-Level Security (RLS) por usuario/sucursal

---

## 🔐 Autenticación

**Implementación actual:** NextAuth v5 skeleton con mock credentials  
**Usuário test:** `test@opticolor.com` (sin password requerido)  

**Semana 2.2:**
- Integración con tabla `Seguridad_Usuarios` en Azure SQL
- JWT con roles + sucursales asignadas
- RLS automático en queries

---

## 🌐 Desarrollo Local

```bash
# Instalar dependencias
npm install

# Iniciar servidor (dev)
npm run dev

# Acceder a
open http://localhost:3000

# Build para producción
npm run build

# Test build localmente
npm run start
```

---

## 🔌 Variables de Entorno

**Desarrollo (.env.local):**
```env
NEXTAUTH_SECRET=tu-secret-aqui
NEXTAUTH_URL=http://localhost:3000
AZURE_SQL_SERVER=srv-opticolor.database.windows.net
AZURE_SQL_DATABASE=db-opticolor-dw
AZURE_SQL_USER=admin_opticolor
AZURE_SQL_PASSWORD=tu-password
```

**Producción (.env.production):**
```env
NEXTAUTH_URL=https://opticolor-bi.vercel.app
NEXTAUTH_SECRET=opticolor-bi-secret-prod-2026-semana2
# Resto se configura en Vercel Dashboard
```

---

## 🚀 Deploy en Vercel

**URL:** https://opticolor-bi.vercel.app  
**Auto-deploy:** Cada push a `main`  

**Configuración Vercel:**
- Framework: Next.js
- Build: `npm run build`
- Output: `.next`
- Environment Variables: `NEXTAUTH_SECRET`, `NEXTAUTH_URL`

---

## 📝 Fuentes de Verdad

- **claude.md** — Contexto arquitectónico completo
- **PROYECTO OPTICOLOR.pdf** — Tracker de tareas por semana
- **Optilux panama DB v2.0** — Referencia vistas SQL (Dim_*, Fact_*)
- **GitHub** — Código fuente (rama `main`)

---

## ✅ Checklist Semana 2

- ✅ Fresh clone template arhamkhnz
- ✅ Integración lógica Opticolor (types, auth, API routes)
- ✅ Adaptación navegación (5 informes)
- ✅ Páginas placeholder dashboard
- ✅ Build sin errores
- ⏳ **Deploy Vercel** (siguiente: push + configurar env vars)
- ⏳ Feedback visual de usuario
- ⏳ Semana 2.2: SQL real + RLS

---

## 🔗 Enlaces Útiles

- [Next.js 16 Docs](https://nextjs.org)
- [shadcn/ui Components](https://ui.shadcn.com)
- [Vercel Deployments](https://vercel.com/dashboard)
- [GitHub Repo](https://github.com/visioflowtech-debug/opticolor-bi)

---

**Última actualización:** 19 de abril de 2026 — Fresh Clone + Rutas Opticolor  
**Siguiente sesión:** Deploy Vercel + feedback UI/UX
