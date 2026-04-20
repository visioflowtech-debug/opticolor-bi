# 📋 Solicitud Formal: Datos Requeridos — Semana 2

**Enviado:** 17 de abril de 2026  
**Destinatario:** Eduardo Martínez, Reinaldo José Rangel (Opticolor)  
**De:** Gerardo Argueta (VisioFlow)  
**Urgencia:** CRÍTICA — Sin estos datos, Semana 2 se bloquea

---

## Resumen Ejecutivo

La fundación técnica del proyecto Opticolor BI está **100% completada:**
- ✅ Azure SQL Database compilada (31 tablas)
- ✅ RBAC/RLS structure implementado (7 roles)
- ✅ Contexto permanente documentado (claude.md + agentes)
- ✅ Usuario SUPER_ADMIN creado (Gerardo)

**Para iniciar Semana 2 sin bloqueos**, necesitamos que proporcionen:

---

## 📌 Datos CRÍTICOS (Requeridos HOY)

### 1. **Logo Opticolor PNG**
- **Formato:** PNG con fondo transparente
- **Tamaño:** Mínimo 500x500px
- **Uso:** Portal Next.js header + Power BI branding
- **Entrega en:** Carpeta `/docs/assets/logo/`
- **Fallback:** Si no disponen, copiaré estilo visual de https://www.opticolor.com.ve/

**Archivo esperado:** `opticolor-logo.png`

---

### 2. **Paleta de Colores Corporativos**
- **Formato:** Código hex (mínimo 3 colores)
  - Primario: `#____` (ej: azul corporativo)
  - Secundario: `#____` (ej: acento)
  - Neutral: `#____` (ej: gris claro/oscuro)

- **Ejemplos esperados:**
  ```
  Primario: #1B3FA8 (azul óptico)
  Secundario: #FF6B35 (naranja)
  Neutral: #F5F5F5 (gris claro)
  ```

- **Uso:** Tailwind CSS config, gráficos Power BI
- **Fallback:** Usar colores estándar sector óptico (azul + blanco + gris)

**Archivo esperado:** `docs/GUIA_COLORES_OPTICOLOR.txt`

---

### 3. **Credenciales API Gesvision**
- **Usuario API:** ___________
- **Contraseña API:** ___________
- **URL Base:** (confirmar si es `https://app.gesvision.com/gesmo/rest/api`)

- **Uso:** Validar endpoints ETL (módulos de sync)
- **Seguridad:** Se guardará en `local.settings.json` (no en GitHub)

**Formato esperado:**
```json
{
  "GESVISION_USER": "...",
  "GESVISION_PASS": "...",
  "GESVISION_BASE_URL": "https://app.gesvision.com/gesmo/rest/api"
}
```

---

## 📌 Datos IMPORTANTES (Requeridos antes del Viernes 22 abril)

### 4. **Lista de Usuarios Operacionales Iniciales**

Formato CSV o tabla con columnas:

| Nombre Completo | Email | Rol | Sucursal(es) Asignadas |
|---|---|---|---|
| Eduardo Martínez | eduardo@opticolor.com | ADMIN | Nacional (todas) |
| Juan Pérez Gómez | juan.perez@opticolor.com | SUPERVISOR | Caracas, Los Teques |
| María López Díaz | maria.lopez@opticolor.com | CONSULTOR | Caracas Centro |
| ... | ... | ... | ... |

**Roles disponibles:**
- `SUPER_ADMIN` — Acceso total (Gerardo/VisioFlow)
- `ADMIN` — Todos los informes + gestión usuarios (Eduardo)
- `GERENTE_ZONA` — Zona geográfica asignada
- `SUPERVISOR` — Sucursal(es) asignada(s)
- `CONSULTOR` — Solo lectura, sucursal(es) asignada(s)

**Mínimo requerido:** Eduardo ADMIN + 2-3 usuarios de prueba

---

### 5. **Estructura de Zonas/Regiones Geográficas**

Describir cómo están organizadas las sucursales:

**Opción A (si están agrupadas por región):**
```
Zona Centro: Caracas, Miranda, Vargas
Zona Occidente: Zulia, Falcón, Lara, Yaracuy
Zona Andes: Mérida, Táchira, Trujillo
Zona Oriente: Sucre, Anzoátegui, Monagas
Zona Centro-Sur: Cojedes, Portuguesa, Barinas, Guárico, Apure
```

**Opción B (si es plana por sucursal):**
```
Sucursal | Ciudad | Estado | Municipio | Zona/Región
Opticolor Caracas | Caracas | Distrito Capital | Libertador | Centro
Opticolor Los Teques | Los Teques | Miranda | Los Teques | Centro
...
```

**Uso:**
- Filtros Portal (slicer "Zona" en informes)
- Reportes consolidados por región
- Asignación GERENTE_ZONA a usuarios

---

### 6. **Sucursales Activas — Lista Completa**

Tabla con todas las sucursales operacionales:

| Nombre Sucursal | Ciudad | Estado | Municipio | Dirección | Teléfono | Email | Zona |
|---|---|---|---|---|---|---|---|
| Opticolor Caracas Centro | Caracas | Distrito Capital | Libertador | Calle X, Piso Y | +58... | caracas@opticolor.com | Centro |
| Opticolor Los Teques | Los Teques | Miranda | Los Teques | Av. Z | +58... | loteques@opticolor.com | Centro |
| Opticolor Valencia | Valencia | Carabobo | Valencia | Calle A | +58... | valencia@opticolor.com | Occidente |
| ... | ... | ... | ... | ... | ... | ... | ... |

**Nota importante:** Ya tenemos datos geográficos de Venezuela (24 estados, 256 municipios) en la BD. Esta lista es para validar sucursales vs geografía.

---

## 📌 Datos SECUNDARIOS (Requeridos antes del Viernes 24 abril)

### 7. **Catálogos Maestros Actuales**

**A. Marcas (Maestro_Marcas)**
```
Código | Nombre | Segmento | Activo
LUX01 | Ray-Ban | Luxury | Sí
LUX02 | Gucci | Luxury | Sí
INT01 | Marca Importada X | Intermedias | Sí
BD01 | Be Diferent | Be Diferent | Sí
CON01 | Lentes de Contacto | Contactos | Sí
...
```

**B. Categorías (Maestro_Categorias)**
```
Luxury / Intermedias / Be Diferent / Contactos
```

**C. Productos (Maestro_Productos)** — Si disponen exportar de Gesvision:
```
SKU | Nombre | Marca | Categoría | Precio_Costo | Precio_Venta | Stock_Actual
...
```

**Nota:** Si no tienen fácil acceso, podemos extraerlo de Gesvision API con las credenciales.

---

### 8. **Feedback Vistas BI Adaptadas** (Opcional Semana 2, crítico Semana 3)

Una vez adaptemos las vistas de Optilux Panama a Venezuela:
- ¿Las fórmulas de cálculo son correctas?
- ¿Los campos son los que esperan en Power BI?
- ¿Hay datos que falten (ej: comisiones, devoluciones)?

Esto lo haremos colaborativamente durante testing.

---

## 📅 Timeline de Entregas

| Fecha | Dato | Responsable |
|-------|------|-------------|
| **HOY (17 abril)** | Logo + Colores + Credenciales Gesvision | Opticolor (CRÍTICO) |
| **Viernes 22 abril** | Usuarios operacionales + Zonas + Sucursales | Opticolor |
| **Viernes 24 abril** | Catálogos maestros (Marcas/Categorías/Productos) | Opticolor |
| **Lunes 28 abril** | Feedback vistas BI | Opticolor |

---

## 📦 Cómo Entregar

### Opción 1: Email
```
Para: visioflow.tech@gmail.com
Asunto: [Opticolor] Datos Semana 2 — Logo, Colores, Usuarios, Credenciales
Adjuntos:
  - opticolor-logo.png
  - GUIA_COLORES_OPTICOLOR.txt
  - USUARIOS_OPERACIONALES.csv
  - SUCURSALES_ACTIVAS.csv
  - CATÁLOGOS_MAESTROS.xlsx
  - ESTRUCTURA_ZONAS.txt
  - CREDENCIALES_GESVISION.txt (encriptado o al teléfono)
```

### Opción 2: Compartir con VisioFlow en Google Drive
```
Link: [Crear carpeta compartida]
Archivos: Mismos que arriba
```

### Opción 3: Actualizar Notion Tracker
```
https://spiky-troodon-8c7.notion.site/...
Crear tabla con datos
```

---

## ✅ Checklist Confirmación

Por favor confirmar en WhatsApp o email que:

- [ ] Logo PNG será enviado hoy/mañana
- [ ] Colores corporativos definidos (o autorización copiar web)
- [ ] Credenciales Gesvision disponibles
- [ ] Email Eduardo confirmado (para usuario ADMIN)
- [ ] Sucursales activas documentadas
- [ ] Usuarios operacionales iniciales identificados

---

## 🎯 Impacto sin estos datos

| Dato | Impacto sin entregar |
|------|---------------------|
| Logo + Colores | Portal sin branding, Power BI sin identidad |
| Credenciales Gesvision | ETL offline, sin testeo real |
| Usuarios operacionales | No se puede validar RBAC/RLS |
| Sucursales | Filtros Portal incompletos |
| Catálogos maestros | Vistas BI vacías |

**Estimación:** Sin estos datos, Semana 2 avanza al **30-40%** en lugar de 100%.

---

## 📞 Contacto

**Para preguntas/dudas:**
- Email: visioflow.tech@gmail.com
- WhatsApp: [Gerardo]
- Teléfono: [Incluir si aplica]

---

**Preparado por:** Gerardo Argueta (VisioFlow)  
**Fecha:** 17 de abril de 2026  
**Referencia:** Proyecto Opticolor BI Venezuela — Semana 2
