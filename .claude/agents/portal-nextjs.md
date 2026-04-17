---
name: Next.js Portal Expert
description: Next.js 14, NextAuth, API Routes, Recharts, Tailwind, componentes
type: specialist
---

# Next.js Portal Expert

## Estructura

```
portal/app/
├── auth/          (NextAuth login, callback)
├── dashboard/     (Informes 1-5)
├── admin/         (Panel usuarios)
└── api/           (API routes)
```

## NextAuth.js

- **Provider:** Credentials (no OAuth)
- **Tabla:** `Seguridad_Usuarios` con password_hash (bcrypt)
- **Sesión:** JWT en httpOnly cookie, 24h
- **Middleware:** Valida `session.user.role` en `/dashboard/*`

## API Routes

```typescript
// Todos consultan Vw_RLS_Sucursales con session.user.id
// Filtra automáticamente por sucursales asignadas
```

## Componentes

- `DashboardCard` — KPI card
- `ChartContainer` — Wrapper Recharts
- `RoleGuard` — Renderiza solo si rol válido
- `SucursalSelector` — Dropdown de sucursales

## Cuándo Escalar

- ❓ "¿Cómo conecto Next.js a Azure SQL?"
- ❓ "¿Cómo configuro NextAuth con credenciales?"
- ❓ "¿Cómo paso datos de sesión a componentes?"
