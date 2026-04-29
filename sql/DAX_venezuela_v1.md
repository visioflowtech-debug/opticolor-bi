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
| 14 | Monto Pedidos | ✅ 27/04/2026 |
| 15 | Monto Saldo Pendiente | ✅ 28/04/2026 |
| 16 | Recaudado en Pedidos | ✅ 28/04/2026 |
| 17 | % Cobro Inmediato | ✅ 28/04/2026 |
| 18 | % Nivel de Abono | ✅ 28/04/2026 |
| 19 | Pedidos por Liquidar | ✅ 28/04/2026 |
| 20 | Total Exámenes | ✅ 28/04/2026 |
| 21 | Cantidad Pedidos | ✅ 27/04/2026 |
| 22 | % Cierre General | ✅ 28/04/2026 |
| 23 | Stock Fisico (Unds) | ✅ 28/04/2026 |
| 24 | Capital Invertido | ✅ 28/04/2026 |
| 25 | Unidades Vendidas | ✅ 28/04/2026 |
| 26 | UPT | ✅ 28/04/2026 |
| 27 | ASP | ✅ 28/04/2026 |
| 28 | Volumen Unidades | ✅ 28/04/2026 |

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

## DAX #14 — Monto Pedidos

**Panamá:**
```dax
Monto Pedidos = COALESCE(SUM(Fact_Pedidos[monto_total]), 0)
```

**Venezuela:**
```dax
Monto Pedidos = COALESCE(SUM(Fact_Pedidos[monto_total]), 0)
```

**Diferencia:** Sin cambios vs Panamá.
Fact_Pedidos Venezuela tiene monto_total confirmado.

**Validación SQL:**
```sql
SELECT periodo_pedido,
       COUNT(DISTINCT id_pedido) AS pedidos,
       ROUND(SUM(monto_total), 2) AS monto_total
FROM Fact_Pedidos
GROUP BY periodo_pedido
ORDER BY periodo_pedido DESC;
```

---

## DAX #15 — Monto Saldo Pendiente

**Panamá:**
```dax
Monto Saldo Pendiente = COALESCE(SUM(Fact_Pedidos[saldo_pendiente]), 0)
```

**Venezuela:**
```dax
Monto Saldo Pendiente = COALESCE(SUM(Fact_Pedidos[saldo_pendiente]), 0)
```

**Diferencia:** Sin cambios vs Panamá.
Venezuela tiene saldo_pendiente confirmado en Fact_Pedidos.
Incluye saldos negativos (sobrepagos) y positivos (deuda).

**Validación SQL:**
```sql
SELECT periodo_pedido,
       COUNT(DISTINCT CASE WHEN saldo_pendiente > 0 
             THEN id_pedido END) AS pedidos_con_deuda,
       ROUND(SUM(saldo_pendiente), 2) AS saldo_neto,
       ROUND(SUM(CASE WHEN saldo_pendiente > 0 
             THEN saldo_pendiente ELSE 0 END), 2) AS total_por_cobrar
FROM Fact_Pedidos
GROUP BY periodo_pedido
ORDER BY periodo_pedido DESC;
```

---

## DAX #16 — Recaudado en Pedidos

**Panamá:**
```dax
Recaudado en Pedidos = COALESCE(SUM(Fact_Pedidos[monto_pagado]), 0)
```

**Venezuela:**
```dax
Recaudado en Pedidos = COALESCE(SUM(Fact_Pedidos[monto_pagado]), 0)
```

**Diferencia:** Sin cambios vs Panamá.
Fact_Pedidos Venezuela tiene monto_pagado confirmado.

**Validación SQL:**
```sql
SELECT periodo_pedido,
       ROUND(SUM(monto_pagado), 2) AS recaudado,
       ROUND(SUM(monto_total), 2) AS total_pedidos,
       ROUND(SUM(monto_pagado) * 100.0 /
             NULLIF(SUM(monto_total), 0), 2) AS pct_recaudado
FROM Fact_Pedidos
GROUP BY periodo_pedido
ORDER BY periodo_pedido DESC;
```

---

## DAX #17 — % Cobro Inmediato

**Panamá:**
```dax
% Cobro Inmediato = 
VAR TotalPedidos = DISTINCTCOUNT('Fact_Pedidos'[id_pedido])
VAR PedidosPagadosFull = 
    CALCULATE(
        DISTINCTCOUNT('Fact_Pedidos'[id_pedido]),
        FILTER('Fact_Pedidos', 'Fact_Pedidos'[saldo_pendiente] = 0)
    ) 
RETURN 
COALESCE(
    DIVIDE(PedidosPagadosFull, TotalPedidos, 0), 
    0
)
```

**Venezuela:**
```dax
% Cobro Inmediato = 
VAR TotalPedidos = DISTINCTCOUNT('Fact_Pedidos'[id_pedido])
VAR PedidosPagadosFull = 
    CALCULATE(
        DISTINCTCOUNT('Fact_Pedidos'[id_pedido]),
        FILTER('Fact_Pedidos', 'Fact_Pedidos'[saldo_pendiente] <= 0)
    ) 
RETURN 
COALESCE(
    DIVIDE(PedidosPagadosFull, TotalPedidos, 0), 
    0
)
```

**Diferencia:** Panamá usa = 0, Venezuela usa <= 0
para incluir sobrepagos (saldo negativo = pagado de más).
Confirmado: Venezuela tiene pedidos con saldo negativo.

**Validación SQL:**
```sql
SELECT periodo_pedido,
       COUNT(DISTINCT id_pedido) AS total_pedidos,
       COUNT(DISTINCT CASE WHEN saldo_pendiente <= 0 
             THEN id_pedido END) AS pedidos_cobrados,
       ROUND(COUNT(DISTINCT CASE WHEN saldo_pendiente <= 0 
             THEN id_pedido END) * 100.0 /
             NULLIF(COUNT(DISTINCT id_pedido), 0), 2) AS pct_cobro_inmediato
FROM Fact_Pedidos
GROUP BY periodo_pedido
ORDER BY periodo_pedido DESC;
```

---

## DAX #18 — % Nivel de Abono

**Panamá:**
```dax
% Nivel de Abono = 
COALESCE(
    DIVIDE([Recaudado en Pedidos], [Monto Pedidos], 0), 
    0
)
```

**Venezuela:**
```dax
% Nivel de Abono = 
COALESCE(
    DIVIDE([Recaudado en Pedidos], [Monto Pedidos], 0), 
    0
)
```

**Diferencia:** Sin cambios vs Panamá.
Depende de DAX #16 Recaudado en Pedidos y DAX #14 Monto Pedidos.

**Validación SQL:**
```sql
SELECT periodo_pedido,
       ROUND(SUM(monto_pagado), 2) AS recaudado,
       ROUND(SUM(monto_total), 2) AS total_pedidos,
       ROUND(SUM(monto_pagado) * 100.0 /
             NULLIF(SUM(monto_total), 0), 2) AS pct_nivel_abono
FROM Fact_Pedidos
GROUP BY periodo_pedido
ORDER BY periodo_pedido DESC;
```

---

## DAX #19 — Pedidos por Liquidar

**Panamá:**
```dax
Pedidos por Liquidar = 
COALESCE(
    CALCULATE(
        DISTINCTCOUNT('Fact_Pedidos'[id_pedido]),
        FILTER('Fact_Pedidos', 'Fact_Pedidos'[saldo_pendiente] > 0)
    ), 
    0
)
```

**Venezuela:**
```dax
Pedidos por Liquidar = 
COALESCE(
    CALCULATE(
        DISTINCTCOUNT('Fact_Pedidos'[id_pedido]),
        FILTER('Fact_Pedidos', 'Fact_Pedidos'[saldo_pendiente] > 0)
    ), 
    0
)
```

**Diferencia:** Sin cambios vs Panamá.
Venezuela tiene 280 pedidos por liquidar en abril
con Bs 6.9M pendiente de cobro.

**Validación SQL:**
```sql
SELECT periodo_pedido,
       COUNT(DISTINCT id_pedido) AS pedidos_por_liquidar,
       ROUND(SUM(saldo_pendiente), 2) AS total_por_cobrar,
       ROUND(AVG(saldo_pendiente), 2) AS promedio_saldo
FROM Fact_Pedidos
WHERE saldo_pendiente > 0
GROUP BY periodo_pedido
ORDER BY periodo_pedido DESC;
```

---

## DAX #20 — Total Exámenes

**Panamá:**
```dax
Total Exámenes = 
COALESCE(COUNTROWS('Fact_Examenes'), 0)
```

**Venezuela:**
```dax
Total Exámenes = 
COALESCE(COUNTROWS('Fact_Examenes'), 0)
```

**Diferencia:** Sin cambios vs Panamá.
Venezuela tiene exámenes desde enero 2026.
Sin tipo_examen (NULL en todos los registros).

**Validación SQL:**
```sql
SELECT periodo_examen,
       COUNT(id_examen) AS total_examenes,
       COUNT(DISTINCT id_sucursal) AS sucursales_activas,
       COUNT(DISTINCT id_optometrista) AS optometristas
FROM Fact_Examenes
GROUP BY periodo_examen
ORDER BY periodo_examen DESC;
```

---

## DAX #22 — % Cierre General

**Panamá:**
```dax
% Cierre General = 
VAR PacientesAtendidos = [Total Exámenes]
VAR VentasCerradas = [Total Pedidos]
RETURN
DIVIDE(VentasCerradas, PacientesAtendidos, 0)
```

**Venezuela:**
```dax
% Cierre General = 
VAR PacientesAtendidos = [Total Exámenes]
VAR VentasCerradas = [Cantidad Pedidos]
RETURN
DIVIDE(VentasCerradas, PacientesAtendidos, 0)
```

**Diferencia:** Venezuela usa [Cantidad Pedidos] en lugar de
[Total Pedidos] porque Total Pedidos depende de 
Fact_Operaciones_Maestra que en Venezuela no tiene
estados logísticos. Cantidad Pedidos usa Fact_Pedidos directo.
Puede superar 100% — válido en Venezuela porque el examen
no es obligatorio para comprar.

**Validación SQL:**
```sql
WITH Pedidos AS (
    SELECT periodo_pedido AS periodo,
           COUNT(DISTINCT id_pedido) AS cantidad_pedidos
    FROM Fact_Pedidos
    GROUP BY periodo_pedido
),
Examenes AS (
    SELECT periodo_examen AS periodo,
           COUNT(id_examen) AS total_examenes
    FROM Fact_Examenes
    GROUP BY periodo_examen
)
SELECT P.periodo,
       P.cantidad_pedidos,
       E.total_examenes,
       ROUND(P.cantidad_pedidos * 100.0 /
             NULLIF(E.total_examenes, 0), 2) AS pct_cierre
FROM Pedidos P
LEFT JOIN Examenes E ON P.periodo = E.periodo
ORDER BY P.periodo DESC;
```

---

## DAX #23 — Stock Fisico (Unds)

**Panamá:**
```dax
Stock Fisico (Unds) = 
SUMX(
    GENERATE(
        VALUES('Dim_Productos'[SK_Producto]),
        CALCULATETABLE(Fact_Inventario)
    ),
    Fact_Inventario[cantidad_disponible]
)
```

**Venezuela:**
```dax
Stock Fisico (Unds) = 
SUMX(
    GENERATE(
        VALUES('Dim_Productos'[SK_Producto]),
        CALCULATETABLE(Fact_Inventario)
    ),
    Fact_Inventario[cantidad_disponible]
)
```

**Diferencia:** Sin cambios vs Panamá.
⚠️ CONFIGURACIÓN REQUERIDA: Desactivar interacción del 
slicer Dim_Tiempo con este visual en Power BI.
El inventario es foto del stock actual — no tiene 
dimensión temporal. Sin esta configuración muestra (Blank).
En Power BI: seleccionar visual → Format → Edit interactions
→ apagar el slicer de fecha para este visual.

**Validación SQL:**
```sql
SELECT 
    COUNT(DISTINCT I.id_producto) AS productos,
    COUNT(DISTINCT I.id_sucursal) AS sucursales,
    SUM(I.cantidad_disponible) AS stock_total
FROM Fact_Inventario I
INNER JOIN Dim_Productos P ON I.id_producto = P.SK_Producto;
```

**Resultado validado 27/04/2026:**
| productos | sucursales | stock_total |
|---|---|---|
| 13025 | 28 | 121,325 |

---

## DAX #24 — Capital Invertido

**Panamá:**
```dax
Capital Invertido = 
COALESCE(
    SUM(Fact_Inventario[valor_total_inventario]), 
    0
)
```

**Venezuela:**
```dax
Capital Invertido = 
COALESCE(
    SUM(Fact_Inventario[valor_total_inventario]), 
    0
)
```

**Diferencia:** Sin cambios vs Panamá.
⚠️ CONFIGURACIÓN REQUERIDA: Igual que Stock Fisico —
desactivar interacción del slicer Dim_Tiempo con este visual.

**Validación SQL:**
```sql
SELECT 
    COUNT(DISTINCT id_producto) AS productos,
    SUM(cantidad_disponible) AS stock_total,
    ROUND(SUM(valor_total_inventario), 2) AS capital_invertido
FROM Fact_Inventario
WHERE valor_total_inventario > 0;
```

---

## DAX #25 — Unidades Vendidas

**Panamá:**
```dax
Unidades Vendidas = 
COALESCE(
    SUM(Fact_Ventas_Detalle[cantidad]), 
    0
)
```

**Venezuela:**
```dax
Unidades Vendidas = 
COALESCE(
    SUM(Fact_Ventas_Detalle[cantidad]), 
    0
)
```

**Diferencia:** Sin cambios vs Panamá.
Fact_Ventas_Detalle Venezuela tiene cantidad confirmado.

**Validación SQL:**
```sql
SELECT periodo_venta,
       SUM(cantidad) AS unidades_vendidas,
       COUNT(DISTINCT id_factura) AS facturas
FROM Fact_Ventas_Detalle
GROUP BY periodo_venta
ORDER BY periodo_venta DESC;
```

---

## DAX #26 — Unidades por Ticket (UPT)

**Panamá:**
```dax
Unidades por Ticket (UPT) = 
COALESCE(
    DIVIDE([Unidades Vendidas], [Cantidad Facturas], 0), 
    0
)
```

**Venezuela:**
```dax
Unidades por Ticket (UPT) = 
COALESCE(
    DIVIDE([Unidades Vendidas], [Cantidad Facturas], 0), 
    0
)
```

**Diferencia:** Sin cambios vs Panamá.
Depende de DAX #25 Unidades Vendidas y DAX #4 Cantidad Facturas.

**Validación SQL:**
```sql
WITH Unidades AS (
    SELECT SUM(cantidad) AS unidades_vendidas
    FROM Fact_Ventas_Detalle
    WHERE periodo_venta = FORMAT(DATEADD(HOUR,-4,GETUTCDATE()),'yyyy-MM')
),
Facturas AS (
    SELECT COUNT(DISTINCT id_factura) AS cantidad_facturas
    FROM Fact_Ventas
    WHERE tipo_transaccion = 'Venta'
    AND periodo_factura = FORMAT(DATEADD(HOUR,-4,GETUTCDATE()),'yyyy-MM')
)
SELECT 
    U.unidades_vendidas,
    F.cantidad_facturas,
    ROUND(U.unidades_vendidas / NULLIF(F.cantidad_facturas, 0), 2) AS upt
FROM Unidades U, Facturas F;
```

---

## DAX #27 — ASP (Precio Promedio)

**Panamá:**
```dax
ASP (Precio Promedio) = 
COALESCE(
    DIVIDE([Venta Neta (Producto)], [Unidades Vendidas], 0), 
    0
)
```

**Venezuela:**
```dax
ASP (Precio Promedio) = 
COALESCE(
    DIVIDE([Venta Neta (Producto)], [Unidades Vendidas], 0), 
    0
)
```

**Diferencia:** Sin cambios vs Panamá.
Depende de DAX #10 Venta Neta (Producto) y DAX #25 Unidades Vendidas.

**Validación SQL:**
```sql
WITH VentaNeta AS (
    SELECT ROUND(SUM(monto_final_transaccional), 2) AS venta_neta
    FROM Fact_Ventas_Detalle
    WHERE periodo_venta = FORMAT(DATEADD(HOUR,-4,GETUTCDATE()),'yyyy-MM')
),
Unidades AS (
    SELECT SUM(cantidad) AS unidades_vendidas
    FROM Fact_Ventas_Detalle
    WHERE periodo_venta = FORMAT(DATEADD(HOUR,-4,GETUTCDATE()),'yyyy-MM')
)
SELECT 
    V.venta_neta,
    U.unidades_vendidas,
    ROUND(V.venta_neta / NULLIF(U.unidades_vendidas, 0), 2) AS asp
FROM VentaNeta V, Unidades U;
```

---

## DAX #28 — Volumen Unidades

**Panamá:**
```dax
Volumen Unidades = SUM(Fact_Ventas_Analitico[cantidad])
```

**Venezuela:**
```dax
Volumen Unidades = SUM(Fact_Ventas_Analitico[cantidad])
```

**Diferencia:** Sin cambios vs Panamá.
Fact_Ventas_Analitico Venezuela tiene cantidad confirmado.
subcategoria_lente eliminada por rendimiento — no afecta este DAX.

**Validación SQL:**
```sql
SELECT periodo_venta,
       SUM(cantidad) AS volumen_unidades,
       COUNT(DISTINCT id_sucursal) AS sucursales
FROM Fact_Ventas_Analitico
GROUP BY periodo_venta
ORDER BY periodo_venta DESC;
```

---
