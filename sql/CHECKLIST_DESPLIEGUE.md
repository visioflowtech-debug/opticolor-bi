# ✅ CHECKLIST INTERACTIVO — Despliegue Vistas Opticolor Venezuela

**Servidor:** Azure SQL `db-opticolor-dw` (opticolor-visioflow-rg)  
**Fecha estimada:** 20-04-2026  
**Usuario:** Gerardo Argueta (VisioFlow)

---

## 📋 FASE 1: PREPARACIÓN (5 min)

- [ ] **1.1** Conexión a Azure SQL activa en SSMS
  - Verificar: Server explorer > db-opticolor-dw > [verde]
  - Database: opticolor_dw (o según nombre real)
  - Usuario: dbo (o con permisos CREATE VIEW/TABLE)

- [ ] **1.2** Archivos SQL listos localmente
  - [ ] `c:\opticolor-bi\sql\vistas_opticolor_venezuela_LIMPIO.sql`
  - [ ] `c:\opticolor-bi\sql\00_VALIDACION_Y_DESPLIEGUE.sql`

- [ ] **1.3** Documentación disponible
  - [ ] `c:\opticolor-bi\docs\PROTOCOLO_DESPLIEGUE_VISTAS_VENEZUELA.md`

---

## 🔍 FASE 2: VALIDACIÓN PREVIA (10 min)

### PASO 1 — Verificar tablas base

**En SSMS ejecuta:**
```sql
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME IN (
    'Maestro_Sucursales', 'Maestro_Clientes', 'Maestro_Categorias',
    'Maestro_Productos', 'Ventas_Pedidos', 'Ventas_Cabecera', 'Ventas_Detalle',
    'Marketing_Citas', 'Clinica_Examenes', 'Operaciones_Ordenes_Cristales',
    'Operaciones_Recepciones_Lab', 'Finanzas_Cobros', 'Finanzas_Tesoreria',
    'Etl_Control_Ejecucion'
  )
ORDER BY TABLE_NAME;
```

**Resultado esperado:** 14 filas (todas las tablas)

- [ ] **Tabla encontrada:** Maestro_Sucursales
- [ ] **Tabla encontrada:** Maestro_Clientes
- [ ] **Tabla encontrada:** Maestro_Categorias
- [ ] **Tabla encontrada:** Maestro_Productos
- [ ] **Tabla encontrada:** Ventas_Pedidos
- [ ] **Tabla encontrada:** Ventas_Cabecera
- [ ] **Tabla encontrada:** Ventas_Detalle
- [ ] **Tabla encontrada:** Marketing_Citas
- [ ] **Tabla encontrada:** Clinica_Examenes
- [ ] **Tabla encontrada:** Operaciones_Ordenes_Cristales
- [ ] **Tabla encontrada:** Operaciones_Recepciones_Lab
- [ ] **Tabla encontrada:** Finanzas_Cobros
- [ ] **Tabla encontrada:** Finanzas_Tesoreria
- [ ] **Tabla encontrada:** Etl_Control_Ejecucion

**Si falta tabla(s):**
- [ ] Contactar Opticolor para confirmar estructura
- [ ] Crear tabla dummy si aplica
- [ ] Documentar en "Notas" al final

---

### PASO 2 — Crear tabla auxiliar

**En SSMS ejecuta:**
```sql
IF NOT EXISTS (SELECT * FROM sys.objects WHERE object_id = OBJECT_ID(N'[dbo].[Param_Venezuela_Geografia]') AND type in (N'U'))
BEGIN
    CREATE TABLE [dbo].[Param_Venezuela_Geografia] (
        id_param INT PRIMARY KEY IDENTITY(1,1),
        estado VARCHAR(100) NOT NULL,
        municipio VARCHAR(100),
        latitud DECIMAL(10,8),
        longitud DECIMAL(11,8),
        UNIQUE(estado, municipio)
    );
    PRINT '✓ Tabla Param_Venezuela_Geografia creada'
END
```

**Resultado esperado:** Mensaje de confirmación ✓

- [ ] Tabla `Param_Venezuela_Geografia` creada o ya existe
- [ ] Verificar con: `SELECT * FROM [dbo].[Param_Venezuela_Geografia];`
  - Esperado: (0 rows) — tabla vacía

---

## 🚀 FASE 3: DESPLIEGUE VISTAS (15 min)

### PASO 3 — Ejecutar script de vistas

**En SSMS:**
1. [ ] Abre: `c:\opticolor-bi\sql\vistas_opticolor_venezuela_LIMPIO.sql`
2. [ ] Selecciona TODO (Ctrl+A)
3. [ ] Ejecuta (F5 o Ctrl+Shift+E)
4. [ ] Espera a que termine

**Resultado esperado:**
```
✓ Todas las vistas para OPTI-COLOR Venezuela han sido creadas exitosamente
✓ Se han eliminado referencias a Zoho Books y GHL
✓ Se han aplicado ajustes GMT-4 (Venezuela) en todas las vistas temporales
✓ IVA ajustado a 16% donde aplica
```

**Checklist de ejecución:**
- [ ] Sin errores críticos (T-SQL syntax)
- [ ] Sin errores de conexión
- [ ] Mensaje de confirmación visible
- [ ] Tiempo de ejecución: ~5-10 segundos

**Si hay ERROR:**
- [ ] Copiar error exacto → ver sección "Troubleshooting" en protocolo
- [ ] ❌ NO continuar hasta resolver
- [ ] Reportar a Gerardo con detalles

---

## ✔️ FASE 4: VALIDACIÓN POST-DESPLIEGUE (10 min)

### PASO 4a — Contar vistas creadas

**En SSMS ejecuta:**
```sql
SELECT COUNT(*) AS total_vistas
FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'dbo'
  AND (TABLE_NAME LIKE 'Dim_%' OR TABLE_NAME LIKE 'Fact_%');
```

- [ ] Total de vistas: **14**

**Si no es 14:**
- [ ] Número encontrado: ___
- [ ] Documentar diferencia
- [ ] Revisar logs de ejecución

---

### PASO 4b — Listar vistas creadas

**En SSMS ejecuta:**
```sql
SELECT TABLE_NAME AS vista FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'dbo'
  AND (TABLE_NAME LIKE 'Dim_%' OR TABLE_NAME LIKE 'Fact_%')
ORDER BY TABLE_NAME;
```

**Verificar estas vistas existen:**

#### Dimensiones (5)
- [ ] `Dim_Categorias`
- [ ] `Dim_Clientes`
- [ ] `Dim_Sucursales`
- [ ] `Dim_Sucursales_Limpia`

#### Hechos (9)
- [ ] `Fact_Eficiencia_Ordenes`
- [ ] `Fact_Examenes`
- [ ] `Fact_Pedidos`
- [ ] `Fact_Produccion_Lentes`
- [ ] `Fact_Recaudo`
- [ ] `Fact_Tesoreria`
- [ ] `Fact_Ventas`
- [ ] `Fact_Ventas_Analitico`
- [ ] `Fact_Ventas_Detalle`

#### Analíticas (1)
- [ ] `Fact_Ventas_Por_Motivo`

---

### PASO 4c — Verificar vistas ELIMINADAS

**En SSMS ejecuta:**
```sql
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME IN (
    'Fact_Zoho_Gastos',
    'Fact_Embudo_Marketing',
    'Dim_GHL_Sucursales_Link'
  );
```

**Resultado esperado:** (0 rows)

- [ ] `Fact_Zoho_Gastos`: ✓ NO EXISTE
- [ ] `Fact_Embudo_Marketing`: ✓ NO EXISTE
- [ ] `Dim_GHL_Sucursales_Link`: ✓ NO EXISTE

---

## 🧪 FASE 5: PRUEBAS DE EJECUCIÓN (5 min)

### PASO 5 — SELECT simple de cada vista principal

**En SSMS, ejecuta cada query y verifica:**

#### Prueba 1: Dim_Sucursales
```sql
SELECT TOP 3 * FROM [dbo].[Dim_Sucursales];
```
- [ ] Ejecuta sin error: **SÍ / NO**
- [ ] Retorna datos: **SÍ / NO / SIN DATOS**
- [ ] Columnas visibles: id_sucursal, nombre_sucursal, provincia, municipio

#### Prueba 2: Fact_Pedidos
```sql
SELECT TOP 3 * FROM [dbo].[Fact_Pedidos];
```
- [ ] Ejecuta sin error: **SÍ / NO**
- [ ] Retorna datos: **SÍ / NO / SIN DATOS**
- [ ] Columnas visibles: id_pedido, fecha_pedido_completa, mes_pedido_nombre

#### Prueba 3: Fact_Ventas
```sql
SELECT TOP 3 * FROM [dbo].[Fact_Ventas];
```
- [ ] Ejecuta sin error: **SÍ / NO**
- [ ] Retorna datos: **SÍ / NO / SIN DATOS**
- [ ] Columnas visibles: id_factura, monto_total, monto_sin_iva

#### Prueba 4: Dim_Clientes
```sql
SELECT TOP 3 * FROM [dbo].[Dim_Clientes];
```
- [ ] Ejecuta sin error: **SÍ / NO**
- [ ] Retorna datos: **SÍ / NO / SIN DATOS**
- [ ] Columnas visibles: id_cliente, nombre_completo, genero_label, edad

**Nota:** Si retorna "SIN DATOS" → NORMAL (ETL aún no cargó). ✓

---

## 📊 FASE 6: VALIDACIÓN DE DATOS (5 min)

### PASO 6a — Verificar Timezone GMT-4

**En SSMS ejecuta:**
```sql
SELECT TOP 5
    fecha_pedido_completa,
    mes_pedido_nombre,
    YEAR(fecha_pedido_completa) AS anio,
    MONTH(fecha_pedido_completa) AS mes
FROM [dbo].[Fact_Pedidos];
```

- [ ] Fecha mostrada en GMT-4: **SÍ / NO / SIN DATOS**
- [ ] Mes_nombre está en español: **SÍ / NO**

---

### PASO 6b — Verificar IVA 16% (Venezuela)

**En SSMS ejecuta:**
```sql
SELECT TOP 3
    monto_total,
    monto_sin_iva,
    CAST(monto_total - monto_sin_iva AS DECIMAL(10,2)) AS iva_calculado,
    CAST((monto_total - monto_sin_iva) / NULLIF(monto_sin_iva, 0) * 100 AS DECIMAL(5,2)) AS porcentaje_iva
FROM [dbo].[Fact_Ventas]
WHERE monto_total <> 0;
```

- [ ] Porcentaje IVA calculado: ~16% **SÍ / NO / SIN DATOS**
- [ ] NO es 7% (Panamá): **CONFIRMADO**

---

## 📝 FASE 7: REPORTE FINAL

### Resumen Ejecución

**Fecha:** __________ (hoy)  
**Servidor:** db-opticolor-dw (opticolor-visioflow-rg)  
**Usuario SSMS:** ________________

### Resultados

| Fase | Componente | Status | Notas |
|------|-----------|--------|-------|
| 1 | Conexión Azure SQL | ✅ / ❌ | |
| 1 | Archivos disponibles | ✅ / ❌ | |
| 2 | Tablas base (14) | ✅ / ⚠️ / ❌ | Faltantes: _____ |
| 2 | Tabla Param_Venezuela_Geografia | ✅ / ⚠️ / ❌ | |
| 3 | Ejecución script vistas | ✅ / ❌ | Errores: _____ |
| 4a | Total vistas (14) | ✅ / ❌ | Cantidad: ___ |
| 4b | Vistas específicas listadas | ✅ / ⚠️ / ❌ | Faltantes: _____ |
| 4c | Vistas eliminadas (Zoho/GHL) | ✅ / ❌ | |
| 5 | Pruebas SELECT | ✅ / ⚠️ / ❌ | Errores: _____ |
| 6a | Timezone GMT-4 | ✅ / ⚠️ / ❌ | |
| 6b | IVA 16% | ✅ / ⚠️ / ❌ | |

### Status General

- [ ] ✅ DESPLIEGUE EXITOSO — Todas las vistas creadas y funcionales
- [ ] ⚠️ DESPLIEGUE CON WARNINGS — Algunas alertas pero vistas funcionales
- [ ] ❌ DESPLIEGUE FALLIDO — Errores críticos, requiere investigación

### Notas Adicionales

```
(Documentar aquí cualquier incidencia, tabla faltante, ajuste realizado, etc.)

Ejemplo:
- Tabla "Clinica_Examenes" no existía, se crió dummy
- IVA 16% verificado correctamente
- 0 datos en Fact_Pedidos (esperado, ETL pendiente)

```

---

## 🔗 SIGUIENTES PASOS

Después de completar este checklist:

1. [ ] Archivar este checklist completo (evidencia)
2. [ ] Notificar a Gerardo: "Despliegue vistas exitoso ✓"
3. [ ] Iniciar carga ETL (módulo Python con CRON)
4. [ ] Configurar Power BI para conectar a vistas (Fact_Ventas, Fact_Pedidos, etc.)
5. [ ] Validar KPIs en Portal Next.js (ya tienen API routes)

---

**Completado por:** ________________  
**Fecha:** ________________  
**Firma:** ________________
