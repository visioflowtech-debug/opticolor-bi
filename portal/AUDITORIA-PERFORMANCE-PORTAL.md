# Auditoría de Performance 360° — Portal Opticolor

**Alcance:** solo lectura (código de aplicación, no infraestructura Azure/ETL/Power BI). Análisis desde cero, sin referencia a auditorías previas del repositorio.
**Metodología:** inventario completo de `src/app/`, lectura línea a línea de 20 archivos de Server Actions + páginas + componentes cliente, `next build --webpack` real cronometrado, inspección de `.next/static` y `.next/build-manifest.json`, conteo de uso real de cada dependencia de `package.json` en `src/`.
**Fecha de medición:** 2026-08-13. **Build:** Next.js 16.2.4, React 19.2.4, webpack.

---

## 1. Resumen ejecutivo

1. **El 54% del payload estático (2.68 MB de 4.98 MB en `.next/static`) son fuentes.** El layout raíz (`src/app/layout.tsx:40`) aplica las **17 familias tipográficas** de `fontVars` (`src/lib/fonts/registry.ts`) de forma incondicional en el `<body>` de cada página, para una feature de "elegir 1 fuente" en el selector de tema — 96 archivos `.woff2` autohospedados. No confirmamos descarga forzada en runtime (no hay `<link rel=preload>` de fuentes en el HTML generado), pero infla el artefacto de build/deploy de forma directamente evitable.
2. **N+1 de escritura severo en `editar-usuario.ts`:** hasta **2×N round-trips secuenciales** a Azure SQL para reasignar N sucursales de un usuario (`SELECT` existencia + `UPDATE`/`INSERT` dentro de un `for`, líneas 171-203). Con un usuario de 10 sucursales son 20 round-trips extra solo en esa sección, sumados a ~6 más del resto de la acción. `crear-usuario.ts` tiene el mismo patrón para altas nuevas (líneas 106-115).
3. **Cardinalidad de caché sin techo en Eficiencia e Inventario:** la clave de `unstable_cache` incluye rango de fecha libre (sin presets) × sucursal multi-select (`2^N−1` subconjuntos) × marca (hasta `2^15−1` en Eficiencia) × grupo/tipo. En la práctica casi ninguna combinación de filtros se repite exactamente, por lo que el caché de 1 hora rara vez se reutiliza fuera de la carga inicial con filtros por defecto.
4. **Fusión de datasets en JavaScript en vez de JOIN SQL** en `inventario/_actions/get-inventario-data.ts`: 3 pares de queries paralelas (marcas, dispersión, rotación por sucursal) traen 2 recordsets cada una y las cruzan con `Map` en Node (líneas 235-262, 417-443, 531-549) en vez de un solo `JOIN`/`FULL OUTER JOIN` en SQL Server.
5. **`@tanstack/react-table` está declarado en `package.json` pero tiene 0 imports en `src/`.** Todas las 5 tablas grandes del portal (`detalle-cristales-table.tsx`, `detalle-marca-table.tsx`, `detalle-table.tsx`, `clientes-deudores-table.tsx`, `usuarios-client.tsx`) son implementaciones manuales, sin virtualización (`@tanstack/react-virtual` tampoco está instalado), y 4 de las 5 recalculan `.filter()`/`.reduce()` en **cada render/keystroke sin `useMemo`**.
6. **4 rutas cargan sin ningún `<Suspense>`** (`sucursales`, `usuarios`, `usuarios/[id]`, `perfil`) — el TTFB completo de esas páginas espera a que terminen todas sus queries SQL. Además `usuarios/loading.tsx` y `perfil/loading.tsx` **no existen**, así que Next no muestra ningún skeleton de ruta mientras tanto.
7. **Duplicación de Server Actions dentro de la misma carga de página:** `/dashboard/eficiencia` invoca `getTipoLente` dos veces (`TipoLenteChartWrapper` y `DetalleCristalesTableWrapper`) y `/dashboard/inventario` invoca `getMarcasDetalleData` dos veces (`RankingMarcasChartWrapper` y `DetalleTableWrapper`) — mismos parámetros, mismo resultado, dos invocaciones.
8. **`/api/revalidate` siempre purga las 5 categorías completas (29 tags)** sin invalidación selectiva por módulo, y el token de autorización viaja en query string sin verificación de origen (`route.ts:48-75`). Cualquier trigger externo (presumiblemente el ETL) fuerza recalcular el caché de módulos que no cambiaron.

**Build medido:** `next build --webpack` → **31.6 s** totales (8.9 s compilación + 5.9 s typecheck + resto en generación de páginas estáticas/trazado). `.next/static` = **4.98 MB** (2.17 MB JS + 2.68 MB fuentes + resto). Salida `standalone` = **52.48 MB**. No hay `@next/bundle-analyzer` configurado (no se instaló uno temporal para mantener el alcance de solo lectura del análisis).

---

## 2. Inventario de Server Actions

| Módulo | Archivo | # Queries SQL | ¿Paralelas? | ¿Cacheada (`unstable_cache`)? |
|---|---|---|---|---|
| dashboard | `_actions/get-mis-sucursales.ts` | 1 | N/A | Sí, 3600s |
| cartera | `_actions/get-cartera-data.ts` (5 acciones) | 8 (4+1+1+1+1) | Sí (KPIs) | Sí, 3600s c/u |
| clinico | `_actions/get-clinica-data.ts` (6 acciones) | 7 (2+1×5) | Sí (KPIs) | Sí, 3600s (60s "hoy") |
| inventario | `_actions/get-inventario-data.ts` (5 acciones) | 12 (3+2+1+2+2) | Sí (pares) | Sí, 3600s |
| inventario | `_actions/get-inventario-filters.ts` | 1 | N/A | Sí, 3600s |
| resumen-comercial | `_actions/get-resumen-data.ts` (4 acciones) | 10 (7+1+1+1) | Sí (KPIs) | Sí, 3600s |
| eficiencia | `_actions/get-eficiencia-data.ts` (7 acciones) | 8 (2+1×6) | Sí (KPIs) | Sí, 3600s (60s "hoy") |
| perfil | `_actions/change-password.ts` | 3-4 (mutación) | No (dependencia real) | No (correcto) |
| sucursales | `_actions/get-usuarios.ts` | 1 | N/A | **No** |
| usuarios | `_actions/get-usuarios.ts` | 1 | N/A | **No** |
| usuarios | `_actions/get-roles.ts` | 1 | N/A | **No** |
| usuarios | `_actions/get-sucursales.ts` | 1 | N/A | **No** |
| usuarios | `_actions/get-datos-edicion.ts` | 2 | **No** (independientes) | **No** |
| usuarios | `_actions/get-usuario-detalle.ts` | 3 | **No** (independientes) | **No** |
| usuarios | `_actions/asignar-sucursal.ts` | 3 (mutación) | No | No |
| usuarios | `_actions/cambiar-rol.ts` | 6 (mutación) | No | No |
| usuarios | `_actions/crear-usuario.ts` | 4-5 + N (mutación) | No | No |
| usuarios | `_actions/editar-usuario.ts` | 4-7 + hasta 2×N (mutación) | No | No |
| usuarios | `_actions/revocar-sucursal.ts` | 2 (mutación) | No | No |
| usuarios | `_actions/toggle-estado-usuario.ts` | 3 (mutación) | No | No |

**Nota de consistencia:** los 5 módulos de reporte (cartera/clínico/inventario/resumen-comercial/eficiencia) cachean agresivamente todo, incluidas las lecturas simples. El módulo `usuarios`/`sucursales` **no cachea ninguna lectura** — puede ser intencional (datos administrativos que deben verse frescos), pero no hay ninguna nota en el código que indique que es una decisión deliberada vs. un olvido (ver Preguntas Abiertas).

---

## 3. Hallazgos detallados por área

### A. Data fetching del servidor

**A1 — N+1 de escritura en `usuarios/_actions/editar-usuario.ts:171-203`** (Alto impacto / Medio esfuerzo)
```ts
for (const id_sucursal of ids_sucursales) {
  const existente = await pool.request()...query("SELECT 1 ...");
  if (existente.recordset.length > 0) { await pool.request()...query("UPDATE...") }
  else { await pool.request()...query("INSERT...") }
}
```
Hasta 2×N round-trips secuenciales solo para reasignar sucursales. Resoluble con `MERGE ... USING (VALUES ...)` vía table-valued parameter en una sola query. El mismo archivo también repite el patrón SELECT-then-UPSERT para la gestión de rol (líneas 114-159, hasta 3 queries).

**A2 — N+1 de inserción en `usuarios/_actions/crear-usuario.ts:106-115`** (Alto impacto en altas con muchas sucursales / Medio esfuerzo)
```ts
for (const id_sucursal of sucursalesAAsignar) {
  await pool.request().input(...).query(`INSERT INTO dbo.Seguridad_Usuarios_Sucursales...`);
}
```
Un `INSERT` por sucursal en vez de un `INSERT` multi-fila. Para un rol MASTER con todas las sucursales puede ser docenas de round-trips secuenciales.

**A3 — Fusión de datasets en JS en vez de JOIN, `inventario/_actions/get-inventario-data.ts`** (Medio impacto / Medio esfuerzo)
- `fetchMarcasDetalle` (líneas 200-264): 2 queries paralelas (inventario por marca, ventas por marca) cruzadas con `Map` (líneas 235-262).
- `fetchDispersionData` (líneas 384-445): mismo patrón por segmento comercial (líneas 417-443).
- `fetchRotacionSucursal` (líneas 500-549): mismo patrón por sucursal (líneas 531-549), y además corta a Top 20 **en JS** (`.sort().slice(0,20)`, línea 549) en vez de `ORDER BY ... OFFSET/FETCH` en SQL.

Los 3 casos comparten el mismo filtro entre ambas queries de cada par — serían un solo `LEFT/FULL OUTER JOIN` en SQL.

**A4 — Auth-context repetido por acción dentro del mismo archivo** (Bajo-Medio impacto / Bajo esfuerzo)
En `cartera` (5×), `clinico` (6×), `resumen-comercial` (4×) y `eficiencia` (7×), cada función exportada del mismo archivo vuelve a llamar `getAuthContext()` + `getUserAllowedSucursales()` de forma independiente. Está cacheado (`security.ts:47`, `unstable_cache` 7200s) así que no genera N queries reales tras el primer hit, pero en un cache-miss simultáneo (primera carga de un dashboard con 4-7 widgets) puede disparar la misma query de permisos varias veces en paralelo sin *request coalescing* entre acciones distintas.

**A5 — Queries de solo lectura independientes sin `Promise.all`** (Bajo-Medio impacto / Bajo esfuerzo)
- `usuarios/_actions/get-datos-edicion.ts:19-37` — 2 queries independientes (rol activo, sucursales vigentes), ambas solo dependen de `idUsuario`.
- `usuarios/_actions/get-usuario-detalle.ts:48-111` — 3 queries independientes (usuario+rol, sucursales, auditoría `TOP 20`).
- `usuarios/_actions/cambiar-rol.ts:49-52` y `:90-94` — consultan la **misma fila** de `Seguridad_Roles` dos veces con columnas distintas; deberían fusionarse en un único `SELECT nombre_rol, nivel_jerarquico`.
- `usuarios/_actions/toggle-estado-usuario.ts:23-37` — el `SELECT` de estado anterior y el `UPDATE` son independientes entre sí.
- `usuarios/_actions/revocar-sucursal.ts:23-50` — `UPDATE` + `INSERT` de auditoría, independientes.

**A6 — Falta de paginación SQL en `usuarios/_actions/get-usuarios.ts:22-37`** (Alto impacto si la tabla crece / Bajo esfuerzo)
`SELECT` sin `TOP`/`OFFSET-FETCH` — trae toda la tabla `Seguridad_Usuarios` en cada carga de la tabla de usuarios. El mismo patrón (agregado completo sin límite) aparece en las queries detrás de `detalle-marca-table.tsx`, `detalle-cristales-table.tsx`, `detalle-table.tsx` y `clientes-deudores-table.tsx` (ver Área D).

**A7 — Infraestructura de conexión (`src/lib/db.ts`)** — sin hallazgos negativos. Singleton correcto vía `globalThis.sqlPool`, reconecta si se desconecta, pool `max:25/min:0`, sin fugas evidentes (todas las acciones usan el pool compartido sin cerrarlo manualmente, que es lo correcto en este patrón).

**A8 — Patrones bien optimizados (referencia positiva, no requieren cambio):** `getCarteraKPIs` (4 queries paralelas), `getClinicaKPIs`, `getInventarioKPIs` (3 paralelas), `getResumenKPIs` (**7 queries en paralelo**, líneas 96-206), `getEficienciaKPIs` — todos usan `Promise.all` correctamente para sus subconsultas de KPI. `change-password.ts` usa `pool.transaction()` correctamente para el UPDATE+auditoría atómico.

---

### B. Renderizado y streaming

**B1 — 4 rutas sin ningún `<Suspense>`** (Medio impacto / Bajo-Medio esfuerzo)
`sucursales/page.tsx`, `usuarios/page.tsx`, `usuarios/[id]/page.tsx`, `perfil/page.tsx` esperan **todas** sus queries antes de retornar JSX. Los 5 módulos de reporte sí usan un patrón híbrido correcto: la fila de KPIs bloquea (`await getXxxKPIs(...)` antes del `return`), pero el resto de gráficos/tablas se envuelve cada uno en su propio `<Suspense>` con un `*-chart-wrapper.tsx` como hijo async, permitiendo streaming parcial.

**B2 — `loading.tsx` ausente en `usuarios/` (raíz) y `perfil/`** (Medio impacto / Bajo esfuerzo)
Next.js no tiene ningún skeleton de ruta que mostrar mientras `usuarios/page.tsx` resuelve su `Promise.all` de 3 acciones o mientras `perfil/page.tsx` resuelve 3 queries SQL secuenciales inline. El resto de módulos sí tiene `loading.tsx` completo (`cartera`, `clinico`, `eficiencia`, `inventario`, `resumen-comercial`, `sucursales`).

**B3 — `cartera/loading.tsx` marcado `"use client"` sin necesidad** (Bajo impacto / Bajo esfuerzo)
Es un skeleton JSX 100% estático (4 filas replicando el layout), sin `useState`/`useEffect`/eventos — el resto de los `loading.tsx` de otros módulos son Server Components. Convertirlo elimina JS de cliente innecesario.

**B4 — `perfil/page.tsx:27-79`: 3 round-trips SQL secuenciales, 2 paralelizables** (Bajo-Medio impacto / Bajo esfuerzo)
La query de sucursales (línea 54) y la de auditoría (línea 69) solo dependen de `user.id_usuario` (ya resuelto tras la query 1), no entre sí — podrían lanzarse con `Promise.all` inmediatamente después de resolver `user`.

**B5 — Client Components sin interactividad real** (Bajo-Medio impacto / Medio esfuerzo)
- `resumen-comercial/_components/kpi-card.tsx:1` — `"use client"` sin ningún hook; usado en **6 de los 7 módulos de reporte**. Incluye un `ICON_MAP` de 22 iconos de `lucide-react` (líneas 38-62) que viaja al bundle de cliente en cada una de esas rutas.
- `dashboard/_components/dual-kpi-card.tsx:1` — mismo patrón; el propio comentario del archivo indica que se marcó cliente solo por la limitación de serializar `iconName` como string desde el Server Component, no por necesidad real de interactividad.

**B6 — `dashboard/page.tsx` (raíz) es un stub vacío** (Informativo)
`return;` sin JSX ni datos (líneas 1-3) — todo el trabajo real de la ruta `/dashboard/*` ocurre en `dashboard/layout.tsx`. No es un problema de performance, pero conviene confirmarlo como intencional.

---

### C. Estrategia de caché

**C1 — Clave de caché de alta cardinalidad en Eficiencia/Inventario** (Alto impacto / Alto esfuerzo)
La clave real de cada `unstable_cache` es el tag fijo + los argumentos serializados (`startDate, endDate, sucursales, allowedSucursales, [marca], [grupo], [tipoLente]`) — documentado en comentarios del propio código (`clinico/_actions/get-clinica-data.ts:104-112`). Dimensiones de filtro:
- **Fecha**: rango libre día-a-día (`date-range-picker.tsx`), sin presets — combinaciones prácticamente ilimitadas.
- **Sucursal**: multi-select, hasta `2^N−1` subconjuntos (evidencia indirecta de N alto: varios gráficos truncan a "Top 10 + Ver más").
- **Marca** (inventario/eficiencia): hasta `2^15−1` en Eficiencia (15 marcas activas confirmadas en código, vs. 563 del catálogo completo).
- **Grupo/Tipo de lente**: dimensiones adicionales multi-select.

Resultado: fuera de la carga inicial con filtros por defecto (mes actual, todas las sucursales del usuario), casi cualquier ajuste de filtro genera una entrada de caché nueva y fría — el TTL de 1h aporta poco valor real de reutilización en esos dos módulos.

**C2 — `/api/revalidate/route.ts:65-75` purga siempre las 5 categorías completas** (Medio impacto / Bajo esfuerzo)
```ts
const categories = ["ventas", "inventario", "clinico", "recaudo", "eficiencia"];
// revalidateTag(tag) para los 29 tags de las 5 categorías, sin selección
```
No hay endpoint para invalidar un solo módulo. Cualquier trigger (presumiblemente del ETL externo — no se encontró ningún llamador dentro del repo) fuerza recalcular caché de módulos cuyos datos no cambiaron. El token de autorización viaja en query string (`?secret=...`) sin verificación adicional de origen.

**C3 — TTL de 1h uniforme sin relación confirmable con la cadencia real del ETL** (Bajo impacto / N/A — depende de infraestructura fuera de alcance)
No hay ningún cron/scheduler visible en el código del portal; la única pista de frescura es `Maestro_Sucursales.fecha_carga_etl`. El diseño (1h para casi todo, salvo dos endpoints "hoy" a 60s) sugiere un TTL genérico no atado a la cadencia real — no se puede confirmar sin contexto del pipeline ETL (fuera de alcance).

**C4 — Módulo `usuarios`/`sucursales` sin ninguna capa de caché** (Bajo impacto / Informativo)
A diferencia de los 5 módulos de reporte, ninguna acción de `usuarios/_actions/` ni `sucursales/_actions/get-usuarios.ts` usa `unstable_cache` — cada lectura golpea Azure SQL directamente. Puede ser intencional (frescura administrativa) pero conviene confirmarlo (ver Preguntas Abiertas).

**C5 — Catálogos casi-estáticos ya cacheados correctamente** (Referencia positiva)
`marcas-grupos-inventory` y `sucursales-list` (3600s), `user-permissions` (7200s) — bien dimensionados para datos de baja volatilidad.

---

### D. Cliente: tablas y datasets grandes

**D1 — Sin librería de virtualización ni uso de `@tanstack/react-table`** (Informativo, ver E1 para el hallazgo de dependencia)
Las 5 tablas grandes (`detalle-cristales-table.tsx`, `detalle-marca-table.tsx`, `detalle-table.tsx`, `clientes-deudores-table.tsx`, `usuarios-client.tsx`) son implementaciones manuales sobre `<table>` HTML con `useState` + `.filter()`/`.slice()` propios. La paginación es solo de UI (slice de 10 en 10), así que el DOM real no crece de forma descontrolada por sí solo, pero el **filtrado sí opera siempre sobre el array completo ya descargado del servidor**.

**D2 — Filtrado y agregación sin `useMemo` en 4 de 5 tablas** (Medio impacto / Bajo esfuerzo — quick win)
- `detalle-cristales-table.tsx:40-54` — `sort()` + `filter()` + `reduce()` de totales, todo recalculado en **cada render**, incluyendo cada pulsación de tecla en el buscador.
- `detalle-marca-table.tsx:40-54` — mismo patrón.
- `detalle-table.tsx:33-40` (inventario) — filtra directo sobre la prop `data` (ni siquiera hay `sortedData` intermedio) + 3 `reduce()` separados sin memoizar.
- `clientes-deudores-table.tsx:43-55` — filtro con doble `.includes()` por fila + `reduce()` de 3 totales sin memoizar; `pctPagado` se recalcula por fila en cada render dentro del `.map()`.
- **`usuarios-client.tsx:65-74` es la única que sí usa `useMemo`** para el filtrado — buena práctica relativa.

**D3 — `usuarios-client.tsx` sin paginación y con recarga completa de página** (Medio impacto / Bajo esfuerzo)
Línea 146: `filtered.map(...)` renderiza **todas** las filas filtradas sin límite. Línea 97-100: `handleSaved` ejecuta `window.location.reload()` tras guardar/editar un usuario — recarga completa del documento en vez de revalidar solo los datos de la tabla.

**D4 — Server Actions detrás de las tablas devuelven el dataset agregado completo sin `TOP`/`OFFSET FETCH`** (cruza con A6/A3)
`getDetalleOrdenesPorMarca` (eficiencia, líneas 505-518), `fetchMarcasDetalle` (inventario, línea 270), `fetchClientesDeudores` (cartera, líneas 325-339) y `getUsuarios` (línea 22-37) — ninguno limita filas en SQL; la paginación se resuelve enteramente en el cliente sobre el array completo.

---

### E. Bundle de cliente y build

**E1 — `@tanstack/react-table` declarado sin uso real** (Bajo impacto / Bajo esfuerzo)
0 imports en `src/` confirmados por búsqueda exhaustiva. Es peso muerto en `node_modules` y en el árbol de dependencias resoluble (aunque al no importarse, no debería estar apareciendo en el bundle de cliente — el problema es solo de higiene de dependencias, no de bundle real). Eliminarlo de `package.json` es una limpieza directa.

**E2 — Medición de build real**
- `next build --webpack`: **31.6 s** (8.9 s compilación + 5.9 s TypeScript + ~16.8 s generación de páginas estáticas/trazado con 11 workers).
- `.next/static` total: **4.98 MB**, de los cuales:
  - JS (`chunks/**/*.js`): **2.17 MB**.
  - Fuentes (`static/media/*.woff2`): **2.68 MB** en 96 archivos (ver E3).
- `.next/standalone` (artefacto de despliegue Docker/Azure): **52.48 MB**.
- No hay `@next/bundle-analyzer` configurado en `next.config.ts` ni como devDependency — no se instaló uno temporal para respetar el alcance de solo lectura. En su lugar se inspeccionaron los chunks generados directamente.

**E3 — 17 familias tipográficas cargadas incondicionalmente (detallado en resumen ejecutivo #1)** (Medio impacto / Bajo-Medio esfuerzo)
`src/lib/fonts/registry.ts:1-108` declara 17 `next/font/google` + 1 `geist/font/pixel`; `fontVars` (línea 187-189) concatena las 17 `variable` classes y `layout.tsx:40` las aplica todas al `<body>` global. Verificado en `.next/server/app/login.html`: **no hay `<link rel="preload">` de fuentes** (solo 2 preloads totales, ninguno de tipografía), por lo que `next/font` no está forzando la descarga de las 17 en cada carga — el costo real es de tamaño de build/imagen de despliegue y de CSS `@font-face` adicional, no necesariamente de red en cada visita. Aun así, mantener 17 familias completas para una preferencia estética que el usuario fija una sola vez es desproporcionado.

**E4 — Chunks JS más pesados** (Informativo, vía inspección de `.next/static/chunks` + `build-manifest.json`)
| Chunk | Tamaño | Contenido probable | ¿Global (rootMainFiles)? |
|---|---|---|---|
| `4416-*.js` | 369 KB | Recharts (confirmado por marcadores `ResponsiveContainer`/`CartesianGrid`/`Treemap`) | No — solo se carga en rutas de dashboard con gráficos |
| `3794-*.js` | 216 KB | Parte del bundle raíz (providers globales: sonner, tooltip, next-auth session, zustand) | **Sí** — en `rootMainFiles`, se carga en toda la app |
| `4bd1b696-*.js` | 195 KB | Runtime compartido | **Sí** — en `rootMainFiles` |
| `framework-*.js` | 185 KB | React/React-DOM runtime | Sí (raíz Next.js estándar) |
| `main-*.js` / `polyfills-*.js` | 128 KB / 110 KB | Bootstrap Next.js + polyfills de compatibilidad de navegador | Sí |
| Radix UI | Repartido en 7 chunks distintos | Componentes de UI (diálogos, dropdowns, tooltips) | Distribuido, no concentrado |

`recharts` (369 KB) **no** está en `rootMainFiles`, así que no se carga en rutas sin gráficos (`usuarios`, `sucursales`, `perfil`) — buen comportamiento de code-splitting por defecto de Next.js App Router, sin necesidad de `next/dynamic` manual adicional.

**E5 — Verificación de tree-shaking en librerías de iconos (referencia positiva)**
`lucide-react` (44 usos) y `simple-icons` (1 uso real, `siX` en `sidebar-support-card.tsx:3`) se importan con named imports. Se confirmó por grep directo sobre los chunks compilados que **ningún otro icono de `simple-icons`** (ej. `siGoogle`, `siGithub`) terminó en el bundle — el tree-shaking funciona correctamente pese a que `simple-icons` pesa 15 MB en disco (`node_modules`). No es un hallazgo, se documenta para descartar la sospecha inicial.

**E6 — `next.config.ts` sin configuración que perjudique performance** (Referencia positiva)
`output: "standalone"`, `outputFileTracingRoot` explícito, `typescript.ignoreBuildErrors: false`, headers de seguridad razonables, y exclusión correcta de `etl/`, `sql/`, `powerbi/` del watcher de webpack para evitar escaneo innecesario en monorepo. Sin hallazgos negativos.

---

### F. Red y waterfalls

**F1 — Reconstrucción de waterfall por página principal**

| Página | Orden de Server Actions |
|---|---|
| `/dashboard` (raíz) | `layout.tsx`: `Promise.all([getPreference, getPreference, getMisSucursales])` — 3 en paralelo. `page.tsx` no hace fetch (vacío). |
| `/dashboard/resumen-comercial` | layout → `getResumenKPIs` (bloqueante) → streaming paralelo: `getTopSucursales`, `getMediosPago`, `getVentasDiarias`. |
| `/dashboard/cartera` | layout → `getCarteraKPIs` (bloqueante) → streaming paralelo: `getGapCobroData`, `getMixVentasData`, `getCarteraSucursalData`, `getClientesDeudoresTabla`. |
| `/dashboard/clinico` | layout → `getClinicaKPIs` (ya paralela internamente) → streaming paralelo: 5 Server Actions independientes. |
| `/dashboard/eficiencia` | layout → `getEficienciaKPIs` → streaming: 5 wrappers, **uno duplicado** (`getTipoLente` se invoca 2 veces, ver resumen ejecutivo #7). |
| `/dashboard/inventario` | layout → `getInventarioKPIs` → streaming: 5 wrappers, **uno duplicado** (`getMarcasDetalleData` se invoca 2 veces). |
| `/dashboard/sucursales` | Sin Suspense: `getSucursales()` (SQL inline, no cacheado) bloquea todo el TTFB; `getUsuariosBySucursal` se dispara client-side al abrir un modal. |
| `/dashboard/usuarios` | Sin Suspense: `Promise.all([getUsuarios, getRoles, getSucursalesParaSelector])` bloquea toda la página (correcto que esté en paralelo, pero sin streaming). |

**F2 — Imágenes** (Referencia positiva)
0 usos de `<img>` HTML crudo en `src/`. Los 2 usos de imagen (`app-sidebar.tsx`, `login/page.tsx`) ya usan `next/image` correctamente, con `priority` en el logo del login.

**F3 — Fuentes** (cruza con E3) — `next/font/google` en todos los casos, sin `<link>`/`@import` externo bloqueante. Único hallazgo es el volumen (17 familias), no la técnica de carga.

---

### G. Estado y re-renders

**G1 — Store de Zustand bien diseñado** (Referencia positiva)
`src/stores/preferences/preferences-store.ts` — store plano de 8 campos de UI. Todos los consumidores usan selectores granulares por campo (`usePreferencesStore(s => s.campo)`) o `useShallow` cuando necesitan varios campos a la vez (`app-sidebar.tsx:63-69`). No se encontró ningún consumo del store completo sin selector. Sin hallazgos.

**G2 — `ChartContext` sin memoizar el valor del provider** (Bajo impacto / Bajo esfuerzo)
`src/components/ui/chart.tsx:30,63` — `<ChartContext.Provider value={{ config }}>` crea un objeto nuevo en cada render de `ChartContainer` (sin `useMemo`), forzando re-render de `ChartTooltipContent`/`ChartLegendContent` en cada render del padre aunque `config` no haya cambiado de contenido. Contrasta con `SidebarContext` (`sidebar.tsx:115-126`), que sí memoiza correctamente su valor.

**G3 — Cascada `useEffect` → Server Action en filtros del navbar** (Medio impacto / Medio esfuerzo)
`src/app/(main)/dashboard/_components/navbar/report-filters.tsx:46-77` — 3 `useEffect` separados disparan Server Actions **después** del mount inicial: `getMarcasGrupos` (solo en `/inventario`), `getTipoLenteOpciones` y `getMarcaOpciones` (solo en `/eficiencia`, esta última re-dispara en cascada cada vez que cambia el filtro de tipo de lente). El usuario ve el navbar/filtros vacíos primero y las opciones "aparecer" tras un round-trip cliente→servidor adicional, en vez de venir precargadas desde el Server Component padre de la página.

**G4 — `useEffect` en `sucursales-client.tsx:49-55`** (Bajo impacto)
Dispara `getUsuariosBySucursal` al abrir el modal de una sucursal — es una carga bajo demanda por interacción del usuario, no una cascada en el mount inicial, así que es un patrón aceptable.

---

### H. Autenticación y middleware

**H1 — Middleware sin trabajo pesado** (Referencia positiva)
`src/middleware.ts` es exactamente el middleware default JWT de `next-auth` (`export default middleware` de `next-auth/middleware`), `matcher: ["/dashboard/:path*"]`. No instancia conexión a base de datos ni hace cómputo adicional — la validación de sesión es puramente JWT (firma/expiración), sin round-trip a Azure SQL en cada navegación protegida. Es el único `middleware.ts` del proyecto.

**H2 — `authOptions` con 2 queries + posible bcrypt en cada login** (Bajo impacto, solo ocurre en login, no en navegación)
`src/app/api/auth/[...nextauth]/route.ts` — `authorize()` hace 1 query (usuario+rol) + `bcrypt.compare` (líneas 24-47); el evento `signIn` hace 2 queries adicionales secuenciales (UPDATE última sesión + INSERT auditoría, líneas 96-126) que **no dependen entre sí** más allá de compartir `user.id` — candidato menor a `Promise.all`, pero al ocurrir solo una vez por sesión (8h de duración, `maxAge` línea 70) el impacto es marginal.

**H3 — Advertencia de build: `middleware` deprecado, existe `src/proxy.ts.bak` abandonado** (Informativo / Bajo esfuerzo)
El build de Next.js 16.2.4 emite: `⚠ The "middleware" file convention is deprecated. Please use "proxy" instead.` Se encontró `src/proxy.ts.bak` en el repo, evidencia de un intento previo de migración que quedó desactivado (extensión `.bak`). No es una regresión de performance hoy, pero es deuda técnica que eventualmente requiere resolución antes de que Next retire la convención `middleware.ts`.

---

## 4. Tabla de priorización final

| # | Hallazgo | Área | Impacto | Esfuerzo | Archivo(s) clave |
|---|---|---|---|---|---|
| 1 | N+1 doble en `editar-usuario.ts` (hasta 2×N round-trips) | A | Alto | Medio | `usuarios/_actions/editar-usuario.ts:171-203` |
| 2 | N+1 de inserción en `crear-usuario.ts` | A | Alto | Medio | `usuarios/_actions/crear-usuario.ts:106-115` |
| 3 | Falta de paginación SQL en `get-usuarios.ts` | A/D | Alto (si crece la tabla) | Bajo | `usuarios/_actions/get-usuarios.ts:22-37` |
| 4 | Cardinalidad de caché sin techo (Eficiencia/Inventario) | C | Alto | Alto | `eficiencia/_actions/*`, `inventario/_actions/*` |
| 5 | 4 rutas sin `<Suspense>` (usuarios, usuarios/[id], sucursales, perfil) | B | Medio | Bajo-Medio | `usuarios/page.tsx`, `sucursales/page.tsx`, `perfil/page.tsx` |
| 6 | Fusión JS en vez de JOIN (3 pares de queries en inventario) | A | Medio | Medio | `inventario/_actions/get-inventario-data.ts` |
| 7 | 17 familias tipográficas cargadas incondicionalmente | E/F | Medio | Bajo-Medio | `src/lib/fonts/registry.ts`, `src/app/layout.tsx:40` |
| 8 | 4 tablas sin `useMemo` en filtro/agregación | D | Medio | Bajo | `detalle-*-table.tsx`, `clientes-deudores-table.tsx` |
| 9 | `usuarios-client.tsx` sin paginación + `window.location.reload()` | D | Medio | Bajo | `usuarios/_components/usuarios-client.tsx:97-100,146` |
| 10 | `/api/revalidate` purga las 5 categorías siempre | C | Medio | Bajo | `src/app/api/revalidate/route.ts:65-75` |
| 11 | `loading.tsx` ausente en `usuarios/` y `perfil/` | B | Medio | Bajo | `usuarios/`, `perfil/` |
| 12 | Duplicación de Server Actions en misma página (eficiencia, inventario) | F | Bajo-Medio | Bajo | `*-wrapper.tsx` de eficiencia/inventario |
| 13 | Queries independientes sin `Promise.all` (get-datos-edicion, get-usuario-detalle, perfil/page.tsx) | A/B | Bajo-Medio | Bajo | Ver A5, B4 |
| 14 | `kpi-card.tsx` / `dual-kpi-card.tsx` cliente sin necesidad | B | Bajo-Medio | Medio | `resumen-comercial/_components/kpi-card.tsx`, `dashboard/_components/dual-kpi-card.tsx` |
| 15 | Query duplicada literal en `cambiar-rol.ts` | A | Bajo | Bajo | `usuarios/_actions/cambiar-rol.ts:49-52,90-94` |
| 16 | Auth-context repetido por acción en mismo archivo | A | Bajo | Bajo | cartera/clínico/resumen-comercial/eficiencia `_actions/*` |
| 17 | `@tanstack/react-table` declarado sin uso | E | Bajo | Bajo | `package.json` |
| 18 | `ChartContext` sin memoizar valor del provider | G | Bajo | Bajo | `src/components/ui/chart.tsx:63` |
| 19 | `cartera/loading.tsx` `"use client"` innecesario | B | Bajo | Bajo | `cartera/loading.tsx:1` |
| 20 | Cascada `useEffect` en filtros de navbar (inventario/eficiencia) | G | Bajo-Medio | Medio | `_components/navbar/report-filters.tsx:46-77` |
| 21 | Migración pendiente `middleware.ts` → `proxy.ts` | H | Bajo | Bajo | `src/middleware.ts`, `src/proxy.ts.bak` |

---

## 5. Preguntas abiertas

1. **¿Cuál es la cadencia real del CRON/ETL que dispara `/api/revalidate`?** No se encontró ningún llamador de ese endpoint dentro del repo del portal (confirma que es externo). Sin esa cadencia real no se puede determinar si el `revalidate: 3600` de respaldo es demasiado agresivo (recalcula contra SQL Server hasta 24x/día sin necesidad) o insuficiente.
2. **¿Es intencional que `usuarios`/`sucursales` no tengan ninguna capa de `unstable_cache`**, a diferencia de los 5 módulos de reporte? Si la razón es "los admins necesitan ver datos frescos siempre", está bien documentarlo explícitamente en el código; si fue un olvido, conviene decidir una política uniforme.
3. **Volumen real de filas en producción** — no se puede correr la app contra datos reales desde este análisis. Los hallazgos de "falta de paginación SQL" (get-usuarios, tablas de detalle) son estructuralmente correctos, pero su impacto real depende de si `Seguridad_Usuarios`, `Fact_Ventas_Detalle` agrupado por marca, o clientes con saldo pendiente son decenas o miles de filas — recomendable instrumentar y medir con datos productivos antes de priorizar el esfuerzo de paginación server-side.
4. **¿Hay telemetría/APM en producción (Application Insights, etc.)?** No se encontró instrumentación de performance runtime en el código (`src/`) — todo este análisis es estático. Si existe telemetría de Azure fuera del repo, cruzarla con estos hallazgos permitiría confirmar cuáles de las 21 filas de la tabla de priorización generan latencia real percibida vs. cuáles son correctas en teoría pero de bajo tráfico en la práctica.
5. **Bundle real por dependencia** — sin instalar `@next/bundle-analyzer` (fuera del alcance de solo lectura de este análisis) no se puede dar una tabla exacta de contribución por paquete al bundle de cliente; el análisis de E4/E5 se basa en inspección de chunks compilados + búsqueda de marcadores de string, que es indicativo pero no tan preciso como un treemap de bundle-analyzer.
