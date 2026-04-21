# ⚡ QUICK REFERENCE: VISTAS OPTICOLOR VENEZUELA

**Última actualización:** 20 de Abril, 2026  
**Servidor:** Azure SQL `db-opticolor-dw` (Venezuela)

---

## 🔥 30 SEGUNDOS

**Para desplegar AHORA:**

```sql
-- En SSMS (conectado a db-opticolor-dw):
-- Abre: c:\opticolor-bi\sql\vistas_opticolor_venezuela_LIMPIO.sql
-- Ejecuta TODO (Ctrl+A → F5)
-- Espera: ✓ Todas las vistas han sido creadas exitosamente
-- Verifica:
SELECT COUNT(*) FROM INFORMATION_SCHEMA.VIEWS 
WHERE TABLE_NAME LIKE 'Dim_%' OR TABLE_NAME LIKE 'Fact_%';
-- Esperado: 14
```

---

## 📋 LISTA DE VISTAS (14)

```
✅ Dim_Sucursales              — Sucursales + geografía Venezuela
✅ Dim_Sucursales_Limpia       — Versión simplificada
✅ Dim_Categorias              — Categorías de productos
✅ Dim_Clientes                — Clientes + segmentos

✅ Fact_Pedidos                — Pedidos + timeline
✅ Fact_Ventas                 — Facturas (IVA 16% Venezuela)
✅ Fact_Ventas_Detalle         — Líneas de venta
✅ Fact_Ventas_Analitico       — Venta + Producto + Categoría
✅ Fact_Ventas_Por_Motivo      — Venta + origen (marketing)
✅ Fact_Recaudo                — Cobros
✅ Fact_Tesoreria              — Movimientos caja
✅ Fact_Examenes               — Exámenes clínicos
✅ Fact_Eficiencia_Ordenes     — Órdenes cristales + timeline
✅ Fact_Produccion_Lentes      — Detalles técnicos lentes
```

---

## 🔄 3 CAMBIOS CLAVE

| Cambio | Línea | Sintaxis |
|--------|-------|----------|
| **GMT-4 (Venezuela)** | Todas las con fechas | `DATEADD(HOUR, -4, fecha)` |
| **IVA 16%** | Fact_Ventas:445 | `monto_total / 1.16` (NO 1.07) |
| **Geografía parametrizada** | Dim_Sucursales:59 | `JOIN Param_Venezuela_Geografia` |

---

## 📁 ARCHIVOS CRÍTICOS

| Archivo | Qué hacer |
|---------|-----------|
| `vistas_opticolor_venezuela_LIMPIO.sql` | **EJECUTAR en SSMS** |
| `00_VALIDACION_Y_DESPLIEGUE.sql` | Validar antes/después (opcional) |
| `QUERIES_ANALISIS_VISTAS.sql` | Post-ETL (analizar datos) |
| `CHECKLIST_DESPLIEGUE.md` | Marcar progreso |
| `PROTOCOLO_DESPLIEGUE_VISTAS_VENEZUELA.md` | Leer primero |

---

## ⚠️ ERRORES TÍPICOS

| Error | Fix |
|-------|-----|
| "Tabla no existe" | Ejecutar setup DDL primero |
| "Permission denied" | Solicitar permisos dbo |
| "Sin datos en vista" | Normal (ETL cargará luego) |
| "Diferencias en columnas" | Ajustar nombres en vistas |

---

## ✅ VALIDACIÓN (1 minuto)

```sql
-- Contar vistas
SELECT COUNT(*) FROM INFORMATION_SCHEMA.VIEWS 
WHERE TABLE_NAME LIKE 'Dim_%' OR TABLE_NAME LIKE 'Fact_%';
-- Esperado: 14

-- Listar vistas
SELECT TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS 
WHERE TABLE_SCHEMA = 'dbo' AND (TABLE_NAME LIKE 'Dim_%' OR TABLE_NAME LIKE 'Fact_%')
ORDER BY TABLE_NAME;

-- Probar una vista
SELECT TOP 3 * FROM [dbo].[Dim_Sucursales];

-- Verificar GMT-4
SELECT TOP 1 fecha_pedido_completa, mes_pedido_nombre FROM [dbo].[Fact_Pedidos];

-- Verificar IVA 16%
SELECT TOP 1 monto_total, monto_sin_iva, 
  CAST((monto_total - monto_sin_iva) / monto_sin_iva * 100 AS DECIMAL(5,2)) AS iva_pct
FROM [dbo].[Fact_Ventas];
```

---

## 🚀 3 OPCIONES DE DESPLIEGUE

**Opción A (Rápido):** 15 min  
→ Abre + Ejecuta + Verifica

**Opción B (Seguro):** 45 min  
→ Sigue PROTOCOLO_DESPLIEGUE_VISTAS_VENEZUELA.md

**Opción C (Completo):** 60 min  
→ Opción B + QUERIES_ANALISIS_VISTAS.sql

---

## 📞 CONTACTO

Errores → Gerardo Argueta (VisioFlow)  
Con: Error exacto + Paso donde falló

---

**Estado:** ✅ LISTO PARA DESPLIEGUE
