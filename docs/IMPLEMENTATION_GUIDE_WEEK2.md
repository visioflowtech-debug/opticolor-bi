# Guía de Implementación — UX Quick Wins (Semana 2.1)
**21 de Abril 2026 | Autor: UX/UI Expert Agent**

---

## OBJETIVO SEMANAL
Implementar 6 mejoras de alto impacto (alto ROI, bajo riesgo, sin datos reales):
- ✅ Active state en navegación visible
- ✅ Colores Opticolor en botones
- ✅ Loading states (skeleton screens)
- ✅ Tablas responsive mobile
- ✅ Dark mode WCAG AA compliant
- ✅ Hover/focus states

**Tiempo estimado:** 4-6 horas  
**Riesgo:** Bajo  
**Dependencies:** Ninguno  

---

## PARTE A: SETUP & TESTING INFRASTRUCTURE

### Paso 1: Crear feature branch
```bash
git checkout main
git pull origin main
git checkout -b feat/ux-improvements-q1
```

### Paso 2: Entorno local
```bash
cd c:/opticolor-bi/portal
npm install  # Si no está actualizado
npm run build  # Verificar que compila
```

### Paso 3: Testing setup checklist
Antes de cualquier cambio:
- [ ] Abrir DevTools (F12)
- [ ] Ir a Lighthouse tab
- [ ] Ir a Accessibility tab (contrast checker)
- [ ] Ir a Device toolbar (mobile testing)

### Paso 4: Vercel preview
Cada commit auto-deploya en:
```
https://opticolor-bi.vercel.app (main)
```
Habrá preview URL en PR también.

---

## PARTE B: MEJORA #1 — ACTIVE STATE EN NAVEGACIÓN (30-45 min)

### Ubicación
`portal/src/app/(main)/dashboard/_components/sidebar/nav-main.tsx`

### Análisis actual (línea ~164)
```tsx
{group.items.map((item) => {
  // ... lógica actual
  return <NavItemExpanded key={item.title} item={item} isActive={isItemActive} />;
})}
```

El problema: `isActive` status es invocado pero el styling es muy sutil.

### Cambio propuesto
En `NavItemExpanded` component (línea ~45):

**ANTES:**
```tsx
<SidebarMenuButton
  disabled={item.comingSoon}
  isActive={isActive(item.url, item.subItems)}
  tooltip={item.title}
>
  {item.icon && <item.icon />}
  <span>{item.title}</span>
  {item.comingSoon && <IsComingSoon />}
  <ChevronRight ... />
</SidebarMenuButton>
```

**DESPUÉS:**
```tsx
{isActive(item.url, item.subItems) ? (
  <SidebarMenuButton
    disabled={item.comingSoon}
    isActive={true}
    tooltip={item.title}
    className="bg-primary text-primary-foreground font-medium"
  >
    {item.icon && <item.icon />}
    <span>{item.title}</span>
    {item.comingSoon && <IsComingSoon />}
    <Badge variant="default" className="ml-auto size-5 flex items-center justify-center rounded-full text-xs">
      ✓
    </Badge>
    <ChevronRight className="ml-0" />
  </SidebarMenuButton>
) : (
  <SidebarMenuButton
    disabled={item.comingSoon}
    isActive={false}
    tooltip={item.title}
  >
    {item.icon && <item.icon />}
    <span>{item.title}</span>
    {item.comingSoon && <IsComingSoon />}
    <ChevronRight ... />
  </SidebarMenuButton>
)}
```

### Testing
- [ ] Desktop: Navegar a cada página, verificar color + badge en active item
- [ ] Mobile: Badge visible sin overflow
- [ ] Dark mode: Color contraste adecuado
- [ ] Keyboard: Tab a items y verificar visual feedback

### Commit message
```
feat(ui): mejorar active state en navegación sidebar

- NavMain items ahora muestran bg color + badge checkmark cuando activos
- Mejora clarity sobre página actual
- Testeo: light/dark mode, desktop/mobile
```

---

## PARTE C: MEJORA #2 — COLORES OPTICOLOR EN BOTONES (45 min)

### Ubicación
Múltiples ubicaciones. Estrategia: usar CSS variables ya existentes.

### Análisis actual
Botones usan `variant="primary"` y `variant="outline"` que mapean a CSS variables.

**Archivos a revisar:**
- `portal/src/components/ui/button.tsx` — Definiciones de variantes
- `portal/src/styles/presets/opticolor.css` — Ya tiene colores correctos

### Verificación (no cambiar, solo confirmar)
En `opticolor.css`:
```css
--primary: #0038E3;           /* Azul Opticolor ✓ */
--primary-foreground: #FFFFFF;
--secondary: #DC143C;         /* Rojo Opticolor ✓ */
--secondary-foreground: #FFFFFF;
```

### Lo que cambiar: Aplicar en componentes
En `dashboard/default/_components/performance-overview.tsx` (línea ~268):
```tsx
// ANTES:
<Button variant="outline" size="sm">
  View report
</Button>

// DESPUÉS:
<Button variant="default" size="sm" className="bg-primary hover:bg-primary/90">
  View report
</Button>
```

En `subscriber-overview.tsx` (línea ~22):
```tsx
// ANTES:
<Button variant="outline" size="sm">
  <Download />
  Export
</Button>

// DESPUÉS:
<Button className="bg-primary text-white hover:bg-primary/90" size="sm">
  <Download />
  Export
</Button>
```

### Links y accents
En `app/globals.css`, agregar para links:
```css
a {
  @apply text-primary hover:underline focus-visible:ring-2 focus-visible:ring-offset-2;
}
```

### Testing
- [ ] Botones primary: azul #0038E3 (light) o #378ADD (dark)
- [ ] Botones secondary (si existen): rojo #DC143C (light) o #E74C3C (dark)
- [ ] Hover state: Color más oscuro o con opacity 0.9
- [ ] Focus state: Ring visible alrededor
- [ ] Links: Underline en hover, ring en focus

### Commit message
```
feat(ui): aplicar colores Opticolor a botones y links

- Primary buttons: #0038E3 light, #378ADD dark
- Secondary buttons: #DC143C light, #E74C3C dark
- Links: underline on hover, ring on focus
- Consistent across all pages
```

---

## PARTE D: MEJORA #3 — SKELETON SCREENS (1.5-2 horas)

### Ubicación
Componentes principales:
1. `dashboard/default/_components/metric-cards.tsx`
2. `dashboard/default/_components/performance-overview.tsx`
3. `dashboard/default/_components/subscriber-overview.tsx`

### Análisis actual
Los gráficos/cards cargan con datos hardcodeados, pero en producción habrá API delay.

### Estrategia
Simulamos loading state (aunque ahora sea instantáneo) para mostrar UX cuando datos tarden.

### Paso 1: Crear componente Skeleton wrapper (Opcional)
Ya existe `@/components/ui/skeleton` en Shadcn.

### Paso 2: Modificar metric-cards.tsx
```tsx
"use client";

import { useEffect, useState } from "react";
import { DollarSign, TrendingDown, TrendingUp, UserPlus, Users, Waves } from "lucide-react";
import { Badge } from "@/components/ui/badge";
import { Card, CardContent, CardDescription, CardHeader, CardTitle } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";

export function MetricCards() {
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    // Simular API delay de 500ms
    const timer = setTimeout(() => setIsLoading(false), 500);
    return () => clearTimeout(timer);
  }, []);

  const SkeletonCard = () => (
    <Card>
      <CardHeader>
        <CardTitle>
          <Skeleton className="h-7 w-7 rounded-lg" />
        </CardTitle>
        <CardDescription>
          <Skeleton className="h-4 w-24" />
        </CardDescription>
      </CardHeader>
      <CardContent className="space-y-2">
        <Skeleton className="h-8 w-32" />
        <Skeleton className="h-3 w-40" />
      </CardContent>
    </Card>
  );

  if (isLoading) {
    return (
      <div className="grid grid-cols-1 gap-4 xl:grid-cols-4">
        {[...Array(4)].map((_, i) => <SkeletonCard key={i} />)}
      </div>
    );
  }

  // ... resto del componente actual
}
```

### Paso 3: Modificar performance-overview.tsx
```tsx
"use client";

import { useState, useEffect } from "react";
import { Skeleton } from "@/components/ui/skeleton";

export function PerformanceOverview() {
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const timer = setTimeout(() => setIsLoading(false), 500);
    return () => clearTimeout(timer);
  }, []);

  if (isLoading) {
    return (
      <Card className="@container/card">
        <CardHeader>
          <Skeleton className="h-6 w-32" />
          <Skeleton className="h-4 w-full mt-2" />
        </CardHeader>
        <CardContent>
          <Skeleton className="h-80 w-full rounded-lg" />
        </CardContent>
      </Card>
    );
  }

  // ... resto del componente
}
```

### Paso 4: Modificar subscriber-overview.tsx
```tsx
"use client";

import { useState, useEffect } from "react";
import { Skeleton } from "@/components/ui/skeleton";

export function SubscriberOverview() {
  const [isLoading, setIsLoading] = useState(true);

  useEffect(() => {
    const timer = setTimeout(() => setIsLoading(false), 500);
    return () => clearTimeout(timer);
  }, []);

  if (isLoading) {
    return (
      <Card>
        <CardHeader>
          <Skeleton className="h-6 w-40" />
          <Skeleton className="h-4 w-full mt-2" />
        </CardHeader>
        <CardContent>
          <div className="space-y-2">
            {[...Array(5)].map((_, i) => (
              <Skeleton key={i} className="h-10 w-full" />
            ))}
          </div>
        </CardContent>
      </Card>
    );
  }

  // ... resto
}
```

### Testing
- [ ] Página dashboardPrincipal: Skeltons aparecen 500ms
- [ ] Después: Datos se renderizan sin parpadeo
- [ ] Mobile: Skeletons responsive (no overflow)
- [ ] Dark mode: Skeleton color legible

### Commit message
```
feat(ui): agregar skeleton loading states a componentes principales

- MetricCards: skeleton cards mientras cargan
- PerformanceOverview: skeleton chart
- SubscriberOverview: skeleton table rows

Simula API latency (500ms) incluso con data hardcoded.
Mejora perceived performance.
```

---

## PARTE E: MEJORA #4 — TABLAS RESPONSIVE (45-60 min)

### Ubicación
`portal/src/app/(main)/dashboard/default/_components/recent-customers-table/table.tsx`

### Análisis actual (línea ~1-50)
```tsx
<div className="border rounded-lg">
  <Table>
    <TableHeader>...</TableHeader>
    <TableBody>...</TableBody>
  </Table>
</div>
```

El problema: En móviles (375px), tabla se corta.

### Cambio propuesto
Envolver table en scroll container:

**ANTES:**
```tsx
<div className="border rounded-lg">
  <Table>{/* Contenido */}</Table>
</div>
```

**DESPUÉS:**
```tsx
<div className="border rounded-lg overflow-hidden">
  <div className="overflow-x-auto">
    <Table className="w-full text-sm">
      {/* Contenido */}
    </Table>
  </div>
</div>
```

### Alternativa: Usar media queries para columnas
Si quieres ocultar columnas en mobile:
```tsx
<TableCell className="hidden md:table-cell">
  {/* Columna que se oculta en mobile */}
</TableCell>
```

### Testing
- [ ] Desktop (1920px): Tabla normal, sin scroll
- [ ] Tablet (768px): Tabla completa, sin scroll
- [ ] Mobile (375px): Tabla scrolleable horizontalmente
- [ ] Touch: Scroll smooth, no sticky fingers
- [ ] Accessibility: Tabla sigue siendo navegable con keyboard

### Commit message
```
feat(ui): hacer tablas responsive con scroll horizontal en mobile

- Envolver table en overflow-x-auto
- Mantener full width en desktop/tablet
- Scroll horizontal en mobile (<768px)
```

---

## PARTE F: MEJORA #5 — DARK MODE WCAG AA (1-1.5 horas)

### Ubicación
`portal/src/styles/presets/opticolor.css` (sección dark mode, línea 49+)

### Herramientas de testing
1. DevTools → Elements → Color picker (contrast ratio)
2. https://webaim.org/resources/contrastchecker/
3. Chrome Lighthouse → Accessibility tab

### Análisis actual (dark mode, línea 56)
```css
.dark:root[data-theme-preset="opticolor"] {
  --primary: #378ADD;       /* Azul claro para dark ✓ 5.2:1 */
  --secondary: #E74C3C;     /* Rojo ajustado ✓ 4.8:1 */
  --border: #3A3A3A;        /* Gris oscuro ✓ */
  --foreground: #FFFFFF;    /* Blanco ✓ */
}
```

### Problemas típicos (si los hay)
1. Links < 4.5:1 contrast
2. Form labels poco visibles
3. Muted text demasiado tenue

### Testing & fixes
```bash
# Abrir DevTools (F12)
# → Activar dark mode (tema toggle en portal)
# → Elements tab → color picker en cada elemento
# → Verificar ratio (debe ser >= 4.5:1 para normal text)
```

**Checklist:**
- [ ] Links: >= 4.5:1 contrast
- [ ] Botones: >= 4.5:1 contrast
- [ ] Text normal: >= 4.5:1 contrast
- [ ] Small text (12px): >= 7:1 contrast
- [ ] Badges: >= 4.5:1 contrast
- [ ] Form inputs: Border >= 3:1 contrast

### Cambios si es necesario
Si algun elemento falla, ajustar en `opticolor.css`:
```css
/* EJEMPLO: Si link text falla */
.dark a {
  color: #60A5FA; /* Más claro que #378ADD */
}
```

### Commit message
```
fix(ui): asegurar WCAG AA contrast en dark mode

Auditados todos los elementos en dark theme:
- Links: 4.5:1+ ✓
- Botones: 4.5:1+ ✓
- Text: 4.5:1+ ✓
- Badges: 4.5:1+ ✓

Testeado con DevTools color picker + WebAIM checker.
```

---

## PARTE G: MEJORA #6 — HOVER/FOCUS STATES (45 min)

### Ubicación
1. `portal/src/components/ui/sidebar.tsx` (sidebar items)
2. `portal/src/components/ui/button.tsx` (buttons)
3. `portal/src/app/globals.css` (global links)

### Cambios propuestos

#### Sidebar menu buttons
En `sidebar.tsx`, buscar `SidebarMenuButton` y agregar:
```tsx
className="transition-colors hover:bg-accent hover:text-accent-foreground focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-primary"
```

#### Buttons
En `button.tsx`, en cada variante:
```tsx
// Base
className={cn(
  "... existing classes ...",
  "focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-primary",
  "transition-colors duration-200"
)}
```

#### Links en globals.css
```css
a {
  @apply text-primary hover:underline;
  @apply focus-visible:outline-none focus-visible:ring-2 focus-visible:ring-offset-2 focus-visible:ring-primary;
  @apply transition-colors;
}
```

### Testing
- [ ] Hover: Cambio de color visible (no solo subtle)
- [ ] Focus: Ring de 2px alrededor del elemento
- [ ] Keyboard Tab: Focus ring visible en todos los elementos
- [ ] Contrast: Ring visible en light y dark mode
- [ ] Mobile: Hover states no interfieren con touch

### Commit message
```
feat(ui): agregar hover/focus states a elementos interactivos

- Sidebar items: hover bg + focus ring
- Buttons: focus ring + transition colors
- Links: underline on hover + focus ring
- Mejora accesibilidad keyboard navigation
```

---

## PARTE H: COMPILAR & TESTING FINAL

### Paso 1: Build local
```bash
cd portal
npm run build
```
Debe completar sin errores. Si hay errores, revisar logs.

### Paso 2: Testing visual en Vercel
Después de último commit:
```bash
git push origin feat/ux-improvements-q1
```

Esperar 2-3 min. Vercel crea preview URL (aparece en GitHub Actions).

### Paso 3: Checklist completo
```
LIGHT MODE:
- [ ] Desktop (1920px): Active state visible, colores correctos
- [ ] Tablet (768px): Responsive OK, gráficos visibles
- [ ] Mobile (375px): Tablas scrollean, botones clickeables
- [ ] Skeltons: Aparecen brevemente (~500ms)

DARK MODE:
- [ ] Colores legibles (contrast 4.5:1+)
- [ ] Active state visible
- [ ] Links underlined en hover
- [ ] Focus rings visibles

KEYBOARD NAVIGATION:
- [ ] Tab through sidebar → todos los items focusables
- [ ] Tab through buttons → focus ring visible
- [ ] Enter/Space activan botones/links
- [ ] Escape cierra dropdowns (si existe)

ACCESSIBILITY:
- [ ] Lighthouse Accessibility > 85
- [ ] NVDA/JAWS: Labels leídos correctamente
- [ ] Color blind: UI funciona sin confusión por color
```

### Paso 4: Performance
```
Lighthouse scores (DevTools → Lighthouse):
- Performance: > 85
- Accessibility: > 85
- Best Practices: > 80
- SEO: > 80
```

---

## PARTE I: MERGE & CLEANUP

### Paso 1: Crear Pull Request
En GitHub: Create PR `feat/ux-improvements-q1` → `main`

### Paso 2: Descripción PR
```markdown
## UX Improvements — Quick Wins (Semana 2.1)

Implementadas 6 mejoras de alto impacto, sin datos reales:

### Cambios
1. **Active state NavMain** — Visible color + badge
2. **Colores Opticolor** — Botones primary/secondary
3. **Skeleton screens** — Loading states en gráficos
4. **Tablas responsive** — Scroll horizontal mobile
5. **Dark mode WCAG AA** — Contrast audit + fixes
6. **Hover/focus states** — Better accessibility

### Testing
- [x] Desktop + mobile visual
- [x] Light + dark mode
- [x] Keyboard navigation
- [x] Lighthouse > 85
- [x] Vercel preview OK

### Archivos cambiados
- nav-main.tsx
- performance-overview.tsx
- metric-cards.tsx
- subscriber-overview.tsx
- button.tsx
- opticolor.css
- globals.css
```

### Paso 3: Review & Merge
1. Self-review (leer cambios propios)
2. Request review (si hay otro dev)
3. Esperar aprobación
4. Merge a main

### Paso 4: Cleanup
```bash
git checkout main
git pull origin main
git branch -d feat/ux-improvements-q1  # Eliminar rama local
```

---

## PARTE J: DOCUMENTACIÓN POST-IMPLEMENTACIÓN

### Actualizar memory
En `.claude/agents/ux-ui-portal.md`:
```markdown
### Cambios recientes (21 Abril):
- ✅ Active state NavMain mejorado
- ✅ Colores Opticolor en botones aplicados
- ✅ Skeleton screens implementados
- ✅ Tablas responsive mobile
- ✅ Dark mode WCAG AA compliant
- ✅ Hover/focus states implementados
```

### Actualizar ux-ui-portal.md
```markdown
## Mejoras UX/UI Completadas

| Fecha | Cambio | Status |
|-------|--------|--------|
| 21 Abril | 6 quick wins (navegación, colores, loading, responsive, a11y) | ✅ |
```

---

## TROUBLESHOOTING

### ❌ Build falla después de cambios
```bash
npm run build  # Ver error
npm run type-check  # Verificar tipos
# Probable: Import faltante o typo en className
```

### ❌ Skeleton screens aparecen todo el tiempo
**Problema:** `useEffect` no se ejecuta en SSR  
**Solución:** Usar `'use client'` al principio del archivo

### ❌ Colores no cambian en Vercel
**Problema:** Cache de Vercel  
**Solución:** Forzar redeploy en Vercel dashboard

### ❌ Dark mode contrast sigue fallando
**Solución:** Verificar cascada CSS en DevTools  
```bash
# En DevTools Elements:
# Right-click elemento → Inspect
# Verificar qué CSS le aplica color
```

### ❌ Tablas no scrollean en mobile
**Problema:** Padre tiene `overflow: hidden`  
**Solución:** Agregar wrapper con `overflow-x-auto`

---

## PRÓXIMOS PASOS (Después de Merge)

### Semana 2.2 (Viernes)
- Testing intensivo en devices reales (iPhone, Android, tablets)
- Feedback de stakeholders
- Iteraciones según feedback

### Semana 2.3 (Próxima)
- Mejora #7: Empty states (requiere datos)
- Mejora #8: Error handling (requiere API testing)
- Polish #9-10 (animaciones, documentation)

---

**¡Listo!** Esta guía te cubre A-Z para implementar Quick Wins.  
**Tiempo total esperado:** 4-6 horas  
**Riesgo:** Bajo  
**Reward:** Alto impacto visual + mejor UX

Si tienes dudas, referencia a `OPTICOLOR_UX_ROADMAP_NEXT_STEPS.md` (versión completa).
