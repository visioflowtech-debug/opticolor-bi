# 🎨 GUIDE: CÓMO PROBAR EL PORTAL Y VER UX/UI EN CHROME

**Duración:** 5-10 minutos  
**Objetivo:** Visualizar el Portal Opticolor en navegador y entender su UI/UX  
**Fuente Base:** https://github.com/arhamkhnz/next-shadcn-admin-dashboard

---

## 🚀 INICIO RÁPIDO (3 pasos)

### Paso 1: Abrir Terminal

```bash
# Windows (PowerShell o CMD)
cd c:\opticolor-bi\portal

# macOS/Linux
cd /path/to/opticolor-bi/portal
```

### Paso 2: Instalar & Ejecutar

```bash
# Instalar dependencias (ya hecho, pero verifica)
npm install

# Iniciar servidor development
npm run dev
```

**Debe ver:**
```
✓ Ready in 2.5s
  - Local: http://localhost:3000
```

### Paso 3: Abrir en Chrome

1. **Abre Chrome** (o Edge/Firefox/Safari)
2. **Navega a:** `http://localhost:3000`
3. **Verás:** Login page azul Opticolor

---

## 🎯 PANTALLAS A EXPLORAR

### PANTALLA 1: Login
**URL:** http://localhost:3000/auth/login

```
┌─────────────────────────────────────┐
│                                     │
│         📊 OPTICOLOR BI             │
│   Portal de Inteligencia de Datos   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ Email                       │   │
│  │ tu@email.com                │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │ Contraseña                  │   │
│  │ ••••••••                    │   │
│  └─────────────────────────────┘   │
│                                     │
│  ┌─────────────────────────────┐   │
│  │   INICIAR SESIÓN            │   │
│  └─────────────────────────────┘   │
│                                     │
│  Credentials para testing: cualquier│
│  email/password (mock)              │
│                                     │
└─────────────────────────────────────┘
```

**Acciones:**
1. Ingresa: `test@opticolor.com`
2. Contraseña: `test123` (cualquier cosa funciona)
3. Click "INICIAR SESIÓN"
4. **Resultado:** Redirige a `/dashboard`

**Elementos a notar:**
- ✅ Logo azul (#1A3A6B)
- ✅ Paleta corporativa
- ✅ Formulario limpio y profesional
- ✅ Botón con hover effect

---

### PANTALLA 2: Dashboard Principal
**URL:** http://localhost:3000/dashboard

```
┌─────────────────────────────────────────────────────────────────────┐
│ 📊 OPTICOLOR BI              Usuario: test@opticolor.com    [SALIR] │
├────────────────┬─────────────────────────────────────────────────────┤
│                │                                                       │
│ 📊 Resumen     │  📊 RESUMEN COMERCIAL                               │
│ Comercial      │  Vista general de ventas, cobranzas y eficiencia    │
│                │                                                       │
│ ⚙️ Eficiencia  │  ┌──────────┐ ┌──────────┐ ┌──────────┐            │
│ de Órdenes     │  │ Venta    │ │ Cobrado  │ │ Ticket   │            │
│                │  │ Total    │ │          │ │ Promedio │            │
│ 💰 Control     │  │ $142,000 │ │ $125,000 │ │ $920     │            │
│ de Cartera     │  └──────────┘ └──────────┘ └──────────┘            │
│                │                                                       │
│ 🏥 Desempeño   │  ┌──────────┐ ┌──────────┐                         │
│ Clínico        │  │ Run Rate │ │ OTIF     │                         │
│                │  │ 99.5%    │ │ 98.1%    │                         │
│ 📦 Inventario  │  └──────────┘ └──────────┘                         │
│                │                                                       │
│                │  TENDENCIA 7 DÍAS                                   │
│                │  ┌──────────────────────────────────────────────┐  │
│                │  │                                              │  │
│                │  │    /\                  /\                   │  │
│                │  │   /  \    ________    /  \    _____         │  │
│                │  │  /    \  /        \  /    \  /     \        │  │
│                │  │ /      \/          \/      \/       \       │  │
│                │  │                                      \      │  │
│                │  │  ─ Venta Total  ─ Cobrado  ─ OTIF    │  │
│                │  └──────────────────────────────────────────────┘  │
│                │                                                       │
└────────────────┴─────────────────────────────────────────────────────┘
```

**Elementos:**

1. **Navbar (arriba):**
   - Logo azul + "OPTICOLOR BI" (izquierda)
   - Usuario actual + botón SALIR (derecha)

2. **Sidebar (izquierda):**
   - 5 links a dashboards
   - Link activo resaltado
   - Colores azul/gris

3. **Content Area:**
   - Título + descripción
   - 5 KPI cards (números grandes)
   - Gráfico LineChart con 7 días de datos

**Interactividad:**
- Hover en KPI cards → Sombra/color cambia
- Hover en líneas gráfico → Tooltip muestra valores
- Click en links Sidebar → Cambia página
- Click SALIR → Vuelve a login

---

### PANTALLA 3: Otros Dashboards (Esqueletos)
**URLs:**
- http://localhost:3000/dashboard/eficiencia-ordenes
- http://localhost:3000/dashboard/control-cartera
- http://localhost:3000/dashboard/desempenio-clinico
- http://localhost:3000/dashboard/inventario

**Estado:** Aún son esqueletos (placeholders)

**Lo que ves:**
- Mismo layout (Navbar + Sidebar)
- Título del dashboard
- Placeholder text
- Mock data

**Lo que viene (Semana 2.2):**
- Componentes propios con gráficos específicos
- Datos conectados a SQL real

---

## 🎨 TESTING RESPONSIVO

### En Chrome DevTools

**Presiona:** `F12` (abre DevTools)

**Busca icono:** "Toggle device toolbar" (esquina arriba-izquierda)

**O atajos:**
- Windows: `Ctrl+Shift+M`
- Mac: `Cmd+Shift+M`

**Tamaños a probar:**

#### Desktop (1920x1080)
```
Vista normal → Sidebar visible, content amplio
```

#### Tablet (768x1024)
```
Sidebar reduce o colapsa → Content se expande
```

#### Mobile (375x667)
```
Sidebar desaparece (hamburger menu?)
Content ocupa pantalla completa
Scroll vertical para ver todo
Botones más grandes para touch
```

**Verificar:**
- ✅ Legible en todos los tamaños
- ✅ No hay text cutoff
- ✅ Gráficos se adaptan
- ✅ Botones clickables

---

## 🌈 TESTING PALETA COLORES

### Presiona `F12` → Inspector

1. Busca elemento azul (ej: navbar)
2. Right-click → "Inspect"
3. Tab "Computed" → busca `background-color`

**Colores esperados:**

| Elemento | Color Hex | RGB |
|----------|-----------|-----|
| Navbar/Logo | #1A3A6B | 26, 58, 107 |
| Botones | #1A3A6B | (azul primario) |
| Links activos | #2B6CB0 | (azul secundario) |
| Accents | #D4A017 | (dorado) |

---

## 🔄 TESTING INTERACTIVIDAD

### Test 1: Navegación
```
1. Click "⚙️ Eficiencia de Órdenes"
   → URL cambia a /dashboard/eficiencia-ordenes
   → Sidebar destaca nuevo item
   
2. Click "💰 Control de Cartera"
   → URL cambia a /dashboard/control-cartera
   
3. Click "📊 Resumen Comercial"
   → Vuelve a /dashboard
```

### Test 2: Logout
```
1. En Navbar, top-right, click "SALIR"
2. Redirige a /auth/login
3. Puedes logearme nuevamente
```

### Test 3: Gráfico Interactivo
```
1. En Resumen Comercial, ve al gráfico
2. Hover en líneas → Tooltip muestra valores
3. Verifica:
   - 3 líneas (Venta, Cobrado, OTIF)
   - Colores diferenciados
   - Eje X: fechas
   - Eje Y: valores numéricos
```

### Test 4: KPI Cards
```
1. Hover en cualquier KPI card
   → Sombra cambia/colores
2. Verifica 5 cards:
   - Venta Total
   - Cobrado
   - Ticket Promedio
   - Run Rate
   - OTIF
```

---

## 🎬 ESCENARIOS COMPLETOS

### Escenario A: Usuario nuevo explora portal
```
1. Abre http://localhost:3000
2. Ve login page → "¿Bonito?"
3. Click "Iniciar" → Dashboard
4. Click en cada sidebar link (5 dashboards)
5. Verifica gráfico, KPIs, responsive
```

### Escenario B: Testing responsivo
```
1. npm run dev
2. F12 → Toggle device
3. Prueba: 1920x1080 → 768x1024 → 375x667
4. Verifica legibilidad en cada tamaño
```

### Escenario C: Testing colores
```
1. Inspector (F12)
2. Busca: #1A3A6B (debe existir)
3. Busca: #2B6CB0 (debe existir)
4. Busca: #D4A017 (debe existir)
5. Navega por site, verifica paleta
```

---

## ⚠️ TROUBLESHOOTING

### Pantalla blanca/vacía
```bash
# Asegúrate que servidor está corriendo
npm run dev

# Si error, limpia y reinstala
rm -rf .next
npm install
npm run dev
```

### Puerto 3000 ocupado
```bash
# Usa puerto diferente
npm run dev -- -p 3001
# Abre: http://localhost:3001
```

### CSS no carga (todo feo)
```bash
# Reconstruye Tailwind
npm run build
npm run dev
```

### "Module not found"
```bash
# Reinstala dependencias
npm install
npm run dev
```

---

## 📸 CAPTURAR SCREENSHOTS

**Para documentar cómo se ve:**

1. **Login page:**
   - F12 → Toggle device → Desktop
   - Ctrl+Shift+P → "Capture screenshot"

2. **Dashboard:**
   - F12 → Toggle device → iPhone 12
   - Ctrl+Shift+P → "Capture screenshot"

3. **Gráfico:**
   - Scroll a gráfico
   - Ctrl+Shift+P → "Capture screenshot"

---

## ✅ CHECKLIST RÁPIDO

- [ ] Node.js 18+ instalado (`node --version`)
- [ ] npm 9+ instalado (`npm --version`)
- [ ] `npm install` sin errores
- [ ] `.env.local` existe
- [ ] `npm run dev` corre sin errores
- [ ] http://localhost:3000 abre en Chrome
- [ ] Login page muestra (azul #1A3A6B)
- [ ] Puedo logearme (cualquier email/password)
- [ ] Dashboard carga (título + KPIs + gráfico)
- [ ] Sidebar links funcionan (5 click = 5 URLs)
- [ ] Responsive: mobile se adapta
- [ ] Sin errores en Console (F12 → Console)
- [ ] Gráfico tiene 3 líneas
- [ ] Paleta Opticolor visible

---

## 🎯 QUÉ NOTAR (UX/UI DESTACADOS)

1. **Color:** Azul corporativo (#1A3A6B) domina
2. **Tipografía:** Limpia, profesional, legible
3. **Spacing:** Generoso, respira bien
4. **Gráficos:** Recharts limpio con 3 líneas de datos
5. **Responsivo:** Se adapta a mobile sin perder contenido
6. **Navegación:** Clara con Sidebar + Links activos resaltados
7. **Feedback:** Hover effects en botones/cards
8. **Estructura:** Navbar + Sidebar + Content (layout profesional)

---

## 🔗 REFERENCIAS

**Template Base:**
- https://github.com/arhamkhnz/next-shadcn-admin-dashboard

**Stack:**
- Next.js 16: https://nextjs.org/docs/getting-started
- Tailwind CSS v4: https://tailwindcss.com/docs
- Recharts: https://recharts.org/guide/installation
- shadcn/ui: https://ui.shadcn.com/ (si hay componentes)

---

**Happy Testing! 🚀**

Co-Authored-By: Claude Code
