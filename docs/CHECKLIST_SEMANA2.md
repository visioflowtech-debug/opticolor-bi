# ✅ Checklist Semana 2 — Portal + Vistas + ETL
**Del 18 al 24 de abril de 2026**

---

## 🎯 Objetivos Semana 2

| Objetivo | Prioridad | Dependencia | Estado |
|----------|-----------|------------|--------|
| Setup Portal Next.js base + Login | ALTA | Branding (logo/colores) | ⏳ BLOQUEADO |
| Copiar y adaptar vistas Dim_*/Fact_* | ALTA | Optilux Panama PDF | ⏳ EN PROGRESO |
| Validar ETL con Gesvision API | ALTA | Credenciales API | ⏳ BLOQUEADO |
| Setup CRON scheduler Azure | MEDIA | ETL validación | ⏳ BLOQUEADO |
| Crear usuarios operacionales | MEDIA | Lista Opticolor | ⏳ BLOQUEADO |

---

## 📋 Checklist: DATOS REQUERIDOS DE OPTICOLOR

### URGENTE (Si no llega, Semana 2 no arranca):

- [ ] **Logo PNG** (fondo transparente, min 500x500px)
  - Para: Portal header, Power BI branding
  - Fallback: Descargar de https://www.opticolor.com.ve/

- [ ] **Paleta de colores** (código hex: primario, secundario, neutral)
  - Ejemplos: `#1B3FA8` (azul), `#F5F5F5` (gris claro)
  - Para: Tailwind CSS config, gráficos Power BI
  - Fallback: Usar colores estándar óptica

- [ ] **Credenciales Gesvision API**
  - Usuario: ___________
  - Contraseña: ___________
  - Para: Validar módulos ETL (EtlVentasCabecera, EtlMaestroClientes, etc.)

### IMPORTANTE (Semana 2 avanzada):

- [ ] **Lista usuarios operacionales iniciales**
  - Formato: nombre | email | rol (ADMIN/SUPERVISOR/CONSULTOR) | sucursal(es)
  - Ejemplo:
    ```
    Eduardo Martínez | eduardo@opticolor.com | ADMIN | Nacional
    Juan Pérez | juan.perez@opticolor.com | SUPERVISOR | Caracas, Los Teques
    María López | maria@opticolor.com | CONSULTOR | Caracas
    ```
  - Para: INSERT Seguridad_Usuarios, asignar roles y sucursales

- [ ] **Estructura zonas/regiones geográficas**
  - ¿Están agrupadas por estado? ¿Por región comercial? ¿Jerarquía?
  - Ejemplo:
    ```
    Zona Centro: Caracas, Miranda, Vargas
    Zona Occidente: Zulia, Falcón, Lara, Yaracuy
    Zona Andes: Mérida, Táchira, Trujillo
    ```
  - Para: Filtros Portal, reportes por zona

- [ ] **Sucursales activas exactas**
  - Formato: Nombre | Ciudad | Estado | Municipio
  - Ejemplo:
    ```
    Opticolor Caracas Centro | Caracas | Distrito Capital | Libertador
    Opticolor Los Teques | Los Teques | Miranda | Los Teques
    Opticolor Valencia | Valencia | Carabobo | Valencia
    ```
  - Para: INSERT Maestro_Sucursales, RLS filtrado

- [ ] **Catálogos maestros actuales**
  - Marcas (Ray-Ban, Gucci, Prada, Be Diferent, etc.)
  - Productos (modelos lentes, precios)
  - Categorías (Luxury, Intermedias, Be Diferent, Contactos)
  - Para: INSERT inicial Maestro_Marcas, Maestro_Productos, Maestro_Categorias

---

## 🛠️ Tareas Internas (No Bloqueadas)

### Hito 1: Portal Next.js Base (Miércoles 22 abril)
**Responsable:** Portal Expert Agent

- [ ] **Crear estructura proyecto**
  ```bash
  npx create-next-app@latest apps/portal --typescript --tailwind
  ```
  - Carpeta: `/apps/portal/`
  - Node 18+, TypeScript, Tailwind CSS, App Router

- [ ] **Instalar dependencias seguridad**
  - `next-auth` v5 (credenciales provider)
  - `bcryptjs` (verificar password)
  - `@prisma/client` (ORM opcional, si lo usamos)

- [ ] **Crear archivo `.env.local.example`**
  ```env
  DATABASE_URL=...
  NEXTAUTH_SECRET=...
  NEXTAUTH_URL=http://localhost:3000
  ```

- [ ] **Configurar NextAuth.js**
  - Provider: Credenciales (email/password)
  - Callback: Validar contra `Seguridad_Usuarios`
  - Verificar password hasheado
  - JWT session con 30 min expiry

- [ ] **Crear Login Page** (`/login`)
  - Form: email + password
  - Error: "Credenciales inválidas"
  - Success: Redirige a `/dashboard`

- [ ] **Crear Dashboard layout**
  - Sidebar con módulos de `Param_Modulos`
  - Topbar con usuario + logout
  - Mock: Placeholder para 5 informes

- [ ] **Integración SQL**
  - Query: SELECT usuario + roles desde `Vw_Usuario_Accesos`
  - Aplicar RBAC: mostrar solo módulos según `Seguridad_Permisos`

---

### Hito 2: Vistas Dim_*/Fact_* Iniciales (Jueves 23 abril)
**Responsable:** SQL DataModel Agent

- [ ] **Leer Optilux Panama PDF**
  - Buscar sección: "Vistas de Análisis" o "Dim_*, Fact_*"
  - Copiar DDL vistas

- [ ] **Crear vistas Venezuela iniciales**
  - `Dim_Sucursales` — Sucursal + municipio + estado + zona
  - `Dim_Clientes` — Cliente + segmento (Luxury/Intermedias/Be Diferent)
  - `Dim_Productos` — Producto + categoría + precio
  - `Fact_Ventas` — Cabecera + detalle + margen

- [ ] **Adaptar cálculos a Venezuela**
  - OTIF = (Entregas On-Time / Total) × 100
  - Run Rate = (Venta_Diaria × Días_Mes)
  - % Conversión = (Con Compra / Exámenes) × 100

- [ ] **Testing queries**
  - `SELECT COUNT(*) FROM Dim_Sucursales` > 0
  - `SELECT COUNT(*) FROM Fact_Ventas` > 0
  - Validar joins no causen duplicados

- [ ] **Commit SQL**
  ```bash
  git add sql/setup_opticolor_venezuela.sql
  git commit -m "feat: vistas Dim_*/Fact_* iniciales adaptadas de Optilux Panama"
  ```

---

### Hito 3: ETL Validación (Viernes 24 abril)
**Responsable:** ETL Azure Agent + Blocking: Credenciales API

- [ ] **Validar endpoints Gesvision** (requiere credenciales)
  - Test: GET /sales (últimos 30 días)
  - Test: GET /clients (lista clientes)
  - Test: GET /products (lista productos)

- [ ] **Ejecutar módulo EtlVentasCabecera manualmente**
  ```bash
  func start  # local
  # Trigger manual o simular webhook
  ```

- [ ] **Verificar datos insertan en SQL**
  - `SELECT COUNT(*) FROM Ventas_Cabecera` > 0

- [ ] **Setup CRON schedule**
  - Provider: Azure Container Apps CRON
  - Schedule: `"0 50 0,2,12,14,16,18,20,22 * * *"` (UTC-5)
  - Telegram notification: ✅ Iniciado, ✅ Completado, ❌ Error

- [ ] **Commit Python**
  ```bash
  git add etl/function_app.py
  git commit -m "feat: validación ETL Gesvision + schedule CRON"
  ```

---

### Hito 4: Power BI Inicial (Lunes 28 abril)
**Responsable:** Power BI Expert + Blocking: Vistas BI (Hito 2)

- [ ] **Conectar Power BI a vistas**
  - New source: Azure SQL
  - Tablas: Dim_*, Fact_*

- [ ] **Crear Informe 1: Resumen Comercial**
  - KPI 1: Venta Neta (SUM fact)
  - KPI 2: Total Cobrado (SUM cobros)
  - KPI 3: Ticket Promedio (Venta / Transacciones)
  - KPI 4: Run Rate (Venta × Días_Mes)
  - KPI 5: OTIF (%)
  - Slicers: Fecha, Sucursal, Zona

- [ ] **DAX cálculos**
  ```dax
  Venta_Neta = SUMX(Fact_Ventas, Fact_Ventas[monto] * (1 - Fact_Ventas[desc_porcentaje]/100))
  OTIF = DIVIDE([Entregas_OnTime], [Total_Entregas], 0)
  RunRate = [Venta_Diaria] * DAY(EOMONTH(TODAY(), 0))
  ```

- [ ] **Publicar a Power BI Service**
  - Workspace: opticolor-bi
  - Compartir con 2 usuarios licencia

---

## 📊 Métricas de Éxito Semana 2

| Métrica | Target | Éxito |
|---------|--------|-------|
| Portal login funcional | ✅ | Si NextAuth + SQL OK |
| Vistas BI adaptadas | 5+ vistas | Si Optilux PDF ok |
| ETL primera ejecución | ✅ | Si credenciales Gesvision ok |
| Informe 1 en Power BI | ✅ | Si vistas ok |
| Usuarios operacionales creados | 5+ | Si lista Opticolor ok |

---

## 🔴 Bloqueadores Críticos

| # | Bloqueador | Responsable | Impacto | Mitigación |
|---|-----------|------------|--------|-----------|
| 1 | Credenciales Gesvision API | Opticolor | ETL offline | Mock data para testing |
| 2 | Logo + colores Opticolor | Opticolor | Portal UI no branded | Usar colores placeholder |
| 3 | Lista usuarios operacionales | Opticolor | No se crean roles | Usar test users |
| 4 | Sucursales exactas | Opticolor | RLS incompleto | Usar sucursales mock |

---

## 📧 Comunicación Semana 2

### Miércoles 22 abril (EOD)
- Status: Portal base + login funcional
- To: Eduardo
- Adjuntar: Screenshot login screen

### Viernes 24 abril (EOD)
- Status: Vistas BI + ETL primer test
- To: Eduardo
- Requerimiento: Feedback vistas (¿están correctas fórmulas?)

### Lunes 28 abril (EOD)
- Status: Informe 1 Power BI + usuarios creados
- To: Eduardo + Reinaldo
- Adjuntar: PDF preview Informe 1

---

## 🎯 Próximo Checklist

**Semana 3 (25 april - 1 mayo):**
- [ ] Informe 2-5 Power BI
- [ ] Testing RBAC/RLS end-to-end
- [ ] Portal responsive (mobile 375px)
- [ ] Performance tuning (< 3seg queries)

---

**Estado:** LISTO PARA SEMANA 2  
**Última actualización:** 17 abril 2026  
**Versión:** 1.0
