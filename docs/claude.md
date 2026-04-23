# 🎯 Opticolor BI — Ecosistema de Inteligencia de Datos Venezuela

## Identidad

| Campo | Valor |
|-------|-------|
| Cliente | OPTI-COLOR #2, C.A. — Venezuela |
| Contactos | Eduardo Martínez, Reinaldo José Rangel |
| Proveedor | VisioFlow — Gerardo Argueta |
| Período | 14 abril 2026 — 26 mayo 2026 (6 semanas) |
| Estado | Semana 2/6 ✅ COMPLETADA — ETL cascada 18 módulos, 208K+ registros, deploy Azure |
| Tracker | https://spiky-troodon-8c7.notion.site/Ecosistema-de-Inteligencia-de-Datos-OPTICOLOR-34160202e30080dea80dc9cd5965b150 |
| Repositorio | https://github.com/visioflowtech/opticolor-bi |
| Informe Ejecutivo | INFORME_EJECUTIVO_SEMANA2.md + TRACKING_ALCANCES_PROYECTO.md |

---

## Stack: Gesvision API → ETL Python → Azure SQL → Power BI + Portal Next.js

| Capa | Tech | Propósito |
|------|------|----------|
| 1 | Gesvision API | Sistema transaccional óptica |
| 2 | Python + Azure | ETL (18 módulos, 8x/día) |
| 3 | Azure SQL | Data warehouse (34 tablas: 23 base + 8 seguridad + 2 control + 1 parámetros) — 208K+ registros ✅ |
| 4A | Power BI | 5 informes (2 usuarios licencia) |
| 4B | Next.js 16 | Portal sin licencia (5+ usuarios) — Vercel |

---

## ⭐ FUENTES DE VERDAD (LEER PRIMERO CADA SESIÓN)

### 1. PROYECTO OPTICOLOR.pdf — TRACKER PRINCIPAL
- Estado actual por semana (tipo Notion)
- Tareas completadas ✅, en progreso ↻, pendientes —
- **ÚSALO PARA:** Saber qué está done, qué sigue

### 2. claude.md (ESTE ARCHIVO) — CONTEXTO PERMANENTE
- Arquitectura, convenciones, tablas, roles
- Variables env, schedule CRON, 5 informes
- **ÚSALO PARA:** No perder contexto sesión a sesión

### 3. HOJA DE RUTA — PLAN 6 SEMANAS
- Fases, dependencias, bloqueadores
- **ÚSALO PARA:** Entender qué bloquea qué

### 4. Optilux panama Documento Técnico DB v2.0 — VISTAS REFERENCIA
- ✅ YA TIENE vistas Dim_*, Fact_* que funcionan en Panamá
- ✅ COPIAREMOS Y ADAPTAREMOS a Venezuela
- **ÚSALO PARA:** Estructura vistas, cálculos, nomenclatura

### 5-7. Propuesta Comercial, Contrato, Docs — REFERENCIAS
- KPIs, segmentos, T&C legales

---

## SQL: Estructura Base Completamente Poblada ✅

### 34 Tablas (23 base + 8 seguridad + 2 control ETL + 1 parámetros)

**Maestros (8):** Sucursales, Empleados, Clientes, Categorias, Marcas, Productos, Proveedores, Metodos_Pago

**Transaccionales (6):** Ventas_Cabecera, Ventas_Pedidos, Finanzas_Cobros, Finanzas_Tesoreria, Clinica_Examenes, Marketing_Citas

**Operacionales (4):** Operaciones_Ordenes_Cristales, Operaciones_Inventario, Operaciones_Pedidos_Laboratorio, Operaciones_Recepciones_Lab

**Geografía (3):** Param_Venezuela_Estados (24), Param_Venezuela_Municipios (256), Param_Venezuela_Parroquias (preparada)

**Seguridad (8) ✨ NUEVAS:**
- Seguridad_Usuarios (bcrypt hash)
- Seguridad_Roles (7 roles: SUPER_ADMIN → PORTAL_SERVICE)
- Seguridad_Permisos (VER_INFORME_*, ADMIN_USUARIOS, EXPORTAR_DATOS)
- Seguridad_Roles_Permisos, Seguridad_Usuarios_Roles (relaciones)
- Seguridad_Usuarios_Sucursales (RLS data)
- Seguridad_Sesiones (JWT tracking)
- Seguridad_Auditoria (log inmutable)
- Param_Modulos (catálogo módulos)

**Control ETL (2):** Etl_Control_Ejecucion, Etl_Checkpoints

### Vistas (5)

**Seguridad:**
- Vw_Usuario_Accesos (usuario + roles + sucursales para NextAuth)
- Vw_RLS_Sucursales (filtra data automáticamente por usuario)

**Geografía:**
- Dim_Sucursales, Dim_Estados_Venezuela, Dim_Municipios_Venezuela

### ESTADO ACTUAL (23/ABRIL/2026)

✅ Estructura completa con 34 tablas compilada y poblada
✅ 208,346 registros sincronizados desde Gesvision (INCREMENTAL 3 días)
✅ ETL cascada 18 módulos ejecutándose automáticamente 8x/día (CRON timer)
✅ Documentación: ESTRUCTURA_COMPLETA_DB.sql + sql-vistas-bi.md para agentes
⏳ Vistas Dim_*, Fact_* para BI se crean Semana 3 (copiar Optilux Panamá + adaptar)
⏳ Power BI: 5 informes Semana 4
⏳ Portal Next.js: APIs + dashboards Semana 5
⏳ UAT + Go-live: Semana 6

---

## RBAC: 7 Roles Jerárquicos

```
1. SUPER_ADMIN    → Gerardo (VisioFlow) — Acceso total
2. ADMIN          → Eduardo/Reinaldo (Gerencia) — Todos informes
3. GERENTE_ZONA   → Jefe zona — Su región
4. SUPERVISOR     → Jefe sucursal — Su sucursal
5. CONSULTOR      → Asesor/optometrista — Solo lectura
6. ETL_SERVICE    → Cuenta SQL ETL (escritura)
7. PORTAL_SERVICE → Cuenta SQL Portal (lectura)
```

**RLS:** Vista Vw_RLS_Sucursales filtra automáticamente por usuario

---

## ETL: 18 Módulos, 8x/día ✅

**Schedule CRON (ACTIVO):** `"0 30 6,8,10,12,14,16,18,20 * * *"` 
→ **Horario Venezuela:** 6:30, 8:30, 10:30, 12:30, 14:30, 16:30, 18:30, 20:30 (UTC-4)

**Modo:** ✅ INCREMENTAL (últimos 3 días) — checkpoints en Etl_Checkpoints

**Módulos (18/18):** SUCURSALES, EMPLEADOS, CATEGORÍAS, MÉTODOS_PAGO, PROVEEDORES, MARCAS, PRODUCTOS, CLIENTES, CITAS, EXÁMENES, PEDIDOS, ÓRDENES_CRISTALES, **VENTAS**, **COBROS**, TESORERÍA, PEDIDOS_LAB, RECEPCIONES_LAB, **INVENTARIO**

**Notificaciones:** ✅ Iniciado, ✅ Completado, ❌ Error (Telegram)

**Deploy:** ✅ Azure Functions Production (EtlOrquestadorPrincipal activo)

**Monitoreo:** EVIDENCIA_CARGA_DATA.sql + VALIDACION_CRON_8_30.sql validados post-ejecución

---

## Power BI: 5 Informes (Copiar Optilux, adaptar)

1. **Resumen Comercial** — Venta, Cobrados, Ticket, Run Rate, OTIF
2. **Eficiencia Órdenes** — Órdenes, En proceso, Días entrega
3. **Control Cartera** — Facturado, Recaudado, Saldo
4. **Desempeño Clínico** — Exámenes, % Conversión, Productividad
5. **Inventario** — Stock, Capital, Unidades por segmento, UPT

**Segmentos:** Luxury / Intermedias / Be Diferent (+ Lentes Contacto)

---

## Portal: Estructura Semana 2 ✅

**Next.js 16.2.4 (App Router)** — Deployado en Vercel

### Cambios recientes (20 abril):
- ✅ Importes relativos corregidos (`../../../config/auth`, `../../../lib/types`)
- ✅ SessionProvider moved to client component (`components/SessionWrapper.tsx`)
- ✅ Mock data types fixed (ResumenComercialRow, EficienciaOrdenesRow, etc.)
- ✅ 5 Dashboard pages + API routes compilando sin errores
- ✅ Build exitoso (next build)
- ⚠️ Dev mode (Turbopack) tiene issues → usando Vercel para testing visual

**Estructura directorios:**
```
portal/
  app/
    api/auth/[...nextauth]/route.ts
    api/data/{resumen-comercial, eficiencia-ordenes, control-cartera, desempenio-clinico, inventario}/route.ts
    auth/login/page.tsx
    dashboard/
      page.tsx
      {eficiencia-ordenes, control-cartera, desempenio-clinico, inventario}/page.tsx
    components/{navbar, sidebar, dashboard, SessionWrapper}.tsx
    config/auth.ts (mock NextAuth)
    lib/types.ts (TypeScript interfaces)
```

## Agentes Especializados (`.claude/agents/`)

- `sql-datamodel.md` → DDL, vistas, nomenclatura, RLS
- `security.md` → RBAC, NextAuth, auditoría
- `etl-azure.md` → Python, Azure, CRON, Telegram
- `portal-nextjs.md` → Next.js, API routes, Tailwind
- `powerbi.md` → DAX, KPIs, segmentos
- `qa.md` → Testing, criterios aceptación
- `optica-negocio.md` → Glosario, reglas negocio
- `azure-cloud.md` → Infrastructure, CI/CD, Vercel

---

## Variables de Entorno (NO Commitar)

**ETL:** GESVISION_*, SQL_AZURE_CONNECTION_STRING, TELEGRAM_*
**Portal:** DATABASE_URL, NEXTAUTH_SECRET

---

## 📋 Datos de Opticolor (ESTADOS)

| # | Dato | Status | Uso | Bloqueador |
|---|------|--------|-----|-----------|
| 1 | **Lista usuarios operacionales** (nombre, email, sucursal) | ⏳ | Crear ADMIN, SUPERVISOR en SQL | Semana 3-4 |
| 2 | **Estructura zonas/regiones geográficas** | ⏳ | Asignar usuarios → sucursales (RLS) | Semana 3 |
| 3 | **Sucursales activas** (nombre, ciudad, estado) | ✅ | 28 sucursales ya en BD | Resuelto |
| 4 | **Logo PNG** (fondo transparente) | ⏳ | Portal Next.js + Power BI branding | Semana 5 |
| 5 | **Paleta colores / manual marca** | ⏳ | Tailwind CSS variables, diseño Portal | Semana 5 |
| 6 | **Credenciales Gesvision API** (usuario/pass) | ✅ | Testing ETL, validación endpoints | Resuelto ✅ |
| 7 | **Catálogos maestros** (Marcas, Productos, Categorías) | ✅ | 143,882 productos ya en BD | Resuelto ✅ |
| 8 | **Investigación Marketing_Citas** | ⏳ | 0 registros en API — ¿habilitado? | Semana 3 |

**Nota:** No hay bloqueadores críticos. ETL y BD operativos con datos históricos desde 01/01/2025.

---

## Instrucciones Críticas

✅ SIEMPRE:
- Leer PROYECTO OPTICOLOR.pdf + HOJA DE RUTA + INFORME_EJECUTIVO_SEMANA1.md antes de empezar
- Consultar Optilux schema para vistas referencia
- Mantener nomenclatura SQL (Maestro_*, Seguridad_*, etc.)
- Agregar auditoría (fecha_carga_etl, usuario_creacion)
- **Revisar tabla de datos pendientes antes de Semana 2**

❌ NUNCA:
- Inventar URLs
- Modificar SQL sin revisar Optilux referencia
- Commitear .env, passwords, secretos
- Cambiar nomenclatura sin actualizar vistas
- Crear usuarios sin confirmación Opticolor

---

**Última actualización:** 23 de abril de 2026 (ETL Semana 2 completada)  
**Versión:** 2.0  
**Estado:** Semana 2/6 ✅ COMPLETADA — ETL cascada operativo, 208K+ registros, deploy Azure

---

## Documentación Organizada

Todos los .md iterativos están en `/docs/`:
- INFORME_EJECUTIVO_SEMANA1.md
- RESUMEN_CONTEXTO_ACTUALIZADO.md
- CHECKLIST_SEMANA2.md
- SOLICITUD_DATOS_OPTICOLOR.md
- Y otros de sesiones anteriores

Mantener raíz limpia: solo README.md + claude.md
