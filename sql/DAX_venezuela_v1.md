# DAX Venezuela — Opticolor BI
Documentación de medidas DAX adaptadas de Optilux Panamá a Opticolor Venezuela.
Arquitectura: lógica en SQL (vistas KPI_*), Power BI solo agrega y presenta.
GMT-4 Venezuela. Datos desde 2026. Tabla medidas: _Medidas_Opticolor

---

## CONTROL DE PROGRESO

| # | DAX | Estado |
|---|---|---|
| 1 | Venta Bruta | ✅ 26/04/2026 |
| 2 | Devoluciones | ✅ 26/04/2026 |
| 3 | Venta Neta | ✅ 26/04/2026 |
| 4 | Cantidad Facturas | ✅ 26/04/2026 |
| 5 | Total Cobrado | ✅ 27/04/2026 |
| 6 | % Mix Medios Pago | ✅ 27/04/2026 |
| 7 | Proyección Venta Neta | ✅ 27/04/2026 |
| 8 | Ticket Promedio | ✅ 27/04/2026 |
| 9 | Net Sales | ✅ 27/04/2026 |
| 10 | Venta Neta (Producto) | ✅ 27/04/2026 |
| 11 | Venta Teorica Lista | ✅ 27/04/2026 |
| 12 | Color Alerta ETL | ✅ 27/04/2026 |
| 13 | Filtro Mes Actual | ✅ 27/04/2026 |
| 14 | Monto Pedidos | ⏳ Pendiente |
| 15 | Monto Saldo Pendiente | ⏳ Pendiente |
| 16 | Recaudado en Pedidos | ⏳ Pendiente |
| 17 | % Cobro Inmediato | ⏳ Pendiente |
| 18 | % Nivel de Abono | ⏳ Pendiente |
| 19 | Pedidos por Liquidar | ⏳ Pendiente |
| 20 | Total Exámenes | ⏳ Pendiente |
| 21 | Cantidad Pedidos | ✅ 27/04/2026 |
| 22 | % Cierre General | ⏳ Pendiente |
| 23 | Stock Fisico (Unds) | ⏳ Pendiente |
| 24 | Capital Invertido | ⏳ Pendiente |
| 25 | Unidades Vendidas | ⏳ Pendiente |
| 26 | UPT | ⏳ Pendiente |
| 27 | ASP | ⏳ Pendiente |
| 28 | Volumen Unidades | ⏳ Pendiente |

---

## DAX #1 — Venta Bruta

**Panamá:**
```dax
Venta Bruta = 
CALCULATE(
    SUM(Fact_Ventas[monto_total]),
    Fact_Ventas[tipo_transaccion] <> "Devolución"
)
```

**Venezuela:**
```dax
Venta Bruta = 
CALCULATE(
    SUM(Fact_Ventas[monto_total]),
    Fact_Ventas[tipo_transaccion] <> "Devolución"
)
```

**Diferencia:** Sin cambios vs Panamá.
Fact_Ventas Venezuela ya tiene tipo_transaccion con
valores 'Venta' y 'Devolución' — lógica idéntica.

**Validación SQL:**
```sql
SELECT periodo_factura,
       COUNT(DISTINCT id_factura) AS facturas,
       ROUND(SUM(monto_total), 2) AS venta_bruta
FROM Fact_Ventas
WHERE tipo_transaccion <> 'Devolución'
GROUP BY periodo_factura
ORDER BY periodo_factura DESC;
```

**Resultado validado 26/04/2026:**
| periodo | facturas | venta_bruta |
|---|---|---|
| 2026-04 | 2707 | 120,684,187.60 |
| 2026-03 | 703 | 26,259,348.62 |

---

## DAX #2 — Devoluciones

**Panamá:**
```dax
Devoluciones = 
COALESCE(
    ABS(
        CALCULATE(
            SUM(Fact_Ventas[monto_total]),
            Fact_Ventas[tipo_transaccion] = "Devolución"
        )
    ), 
    0
)
```

**Venezuela:**
```dax
Devoluciones = 
COALESCE(
    ABS(
        CALCULATE(
            SUM(Fact_Ventas[monto_total]),
            Fact_Ventas[tipo_transaccion] = "Devolución"
        )
    ), 
    0
)
```

**Diferencia:** Sin cambios vs Panamá.
Venezuela tiene 13 devoluciones reales con monto negativo.
ABS() convierte el monto negativo a positivo.

**Validación SQL:**
```sql
SELECT periodo_factura,
       COUNT(*) AS devoluciones,
       ROUND(ABS(SUM(monto_total)), 2) AS total_devoluciones
FROM Fact_Ventas
WHERE tipo_transaccion = 'Devolución'
GROUP BY periodo_factura
ORDER BY periodo_factura DESC;
```

---

## DAX #3 — Venta Neta

**Panamá:**
```dax
Venta Neta = 
COALESCE(
    [Venta Bruta] - [Devoluciones], 
    0
)
```

**Venezuela:**
```dax
Venta Neta = 
COALESCE(
    [Venta Bruta] - [Devoluciones], 
    0
)
```

**Diferencia:** Sin cambios vs Panamá.
Depende de DAX #1 y DAX #2 ya validados.

**Validación SQL:**
```sql
SELECT periodo_factura,
       ROUND(SUM(CASE WHEN tipo_transaccion <> 'Devolución' 
             THEN monto_total ELSE 0 END), 2) AS venta_bruta,
       ROUND(ABS(SUM(CASE WHEN tipo_transaccion = 'Devolución' 
             THEN monto_total ELSE 0 END)), 2) AS devoluciones,
       ROUND(SUM(monto_total), 2) AS venta_neta
FROM Fact_Ventas
GROUP BY periodo_factura
ORDER BY periodo_factura DESC;
```

---

## DAX #4 — Cantidad Facturas

**Panamá:**
```dax
Cantidad Facturas = 
COALESCE(
    DISTINCTCOUNT(Fact_Ventas[id_factura]), 
    0
)
```

**Venezuela:**
```dax
Cantidad Facturas = 
COALESCE(
    CALCULATE(
        DISTINCTCOUNT(Fact_Ventas[id_factura]),
        Fact_Ventas[tipo_transaccion] = "Venta"
    ), 
    0
)
```

**Diferencia:** Venezuela agrega filtro tipo_transaccion = "Venta"
porque las devoluciones tienen id_factura propio (no comparten
con la venta original). Sin filtro Power BI cuenta 2,712 
incluyendo 5 facturas de devolución. Con filtro = 2,707. ✅

**Validación SQL:**
```sql
SELECT COUNT(DISTINCT id_factura) AS todas_facturas,
       COUNT(DISTINCT CASE WHEN tipo_transaccion = 'Venta' 
             THEN id_factura END) AS solo_ventas,
       COUNT(DISTINCT CASE WHEN tipo_transaccion = 'Devolución' 
             THEN id_factura END) AS solo_devoluciones
FROM Fact_Ventas
WHERE periodo_factura = '2026-04';
```

**Resultado validado 26/04/2026:**
| todas_facturas | solo_ventas | solo_devoluciones |
|---|---|---|
| 2712 | 2707 | 5 |

---

## DAX #5 — Total Cobrado

**Panamá:**
```dax
Total Cobrado = 
COALESCE(
    SUM(Fact_Recaudo[importe_neto]), 
    0
)
```

**Venezuela:**
```dax
Total Cobrado = 
COALESCE(
    SUM(Fact_Recaudo[importe_neto]), 
    0
)
```

**Diferencia:** Sin cambios vs Panamá.
Fact_Recaudo Venezuela tiene importe_neto confirmado.

**Validación SQL:**
```sql
SELECT periodo,
       COUNT(*) AS cobros,
       ROUND(SUM(importe_neto), 2) AS total_cobrado
FROM Fact_Recaudo
GROUP BY periodo
ORDER BY periodo DESC;
```

---

## DAX #6 — % Mix Medios Pago

**Panamá:**
```dax
% Mix Medios Pago = 
VAR CobroPorCategoria = [Total Cobrado]
VAR CobroTotal = CALCULATE([Total Cobrado], ALL(Fact_Recaudo[metodo_pago]))
RETURN
IF(
    CobroPorCategoria < 0, 
    0, 
    DIVIDE(CobroPorCategoria, CobroTotal)
)
```

**Venezuela:**
```dax
% Mix Medios Pago = 
VAR CobroPorCategoria = [Total Cobrado]
VAR CobroTotal = CALCULATE([Total Cobrado], ALL(Fact_Recaudo[metodo_pago]))
RETURN
IF(
    CobroPorCategoria < 0, 
    0, 
    DIVIDE(CobroPorCategoria, CobroTotal)
)
```

**Diferencia:** Sin cambios vs Panamá.
Métodos Venezuela confirmados: CASHEA (~41%), 
TARJETA DEBITO (~31%), DIVISA (~13%), PAGO MOVIL (~7%),
TRANSFERENCIA (~5%), TARJETA CREDITO (~2%), 
EFECTIVO (~1%), LYSTO, TODOTICKET.

**Validación SQL:**
```sql
SELECT metodo_pago,
       COUNT(*) AS cobros,
       ROUND(SUM(importe_neto), 2) AS total_cobrado,
       ROUND(SUM(importe_neto) * 100.0 /
             SUM(SUM(importe_neto)) OVER(), 2) AS pct_participacion
FROM Fact_Recaudo
WHERE importe_neto > 0
AND periodo = '2026-04'
GROUP BY metodo_pago
ORDER BY total_cobrado DESC;
```

---

## DAX #7 — Proyección Venta Neta

**Panamá:**
```dax
Proyección Venta Neta = 
VAR FechaHoraGMT5 = UTCNOW() - (5/24)
VAR FechaHoyGMT5 = DATE(YEAR(FechaHoraGMT5), MONTH(FechaHoraGMT5), DAY(FechaHoraGMT5))
VAR MesHoy = MONTH(FechaHoyGMT5)
VAR AnioHoy = YEAR(FechaHoyGMT5)
VAR DiaHoy = DAY(FechaHoyGMT5)
VAR DiasTranscurridos = IF(DiaHoy = 1, 1, DiaHoy - 1) 
VAR UltimoDiaMes = DAY(EOMONTH(FechaHoyGMT5, 0))
VAR MesSeleccionado = SELECTEDVALUE('Dim_Tiempo'[Mes Nro])
VAR AnioSeleccionado = SELECTEDVALUE('Dim_Tiempo'[Año])
VAR VentaActual = [Venta Neta]
VAR CalculoProyeccion = DIVIDE(VentaActual, DiasTranscurridos, 0) * UltimoDiaMes
RETURN
IF(
    ISFILTERED('Dim_Tiempo'[Mes]) || ISFILTERED('Dim_Tiempo'[Date]), 
    IF(
        AnioSeleccionado < AnioHoy || (AnioSeleccionado = AnioHoy && MesSeleccionado < MesHoy),
        [Venta Neta],
        CalculoProyeccion
    ),
    CALCULATE(
        DIVIDE([Venta Neta], DiasTranscurridos, 0) * UltimoDiaMes,
        'Dim_Tiempo'[Mes Nro] = MesHoy,
        'Dim_Tiempo'[Año] = AnioHoy
    )
)
```

**Venezuela:**
```dax
Proyección Venta Neta = 
VAR FechaHoraGMT4 = UTCNOW() - (4/24)
VAR FechaHoyGMT4 = DATE(YEAR(FechaHoraGMT4), MONTH(FechaHoraGMT4), DAY(FechaHoraGMT4))
VAR MesHoy = MONTH(FechaHoyGMT4)
VAR AnioHoy = YEAR(FechaHoyGMT4)
VAR DiaHoy = DAY(FechaHoyGMT4)
VAR DiasTranscurridos = IF(DiaHoy = 1, 1, DiaHoy - 1) 
VAR UltimoDiaMes = DAY(EOMONTH(FechaHoyGMT4, 0))
VAR MesSeleccionado = SELECTEDVALUE('Dim_Tiempo'[Mes Nro])
VAR AnioSeleccionado = SELECTEDVALUE('Dim_Tiempo'[Año])
VAR VentaActual = [Venta Neta]
VAR CalculoProyeccion = DIVIDE(VentaActual, DiasTranscurridos, 0) * UltimoDiaMes
RETURN
IF(
    ISFILTERED('Dim_Tiempo'[Mes]) || ISFILTERED('Dim_Tiempo'[Date]), 
    IF(
        AnioSeleccionado < AnioHoy || (AnioSeleccionado = AnioHoy && MesSeleccionado < MesHoy),
        [Venta Neta],
        CalculoProyeccion
    ),
    CALCULATE(
        DIVIDE([Venta Neta], DiasTranscurridos, 0) * UltimoDiaMes,
        'Dim_Tiempo'[Mes Nro] = MesHoy,
        'Dim_Tiempo'[Año] = AnioHoy
    )
)
```

**Diferencia:** Solo cambia GMT-5 → GMT-4.
Corrección: DAY(FechaHoraGMT4) en línea 3 — no FechaHoyGMT4.
Lógica dual:
- Mes pasado → muestra Venta Neta real
- Mes actual → proyecta al cierre del mes

**Validación SQL:**
```sql
DECLARE @DiasTranscurridos INT = DAY(DATEADD(HOUR,-4,GETUTCDATE())) - 1;
DECLARE @UltimoDiaMes INT = DAY(EOMONTH(DATEADD(HOUR,-4,GETUTCDATE())));

SELECT 
    ROUND(SUM(monto_total), 2) AS venta_neta,
    @DiasTranscurridos AS dias_transcurridos,
    @UltimoDiaMes AS dias_del_mes,
    ROUND(SUM(monto_total) / @DiasTranscurridos * @UltimoDiaMes, 2) 
        AS proyeccion_cierre
FROM Fact_Ventas
WHERE periodo_factura = FORMAT(DATEADD(HOUR,-4,GETUTCDATE()),'yyyy-MM');
```

---

## DAX #21 — Cantidad Pedidos

**Panamá:**
```dax
Cantidad Pedidos = DISTINCTCOUNT(Fact_Pedidos[id_pedido])
```

**Venezuela:**
```dax
Cantidad Pedidos = DISTINCTCOUNT(Fact_Pedidos[id_pedido])
```

**Diferencia:** Sin cambios vs Panamá.
Fact_Pedidos Venezuela tiene id_pedido confirmado.

**Validación SQL:**
```sql
SELECT periodo_pedido,
       COUNT(DISTINCT id_pedido) AS cantidad_pedidos
FROM Fact_Pedidos
GROUP BY periodo_pedido
ORDER BY periodo_pedido DESC;
```

---

## DAX #9 — Net Sales

**Panamá:**
```dax
Net Sales = SUM('Fact_Ventas_Analitico'[monto_final_transaccional])
```

**Venezuela:**
```dax
Net Sales = SUM('Fact_Ventas_Analitico'[monto_final_transaccional])
```

**Diferencia:** Sin cambios vs Panamá.
Fact_Ventas_Analitico Venezuela tiene monto_final_transaccional
confirmado. subcategoria_lente eliminada por rendimiento —
no afecta este DAX.

**Validación SQL:**
```sql
SELECT periodo_venta,
       ROUND(SUM(monto_final_transaccional), 2) AS net_sales,
       SUM(cantidad) AS unidades
FROM Fact_Ventas_Analitico
GROUP BY periodo_venta
ORDER BY periodo_venta DESC;
```

---

## DAX #8 — Ticket Promedio

**Panamá:**
```dax
Ticket Promedio = 
COALESCE(
    DIVIDE([Venta Neta], [Cantidad Pedidos], 0), 
    0
)
```

**Venezuela:**
```dax
Ticket Promedio = 
COALESCE(
    DIVIDE([Venta Neta], [Cantidad Pedidos], 0), 
    0
)
```

**Diferencia:** Sin cambios vs Panamá.
Depende de DAX #3 Venta Neta y DAX #21 Cantidad Pedidos.

**Validación SQL:**
```sql
WITH VentaNeta AS (
    SELECT ROUND(SUM(monto_total), 2) AS venta_neta
    FROM Fact_Ventas
    WHERE periodo_factura = FORMAT(DATEADD(HOUR,-4,GETUTCDATE()),'yyyy-MM')
),
Pedidos AS (
    SELECT COUNT(DISTINCT id_pedido) AS cantidad_pedidos
    FROM Fact_Pedidos
    WHERE periodo_pedido = FORMAT(DATEADD(HOUR,-4,GETUTCDATE()),'yyyy-MM')
)
SELECT 
    V.venta_neta,
    P.cantidad_pedidos,
    ROUND(V.venta_neta / NULLIF(P.cantidad_pedidos, 0), 2) AS ticket_promedio
FROM VentaNeta V, Pedidos P;
```

---

## DAX #10 — Venta Neta (Producto)

**Panamá:**
```dax
Venta Neta (Producto) = SUM('Fact_Ventas_Detalle'[monto_final_transaccional])
```

**Venezuela:**
```dax
Venta Neta (Producto) = SUM('Fact_Ventas_Detalle'[monto_final_transaccional])
```

**Diferencia:** Sin cambios vs Panamá.
Fact_Ventas_Detalle Venezuela tiene monto_final_transaccional
confirmado. Granularidad por línea de factura.

**Validación SQL:**
```sql
SELECT periodo_venta,
       ROUND(SUM(monto_final_transaccional), 2) AS venta_neta_producto,
       SUM(cantidad) AS unidades,
       COUNT(DISTINCT id_factura) AS facturas
FROM Fact_Ventas_Detalle
GROUP BY periodo_venta
ORDER BY periodo_venta DESC;
```

---

## DAX #11 — Venta Teorica Lista

**Panamá:**
```dax
Venta Teorica Lista = 
SUMX(
    Fact_Ventas_Detalle, 
    Fact_Ventas_Detalle[cantidad] * Fact_Ventas_Detalle[precio_lista_unitario]
)
```

**Venezuela:**
```dax
Venta Teorica Lista = 
SUMX(
    Fact_Ventas_Detalle, 
    Fact_Ventas_Detalle[cantidad] * Fact_Ventas_Detalle[precio_lista_unitario]
)
```

**Diferencia:** Sin cambios vs Panamá.
Fact_Ventas_Detalle Venezuela tiene cantidad y 
precio_lista_unitario confirmados.
Venta Teorica - Venta Neta = descuentos aplicados.

**Validación SQL:**
```sql
SELECT periodo_venta,
       ROUND(SUM(cantidad * precio_lista_unitario), 2) AS venta_teorica,
       ROUND(SUM(monto_final_transaccional), 2) AS venta_real,
       ROUND(SUM(monto_final_transaccional) - 
             SUM(cantidad * precio_lista_unitario), 2) AS descuentos,
       ROUND((SUM(monto_final_transaccional) - 
             SUM(cantidad * precio_lista_unitario)) * 100.0 /
             NULLIF(SUM(cantidad * precio_lista_unitario), 0), 2) AS pct_descuento
FROM Fact_Ventas_Detalle
GROUP BY periodo_venta
ORDER BY periodo_venta DESC;
```

---

## DAX #12 — Color Alerta ETL

**Panamá:**
```dax
Color Alerta ETL = 
IF(
    SELECTEDVALUE(Vista_Notificacion_ETL[Estado_Salud]) = "OK", 
    "#2C3E50",
    "#AD0024"
)
```

**Venezuela:**
```dax
Color Alerta ETL = 
IF(
    SELECTEDVALUE(Vista_Notificacion_ETL[Estado_Salud]) = "OK",
    "#2C3E50",
    IF(
        SELECTEDVALUE(Vista_Notificacion_ETL[Estado_Salud]) = "EN PROCESO",
        "#F39C12",
        "#AD0024"
    )
)
```

**Diferencia:** Venezuela agrega tercer estado "EN PROCESO"
(amarillo #F39C12) — ETL corriendo normalmente < 15 minutos.
- OK → #2C3E50 Azul corporativo
- EN PROCESO → #F39C12 Amarillo
- ERROR → #AD0024 Rojo granate

**Validación SQL:**
```sql
SELECT Notificacion_Texto, Estado_Salud,
       modulos_completados, modulos_en_proceso, modulos_con_error
FROM Vista_Notificacion_ETL;
```

---

## DAX #13 — Filtro Mes Actual

**Panamá:**
```dax
Filtro Mes Actual = 
IF(
    MONTH(MAX('Dim_Tiempo'[Date])) = MONTH(TODAY()) && 
    YEAR(MAX('Dim_Tiempo'[Date])) = YEAR(TODAY()), 
    1, 
    0
)
```

**Venezuela:**
```dax
Filtro Mes Actual = 
IF(
    MONTH(MAX('Dim_Tiempo'[Date])) = MONTH(TODAY()) && 
    YEAR(MAX('Dim_Tiempo'[Date])) = YEAR(TODAY()), 
    1, 
    0
)
```

**Diferencia:** Sin cambios vs Panamá.
TODAY() en Power BI usa la hora local del servidor
donde está publicado — verificar en producción Azure.

**Validación SQL:**
```sql
SELECT Date, Slicer_Mes, Filtro_Comparativo_Dinamico
FROM Dim_Tiempo
WHERE Slicer_Mes = 'Mes Actual'
ORDER BY Date DESC;
```

---
