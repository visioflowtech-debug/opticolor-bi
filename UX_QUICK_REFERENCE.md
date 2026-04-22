# UX/UI Quick Reference — Opticolor BI Portal
**21 de Abril 2026 | Estado: Propuesta**

---

## TOP 6 QUICK WINS (Implementar hoy/mañana, 4-6 horas)

| # | Mejora | Dónde | Cómo | Tiempo |
|---|--------|-------|------|--------|
| 1️⃣ | **Active state visible** | `nav-main.tsx` | Bg color + badge "Activo" | 30-45 min |
| 2️⃣ | **Botones Opticolor** | Toda la app | Primary: #0038E3, Secondary: #DC143C | 45 min |
| 3️⃣ | **Skeleton screens** | Gráficos (3x) | Mostrar `<Skeleton>` mientras cargan | 1.5-2h |
| 4️⃣ | **Tablas responsive** | `recent-customers-table/` | `overflow-x-auto` en mobile | 45-60 min |
| 5️⃣ | **Dark mode contrast** | CSS variables | Link: #378ADD (dark), check WCAG AA | 1-1.5h |
| 6️⃣ | **Hover/focus states** | Sidebar + Buttons | `hover:bg-accent`, `focus-visible:ring-2` | 45 min |

---

## MEDIUM-TERM (Semana 2.2-2.3, 5-7 horas)

| # | Mejora | Requisito | Tiempo |
|---|--------|-----------|--------|
| 7️⃣ | Empty states (no data UI) | Estructura datos final | 2-3h |
| 8️⃣ | Error boundary + toast | API testing | 2.5-3.5h |

---

## POLISH (Opcional, Semana 3, 2-3 horas)

| # | Mejora | Impacto |
|---|--------|--------|
| 9️⃣ | Animaciones suaves (Framer) | Bajo (visual only) |
| 🔟 | Design tokens guide | Bajo (documentation) |

---

## CHECKLIST PRE-IMPLEMENTACIÓN

### ✅ Antes de empezar cada fase:
- [ ] Branch: `feat/ux-improvements-q1`
- [ ] Build local: `npm run build` sin errores
- [ ] Testing visual: Desktop (1920px) + Mobile (375px)
- [ ] Dark mode: Contrast checker en todos los colores

### ✅ Después de cada cambio:
- [ ] Deploy Vercel automático ✓
- [ ] Visual en https://opticolor-bi.vercel.app
- [ ] Keyboard nav: Tab through todos los elementos
- [ ] DevTools Lighthouse: Performance > 85

---

## ARCHITECTURE DECISIONS

### Colores (Opticolor theme lock)
```
Light:  Primary #0038E3 (azul) | Secondary #DC143C (rojo)
Dark:   Primary #378ADD (más claro) | Secondary #E74C3C (ajustado)
```
📍 Archivo: `portal/src/styles/presets/opticolor.css`

### Componentes a tocar
```
portal/src/
  ├─ app/(main)/dashboard/_components/sidebar/nav-main.tsx        ← #1, #6
  ├─ components/ui/button.tsx                                      ← #2
  ├─ app/(main)/dashboard/default/_components/*.tsx               ← #3, #4
  ├─ app/globals.css                                              ← #5
```

### NO tocar (breaking risk)
```
- RootLayout → SSR theme boot
- Sidebar component structure → collapsible logic
- Next.js routing → test antes de cambiar paths
```

---

## TESTING QUICK CHECKLIST

**Visual (3 min per viewport):**
- [ ] Desktop 1920x1080: Sidebar expandido/colapsado
- [ ] Tablet 768x1024: Gráficos responsive
- [ ] Mobile 375x667: Content no se corta, sidebar offscreen

**Accessibility (5 min):**
- [ ] Contrast: https://webaim.org/resources/contrastchecker/
- [ ] Keyboard: Tab + Shift+Tab navega todos los elementos
- [ ] Screen reader ready: Label cada input/button

**Dark Mode (2 min):**
- [ ] Todos los textos legibles (contrast 4.5:1)
- [ ] Sin "panda eyes" (text con poco contrast)
- [ ] Botones/links claramente clicables

**Performance (2 min):**
- [ ] DevTools Lighthouse: Performance > 85
- [ ] Gráficos no hacen lag en drag/zoom
- [ ] Sidebar toggle smooth (no jumps)

---

## GIT WORKFLOW

```bash
# 1. Crear branch
git checkout -b feat/ux-improvements-q1

# 2. Hacer cambios (max 1 hora per commit)
# Preferible: 1 commit per mejora

# 3. Commit message format:
git commit -m "feat(ui): mejorar active state en navegación

- NavMain items now show colored bg + badge when active
- Improves UX clarity on current page
- Tested in light/dark mode, desktop/mobile"

# 4. Push y hacer PR
git push origin feat/ux-improvements-q1

# 5. Vercel auto-deploys preview URL

# 6. Merge to main después de aprobación
```

---

## BLOCKERS & DEPENDENCIES

### ✅ PUEDO HACER YA (no bloqueados):
- Mejoras #1-6 — puro CSS/UI

### ⏳ REQUIEREN DATOS:
- Mejora #7 (empty states) — estructura datos final
- Mejora #8 (error handling) — API testing con datos reales

### ⚠️ REQUIEREN OPTICOLOR:
- Logo PNG (branding en auth)
- Paleta colores definitiva (actualmente #0038E3 + #DC143C assumed)

---

## TIMELINE VISUAL

```
Semana 2.1 (HOY/MAÑANA)    Semana 2.2 (Viernes)    Semana 2.3 (Next Mon)
├─ Quick wins #1-6         ├─ Testing intensive    ├─ Empty states
│  (4-6h)                  │ (2-3h)                │ (2-3h)
│  └─ Auto-deploy          │ └─ Feedback loop      │ └─ Error handling
└─ PR review               └─ Medium fixes         └─ Polish #9-10
   (1-2h)                                            (2-3h)

TOTAL: 11-16 hours
```

---

## QUICK WIN EXAMPLES

### #1: Active state (nav-main.tsx, línea ~164)
```tsx
// ANTES:
<SidebarMenuButton isActive={isItemActive(item.url)} />

// DESPUES:
{isItemActive(item.url) && (
  <SidebarMenuButton className="bg-primary text-primary-foreground">
    {item.icon && <item.icon />}
    <span>{item.title}</span>
    <Badge variant="default" className="ml-auto">Active</Badge>
  </SidebarMenuButton>
) || (
  <SidebarMenuButton>{item.icon && <item.icon />}<span>{item.title}</span></SidebarMenuButton>
)}
```

### #3: Skeleton screens (metric-cards.tsx)
```tsx
// ANTES:
<Card><CardContent>{data && <MetricValue data={data} />}</CardContent></Card>

// DESPUES:
<Card>
  <CardContent>
    {isLoading ? (
      <Skeleton className="h-12 w-full rounded-md" />
    ) : (
      <MetricValue data={data} />
    )}
  </CardContent>
</Card>
```

### #5: Dark mode contrast fix (opticolor.css)
```css
/* ANTES: Links casi invisibles en dark */
.dark a { color: #0038E3; } /* Fail: 2.5:1 contrast */

/* DESPUES: Links legibles */
.dark a { color: #378ADD; } /* Pass: 5.2:1 contrast */
```

---

## APROBACIÓN & FEEDBACK

**Estado actual:** 📋 Propuesta completada  
**Siguiente paso:** ⏳ Espera aprobación PM/Usuario  
**Si aprobado:** ✅ Comenzar implementación Quick Wins  
**Si cambios:** 🔄 Iterar roadmap según feedback  

**Contacto:** Este documento + `OPTICOLOR_UX_ROADMAP_NEXT_STEPS.md` (completo)

---

*Generado automáticamente. Para detalles, ver documento completo.*
