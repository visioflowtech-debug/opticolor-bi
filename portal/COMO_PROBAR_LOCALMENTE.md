# 🧪 CÓMO PROBAR EL PORTAL LOCALMENTE EN CHROME

**Objetivo:** Visualizar UX/UI del Portal Opticolor BI en navegador  
**Tiempo:** 5-10 minutos setup + exploración  
**Requisitos:** Node.js 18+, npm 9+, Chrome instalado

---

## PASO 1: VERIFICAR REQUISITOS

```bash
node --version      # Debe ser v18.17+ (ej: v20.11.0)
npm --version       # Debe ser 9+ (ej: 10.2.4)
```

Si no tienes Node.js, descarga desde: https://nodejs.org/ (versión LTS)

---

## PASO 2: INSTALAR DEPENDENCIAS (si no está hecho)

```bash
cd c:/opticolor-bi/portal
npm install
```

**Esperar:** ~2-3 minutos (instala 177 dependencias)

**Debe terminar con:**
```
added 177 packages in 2m
```

---

## PASO 3: CONFIGURAR .env.local

**Archivo:** `c:\opticolor-bi\portal\.env.local`

Debe tener (ya está preconfigurado, pero verifica):

```env
NEXTAUTH_SECRET=desarrollo-local-seguro-cambiar-produccion
NEXTAUTH_URL=http://localhost:3000

SQL_SERVER=srv-opticolor.database.windows.net
SQL_DATABASE=db-opticolor-dw
SQL_USER=admin_opticolor
SQL_PASSWORD=bS6RyEU33MsY8m@
```

**Nota:** Para testing LOCAL, usamos mock data. No necesita conexión real a BD.

---

## PASO 4: INICIAR SERVIDOR DESARROLLO

```bash
npm run dev
```

**Output esperado:**
```
> next dev

  ▲ Next.js 16.2.4
  - Local:        http://localhost:3000
  - Environments: .env.local

✓ Ready in 2.5s
```

**Si ves errores:**
- `Port 3000 already in use` → Cierra otra aplicación en ese puerto
- `Module not found` → Ejecuta `npm install` nuevamente

---

## PASO 5: ABRIR EN CHROME

1. **Abre Chrome** (o Edge, Firefox, Safari — cualquier navegador moderno)
2. **Navega a:** `http://localhost:3000`
3. **Verás:** Login page de Opticolor BI

---

## 🔑 CREDENCIALES TESTING

Para testing LOCAL, el portal usa **mock authentication**. Puedes usar:

```
Email:    cualquier@email.com
Password: cualquier-contraseña
```

**Nota:** Estos datos solo funcionan localmente (mock). En Semana 2.2, cuando conectemos BD real, validaremos contra `Seguridad_Usuarios`.

---

## 🎨 EXPLORACIÓN UX/UI

### PÁGINA 1: Login
- **URL:** http://localhost:3000/auth/login
- **Elementos:**
  - Logo Opticolor (azul)
  - Formulario email + password
  - Botón "Iniciar Sesión"
  - Paleta corporativa: azul primario #1A3A6B
- **Acciones:** Ingresa cualquier email/password → Redirige a /dashboard

### PÁGINA 2: Dashboard Principal (Resumen Comercial)
- **URL:** http://localhost:3000/dashboard
- **Layout:**
  - **Navbar (arriba):** Logo + "Opticolor BI" + Usuario + Botón Salir
  - **Sidebar (izquierda):** 5 links a informes
  - **Content (centro):** Resumen Comercial con:
    - Título: "📊 Resumen Comercial"
    - 5 KPI cards: Venta Total, Cobrado, Ticket Promedio, Run Rate, OTIF
    - Gráfico LineChart (Recharts) con datos 7 días
    - Responsivo: se adapta a cualquier pantalla

### PÁGINA 3-5: Otros Dashboards (Esqueletos)
- **URLs:**
  - http://localhost:3000/dashboard/eficiencia-ordenes
  - http://localhost:3000/dashboard/control-cartera
  - http://localhost:3000/dashboard/desempenio-clinico
  - http://localhost:3000/dashboard/inventario
- **Estado:** Esqueletos con placeholder text (mock data)
- **Próximos:** Se llenarán con componentes en Semana 2.2

---

## 🎬 ESCENARIOS TESTING

### Escenario 1: Testing Responsivo
**Probar que funciona en diferentes tamaños:**

1. En Chrome, presiona `F12` (DevTools)
2. Click en icono "Toggle device toolbar" (esquina arriba-izq)
3. Prueba tamaños:
   - **Desktop:** 1920x1080
   - **Tablet:** 768x1024
   - **Mobile:** 375x667

**Verificar:**
- ✅ Navbar se ajusta
- ✅ Sidebar se colapsa (o desaparece en mobile)
- ✅ Content legible en todos los tamaños
- ✅ Gráficos responsive

### Escenario 2: Testing Tema Colores
**Verificar paleta Opticolor:**

1. Abre Inspector (F12)
2. Ve a tab "Computed Styles" en cualquier elemento
3. Busca colores:
   - **Primario:** #1A3A6B (azul oscuro)
   - **Secundario:** #2B6CB0 (azul medio)
   - **Accent:** #D4A017 (dorado)

**Elementos que deben ser azul #1A3A6B:**
- Logo en Navbar
- Botón "Iniciar Sesión"
- Links activos en Sidebar

### Escenario 3: Testing Navegación
**Verificar que links funcionan:**

1. En Sidebar, click "📊 Resumen Comercial" → Debe ir a `/dashboard`
2. Click "⚙️ Eficiencia de Órdenes" → Debe ir a `/dashboard/eficiencia-ordenes`
3. Click "💰 Control de Cartera" → Debe ir a `/dashboard/control-cartera`
4. Click "🏥 Desempeño Clínico" → Debe ir a `/dashboard/desempenio-clinico`
5. Click "📦 Inventario" → Debe ir a `/dashboard/inventario`

**Verificar:**
- ✅ URL cambia
- ✅ Sidebar destaca la página activa
- ✅ No hay errores en consola (F12 → Console)

### Escenario 4: Testing Interactividad
**Probar elementos interactivos:**

1. **Hover en KPI cards:** Debe cambiar sombra/color
2. **Hover en botones:** Cambio de color
3. **Click botón "Salir":** Redirige a login
4. **Volver a login, click "Iniciar":** Redirige a dashboard

**Verificar:**
- ✅ Transiciones suaves
- ✅ Feedback visual claro
- ✅ No hay lags/freezes

### Escenario 5: Testing Gráfico Recharts
**Verificar gráfico en Resumen Comercial:**

1. Ve a http://localhost:3000/dashboard
2. Desplázate hasta el gráfico LineChart
3. Hover en líneas:
   - **Azul:** Venta Total
   - **Azul claro:** Cobrado
   - **Dorado:** OTIF
4. Verifica que tooltip muestra valores

**Verificar:**
- ✅ 3 líneas visibles
- ✅ Tooltip muestra datos
- ✅ Eje X: fechas (7 días)
- ✅ Eje Y: valores numéricos
- ✅ Leyenda: 3 items

---

## 🐛 TESTING ERRORES

### Si ves blanco/vacío:
```bash
# Verifica servidor corre
npm run dev

# Si error, limpia cache y reinstala
rm -rf .next node_modules
npm install
npm run dev
```

### Si ves error "Module not found":
```bash
npm install
npm run dev
```

### Si puerto 3000 ya está en uso:
```bash
# Mata proceso en puerto 3000
lsof -i :3000  # Mac/Linux
netstat -ano | findstr :3000  # Windows

# Usa puerto diferente
npm run dev -- -p 3001
# Abre: http://localhost:3001
```

### Si CSS no carga (todo se ve feo):
```bash
# Reconstruye Tailwind
npm run build
npm run dev
```

---

## 📸 SCREENSHOTS / SNAPSHOTS

Para capturar cómo se ve:

1. **Login Page:**
   - Presiona `F12` → Devices Toggle → Desktop
   - Presiona `Ctrl+Shift+P` → "Capture screenshot"

2. **Dashboard:**
   - Presiona `Ctrl+Shift+P` → "Capture screenshot"

3. **Mobile View:**
   - Devices Toggle → iPhone 12
   - Presiona `Ctrl+Shift+P` → "Capture screenshot"

---

## 🔗 REFERENCIAS

**Fuente de Verdad Arquitectónica:**
- https://github.com/arhamkhnz/next-shadcn-admin-dashboard
- Estamos usando su estructura como base, personalizando para Opticolor

**Stack Usado:**
- Next.js 16.2.4: https://nextjs.org/docs
- shadcn/ui: https://ui.shadcn.com/
- Tailwind CSS v4: https://tailwindcss.com/
- Recharts: https://recharts.org/

---

## ✅ CHECKLIST TESTING RÁPIDO

- [ ] Node.js 18+ instalado
- [ ] `npm install` ejecutado sin errores
- [ ] `.env.local` configurado
- [ ] `npm run dev` corre sin errores
- [ ] http://localhost:3000 abre en Chrome
- [ ] Login page muestra (azul Opticolor)
- [ ] Puedo logearme (cualquier email/password)
- [ ] Dashboard carga (Resumen Comercial con gráfico)
- [ ] Sidebar navigation funciona (5 links)
- [ ] Responsivo en mobile (F12 → Toggle device)
- [ ] Colores correctos (primario #1A3A6B)
- [ ] Sin errores en Console (F12 → Console)

---

## 🎯 PRÓXIMA FASE (SEMANA 2.2)

Cuando llegue **Excel de Reinaldo** con usuarios reales:

1. Cargar usuarios en `Seguridad_Usuarios` (BD)
2. Reemplazar mock auth con BD real
3. Conectar endpoints a SQL (reemplazar mockData)
4. Testing con usuarios reales por rol

Por ahora, **testing con mock es suficiente** para validar UX/UI.

---

**Happy Testing! 🚀**

Co-Authored-By: Claude Code Portal Controller
