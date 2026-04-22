# UX/UI Roadmap — Opticolor BI Portal
**Fecha:** 21 Abril 2026  
**Versión:** 1.0  
**Estado:** Diagnosticado — Listo para implementación

---

## PARTE A: Estado Actual Diagnosticado

### 1. Arquitectura del Portal
- **Framework:** Next.js 16.2.4 (App Router) con Shadcn/UI
- **Theme System:** CSS Variables (oklch) + Presets (opticolor.css, brutalist, soft-pop, tangerine)
- **Componentes disponibles:** 50+ de Shadcn/UI (Button, Card, Table, Sidebar, Breadcrumb, etc.)
- **Estructura:** Layout + Dashboard + 5 Informes + Auth pages

### 2. Estado Responsive (Diagnóstico Actual)
- **Desktop:** Sidebar colapsable (expandido 68px col, colapsado icon-only) ✅
- **Tablet (768px):** Responsive classes usando Tailwind `md:` y `lg:` breakpoints ✅
- **Mobile (375px):** 
  - Sidebar aparentemente responsive pero NO TESTADO en dispositivos reales
  - Tables, gráficos, y layouts no optimizados para pantallas pequeñas ⚠️
  - Header navbar con muchos elementos (5+) puede causar overflow ⚠️

**Recomendación:** Crear breakpoint strategy claro para mobile-first

### 3. Mock Data vs Datos Reales
- **Dashboards actuales:** 5 informes (Resumen Comercial, Eficiencia Órdenes, Control Cartera, Desempeño Clínico, Inventario)
- **Estado:** Placeholder "Informe en construcción — Semana 2.2" ⚠️
- **Homepage:** Tiene componentes mockeados (MetricCards, PerformanceOverview, SubscriberOverview) ✅
- **API routes:** Existen pero devuelven mock data estática
- **Impacto UX:** Datos reales de Azure SQL llegarán en Semana 2.2 — estructura visual está lista

### 4. Estructura de Navegación (Actual)
- **Sidebar:** NavMain (7 items primarios, algunos con subItems)
  - Grupo 1: "Informes Opticolor" (5 informes activos)
  - Grupo 2: "Administración" (3 items, algunos coming-soon)
- **Navbar:** SidebarTrigger + SearchDialog + LayoutControls + ThemeSwitcher + AccountSwitcher
- **Breadcrumbs:** Componente Shadcn/UI EXISTE pero NO está implementado en páginas
- **Active state:** Usa URL matching (Next.js router) en NavMain ✅

**Problema:** SIN BREADCRUMBS en páginas = navegación confusa en mobile

### 5. Colores Actuales (Opticolor Preset ✅)
- **Primario:** #0038E3 (Azul royal)
- **Secundario:** #DC143C (Rojo crimson)
- **Accent:** #0F3E68 (Azul oscuro)
- **Fondo:** #F5F5F5 (Blanco muy claro)
- **Dark mode:** Colores adaptados para readibilidad
- **Status:** YA IMPLEMENTADO en `/src/styles/presets/opticolor.css` ✅

**Nota:** Paleta Opticolor oficial YA está configurada — no bloqueado

### 6. Sidebar Minimizado (PAIN POINT ACTUAL)
```
EXPANDIDO:
┌──────────────────────┐
│ [LOGO] OPTICOLOR     │  ← Logo sm 60px + texto
├──────────────────────┤
│ Resumen Comercial    │
│ Eficiencia Órdenes   │
│ ...                  │
└──────────────────────┘

MINIMIZADO (Actual):
┌──┐
│[I]│  ← Favicon.ico 24x24px (PROBLEMA: se corta, no es lo ideal)
├──┤
│  │
└──┘
```

**Problema diagnosticado:**
- Favicon en minimizado se ve pequeño y poco profesional
- No hay contexto visual (qué es ese icono?)
- Tooltips ausentes al pasar sobre el ícono

---

## PARTE B: Mejoras Propuestas (Orden Prioritario)

### PRIORITY 1: Sidebar Minimizado (QUICK FIX — 5-10 min)

**Problema:** Minimizado no es visualmente satisfactorio

**Opciones evaluadas:**

#### Opción A: Dejar espacio en blanco (RECOMENDADA)
```tsx
// Cambiar SidebarLogoContent para que en minimizado NO muestre favicon
export function SidebarLogoContent() {
  const { state } = useSidebar();
  const isCollapsed = state === "collapsed";

  return (
    <SidebarMenu>
      <SidebarMenuItem>
        <SidebarMenuButton asChild>
          <Link href="/dashboard/default" className="flex items-center gap-2">
            {!isCollapsed && <Logo size="sm" />}
            {!isCollapsed && <span className="font-semibold text-sm">OPTICOLOR</span>}
            {/* isCollapsed: espacio vacío, limpio */}
          </Link>
        </SidebarMenuButton>
      </SidebarMenuItem>
    </SidebarMenu>
  );
}
```

**Ventajas:**
- Minimalista y moderno
- Espacio visual claro para separar navbar del contenido
- Consistent con diseño de apps profesionales (Vercel, GitHub, Notion)

**Desventajas:**
- Menos branding visible

#### Opción B: Línea horizontal como separador
```tsx
{isCollapsed && <Separator orientation="horizontal" className="my-2" />}
```

**Ventajas:** Visual cue que el sidebar existe

**Desventajas:** Menos limpio, menos profesional

#### Opción C: Logo vertical "O P T I" (NO RECOMENDADO)
Poco legible, confuso, no recomendado.

---

### PRIORITY 2: Breadcrumbs + Navegación (30-45 min)

**Problema:** Usuario no sabe dónde está en la app (especialmente mobile)

**Propuesta:**
```
Dashboard / Resumen Comercial / Detalles Mensuales

vs.

Dashboard > Eficiencia Órdenes > Análisis por Orden #123
```

**Implementación sugerida:**

1. **Crear componente `<BreadcrumbNav />`** en `_components/breadcrumb-nav.tsx`:
```tsx
"use client";

import { usePathname } from "next/navigation";
import {
  Breadcrumb,
  BreadcrumbItem,
  BreadcrumbLink,
  BreadcrumbList,
  BreadcrumbSeparator,
} from "@/components/ui/breadcrumb";

interface BreadcrumbPath {
  label: string;
  href?: string;
}

const breadcrumbMap: Record<string, BreadcrumbPath[]> = {
  "/dashboard/default": [{ label: "Dashboard" }],
  "/dashboard/resumen-comercial": [
    { label: "Dashboard", href: "/dashboard/default" },
    { label: "Resumen Comercial" },
  ],
  "/dashboard/eficiencia-ordenes": [
    { label: "Dashboard", href: "/dashboard/default" },
    { label: "Eficiencia de Órdenes" },
  ],
  // ... más rutas
};

export function BreadcrumbNav() {
  const pathname = usePathname();
  const paths = breadcrumbMap[pathname] || [];

  if (paths.length === 0) return null;

  return (
    <Breadcrumb>
      <BreadcrumbList>
        {paths.map((path, idx) => (
          <div key={idx} className="flex items-center gap-2">
            <BreadcrumbItem>
              {path.href ? (
                <BreadcrumbLink href={path.href}>{path.label}</BreadcrumbLink>
              ) : (
                <span className="text-foreground font-medium">{path.label}</span>
              )}
            </BreadcrumbItem>
            {idx < paths.length - 1 && <BreadcrumbSeparator />}
          </div>
        ))}
      </BreadcrumbList>
    </Breadcrumb>
  );
}
```

2. **Integrar en dashboard layout.tsx:**
```tsx
<header className={cn(...)}>
  <div className="flex w-full flex-col gap-2 px-4 lg:px-6">
    <div className="flex items-center justify-between">
      {/* Logo + Sidebar trigger */}
    </div>
    <BreadcrumbNav /> {/* AGREGAR AQUÍ */}
  </div>
</header>
```

3. **Mobile optimization:**
   - Breadcrumbs colapsables en mobile (mostrar solo últimos 2-3 items)
   - Usar `truncate` para labels largos
   - Separador debe ser visible pero pequeño

---

### PRIORITY 3: Responsive Mobile Testing (1-2 horas)

**Problema:** No testado en dispositivos reales (375px-430px)

**Puntos a evaluar:**

#### 3.1 Header Navbar Overflow
Actualmente tiene: Logo + SidebarTrigger + SearchDialog + LayoutControls + ThemeSwitcher + AccountSwitcher

**En 375px:** Probablemente overflow horizontal

**Propuesta:**
```tsx
// Opción A: Hamburger menu en mobile (ocultar algunos elementos)
<header className={cn(
  "flex h-12 shrink-0 items-center gap-2 border-b",
  // En mobile: mostrar solo lo esencial
  "md:gap-4"  // Más espacio en tablet+
)}>
  {/* Solo SidebarTrigger + SearchDialog */}
  <div className="md:hidden flex items-center gap-1">
    <SidebarTrigger />
    <SearchDialog />
  </div>
  
  {/* Desktop: mostrar todo */}
  <div className="hidden md:flex items-center gap-2">
    {/* Full header */}
  </div>
</header>
```

#### 3.2 Tables en Mobile
Si hay DataTable con muchas columnas → no scrolleable horizontalmente

**Propuesta:**
- Agregar `overflow-x-auto` si no existe
- Cards stacked layout alternativo para mobile
- Ejemplo: en vez de tabla con 5 cols, mostrar 5 cards en grid

#### 3.3 Gráficos Recharts
Gráficos típicamente responsivos, pero verificar:
- ResponsiveContainer width/height
- Tooltip legible en pantalla pequeña
- Leyenda no overflow

---

### PRIORITY 4: Colores Opticolor (COMPLETADO ✅)

**Status:** YA IMPLEMENTADO

`/src/styles/presets/opticolor.css` contiene:
- Primario: #0038E3 (azul)
- Secundario: #DC143C (rojo)
- Accent: #0F3E68
- Dark mode: adaptaciones correctas

**Uso actual:**
- `data-theme-preset="opticolor"` activa automáticamente
- Todos los componentes Shadcn/UI heredan variables CSS

**No bloqueado** ✅

---

## PARTE C: Plan de Implementación (Sugerido)

### Fase 1: Sidebar Minimizado (WEEK 1 - 10 min)
1. Modificar `sidebar-logo-content.tsx`
2. Opción A: Dejar espacio vacío cuando collapsed
3. Test en browser desktop + mobile (screenshot)
4. Commit: `fix: clean sidebar minimized state`

### Fase 2: Breadcrumbs (WEEK 1 - 30-45 min)
1. Crear `BreadcrumbNav` componente
2. Agregar ruta mappings en breadcrumbMap
3. Integrar en `dashboard/layout.tsx`
4. Test responsive (mobile collapse breadcrumbs si necesario)
5. Commit: `feat: add breadcrumb navigation to dashboard`

### Fase 3: Mobile Responsive Testing (WEEK 1-2 - 1-2 horas)
1. Usar DevTools mobile emulation (375px viewport)
2. Inspeccionar cada dashboard en mobile
3. Crear GitHub issue si encuentra problemas
4. Documentar en `MOBILE_TESTING_REPORT.md`

### Fase 4: Visual Polish (WEEK 2+ - iterativo)
1. Refinar transiciones sidebar
2. Ajustar spacing en mobile
3. Validar dark mode en todas las páginas
4. Deploy en Vercel + visual regression testing

---

## PARTE D: Checklist Visual Testing (Antes de cada commit)

### Desktop (1920px)
- [ ] Logo + OPTICOLOR texto visible en sidebar expandido
- [ ] Sidebar collapse animation smooth
- [ ] Breadcrumbs aparecen debajo navbar
- [ ] Todos los botones clickeables
- [ ] Hover states visibles (color change)

### Tablet (768px)
- [ ] Sidebar responsive (puede collapse)
- [ ] Header no overflows
- [ ] Breadcrumbs wrap si es necesario
- [ ] Tables scrolleable horizontalmente si needed

### Mobile (375px)
- [ ] SidebarTrigger accesible (no hidden)
- [ ] Header elementos no overflow
- [ ] Breadcrumbs colapsados O solo "Dashboard / Actual"
- [ ] Taps (touch targets) mín. 44x44px
- [ ] Text legible sin zoom

### Dark Mode (All viewports)
- [ ] Colores legibles (contrast ratio >= 4.5:1)
- [ ] Breadcrumbs distinguibles
- [ ] Sidebar background claro vs foreground

### Keyboard Navigation
- [ ] Tab through navbar items (SidebarTrigger, Search, Account)
- [ ] Breadcrumb links tabbable
- [ ] Focus outline visible

---

## PARTE E: Recomendaciones Adicionales

### 1. Naming & Organization
- Mantener estructura actual: `_components/sidebar/`, `_components/breadcrumb-nav.tsx`
- Documentar en JSDoc si agrega componentes nuevos
- Seguir convención Shadcn/UI (componentes en `/src/components/ui/`)

### 2. CSS & Tailwind
- NO agregar custom CSS global
- Usar clases Tailwind existentes
- Si necesita breakpoint nuevo, verificar `tailwind.config.ts`
- Validar oklch colors (CSS Variables) antes de aplicar

### 3. Performance
- Breadcrumbs: usePathname() es lightweight ✅
- Logo component: Already optimized (Next.js Image)
- Sidebar transitions: Hardware-accelerated ✅

### 4. Accesibilidad
- Breadcrumbs: `aria-label="breadcrumb"` ya en componente Shadcn ✅
- Links: Asegurar href correcto (prevenir 404)
- Mobile: Touch targets >= 44x44px

### 5. Git Workflow
Commits sugeridos:
1. `fix: clean sidebar minimized state`
2. `feat: add breadcrumb navigation`
3. `test: verify responsive mobile (375px)`
4. `style: polish sidebar transitions`

---

## Datos Pendientes que Afectan UX

(Desde CLAUDE.md — bloqueadores Semana 2)

| # | Dato | Impacto UX | Status |
|---|------|-----------|--------|
| 1 | Logo Opticolor PNG | Alto — branding | ⏳ Esperando |
| 2 | Paleta colores | Medio — ya tiene preset | ✅ NO bloqueado |
| 3 | Usuarios operacionales | Alto — RLS/Permisos | ⏳ Esperando |
| 4 | Datos reales Azure SQL | CRÍTICO — dashboards | ⏳ Semana 2.2 |

---

## Conclusión

**Estado actual:** Portal es funcional, estructura es sólida, Shadcn/UI components listos

**Críticos inmediatos:**
1. ✅ Colores Opticolor: YA HECHO (preset opticolor.css)
2. ⏳ Breadcrumbs: RÁPIDO, propone mejora de UX
3. ⏳ Mobile responsive: NO es bloqueador pero recomendado testear
4. ⏳ Sidebar minimizado: MINOR FIX, mejora visual

**Blockers verdaderos:** Datos reales de Azure SQL (Semana 2.2)

**Próxima sesión:** Implementar Fase 1 + 2 (breadcrumbs + sidebar fix) en <1 hora

---

**Documento preparado por:** UX/UI Expert  
**Siguiente revisión:** Post-implementación breadcrumbs  
**Responsable escalation:** VisioFlow Tech (@visioflowtech-debug)
