# ANÁLISIS-PORTAL — Auditoría técnica 360° del portal Opticolor BI

**Alcance:** solo lectura. Ningún archivo de código fuente fue modificado durante esta auditoría.
**Ruta auditada:** `c:\Users\MICHELLE\opticolor-bi\portal`
**Fecha del relevamiento:** 28 de julio de 2026.

---

## 1. Resumen ejecutivo

El portal es una aplicación Next.js 16.2.4 (App Router, React 19.2.4, TypeScript estricto) que sirve un panel administrativo con 5 reportes de negocio (Resumen Comercial, Cartera, Clínico, Eficiencia, Inventario), gestión de usuarios/roles/sucursales, perfil de autogestión y login. Los datos provienen de Azure SQL Server vía el driver `mssql`, sin ORM ni stored procedures invocados en tiempo de request: cada Server Action ejecuta SQL de texto parametrizado contra vistas y tablas ya agregadas por un pipeline ETL externo. La autenticación usa NextAuth v4 con `CredentialsProvider` y sesión JWT, y el control de acceso a datos se resuelve por sucursal asignada a cada usuario (Row-Level Security aplicativa), no por rol.

El repositorio conserva una fracción significativa de un boilerplate de admin dashboard genérico: 4 de las 13 subcarpetas de `dashboard/` (`analytics`, `crm`, `default`, `productivity`) no están enlazadas en la navegación real, no tocan la base de datos y contienen datos/nombres de usuario ficticios de la plantilla original; conviven con los 8 módulos de negocio reales sin estar señalizados como tales. También hay dependencias de producción instaladas y no usadas, una utilidad de seguridad de rutas más completa (`proxy.ts.bak`) que quedó deshabilitada en favor de un middleware más simple, y cero infraestructura de testing automatizado.

El estado general del código de negocio (reportes, usuarios, sucursales, auth) es consistente y sigue un patrón repetido de forma disciplinada (Server Component → Server Action cacheada → SQL parametrizado con filtro de sucursal obligatorio), lo cual facilita la lectura módulo a módulo. La deuda técnica más visible no está en la lógica de negocio en sí, sino en remanentes de plantilla sin limpiar, formateo de números/fechas duplicado en decenas de archivos en lugar de centralizado, y una asimetría de autorización entre el módulo de Sucursales (sin guardas de sesión/rol) y el de Usuarios (con guardas consistentes).

---

## 2. Inventario técnico

### 2.1 Stack exacto

- **Framework:** Next.js `16.2.4`, App Router (no Pages Router). Scripts (`package.json:6-9`) usan explícitamente el flag `--webpack` (`next dev --webpack`, `next build --webpack`), es decir, el proyecto fija Webpack en vez del bundler por defecto de Next 16.
- **Lenguaje:** TypeScript, `strict: true` (`tsconfig.json`), target `ES2017`, `moduleResolution: bundler`, alias `@/*` → `./src/*`.
- **React:** 19.2.4 / `react-dom` 19.2.4.
- **Estilos:** Tailwind CSS v4 (`^4`, vía `@tailwindcss/postcss`), variables CSS nativas/OKLCH en `globals.css`.
- **Componentes UI:** `radix-ui` (meta-paquete v1.4.3) + `@base-ui/react`, siguiendo la convención shadcn (`src/components/ui/`, ~40 archivos).
- **Gráficos:** `recharts` ^3.8.1.
- **Estado cliente:** `zustand` ^5.0.12 (usado solo para preferencias de UI en memoria, ver §5.3 — no hay un store de dominio/negocio).
- **Auth:** `next-auth` ^4.24.14 (NextAuth v4 clásico, no Auth.js v5).
- **Acceso a datos:** `mssql` ^12.5.0 (driver nativo de SQL Server, sin ORM).
- **Formularios/validación:** `react-hook-form` ^7.75.0 + `@hookform/resolvers` ^5.2.2 + `zod` ^4.4.2.
- **Linter:** ESLint 9 (`eslint-config-next` 16.2.4, flat config), sin reglas custom más allá de `core-web-vitals` + `typescript`.
- **`next.config.ts` relevante:** `output: "standalone"` (empaquetado para Docker), `outputFileTracingRoot` anclado a `portal/` (el repo vive dentro de un monorepo mayor junto a `etl/`, `sql/`, `powerbi/`, `memory/` — ver `tsconfig.json` `exclude`), cabeceras de seguridad HTTP explícitas (`X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, HSTS con preload, y una CSP que permite `'unsafe-inline' 'unsafe-eval'` en `script-src`), y config custom de Webpack que excluye `etl/.venv` del watcher para no agotar handles de archivos en Windows.

**Hallazgo — Biome instalado pero inerte:** `@biomejs/biome` `^2.4.14` está en `devDependencies` (`package.json:49`), pero no existe ningún `biome.json`/`biome.jsonc` en el repo, y el único script de lint (`"lint": "eslint"`, `package.json:9`) no lo invoca. `AGENTS.md` menciona "cumplimiento de Biome/ESLint" como invariable del agente de arquitectura, pero en la práctica Biome no participa del flujo de trabajo real.

### 2.2 Dependencias agrupadas por función

| Categoría | Paquetes |
|---|---|
| UI / componentes | `radix-ui`, `@base-ui/react`, `lucide-react`, `simple-icons`, `class-variance-authority`, `clsx`, `tailwind-merge`, `tailwindcss-animate`, `next-themes`, `sonner`, `cmdk`, `react-day-picker`, `vaul`, `input-otp`, `embla-carousel-react`, `@dnd-kit/core`, `@dnd-kit/modifiers`, `@dnd-kit/sortable`, `react-resizable-panels` |
| Formularios / validación | `react-hook-form`, `@hookform/resolvers`, `zod` |
| Datos / tablas / DB | `@tanstack/react-table`, `mssql`, `@types/mssql`, `recharts` |
| Auth | `next-auth`, `bcryptjs`, `@types/bcryptjs` |
| Estado | `zustand` |
| Fechas | `date-fns` |
| Fuentes / branding | `geist` |
| Dev tools | `@biomejs/biome`, `eslint`, `eslint-config-next`, `typescript`, `@types/node`, `@types/react`, `@types/react-dom`, `tailwindcss`, `@tailwindcss/postcss` |
| Testing | *(ninguna — ver §7)* |

**Dependencias de producción confirmadas como no usadas** (0 coincidencias en `src/`, verificado por grep de imports y ausencia del componente shadcn correspondiente en `components/ui/`):

| Paquete | Evidencia de no uso |
|---|---|
| `@dnd-kit/core`, `@dnd-kit/modifiers`, `@dnd-kit/sortable` | Sin imports; no hay `DndContext`/`useSortable` en todo `src/` |
| `embla-carousel-react` | Sin imports; no existe `components/ui/carousel.tsx` |
| `input-otp` | Sin imports; no existe `components/ui/input-otp.tsx` |
| `vaul` | Sin imports; no existe `components/ui/drawer.tsx` |
| `react-resizable-panels` | Sin imports; no existe `components/ui/resizable.tsx` |

Paquetes con uso real confirmado y no obvio a priori: `cmdk` (paleta de comandos, `components/ui/command.tsx:4`, usada por el buscador Cmd+K del sidebar), `@base-ui/react` (`components/ui/combobox.tsx:4`, selector virtualizado usado en el formulario de usuarios).

### 2.3 Estructura de directorios (`src/`)

```
src/
├── app/                     App Router: rutas, layouts, API routes
│   ├── (external)/            Rutas públicas: layout propio + /login + página raíz
│   ├── (main)/                 Rutas protegidas por sesión
│   │   ├── auth/_components/      Formulario de login
│   │   ├── dashboard/              Todos los módulos del panel (ver §2.4)
│   │   └── unauthorized/           Página de acceso denegado (no enlazada activamente, ver §4.6)
│   └── api/
│       ├── auth/[...nextauth]/      Configuración de NextAuth
│       ├── revalidate/                Endpoint de revalidación ISR protegido por token
│       └── test-db/                    Carpeta vacía (sin route.ts) — remanente de endpoint de diagnóstico eliminado
├── components/
│   ├── auth/SessionWatcher.tsx      Cierre de sesión por inactividad (15 min) en cliente
│   ├── providers/                    SessionProvider de next-auth
│   └── ui/                            ~40 componentes estilo shadcn/Radix
├── config/app-config.ts             Nombre/versión/metadata de la app (lee package.json)
├── data/users.ts                    Usuarios mock hardcodeados — código muerto (ver §4.6)
├── hooks/use-mobile.ts               Detección de viewport
├── lib/
│   ├── db.ts                          Pool de conexión Azure SQL (singleton en globalThis)
│   ├── get-auth-context.ts             Contexto de sesión/rol server-side
│   ├── security.ts                      getUserAllowedSucursales (RLS aplicativa por sucursal)
│   ├── sql-helpers.ts                    buildSucursalFilter (fragmento SQL de filtro de sucursal)
│   ├── date-utils.ts                      Mapas mes→abreviatura en español (no funciones de formateo)
│   ├── utils.ts                            cn(), formateo de números/moneda, getInitials, truncateText
│   ├── cookie.client.ts / local-storage.client.ts   Helpers de almacenamiento en cliente
│   ├── preferences/                        Sistema de preferencias de UI (tema, layout, sidebar)
│   ├── fonts/registry.ts                    Registro de fuentes Geist
│   └── scripts/generate-theme-presets.ts    Generación de presets de tema
├── navigation/sidebar/sidebar-items.ts   Única fuente de verdad de la navegación real
├── server/server-actions.ts               getPreference/setValueToCookie (utilidades de cookie, sin SQL)
├── stores/preferences/                    Store zustand de preferencias de UI (no de negocio)
├── styles/flag-icons/ + presets/           CSS de banderas (solo usado por el módulo demo "analytics") y temas
└── types/
    ├── dashboard.ts                        ReportParams (único tipo de dominio "global")
    └── next-auth.d.ts                      Extensión de Session/JWT: id, rol, nivel
```

### 2.4 Módulos reales vs. remanentes de plantilla

La navegación real (`src/navigation/sidebar/sidebar-items.ts`) define exactamente 2 grupos y 7 ítems, todos con Server Actions que ejecutan SQL contra Azure SQL vía `getConnection()`:

**Grupo "Reportes":** `/dashboard/resumen-comercial`, `/dashboard/cartera`, `/dashboard/eficiencia`, `/dashboard/clinico`, `/dashboard/inventario`.
**Grupo "Configuración":** `/dashboard/usuarios`, `/dashboard/sucursales`.

Se suma `/dashboard/perfil`, no presente en el sidebar pero enlazado desde el menú desplegable del avatar de usuario (`nav-user.tsx:129`) y con Server Action real (`change-password.ts`, con bcrypt + `UPDATE` en `dbo.Seguridad_Usuarios`).

De las 13 subcarpetas bajo `dashboard/`, las siguientes **4 son remanentes de un template de admin dashboard genérico**, sin conexión a `@/lib/db` ni enlace en la navegación:

| Carpeta | Evidencia de ser demo/boilerplate |
|---|---|
| `analytics` | Saludo hardcodeado `"Hello, Aiy"`; tabs que renderizan literalmente `"... view coming soon."`; componentes de analítica web genérica (visitantes en tiempo real, tráfico) sin relación con el dominio óptico. |
| `crm` | Datos de "oportunidades" en `_components/opportunities-table/data.json`, JSON local estático, sin ninguna Server Action. |
| `default` | Tabla "recent-customers-table" con `data.json` ficticio. Es además el destino del botón "Go back home" del 404 global (`src/app/not-found.tsx:12` → `/dashboard/default`) — el 404 de todo el sitio apunta a una página demo, no a un módulo real. |
| `productivity` | Saludo hardcodeado `"Good morning, Arham."`; calendario/notas/tareas genéricas sin relación con Opticolor. |

`coming-soon` es un placeholder estático, referenciado solo como filtro de exclusión en el buscador (`search-dialog.tsx:65`); como ningún ítem real del sidebar tiene `comingSoon: true`, la ruta no es alcanzable desde la navegación visible actual.

---

## 3. Mapa de datos

### 3.1 Conexión a SQL Server

- **Driver:** `mssql` (paquete npm, cliente nativo de Tedious), sin ORM ni query builder genérico.
- **Configuración y pool:** `src/lib/db.ts`. Singleton `globalThis.sqlPool` para sobrevivir recargas de módulo en dev/serverless. `getConnection()` reutiliza el pool si `.connected === true`; si está caído, lo cierra de forma segura y crea uno nuevo. Config del pool: `max: 25, min: 0, idleTimeoutMillis: 30000`; `connectionTimeout`/`requestTimeout` de 180 000 ms (180 s); `encrypt: true, trustServerCertificate: false` (TLS obligatorio, sin bypass de certificado).
- **Variables de entorno de conexión** (leídas únicamente en `src/lib/db.ts:12-16`): `AZURE_SQL_USER`, `AZURE_SQL_PASSWORD`, `AZURE_SQL_DATABASE`, `AZURE_SQL_SERVER`, `AZURE_SQL_PORT` (default `1433` si no está definida).
- **No hay stored procedures invocados en tiempo de request:** búsqueda exhaustiva de `.execute(`/`EXEC`/`EXECUTE` en `src/` no arrojó coincidencias. Los SPs existentes en la base (`sp_Actualizar_Resumen_*`, según `docs/Procedimientos Almacenados.csv`) corresponden al pipeline ETL batch que alimenta las tablas `Dash_*`, ejecutado fuera del portal.
- **Helper de filtrado:** `src/lib/sql-helpers.ts` expone `buildSucursalFilter(tableAlias)`, que genera el fragmento SQL `AND id_sucursal IN (STRING_SPLIT(@allowedSucursales,',')) AND (@sucursales IS NULL OR id_sucursal IN (STRING_SPLIT(@sucursales,',')))`. Se usa en las ~20+ queries de los 5 reportes para aplicar simultáneamente el permiso de sucursal del usuario (`@allowedSucursales`) y el filtro opcional que el usuario elige en la UI (`@sucursales`).
- **Resolución del permiso por sucursal:** `src/lib/security.ts` — `getUserAllowedSucursales(userId)`, cacheada 2 h (`unstable_cache`, tag `user-permissions`), consulta `dbo.Seguridad_Usuarios_Sucursales WHERE id_usuario=@userId AND esta_vigente=1`; si no hay filas o falla, retorna `"-1"` como fallback seguro (ningún `id_sucursal` real es -1, así que el filtro no devuelve datos ante error).
- **Contexto de sesión server-side:** `src/lib/get-auth-context.ts` — `getAuthContext()` envuelve `getServerSession` y expone `userId`, `isSupervisor`, `isMaster`. Un comentario en el propio código (`get-clinica-data.ts:56`, referencia "F-9") indica que `isSupervisor`/`isMaster` ya no se usan para bifurcar SQL — el filtrado real de sucursal se resuelve enteramente vía `getUserAllowedSucursales`, no por rol.

### 3.2 Inventario de queries por módulo

| Archivo | Funciones exportadas | Tabla(s)/vista(s) principal(es) |
|---|---|---|
| `resumen-comercial/_actions/get-resumen-data.ts` | `getResumenKPIs`, `getVentasDiarias`, `getTopSucursales`, `getMediosPago` | `KPI_Inf1_Venta_Neta`, `KPI_Inf1_Proyeccion_Venta_Neta`, `Dash_Recaudo_Agregado`, `Fact_Pedidos`, `Fact_Examenes`, `Dim_Sucursales` |
| `cartera/_actions/get-cartera-data.ts` | `getCarteraKPIs`, `getGapCobroData`, `getMixVentasData`, `getCarteraSucursalData`, `getClientesDeudoresTabla` | `KPI_Inf3_Monto_Pedidos`, `KPI_Inf3_Recaudado_Pedidos`, `KPI_Inf3_Saldo_Pendiente`, `KPI_Inf3_Pedidos_Liquidar`, `Fact_Ventas_por_Categoria`, `Dim_Sucursales`, `Fact_Pedidos`, `Dim_Clientes` |
| `clinico/_actions/get-clinica-data.ts` | `getClinicaKPIs`, `getTendenciaExamen`, `getVolumenConversion`, `getGeneroExamen`, `getEdadExamen`, `getTopSucursalesExamen` | `Fact_Examenes`, `Dim_Clientes`, `Dim_Sucursales` |
| `eficiencia/_actions/get-eficiencia-data.ts` | `getEficienciaKPIs`, `getTendenciaOrden`, `getTipoLente`, `getOrdenesSucursal` | `Fact_Eficiencia_Ordenes`, `Dim_Sucursales` |
| `inventario/_actions/get-inventario-data.ts` | `getInventarioKPIs`, `getMarcasDetalleData`, `getGruposMixData`, `getDispersionData` | `Fact_Inventario`, `Dash_Ventas_Resumen`, `Dim_Productos` |
| `inventario/_actions/get-inventario-filters.ts` | `getMarcasGrupos` | `Dim_Productos` (catálogo de marcas/segmentos) |
| `dashboard/_actions/get-mis-sucursales.ts` | `getMisSucursales` | `Seguridad_Usuarios_Sucursales`, `Maestro_Sucursales` |
| `sucursales/_actions/get-usuarios.ts` | `getUsuariosBySucursal` | `Seguridad_Usuarios`, `Seguridad_Usuarios_Sucursales` |
| `usuarios/_actions/*.ts` (11 archivos) | `getUsuarios`, `getRoles`, `getSucursalesParaSelector`, `getUsuarioDetalle`, `getDatosEdicion`, `crearUsuario`, `editarUsuario`, `cambiarRol`, `asignarSucursal`, `revocarSucursal`, `toggleEstadoUsuario` | `Seguridad_Usuarios`, `Seguridad_Usuarios_Roles`, `Seguridad_Roles`, `Seguridad_Usuarios_Sucursales`, `Maestro_Sucursales`, `Seguridad_Auditoria` |
| `perfil/_actions/change-password.ts` | `changePassword`, `verifyCurrentPassword` | `Seguridad_Usuarios`, `Seguridad_Auditoria` |
| `perfil/page.tsx` (queries embebidas, sin Server Action separada) | — | `Seguridad_Usuarios`, `Seguridad_Usuarios_Roles`, `Seguridad_Roles`, `Seguridad_Usuarios_Sucursales`, `Maestro_Sucursales`, `Seguridad_Auditoria` |
| `sucursales/page.tsx` (query embebida) | — | `Maestro_Sucursales`, `Seguridad_Usuarios_Sucursales` |
| `api/auth/[...nextauth]/route.ts` | `authorize()` (NextAuth) | `Seguridad_Usuarios`, `Seguridad_Usuarios_Roles`, `Seguridad_Roles`, `Seguridad_Auditoria` |

Todas las Server Actions de lectura de los 5 reportes están envueltas en `unstable_cache` con `revalidate: 3600` (1 h); `getMisSucursales` y `getUserAllowedSucursales` usan ventanas de caché más largas (1 h y 2 h respectivamente).

### 3.3 Tablas y vistas efectivamente consumidas

**Vistas analíticas (`docs/VISTAS.csv`):** `KPI_Inf1_Venta_Neta`, `KPI_Inf1_Proyeccion_Venta_Neta`, `KPI_Inf3_Monto_Pedidos`, `KPI_Inf3_Recaudado_Pedidos`, `KPI_Inf3_Saldo_Pendiente`, `KPI_Inf3_Pedidos_Liquidar`, `Fact_Ventas_por_Categoria`, `Dim_Sucursales`, `Fact_Pedidos`, `Dim_Clientes`, `Fact_Examenes`, `Fact_Eficiencia_Ordenes`, `Fact_Inventario`, `Dim_Productos`.

**Tablas físicas (`docs/BD.csv`):** `Dash_Ventas_Resumen`, `Dash_Recaudo_Agregado`, `Maestro_Sucursales`, `Seguridad_Usuarios`, `Seguridad_Usuarios_Roles`, `Seguridad_Usuarios_Sucursales`, `Seguridad_Roles`, `Seguridad_Auditoria`.

**Contrastes relevantes contra el schema documentado:**
- `Dim_Sucursales` no existe como tabla física en `BD.csv`, solo como vista en `VISTAS.csv` — los 5 reportes consumen siempre la vista analítica, mientras que el módulo administrativo de usuarios/sucursales usa la tabla física `Maestro_Sucursales`.
- Existen vistas de KPI dedicadas que el portal **no usa** y que en su lugar recalcula manualmente: `KPI_Inf3_Pct_Cobro_Inmediato`, `KPI_Inf3_Pct_Nivel_Abono` (cartera recalcula estos porcentajes desde `KPI_Inf3_Monto_Pedidos`) y `KPI_Inf5_ASP`, `KPI_Inf5_UPT`, `KPI_Inf5_Stock_Fisico`, `KPI_Inf5_Capital_Invertido`, `KPI_Inf5_Unidades_Vendidas`, `KPI_Inf5_Volumen_Unidades` (inventario recalcula estas métricas con joins propios sobre `Fact_Inventario`/`Dash_Ventas_Resumen`).
- Existen vistas `Vw_RLS_Sucursales` y `Vw_Usuario_Accesos` aparentemente diseñadas para centralizar RLS/autenticación, que el portal no usa: el control de acceso por sucursal se resuelve consultando directamente `Seguridad_Usuarios_Sucursales` en `security.ts`.
- `Fact_Inventario` ya trae columnas propias `Marca` y `Segmento_Comercial` (según `VISTAS.csv`), pero el código igualmente hace `LEFT JOIN Dim_Productos` para obtenerlas, lo cual es redundante si la vista ya las desnormaliza.

Ninguno de estos contrastes fue verificado contra una explicación de negocio — quedan como pregunta abierta en §9.

---

## 4. Detalle por módulo

### 4.1 Reporte — Resumen Comercial (`dashboard/resumen-comercial/`)

- **Datos:** `getResumenKPIs` agrega 5 queries en paralelo sobre `KPI_Inf1_Venta_Neta` (venta neta período y YTD), `KPI_Inf1_Proyeccion_Venta_Neta`, `Dash_Recaudo_Agregado` y `Fact_Pedidos`/`Fact_Examenes`. `getTopSucursales`, `getMediosPago` y `getVentasDiarias` alimentan gráficos independientes.
- **Cálculos:** la proyección de cierre de mes se calcula en SQL con lógica condicional T-SQL (mes histórico = suma real; mes en curso = extrapolación lineal por días transcurridos usando `EOMONTH`/`SWITCHOFFSET` en GMT-4). El ticket promedio (`ventaNeta / cantidadPedidos`) y el % de participación de medios de pago se calculan en JS dentro del Server Action. `proyeccionPct` y `pendienteCobro` se calculan en el propio Server Component de la página (`page.tsx:49-52`).
- **Presentación:** 8 KPI cards (Venta Neta, Proyección Cierre, Total Cobrado, Ticket Promedio, Venta Neta YTD, Órdenes Facturadas, Total Exámenes, Clientes Nuevos); gráfico combinado Recharts (barras + línea, doble eje) para ventas diarias; donut Recharts para medios de pago; lista de barras de progreso (no Recharts) para top sucursales.
- **Filtros:** rango de fechas y sucursal (estándar de los 5 reportes). **Particularidad:** el gráfico de ventas diarias (`VentasChartWrapper`) ignora el rango de fechas elegido por el usuario — su Server Action fija el año en curso vía SQL, solo respeta el filtro de sucursal.

### 4.2 Reporte — Cartera (`dashboard/cartera/`)

- **Datos:** 5 Server Actions sobre las vistas dedicadas `KPI_Inf3_Monto_Pedidos`, `KPI_Inf3_Recaudado_Pedidos`, `KPI_Inf3_Saldo_Pendiente`, `KPI_Inf3_Pedidos_Liquidar`, más `Fact_Ventas_por_Categoria` (mix de ventas) y `Fact_Pedidos`/`Dim_Clientes` (tabla de clientes deudores, con `HAVING saldo_pendiente > 0`).
- **Cálculos:** `% Primer Abono` y `% Pago Total` se calculan directamente en SQL (`COUNT(CASE WHEN...) * 100.0 / NULLIF(...)`); el % de participación por categoría se recalcula en el tooltip del cliente sobre datos ya agregados por SQL; los totales de la tabla de deudores se recalculan por `reduce` en el cliente sobre el subconjunto filtrado por el buscador.
- **Presentación:** 6 KPI cards; gráfico de área (GAP de cobro: monto vs. saldo pendiente); barras horizontales (mix de ventas); barras/progreso por sucursal; tabla de clientes deudores con buscador, paginación y fila de totales.
- **Filtros:** rango de fechas y sucursal (estándar).

### 4.3 Reporte — Clínico (`dashboard/clinico/`)

- **Datos:** 6 Server Actions, todas sobre `Fact_Examenes` como única fuente, con joins opcionales a `Dim_Clientes` (género, edad) y `Dim_Sucursales` (ranking).
- **Cálculos:** `% Conversión` y promedio diario en SQL; el `% de participación por género` es el único cálculo porcentual del proyecto resuelto con función de ventana SQL (`SUM(...) OVER()`) en vez de en JS; los rangos etarios (`'01 a 18'`, etc.) se generan enteramente en SQL con `CASE WHEN`; el `% de conversión` mensual para el gráfico combinado se calcula en JS tras traer los conteos.
- **Presentación:** 6 KPI cards; línea (tendencia de exámenes); donut (género); barras (edad); barras horizontales con línea de referencia de promedio (top sucursales); combinado barras+línea (volumen vs. conversión).
- **Filtros:** rango de fechas y sucursal (estándar), más una exclusión fija adicional de sucursales vía la variable de entorno `EXCLUDED_CLINICA_IDS` (fallback hardcodeado `"3,4"` si no está definida) — es el único de los 5 reportes con un filtro estructural extra no controlable desde la UI.

### 4.4 Reporte — Eficiencia (`dashboard/eficiencia/`)

- **Datos:** 4 Server Actions sobre `Fact_Eficiencia_Ordenes`, con join opcional a `Dim_Sucursales`. `getTipoLente` alimenta simultáneamente un gráfico y una tabla de detalle (misma Server Action, dos consumidores).
- **Cálculos:** volumen de órdenes = `COUNT` de filas (no `DISTINCT`, con comentario explícito en el código sobre esta semántica); promedio diario calculado en SQL; `promedioDiario` se trunca con `Math.floor` (no redondeo) en JS; el % de participación por tipo de lente se calcula en el tooltip del cliente.
- **Presentación:** 4 KPI cards; línea (tendencia de órdenes); barras horizontales (tipo de lente, con progreso CSS en mobile); barras horizontales con línea de referencia de promedio (órdenes por sucursal); tabla de detalle con buscador y totales.
- **Filtros:** rango de fechas y sucursal (estándar), sin filtros propios adicionales.

### 4.5 Reporte — Inventario (`dashboard/inventario/`)

- **Datos:** 4 Server Actions más un archivo de filtros propio. `getMarcasDetalleData` y `getGruposMixData`/`getDispersionData` combinan dos fuentes distintas (`Fact_Inventario` para stock y `Dash_Ventas_Resumen` para ventas) que **no comparten join directo en SQL**: la fusión se hace en memoria JS con un `Map`, el único caso de los 5 reportes donde el join ocurre en la capa de aplicación en vez de en la base de datos.
- **Cálculos:** UPT (`SUM(cantidad)/COUNT(DISTINCT id_factura)`) y ASP (`SUM(monto)/SUM(cantidad)`) se calculan en SQL con `ROUND(...,4)`; el ASP se recalcula de forma redundante en el tooltip del ranking de marcas en el cliente; el % del treemap se calcula en JS sobre el total ya agregado.
- **Presentación:** 6 KPI cards (Stock Físico, Capital Invertido, Unidades Vendidas, UPT, ASP, Volumen Total — reutiliza el componente `KpiCard` de resumen-comercial vía re-export); tabla de detalle por marca; scatter plot (dispersión stock vs. ventas); barras horizontales (ranking de marcas); treemap (mix por grupo comercial).
- **Filtros:** único reporte con filtros propios además de fecha/sucursal — **Marca** y **Grupo** (`Segmento_Comercial`), cargados de forma perezosa desde `get-inventario-filters.ts` y solo visibles cuando la ruta activa es `/dashboard/inventario`.

### 4.6 Gestión de sucursales (`dashboard/sucursales/`)

- **Estructura:** módulo exclusivamente de **lectura** — no existe ninguna operación de creación, edición ni eliminación de sucursales en el código. `page.tsx` ejecuta la consulta directamente (no delega a una Server Action) y pasa los datos a `SucursalesClient`; la única Server Action del módulo (`get-usuarios.ts`) trae los usuarios asignados a una sucursal, invocada bajo demanda al abrir el modal de detalle.
- **Datos que maneja:** `id_sucursal`, `nombre_sucursal`, `alias_sucursal`, ubicación (`municipio_raw`, `localidad_raw`, `direccion_raw`), `fecha_carga_etl` (metadato de la última carga del maestro) y `total_usuarios` (conteo calculado). No hay campos de auditoría de creación/modificación propios de la entidad — el maestro de sucursales se alimenta por ETL externo, no por el portal.
- **Componentes:** `SucursalesClient` (buscador en memoria + tabla + modal de detalle con resumen de acceso y usuarios vigentes vía `getUsuariosBySucursal`).
- **Hallazgo de seguridad:** a diferencia de todos los demás módulos administrativos, **ni `sucursales/page.tsx` ni `get-usuarios.ts` verifican sesión ni rol** (no llaman a `getServerSession`/`getAuthContext`). El único control de acceso que llega a esta ruta es el middleware global (que solo exige un JWT válido, ver §4.8) — no hay una guarda de nivel jerárquico como sí existe en `usuarios/page.tsx` (`nivel > 2` bloqueado). Esto es una asimetría de autorización entre dos módulos que en la navegación aparecen agrupados bajo el mismo encabezado "Configuración".

### 4.7 Gestión de usuarios/empleados (`dashboard/usuarios/`)

No existe un módulo separado llamado "empleados": toda la administración de personal del sistema (cuenta, rol, estado, sucursales asignadas, historial de auditoría) vive en `dashboard/usuarios/`, que es el equivalente funcional solicitado.

- **Estructura:** `page.tsx` (listado, protegido: redirige a `/login` sin sesión y muestra "Acceso Denegado" si `nivel > 2`) y `[id]/page.tsx` (ficha de detalle, misma protección). 11 Server Actions en `_actions/`. Las de **mutación** (`crear-usuario`, `editar-usuario`, `cambiar-rol`, `asignar-sucursal`, `revocar-sucursal`, `toggle-estado-usuario`) validan sesión y nivel jerárquico **dentro de cada Action** (defensa en profundidad); las de **lectura auxiliar** (`get-usuarios`, `get-roles`, `get-sucursales`, `get-usuario-detalle`, `get-datos-edicion`) no tienen guarda propia — confían en que solo se invocan desde páginas ya protegidas.
- **CRUD:**
  - **Crear** (`crear-usuario.ts`): valida con Zod (nombre ≥3, email válido, password con política de mayúscula/minúscula/número/símbolo ≥8 chars), verifica email único, hashea con bcrypt costo 12; si el rol asignado es `MASTER`, auto-asigna **todas** las sucursales existentes ignorando la selección del formulario.
  - **Editar** (`editar-usuario.ts`): mismo esquema Zod con password opcional; bloquea que un admin cambie su propio rol (usa `id_rol === 0` como sentinela de "no tocar rol" en autoedición); revoca todas las sucursales vigentes y reasigna las seleccionadas.
  - **Cambiar rol** (`cambiar-rol.ts`): desactiva el rol vigente e inserta el nuevo; bloquea auto-modificación de rol y protege explícitamente los perfiles de nivel jerárquico 1 (Super Admin) — no se pueden modificar ni asignarse desde este panel.
  - **Asignar/revocar sucursal** (`asignar-sucursal.ts`, `revocar-sucursal.ts`): upsert de la relación (reactiva si existe inactiva) y soft-delete (`esta_vigente=0`) respectivamente.
  - **Activar/desactivar** (`toggle-estado-usuario.ts`): soft-delete lógico de la cuenta (`esta_activo`); no se detectó guarda explícita contra auto-desactivación, a diferencia de la protección sí presente para el cambio de rol.
  - No existe ningún `DELETE` físico — el diseño es consistentemente de soft-delete vía flags `esta_vigente`/`esta_activo`.
- **Auditoría transversal:** toda mutación inserta un registro en `Seguridad_Auditoria` (actor, acción, tabla afectada, IP de origen extraída de `x-forwarded-for`/`x-real-ip`, valores anteriores/nuevos en JSON, timestamp).
- **Datos de la entidad:** `id_usuario`, `nombre_completo`, `email`, `esta_activo`, `ultima_sesion`, `nombre_rol`, `nivel_jerarquico`, más en la ficha de detalle: fechas y responsables de creación/modificación, sucursales vigentes y últimos 20 registros de auditoría.
- **Componentes:** `UsuariosClient` (tabla + modal crear/editar + confirmación activar/desactivar; refresca con `window.location.reload()` tras guardar, en vez de revalidar solo los datos), `UsuarioFormModal` (formulario unificado crear/editar con selector virtualizado de sucursales), `UsuarioDetalleClient` (cuenta, selector de rol en línea, sucursales asignadas con revocar/asignar, timeline de auditoría), `AuditDetailDialog` (diff JSON de valores anteriores/nuevos).

### 4.8 Perfil (autogestión)

Vista de solo el propio usuario en sesión, reutilizando las mismas tablas de seguridad del módulo Usuarios pero acotada siempre al registro propio (no puede ver ni editar datos de terceros, ni su propio rol/sucursales/estado).

- `perfil/page.tsx` ejecuta 3 queries embebidas (datos propios + rol, sucursales asignadas, últimos 5 registros de auditoría propios), con `WHERE email=@email AND esta_activo=1` — si el usuario fue desactivado por un admin, no puede ver su propio perfil y es redirigido a login.
- `change-password.ts` expone `verifyCurrentPassword` (valida el hash actual antes de habilitar el cambio) y `changePassword` (transacción SQL, re-verifica bcrypt, política de contraseña vía Zod). Buena práctica puntual: registra `[HASH_ACTUAL_PROTEGIDO]`/`[NUEVO_HASH_GENERADO]` como placeholders en la auditoría en vez de serializar los hashes reales — a diferencia de otras Actions del módulo Usuarios que sí serializan objetos con datos reales en el JSON de auditoría.
- Componente `ChangePasswordModal`: flujo de 2 pasos (verificar contraseña actual → ingresar nueva, con checklist visual de política).

### 4.9 Login / autenticación

- **Tecnología:** NextAuth v4.24.14 clásico, un único `CredentialsProvider` (email + password contra `dbo.Seguridad_Usuarios`, sin OAuth/SSO). Estrategia de sesión **JWT**, `maxAge: 8 horas` (`api/auth/[...nextauth]/route.ts:68-71`). Hashing con `bcryptjs` (`bcrypt.compare` dentro del propio `authorize()`; no hay un módulo dedicado a hashing — `src/lib/security.ts` en la práctica solo contiene la lógica de sucursales permitidas, no utilidades de hash).
- **Flujo:** `login/page.tsx` → `LoginForm` (react-hook-form + Zod) → `signIn("credentials", {redirect:false})` → si no hay error, `router.push("/dashboard/resumen-comercial")` hardcodeado (no varía según rol). En el backend, `authorize()` valida bcrypt y retorna `{id, name, email, rol, nivel}`; los callbacks `jwt`/`session` los inyectan en el token/sesión; el evento `signIn` actualiza `ultima_sesion` e inserta auditoría con IP de origen.
- **Protección de rutas — hallazgo relevante:** el middleware activo (`src/middleware.ts`) es el middleware por defecto de `next-auth` aplicado a `/dashboard/:path*`, que **solo verifica que exista un JWT válido**, sin lógica de autorización por rol ni cabeceras de seguridad adicionales. Existe un archivo `src/proxy.ts.bak` (extensión `.bak`, no compilado por Next.js) con una versión mucho más completa: cabeceras CSP/HSTS/X-Frame-Options, bloqueo explícito de `/dashboard/usuarios` y `/dashboard/sucursales` para el rol SUPERVISOR con redirect, y verificación de expiración de token — es decir, existe una guarda de autorización por rol ya escrita, pero deshabilitada. El único control de rol para rutas de Configuración que sí está activo hoy ocurre **en el cliente** (oculta el ítem de menú si `isSupervisor`, `app-sidebar.tsx:71-77`), lo cual es evadible navegando directo a la URL.
- **Protección adicional:** el layout del dashboard (`(main)/dashboard/layout.tsx:20-22`) también redirige a `/login` si no hay `session.user` (doble guarda: middleware + layout), y `SessionWatcher` (`components/auth/SessionWatcher.tsx`) cierra la sesión en cliente tras 15 minutos de inactividad o si detecta `status === "unauthenticated"`.
- **Modelo de roles:** `next-auth.d.ts` extiende `Session`/`JWT`/`User` con `id`, `rol` (string) y `nivel` (number). En código solo se referencian explícitamente 2-3 roles operativos: `SUPERVISOR` (nivel 4), `MASTER`/`SUPER_ADMIN` (nivel 1), y fallback `USUARIO`. `get-roles.ts` filtra `nivel_jerarquico IN (1,2,4)` como los únicos niveles asignables desde la UI. **No se encontró evidencia en el código, `docs/BD.csv`, `docs/VISTAS.csv` ni `docs/E5-Guia_Interpretacion_Dashboards.txt` de los "7 roles jerárquicos" mencionados en la documentación de nivel proyecto** — la guía funcional solo describe explícitamente MASTER (acceso total) y SUPERVISOR (acceso restringido por RLS de sucursal). Esto se deja como pregunta abierta en §9.
- **Hallazgos de código muerto relacionados:** `src/data/users.ts` contiene un array de usuarios ficticios hardcodeados (nombres/roles de la plantilla original), confirmado sin ninguna referencia desde el resto del código (no participa del flujo real de auth, que consulta SQL directamente). `src/app/(main)/unauthorized/page.tsx` no tiene ningún redirect activo que apunte a ella (el middleware de next-auth redirige a `/login`, no a `/unauthorized`), por lo que también parece código no enlazado en el flujo actual.

### 4.10 Filtros — inventario completo

Arquitectura general: todos los filtros viven en **query params de la URL** (no en el store de preferencias de Zustand, que solo gestiona tema/layout). El flujo es: componente cliente lee/escribe `useSearchParams()` → el Server Component de cada reporte normaliza los params → los pasa a la Server Action → la Server Action agrega `allowedSucursales` (RLS) y ejecuta SQL parametrizado. **No se detectó filtrado en memoria sobre datos ya cargados** en ninguno de los 5 reportes — el filtrado de negocio ocurre siempre en el servidor/SQL.

| Filtro | Vistas donde aplica | Campo(s) SQL | Componente UI |
|---|---|---|---|
| Rango de fechas | Los 5 reportes | `fecha_pedido_completa` / `fecha_examen_completa` / `fecha_factura` / `fecha_recaudo` según módulo | `src/components/date-range-picker.tsx` |
| Sucursal | Los 5 reportes | `id_sucursal` (vía `buildSucursalFilter`) | `MultiSelectFilter` dentro de `navbar/report-filters.tsx`, poblado por `getMisSucursales` (solo muestra sucursales permitidas al usuario) |
| Marca | Solo Inventario | `Dim_Productos.Marca` | `MultiSelectFilter`, opciones de `get-inventario-filters.ts` |
| Grupo (Segmento Comercial) | Solo Inventario | `Dim_Productos.Segmento_Comercial` | `MultiSelectFilter`, mismo origen |

Particularidades: el gráfico de ventas diarias de Resumen Comercial ignora el filtro de fecha (ver §4.1); varias métricas de tendencia usan una ventana fija de "últimos 12 meses hasta `endDate`" independiente del rango elegido; el KPI "Venta Neta YTD" siempre calcula desde el 1 de enero del año en curso, sin importar el filtro; Clínico añade una exclusión fija adicional de sucursales vía `EXCLUDED_CLINICA_IDS` que no es controlable desde la UI.

---

## 5. Modelado de datos en frontend

### 5.1 Tipos de dominio

`src/types/dashboard.ts` es el único archivo de tipos "global" del dominio y contiene una sola interfaz, compartida por los 5 reportes:

```ts
export interface ReportParams {
  startDate: string;
  endDate: string;
  sucursales: string | null;
  marcaFilter?: string | null;
  grupoFilter?: string | null;
}
```

Fuera de esto, **cada módulo define sus propios tipos de KPI/serie inline** dentro de su archivo `_actions/*.ts` (`KpiData`/`MonthlyTrendData`/`VentaSucursal`/`MedioPago` en resumen-comercial; `CarteraKpiData`/`GapCobro`/`MixVenta`/... en cartera; `ClinicaKpis`/`TendenciaExamen`/... en clínico; `EficienciaKpis`/... en eficiencia; `InventarioKpis`/`MarcaItem`/... en inventario), sin una interfaz común de "KPI genérico" o "serie temporal" reutilizada entre módulos — mismo shape estructural, nombres distintos, duplicado 5 veces. También se observa inconsistencia de convención de nombres de campo entre módulos: `cartera` usa `snake_case` en sus tipos de retorno mientras que `resumen-comercial` usa `camelCase`.

Los schemas Zod de `crm/_components/opportunities-table/schema.ts` y `default/_components/recent-customers-table/schema.ts` son datos mock/demo (campos `account/stage/priority/health` y `plan/billing/joined`, vocabulario SaaS genérico), consistentes con el hallazgo de §2.4 de que esos módulos son remanentes de plantilla.

### 5.2 Formateo de fechas y números — duplicado, no centralizado

- `src/lib/date-utils.ts` (9 líneas) solo contiene dos diccionarios estáticos de mapeo mes→abreviatura en español (`MAP_MES_NAME_TO_ABBR`, `MAP_MES_NUM_TO_ABBR`), usados por 3 de los 5 reportes. No expone ninguna función real de formateo de fecha.
- `src/lib/utils.ts` sí concentra varias utilidades (`cn`, `getInitials`, `formatCompactNumber`, `formatCompactCurrency`, `formatCurrency`, `truncateText`, `formatBsCurrency`), pero **solo `formatBsCurrency` tiene consumidores confirmados fuera del propio archivo** (2 usos, en `ranking-marcas-chart.tsx`). `formatCurrency` y `formatBsCurrency` son además casi idénticas entre sí (redundancia interna del mismo archivo).
- El resto de los ~30 componentes de reporte reimplementa el formateo de forma ad-hoc: patrón `new Intl.NumberFormat("en-US").format(x)` repetido en 6 archivos de gráficos/tooltips; `.toLocaleString("en-US")` repetido en al menos 12 archivos (KPI cards y tablas de los 5 reportes); una tercera reimplementación de formateo de moneda vive en `src/components/ui/chart-tooltip-container.tsx:37-41` (prefijo `"Bs. "` hardcodeado), sin reutilizar `formatCurrency`/`formatBsCurrency` de `utils.ts`.
- El cálculo del rango de fechas por defecto (`format(startOfMonth(new Date()), ...)` con `date-fns`) está copiado literalmente en las 5 páginas de reporte (`resumen-comercial/page.tsx`, `cartera/page.tsx`, `clinico/page.tsx`, `eficiencia/page.tsx`, `inventario/page.tsx`), sin ninguna función compartida que lo encapsule.

### 5.3 Preferencias de usuario

El sistema de preferencias (`src/lib/preferences/` + `src/stores/preferences/`) gestiona 7 claves de UI (`theme_mode`, `theme_preset`, `font`, `content_layout`, `navbar_style`, `sidebar_variant`, `sidebar_collapsible`) — **no** filtros de reporte ni datos de negocio. El mecanismo real de persistencia es **cookies** (client-side y server-side, todas configuradas como `"client-cookie"`), no `localStorage` (soportado en el código pero sin ninguna clave activa hoy) ni el middleware `persist` de Zustand. Zustand se usa únicamente como store reactivo en memoria para que los componentes React reaccionen a cambios; la sincronización inicial ocurre leyendo atributos `data-*` inyectados por SSR desde las cookies.

### 5.4 `src/components/ui/`

Confirmado como la carpeta estándar de componentes base shadcn/Radix (~40 archivos: `button`, `dialog`, `table`, `sidebar`, `chart`, etc.). Contiene además dos wrappers propios del proyecto que no son parte del set estándar de shadcn — `safe-chart-container.tsx` y `chart-tooltip-container.tsx` (este último con lógica de formateo de moneda propia, ver §5.2) — mezclados junto a los primitives puros, una desviación menor de convención.

---

## 6. Deploy / Azure

- **Plataforma confirmada:** Azure Container Apps (`app-portal-opticolor-prd`, resource group `rg-opticolor-prd`), con imágenes en Azure Container Registry (`opticoloracr.azurecr.io`). No es App Service ni AKS.
- **Dockerfile:** build multi-stage de 3 etapas sobre `node:20-alpine` — `deps` (`npm ci`), `builder` (`next build --webpack`, `NEXT_TELEMETRY_DISABLED=1`), `runner` (usuario no-root `nextjs`, copia solo `.next/standalone` + `.next/static` + `public/`, aprovechando `output: "standalone"`). `EXPOSE 3000`, `CMD ["node","server.js"]`.
- **`.dockerignore`:** solo 4 líneas (`node_modules`, `.next`, `.git`, `.env`, `*.md`) — no excluye `.env.local` por nombre exacto (mitigado en la práctica porque `.gitignore` ya bloquea `.env*` de forma global, evitando que llegue a versionarse).
- **CI/CD:** no hay workflows dentro de `portal/`; en la raíz del monorepo existe `.github/workflows/deploy-portal.yml` — trigger en push a `main` con cambios en `portal/**` (o `workflow_dispatch`), login a ACR, build&push con tag `latest` + SHA corto, login a Azure vía `azure/login@v2.1.1`, y `az containerapp update`. Existe un segundo workflow `deploy-etl.yml` para el componente ETL del monorepo (fuera del alcance de esta auditoría del portal). No se encontró ningún `azure-pipelines.yml`.
- **Variables de entorno:** no existe `.env.example` en `portal/` ni en la raíz del monorepo — no hay documentación versionada de qué variables necesita un desarrollador nuevo. `.env.local` existe (contenido no reproducido); los **nombres** de clave presentes son: `AZURE_SQL_SERVER`, `AZURE_SQL_DATABASE`, `AZURE_SQL_USER`, `AZURE_SQL_PASSWORD`, `AZURE_SQL_PORT`, `NEXTAUTH_URL`, `NEXTAUTH_SECRET`, `REVALIDATE_SECRET_TOKEN`.
  - **Hallazgo — variable posiblemente faltante:** `clinico/_actions/get-clinica-data.ts:77` lee `process.env.EXCLUDED_CLINICA_IDS`, que **no aparece** en `.env.local`. Localmente esto degrada a un fallback hardcodeado (`"3,4"`); no se pudo verificar si está configurada como secret/env var del Container App en Azure (fuera del alcance de este repo).

---

## 7. Testing

**No existe ninguna infraestructura de testing en el proyecto.** Búsqueda exhaustiva (excluyendo `node_modules`/`.next`) de `*.test.ts(x)`, `*.spec.ts(x)`, carpetas `__tests__`, y configs de `jest`/`vitest`/`playwright`/`cypress`: cero resultados. `package.json` no declara ninguna dependencia de testing ni un script `test`; el único script de calidad es `"lint": "eslint"`. Esto incluye la ausencia total de pruebas sobre el módulo de autenticación (credenciales, bcrypt, auditoría de seguridad) y sobre las Server Actions de mutación de usuarios/sucursales (creación, cambio de rol, asignación de sucursal), que son las rutas de código con mayor impacto si fallan silenciosamente.

---

## 8. Observaciones generales de calidad de código

Estas observaciones surgen de la evidencia recogida en las secciones anteriores; se agrupan aquí para visibilidad conjunta, no representan una sección de hallazgos nueva.

1. **Remanentes de plantilla sin señalizar** (§2.4): 4 de 13 módulos de `dashboard/` (`analytics`, `crm`, `default`, `productivity`) son boilerplate genérico con nombres de usuario ficticios y datos JSON hardcodeados, sin ningún comentario o convención que los distinga de los 8 módulos de negocio real. El 404 global redirige a uno de ellos (`/dashboard/default`).
2. **Dependencias de producción muertas:** 7 paquetes (`@dnd-kit/*` ×3, `embla-carousel-react`, `input-otp`, `vaul`, `react-resizable-panels`) instalados sin uso, más `@biomejs/biome` como devDependency sin configuración ni script que lo invoque.
3. **Asimetría de autorización entre módulos "Configuración":** Usuarios aplica guardas de sesión/rol tanto en el `page.tsx` como dentro de cada Server Action de mutación; Sucursales no aplica ninguna guarda de sesión ni rol en su `page.tsx` ni en su única Server Action (§4.6).
4. **Guarda de autorización por rol deshabilitada:** `src/proxy.ts.bak` contiene una versión de middleware con cabeceras de seguridad y bloqueo de rutas de Configuración para el rol SUPERVISOR, pero no está activa; el middleware real solo exige sesión válida, y el único control de rol activo para esas rutas ocurre en el cliente (ocultamiento de menú, evadible por URL directa) — ver §4.9.
5. **Formateo de números/fechas duplicado en ~30 archivos** en lugar de centralizado en `lib/utils.ts`/`lib/date-utils.ts`, incluyendo tres reimplementaciones distintas de formateo de moneda y el mismo boilerplate de rango de fechas por defecto copiado en las 5 páginas de reporte (§5.2).
6. **Fragmentación de tipos de dominio:** cada uno de los 5 reportes define su propio conjunto de tipos de KPI/serie inline sin una interfaz común, con inconsistencia de convención (`camelCase` vs `snake_case`) entre módulos (§5.1).
7. **Vistas de KPI dedicadas no utilizadas:** existen vistas SQL (`KPI_Inf3_Pct_*`, `KPI_Inf5_*`) que ya precalculan métricas que el portal recalcula manualmente con lógica propia (§3.3) — no se pudo determinar si esto es intencional (por ejemplo, si las vistas están desactualizadas) sin contexto adicional.
8. **Código muerto / no enlazado:** `src/data/users.ts` (usuarios mock hardcodeados, sin ninguna referencia en el resto del código), `src/app/(main)/unauthorized/page.tsx` (sin redirect activo que la use), `src/app/api/test-db/` (carpeta vacía, sin `route.ts`), la carpeta `scratch/` en la raíz del portal (vacía), y `coming-soon` (inalcanzable desde la navegación actual).
9. **Sin infraestructura de testing** (§7), incluyendo el flujo de autenticación y las mutaciones administrativas.
10. **Patrón de refresco posterior a mutación:** `UsuariosClient` recarga la página completa (`window.location.reload()`) tras crear/editar un usuario en vez de revalidar solo los datos afectados.
11. **Falta de `.env.example`:** ningún archivo versionado documenta las variables de entorno requeridas para un entorno nuevo (§6), y al menos una variable (`EXCLUDED_CLINICA_IDS`) usada en código no aparece en el `.env.local` local auditado.
12. **CSP permisiva:** la Content-Security-Policy definida en `next.config.ts` incluye `'unsafe-inline' 'unsafe-eval'` en `script-src`, lo cual reduce la efectividad de la cabecera como mitigación de XSS.

No se evaluaron aquí paridad matemática con Power BI, hardening ofensivo de seguridad (IDOR/BOLA, inyección), ni contraste exhaustivo campo-a-campo contra `E5-Guia_Interpretacion_Dashboards.txt` — esos análisis corresponden a los protocolos específicos de los agentes `Analytics Integrity Auditor` y `Cyber-Security Architect` definidos en `/agents/`, fuera del alcance parejo de 360° solicitado en esta auditoría.

---

## 9. Preguntas abiertas / puntos que no quedaron claros solo con el código

1. **¿Existen realmente "7 roles jerárquicos"?** La documentación de nivel proyecto (`opticolor-bi/CLAUDE.md`) lo menciona como parte del RBAC, pero el código, `docs/BD.csv`, `docs/VISTAS.csv` y `docs/E5-Guia_Interpretacion_Dashboards.txt` solo evidencian 2-3 roles operativos activos (MASTER, SUPERVISOR, y un fallback "USUARIO"), con `nivel_jerarquico IN (1,2,4)` como únicos niveles asignables desde la UI. No queda claro si los 7 roles existen en la tabla `Seguridad_Roles`/`Seguridad_Roles_Permisos` sin lógica de aplicación implementada aún, o si el número es aspiracional/documental.
2. **¿Es intencional que el módulo Sucursales no tenga guardas de sesión/rol** mientras que Usuarios sí las tiene extensivamente? ¿Fue una omisión o se asume que el middleware es suficiente para ese caso particular?
3. **¿Por qué `src/proxy.ts.bak` quedó deshabilitado** en favor del middleware más simple? ¿Fue un rollback intencional, un experimento abandonado, o un archivo pendiente de reactivar?
4. **¿Las vistas de KPI dedicadas no usadas** (`KPI_Inf3_Pct_Cobro_Inmediato`, `KPI_Inf3_Pct_Nivel_Abono`, familia `KPI_Inf5_*`) están desactualizadas/deprecadas, o el portal debería estar usándolas en vez de recalcular la misma lógica manualmente?
5. **¿Los módulos `analytics`, `crm`, `default` y `productivity`** son plantilla temporal a eliminar, o hay planes de convertirlos en módulos reales del portal (por ejemplo, un CRM propio de Opticolor)?
6. **¿`EXCLUDED_CLINICA_IDS` está configurada como variable de entorno del Container App en Azure** (fuera de este repositorio), o el fallback hardcodeado `"3,4"` es efectivamente el valor en producción hoy?
7. **¿Cuál es el criterio de negocio para excluir sucursales del reporte Clínico** vía esa variable — son sucursales sin consultorio clínico, sucursales piloto, o algo distinto?
8. **¿Las vistas `Vw_RLS_Sucursales` y `Vw_Usuario_Accesos`** mencionadas en `docs/VISTAS.csv` fueron diseñadas para un modelo de autorización que se reemplazó por el actual (`Seguridad_Usuarios_Sucursales` consultada directamente), o siguen vigentes para otro consumidor (Power BI) fuera del portal?
9. **¿Se planea agregar testing automatizado**, y si es así, ¿con qué prioridad relativa dado que el proyecto está en producción activa (Semana 2/6 según `opticolor-bi/CLAUDE.md`)?
