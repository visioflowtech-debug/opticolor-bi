# 🎯 Opticolor BI — Ecosistema de Inteligencia de Datos Venezuela

## Identidad del Proyecto

| Campo | Valor |
|-------|-------|
| **Cliente** | OPTI-COLOR #2, C.A. — Venezuela |
| **Contacto Cliente** | Eduardo Martínez (Emartinez@grupoopticolor.com), Reinaldo José Rangel (Director General) |
| **Proveedor** | VisioFlow — Gerardo Argueta (visioflow.tech@gmail.com) |
| **Período** | 14 abril 2026 — 26 mayo 2026 (6 semanas) |
| **Estado** | En Desarrollo (Semana 1-2) |
| **Repositorio** | https://github.com/visioflowtech/opticolor-bi |
| **Propuesta Comercial** | Versión 1.2 (06/04/2026) |

---

## Stack Tecnológico

**Flujo completo:** Gesvision API → ETL Python → Azure SQL → Power BI + Portal Next.js

| Capa | Tecnología | Propósito |
|------|-----------|----------|
| 1. Fuente | Gesvision API | Sistema transaccional óptica |
| 2. ETL | Python + Azure Container Apps | Extracción, transformación, carga (18 módulos, 8x/día) |
| 3. Datos | Azure SQL Database (Tier Basic) | Data warehouse centralizado (23+8 tablas) |
| 4A. BI Ejecutiva | Power BI Service | 5 informes para gerencia (2 usuarios con licencia) |
| 4B. BI Portal | Next.js 14 + TypeScript | Portal propio sin licencia (5+ usuarios) |

**Autenticación:** NextAuth.js (credenciales locales, no OAuth)  
**RBAC:** 6 roles jerárquicos desde SUPER_ADMIN hasta CONSULTOR  
**Monitoreo:** Telegram Bot (notificaciones ETL en tiempo real)

---

## Estructura de Carpetas

```
c:\opticolor-bi\
├── .claude/
│   ├── settings.json
│   └── agents/                  ← NUEVO: 8 agentes especializados
├── docs/                        ← Documentación de referencia (7 PDFs)
├── etl/                         ← Python ETL (2,983 líneas, 18 módulos)
├── portal/                      ← Next.js (vacío, a crear)
├── sql/                         ← T-SQL (23 tablas existentes + 8 nuevas seguridad)
├── claude.md                    ← ESTE ARCHIVO (fuente de verdad)
├── README.md
└── ADAPTACION_OPTICOLOR.md
```

---

## ETL: Módulos y Schedule

**Archivo:** `etl/function_app.py` (2,983 líneas)

**18 módulos en secuencia:**
1. sync_dimensions — Sucursales, Empleados, Clientes, Categorías, Marcas, Productos, Proveedores, Métodos Pago
2. sync_invoices_incremental — Ventas con checkpoint
3. sync_collections — Cobros
4. sync_treasury — Tesorería
5. sync_orders — Pedidos de venta
6. sync_brands_full — Marcas (carga completa)
7. sync_products — Productos (completa)
8. sync_categories — Categorías
9. sync_glasses_orders — Órdenes de cristales (Rx óptica)
10. sync_inventory — Stock
11. sync_laboratory_orders — Pedidos laboratorio
12. sync_received_delivery_notes — Recepciones
13. sync_exams — Exámenes clínicos
14. sync_appointments — Citas
15-18. Módulos operacionales adicionales

**CRON:** `"0 50 0,2,12,14,16,18,20,22 * * *"` → 8 veces/día (07:50, 09:50, ... 21:50 UTC-5)

**Modo:** INCREMENTAL (checkpoints en `Etl_Checkpoints`)

**Notificaciones Telegram:** ✅ Iniciado, ✅ Completado, ❌ Error

---

## Portal Web: RBAC y RLS

**Autenticación:** NextAuth.js credenciales → tabla `Seguridad_Usuarios` (bcrypt password_hash)

**6 Roles:**
```
1. SUPER_ADMIN     → Gerardo (VisioFlow) — Acceso total
2. ADMIN           → Eduardo/Reinaldo (Gerencia Nacional) — Todos informes, todas sucursales
3. GERENTE_ZONA    → Jefes de zona — Informes 1,3,4,5 + su zona
4. SUPERVISOR      → Jefe sucursal — Informes 1,3,4,5 + su sucursal
5. CONSULTOR       → Asesor/optometrista — Solo lectura + su sucursal
6. ETL_SERVICE     → Cuenta servicio ETL (SQL escritor)
7. PORTAL_SERVICE  → Cuenta servicio Portal (SQL lector)
```

**RLS:** Vista `Vw_RLS_Sucursales` filtra datos automáticamente por usuario

**Permisos granulares:** VER_INFORME_1, VER_INFORME_2, ..., ADMIN_USUARIOS, EXPORTAR_DATOS

---

## Power BI: 5 Informes

**Todos incluyen segmentos comerciales:** Luxury / Intermedias / Be Diferent

1. **Resumen Comercial** — Venta, Cobros, Ticket, Run Rate, OTIF, Clientes Nuevos
2. **Eficiencia de Órdenes** — Órdenes hoy/mes, En proceso, Días entrega, Crítico
3. **Control de Cartera** — Facturado, Recaudado, Saldo, Cartera por sucursal
4. **Desempeño Clínico** — Exámenes, % Conversión, Productividad, Demográfica
5. **Inventario** — Stock, Capital invertido, Unidades por segmento, Eficiencia

---

## Tablas SQL

**23 existentes:**
- Maestro_* (8 dimensiones)
- Ventas_* (2 transaccionales)
- Operaciones_* (4 laboratorio/inventario)
- Clinica_*, Marketing_* (2 clínica)
- Finanzas_* (2 cobros/tesorería)
- Etl_* (2 control)
- Param_Venezuela_* (3 geografía: Estados, Municipios, Parroquias)

**8 NUEVAS de seguridad (a crear):**
- Seguridad_Usuarios, Seguridad_Roles, Seguridad_Permisos, Seguridad_Roles_Permisos
- Seguridad_Usuarios_Roles, Seguridad_Usuarios_Sucursales, Seguridad_Sesiones, Seguridad_Auditoria
- Param_Modulos (catálogo de módulos para permisos)

---

## Variables de Entorno

**ETL:** `GESVISION_*`, `SQL_AZURE_CONNECTION_STRING`, `TELEGRAM_BOT_TOKEN`, `TELEGRAM_CHAT_ID`

**Portal:** `DATABASE_URL`, `NEXTAUTH_SECRET`

**NUNCA commitar:** `.env*`, `local.settings.json`, archivos con secretos

---

## Bloqueos Activos

1. ⏳ Pago inicial ($900) — Gerencia próxima confirmación
2. ⏳ Licencias Power BI Service — Eduardo confirma cantidad
3. 🔄 Estructura usuarios/roles — Implementando SQL esta semana
4. ⏳ Portal Next.js — Inicia Semana 2

---

## Instrucciones Críticas para Claude

✅ **SIEMPRE:**
- Leer `PROYECTO OPTICOLOR.pdf` antes de iniciar feature
- Revisar `HOJA DE RUTA` para estado actual
- Mantener nomenclatura SQL (Maestro_*, Seguridad_*, etc.)
- Agregar auditoría (fecha_carga_etl, usuario_creacion, etc.)
- Documentar cambios en ADAPTACION_OPTICOLOR.md

❌ **NUNCA:**
- Inventar URLs — usar doc referencias reales
- Crear tablas sin consultar schema referencia Panamá
- Commitear secretos (.env, passwords, tokens)
- Cambiar nombres SQL sin actualizar vistas Dim_*/Fact_*

---

**Última actualización:** 17 de abril de 2026  
**Versión:** 1.0  
**Estado:** Listo para Desarrollo
