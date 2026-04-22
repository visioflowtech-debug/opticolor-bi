# 🎯 Redesign: Botón Toggle Sidebar en Header

**Fecha:** 21 Abril 2026  
**Expert:** UX/UI Portal  
**Estado:** Propuesta de Diseño + Guía de Implementación  

---

## PARTE A: ANÁLISIS VISUAL & DECISIONES UX

### 1. Estado Actual (Problema)

**Ubicación:** Navbar (header) — Lado izquierdo  
**Componente:** `<SidebarTrigger>` importado de Shadcn/UI  
**Inconveniente:**
- Toggle está lejos del sidebar (lado opuesto)
- En mobile, ocupa espacio valioso en navbar
- No es evidente dónde está el control (usuario busca en sidebar)
- Navbar se siente "abarrotada" (trigger + separator + search + theme + account)

**Archivos afectados:**
- `layout.tsx` línea 54: `<SidebarTrigger className="-ml-1" />`
- `layout.tsx` línea 55-58: Separador innecesario

---

### 2. Diseño Propuesto (Solución)

```
SIDEBAR EXPANDIDO (272px):
┌──────────────────────────────┐
│ [📍] OPTICOLOR        [◀︎]   │ ← Logo + Texto + Toggle (chevron-left)
├──────────────────────────────┤
│ 🏠 Dashboard                 │
│ 📊 Reportes                  │
│ ⚙️ Configuración             │
└──────────────────────────────┘

SIDEBAR MINIMIZADO (48px):
┌────┐
│ [📍]│ ← Favicon + Auto-show toggle on hover
├────┤
│ 🏠 │
│ 📊 │
│ ⚙️ │
└────┘
(El toggle aparece en hover/focus)
```

**Beneficios:**
✅ Toggle visible donde está la action (sidebar header)  
✅ Navbar más limpia (sin trigger + separator)  
✅ Coherencia espacial (collapse/expand = lado del nombre)  
✅ Mobile: gana espacio en navbar  
✅ Intuitivo: usuario ve icon + ve dónde reduce  

---

### 3. Iconografía Recomendada

| Estado | Ícono | Nombre Lucide | Código | Razón |
|--------|-------|---------------|--------|-------|
| **Expandido** | `◀︎` | `ChevronLeft` | `<ChevronLeft size={16} />` | Estándar UI (collapsa hacia la izquierda) |
| **Minimizado** | `▶︎` | `ChevronRight` | `<ChevronRight size={16} />` | Espeja el anterior (expande hacia la derecha) |

**Alternativas descartadas:**
- ❌ `Minimize2` + `Maximize2`: Demasiado literal, visual congestionada
- ❌ `X`: Confunde con "cerrar" (parece destruir sidebar)
- ❌ `Menu`: Ya existe en mobile, redundante

**Razón de Chevrons:**
- Lucide React usa chevrons para navegación/colapso (consistencia)
- Tamaño 16px mantiene proporción con logo (24px)
- Fácil reconocimiento en hover/focus
- Funciona bien en light + dark mode

---

### 4. Posicionamiento en Sidebar Header

**Estructura propuesta:**

```tsx
<SidebarLogoContent>
  ┌───────────────────────────────────────┐
  │ [Logo] [OPTICOLOR text]        [Toggle]│
  └───────────────────────────────────────┘
  
  ┌───────────────────────────────────────┐
  │ [Logo]                         [Toggle]│
  └───────────────────────────────────────┘
  (minimizado)
```

**Especificaciones:**
- **Position:** Derecha del contenedor (`ml-auto`)
- **Hit Area:** Mínimo 44x44px (WCAG AA — mobile touch target)
- **Padding:** 8px alrededor del ícono (16x16px → 32x32px hit area)
- **Tooltip:** "Minimizar" / "Expandir" (título + descripción en ARIA)

---

### 5. Tooltip & Accesibilidad

**Tooltip (Shadcn/UI `<Tooltip>`):**

```
Expandido: "Minimizar sidebar" (Ctrl+B)
Minimizado: "Expandir sidebar" (Ctrl+B)
```

**ARIA:**
```tsx
<button
  onClick={toggleSidebar}
  aria-label="Minimizar sidebar"
  title="Minimizar (Ctrl+B)"
  className="..."
>
  <ChevronLeft size={16} />
</button>
```

---

## PARTE B: CAMBIOS TÉCNICOS PROPUESTOS

### 1. Remover de Navbar

**Archivo:** `c:\opticolor-bi\portal\src\app\(main)\dashboard\layout.tsx`

**Cambios:**
```diff
- import { SidebarTrigger } from "@/components/ui/sidebar";
- import { Separator } from "@/components/ui/separator";

  // En la línea 52-60, remover:
  <div className="flex items-center gap-1 lg:gap-2">
-   <SidebarTrigger className="-ml-1" />
-   <Separator orientation="vertical" ... />
    <SearchDialog />
  </div>
```

**Resultado:**
```tsx
<div className="flex items-center gap-1 lg:gap-2">
  <SearchDialog />
</div>
```

---

### 2. Agregar a Sidebar Header

**Archivo:** `c:\opticolor-bi\portal\src\app\(main)\dashboard\_components\sidebar\sidebar-logo-content.tsx`

**Imports nuevos:**
```tsx
"use client";

import Link from "next/link";
import Image from "next/image";
import { ChevronLeft, ChevronRight } from "lucide-react";

import { Logo } from "@/components/Logo";
import {
  useSidebar,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar";
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { Button } from "@/components/ui/button";
```

**Componente propuesto:**
```tsx
export function SidebarLogoContent() {
  const { state, toggleSidebar } = useSidebar();
  const isCollapsed = state === "collapsed";

  const toggleLabel = isCollapsed ? "Expandir sidebar" : "Minimizar sidebar";
  const toggleHint = isCollapsed ? "Expandir (Ctrl+B)" : "Minimizar (Ctrl+B)";
  const ChevronIcon = isCollapsed ? ChevronRight : ChevronLeft;

  return (
    <SidebarMenu>
      <SidebarMenuItem>
        <div className="flex items-center justify-between w-full px-2 py-1.5 group/logo">
          {/* Logo + Text / Favicon */}
          <SidebarMenuButton asChild className="flex-1">
            <Link prefetch={false} href="/dashboard/default">
              {!isCollapsed && (
                <>
                  <Logo size="sm" />
                  <span className="font-semibold text-sm">OPTICOLOR</span>
                </>
              )}
              {isCollapsed && (
                <Image
                  src="/favicon.ico"
                  alt="Opticolor"
                  width={24}
                  height={24}
                />
              )}
            </Link>
          </SidebarMenuButton>

          {/* Toggle Button with Tooltip */}
          <Tooltip>
            <TooltipTrigger asChild>
              <Button
                variant="ghost"
                size="sm"
                onClick={toggleSidebar}
                className="h-8 w-8 p-0 shrink-0 hover:bg-accent"
                aria-label={toggleLabel}
                title={toggleHint}
              >
                <ChevronIcon size={16} className="text-muted-foreground" />
              </Button>
            </TooltipTrigger>
            <TooltipContent side="right" align="center">
              <p className="text-xs">{toggleLabel}</p>
              <p className="text-xs text-muted-foreground">Ctrl+B</p>
            </TooltipContent>
          </Tooltip>
        </div>
      </SidebarMenuItem>
    </SidebarMenu>
  );
}
```

---

### 3. Integración con TooltipProvider

**Nota importante:** Shadcn/UI `<Tooltip>` requiere `<TooltipProvider>` en el árbol.

**Verificación requerida en:** `c:\opticolor-bi\portal\src\app\layout.tsx` (root layout)

Debe contener:
```tsx
import { TooltipProvider } from "@/components/ui/tooltip";

export default function RootLayout({ children }) {
  return (
    <TooltipProvider>
      {children}
    </TooltipProvider>
  );
}
```

Si no está, agregarlo (una sola vez en raíz).

---

## PARTE C: GUÍA DE IMPLEMENTACIÓN PASO A PASO

### Paso 1: Verificar raíz de TooltipProvider

```bash
# Revisar que layout.tsx root tenga TooltipProvider
grep -n "TooltipProvider" src/app/layout.tsx
```

Si no existe, agregarlo.

---

### Paso 2: Actualizar sidebar-logo-content.tsx

1. Reemplazar imports (agregar Lucide icons + Tooltip + Button)
2. Extraer `toggleSidebar` del hook `useSidebar()`
3. Refactorizar estructura JSX:
   - Contenedor flex con `justify-between`
   - Link con Logo/Favicon (flex-1)
   - Button con toggle + Tooltip (shrink-0)

**Detalle de estilos:**
- `group/logo` en contenedor padre para estados hover
- `h-8 w-8 p-0` en botón (hit area 32x32px)
- `hover:bg-accent` para feedback visual
- `text-muted-foreground` para icon (coherencia con navbar)

---

### Paso 3: Limpiar navbar en layout.tsx

1. **Remover imports:**
   - `import { SidebarTrigger } from "@/components/ui/sidebar"`
   - `import { Separator } from "@/components/ui/separator"` (si solo se usaba aquí)

2. **Remover JSX:**
   - `<SidebarTrigger className="-ml-1" />`
   - `<Separator orientation="vertical" ... />`

3. **Verificar que SearchDialog aún funciona** (no depende de Separator)

---

### Paso 4: Testing

```bash
# Build local
npm run build

# Type check
npm run type-check

# Visual test en Vercel (push a rama + esperar deploy)
git add -A
git commit -m "refactor: move sidebar toggle from navbar to sidebar header"
git push origin feature/sidebar-toggle-redesign
```

**Checklist visual:**
- [ ] Desktop 1920px: Toggle visible, chevron apunta correcto
- [ ] Tablet 768px: Toggle aún clickeable, sin overflow
- [ ] Mobile 375px: Sidebar minimizado, toggle accesible en hover
- [ ] Expandir/Minimizar: Transición suave, chevron cambia dirección
- [ ] Tooltip: Aparece en hover, desaparece al minimizar
- [ ] Dark mode: Ícono visible, fondo hover coherente
- [ ] Light mode: Contraste suficiente
- [ ] Keyboard: Ctrl+B sigue funcionando, Tab a través del botón

---

## PARTE D: PSEUDOCÓDIGO & EJEMPLOS

### Ejemplo 1: Sidebar Logo Content (Versión Final)

```tsx
"use client";

import Link from "next/link";
import Image from "next/image";
import { ChevronLeft, ChevronRight } from "lucide-react";

import { Logo } from "@/components/Logo";
import {
  useSidebar,
  SidebarMenu,
  SidebarMenuButton,
  SidebarMenuItem,
} from "@/components/ui/sidebar";
import {
  Tooltip,
  TooltipContent,
  TooltipTrigger,
} from "@/components/ui/tooltip";
import { Button } from "@/components/ui/button";

export function SidebarLogoContent() {
  const { state, toggleSidebar } = useSidebar();
  const isCollapsed = state === "collapsed";

  // Icons dinamicos segun estado
  const ChevronIcon = isCollapsed ? ChevronRight : ChevronLeft;
  const toggleLabel = isCollapsed ? "Expandir sidebar" : "Minimizar sidebar";

  return (
    <SidebarMenu>
      <SidebarMenuItem>
        <div className="flex items-center justify-between gap-2 px-2">
          {/* Logo + Texto / Favicon */}
          <SidebarMenuButton asChild className="flex-1 min-w-0">
            <Link prefetch={false} href="/dashboard/default">
              {!isCollapsed ? (
                <>
                  <Logo size="sm" />
                  <span className="font-semibold text-sm truncate">OPTICOLOR</span>
                </>
              ) : (
                <Image
                  src="/favicon.ico"
                  alt="Opticolor"
                  width={24}
                  height={24}
                />
              )}
            </Link>
          </SidebarMenuButton>

          {/* Toggle Button */}
          <Tooltip>
            <TooltipTrigger asChild>
              <Button
                variant="ghost"
                size="sm"
                onClick={toggleSidebar}
                className="h-8 w-8 p-0 shrink-0"
                aria-label={toggleLabel}
                title={toggleLabel}
              >
                <ChevronIcon size={16} />
              </Button>
            </TooltipTrigger>
            <TooltipContent side="right">
              {toggleLabel}
            </TooltipContent>
          </Tooltip>
        </div>
      </SidebarMenuItem>
    </SidebarMenu>
  );
}
```

---

### Ejemplo 2: Layout.tsx (Cambios)

```tsx
// ANTES:
<div className="flex items-center gap-1 lg:gap-2">
  <SidebarTrigger className="-ml-1" />
  <Separator orientation="vertical" ... />
  <SearchDialog />
</div>

// DESPUES:
<div className="flex items-center gap-1 lg:gap-2">
  <SearchDialog />
</div>
```

---

## PARTE E: RESPONSIVIDAD & EDGE CASES

### Desktop (1920px)
- ✅ Logo + Texto + Toggle en línea
- ✅ Tooltip a la derecha sin overflow
- ✅ Toggle siempre visible (no collapse en hover)

### Tablet (768px)
- ✅ Toggle aún clickeable (hit area 32x32px)
- ✅ Sin overflow al lado derecho
- ✅ Transición smooth cuando cambia ancho sidebar

### Mobile (375px)
- ⚠️ Sidebar off-canvas (Sheet)
- ✅ Toggle dentro del header on-canvas
- ✅ Hover → aparece fondo del botón
- ✅ Tooltip abajo (no a la derecha, sin espacio)

**Ajuste mobile en `sidebar-logo-content.tsx`:**
```tsx
// Mobile: tooltip abajo en lugar de derecha
const tooltipSide = isCollapsed ? "right" : "bottom";

<TooltipContent side={tooltipSide}>
  {toggleLabel}
</TooltipContent>
```

---

## PARTE F: CHANGELOG & COMMIT MESSAGE

```
refactor: relocate sidebar toggle from navbar to sidebar header

- Move SidebarTrigger from navbar (layout.tsx) to sidebar header
- Remove unnecessary vertical separator from navbar
- Add toggle button with ChevronLeft/Right icons to SidebarLogoContent
- Integrate Tooltip component for improved UX
- Maintain keyboard shortcut (Ctrl+B) functionality
- Improve mobile space utilization in navbar

Files changed:
  - src/app/(main)/dashboard/layout.tsx (remove trigger + separator)
  - src/app/(main)/dashboard/_components/sidebar/sidebar-logo-content.tsx (add toggle)

Breaking changes: None
```

---

## PARTE G: CRITERIOS DE ACEPTACIÓN

### Visual
- [ ] Sidebar header muestra Logo + Toggle en expandido
- [ ] Sidebar header muestra Favicon + Toggle en minimizado
- [ ] Chevron apunta left (collapse) / right (expand) correctamente
- [ ] Toggle tiene hit area de 32x32px minimum
- [ ] Tooltip visible en hover con texto claro

### Funcional
- [ ] Toggle clickea y cambia estado sidebar
- [ ] Ctrl+B shortcut sigue funcionando
- [ ] Estado persiste en cookie (reload mantiene estado)
- [ ] Navbar sin SidebarTrigger (limpio)

### Accesibilidad
- [ ] Button tiene aria-label descriptivo
- [ ] Tooltip tiene TooltipProvider en raíz
- [ ] Keyboard nav (Tab) accede al botón
- [ ] Focus visible en light + dark mode

### Responsive
- [ ] Desktop (1920px): OK
- [ ] Tablet (768px): OK
- [ ] Mobile (375px): OK

---

## PARTE H: RIESGOS & MITIGACIONES

| Riesgo | Probabilidad | Mitigation |
|--------|--------------|-----------|
| TooltipProvider no en raíz → error | Media | Verificar layout.tsx antes de implementar |
| Mobile tooltip overflow → illegible | Baja | Usar `side="bottom"` en mobile |
| Namespace conflict con `group/logo` | Muy baja | Shadcn/UI maneja bien custom group prefixes |
| Old sidebar state en cookies → error | Muy baja | No hay schema change, solo UI repositioning |

---

## RESUMEN FINAL

**Propuesta recomendada:**
- ✅ **Ícono:** ChevronLeft (collapse) / ChevronRight (expand)
- ✅ **Posición:** Derecha en sidebar header (dentro SidebarLogoContent)
- ✅ **Tooltip:** "Minimizar/Expandir sidebar (Ctrl+B)"
- ✅ **Hit Area:** 32x32px (botón 8x8p + padding)
- ✅ **Estilo:** Button variant="ghost" con hover:bg-accent

**Beneficios UX:**
1. Toggle más intuitivo (donde está el contenedor)
2. Navbar más limpia (gana espacio para future features)
3. Coherencia visual (chevron es estándar en Lucide)
4. Accesibilidad garantizada (Tooltip + ARIA labels)

**Complejidad técnica:** BAJA
- Solo cambio de JSX structure
- No hay nueva lógica, solo movimiento de componente
- Usa hooks + componentes existentes (useSidebar, Tooltip, Button)

---

**Última actualización:** 21 Abril 2026  
**Estado:** ✅ Propuesta completa, lista para implementación  
**Next step:** Ejecutar Parte C (pasos 1-4) + commit  
