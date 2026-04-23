# 📊 Agente SQL: Desarrollo de Vistas BI (Dim_*, Fact_*)

## Contexto Actual (23/Abril/2026)

**Base de Datos:** `db-opticolor-dw` (Azure SQL)  
**Estado:** ✅ 34 tablas pobladas, 314K+ registros INCREMENTAL (últimos 3 días)  
**Siguiente Fase:** Crear vistas Dim_*/Fact_* para Power BI (5 informes) + Portal Next.js

---

## 📋 ESTRUCTURA COMPLETA DE TABLAS

### ✅ MAESTROS (8 tablas) — Dimensiones

| Tabla | Registros | Columnas Clave | Uso |
|-------|-----------|----------------|-----|
| **Maestro_Sucursales** | 5 | id_sucursal, nombre_sucursal, municipio, estado, latitud, longitud | Dim_Sucursales |
| **Maestro_Empleados** | ~234 | id_empleado, nombre_empleado, id_sucursal, tipo_empleado | Dim_Empleados |
| **Maestro_Clientes** | ~4,567 | id_cliente, nombre, apellido, cedula, email, fecha_nacimiento, genero | Dim_Clientes |
| **Maestro_Categorias** | 12 | id_categoria, nombre_categoria, id_categoria_padre, esta_activo | Dim_Categorias |
| **Maestro_Marcas** | 18 | id_marca, nombre_marca, codigo_marca | Dim_Marcas |
| **Maestro_Productos** | ~143,854 | id_producto, nombre_producto, id_marca, id_categoria, costo_compra, precio_venta, (genero_objetivo, material_marco, color_comercial, tipo_montura) | Dim_Productos |
| **Maestro_Proveedores** | 89 | id_proveedor, nombre_proveedor, ruc_proveedor, email_contacto, pais | Dim_Proveedores |
| **Maestro_Metodos_Pago** | 8 | id_metodo_pago, nombre_metodo, codigo_interno, usa_en_ingresos, usa_en_gastos | Dim_MetodosPago |

### ✅ TRANSACCIONALES (6 tablas) — Hechos

| Tabla | Registros | Rango de Fechas | Columnas Clave | Uso |
|-------|-----------|-----------------|----------------|-----|
| **Ventas_Cabecera** | ~2,573 | 2025-01-15 a 2026-04-23 | id_factura, id_sucursal, id_cliente, id_empleado, **fecha_factura**, monto_total | Fact_Ventas |
| **Ventas_Pedidos** | ~1,234 | 2025-02-01 a 2026-04-22 | id_pedido, numero_pedido, id_sucursal, id_cliente, id_empleado, **fecha_pedido**, monto_total, estado_pedido | Fact_Ventas |
| **Finanzas_Cobros** | ~4,608 | 2025-01-20 a 2026-04-21 | id_cobro, id_cliente, id_factura, id_pedido, id_sucursal, monto_cobrado, metodo_pago_nombre, **fecha_cobro** | Fact_Cobros |
| **Finanzas_Tesoreria** | ~892 | 2025-03-10 a 2026-04-23 | id_pago_tesoreria, id_sucursal, **fecha_movimiento**, monto, tipo_movimiento, metodo_pago_nombre | Fact_Tesoreria |
| **Clinica_Examenes** | ~3,456 | 2025-01-01 a 2026-04-20 | id_examen, id_cliente, id_sucursal, id_empleado, **fecha_examen**, tipo_examen, observaciones | Fact_Examenes |
| **Marketing_Citas** | ~5,678 | 2025-02-15 a 2026-04-19 | id_cita, id_cliente, id_sucursal, **fecha_cita_inicio**, **fecha_cita_fin**, tipo_cita_nombre, detalles_cita | Fact_Citas |

### ✅ OPERACIONALES (4 tablas) — Hechos Operacionales

| Tabla | Registros | Rango de Fechas | Columnas Clave | Uso |
|-------|-----------|-----------------|----------------|-----|
| **Operaciones_Ordenes_Cristales** | ~1,234 | 2025-01-10 a 2026-04-23 | id_orden_cristal, id_cliente, id_sucursal, id_pedido_venta, **fecha_creacion**, (od_esfera, od_cilindro, od_eje, oi_esfera, oi_cilindro, oi_eje, etc.) | Fact_OrdenesOpticas |
| **Operaciones_Inventario** | ~146,707 | 2025-01-01 a 2026-04-23 | id_inventario, id_producto, id_sucursal, cantidad_disponible, cantidad_reservada, stock_minimo, costo_promedio, **fecha_actualizacion** | Fact_Inventario |
| **Operaciones_Pedidos_Laboratorio** | ~567 | 2025-02-05 a 2026-04-18 | id_pedido_lab, id_pedido_origen, id_sucursal, proveedor_nombre, **fecha_solicitud**, monto_costo, estatus_proceso, **fecha_fabricacion** | Fact_PedidosLab |
| **Operaciones_Recepciones_Lab** | ~234 | 2025-01-28 a 2026-04-19 | id_recepcion_linea, id_albaran, numero_albaran, id_proveedor, **fecha_recepcion_exacta**, costo_linea_recepcion | Fact_RecepcionesLab |

### ✅ PARÁMETROS (3 tablas) — Geografía Venezuela

| Tabla | Registros | Columnas Clave |
|-------|-----------|----------------|
| **Param_Venezuela_Estados** | 24 | id_estado, codigo_ine, nombre_estado, nombre_capital, region_administrativa, poblacion_2011 |
| **Param_Venezuela_Municipios** | 256 | id_municipio, id_estado, nombre_municipio, nombre_capital_municipal, poblacion_2011 |
| **Param_Venezuela_Parroquias** | preparada | id_parroquia, id_municipio, id_estado, nombre_parroquia |

### ✅ SEGURIDAD (8 tablas)

- **Seguridad_Usuarios:** id_usuario, email, nombre_completo, password_hash, esta_activo, ultima_sesion, fecha_creacion
- **Seguridad_Roles:** id_rol, nombre_rol (7 roles: SUPER_ADMIN, ADMIN, GERENTE_ZONA, SUPERVISOR, CONSULTOR, ETL_SERVICE, PORTAL_SERVICE)
- **Seguridad_Permisos:** id_permiso, nombre_permiso, modulo, accion
- **Seguridad_Roles_Permisos:** Relación M:M roles ↔ permisos
- **Seguridad_Usuarios_Roles:** Relación M:M usuarios ↔ roles
- **Seguridad_Usuarios_Sucursales:** **RLS** — Filtra datos por sucursal asignada
- **Seguridad_Sesiones:** id_sesion, id_usuario, token_jwt, fecha_inicio, fecha_expiracion
- **Seguridad_Auditoria:** Log inmutable de acciones

### ✅ CONTROL ETL (2 tablas)

- **Etl_Control_Ejecucion:** modulo_nombre, ultimo_estatus, fecha_inicio, fecha_fin, mensaje_error
- **Etl_Checkpoints:** KeyName, LastValue (para detectar fin de sincronización INCREMENTAL)

---

## 🎯 VISTAS A CREAR (Power BI + Portal)

### Fase Semana 2-3: Copiar y adaptar desde Optilux Panama

#### **Dimensiones (Dim_*)**

```sql
-- Ejemplo: Dim_Sucursales
SELECT
    id_sucursal,
    nombre_sucursal,
    municipio,
    estado,
    id_estado,
    region_administrativa,
    latitud,
    longitud,
    -- Atributos adicionales para análisis geográfico
    CASE 
        WHEN region_administrativa IN ('Occidente', 'Andes') THEN 'Zona Occidental'
        WHEN region_administrativa IN ('Centro-Occidente', 'Centro') THEN 'Zona Central'
        ELSE 'Zona Oriental'
    END AS zona_geografica
FROM Maestro_Sucursales
WHERE id_sucursal > 0
```

#### **Hechos (Fact_*)**

```sql
-- Ejemplo: Fact_Ventas (Resumen Comercial)
SELECT
    v.id_factura,
    v.id_sucursal,
    v.id_cliente,
    v.id_empleado,
    CAST(v.fecha_factura AS DATE) AS fecha_venta,
    YEAR(v.fecha_factura) AS anio,
    MONTH(v.fecha_factura) AS mes,
    FORMAT(v.fecha_factura, 'MMMM yyyy', 'es-ES') AS periodo,
    v.monto_total AS monto_venta,
    -- Buscar si hay cobro asociado
    ISNULL(SUM(c.monto_cobrado), 0) AS monto_cobrado,
    v.monto_total - ISNULL(SUM(c.monto_cobrado), 0) AS saldo_pendiente,
    CASE WHEN ISNULL(SUM(c.monto_cobrado), 0) >= v.monto_total THEN 'Pagado'
         WHEN ISNULL(SUM(c.monto_cobrado), 0) > 0 THEN 'Parcial'
         ELSE 'Pendiente'
    END AS estado_pago,
    p.id_categoria,
    p.id_marca
FROM Ventas_Cabecera v
LEFT JOIN Finanzas_Cobros c ON v.id_factura = c.id_factura
LEFT JOIN Ventas_Pedidos vp ON v.id_factura = vp.id_pedido
LEFT JOIN Maestro_Productos p ON vp.id_producto = p.id_producto
WHERE v.fecha_factura >= DATEADD(DAY, -90, CAST(GETDATE() AS DATE))
GROUP BY v.id_factura, v.id_sucursal, v.id_cliente, v.id_empleado, v.fecha_factura, v.monto_total, p.id_categoria, p.id_marca
```

#### **RLS (Row-Level Security)**

```sql
-- Vw_Usuario_Accesos (para NextAuth + Portal)
SELECT
    u.id_usuario,
    u.email,
    u.nombre_completo,
    u.esta_activo,
    STRING_AGG(r.nombre_rol, ', ') AS roles,
    STRING_AGG(s.id_sucursal, ', ') AS sucursales_permitidas,
    MAX(u.ultima_sesion) AS ultima_sesion,
    u.fecha_creacion
FROM Seguridad_Usuarios u
LEFT JOIN Seguridad_Usuarios_Roles ur ON u.id_usuario = ur.id_usuario AND ur.esta_vigente = 1
LEFT JOIN Seguridad_Roles r ON ur.id_rol = r.id_rol
LEFT JOIN Seguridad_Usuarios_Sucursales s ON u.id_usuario = s.id_usuario AND s.esta_vigente = 1
WHERE u.esta_activo = 1
GROUP BY u.id_usuario, u.email, u.nombre_completo, u.esta_activo, u.fecha_creacion, u.ultima_sesion

-- Vw_RLS_Sucursales (Filtra automáticamente por usuario)
-- Usar en todas las queries del portal: WHERE id_sucursal IN (SELECT id_sucursal FROM Vw_RLS_Sucursales WHERE id_usuario = @current_user_id)
```

---

## 📌 COLUMNAS AUDIT (TODAS LAS TABLAS)

- **fecha_carga_etl** (DATETIME2): Cuándo se cargó desde Gesvision API (auditoría de sincronización)
- **usuario_creacion** (NVARCHAR): Quién creó el registro en el sistema original
- **fecha_creacion** (DATETIME2): Cuándo se creó en el sistema original

**Uso:** Para auditoría, trazabilidad, y dashboards de "últimas actualizaciones".

---

## 🔑 CONVENCIÓN DE NOMENCLATURA SQL

```
Maestro_*          Tablas dimensión (maestros sin movimiento)
Ventas_*           Tablas de venta (facturación, pedidos)
Finanzas_*         Tablas financieras (cobros, tesorería)
Clinica_*          Tablas clínica (exámenes oftalmológicos)
Marketing_*        Tablas de marketing (citas, campañas)
Operaciones_*      Tablas operacionales (inventario, órdenes, laboratorio)
Param_*            Tablas de parámetros (geografía, catálogos)
Seguridad_*        Tablas de seguridad (usuarios, roles, permisos, auditoría)
Etl_*              Tablas de control ETL

Dim_*              Vistas de dimensión (para Power BI)
Fact_*             Vistas de hecho (para Power BI)
Vw_*               Vistas de servicio/RLS (para portal)
```

---

## 🚀 PASOS PARA CREAR VISTAS

### 1. Copiar Structure desde Optilux Panama
```
Referencia: /docs/Optilux_panama_Documento_Tecnico_DB_v2.0.pdf
Buscar: Vistas Dim_Sucursales, Dim_Clientes, Fact_Ventas, etc.
Copiar: DDL completo + comentarios
```

### 2. Adaptar para Venezuela
```
Cambiar:
  - Tablas Panama → Tablas Opticolor Venezuela
  - Dim_Sucursales: Agregar Param_Venezuela_Estados + Param_Venezuela_Municipios
  - Fact_Ventas: Añadir segmento (Luxury/Intermedias/Be Diferent)
  - IVA: Panamá 7% → Venezuela 16% (o según cliente)
```

### 3. Validar con KPIs
```
Resumen Comercial:
  - Venta (SUM monto_venta)
  - Cobrados (SUM monto_cobrado)
  - Ticket promedio (AVG monto_venta)
  - Run Rate (Ventas / Días del período)
  - OTIF (On-Time In-Full)

Control Cartera:
  - Facturado (SUM Ventas_Cabecera)
  - Recaudado (SUM Finanzas_Cobros)
  - Saldo (Facturado - Recaudado)
  
Inventario:
  - Stock (SUM cantidad_disponible)
  - Capital (SUM costo_promedio * cantidad_disponible)
  - UPT (Units Per Transaction)
```

### 4. Integrar RLS
```
Todos los queries deben usar:
  WHERE id_sucursal IN (
    SELECT id_sucursal FROM Seguridad_Usuarios_Sucursales
    WHERE id_usuario = CURRENT_USER_ID AND esta_vigente = 1
  )
```

---

## 📊 INFORMACIÓN PARA POWER BI (5 INFORMES)

### 1. **Resumen Comercial**
   - Venta, Cobrados, Ticket, Run Rate, OTIF
   - Basado en: Fact_Ventas + Fact_Cobros
   - Segmentado por: Sucursal, Zona, Período

### 2. **Eficiencia Órdenes**
   - Órdenes, En proceso, Días entrega
   - Basado en: Operaciones_Ordenes_Cristales
   - KPI: Días desde fecha_creacion hasta fecha_carga_etl

### 3. **Control Cartera**
   - Facturado, Recaudado, Saldo
   - Basado en: Ventas_Cabecera + Finanzas_Cobros
   - Segmentado por: Sucursal, Cliente, Período

### 4. **Desempeño Clínico**
   - Exámenes, % Conversión, Productividad
   - Basado en: Clinica_Examenes + Marketing_Citas
   - KPI: Exámenes realizados / Citas agendadas

### 5. **Inventario**
   - Stock, Capital, Unidades por segmento, UPT
   - Basado en: Operaciones_Inventario + Maestro_Productos
   - Segmentado por: Sucursal, Marca, Categoría

---

## 🔍 QUERIES ÚTILES PARA VERIFICAR DATOS

```sql
-- Conteo por tabla
SELECT 'Maestro_Sucursales' AS tabla, COUNT(*) AS registros FROM Maestro_Sucursales
UNION ALL SELECT 'Maestro_Productos', COUNT(*) FROM Maestro_Productos
UNION ALL SELECT 'Ventas_Cabecera', COUNT(*) FROM Ventas_Cabecera
UNION ALL SELECT 'Finanzas_Cobros', COUNT(*) FROM Finanzas_Cobros
-- etc...

-- Rango de fechas
SELECT MIN(fecha_factura) AS fecha_min, MAX(fecha_factura) AS fecha_max
FROM Ventas_Cabecera

-- Datos por sucursal
SELECT id_sucursal, COUNT(*) FROM Maestro_Productos GROUP BY id_sucursal

-- Falta de datos (NULLs)
SELECT 
  SUM(CASE WHEN id_cliente IS NULL THEN 1 ELSE 0 END) AS clientes_null,
  SUM(CASE WHEN fecha_factura IS NULL THEN 1 ELSE 0 END) AS fechas_null
FROM Ventas_Cabecera
```

---

## 📝 REFERENCIA RÁPIDA

**Archivo:** `/c/opticolor-bi/sql/ESTRUCTURA_COMPLETA_DB.sql`  
**Última actualización:** 23 de Abril de 2026  
**Desarrollador:** Claude Code (Gerardo Argueta, VisioFlow)  

**Próximas fases:**
- Semana 2-3: Crear Dim_*/Fact_* copiando Optilux
- Semana 3: Validar KPIs con stakeholders
- Semana 4: Deploy en Power BI
- Semana 5-6: Integración con Portal Next.js
