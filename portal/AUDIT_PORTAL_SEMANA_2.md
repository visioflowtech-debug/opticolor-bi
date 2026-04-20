# 🔍 AUDITORÍA PORTAL NEXT.JS — SEMANA 2
**Fecha:** 19 de abril de 2026  
**Auditores:** Portal Next.js Expert, Security Expert, QA Expert  
**Objetivo:** Evaluar si el Portal está listo como base para construcción Semana 2.2

---

## ✅ ESTADO GENERAL: VERDE CON ALERTAS

| Aspecto | Status | % | Notas |
|---------|--------|---|-------|
| **Estructura Base** | ✅ OK | 100% | Next.js 16 + App Router |
| **Autenticación** | ⚠️ CRÍTICO | 50% | Config falta, NextAuth sin DB |
| **Componentes** | ❌ FALTA | 0% | No existen (referencias pero no archivos) |
| **API Endpoints** | ⏳ SKELETON | 70% | Estructura OK, sin SQL real |
| **Tailwind** | ✅ OK | 100% | Paleta Opticolor configurada |
| **TypeScript** | ✅ OK | 90% | Tipos básicos, faltan tipos DB |
| **Seguridad** | ⚠️ CRÍTICO | 40% | Sin RLS, sin validación roles |
| **Testing** | ❌ NO | 0% | Sin tests unitarios |
| **Documentación** | ✅ OK | 85% | Buena, pero desactualizada |

---

## 🏗️ ESTRUCTURA PROYECTO (ACTUAL vs ESPERADO)

### ACTUAL:
```
portal/
├── api/
│   ├── auth/[...nextauth]/route.ts    (refs config/auth — NO EXISTE)
│   └── data/*/route.ts               (5 endpoints mock)
├── auth/
│   ├── login/page.tsx                (✅ OK)
│   └── error/page.tsx                (✅ OK)
├── dashboard/
│   ├── layout.tsx                    (refs Navbar, Sidebar — NO EXISTEN)
│   └── page.tsx                      (refs ResumenComercialDashboard — NO EXISTE)
├── layout.tsx                        (✅ OK - SessionProvider)
├── middleware.ts                     (⏳ Deshabilitado)
├── tailwind.config.ts                (✅ OK - Paleta Opticolor)
├── globals.css                       (✅ OK)
└── package.json                      (✅ OK - deps correctas)
```

### ESPERADO:
```
portal/
├── app/
│   ├── api/
│   ├── auth/
│   ├── dashboard/
│   ├── layout.tsx
│   └── middleware.ts
├── components/                       ❌ FALTA
│   ├── navbar/Navbar.tsx            ❌ FALTA
│   ├── sidebar/Sidebar.tsx          ❌ FALTA
│   ├── dashboard/
│   │   ├── ResumenComercialDashboard.tsx  ❌ FALTA
│   │   └── ... (4 más para otros informes)
│   └── ...
├── config/                           ❌ FALTA
│   └── auth.ts                      ❌ FALTA (crítico)
├── lib/
│   ├── db.ts                        ❌ FALTA (mssql pool)
│   └── types.ts                     ❌ FALTA (TypeScript interfaces)
└── ...
```

---

## 🔴 PROBLEMAS CRÍTICOS (BLOQUEAN COMPILACIÓN)

### 1. **FALTA: `config/auth.ts`** (NextAuth configuración)
- **Línea:** `api/auth/[...nextauth]/route.ts` línea 1: `import { handlers } from "@/config/auth"`
- **Impacto:** Compilación falla, login no funciona
- **Requerido para:** NextAuth handlers (GET, POST)
- **Debe incluir:**
  ```typescript
  import NextAuth from "next-auth";
  import Credentials from "next-auth/providers/credentials";
  
  export const { handlers, auth } = NextAuth({
    providers: [
      Credentials({
        credentials: { email: {}, password: {} },
        authorize: async (credentials) => {
          // Query BD contra Seguridad_Usuarios
          // Validar password PBKDF2
          // Retornar usuario + roles
        }
      })
    ],
    callbacks: {
      jwt: ({ token, user }) => { /* Agregar roles */ },
      session: ({ session, token }) => { /* Inyectar roles */ }
    }
  });
  ```

### 2. **FALTA: `lib/db.ts`** (Azure SQL pool)
- **Línea:** `api/data/*/route.ts` línea 2: `import { auth } from '@/config/auth'`
- **Impacto:** No hay conexión a BD, API endpoints vacíos
- **Requerido para:** Ejecutar queries SQL contra `db-opticolor-dw`
- **Debe incluir:**
  ```typescript
  import { ConnectionPool } from 'mssql';
  
  const pool = new ConnectionPool({
    server: process.env.SQL_SERVER,
    database: process.env.SQL_DATABASE,
    authentication: { type: 'default', options: { userName: process.env.SQL_USER, password: process.env.SQL_PASSWORD } },
    options: { encrypt: true, trustServerCertificate: true }
  });
  
  export async function query<T>(sql: string, params?: any): Promise<T[]> {
    const request = pool.request();
    if (params) Object.entries(params).forEach(([k, v]) => request.input(k, v));
    return request.query(sql);
  }
  ```

### 3. **FALTA: `lib/types.ts`** (TypeScript interfaces)
- **Línea:** Múltiples archivos importan de `@/lib/types`
- **Impacto:** TypeScript compilation error
- **Requerido para:** Tipado fuerte de datos
- **Debe incluir:**
  ```typescript
  export interface ResumenComercialRow {
    fecha: string;
    venta_total: number;
    cobrado: number;
    ticket_promedio: number;
    run_rate: number;
    otif: number;
  }
  
  export interface ApiResponse<T> {
    success: boolean;
    data?: T;
    error?: string;
    message?: string;
  }
  
  export interface User {
    id_usuario: number;
    email: string;
    nombre_completo: string;
    id_rol: number;
    nombre_rol: string;
    nivel_jerarquico: number;
    sucursales: number[];
  }
  ```

### 4. **FALTA: `components/navbar/Navbar.tsx`**
- **Línea:** `dashboard/layout.tsx` línea 1: `import Navbar from '@/components/navbar/Navbar'`
- **Impacto:** Dashboard no renderiza
- **Requerido para:** Topbar con logo, usuario, logout

### 5. **FALTA: `components/sidebar/Sidebar.tsx`**
- **Línea:** `dashboard/layout.tsx` línea 2: `import Sidebar from '@/components/sidebar/Sidebar'`
- **Impacto:** Dashboard no renderiza
- **Requerido para:** Menú lateral con 5 dashboard links

### 6. **FALTA: `components/dashboard/ResumenComercialDashboard.tsx`**
- **Línea:** `dashboard/page.tsx` línea 2
- **Impacto:** Dashboard principal no renderiza
- **Requerido para:** Gráficos Recharts (Resumen Comercial)

---

## ⚠️ PROBLEMAS SECUNDARIOS (FUNCIONALIDAD)

### 7. **Autenticación sin validación BD**
- **Estado:** Login form existe, pero NextAuth no consulta `Seguridad_Usuarios`
- **Riesgo:** Cualquiera puede ingresar (si default credentials)
- **Fix requerido:** Implementar `authorize` callback en NextAuth contra BD

### 8. **Sin RLS (Row-Level Security)**
- **Estado:** Endpoints no aplican filtro `Vw_RLS_Sucursales`
- **Riesgo:** Usuario puede ver datos de todas las sucursales
- **Fix requerido:** Agregar WHERE con `id_sucursal IN (SELECT... FROM Vw_RLS_Sucursales WHERE email = @email)`

### 9. **Sin validación de roles (RBAC)**
- **Estado:** Endpoints no validan permisos del usuario
- **Riesgo:** CONSULTOR puede acceder datos de ADMIN
- **Fix requerido:** Validar `session.user.nombre_rol` contra `Seguridad_Permisos`

### 10. **Middleware deshabilitado**
- **Estado:** `middleware.ts` retorna `NextResponse.next()` sin validaciones
- **Riesgo:** Rutas `/dashboard/*` accesibles sin sesión válida
- **Fix requerido:** Implementar protección de rutas (opcional si NextAuth session en layout)

### 11. **Sin manejo de tipos dinámicos**
- **Estado:** Endpoints retornan `any` o tipos genéricos
- **Riesgo:** TypeScript no valida estructura de respuestas
- **Fix requerido:** Crear tipos específicos por endpoint (DIM_*)

### 12. **Sin error handling robusto**
- **Estado:** Catch-all genérico en endpoints
- **Riesgo:** No diferencia errores (SQL, auth, validación)
- **Fix requerido:** Error handling granular por tipo

---

## ✅ LO QUE SÍ ESTÁ BIEN

### Package.json
- ✅ Dependencias correctas (next 16, nextauth 5-beta, recharts, tailwind 4)
- ✅ Scripts: dev, build, start
- ✅ Versiones pinned (seguridad)

### Login Page (`auth/login/page.tsx`)
- ✅ UI limpia y responsive
- ✅ Usa Next.js `signIn()` de NextAuth
- ✅ Validación básica (email required, password required)
- ✅ Error handling (muestra mensajes)
- ✅ Paleta Opticolor aplicada (#1A3A6B primario)
- ✅ Loading state en botón

### Tailwind Config
- ✅ Paleta Opticolor correcta (Primary #1A3A6B, Secondary #2B6CB0, Accent #D4A017)
- ✅ Extensiones bien configuradas
- ✅ Content paths incluyen app, components, lib

### Layout Root
- ✅ Metadata correcta (título, descripción)
- ✅ SessionProvider envuelve app
- ✅ HTML/body estructura estándar

### API Response Types
- ✅ Estructura base correcta (success, data, error)
- ✅ HTTP status codes apropiados (401, 500)
- ✅ Logs en consola para debugging

---

## 🔒 AUDITORÍA SEGURIDAD

### CRÍTICOS:
- ❌ **Sin autenticación real:** Login valida contra BD pero no hay BD config
- ❌ **Sin RLS:** Endpoints no filtran por sucursal del usuario
- ❌ **Sin RBAC:** Endpoints no validan permisos (VER_INFORME_1, etc.)
- ❌ **Sin validación entrada:** Email/password sin sanitizar (aunque Next.js ayuda)
- ❌ **JWT sin secreto:** NEXTAUTH_SECRET no configurado (.env.local)
- ❌ **Sin CORS:** Si API en otro origen, falta configuración

### BUENOS:
- ✅ Password en input type="password"
- ✅ httpOnly cookies en NextAuth (por defecto)
- ✅ HTTPS en producción (recomendación)
- ✅ No hay secretos en código (usan .env)

**Score Seguridad:** 3/10 (estructura OK, implementación incompleta)

---

## 🧪 AUDITORÍA QA

### Testing:
- ❌ Sin tests unitarios (Jest/Vitest)
- ❌ Sin tests e2e (Playwright/Cypress)
- ❌ Sin mock data setup

### Cobertura:
- ❌ Login: manualmente, no automático
- ❌ RLS: no testeado (con 3 roles diferentes)
- ❌ RBAC: no testeado
- ⏳ Endpoints: mock data solo, no SQL

### Criterios Aceptación (Semana 2):
- ⏳ Login: usuario puede entrar con credenciales válidas
- ⏳ Dashboard: carga Resumen Comercial en < 3 seg
- ⏳ RLS: SUPERVISOR ve solo su sucursal
- ⏳ RBAC: CONSULTOR NO ve /dashboard/admin
- ⏳ Responsive: funciona en 375px (mobile)

**Score Testing:** 2/10 (no tests, funcionalidad manual)

---

## 🚀 READINESS CHECKLIST

| Item | Status | Priority | FIX Semana 2.2 |
|------|--------|----------|---|
| Componentes creados | ❌ NO | CRÍTICA | 2-3h |
| `config/auth.ts` | ❌ NO | CRÍTICA | 1-2h |
| `lib/db.ts` | ❌ NO | CRÍTICA | 1h |
| `lib/types.ts` | ❌ NO | CRÍTICA | 1-2h |
| Autenticación BD | ⏳ SKELETON | CRÍTICA | 2h |
| RLS en endpoints | ❌ NO | CRÍTICA | 2-3h |
| RBAC validación | ❌ NO | ALTA | 2h |
| Middleware activo | ❌ NO | MEDIA | 1h |
| Tests unitarios | ❌ NO | MEDIA | 4-6h |
| Tests e2e | ❌ NO | BAJA | 6-8h |

---

## 📋 RECOMENDACIÓN FINAL

### ESTÁ LISTO COMO BASE? 
**⚠️ SÍ, PERO CON RESERVAS**

**Pros:**
- ✅ Estructura Next.js correcta (App Router)
- ✅ Autenticación framework listo (NextAuth)
- ✅ UI base funcional (login page)
- ✅ Paleta corporativa aplicada
- ✅ Endpoints skeleton estructurados

**Contras:**
- ❌ 6 componentes falta (bloques compilación)
- ❌ 3 archivos config/lib críticos falta
- ❌ Autenticación sin BD real
- ❌ Sin RLS (seguridad crítica)
- ❌ Sin RBAC (control acceso crítica)
- ❌ Sin tests

### PRÓXIMOS PASOS (SEMANA 2.2 - 4 HORAS):

**MAÑANA (Orden de prioridad):**

1. **CREAR ARCHIVOS CRÍTICOS (1.5h)**
   ```
   config/auth.ts         ← NextAuth + authorize callback BD
   lib/db.ts             ← mssql pool connection
   lib/types.ts          ← Interfaces TypeScript
   ```

2. **CREAR COMPONENTES (1.5h)**
   ```
   components/navbar/Navbar.tsx
   components/sidebar/Sidebar.tsx
   components/dashboard/ResumenComercialDashboard.tsx  ← Recharts
   ```

3. **INTEGRACIÓN AUTENTICACIÓN (1h)**
   - Conectar NextAuth a `Seguridad_Usuarios`
   - Validar PBKDF2 password
   - Cargar roles en JWT

4. **AGREGAR SEGURIDAD (1h)**
   - RLS en endpoints (WHERE id_sucursal IN...)
   - RBAC validación (session.user.nombre_rol)
   - Middleware protección

**Después (Semana 2.3+):**
- Tests unitarios
- Tests e2e
- Performance tuning
- Documentación actualizada

---

## 📁 PLAN IMPLEMENTACIÓN DETALLADO

Ver: `PLAN_IMPLEMENTACION_PORTAL.md` (a crear Semana 2.2)

---

**Estado:** LISTO PARA SEMANA 2.2 (con reservas)  
**Estimado:** 4-6h para completar críticos  
**Bloqueador:** Usuarios reales (Excel Reinaldo) para testear autenticación

Co-Authored-By: Portal Next.js Expert + Security Expert + QA Expert
