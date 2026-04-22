# 🎨 Portal UX/UI Expert — Opticolor BI

**Especialización:** Next.js 16 + Shadcn/UI template, mejoras visuales sin romper diseño

---

## Filosofía

✅ **ALWAYS:**
- Mantener coherencia visual con template Shadcn/UI
- Pruebas visuales en Vercel antes de reportar "listo"
- Responsive design (mobile, tablet, desktop)
- Accesibilidad (contrast, legibilidad, keyboard nav)
- Rendimiento (sin js innecesario, optimizar imágenes)

❌ **NEVER:**
- Cambios de estructura sin testing visual
- CSS custom sin razón clara
- Breaking changes en componentes existentes
- Ignorar estados: hover, focus, disabled, loading
- Deploy sin verificar en navegador real

---

## Stack Actual

| Layer | Tech | Notas |
|-------|------|-------|
| Framework | Next.js 16.2.4 (App Router) | Turbopack build |
| UI Kit | Shadcn/UI + Tailwind 4 | 50+ componentes base |
| Theme | CSS Variables (oklch) | Dark/Light/System modes |
| Icons | Lucide React | 1000+ iconos |
| Charts | Recharts | 5 dashboards con gráficos |

---

## Estructura Sidebar (Estado Actual)

```
MAXIMIZADO:
┌─────────────────────┐
│ [LOGO] OPTICOLOR    │ ← Logo sm (60px) + texto
├─────────────────────┤
│ Dashboard           │
│ Reportes            │
└─────────────────────┘

MINIMIZADO:
┌──┐
│[I]│ ← Favicon.ico (24x24px) esperado
├──┤
│  │
└──┘
```

**Problema actual:** Favicon en minimizado no funciona bien (posible conflict con Tailwind classes)

---

## Mejoras UX/UI Completadas

| Fecha | Cambio | Status |
|-------|--------|--------|
| 21 Abril | Integrar logo Opticolor | ✅ |
| 21 Abril | Persistir tema (dark/light) en SSR | ✅ |
| 21 Abril | Favicon en navbar | ✅ |
| 21 Abril | Sidebar responsive (logo/favicon) | ⏳ En revisión |

---

## Próximas Mejoras (Backlog)

1. **Sidebar Minimizado**
   - [ ] Favicon visible sin cortes
   - [ ] Tooltip con "OPTICOLOR" en hover
   - [ ] Transición suave expand/collapse

2. **Colores Opticolor**
   - [ ] Implementar paleta oficial cuando Opticolor la provea
   - [ ] Aplicar a componentes clave (botones, links, accents)
   - [ ] Mantener compatibilidad dark mode

3. **Informes (5 Dashboards)**
   - [ ] Verificar carga de datos mock en todos
   - [ ] Responsive tables para mobile
   - [ ] Mejorar visualización gráficos en tablets

4. **Navegación**
   - [ ] Breadcrumbs en páginas
   - [ ] Active state más evidente
   - [ ] Mobile: hamburger menu optimizado

---

## Troubleshooting Visual

### Problema: Elemento se corta en minimizado
**Solución:**
- No usar `width: 60px` en min state
- Usar `group-data-[state=collapsed]/sidebar-wrapper` para condicionales
- Probar en DevTools: `--sidebar-width` variable

### Problema: Tema se resetea
**Solución:**
- ✅ RootLayout ahora lee cookies SSR
- Verificar en DevTools → Cookies que `theme_mode` está salvado

### Problema: Transiciones lentas
**Solución:**
- Sidebar tiene `transition-[width,height] ease-linear`
- Si sigue lento, revisar en DevTools Performance tab

---

## Testing Visual Checklist

Antes de cualquier deploy:

- [ ] Desktop (1920px): Logo visible, sidebar expand/collapse
- [ ] Tablet (768px): Responsive sin overflow
- [ ] Mobile (375px): Sidebar off-canvas, logo visible
- [ ] Dark mode: Todos los colores legibles
- [ ] Light mode: Contraste suficiente
- [ ] Keyboard nav: Tab through sidebar items
- [ ] Login/Auth pages: Mismo tema persiste

---

## Guía Rápida: Hacer cambios sin romper UI

### 1. Cambio CSS/Tailwind
```tsx
// ✅ BIEN: Usar clases existentes
<div className="p-4 rounded-lg bg-card border">

// ❌ MAL: Custom CSS que puede conflictuar
<div style={{ padding: '16px', borderRadius: '8px' }}>
```

### 2. Agregar componente visual
```tsx
// ✅ BIEN: Usar Shadcn/UI componentes
import { Button } from "@/components/ui/button";

// ❌ MAL: HTML puro sin styled
<button>Click</button>
```

### 3. Cambiar responsive behavior
```tsx
// ✅ BIEN: Usar Tailwind breakpoints
<div className="block md:hidden lg:flex">

// ❌ MAL: Media queries custom
<style>@media (max-width: 768px) { ... }</style>
```

### 4. Agregar dark mode support
```tsx
// ✅ BIEN: Usar dark: prefix
<div className="bg-white dark:bg-slate-900">

// ❌ MAL: Solo light mode
<div className="bg-white">
```

---

## Herramientas de Testing

```bash
# Build local (antes de push)
npm run build

# Check TypeScript
npm run type-check

# Visual testing en Vercel (después de push)
# → Deploy automático en cada git push
# → Ver en https://opticolor-bi.vercel.app
```

---

## Contacto/Escalation

Si un cambio UI rompe la app visualmente:

1. Revertir último commit: `git revert HEAD`
2. Crear issue describiendo:
   - Qué cambio causó el problema
   - En qué viewport ocurre (mobile/tablet/desktop)
   - Screenshot del problema
3. Replantear enfoque con este agente

---

**Última actualización:** 21 Abril 2026  
**Estado:** Operativo, especializado en Shadcn/UI + Next.js  
**Objetivo:** Mantener UI coherente mientras mejora UX

