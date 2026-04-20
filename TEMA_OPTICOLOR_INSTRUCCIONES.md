# 🎨 INTEGRACIÓN TEMA OPTI-COLOR — Instrucciones Detalladas

**Proyecto:** Opticolor BI Portal  
**Objetivo:** Agregar tema "OPTI-COLOR" a Preferences/Theme Preset sin eliminar temas existentes  
**Estado:** Listo para implementar

---

## 📋 RESUMEN DE CAMBIOS

Se modificarán **3 archivos** y se creará **1 nuevo archivo CSS**:

| Archivo | Acción | Razón |
|---------|--------|-------|
| `src/lib/preferences/theme.ts` | Agregar opción OPTI-COLOR | Registrar preset en selector |
| `src/styles/presets/opticolor.css` | **CREAR NUEVO** | Estilos CSS variables tema |
| `src/app/globals.css` | Importar opticolor.css | Cargar estilos preset |
| `src/stores/preferences/preferences-store.ts` | Sin cambios | Ya soporta cualquier preset |

---

## 🎯 PASO 1: Agregar OPTI-COLOR a theme.ts

**Archivo:** `portal/src/lib/preferences/theme.ts`

**Acción:** Agregar objeto `opticolor` en el array `THEME_PRESET_OPTIONS`

### Código a agregar (copiar/pegar):

```typescript
// En THEME_PRESET_OPTIONS, agregar este objeto ANTES del ] final:

  {
    label: "⭐ OPTI-COLOR",
    value: "opticolor",
    primary: {
      light: "oklch(0.3 0.2 259.5)",    // Deep Blue #0038E3
      dark: "oklch(0.55 0.18 259.5)",   // Light Blue #378ADD
    },
  },
```

### Archivo completo después del cambio:

```typescript
export const THEME_MODE_OPTIONS = [
  { label: "Light", value: "light" },
  { label: "Dark", value: "dark" },
  { label: "System", value: "system" },
] as const;

export const THEME_MODE_VALUES = THEME_MODE_OPTIONS.map((o) => o.value);
export type ThemeMode = (typeof THEME_MODE_VALUES)[number];
export type ResolvedThemeMode = "light" | "dark";

// --- generated:themePresets:start ---

export const THEME_PRESET_OPTIONS = [
  {
    label: "Default",
    value: "default",
    primary: {
      light: "oklch(0.205 0 0)",
      dark: "oklch(0.922 0 0)",
    },
  },
  {
    label: "Brutalist",
    value: "brutalist",
    primary: {
      light: "oklch(0.6489 0.237 26.9728)",
      dark: "oklch(0.7044 0.1872 23.1858)",
    },
  },
  {
    label: "Soft Pop",
    value: "soft-pop",
    primary: {
      light: "oklch(0.5106 0.2301 276.9656)",
      dark: "oklch(0.6801 0.1583 276.9349)",
    },
  },
  {
    label: "Tangerine",
    value: "tangerine",
    primary: {
      light: "oklch(0.64 0.17 36.44)",
      dark: "oklch(0.64 0.17 36.44)",
    },
  },
  {
    label: "⭐ OPTI-COLOR",
    value: "opticolor",
    primary: {
      light: "oklch(0.3 0.2 259.5)",
      dark: "oklch(0.55 0.18 259.5)",
    },
  },
] as const;

export const THEME_PRESET_VALUES = THEME_PRESET_OPTIONS.map((p) => p.value);

export type ThemePreset = (typeof THEME_PRESET_OPTIONS)[number]["value"];

// --- generated:themePresets:end ---
```

---

## 🎨 PASO 2: Crear archivo CSS con paleta OPTI-COLOR

**Archivo:** `portal/src/styles/presets/opticolor.css`

**Acción:** Crear archivo nuevo con estilos tema

### Contenido completo (copiar/pegar):

```css
/* 
label: OPTI-COLOR
value: opticolor 
*/

:root[data-theme-preset="opticolor"] {
  --radius: 0.625rem;
  --card: #FFFFFF;
  --card-foreground: #232323;
  --popover: #FFFFFF;
  --popover-foreground: #232323;
  --primary: #0038E3;
  --primary-foreground: #FFFFFF;
  --secondary: #DC143C;
  --secondary-foreground: #FFFFFF;
  --muted: #F5F5F5;
  --muted-foreground: #828282;
  --accent: #0F3E68;
  --accent-foreground: #FFFFFF;
  --destructive: #DC143C;
  --border: #E0E0E0;
  --input: #FFFFFF;
  --ring: #185FA5;
  --chart-1: #0038E3;
  --chart-2: #DC143C;
  --chart-3: #0F3E68;
  --chart-4: #B8860B;
  --chart-5: #6B4C9A;
  --sidebar: #F5F5F5;
  --sidebar-foreground: #232323;
  --sidebar-primary: #0038E3;
  --sidebar-primary-foreground: #FFFFFF;
  --sidebar-accent: #0F3E68;
  --sidebar-accent-foreground: #FFFFFF;
  --sidebar-border: #E0E0E0;
  --sidebar-ring: #185FA5;
  --background: #F5F5F5;
  --foreground: #232323;
  --shadow-2xs: 0px 0px 0px 0px rgba(35, 37, 35, 0.03);
  --shadow-xs: 0px 0px 0px 0px rgba(35, 37, 35, 0.03);
  --shadow-sm: 0px 0px 0px 0px rgba(35, 37, 35, 0.05), 0px 1px 2px -1px rgba(35, 37, 35, 0.05);
  --shadow: 0px 0px 0px 0px rgba(35, 37, 35, 0.05), 0px 1px 2px -1px rgba(35, 37, 35, 0.05);
  --shadow-md: 0px 0px 0px 0px rgba(35, 37, 35, 0.05), 0px 2px 4px -1px rgba(35, 37, 35, 0.05);
  --shadow-lg: 0px 0px 0px 0px rgba(35, 37, 35, 0.05), 0px 4px 6px -1px rgba(35, 37, 35, 0.05);
  --shadow-xl: 0px 0px 0px 0px rgba(35, 37, 35, 0.05), 0px 8px 10px -1px rgba(35, 37, 35, 0.05);
  --shadow-2xl: 0px 0px 0px 0px rgba(35, 37, 35, 0.13);
}

.dark:root[data-theme-preset="opticolor"] {
  --background: #1A1A1A;
  --foreground: #FFFFFF;
  --card: #232323;
  --card-foreground: #FFFFFF;
  --popover: #232323;
  --popover-foreground: #FFFFFF;
  --primary: #378ADD;
  --primary-foreground: #1A1A1A;
  --secondary: #E74C3C;
  --secondary-foreground: #1A1A1A;
  --muted: #3A3A3A;
  --muted-foreground: #B0B0B0;
  --accent: #00A86B;
  --accent-foreground: #1A1A1A;
  --destructive: #E74C3C;
  --border: #3A3A3A;
  --input: #232323;
  --ring: #378ADD;
  --chart-1: #378ADD;
  --chart-2: #E74C3C;
  --chart-3: #00A86B;
  --chart-4: #F39C12;
  --chart-5: #B8860B;
  --sidebar: #1A1A1A;
  --sidebar-foreground: #FFFFFF;
  --sidebar-primary: #378ADD;
  --sidebar-primary-foreground: #1A1A1A;
  --sidebar-accent: #00A86B;
  --sidebar-accent-foreground: #1A1A1A;
  --sidebar-border: #3A3A3A;
  --sidebar-ring: #378ADD;
  --shadow-2xs: 0px 0px 0px 0px rgba(0, 0, 0, 0.03);
  --shadow-xs: 0px 0px 0px 0px rgba(0, 0, 0, 0.03);
  --shadow-sm: 0px 0px 0px 0px rgba(0, 0, 0, 0.05), 0px 1px 2px -1px rgba(0, 0, 0, 0.05);
  --shadow: 0px 0px 0px 0px rgba(0, 0, 0, 0.05), 0px 1px 2px -1px rgba(0, 0, 0, 0.05);
  --shadow-md: 0px 0px 0px 0px rgba(0, 0, 0, 0.05), 0px 2px 4px -1px rgba(0, 0, 0, 0.05);
  --shadow-lg: 0px 0px 0px 0px rgba(0, 0, 0, 0.05), 0px 4px 6px -1px rgba(0, 0, 0, 0.05);
  --shadow-xl: 0px 0px 0px 0px rgba(0, 0, 0, 0.05), 0px 8px 10px -1px rgba(0, 0, 0, 0.05);
  --shadow-2xl: 0px 0px 0px 0px rgba(0, 0, 0, 0.13);
}
```

---

## 📄 PASO 3: Importar CSS en globals.css

**Archivo:** `portal/src/app/globals.css`

**Acción:** Agregar línea de import para opticolor.css

### Línea a agregar (después línea 8):

```css
@import "../styles/presets/opticolor.css";
```

### Contexto (primeras 10 líneas después del cambio):

```css
@import "tailwindcss";
@import "tw-animate-css";
@import "shadcn/tailwind.css";

/* Theme preset styles: these override CSS variables based on the selected data-theme-preset */
@import "../styles/presets/brutalist.css";
@import "../styles/presets/soft-pop.css";
@import "../styles/presets/tangerine.css";
@import "../styles/presets/opticolor.css";

@custom-variant dark (&:is(.dark *));
```

---

## ✅ PASO 4: Validar cambios

### 4.1 Verificar archivos creados/modificados:

```bash
# En portal/
ls -la src/styles/presets/opticolor.css          # Debe existir
grep "opticolor" src/lib/preferences/theme.ts   # Debe contener opticolor
grep "opticolor.css" src/app/globals.css        # Debe tener import
```

### 4.2 Compilar Portal:

```bash
cd portal
npm run build
```

Si hay errores, revisar:
- Sintaxis TypeScript en theme.ts
- Sintaxis CSS en opticolor.css
- Paths relativos en imports

### 4.3 Dev mode y test visual:

```bash
npm run dev
# Ir a http://localhost:3000
# Settings/Preferences → Theme Preset
# Debe aparecer "⭐ OPTI-COLOR"
# Seleccionar y ver cambios colores
# Test: Light mode + Dark mode
```

### 4.4 Verificar localStorage:

Abrir DevTools Console:

```javascript
// Debe estar guardada la preferencia
localStorage.getItem('theme_preset')  // Output: "opticolor"
```

---

## 🎯 RESUMEN MAPEO COLORES

| Variable CSS | Color Hex | Uso |
|-------------|-----------|-----|
| `--primary` (light) | #0038E3 | Botones, links, headings |
| `--primary` (dark) | #378ADD | Botones en dark mode |
| `--secondary` (light) | #DC143C | Accents, badges |
| `--secondary` (dark) | #E74C3C | Accents dark mode |
| `--accent` | #0F3E68 | Highlights secundarios |
| `--destructive` | #DC143C | Botones peligrosos |
| `--chart-1 a 5` | Mix | Gráficos (5 series) |
| `--background` | #F5F5F5 | Fondo página |
| `--sidebar` | #F5F5F5 | Fondo sidebar |
| `--border` | #E0E0E0 | Bordes elementos |
| `--text` | #232323 | Texto principal |

---

## 🔄 FLUJO DE APLICACIÓN (interno)

1. Usuario selecciona "⭐ OPTI-COLOR" en Preferences
2. `ThemePreset` guardado en localStorage
3. `preferences-store` actualiza estado
4. `applyThemePreset("opticolor")` ejecutado
5. `data-theme-preset="opticolor"` set en `<html>`
6. CSS `:root[data-theme-preset="opticolor"]` aplicado
7. Todos los `var(--primary)`, `var(--secondary)`, etc. resuelven a colores OPTI-COLOR
8. Tailwind utiliza variables → colores aplicados a UI

---

## 📝 CHECKLIST FINAL

- [ ] Línea "⭐ OPTI-COLOR" agregada a `THEME_PRESET_OPTIONS`
- [ ] Archivo `opticolor.css` creado en `/src/styles/presets/`
- [ ] Import agregado en `globals.css`
- [ ] `npm run build` sin errores
- [ ] Tema visible en selector Preferences
- [ ] Colores aplicados correctamente (light + dark)
- [ ] localStorage guarda preferencia
- [ ] Temas existentes (Default, Brutalist, Soft Pop, Tangerine) intactos

---

## 🆘 TROUBLESHOOTING

| Problema | Solución |
|----------|----------|
| Tema no aparece en selector | Verificar sintaxis TypeScript en theme.ts |
| Colores no se aplican | Verificar import en globals.css, path a opticolor.css |
| Build falla | Revisar sintaxis CSS, verificar valores colores |
| Solo aplica partial | Verificar selectorores `:root[data-theme-preset="opticolor"]` |
| Dark mode roto | Verificar selectores `.dark:root[data-theme-preset="opticolor"]` |

---

**Tiempo estimado:** 5-10 minutos  
**Dificultad:** ⭐ Baja (copiar/pegar + crear 1 archivo)  
**Riesgo:** ⭐ Muy bajo (sin cambios a lógica, solo estilos)
