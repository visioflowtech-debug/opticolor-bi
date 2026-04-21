# 🚀 README: DESPLIEGUE VISTAS OPTICOLOR VENEZUELA

**Versión:** 1.0  
**Fecha:** 20 de Abril, 2026  
**Servidor destino:** Azure SQL `db-opticolor-dw` (Opticolor Venezuela)  
**Estado:** ✅ LISTO PARA DESPLIEGUE INMEDIATO

---

## 📍 ÍNDICE DE ARCHIVOS

### 🔴 ARCHIVOS CRÍTICOS (DEBE EJECUTAR)

#### 1. **vistas_opticolor_venezuela_LIMPIO.sql** ⭐ PRINCIPAL
```
Propósito: Crear 14 vistas BI + 1 tabla auxiliar
Líneas: 544
Tiempo ejecución: ~5-10 segundos
Cambios aplicados: GMT-4, IVA 16%, geografía parametrizada
Dependencias: 14 tablas base maestras/transaccionales

INSTRUCCIONES:
1. Abre en SSMS
2. Conecta a db-opticolor-dw
3. Selecciona TODO (Ctrl+A)
4. Ejecuta (F5)
5. Espera confirmación: "✓ Todas las vistas... han sido creadas exitosamente"
```

#### 2. **00_VALIDACION_Y_DESPLIEGUE.sql** (Opcional: para validación)
```
Propósito: Script con 6 pasos de validación y testing
Lineas: 250
Uso: Antes de desplegar para validar tablas base
      Después de desplegar para confirmar vistas creadas

CÓMO USAR:
- Ejecuta paso a paso en SSMS
- No necesario si confías en las tablas base
- Recomendado para auditoria post-despliegue
```

#### 3. **QUERIES_ANALISIS_VISTAS.sql** (Post-despliegue)
```
Propósito: 15 queries SQL para validar datos + volúmenes
Líneas: 350
Tiempo ejecución: ~10 segundos (depende de volumen)
Cuándo ejecutar: DESPUÉS de cargar datos ETL

Análisis incluidos:
- Estado vistas + conteo registros
- Timeline de fechas (validate GMT-4)
- Verificación IVA 16%
- Distribución geográfica Venezuela
- Volúmenes por segmento
```

---

### 📘 DOCUMENTACIÓN (LEER PRIMERO)

#### **PROTOCOLO_DESPLIEGUE_VISTAS_VENEZUELA.md** ⭐ GUÍA COMPLETA
```
Ubicación: c:\opticolor-bi\docs\
Propósito: Guía paso a paso completa del despliegue
Secciones:
  1. Resumen cambios aplicados
  2. Pasos de ejecución (6 fases)
  3. Queries SQL para cada paso
  4. Resultados esperados
  5. Troubleshooting
  6. Reporte final template

RECOMENDADO: Leer antes de cualquier ejecución
```

#### **RESUMEN_PREPARACION_VISTAS_VENEZUELA.md** (Contexto general)
```
Ubicación: c:\opticolor-bi\docs\
Propósito: Resumen ejecutivo de cambios + archivos entregados
Secciones:
  - Objetivo completado
  - Archivos entregados (5)
  - Vistas desplegadas (14)
  - Cambios clave explicados
  - Checklist pre-despliegue
  - Cómo desplegar (resumen rápido)
```

#### **CHECKLIST_DESPLIEGUE.md** ⭐ USAR DURANTE DESPLIEGUE
```
Ubicación: c:\opticolor-bi\sql\
Propósito: Checklist interactivo con 50+ items verificables
Secciones:
  - Fase 1: Preparación (conexión, archivos)
  - Fase 2: Validación previa (tablas base)
  - Fase 3: Despliegue vistas (ejecución)
  - Fase 4: Validación post-despliegue
  - Fase 5: Pruebas de ejecución (SELECT)
  - Fase 6: Validación de datos (timezone, IVA)
  - Fase 7: Reporte final (template)

CÓMO USAR:
1. Imprime o abre en editor
2. Marca checkboxes conforme avanzas
3. Reporta resultados al final
```

---

## 🎯 FLUJO RECOMENDADO

### Opción A: Despliegue Rápido (15 minutos)
**Para usuarios con experiencia SQL**

```
1. Abre vistas_opticolor_venezuela_LIMPIO.sql en SSMS
2. Conecta a db-opticolor-dw
3. Ejecuta TODO (Ctrl+A → F5)
4. Espera confirmación ✓
5. Verifica: SELECT COUNT(*) FROM INFORMATION_SCHEMA.VIEWS 
             WHERE TABLE_NAME LIKE 'Dim_%' OR TABLE_NAME LIKE 'Fact_%'
   Resultado esperado: 14
```

### Opción B: Despliegue Seguro CON VALIDACIÓN (45 minutos)
**Recomendado para auditoria / producción**

```
1. Lee: PROTOCOLO_DESPLIEGUE_VISTAS_VENEZUELA.md
2. Lee: CHECKLIST_DESPLIEGUE.md
3. Ejecuta PASO 1 (Validación tablas base)
   → Abre 00_VALIDACION_Y_DESPLIEGUE.sql
   → Ejecuta queries de validación previa
4. Ejecuta PASO 2 (Crear tabla auxiliar)
5. Ejecuta PASO 3 (Despliegue vistas)
   → Abre vistas_opticolor_venezuela_LIMPIO.sql
   → Ejecuta TODO
6. Ejecuta PASO 4-6 (Validación post-despliegue)
   → Abre 00_VALIDACION_Y_DESPLIEGUE.sql
   → Ejecuta queries de validación posterior
7. Documenta resultados en CHECKLIST_DESPLIEGUE.md
8. Entrega reporte final
```

### Opción C: Despliegue CON ANÁLISIS PROFUNDO (60 minutos)
**Para debugging o cuando hay errores**

```
1-8. Ejecuta Opción B completa
9.  Después de despliegue exitoso:
    → Abre QUERIES_ANALISIS_VISTAS.sql
    → Ejecuta análisis 1-15
    → Verifica volúmenes, timezone, IVA
    → Documenta hallazgos
```

---

## ⚡ QUICK START (30 segundos)

**Si ya conectaste a Azure SQL SSMS:**

```sql
-- 1. Abre este archivo
cd c:\opticolor-bi\sql\vistas_opticolor_venezuela_LIMPIO.sql

-- 2. En SSMS: Ctrl+A → F5

-- 3. Espera 10 segundos

-- 4. Verifica
SELECT COUNT(*) AS total_vistas
FROM INFORMATION_SCHEMA.VIEWS
WHERE TABLE_SCHEMA = 'dbo'
  AND (TABLE_NAME LIKE 'Dim_%' OR TABLE_NAME LIKE 'Fact_%');

-- 5. Si retorna 14 → ✅ ÉXITO
```

---

## 📊 VISTAS QUE SE CREARÁN (14 Total)

### Dimensiones (4)
- ✅ `Dim_Sucursales` — Maestro + geografía Venezuela
- ✅ `Dim_Sucursales_Limpia` — Versión simplificada
- ✅ `Dim_Categorias` — Categorías producto + línea negocio
- ✅ `Dim_Clientes` — Clientes + segmentos demográficos

### Hechos (9)
- ✅ `Fact_Pedidos` — Pedidos + estado + timeline
- ✅ `Fact_Ventas` — Facturas (IVA 16% Venezuela)
- ✅ `Fact_Ventas_Detalle` — Líneas de venta
- ✅ `Fact_Ventas_Analitico` — Venta + Producto + Categoría
- ✅ `Fact_Recaudo` — Cobros (cobranza)
- ✅ `Fact_Tesoreria` — Movimientos caja
- ✅ `Fact_Examenes` — Exámenes clínicos
- ✅ `Fact_Eficiencia_Ordenes` — Órdenes cristales + timeline
- ✅ `Fact_Produccion_Lentes` — Detalles técnicos lentes

### Analíticas (1)
- ✅ `Fact_Ventas_Por_Motivo` — Venta + origen (marketing)

---

## 🔧 CAMBIOS APLICADOS

| Cambio | Antes | Después | Línea |
|--------|-------|---------|-------|
| **Timezone** | GMT-5 (Panamá) | GMT-4 (Venezuela) | Todas las vistas con DATEADD |
| **IVA** | 7% (Panamá) | 16% (Venezuela) | Fact_Ventas:445 |
| **Geografía** | Hardcoding Panamá | Tabla Venezuela parametrizada | Dim_Sucursales:59 |
| **Dependencias** | Zoho Books, GHL | Removidas | Línea 6-10 (comentarios) |

---

## ✅ PRE-REQUISITOS

**Obligatorios:**
- [ ] SSMS conectado a Azure SQL `db-opticolor-dw`
- [ ] Permisos: CREATE VIEW, CREATE TABLE
- [ ] 14 tablas base creadas (ver Paso 1 validación)

**Tablas requeridas:**
```
Maestro_Sucursales           ← Sucursales
Maestro_Clientes             ← Clientes
Maestro_Categorias           ← Categorías producto
Maestro_Productos            ← Productos
Ventas_Pedidos               ← Pedidos
Ventas_Cabecera              ← Facturas
Ventas_Detalle               ← Líneas factura
Marketing_Citas              ← Agenda clientes
Clinica_Examenes             ← Exámenes
Operaciones_Ordenes_Cristales ← Órdenes lab
Operaciones_Recepciones_Lab   ← Recepciones lab
Finanzas_Cobros              ← Cobros
Finanzas_Tesoreria           ← Tesorería
Etl_Control_Ejecucion        ← Control ETL
```

---

## 🚨 ERRORES COMUNES Y SOLUCIONES

| Error | Causa | Solución |
|-------|-------|----------|
| "Tabla 'Maestro_Sucursales' no existe" | DDL tablas no ejecutado | Ejecutar setup_opticolor_venezuela.sql primero |
| "CREATE VIEW permission denied" | Permisos insuficientes | Solicitar acceso dbo a Gerardo |
| "Division by zero" en IVA | Facturas con monto=0 | Normal, script maneja con NULLIF |
| "Invalid column name" | Estructura diferente Panamá vs Venezuela | Revisar DDL tablas base |
| Vista creada pero SELECT vacío | Sin datos ETL | Normal, despliegue exitoso |

---

## 📞 SOPORTE

**Antes de contactar:**
1. Revisar "Errores comunes" arriba
2. Revisar sección Troubleshooting en PROTOCOLO_DESPLIEGUE_VISTAS_VENEZUELA.md
3. Ejecutar Paso 1 (Validación tablas base)

**Contactar a:** Gerardo Argueta (VisioFlow)  
**Con:** Error exacto + Paso donde falló + Checklist hasta qué punto

---

## 📈 PRÓXIMOS PASOS

Después de despliegue exitoso:

1. **Semana 2:** Cargar datos ETL (módulo Python + CRON)
2. **Semana 2:** Conectar Power BI a vistas (5 informes)
3. **Semana 3:** Validar KPIs y métricas
4. **Semana 4:** Portal Next.js con datos reales
5. **Semana 5-6:** Optimizaciones y monitoreo

---

## 📝 NOTAS OPERATIVAS

- ✓ Script es **idempotente**: puedes ejecutarlo múltiples veces sin problemas
- ✓ Usa **CREATE OR ALTER**: reemplaza vistas existentes automáticamente
- ✓ **Sin datos será normal** en fase inicial: ETL cargará luego
- ✓ **Backup recomendado** de db-opticolor-dw antes de despliegue
- ✓ **Sin transacciones** en tablas base durante ejecución

---

## 🎯 ESTADO FINAL

```
┌───────────────────────────────────────────┐
│ ✅ DESPLIEGUE LISTO                       │
├───────────────────────────────────────────┤
│ Vistas: 14 BI                             │
│ Tabla auxiliar: 1                         │
│ Cambios: timezone, IVA, geografía         │
│ Documentación: 100% completa              │
│ Checklist: interactivo                    │
│ Queries análisis: 15 listos               │
│                                           │
│ 🚀 PROCEDE A DESPLIEGUE                  │
└───────────────────────────────────────────┘
```

---

**Versión:** 1.0  
**Creado por:** Claude Code  
**Aprobado por:** Gerardo Argueta (VisioFlow)  
**Última actualización:** 20 de Abril, 2026
