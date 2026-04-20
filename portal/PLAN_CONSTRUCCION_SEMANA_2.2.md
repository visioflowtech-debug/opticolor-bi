# 🔨 PLAN CONSTRUCCIÓN PORTAL — SEMANA 2.2
**Responsable:** Claude Code (Controlador Portal)  
**Entrada:** Excel Reinaldo (usuarios) + Datos Opticolor  
**Salida:** Portal compilable y funcional con autenticación real  
**Timing:** 4-6 horas de trabajo

---

## FASE 1: CREAR ARCHIVOS CRÍTICOS (1.5 horas)

### 1.1 `lib/types.ts` — Interfaces TypeScript
**Tiempo:** 30min  
**Archivos a actualizar:** Múltiples (imports)

```typescript
// lib/types.ts
export interface ResumenComercialRow {
  fecha: string;
  venta_total: number;
  cobrado: number;
  ticket_promedio: number;
  run_rate: number;
  otif: number;
}

export interface EficienciaOrdenesRow {
  fecha: string;
  ordenes_total: number;
  ordenes_proceso: number;
  dias_promedio_entrega: number;
  cumplimiento_fecha: number;
}

export interface ControlCarteraRow {
  fecha: string;
  facturado: number;
  recaudado: number;
  saldo: number;
  dias_cartera: number;
}

export interface DesempenioClinicoRow {
  fecha: string;
  total_examenes: number;
  pacientes_con_compra: number;
  tasa_conversion: number;
  venta_promedio_paciente: number;
}

export interface InventarioRow {
  nombre_producto: string;
  stock_actual: number;
  stock_minimo: number;
  rotacion_dias: number;
  capital_invertido: number;
}

export interface ApiResponse<T = any> {
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
  permisos: string[];
}

export interface JWTPayload {
  sub: string; // id_usuario
  email: string;
  nombre_completo: string;
  id_rol: number;
  nombre_rol: string;
  nivel_jerarquico: number;
  sucursales: number[];
  iat: number;
  exp: number;
}
```

### 1.2 `lib/db.ts` — Azure SQL Pool Connection
**Tiempo:** 30min  
**Archivos a crear:** lib/db.ts (nuevo)

```typescript
// lib/db.ts
import { ConnectionPool, Request, config } from 'mssql';

const sqlConfig = {
  server: process.env.SQL_SERVER!,
  database: process.env.SQL_DATABASE!,
  authentication: {
    type: 'default' as const,
    options: {
      userName: process.env.SQL_USER!,
      password: process.env.SQL_PASSWORD!,
    },
  },
  options: {
    encrypt: true,
    trustServerCertificate: true,
    connectionTimeout: 30000,
    requestTimeout: 30000,
  },
};

let pool: ConnectionPool | null = null;

export async function getPool(): Promise<ConnectionPool> {
  if (!pool) {
    pool = new ConnectionPool(sqlConfig);
    await pool.connect();
    console.log('[DB] Connected to Azure SQL');
  }
  return pool;
}

export async function query<T>(
  sql: string,
  params?: Record<string, any>
): Promise<T[]> {
  const p = await getPool();
  const request = p.request();

  if (params) {
    Object.entries(params).forEach(([key, value]) => {
      request.input(key, value);
    });
  }

  const result = await request.query(sql);
  return result.recordset as T[];
}

export async function queryOne<T>(
  sql: string,
  params?: Record<string, any>
): Promise<T | null> {
  const results = await query<T>(sql, params);
  return results.length > 0 ? results[0] : null;
}

export async function close(): Promise<void> {
  if (pool) {
    await pool.close();
    pool = null;
    console.log('[DB] Connection closed');
  }
}
```

### 1.3 `config/auth.ts` — NextAuth Configuration
**Tiempo:** 30min  
**Archivos a crear:** config/auth.ts (nuevo)

```typescript
// config/auth.ts
import NextAuth from 'next-auth';
import Credentials from 'next-auth/providers/credentials';
import { query, queryOne } from '@/lib/db';
import { User, JWTPayload } from '@/lib/types';
import crypto from 'crypto';

// PBKDF2 verify (mismo algoritmo que BD)
function verifyPassword(password: string, hash: string): boolean {
  const [salt, storedHash] = hash.split(':');
  const computed = crypto
    .pbkdf2Sync(password, Buffer.from(salt, 'base64'), 100000, 64, 'sha256')
    .toString('base64');
  return computed === storedHash;
}

export const { handlers, auth, signIn, signOut } = NextAuth({
  providers: [
    Credentials({
      name: 'Credentials',
      credentials: {
        email: { label: 'Email', type: 'email' },
        password: { label: 'Password', type: 'password' },
      },
      async authorize(credentials) {
        if (!credentials?.email || !credentials?.password) {
          throw new Error('Email y contraseña requeridos');
        }

        try {
          // Buscar usuario en BD
          const user = await queryOne<any>(
            `SELECT id_usuario, email, nombre_completo, password_hash, esta_activo
             FROM [dbo].[Seguridad_Usuarios]
             WHERE email = @email`,
            { email: credentials.email as string }
          );

          if (!user) {
            throw new Error('Usuario no encontrado');
          }

          if (!user.esta_activo) {
            throw new Error('Usuario inactivo');
          }

          // Verificar password
          if (!verifyPassword(credentials.password as string, user.password_hash)) {
            throw new Error('Contraseña incorrecta');
          }

          // Obtener roles y sucursales
          const roles = await query<any>(
            `SELECT r.id_rol, r.nombre_rol, r.nivel_jerarquico
             FROM [dbo].[Seguridad_Usuarios_Roles] ur
             JOIN [dbo].[Seguridad_Roles] r ON ur.id_rol = r.id_rol
             WHERE ur.id_usuario = @id_usuario AND ur.esta_vigente = 1`,
            { id_usuario: user.id_usuario }
          );

          const sucursales = await query<any>(
            `SELECT id_sucursal FROM [dbo].[Seguridad_Usuarios_Sucursales]
             WHERE id_usuario = @id_usuario`,
            { id_usuario: user.id_usuario }
          );

          const permisos = await query<any>(
            `SELECT DISTINCT p.nombre_permiso
             FROM [dbo].[Seguridad_Usuarios_Roles] ur
             JOIN [dbo].[Seguridad_Roles_Permisos] rp ON ur.id_rol = rp.id_rol
             JOIN [dbo].[Seguridad_Permisos] p ON rp.id_permiso = p.id_permiso
             WHERE ur.id_usuario = @id_usuario AND ur.esta_vigente = 1 AND p.esta_activo = 1`,
            { id_usuario: user.id_usuario }
          );

          const mainRole = roles[0];

          return {
            id: user.id_usuario.toString(),
            email: user.email,
            name: user.nombre_completo,
            // Custom props
            id_usuario: user.id_usuario,
            id_rol: mainRole.id_rol,
            nombre_rol: mainRole.nombre_rol,
            nivel_jerarquico: mainRole.nivel_jerarquico,
            sucursales: sucursales.map((s: any) => s.id_sucursal),
            permisos: permisos.map((p: any) => p.nombre_permiso),
          };
        } catch (error) {
          console.error('[Auth] Error en authorize:', error);
          throw error;
        }
      },
    }),
  ],
  callbacks: {
    jwt: async ({ token, user }) => {
      if (user) {
        token.id_usuario = (user as any).id_usuario;
        token.id_rol = (user as any).id_rol;
        token.nombre_rol = (user as any).nombre_rol;
        token.nivel_jerarquico = (user as any).nivel_jerarquico;
        token.sucursales = (user as any).sucursales;
        token.permisos = (user as any).permisos;
      }
      return token;
    },
    session: async ({ session, token }) => {
      session.user = {
        ...session.user,
        id_usuario: token.id_usuario as number,
        id_rol: token.id_rol as number,
        nombre_rol: token.nombre_rol as string,
        nivel_jerarquico: token.nivel_jerarquico as number,
        sucursales: token.sucursales as number[],
        permisos: token.permisos as string[],
      } as any;
      return session;
    },
  },
  pages: {
    signIn: '/auth/login',
    error: '/auth/error',
  },
  session: {
    strategy: 'jwt',
    maxAge: 24 * 60 * 60, // 24 horas
  },
});
```

---

## FASE 2: CREAR COMPONENTES (1.5 horas)

### 2.1 `components/navbar/Navbar.tsx`
**Tiempo:** 30min

```typescript
// components/navbar/Navbar.tsx
'use client';

import { useSession, signOut } from 'next-auth/react';
import Link from 'next/link';

export default function Navbar() {
  const { data: session } = useSession();

  return (
    <nav className="fixed top-0 left-0 right-0 bg-white border-b border-gray-200 shadow-sm z-50 h-16 flex items-center px-6">
      <div className="flex-1 flex items-center gap-4">
        <div className="w-10 h-10 bg-primary-500 rounded-lg flex items-center justify-center">
          <span className="text-white font-bold">📊</span>
        </div>
        <span className="text-xl font-bold text-primary-600">Opticolor BI</span>
      </div>

      <div className="flex items-center gap-4">
        {session?.user && (
          <>
            <div className="text-right">
              <p className="text-sm font-medium text-foreground">{session.user.name}</p>
              <p className="text-xs text-foreground/60">{session.user.nombre_rol}</p>
            </div>
            <button
              onClick={() => signOut({ callbackUrl: '/auth/login' })}
              className="px-4 py-2 text-sm bg-red-50 text-red-600 hover:bg-red-100 rounded-lg"
            >
              Salir
            </button>
          </>
        )}
      </div>
    </nav>
  );
}
```

### 2.2 `components/sidebar/Sidebar.tsx`
**Tiempo:** 30min

```typescript
// components/sidebar/Sidebar.tsx
'use client';

import Link from 'next/link';
import { usePathname } from 'next/navigation';

const navItems = [
  { href: '/dashboard', label: '📊 Resumen Comercial', icon: '📊' },
  { href: '/dashboard/eficiencia-ordenes', label: '⚙️ Eficiencia de Órdenes', icon: '⚙️' },
  { href: '/dashboard/control-cartera', label: '💰 Control de Cartera', icon: '💰' },
  { href: '/dashboard/desempenio-clinico', label: '🏥 Desempeño Clínico', icon: '🏥' },
  { href: '/dashboard/inventario', label: '📦 Inventario', icon: '📦' },
];

export default function Sidebar() {
  const pathname = usePathname();

  return (
    <aside className="fixed left-0 top-16 bottom-0 w-64 bg-primary-900 text-white overflow-y-auto">
      <nav className="p-4 space-y-2">
        {navItems.map((item) => (
          <Link
            key={item.href}
            href={item.href}
            className={`block px-4 py-3 rounded-lg transition ${
              pathname === item.href
                ? 'bg-primary-600 font-semibold'
                : 'hover:bg-primary-800'
            }`}
          >
            {item.label}
          </Link>
        ))}
      </nav>
    </aside>
  );
}
```

### 2.3 `components/dashboard/ResumenComercialDashboard.tsx`
**Tiempo:** 30min

```typescript
// components/dashboard/ResumenComercialDashboard.tsx
'use client';

import { useEffect, useState } from 'react';
import {
  LineChart,
  Line,
  XAxis,
  YAxis,
  CartesianGrid,
  Tooltip,
  Legend,
  ResponsiveContainer,
} from 'recharts';
import { ResumenComercialRow, ApiResponse } from '@/lib/types';

export default function ResumenComercialDashboard() {
  const [data, setData] = useState<ResumenComercialRow[]>([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState('');

  useEffect(() => {
    const fetchData = async () => {
      try {
        const res = await fetch('/api/data/resumen-comercial');
        if (!res.ok) throw new Error('Error cargando datos');
        const json = (await res.json()) as ApiResponse<ResumenComercialRow[]>;
        if (json.success && json.data) {
          setData(json.data);
        }
      } catch (err) {
        setError('Error cargando dashboard');
        console.error(err);
      } finally {
        setLoading(false);
      }
    };

    fetchData();
  }, []);

  if (loading) return <div className="text-center py-8">Cargando...</div>;
  if (error) return <div className="text-red-500">{error}</div>;

  return (
    <div className="space-y-6">
      {/* KPIs */}
      <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
        {[
          { label: 'Venta Total', key: 'venta_total', format: '$' },
          { label: 'Cobrado', key: 'cobrado', format: '$' },
          { label: 'Ticket Promedio', key: 'ticket_promedio', format: '$' },
          { label: 'Run Rate', key: 'run_rate', format: '%' },
          { label: 'OTIF', key: 'otif', format: '%' },
        ].map((kpi) => {
          const latest = data[data.length - 1];
          const value = latest ? latest[kpi.key as keyof ResumenComercialRow] : 0;
          return (
            <div key={kpi.key} className="bg-white p-4 rounded-lg shadow">
              <p className="text-sm text-foreground/60">{kpi.label}</p>
              <p className="text-2xl font-bold text-primary-600">
                {kpi.format === '$'
                  ? `$${(value as number).toLocaleString('es-VE')}`
                  : `${value}${kpi.format}`}
              </p>
            </div>
          );
        })}
      </div>

      {/* Gráfico */}
      <div className="bg-white p-6 rounded-lg shadow">
        <h2 className="text-lg font-semibold mb-4">Tendencia 7 días</h2>
        <ResponsiveContainer width="100%" height={300}>
          <LineChart data={data}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="fecha" />
            <YAxis />
            <Tooltip />
            <Legend />
            <Line type="monotone" dataKey="venta_total" stroke="#1A3A6B" />
            <Line type="monotone" dataKey="cobrado" stroke="#2B6CB0" />
            <Line type="monotone" dataKey="otif" stroke="#D4A017" />
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
```

---

## FASE 3: ACTUALIZAR ARCHIVOS EXISTENTES (1.5 horas)

### 3.1 Actualizar endpoints API (descomentar SQL)
**Tiempo:** 30min

Para cada archivo en `api/data/*/route.ts`:
1. Descomentar bloque SQL (líneas ~75-90)
2. Reemplazar `mockData` con `await query<T>(...)`
3. Agregar RLS filter: `WHERE id_sucursal IN (SELECT ... FROM Vw_RLS_Sucursales WHERE email = @email)`

**Ejemplo (resumen-comercial/route.ts):**
```typescript
// Línea ~75, descomentar:
const data = await query<ResumenComercialRow>(`
  SELECT
    CAST(DATEADD(HOUR, -5, fecha_utc) AS DATE) AS fecha,
    SUM(monto_total) AS venta_total,
    SUM(monto_cobrado) AS cobrado,
    AVG(monto_total) AS ticket_promedio,
    AVG(run_rate) AS run_rate,
    AVG(otif) AS otif
  FROM [dbo].[Fact_Ventas]
  WHERE id_sucursal IN (
    SELECT id_sucursal FROM [dbo].[Vw_RLS_Sucursales] 
    WHERE email = @email AND id_usuario = @id_usuario
  )
  GROUP BY CAST(DATEADD(HOUR, -5, fecha_utc) AS DATE)
  ORDER BY fecha DESC
`, {
  email: session.user.email,
  id_usuario: session.user.id_usuario
});

// Reemplazar mockData por data
```

### 3.2 Agregar RBAC validación en endpoints
**Tiempo:** 30min

Para cada endpoint, agregar validación de permiso:
```typescript
// Después de: const session = await auth();
if (!session?.user?.permisos.includes('VER_INFORME_1')) {
  return NextResponse.json(
    { success: false, error: 'No tiene permiso VER_INFORME_1' },
    { status: 403 }
  );
}
```

### 3.3 Activar middleware de protección
**Tiempo:** 30min

```typescript
// middleware.ts
import { auth } from '@/config/auth';
import { NextRequest, NextResponse } from 'next/server';

export const config = {
  matcher: ['/dashboard/:path*'],
};

export async function middleware(request: NextRequest) {
  const session = await auth();

  if (!session?.user) {
    return NextResponse.redirect(new URL('/auth/login', request.url));
  }

  return NextResponse.next();
}
```

---

## FASE 4: TESTING & VALIDACIÓN (1 hora)

### 4.1 Compilación
```bash
cd c:/opticolor-bi/portal
npm run build
# Debe pasar sin errores
```

### 4.2 Dev Server
```bash
npm run dev
# Debe correr en http://localhost:3000
```

### 4.3 Testing Login
```
1. Ir a http://localhost:3000/auth/login
2. Ingresar usuario real (ej: visioflow.tech@gmail.com / Cusca915des$)
3. Debe redirigir a /dashboard
4. Verificar Navbar muestre nombre usuario + rol
5. Verificar Sidebar muestre 5 dashboards
```

### 4.4 Testing RLS
```
1. Login como usuario rol SUPERVISOR
2. Ir a Resumen Comercial
3. Ejecutar API en DevTools → Network
4. Verificar datos vienen filtr ados (solo su sucursal)
```

### 4.5 Testing RBAC
```
1. Login como CONSULTOR
2. Intentar acceder /dashboard/admin (debe denegar)
3. Verificar permiso VER_INFORME_1 en BD
```

---

## 📋 CHECKLIST FINAL

- [ ] `lib/types.ts` creado y bien tipado
- [ ] `lib/db.ts` conecta a Azure SQL
- [ ] `config/auth.ts` autentica contra BD
- [ ] `components/navbar/Navbar.tsx` creado
- [ ] `components/sidebar/Sidebar.tsx` creado
- [ ] `components/dashboard/ResumenComercialDashboard.tsx` con Recharts
- [ ] 5 endpoints API descomentados y con SQL real
- [ ] RLS aplicado en todos los endpoints
- [ ] RBAC validación en endpoints
- [ ] Middleware protege /dashboard/*
- [ ] npm run build ✅
- [ ] npm run dev funciona
- [ ] Login con usuario real funciona
- [ ] Dashboard carga datos en < 3 seg
- [ ] RLS verifica (usuario ve solo su sucursal)
- [ ] Tailwind paleta Opticolor aplicada

---

## ⏱️ TIMING ESTIMADO

| Fase | Tarea | Time |
|------|-------|------|
| 1 | Archivos críticos (types, db, auth) | 1.5h |
| 2 | Componentes (navbar, sidebar, dashboard) | 1.5h |
| 3 | Actualizar endpoints + RLS + RBAC + middleware | 1.5h |
| 4 | Testing + debugging | 1h |
| **TOTAL** | | **5.5h** |

**CON BUFFER:** 6-7h (si hay errores inesperados)

---

**Estado:** LISTO PARA SEMANA 2.2  
**Próxima acción:** Esperar Excel usuarios Reinaldo para testear autenticación real

Co-Authored-By: Claude Code Portal Controller
