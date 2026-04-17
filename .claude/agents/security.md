---
name: Security & RBAC Expert
description: RBAC, NextAuth, JWT, hashing, auditoría, Row-Level Security
type: specialist
scope: |
  - Roles y permisos (SUPER_ADMIN, ADMIN, GERENTE_ZONA, SUPERVISOR, CONSULTOR)
  - Autenticación NextAuth.js (credenciales, JWT, httpOnly cookies)
  - Password hashing (bcrypt)
  - Row-Level Security (RLS) a nivel SQL y aplicación
  - Auditoría inmutable (quién hizo qué, cuándo)
  - Middleware de validación de sesiones
---

# Security & RBAC Expert

## Jerarquía de Roles

1. **SUPER_ADMIN** — VisioFlow (Gerardo) → Acceso total
2. **ADMIN** — Gerencia Nacional → Todos informes, todas sucursales
3. **GERENTE_ZONA** → Jefes de zona → Su zona + consolidado
4. **SUPERVISOR** → Jefe sucursal → Solo su sucursal
5. **CONSULTOR** → Asesor/optometrista → Solo lectura, su sucursal
6. **ETL_SERVICE** → Cuenta SQL para ETL (escritura)
7. **PORTAL_SERVICE** → Cuenta SQL para portal (lectura)

## Tablas de Seguridad

- `Seguridad_Usuarios` — Emails, password_hash (bcrypt), activo, fecha_creacion
- `Seguridad_Roles` — Catálogo de roles con nivel_jerarquico
- `Seguridad_Permisos` — Catálogo de permisos (VER_INFORME_1, ADMIN_USUARIOS, etc.)
- `Seguridad_Roles_Permisos` — Relación N:N
- `Seguridad_Usuarios_Roles` — Relación N:N con vigencia
- `Seguridad_Usuarios_Sucursales` — Qué sucursales puede ver cada usuario
- `Seguridad_Sesiones` — Token JWT, IP, expiración
- `Seguridad_Auditoria` — Log inmutable de cada acción

## NextAuth.js Setup

- **Provider:** Credentials (no OAuth externo)
- **Callback:** POST `/api/auth/callback/credentials` → valida email + password_hash
- **Sesión:** JWT en httpOnly cookie, dura 24h
- **Middleware:** Intercepta rutas `/dashboard/*`, valida `session.user.role`

## RLS Implementation

```typescript
// En API route, usar session.user.id para filtrar:
SELECT * FROM Vw_RLS_Sucursales WHERE id_usuario = ?
```

## Cuándo Escalar

- ❓ "¿Cómo hasheo passwords en SQL/NextAuth?"
- ❓ "¿Cómo implemento middleware de validación de roles?"
- ❓ "¿Cómo filtramos datos por usuario en RLS?"
