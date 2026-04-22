# OPTICOLOR BI — UX/UI Roadmap & Next Steps
**Fecha:** 21 de abril de 2026  
**Versión:** 1.0  
**Estado:** Propuesta (No implementado, pendiente feedback)

---

## EXECUTIVE SUMMARY

### ¿Dónde estamos?
✅ **Portal funcional:** Next.js 16 + Shadcn/UI + Tailwind 4, 5 informes compilando, build exitoso  
✅ **Branding:** Colores Opticolor (#0038E3 azul, #DC143C rojo) integrados  
✅ **Estructura:** Sidebar responsive, navegación clara, dark/light mode persistente  
✅ **Deploy:** Vercel automático en cada git push  

### ¿Qué mejora ahora?
**Top 5 Quick Wins (< 2 horas cada, impacto visual alto):**

1. **Mejorar active state en NavMain** — El item activo en el sidebar es casi imperceptible  
2. **Aplicar colores Opticolor a botones y links** — Actualmente usan colores genéricos  
3. **Agregar loading states en gráficos** — Skeleton screens para mejor UX  
4. **Tablas responsive en mobile** — Scroll horizontal en smartphones  
5. **Contrast audit dark mode** — Asegurar legibilidad en todos los elementos  

### Timeline & Recursos
- **Semana 2.1 (próximas 4-6 horas):** Quick wins (navegación, colores, loading states)  
- **Semana 2.2 (próximos 2-3 días):** Testing responsive, accesibilidad inicial  
- **Semana 2.3 (pendiente datos):** Integración SQL, empty states, error handling  

---

## 1. AUDITORÍA ACTUAL: ESTADO DEL PORTAL

### Strengths (No tocar)
| Aspecto | Estado | Por qué |
|--------|--------|--------|
| **Estructura base** | ✅ Excelente | Layout bien organizado, componentes reutilizables |
| **Tema oscuro** | ✅ Implementado | Dark/light mode persiste en cookies, smooth transitions |
| **Icons** | ✅ Completo | Lucide React bien integrado, consistente |
| **Gráficos** | ✅ Funcionan | Recharts responsive, leyendas claras |
| **Sidebar** | ✅ Bueno | Colapsable, tooltips en hover, logo visible |
| **Tipografía** | ✅ Limpia | Geist font coherente, legible en todos los tamaños |

### Oportunidades UX/UI (Prioridad alta)
| Área | Problema | Impacto |
|-----|---------|--------|
| **Navegación** | Active state poco visible | Alto — Confunde al usuario sobre página actual |
| **Colores** | Botones/links usan colores genéricos | Alto — No reflejan marca Opticolor |
| **Feedback visual** | No hay loading/skeleton screens | Alto — Parece que app está congelada |
| **Responsive** | Tablas no scroll en mobile | Medio — Content se corta en iPhone |
| **Accesibilidad** | Dark mode con poco contrast en algunos links | Medio — Fallan WCAG AA en ciertos elementos |
| **Branding** | Logo solo en sidebar | Bajo — Perdido oportunidad en auth pages |
| **Estados vacíos** | No hay "empty state" cuando no hay datos | Bajo — Confusión sobre si falló carga |

---

## 2. ROADMAP PRIORIZADO: 8-10 MEJORAS

### Escala de Evaluación
- **Impacto UX:** Alto (3) / Medio (2) / Bajo (1)  
- **Complejidad:** Baja (1h) / Media (2-4h) / Alta (>4h)  
- **Riesgo:** Bajo / Medio / Alto  
- **Score:** (Impacto × 3) + (10 - Complejidad)  

### Tabla de Mejoras Ranqueadas

| Ranking | Mejora | Impacto | Complejidad | Riesgo | Score | Tiempo Estimado | Status |
|---------|--------|--------|-------------|--------|-------|-----------------|--------|
| **1** | Mejorar active state en NavMain (color + badge) | Alto (3) | Baja (1h) | Bajo | 28 | **30-45 min** | Quick Win |
| **2** | Aplicar colores Opticolor a botones primarios | Alto (3) | Baja (1h) | Bajo | 28 | **45 min** | Quick Win |
| **3** | Agregar skeleton screens en gráficos | Alto (3) | Media (2h) | Bajo | 25 | **1.5-2h** | Quick Win |
| **4** | Tablas: scroll horizontal en mobile | Medio (2) | Baja (1h) | Bajo | 27 | **45-60 min** | Quick Win |
| **5** | Contrast audit + fixes dark mode | Medio (2) | Baja (1h) | Bajo | 27 | **1-1.5h** | Quick Win |
| **6** | Mejorar hover/focus states en sidebar | Medio (2) | Baja (1h) | Bajo | 27 | **45 min** | Quick Win |
| **7** | Agregar empty states (no data) | Medio (2) | Media (2h) | Bajo | 24 | **2-3h** | Medium-term |
| **8** | Error boundary + error state UI | Medio (2) | Media (3h) | Medio | 22 | **2.5-3.5h** | Medium-term |
| **9** | Animaciones suaves en transiciones | Bajo (1) | Media (2h) | Bajo | 19 | **1.5-2h** | Polish |
| **10** | Documentación design tokens + brand guide | Bajo (1) | Baja (1h) | Bajo | 18 | **1h** | Documentation |

---

## 3. IMPLEMENTACIÓN POR FASE

### FASE 1: QUICK WINS (4-6 horas totales, Semana 2.1)
**Objetivo:** Mejoras visuales de alto impacto sin datos reales

#### Mejora #1: Active State NavMain — `sidebar/nav-main.tsx`
**Qué:** El item activo debe ser más visible (color + badge + fondo)  
**Cómo:**
```tsx
// Actual: apenas visible
<SidebarMenuButton isActive={isActive(...)} />

// Propuesto:
<SidebarMenuButton isActive={isActive(...)} className={isActive(...) ? "bg-primary text-primary-foreground" : ""}>
  {item.icon && <item.icon />}
  <span>{item.title}</span>
  {isActive(...) && <Badge variant="default" className="ml-auto">Activo</Badge>}
</SidebarMenuButton>
```
**Impacto:** El usuario sabe claramente dónde está  
**Tiempo:** 30-45 min  
**Riesgo:** Bajo (solo CSS + condicional)

#### Mejora #2: Colores Opticolor en Botones
**Qué:** Reemplazar colores genéricos con paleta Opticolor (#0038E3, #DC143C)  
**Dónde:** Componentes Button, Badge, Links  
**Cómo:**
- Botón primario: `bg-primary` (ya está configurado a #0038E3)  
- Botón secundario: agregar variante con #DC143C  
- Links: cambiar color a `text-primary` con underline en hover  

**Archivo:** `portal/src/components/ui/button.tsx`  
**Tiempo:** 45 min  
**Impacto:** Alto — Refuerza branding  

#### Mejora #3: Loading States (Skeleton Screens)
**Qué:** Mientras se cargan gráficos, mostrar skeleton en lugar de blank  
**Dónde:** `dashboard/default/_components/*.tsx`  
**Cómo:**
```tsx
// Usar Shadcn <Skeleton /> component
import { Skeleton } from "@/components/ui/skeleton";

{isLoading ? (
  <div className="h-80 space-y-2">
    <Skeleton className="h-full w-full rounded-lg" />
  </div>
) : (
  <ChartContainer>...</ChartContainer>
)}
```
**Tiempo:** 1.5-2h (aplicar a 3 gráficos principales)  
**Impacto:** Alto — Indica carga activa  

#### Mejora #4: Tablas Responsive (Scroll Mobile)
**Qué:** En phones, las tablas deben ser scrolleables horizontalmente  
**Dónde:** `dashboard/default/_components/recent-customers-table/table.tsx`  
**Cómo:**
```tsx
<div className="overflow-x-auto md:overflow-x-visible">
  <table className="w-full text-sm">...</table>
</div>
```
**Tiempo:** 45-60 min  
**Impacto:** Medio — Mejora mobile UX  

#### Mejora #5: Contrast Audit Dark Mode
**Qué:** Verificar WCAG AA (4.5:1) en dark mode para links, badges, etc.  
**Dónde:** Toda la app (audit con DevTools)  
**Acción:**
- Usar DevTools Accessibility tab → Check contrast  
- Links en dark: cambiar a colores más claros (#378ADD en lugar de #0038E3)  
- Badges: asegurar contraste 4.5:1  

**Tiempo:** 1-1.5h  
**Impacto:** Medio — Accesibilidad mejorada  

#### Mejora #6: Hover/Focus States
**Qué:** Todos los elementos interactivos deben tener estados claros  
**Dónde:** Sidebar items, buttons, cards  
**Cómo:**
```tsx
<SidebarMenuButton className="hover:bg-accent focus-visible:ring-2 focus-visible:ring-offset-2" />
```
**Tiempo:** 45 min  
**Impacto:** Medio — Mejor keyboard navigation  

---

### FASE 2: MEDIUM-TERM (2-3 días, Semana 2.2-2.3)
**Objetivo:** Mejoras que requieren coordinación con datos o cliente

#### Mejora #7: Empty States
**Qué:** Cuando no hay datos, mostrar UI descriptiva en lugar de tabla vacía  
**Ejemplo:**
```tsx
{data.length === 0 ? (
  <div className="flex flex-col items-center justify-center gap-4 py-12">
    <PackageOpen className="size-12 text-muted-foreground" />
    <div className="text-center">
      <h3 className="font-medium">No customers yet</h3>
      <p className="text-muted-foreground text-sm">Start by adding your first customer.</p>
    </div>
  </div>
) : (
  <RecentCustomersTable data={data} />
)}
```
**Tiempo:** 2-3h (para 5 informes)  
**Dependencia:** Estructura de datos desde Azure SQL  
**Impacto:** Medio — Mejor experiencia cuando faltan datos  

#### Mejora #8: Error Boundary + Error State
**Qué:** Si falla API, mostrar UI con retry button en lugar de blanco  
**Dónde:** Componentes principales (gráficos, tablas)  
**Implementar:** React error boundary + toast notifications  
**Tiempo:** 2.5-3.5h  
**Dependencia:** Testing con datos reales  
**Impacto:** Medio — Recuperación elegante de errores  

---

### FASE 3: POLISH & DOCUMENTATION (1-2 horas, Semana 3)
**Objetivo:** Refinamiento final + guía para el equipo

#### Mejora #9: Animaciones Suaves
**Qué:** Page transitions, chart animations, hover effects  
**Implementar:** Framer Motion o CSS transitions nativas  
**Tiempo:** 1.5-2h  
**Impacto:** Bajo (visual polish)  

#### Mejora #10: Design Tokens + Brand Guide
**Qué:** Documentar colores, spacing, typography usados  
**Formato:** Markdown con ejemplos visuales  
**Ubicación:** `portal/DESIGN_TOKENS.md`  
**Tiempo:** 1h  
**Impacto:** Bajo (pero necesario para team)  

---

## 4. CHECKLIST DE TESTING POR FASE

### Antes de implementar cada fase:

#### Testing Visual (Desktop)
- [ ] En 1920x1080: sidebar expandido/colapsado, gráficos completos  
- [ ] Dark mode: todos los colores legibles (contrast 4.5:1)  
- [ ] Light mode: no hay glare excesivo  
- [ ] Hover states: botones, links, sidebar items responden  
- [ ] Focus indicators: Tab navega por todos los elementos  

#### Testing Responsive (Mobile)
- [ ] iPhone SE (375px): content no se corta, sidebar offscreen  
- [ ] iPad (768px): gráficos responsive, tablas scrolleables  
- [ ] Android (360px): Google Pixel 3 equivalent  
- [ ] Touch: botones 44x44px mínimo, sin accidentes  

#### Testing Accesibilidad
- [ ] NVDA/JAWS: ¿Lee bien los labels y titles?  
- [ ] Keyboard: ¿Se puede navegar sin mouse?  
- [ ] Contrast: DevTools Accessibility → 4.5:1 WCAG AA  
- [ ] Color blind: Usar Contrast Checker online  

#### Testing en Vercel
- [ ] Deploy automático después de commit  
- [ ] Preview URL funciona en mobile real  
- [ ] Perf: Lighthouse > 85 (Performance, Accessibility)  

---

## 5. ESTIMACIÓN TOTAL & TIMELINE

| Fase | Mejoras | Tiempo | Bloqueadores | Target Date |
|------|---------|--------|--------------|-------------|
| **Quick Wins** | #1-6 | 4-6h | Ninguno | Martes 22/Abril |
| **Medium-term** | #7-8 | 5-7h | Datos SQL, API testing | Viernes 25/Abril |
| **Polish** | #9-10 | 2-3h | Feedback cliente | Lunes 28/Abril |
| **TOTAL** | 10 mejoras | **11-16 horas** | — | Semana 2.3 |

---

## 6. BLOCKERS & DEPENDENCIAS

### No bloqueados (puedo hacer YA):
- ✅ Mejoras #1-6 (visual, no requieren datos)  

### Parcialmente bloqueados:
- ⏳ Mejora #7 (empty states) — Requiere estructura de datos final  
- ⏳ Mejora #8 (error handling) — Requiere testing con API real  

### Bloqueados por Opticolor:
- Logo en auth pages (necesito logo PNG)  
- Paleta colores definitiva (actualmente uso #0038E3 + #DC143C asumidos)  
- Datos reales (PRODUCTOS, VENTAS, etc.)  

---

## 7. CRITERIOS DE ACEPTACIÓN

### Quick Wins
- [ ] NavMain active state visible (color + badge)  
- [ ] Botones primarios son azul Opticolor (#0038E3)  
- [ ] Gráficos muestran skeleton mientras cargan  
- [ ] Tablas scrolleables en mobile  
- [ ] Dark mode WCAG AA en todos los elementos  
- [ ] Hover/focus states implementados  
- [ ] Build: `npm run build` sin errores  
- [ ] Deploy Vercel exitoso  
- [ ] Visual testing en 375px (mobile) + 1920px (desktop)  

### Medium-term
- [ ] Empty states con iconos descriptivos  
- [ ] Error boundary + toast notifications  
- [ ] API fallback graceful  

### Polish
- [ ] Page transitions suaves  
- [ ] Brand guide documentado  

---

## 8. RECOMENDACIONES FINALES

### ¿Qué hacer ahora?
1. **Implementar Quick Wins** (hoy/mañana) — Alto ROI, bajo riesgo  
2. **Testing en mobile real** — No asumir que responsive = listo  
3. **Feedback Opticolor** — ¿Les gusta el estilo? ¿Cambios en colores?  

### ¿Qué esperar?
- No esperar datos de Azure SQL para mejorar UI  
- Las mejoras visuales se pueden hacer en paralelo con ETL  
- Testing visual en Vercel es gratis y fast  

### ¿Qué NO hacer?
- No cambiar estructura HTML sin testing (riesgo de romper layout)  
- No inventar colores nuevos sin aprobación Opticolor  
- No agregar librerías sin revisar bundle size  

---

## 9. PRÓXIMOS PASOS

### Hoy (21/Abril):
1. ✅ Auditoría completada  
2. ⏭️ **ESPERA:** Aprobación de roadmap por PM/Usuario  

### Mañana (22/Abril) — SI APROBADO:
1. Feature branch: `feat/ux-improvements-q1`  
2. Implementar mejoras #1-6  
3. Testing en Vercel  
4. PR + feedback antes de merge  

### Semana siguiente (25-28/Abril):
1. Mejoras #7-8 (con datos)  
2. Polish #9-10  
3. Deploy final a producción  

---

## ANEXO A: STACK TÉCNICO (Contexto)

| Layer | Tech | Versión | Notas |
|-------|------|---------|-------|
| Framework | Next.js | 16.2.4 | App Router, SSR |
| UI Kit | Shadcn/UI | Latest | 50+ componentes |
| Styling | Tailwind CSS | 4 | CSS variables oklch |
| Icons | Lucide React | Latest | 1000+ icons |
| Charts | Recharts | Latest | Responsive |
| Theme | CSS Variables | — | Dark/light + 4 presets |
| Deploy | Vercel | — | Auto-deploy on push |

---

## ANEXO B: COLOR PALETTE (Actual)

**Light Mode (Opticolor preset):**
```
Primary:   #0038E3 (Azul corporativo)
Secondary: #DC143C (Rojo/Crimson)
Accent:    #0F3E68 (Azul oscuro)
BG:        #F5F5F5 (Gris claro)
Text:      #232323 (Negro suave)
Border:    #E0E0E0 (Gris muy claro)
```

**Dark Mode (Opticolor preset):**
```
Primary:   #378ADD (Azul más claro)
Secondary: #E74C3C (Rojo ajustado)
Accent:    #00A86B (Verde)
BG:        #1A1A1A (Negro)
Text:      #FFFFFF (Blanco)
Border:    #3A3A3A (Gris oscuro)
```

---

## ANEXO C: REFERENCIAS & RECURSOS

### Documentación interna:
- `.claude/agents/ux-ui-portal.md` — Filosofía UX/UI  
- `CLAUDE.md` — Contexto general Opticolor BI  
- Vercel deploy: https://opticolor-bi.vercel.app  

### Herramientas externas:
- **WCAG Contrast Checker:** https://webaim.org/resources/contrastchecker/  
- **Lighthouse:** DevTools → Lighthouse tab  
- **Responsive Design Checker:** DevTools → Toggle device toolbar  
- **Color Blindness Simulator:** https://www.color-blindness.com/coblis-color-blindness-simulator/  

---

## ANEXO D: PREGUNTAS FRECUENTES (FAQ)

**P: ¿Por qué no hiciste ya los cambios?**  
R: Propuesta primero, feedback segundo — así evitamos cambios que no le gustan a Opticolor.

**P: ¿Esto funciona sin datos reales?**  
R: Sí — Las mejoras #1-6 son puro CSS/UI. Los datos vienes después en Semana 2.3.

**P: ¿Qué pasa si Opticolor quiere otros colores?**  
R: Rápido cambio en `portal/src/styles/presets/opticolor.css` + redeploy.

**P: ¿Puedo hacer esto en paralelo con ETL?**  
R: Sí, totalmente. Teams separados sin conflictos.

**P: ¿Riesgo de romper algo?**  
R: Bajo si seguimos el checklist. Cambios son CSS + condicionales, no lógica core.

---

**Documento creado:** 21 de abril de 2026  
**Última revisión:** 21 de abril de 2026  
**Estado:** LISTO PARA FEEDBACK  
**Próxima reunión:** Pendiente aprobación de roadmap
