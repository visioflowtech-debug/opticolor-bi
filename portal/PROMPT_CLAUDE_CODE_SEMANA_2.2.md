# 🤖 PROMPT ESPECIALIZADO PARA CLAUDE CODE — SEMANA 2.2

**Fecha:** 24 abril 2026 (Lunes, Semana 2.2)  
**Herramienta:** Claude Code  
**Contexto:** Portal Next.js ya existe, necesita conectar a datos reales + crear vistas SQL

---

## 📋 INSTRUCCIÓN INICIAL (Copiar y Pegar en Claude Code)

```
Soy Gerardo Argueta (@visioflow.tech). Continúo Opticolor BI Venezuela Semana 2.2.

Portal Next.js 16 ya existe en /portal/ (Semana 2 completado).

HOY necesito:
1. Cargar usuarios reales en Azure SQL (desde Excel de Reinaldo)
2. Conectar 5 endpoints API a queries SQL reales (reemplazar mock data)
3. Crear vistas SQL para BI (copiar Panamá + adaptar)
4. Testing: login con roles + verificar RLS

CONTEXTO CRÍTICO:
- Repo: https://github.com/visioflowtech/opticolor-bi (privado)
- BD: Azure SQL srv-opticolor.database.windows.net / db-opticolor-dw
- 31 tablas existentes (23 base + 8 seguridad)
- 7 roles RBAC: SUPER_ADMIN → PORTAL_SERVICE
- RLS: Vw_RLS_Sucursales filtra por email usuario
- Referencia: Optilux Panama (mismo schema v2.0)

PROYECTO_OPTICOLOR.pdf = tracker semanal (lee primero)
claude.md = contexto permanente (7 roles, 18 módulos ETL, etc.)

¿Listo?
```

---

## 🎯 TAREA 1: CARGAR USUARIOS DESDE EXCEL

### Input esperado:
Archivo `usuarios_semana2.xlsx` con columnas:
```
| email | nombre_completo | rol | sucursales_ids |
|-------|-----------------|-----|-----------------|
| emartinez@grupoopticolor.com | Eduardo Martínez | ADMIN | 1,2,3 |
| supervisor1@... | Supervisor Caracas | SUPERVISOR | 1 |
...
```

### Tu tarea:
1. **Lee el Excel** → extrae datos
2. **Genera script SQL** que:
   - `INSERT INTO Seguridad_Usuarios` con password_hash PBKDF2
   - `INSERT INTO Seguridad_Usuarios_Roles`
   - `INSERT INTO Seguridad_Usuarios_Sucursales`
3. **Ejecuta en Azure SQL** (o dame el script para que Reinaldo lo ejecute)
4. **Verifica:** Login funciona con usuario real

### Script Python helper (opcional):
```python
# generate_user_hashes.py
import hashlib
import os
import binascii

def generate_pbkdf2_hash(password, iterations=100000, hash_name='sha256'):
    salt = os.urandom(32)
    pwd_hash = hashlib.pbkdf2_hmac(
        hash_name,
        password.encode('utf-8'),
        salt,
        iterations
    )
    return f"{binascii.hexlify(salt).decode()}${binascii.hexlify(pwd_hash).decode()}"

# Uso:
hash = generate_pbkdf2_hash("contraseña_usuario")
print(hash)
```

---

## 🎯 TAREA 2: CONECTAR APIs A SQL REAL

### Ubicación archivos:
```
/portal/app/api/data/
├── resumen-comercial/route.ts       ← REEMPLAZAR MOCK
├── eficiencia-ordenes/route.ts      ← REEMPLAZAR MOCK
├── control-cartera/route.ts         ← REEMPLAZAR MOCK
├── desempenio-clinico/route.ts      ← REEMPLAZAR MOCK
└── inventario/route.ts              ← REEMPLAZAR MOCK
```

### Patrón a seguir:

**ANTES (mock):**
```typescript
const mockData = [...];
return NextResponse.json({ success: true, data: mockData });
```

**DESPUÉS (SQL real):**
```typescript
const { query } = require('@/lib/db');

export async function GET(request: NextRequest) {
  const session = await auth();
  if (!session?.user) return NextResponse.json({ error: 'Not auth' }, { status: 401 });
  
  // DESCOMENTAR Y ADAPTAR:
  const data = await query(`
    SELECT
      CAST(DATEADD(HOUR, -5, fecha_utc) AS DATE) AS fecha,
      SUM(monto_total) AS venta_total,
      ...
    FROM [dbo].[Fact_Ventas]
    WHERE id_sucursal IN (
      SELECT id_sucursal FROM [dbo].[Vw_RLS_Sucursales] 
      WHERE email = @email
    )
    GROUP BY CAST(DATEADD(HOUR, -5, fecha_utc) AS DATE)
    ORDER BY fecha DESC
  `, { email: session.user.email });
  
  return NextResponse.json({ success: true, data });
}
```

### Queries base (ya tienen comentarios con REEMPLAZAR):
- `/portal/app/api/data/resumen-comercial/route.ts` línea 50
- `/portal/app/api/data/eficiencia-ordenes/route.ts` línea 35
- `/portal/app/api/data/control-cartera/route.ts` línea 35
- `/portal/app/api/data/desempenio-clinico/route.ts` línea 35
- `/portal/app/api/data/inventario/route.ts` línea 35

---

## 🎯 TAREA 3: CREAR VISTAS SQL

### Referencia:
- **Fuente:** `Documento_Técnico_y_Funcional_de_Base_de_Datos_ver_2_0.pdf` (Optilux Panamá)
- **Adapt para:** Venezuela (cambiar tablas, índices, cálculos)
- **Ubicación script:** `/sql/vistas_operacionales_venezuela.sql` (nuevo)

### Vistas prioritarias:

**1. Dim_Sucursales (maestro)**
```sql
CREATE VIEW [dbo].[Dim_Sucursales] AS
SELECT
  id_sucursal,
  nombre_sucursal,
  alias_sucursal,
  municipio_raw,
  -- JOIN con Param_Venezuela_Municipios para normalizar
FROM [dbo].[Maestro_Sucursales]
WHERE esta_activo = 1
```

**2. Fact_Ventas (transaccional)**
```sql
-- Debe:
-- - Sumar monto_total, monto_cobrado por fecha/sucursal
-- - Calcular ticket promedio, run_rate, OTIF
-- - Aplicar RLS: filtrar por id_sucursal
-- - Timestamp GMT-5
```

**3. Fact_Ordenes, Fact_Cartera, Fact_Clinica, Fact_Inventario**
- Mismo patrón que Fact_Ventas
- Copiar lógica Panamá + adaptar columnas

### Validación:
```sql
-- Verificar vistas creadas:
SELECT TABLE_NAME, TABLE_TYPE 
FROM INFORMATION_SCHEMA.TABLES 
WHERE TABLE_TYPE = 'VIEW' 
  AND TABLE_NAME LIKE 'Fact_%' OR TABLE_NAME LIKE 'Dim_%'
```

---

## 🎯 TAREA 4: TESTING RLS + ROLES

### Test 1: Login por rol
```
Abrir http://localhost:3000/auth/login
Loguear como:
  - SUPER_ADMIN (ve todo)
  - GERENTE_ZONA (ve su región)
  - SUPERVISOR (ve su sucursal)
Verificar sidebar muestra sucursales correctas
```

### Test 2: RLS en dashboards
```
Usuario SUPERVISOR asignado a sucursal #1
→ /dashboard debería mostrar SOLO datos sucursal #1
→ /api/data/resumen-comercial devuelve SOLO sucursal #1
```

### Test 3: Gráficos
```
Abrir /dashboard/resumen-comercial
Verificar:
  - Venta vs Cobrado (Area chart) llena con datos reales
  - Run Rate & OTIF (Line chart) llena
  - Tabla detalle tiene 7+ filas (últimos 7 días)
```

### Script testing (opcional):
```bash
# Verificar API endpoint con curl:
curl -H "Cookie: next-auth.session-token=YOUR_JWT" \
  http://localhost:3000/api/data/resumen-comercial | jq

# Verificar RLS (debe retornar SOLO sucursales del usuario):
curl -H "Cookie: ..." \
  http://localhost:3000/api/data/resumen-comercial | jq '.data | map(.sucursal) | unique'
```

---

## 📦 ARCHIVOS A CREAR/EDITAR

### Crear:
- `sql/vistas_operacionales_venezuela.sql` (500+ líneas)
- `scripts/generate_user_hashes.py` (helper)
- `docs/TESTING_RLS.md` (guía testing)

### Editar:
- `/portal/app/api/data/*.ts` (5 archivos) — descomentar SQL
- `/config/auth.ts` (opcional) — mejorar error handling
- `.env.local` (si no existe ya)

### No tocar:
- `/components/*` (UI está lista)
- `/lib/db.ts` (pool está ok)
- `tailwind.config.ts` (paleta lista)

---

## 🎯 ENTREGABLES ESPERADOS

**Semana 2.2 — FIN DE DÍA (viernes 26 abril):**

✅ Usuarios reales cargados en BD  
✅ Endpoints API conectados a SQL (no mock data)  
✅ 5 Vistas operacionales creadas  
✅ Testing RLS verificado  
✅ Dashboards muestran datos reales  
✅ Git commit con mensaje: "Semana 2.2: Connect live data + SQL views + RLS testing"

**Blockers conocidos:**
- ❓ Credenciales Azure SQL ← Reinaldo debe confirmar
- ❓ Usuarios Excel ← Reinaldo debe enviar mañana 18 abril
- ❓ Password policy ← ¿cuál es? (usar PBKDF2 default)

---

## 📚 REFERENCIAS CRÍTICAS

| Documento | Ubicación | Uso |
|-----------|-----------|-----|
| PROYECTO_OPTICOLOR.pdf | /mnt/project | Tracker semanal |
| claude.md | /mnt/project | Contexto técnico |
| Documento_Técnico_DB_v2_0.pdf | /mnt/project | Vistas referencia (Panamá) |
| INFORME_EJECUTIVO_SEMANA1.md | /mnt/project | Qué se hizo Semana 1 |

---

## 💡 TIPS PARA CLAUDE CODE

1. **Lee PROYECTO_OPTICOLOR.pdf primero** → sabe qué está done, qué no
2. **Abre archivos en editor** → navega por estructura
3. **Usa `find` command** → busca "TODO: Semana 2.2" en código
4. **Test local** → `npm run dev` después de cada cambio
5. **Commit frecuente** → `git commit -am "Tarea X completada"`
6. **Preguntas:** tag @gerardo en commits si hay blockers

---

## ⚡ RESUMEN QUICK

```
INPUT:  Excel usuarios + credenciales Azure SQL
PROCESS: 
  1. Cargar usuarios en BD (INSERT + PBKDF2)
  2. Reemplazar mock data en 5 endpoints
  3. Crear 5 vistas SQL (Dim_*, Fact_*)
  4. Testing RLS + login
OUTPUT: Portal con datos reales, RLS funcionando
DELIVERY: Git push + link commit a Notion
```

---

**¿Preguntas antes de empezar?** Responde en hilo Slack #opticolor-bi

¡Listo! 🚀
