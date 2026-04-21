# 🚀 PROTOCOLO DE DESPLIEGUE: VISTAS OPTICOLOR VENEZUELA
**Fecha:** 20 de Abril, 2026  
**Servidor:** Azure SQL `db-opticolor-dw` (opticolor-visioflow-rg)  
**Origen:** Optilux Panamá (adaptado Venezuela)

---

## 📋 RESUMEN CAMBIOS APLICADOS

| Cambio | Antes | Después | Impacto |
|--------|-------|---------|---------|
| **Dependencias externas** | Zoho Books, GHL | Eliminadas | ✅ Script standalone |
| **Timezone** | GMT-5 (Panamá) | GMT-4 (Venezuela) | ✅ Fechas correctas |
| **IVA** | 7% (Panamá) | 16% (Venezuela) | ✅ Facturación correcta |
| **Geografía** | Hardcoding Panamá | Param_Venezuela_Geografia | ✅ Escalable |
| **Vistas BI** | 17 vistas | 14 vistas | ✅ Limpio |

---

## 🔧 ARCHIVOS NECESARIOS

```
c:\opticolor-bi\sql\
├── vistas_opticolor_venezuela_LIMPIO.sql     ← Script principal (14 vistas)
├── 00_VALIDACION_Y_DESPLIEGUE.sql            ← Protocolo de validación
└── README.md                                   ← Este archivo
```

---

## ⚡ PASOS DE EJECUCIÓN

### PASO 1️⃣ - VALIDACIÓN PREVIA (5 min)
**Objetivo:** Verificar que todas las tablas base existen

**En SSMS, ejecuta:**
```sql
-- Valida tablas principales
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME IN (
    'Maestro_Sucursales',
    'Maestro_Clientes',
    'Maestro_Categorias',
    'Maestro_Productos',
    'Ventas_Pedidos',
    'Ventas_Cabecera',
    'Ventas_Detalle',
    'Marketing_Citas',
    'Clinica_Examenes',
    'Operaciones_Ordenes_Cristales',
    'Operaciones_Recepciones_Lab',
    'Finanzas_Cobros',
    'Finanzas_Tesoreria',
    'Etl_Control_Ejecucion'
  )
ORDER BY TABLE_NAME;
```

**Responde:**
- ✅ ¿Todas las 14 tablas existen?
- ⚠️ ¿Cuáles tablas NO existen? (si aplica)

**Acción si falta tabla:**
- Si falta `Clinica_Examenes`: Fact_Examenes fallará → Crear tabla dummy o descartar vista
- Si faltan otras: Contactar Opticolor para estructura

---

### PASO 2️⃣ - CREAR TABLA AUXILIAR (2 min)
**Objetivo:** Crear tabla para parámetros geográficos Venezuela

**En SSMS, ejecuta:**
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

**Verifica:**
```sql
SELECT * FROM [dbo].[Param_Venezuela_Geografia];
-- Debe retornar: (0 rows) — tabla vacía pero lista
```

---

### PASO 3️⃣ - DESPLEGAR VISTAS (10 min)
**Objetivo:** Crear todas las vistas BI

**En SSMS:**
1. Abre archivo: `c:\opticolor-bi\sql\vistas_opticolor_venezuela_LIMPIO.sql`
2. **Selecciona TODO** el contenido (Ctrl+A)
3. **Ejecuta** (F5 o Ctrl+Shift+E)

**Espera a ver:**
```
✓ Todas las vistas para OPTI-COLOR Venezuela han sido creadas exitosamente
✓ Se han eliminado referencias a Zoho Books y GHL
✓ Se han aplicado ajustes GMT-4 (Venezuela) en todas las vistas temporales
✓ IVA ajustado a 16% donde aplica
```

**Si hay ERROR:**
- ✗ Detén aquí
- Copia el error exacto
- Reporta (ver sección "Troubleshooting" abajo)

---

### PASO 4️⃣ - VALIDACIÓN POST-DESPLIEGUE (5 min)
**Objetivo:** Verificar que todas las vistas se crearon correctamente

**En SSMS, ejecuta:**

#### 4a) Conteo de vistas
```sql
SELECT COUNT(*) AS total_vistas
FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'dbo'
  AND (TABLE_NAME LIKE 'Dim_%' OR TABLE_NAME LIKE 'Fact_%');
```
**Esperado:** `14` vistas

#### 4b) Listado completo
```sql
SELECT TABLE_NAME AS nombre_vista
FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'dbo'
  AND (TABLE_NAME LIKE 'Dim_%' OR TABLE_NAME LIKE 'Fact_%')
ORDER BY TABLE_NAME;
```
**Esperado:** 14 vistas listadas

#### 4c) Verificar vistas ELIMINADAS
```sql
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME IN (
    'Fact_Zoho_Gastos',
    'Fact_Embudo_Marketing',
    'Dim_GHL_Sucursales_Link'
  );
```
**Esperado:** `(0 rows)` — vacío significa que fueron eliminadas correctamente ✓

---

### PASO 5️⃣ - PRUEBAS DE EJECUCIÓN (3 min)
**Objetivo:** Verificar que cada vista es funcional

**En SSMS, ejecuta cada query:**

```sql
-- Prueba 1: Dim_Sucursales
SELECT TOP 3 * FROM [dbo].[Dim_Sucursales];
-- Resultado: Debe mostrar id_sucursal, nombre, provincia, etc.

-- Prueba 2: Fact_Pedidos
SELECT TOP 3 * FROM [dbo].[Fact_Pedidos];
-- Resultado: Debe mostrar id_pedido, fecha_pedido_completa, mes_pedido_nombre, etc.

-- Prueba 3: Fact_Ventas
SELECT TOP 3 * FROM [dbo].[Fact_Ventas];
-- Resultado: Debe mostrar id_factura, monto_total, monto_sin_iva, etc.

-- Prueba 4: Dim_Clientes
SELECT TOP 3 * FROM [dbo].[Dim_Clientes];
-- Resultado: Debe mostrar id_cliente, nombre_completo, genero_label, etc.
```

**Reporta:**
- ✅ ¿Vista retorna datos? (SÍ / NO / SIN DATOS)
- ❌ ¿Hay errores? (qué error?)

**Nota:** Si no hay datos → es NORMAL en fase inicial. ETL cargará datos luego.

---

### PASO 6️⃣ - VALIDACIÓN DE DATOS (5 min)
**Objetivo:** Verificar que los ajustes de timezone e IVA están correctos

#### 6a) Verificar Timezone GMT-4
```sql
SELECT TOP 5
    fecha_pedido_completa,
    mes_pedido_nombre,
    YEAR(fecha_pedido_completa) AS anio,
    MONTH(fecha_pedido_completa) AS mes
FROM [dbo].[Fact_Pedidos];
```
**Esperado:** Las fechas deben reflejar GMT-4 (UTC-4)

#### 6b) Verificar IVA 16%
```sql
SELECT TOP 3
    monto_total,
    monto_sin_iva,
    CAST(monto_total - monto_sin_iva AS DECIMAL(10,2)) AS iva_calculado,
    CAST((monto_total - monto_sin_iva) / NULLIF(monto_sin_iva, 0) * 100 AS DECIMAL(5,2)) AS porcentaje_iva
FROM [dbo].[Fact_Ventas]
WHERE monto_total <> 0;
```
**Esperado:** El `porcentaje_iva` debe ser ~16% (no 7%)

---

## 📊 LISTADO FINAL DE VISTAS (14 Total)

### Dimensiones (5)
| Vista | Descripción |
|-------|-------------|
| `Dim_Sucursales` | Maestro de sucursales + geografía Venezuela |
| `Dim_Sucursales_Limpia` | Versión simplificada para reportes |
| `Dim_Categorias` | Categorías de productos y línea negocio |
| `Dim_Clientes` | Clientes con edad, género, segmentos |
| `Dim_Productos` *(referencia)* | No en script (usar Maestro_Productos directo) |

### Hechos (9)
| Vista | Descripción |
|-------|-------------|
| `Fact_Pedidos` | Pedidos con estado y timeline |
| `Fact_Ventas` | Facturas con IVA 16% (Venezuela) |
| `Fact_Ventas_Detalle` | Líneas de venta por artículo |
| `Fact_Ventas_Analitico` | Venta + producto + categoría |
| `Fact_Recaudo` | Cobros clasificados |
| `Fact_Tesoreria` | Movimientos de caja |
| `Fact_Examenes` | Exámenes clínicos |
| `Fact_Eficiencia_Ordenes` | Órdenes de cristales + tiempo lab |
| `Fact_Produccion_Lentes` | Detalles técnicos de lentes (esfera, cilindro, etc.) |

### Analíticas (1)
| Vista | Descripción |
|-------|-------------|
| `Fact_Ventas_Por_Motivo` | Venta + origen (redes, referido, etc.) |

---

## ⚠️ TROUBLESHOOTING

### ❌ Error: "Tabla 'Maestro_Sucursales' no existe"
**Causa:** Tabla base no existe  
**Solución:**
1. Verifica que el DDL de tablas se ejecutó antes
2. Contacta a Gerardo para confirmar que las tablas existen
3. Ejecuta Paso 1 de validación previa

### ❌ Error: "Invalid column name 'fecha_pedido'"
**Causa:** Estructura de columnas diferente en Panamá vs Venezuela  
**Solución:**
1. Verifica estructura: `SELECT * FROM Ventas_Pedidos WHERE 1=0;`
2. Compara con schema esperado en `Optilux Panama schema.sql`
3. Ajusta nombres de columnas en vistas

### ❌ Error: "Division by zero" en IVA
**Causa:** monto_total = 0 o estructura de precios diferente  
**Solución:**
1. Verifica que `monto_total` en Ventas_Cabecera es precio BRUTO (con IVA)
2. Verifica que no hay facturas con monto=0
3. Si es necesario, ajusta fórmula IVA

### ❌ Vistas creadas pero SELECT retorna vacío
**Normal.** Significa:
- Tablas base existen pero sin datos
- ETL aún no cargó datos
- **Acción:** Continuar, despliegue es exitoso

### ❌ Error: "VIEW CREATION FAILED" con 10+ errores
**Causa:** Típicamente, tablas base tienen estructura diferente  
**Solución:**
1. Ejecuta queries de PASO 1 para confirmar tablas
2. Para cada tabla faltante, crea vista dummy o desactiva vista
3. Reintenta despliegue

---

## 📝 REPORTE FINAL A ENTREGAR

Usa este template después de completar todos los pasos:

```
┌─────────────────────────────────────────────────────────┐
│ DESPLIEGUE VISTAS OPTICOLOR VENEZUELA                  │
│ Fecha: [HOY] | Servidor: db-opticolor-dw (Venezuela)   │
├─────────────────────────────────────────────────────────┤
│ ✅ PASO 1: VALIDACIÓN TABLAS BASE                       │
│  Total tablas encontradas: __ / 14                       │
│  Tablas faltantes: ___ (si hay)                          │
│                                                         │
│ ✅ PASO 2: TABLA AUXILIAR                               │
│  Param_Venezuela_Geografia: [CREADA / YA EXISTÍA]      │
│                                                         │
│ ✅ PASO 3: DESPLIEGUE VISTAS                            │
│  Errores críticos: 0                                    │
│  Warnings: 0                                            │
│  Status: ✓ COMPLETADO                                  │
│                                                         │
│ ✅ PASO 4: VALIDACIÓN POST-DESPLIEGUE                   │
│  Total vistas creadas: 14                               │
│  Dim_Sucursales: ✓ OK                                   │
│  Fact_Pedidos: ✓ OK                                     │
│  Fact_Ventas: ✓ OK                                      │
│  Dim_Clientes: ✓ OK                                     │
│  Vistas eliminadas (Zoho/GHL): ✓ NO EXISTEN           │
│                                                         │
│ ✅ PASO 5: PRUEBAS EJECUCIÓN                            │
│  Dim_Sucursales SELECT: ✓ OK                            │
│  Fact_Pedidos SELECT: ✓ OK                              │
│  Fact_Ventas SELECT: ✓ OK                               │
│  Dim_Clientes SELECT: ✓ OK                              │
│                                                         │
│ ✅ PASO 6: VALIDACIÓN DATOS                             │
│  Timezone GMT-4: ✓ VERIFICADO                           │
│  IVA 16%: ✓ VERIFICADO                                  │
│  Geografía Venezuela: ✓ PARAMETRIZADA                  │
│                                                         │
│ 🎉 DESPLIEGUE EXITOSO                                   │
│ Siguiente paso: Cargar datos ETL                        │
└─────────────────────────────────────────────────────────┘
```

---

## 🔗 REFERENCIAS

- **Script principal:** `c:\opticolor-bi\sql\vistas_opticolor_venezuela_LIMPIO.sql`
- **Validación:** `c:\opticolor-bi\sql\00_VALIDACION_Y_DESPLIEGUE.sql`
- **Optilux Panama referencia:** Documentación Técnica DB v2.0
- **Tracker proyecto:** PROYECTO OPTICOLOR.pdf (Notion)

---

**Autor:** Claude Code  
**Estado:** Listo para despliegue  
**Aprobación requerida:** Gerardo Argueta (VisioFlow)
