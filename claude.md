# 🎯 Opticolor BI — Ecosistema de Inteligencia de Datos Venezuela

## Identidad

| Campo | Valor |
|-------|-------|
| Cliente | OPTI-COLOR #2, C.A. — Venezuela |
| Contactos | Eduardo Martínez, Reinaldo José Rangel |
| Proveedor | VisioFlow — Gerardo Argueta |
| Período | 14 abril 2026 — 26 mayo 2026 (6 semanas) |
| Estado | Semana 1-2: Contexto + Seguridad completado ✅ → Semana 2: Portal + Vistas + ETL |
| Tracker | https://spiky-troodon-8c7.notion.site/Ecosistema-de-Inteligencia-de-Datos-OPTICOLOR-34160202e30080dea80dc9cd5965b150 |
| Repositorio | https://github.com/visioflowtech/opticolor-bi |
| Informe Ejecutivo | INFORME_EJECUTIVO_SEMANA1.md (avance semanal) |

---

## Stack: Gesvision API → ETL Python → Azure SQL → Power BI + Portal Next.js

| Capa | Tech | Propósito |
|------|------|----------|
| 1 | Gesvision API | Sistema transaccional óptica |
| 2 | Python + Azure | ETL (18 módulos, 8x/día) |
| 3 | Azure SQL | Data warehouse (31 tablas: 23 base + 8 seguridad) |
| 4A | Power BI | 5 informes (2 usuarios licencia) |
| 4B | Next.js 14 | Portal sin licencia (5+ usuarios) |

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

## SQL: Estructura Base Lista para Compilar

### 31 Tablas (23 base + 8 seguridad)

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

### ITERACIÓN SOBRE LA MARCHA

✅ Estructura base lista para compilar
⏳ Vistas Dim_*, Fact_* para BI se crean Semana 2-3 (copiar Panamá + adaptar)
✅ Permisos compilar SQL YA, feedback BI ayuda refinar vistas

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

## ETL: 18 Módulos, 8x/día, Telegram Monitoreo

**Schedule CRON:** `"0 50 0,2,12,14,16,18,20,22 * * *"` → 07:50-21:50 UTC-5

**Modo:** INCREMENTAL (checkpoints en Etl_Checkpoints)

**Notificaciones:** ✅ Iniciado, ✅ Completado, ❌ Error (Telegram)

---

## Power BI: 5 Informes (Copiar Optilux, adaptar)

1. **Resumen Comercial** — Venta, Cobrados, Ticket, Run Rate, OTIF
2. **Eficiencia Órdenes** — Órdenes, En proceso, Días entrega
3. **Control Cartera** — Facturado, Recaudado, Saldo
4. **Desempeño Clínico** — Exámenes, % Conversión, Productividad
5. **Inventario** — Stock, Capital, Unidades por segmento, UPT

**Segmentos:** Luxury / Intermedias / Be Diferent (+ Lentes Contacto)

---

## Agentes Especializados (`.claude/agents/`)

- `sql-datamodel.md` → DDL, vistas, nomenclatura, RLS
- `security.md` → RBAC, NextAuth, auditoría
- `etl-azure.md` → Python, Azure, CRON, Telegram
- `portal-nextjs.md` → Next.js, API routes, Tailwind
- `powerbi.md` → DAX, KPIs, segmentos
- `qa.md` → Testing, criterios aceptación
- `optica-negocio.md` → Glosario, reglas negocio
- `azure-cloud.md` → Infrastructure, CI/CD

---

## Variables de Entorno (NO Commitar)

**ETL:** GESVISION_*, SQL_AZURE_CONNECTION_STRING, TELEGRAM_*
**Portal:** DATABASE_URL, NEXTAUTH_SECRET

---

## 🚨 Datos Pendientes de Opticolor (BLOQUEADORES SEMANA 2)

Solicitados en mensaje WhatsApp del 17 abril — **Requerido HAYA para continuar sin bloqueos:**

| # | Dato | Status | Uso |
|---|------|--------|-----|
| 1 | **Lista usuarios operacionales** (nombre, email, sucursal) | ⏳ | Crear ADMIN, SUPERVISOR, CONSULTOR en SQL |
| 2 | **Estructura zonas/regiones geográficas** | ⏳ | Asignar usuarios → sucursales (RLS) |
| 3 | **Sucursales activas** (nombre, ciudad, estado) | ⏳ | Maestro_Sucursales, filtros Portal |
| 4 | **Logo PNG** (fondo transparente) | ⏳ | Portal Next.js + Power BI branding |
| 5 | **Paleta colores / manual marca** | ⏳ | Tailwind CSS variables, diseño Portal |
| 6 | **Credenciales Gesvision API** (usuario/pass) | ⏳ | Testing ETL, validación endpoints |
| 7 | **Catálogos maestros** (Marcas, Productos, Categorías) | ⏳ | Insert inicial Maestro_* tablas |
| 8 | **Feedback vistas BI adaptadas** | ⏳ | Refinar Dim_*/Fact_* para KPIs |

**Alternativa branding (si Opticolor no provee):**
- Copiar estilo visual de https://www.opticolor.com.ve/
- Usar colores estándar óptica (azul corporativo, blanco, gris)

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

**Última actualización:** 17 de abril de 2026 (WhatsApp Opticolor)  
**Versión:** 1.2  
**Estado:** Semana 1 Completa — Semana 2 Esperando Datos Opticolor
