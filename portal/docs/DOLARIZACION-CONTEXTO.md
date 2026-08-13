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

## Lecciones de Fase 2 (por módulo)

- **Bug de parseo de fechas (ya corregido en los 5 reportes).** Los 5 `page.tsx` de reporte
  (`resumen-comercial`, `cartera`, `clinico`, `eficiencia`, `inventario`) reparseaban `from`/`to`
  con `format(new Date(from), "yyyy-MM-dd")` aunque esos parámetros ya llegan en formato
  `"yyyy-MM-dd"` válido desde `date-range-picker.tsx`. Un string solo-fecha se interpreta como
  medianoche UTC, y `format()` la renderiza en la zona horaria local del servidor — en zonas al
  oeste de UTC (Venezuela incluida) esto podía correr la fecha seleccionada un día completo hacia
  atrás, mostrando datos de un día distinto al elegido en el UI. Se corrigió en los 5 archivos:
  ahora `from`/`to` se usan directamente (`from ?? format(startOfMonth(new Date()), "yyyy-MM-dd")`),
  sin volver a pasarlos por `new Date(...)`.
- **Algunos KPIs reflejan el estado actual de la base, no una foto histórica de la fecha
  filtrada.** En Cartera, "Monto Saldo Pendiente" y "Órdenes por Liquidar" (`KPI_Inf3_Saldo_Pendiente`,
  `KPI_Inf3_Pedidos_Liquidar`) filtran con `fecha_pedido_completa <= @endDate`, pero el
  `saldo_pendiente_usd` que traen es el saldo **vigente hoy** de esos pedidos, no el saldo que
  tenían el día del filtro. Si un pedido se termina de pagar entre la fecha filtrada y el momento
  de la consulta, deja de aparecer con saldo pendiente — es comportamiento esperado, no un bug.
  Esto hace que validar estos KPIs específicos contra un cuadre capturado en otro día casi
  siempre dé una diferencia (generalmente a la baja, nunca al alza) que no hay que "corregir".
  Antes de asumir un bug en un KPI de este tipo en otro módulo, primero confirmar con casos
  puntuales (pedido por pedido, contra `Fact_Pedidos`/la vista `KPI_*` correspondiente) si el
  cálculo en sí es correcto — recién si un caso puntual también difiere, hay algo real que mirar.
- **`ChartTooltipContainer`** (`src/components/ui/chart-tooltip-container.tsx`, componente
  compartido) ahora acepta un prop opcional `currency` — se usa junto con `isCurrency={true}`
  para pedir formateo en USD explícito (`<ChartTooltipContainer isCurrency currency="USD" />`).
  Sin ese prop sigue formateando en Bs por default, así que los módulos no migrados no se ven
  afectados.
- **Cuidado al tocar funciones compartidas que algún módulo pasa "bare" a `tickFormatter` de
  Recharts** (`formatCompactCurrency`, y potencialmente otras). Recharts invoca esos callbacks
  como `(value, index: number)`; si se le agrega un segundo parámetro de opciones al tipo de la
  función, TypeScript puede romper la compilación en *otro* módulo que ni se está tocando, porque
  el `index` numérico ya no es asignable al nuevo tipo del segundo parámetro. Antes de agregar un
  parámetro a una función compartida, grepear todo `src/` por usos "bare" (`tickFormatter={fn}`,
  sin arrow function envolviendo la llamada) y diseñar el tipo para que siga aceptando `number`
  en ese segundo lugar sin cambiar el comportamiento por default.

## Visuales sin filtro de fecha (paridad con Power BI)

Confirmado por revisión directa del .pbix (Edit Interactions / Performance Analyzer) que estos
visuales NO están vinculados al slicer de fecha en Power BI — solo al de sucursal. Al migrar
cada reporte, verificar si el portal replica esto o si aplica un filtro de fecha que no debería.

- **Resumen Comercial:** gráfico de relación de Ventas Netas y Tráfico de Ventas — confirmado por
  el usuario en el `.pbix`, pendiente de aplicar cuando se migre este reporte.
- **Cartera:** Monto Saldo Pendiente, Órdenes por Liquidar, gráfico de tendencia GAP de Cobro,
  tabla de Clientes Deudores — todos corregidos.
- **Eficiencia:** gráfico de Tendencia de Órdenes — corregido.
- **Desempeño Clínico:** gráfico de Exámenes (Volumen Total vs. Conversión), gráfico de Tendencia
  de Exámenes por Mes — corregidos (Prompt Fase 2 Clínico). Nota: este módulo no tiene ningún KPI
  ni gráfico monetario (todos son de conteo/porcentaje), así que el único fix aplicable acá fue el
  de la ventana de tendencia, no hubo migración de moneda.
- **Inventario:** Stock Físico (Unidades), Capital Invertido — confirmado por el usuario en el
  `.pbix`, pendiente de aplicar cuando se migre este reporte.

Metodología: nunca asumir que un visual debe desvincularse solo por estar en esta lista — validar
primero con una consulta directa comparando contra el valor/comportamiento real de Power BI, y
recién ahí aplicar el cambio.

**Nota sobre gráficos de tendencia (series, no tarjetas):** en Cartera (GAP de Cobro) y Eficiencia
(Tendencia de Órdenes) las queries ya usaban una ventana de "últimos 12 meses" independiente de
`@startDate`, pero seguían anclando el límite superior de esa ventana a `@endDate` (el fin del
rango seleccionado en el picker). Se confirmó con una consulta directa que esto SÍ hacía
reaccionar el gráfico al slicer: con un `@endDate` fuera del rango real de datos, la serie
completa se vaciaba. El fix fue anclar la ventana a `GETDATE()` (fecha actual del servidor) en vez
de `@endDate`, dejando el filtro de sucursal/RLS intacto. Este mismo patrón ("ventana de tiempo
fija de N meses, pero anclada a `@endDate` en vez de a `GETDATE()`") es el primer lugar a revisar
en cualquier gráfico de tendencia de los reportes aún no migrados.

## Metodología de validación

- **Nunca validar el portal contra Power BI usando un rango de fechas que incluya el día de hoy**
  (o cualquier día posterior al último refresh conocido de Power BI). El portal consulta la base
  de datos en vivo; Power BI trabaja sobre un snapshot que se actualiza en su propio ciclo de
  refresh (confirmado: el último fue a las 8pm). El ETL interno de Opticolor (`Etl_Ciclos`) sigue
  corriendo después de ese refresh — se confirmó actividad a las 20:00, 22:00, 00:00 y 02:28 del
  mismo ciclo diario, con `Etl_Checkpoints.checkpoint_exams_watermark` en `2026-07-29 02:29:22` —
  por lo que cualquier transacción cargada por esos ciclos posteriores al refresh de Power BI
  aparece de inmediato en el portal pero no en Power BI hasta su próximo refresh.
- **Cómo validar correctamente:** comparar siempre contra días ya cerrados (ej. 01/07 al 27/07 en
  vez de 01/07 al 28/07 si "hoy" es 28/07), o si hace falta validar el día en curso, comparar contra
  la hora exacta del último refresh conocido de Power BI, no contra "ahora".
- **Evidencia de referencia (Eficiencia, todas las sucursales):** rango 01/07 al 27/07 (cerrado) =
  16,158 órdenes / \$2,220,796.33 USD. Rango 01/07 al 28/07 (incluye hoy) = 16,681 órdenes /
  \$2,297,218.67 USD. El día de hoy por sí solo aporta 523 órdenes / \$76,422.34 USD — una
  diferencia grande, esperable, y que no debe interpretarse como un bug de cálculo.

## `DualKpiCard`: el ícono debe pasarse como string, no como referencia cruda al componente

`DualKpiCard` (y `KpiCard`) son Client Components (`"use client"`), pero se renderizan siempre
desde Server Components (los `page.tsx` de cada reporte). React no puede serializar en el límite
Server→Client una referencia de función/componente sin resolver (ej. `icon={DollarSign}`, la
importación cruda de `lucide-react`) — solo datos planos (string, number, boolean, objetos/arrays
de esos) o JSX ya renderizado. Pasar `icon={DollarSign}` directo desde un `page.tsx` revienta el
sitio con: *"Functions cannot be passed directly to Client Components..."* / *"Only plain objects
can be passed to Client Components..."*.

El patrón correcto, ya usado por `KpiCard` en todo el portal: el Server Component pasa un
`iconName` de tipo `string` (ej. `"dollar-sign"`), y el propio Client Component resuelve ese string
a un componente de ícono mediante un diccionario (`ICON_MAP`) importado y definido **dentro** del
archivo cliente. `DualKpiCard` se corrigió para seguir el mismo patrón (antes recibía `icon:
LucideIcon` como prop). Cualquier uso futuro de `DualKpiCard` en otro módulo debe pasar
`iconName="..."`, nunca la referencia al componente de ícono.

## Formato numérico venezolano y precisión completa en tarjetas KPI

- **Separadores:** el portal usa convención venezolana — punto de miles, coma decimal
  (ej. `$1.234,56`, `60.112`), no el estilo `en-US` (`1,234.56`) usado originalmente. Esto se
  implementa centralizado en `src/lib/utils.ts` vía el locale `es-VE` (constante interna
  `VE_LOCALE`), usado por `formatCurrency`, `formatCompactCurrency`, `formatNumber` y
  `formatCompactNumber`. Ningún componente debe formatear números por su cuenta con
  `.toLocaleString("en-US")` ni codificar separadores a mano.
- **Detalle importante de `Intl` verificado con ejecución real:** `Intl.NumberFormat('es-VE',
  { style: 'currency', currency: 'USD' })` antepone el string `"USD"` en vez de un símbolo `$`
  limpio (da `"USD 1.234,56"`). Hace falta el flag `currencyDisplay: 'narrowSymbol'` para obtener
  `"$1.234,56"` exacto. `es-ES` tampoco sirve (pospone `"US$"` al final: `"1234,56 US$"`). Si en el
  futuro se toca el formateo de moneda, verificar siempre con una ejecución real de `Intl` — el
  comportamiento por locale no es intuitivo ni está bien documentado.
- **`formatNumber`** (nueva función): formatea conteos/enteros no monetarios con separador de
  miles venezolano, sin abreviar (ej. `60112` → `"60.112"`). Reemplaza los usos de
  `.toLocaleString("en-US")` para conteos (Clientes Nuevos, Volumen de Órdenes, etc.).
- **`formatCompactCurrency`/`formatCompactNumber`:** se mantienen (siguen usándose en ejes y
  tooltips de gráficos, donde el espacio limitado sigue requiriendo abreviación K/M/B) — solo se
  les aplicó el separador venezolano en la parte decimal (ej. `"271,8 M"` en vez de `"271.8 M"`).
  Abreviación de magnitud y formato de separadores son decisiones independientes entre sí.
- **Tarjetas KPI — valor completo, sin abreviar:** decisión de producto — las tarjetas KPI de los
  5 reportes ya no muestran el patrón abreviado (`value` corto + `fullValue` completo solo en
  tooltip); se pasa a mostrar siempre el valor completo (`formatCurrency`/`formatNumber`)
  directamente. Este cambio de fuente es la base (Prompt 1); el rollout a los componentes de los
  5 reportes es un prompt aparte.
- **Montos USD sin decimales — truncados, no redondeados:** decisión de producto — todo monto en
  USD formateado con `formatCurrency(valor, { currency: "USD" })` muestra 0 decimales, truncando
  la parte decimal (`Math.trunc`) en vez de redondearla (ej. `3.815.996,94` → `$3.815.996`, nunca
  `$3.815.997`). `maximumFractionDigits: 0` en `Intl.NumberFormat` redondea por defecto, así que
  el truncamiento se hace manualmente sobre el número ANTES de formatear — no se usa
  `roundingMode: 'trunc'` (soportado en Node 24 local, pero no verificable contra el runtime real
  de producción, `node:20-alpine`, en este entorno). `formatCompactCurrency` aplica el mismo
  criterio al decimal de su forma abreviada (ej. `2,359 M` no sube a `2,4 M`) solo en su rama USD;
  su rama Bs. (formato transitorio) sigue redondeando igual que antes, fuera del alcance de este
  cambio. Los montos en Bs. (`formatCurrency` sin `currency` explícito) no fueron tocados.
