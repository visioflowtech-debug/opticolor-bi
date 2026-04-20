# 🎨 Opticolor BI Portal — Next.js Dashboard

**Estado:** Semana 2 — ✅ Deployado en Vercel  
**Cliente:** OPTI-COLOR #2, C.A. — Venezuela  
**Stack:** Next.js 16 + TypeScript + NextAuth.js v5 + Tailwind + shadcn/ui + Recharts
**Fuente de Verdad Base:** https://github.com/arhamkhnz/next-shadcn-admin-dashboard (admin template reference)
**Deploy:** https://opticolor-bi.vercel.app (Vercel — testing visual)

---

## ⭐ FUENTE DE VERDAD

Este Portal se basa en el **admin template de arhamkhnz** como referencia arquitectónica. Los cambios específicos a Opticolor se versionan en nuestro monorepo Git (`opticolor-bi/portal/`).

**NO clonar template en monorepo.** Las decisiones de arquitectura usan ese repo como inspiración, pero toda la implementación es propia.

## 📦 Instalación Rápida

### Requisitos
- Node.js 18.17+ 
- npm 9+

### Pasos

\`\`\`bash
# 1. Clonar/extraer el portal
cd opticolor-bi/portal

# 2. Instalar dependencias (ya hecho, pero por si acaso)
npm install

# 3. Configurar variables de entorno
# Editar .env.local y reemplazar credenciales reales

# 4. Iniciar servidor desarrollo
npm run dev

# 5. Abrir en navegador
open http://localhost:3000
\`\`\`

---

## 🔐 Autenticación

Implementado: NextAuth.js v5 con Credentials provider
Origen: Tabla Seguridad_Usuarios en Azure SQL
JWT con roles + sucursales asignadas

**Semana 2.2:** Cuando llegue lista de usuarios de Reinaldo, cargar en BD.

---

## 📊 Dashboards (5 Informes)

✅ **Resumen Comercial** — Completamente funcional con Recharts
⏳ **Eficiencia de Órdenes** — Esqueleto + mock data
⏳ **Control de Cartera** — Esqueleto + mock data
⏳ **Desempeño Clínico** — Esqueleto + mock data
⏳ **Inventario** — Esqueleto + mock data

---

## 🌐 Deploy en Vercel

**Configuración:**
- Monorepo detectado via `vercel.json`
- Build: `npm run build` 
- Output: `.next`
- Output dir: `portal`

**Testing:**
```bash
# Vercel auto-deploya en cada push a main
# URL: https://opticolor-bi.vercel.app
# Redirige a /dashboard (mock session)
```

---

## 🚀 Próximos Pasos (Semana 2.2)

1. Cargar usuarios reales en BD (datos Opticolor)
2. Conectar APIs a SQL real en Azure
3. Crear vistas SQL (copiar Panamá)
4. Testing por rol y RLS
5. Migrar a Azure Container Apps (producción)

---

## 📝 Contexto Completo

Ver `/docs/` en raíz para documentación iterativa y `/claude.md` para arquitectura del ecosistema completo.
