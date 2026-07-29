# Dolarización — Convenciones y decisiones del proyecto

Este documento es la fuente de verdad de las decisiones tomadas para la migración del portal a
mostrar montos en USD. Cualquier tarea futura relacionada a este proyecto debe respetar lo acá
definido, salvo que se indique explícitamente lo contrario en el prompt de la tarea.

## Decisiones de producto (cerradas)

- El portal muestra montos **únicamente en USD**. No hay toggle de moneda ni columnas en Bs
  visibles en ningún reporte.
- El KPI "Venta Neta" se muestra en dos tarjetas separadas, igual que en Power BI:
  "Venta Neta USD" (con IVA) y "Venta Neta Sin Impuesto USD" (sin IVA). No se fusionan en una sola.
- El indicador UPT (Unidades por Ticket) de Inventario aún no fue validado por el equipo de datos
  (VisioFlow) contra el sistema fuente. Se implementa igual, pero debe quedar marcado en la UI
  como un dato pendiente de validación hasta nuevo aviso.

## Origen de los datos en USD

- Los montos en USD se leen siempre de las vistas `Fact_*` / `KPI_*` de la base de datos
  (`db-opticolor-dw`), que ya vienen validadas contra el sistema fuente (Gesvision).
- **Nunca** se leen montos en USD desde las tablas materializadas `Dash_*`
  (`Dash_Ventas_Resumen`, `Dash_Recaudo_Agregado`, `Dash_Clinico_Agregado`,
  `Dash_Eficiencia_Agregado`, `Dash_Inventario_Agregado`, `Dash_Inventario_Resumen`), porque esas
  tablas no tienen columnas `_usd`. Cualquier Server Action que hoy lea de una tabla `Dash_*`
  debe migrarse a la vista `Fact_*`/`KPI_*` equivalente en el momento en que se toque ese módulo.
- No se reimplementa ninguna lógica de tasa de cambio ni conversión en el portal. Si parece
  necesario calcular una conversión manualmente, es señal de que falta una columna en la base de
  datos, no algo a resolver en el frontend.

## Convención de nombres de campos (TypeScript)

- Los tipos de cada módulo (`KpiData`, `CarteraKpiData`, `ClinicaKpis`, `EficienciaKpis`,
  `InventarioKpis`, etc.) usan **camelCase con sufijo `Usd`**, reflejando 1:1 el nombre de columna
  SQL de origen. Ejemplo: la columna `monto_total_usd` se mapea al campo `montoTotalUsd`.
- No se inventan nombres nuevos ni se abrevia — el mapeo columna SQL → campo TypeScript debe ser
  directo y auditable con solo mirar el nombre.
- Ningún tipo ni ninguna respuesta de Server Action debe incluir campos en bolívares. Si hoy un
  tipo tiene `montoTotal` (Bs) y `montoTotalUsd` en paralelo, al migrar ese módulo se elimina el
  campo en Bs — no conviven ambos.

## Formateo

- Toda moneda del portal se formatea exclusivamente con la función `formatCurrency` de
  `src/lib/utils.ts`. Ningún componente debe reimplementar formateo de moneda por su cuenta.

## Estado transitorio (Fase 1 → Fase 2)

- `formatCurrency` tiene como valor por defecto el formato en Bolívares, porque a la fecha
  (28 de julio de 2026) ningún reporte fue migrado todavía a leer columnas `_usd`
  de la base de datos.
- Cuando se migre un reporte en Fase 2, el cambio a USD se hace en dos frentes a la vez:
  la Server Action pasa a leer la columna `_usd` correspondiente, Y los componentes de ese
  reporte pasan a llamar `formatCurrency(valor, { currency: "USD" })` explícitamente. Nunca se
  cambia el default global de la función — cada reporte declara su propia moneda cuando
  realmente la tiene disponible.
- Esta sección se puede eliminar una vez que los 5 reportes estén migrados y ya no quede
  ningún dato en Bs en ningún módulo del portal.

## Insumo obligatorio para tareas de Fase 2 en adelante

- Antes de escribir o modificar cualquier query SQL, consultar `docs/Auditoria Base de Datos.xlsx`
  (inventario completo de tablas, vistas, columnas y stored procedures de `db-opticolor-dw`) para
  confirmar los nombres reales de columnas y vistas.
- No se deben asumir, adivinar ni inventar nombres de columnas o vistas que no figuren
  explícitamente en ese archivo. Si una columna que se necesita no aparece ahí, se reporta como
  pregunta abierta en vez de asumir un nombre plausible.
