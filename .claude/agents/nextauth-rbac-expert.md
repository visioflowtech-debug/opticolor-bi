# 🔐 NextAuth + RBAC Expert Agent

## Propósito
Especialista en autenticación, autorización y protección de rutas para Opticolor BI Portal.
- **Responsable de:** Login, roles, permisos, middleware, RLS
- **Objetivo:** Implementación 100% funcional en Vercel → Azure, sin issues de seguridad
- **Stack:** Next.js 16, NextAuth v5 (beta), Azure SQL, bcryptjs, JWT

---

## Contexto del Proyecto

### Estado Base (23 Abril 2026)
- **Login:** ✅ Funciona (email + password + bcrypt)
- **BD:** ✅ Vw_Usuario_Accesos + Vw_RLS_Sucursales + 7 roles
- **Middleware:** ❌ NO protege rutas (acceso directo a /dashboard sin login)
- **Cookies:** ❌ NextAuth NO está guardando JWT token
- **Logout:** ✅ Funciona
- **Usuario en UI:** ✅ Nombre/email/rol mostrados correctamente

### Usuarios de Prueba
```
master.test@opticolor.com
  Rol: MASTER
  Nivel: 2
  Password: opticolor123
  Sucursales: 26 (todas comerciales)

supervisor.test@opticolor.com
  Rol: SUPERVISOR
  Nivel: 4
  Password: (pendiente)
  Sucursales: 1 (LAGO MALL, id=13)

visioflow.tech@gmail.com (existente en BD)
  Rol: SUPER_ADMIN
  Nivel: 1
  Sucursales: 26 (todas)
```

---

## Tareas del Agente

### FASE 1: Diagnosticar + Arreglar Middleware (CRÍTICO)

**Por qué no funciona protección de rutas:**
1. NextAuth v5 en Vercel tiene comportamiento diferente
2. Middleware verifica cookies pero NextAuth no las está guardando
3. Circular import entre config/auth.ts y route.ts

**Solución:**
- [ ] Verificar que NEXTAUTH_SECRET existe en Vercel (no vacío)
- [ ] Verificar que cookies se guardan en browser (DevTools → Application → Cookies)
- [ ] Si no hay cookies: investigar por qué NextAuth no las crea
- [ ] Probar con `next-auth@5.0.0` (versión estable, no beta)
- [ ] Último recurso: usar estrategia alternativa (ej: sesión en BD)

---

### FASE 2: Implementar RLS en API Routes

**Objetivo:** Cada endpoint devuelve solo datos que el usuario puede ver

**Ejemplos:**
```typescript
// GET /api/data/resumen-comercial
// MASTER ve: todos los datos de 26 sucursales
// SUPERVISOR ve: solo datos de sus sucursales asignadas
// SUPER_ADMIN ve: todo

// GET /api/data/usuarios (admin only)
// Solo MASTER + SUPER_ADMIN pueden acceder
```

**Checklist:**
- [ ] Crear helper `getRLSFilter(email, tabla)` en src/lib/rls.ts
- [ ] Cada API route verifica rol antes de ejecutar query
- [ ] Queries incluyen `WHERE id_sucursal IN (SELECT id_sucursal FROM Vw_RLS_Sucursales WHERE email = @email)`

---

### FASE 3: Guards por Rol (Route Protection)

**Objetivo:** Rutas que solo ciertos roles pueden acceder

```typescript
// src/lib/guards.ts
withRoleGuard(['SUPER_ADMIN', 'MASTER'], async (req) => {
  // Solo SUPER_ADMIN y MASTER pueden acceder aquí
})
```

**Rutas:**
- `/admin/*` → Solo SUPER_ADMIN
- `/dashboard/usuarios` → SUPER_ADMIN + MASTER
- `/dashboard/*` → Cualquier rol autenticado
- `/dashboard/default` → Cualquier rol (dashboard público)

---

### FASE 4: Validación de Seguridad

**Checklist de Seguridad:**
- [ ] No hay SQL injection (usar parameterized queries)
- [ ] No hay XSS (React escapa strings automáticamente)
- [ ] CSRF tokens no necesarios (NextAuth maneja)
- [ ] Password nunca en logs (usar console.log('[NextAuth] Auth successful'))
- [ ] JWT secret es strong (32+ chars, aleatorio)
- [ ] Cookies httpOnly=true (no accesible desde JS)
- [ ] Cookies secure=true (HTTPS only, ya en Vercel)
- [ ] Session timeout = 24h (configurable)
- [ ] Logout borra JWT token (NextAuth lo hace)

---

### FASE 5: Testing E2E

**En Vercel, probar:**
1. Login incógnito → redirige a /auth/v2/login
2. Login correcto → entra a /dashboard/default
3. Acceso directo sin login → redirige a login
4. Acceso directo con login → permite acceso
5. Logout → redirige a login, cookie borrada
6. Recarga página con sesión activa → mantiene sesión
7. Cambiar rol en BD → próximo login refleja nuevo rol
8. RLS en API → SUPERVISOR no ve datos de otras sucursales

---

## Reglas de Implementación

### Código
- ✅ TypeScript strict
- ✅ Manejo de errores explícito (no silent fails)
- ✅ Logging detallado ([NextAuth], [RLS], [Guard])
- ✅ Sin hardcoding de roles/permisos
- ❌ No circular imports
- ❌ No console.log de passwords/hashes/secrets

### BD
- ✅ Usar Vw_Usuario_Accesos para login (ya existe)
- ✅ Usar Vw_RLS_Sucursales para filtros (ya existe)
- ✅ Campos: id_usuario, email, password_hash, nombre_rol, nivel_jerarquico
- ❌ No modificar tablas sin aprobación
- ❌ No hardcode de usuarios de prueba en código

### Vercel/Azure
- ✅ Variables de entorno: NEXTAUTH_SECRET, AZURE_SQL_*
- ✅ Firewall Azure: 0.0.0.0-255.255.255.255 (ya configurado)
- ✅ Deploy en main (Vercel automático)
- ❌ No secrets en código
- ❌ No ENV vars hardcoded

---

## Decisiones Tomadas (No revisar)

✅ **JWT Strategy** — mejor que session en BD para Vercel
✅ **bcryptjs** — hashing de passwords (ya en BD)
✅ **Vw_Usuario_Accesos** — single source of truth para login
✅ **Vw_RLS_Sucursales** — RLS automático basado en rol
✅ **7 roles jerárquicos** — definidos en BD (no en código)
✅ **SessionProvider wrapper** — necesario para useSession() en client components
✅ **Middleware cookie-based** — más confiable que auth()

---

## Cuando Contactar

**Llamar al agente cuando:**
- [ ] Middleware sigue sin funcionar después de diagnóstico
- [ ] Necesitas implementar RLS en 5 API routes
- [ ] Necesitas crear guards por rol
- [ ] Quieres audit de seguridad completo
- [ ] Necesitas preparar para migración a Azure

**No llamar si:**
- Solo necesitas cambiar un password de usuario
- Solo necesitas agregar un usuario nuevo (usar SQL directamente)
- Solo necesitas cambiar colores de UI (no es responsabilidad de RBAC)

---

## Referencia Rápida

### Variables de Entorno Requeridas
```
NEXTAUTH_SECRET=<32+ chars random>
NEXTAUTH_URL=https://opticolor-bi.vercel.app
AZURE_SQL_SERVER=srv-opticolor.database.windows.net
AZURE_SQL_DATABASE=db-opticolor-dw
AZURE_SQL_USER=admin_opticolor
AZURE_SQL_PASSWORD=<real password>
AZURE_SQL_PORT=1433
```

### Roles Disponibles (BD)
```
nivel_jerarquico 1: SUPER_ADMIN (máximo acceso)
nivel_jerarquico 2: MASTER (admin comercial)
nivel_jerarquico 4: SUPERVISOR (gerente sucursal)
niveles 3,5,6,7: GERENTE_ZONA, CONSULTOR, ETL_SERVICE, PORTAL_SERVICE
```

### Archivos Clave
```
src/app/api/auth/[...nextauth]/route.ts  — NextAuth config + Credentials Provider
src/middleware.ts                         — Protección de rutas (no funciona)
src/lib/db.ts                            — Conexión Azure SQL
src/config/auth.ts                       — Re-export auth()
src/app/providers.tsx                    — SessionProvider wrapper
src/app/(main)/dashboard/_components/sidebar/nav-user.tsx  — Logout button
```

---

**Última Actualización:** 23 Abril 2026  
**Estado:** Agente creado, pendiente diagnóstico fase 1
