# PROMPT — CLAUDE CODE
## OPTICOLOR BI Venezuela | Semana 3 | 23 Abril 2026
**Proyecto:** Ecosistema de Inteligencia de Datos — Opticolor #2, C.A.
**Repo:** GitHub privado `opticolor-bi` (monorepo `/etl /portal /sql /docs`)
**DB:** Azure SQL — `srv-opticolor.database.windows.net` / `db-opticolor-dw`
**Portal:** Next.js 14 + NextAuth.js + Tailwind CSS — Azure Container Apps

---

## CONTEXTO DEL PROYECTO

Eres el asistente de desarrollo del proyecto OPTICOLOR BI Venezuela. Se trata de un portal web de Business Intelligence para una cadena de ópticas venezolana con 103 sucursales en 14 estados. El stack es Next.js 14 + NextAuth.js + Tailwind CSS + Recharts en el frontend, Azure SQL como data warehouse, Python ETL en Azure Function App, y 5 informes de negocio como entregables principales.

**Estado al 23 abril 2026:**
- Semana 1 ✅ completa — infraestructura Azure, ETL, 34 tablas SQL, Telegram bot
- Semana 2 ✅ parcial — ETL con 208,346 registros cargados, 18 módulos en producción
- Deuda activa: portal Next.js sin NextAuth, vistas Dim_*/Fact_* pendientes, API routes sin empezar
- Go-live: 26 mayo 2026 (33 días)

---

## ESTRATEGIA RBAC — CONTEXTO CRÍTICO

El diseño original tenía 7 roles. Hoy, con el Excel real de Opticolor como fuente de verdad, simplificamos a **3 roles humanos operacionales**:

### Roles definitivos

| id_rol | nombre_rol  | Quién                        | Acceso                                      |
|--------|-------------|------------------------------|---------------------------------------------|
| 1      | SUPER_ADMIN | Gerardo Argueta (VisioFlow)  | Control total del sistema                   |
| 2      | MASTER      | 5 usuarios Opticolor         | Todas las sucursales sin filtro             |
| 4      | SUPERVISOR  | 21 usuarios Opticolor        | Solo sucursales asignadas en mantenimiento  |
| 6      | ETL_SERVICE | Cuenta técnica ETL           | Solo escritura SQL (no es usuario humano)   |
| 7      | PORTAL_SERVICE | Cuenta técnica portal     | Solo lectura SQL (no es usuario humano)     |

**Roles eliminados:** GERENTE_ZONA (id=3) y CONSULTOR (id=5) — no existen en la operación real.

### Lógica RLS en el portal
```typescript
// En cada API route — lógica de filtrado
if (session.user.role === 'SUPER_ADMIN' || session.user.role === 'MASTER') {
  // Sin filtro — devuelve todas las sucursales
  query = `SELECT * FROM Vw_RLS_Sucursales WHERE id_usuario = ${userId}`
  // Retorna las 103 sucursales del directorio
} else if (session.user.role === 'SUPERVISOR') {
  // Filtra estrictamente por sucursales asignadas
  query = `SELECT * FROM Vw_RLS_Sucursales WHERE id_usuario = ${userId}`
  // Retorna solo las sucursales en Seguridad_Usuarios_Sucursales
}
// La vista Vw_RLS_Sucursales maneja la lógica internamente
```

### Tabla nueva: `Param_Sucursales_Directorio`
Existe porque `Maestro_Sucursales` solo tiene 28 filas (ETL carga progresivamente). El directorio tiene las 103 sucursales del Excel y permite pre-asignar accesos. `Seguridad_Usuarios_Sucursales` referencia esta tabla, no `Maestro_Sucursales`.

### Usuarios actuales en BD
- 1 existente: `visioflow.tech@gmail.com` → SUPER_ADMIN (id=1, Gerardo)
- 26 por insertar: 5 MASTER + 21 SUPERVISOR (del Excel Opticolor Abril 2024)

---

## ALCANCES DEL DÍA — 23 ABRIL

### TAREA 1 — SQL RBAC Setup (PRIORITARIA — desbloquea todo)
**Archivo a crear:** `/sql/rbac_setup_23abr2026.sql`

Genera y ejecuta en Azure SQL el script completo que haga:

**1.1 Limpiar roles que no aplican:**
```sql
-- Eliminar dependencias y roles GERENTE_ZONA (id=3) y CONSULTOR (id=5)
DELETE FROM Seguridad_Roles_Permisos WHERE id_rol IN (3, 5);
DELETE FROM Seguridad_Roles WHERE id_rol IN (3, 5);
-- Renombrar ADMIN → MASTER
UPDATE Seguridad_Roles SET nombre_rol = 'MASTER',
  descripcion = 'Acceso total — todas las sucursales Opticolor'
WHERE id_rol = 2;
```

**1.2 Crear `Param_Sucursales_Directorio`:**
```sql
CREATE TABLE [dbo].[Param_Sucursales_Directorio] (
    id_sucursal  INT           NOT NULL PRIMARY KEY,
    nombre       NVARCHAR(150) NOT NULL,
    ciudad       NVARCHAR(100) NULL,
    estado       NVARCHAR(100) NULL,
    es_corporativo BIT         NULL DEFAULT 0,
    esta_activo  BIT           NULL DEFAULT 1,
    fecha_carga  DATETIME2     NULL DEFAULT GETUTCDATE()
);
```

Luego INSERT de las 103 sucursales del Excel (ver datos completos abajo).

**1.3 Insertar 26 usuarios:**
Password temporal para todos: `Opticolor2026!`
**IMPORTANTE:** Debes generar el hash bcrypt (cost=10) de ese password con Node.js o Python y usarlo en el INSERT. No insertar texto plano.

```bash
# Generar hash en Node.js
node -e "const b=require('bcryptjs'); b.hash('Opticolor2026!',10).then(h=>console.log(h))"
```

Usuarios MASTER (5):
- `gmartinez@grupoopticolor.com` — GUSTAVO MARTINEZ
- `jhernandez@grupoopticolor.com` — JUNIELSY HERNANDEZ
- `rarangel@grupoopticolor.com` — REINALDO A RANGEL
- `rrangel@grupoopticolor.com` — REINALDO J RANGEL
- `emartinez@grupoopticolor.com` — EDUARDO MARTINEZ

Usuarios SUPERVISOR (21) con su sucursal asignada:
| Email | Nombre | id_sucursal |
|---|---|---|
| hquintero@grupoopticolor.com | HERNAN QUINTERO | 2 |
| malvarez@grupoopticolor.com | MARIA ALVAREZ | 3 |
| khurtado@grupoopticolor.com | KATHERIN HURTADO | 8 |
| bbolivar@opticolor.com.ve | BABARA BOLIVAR | 9 |
| egarcia@opticolor.com.ve | EDITH GARCIA | 10 |
| jsoto@grupoopticolor.com | JOSE SOTO | 11 |
| rpina@opticolor.com.ve | ROSAIDA PINA | 12 |
| kjimenez@grupoopticolor.com | KARLA JIMENEZ | 13 |
| ytadino@opticolor.com.ve | YOLIBERT TADINO | 14 |
| yanez@grupoopticolor.com | JENNY ANEZ | 15 |
| arodriguez@grupoopticolor.com | ADELAIDA RODRIGUEZ | 16 |
| kgarcia@grupoopticolor.com | KERVIN GARCIA | 17 |
| yrodriguez@grupoopticolor.com | YASMIRA RODRIGUEZ | 18 |
| vaponte@grupoopticolor.com | VICKY APONTE | 19 |
| lvillarroel@grupoopticolor.com | LANYEINY VILLARROEL | 20 |
| janez@grupoopticolor.com | JOANGEL ANEZ | 21 |
| wcaballero@grupoopticolor.com | WILFREDO CABALLERO | 22 |
| kcastillo@croven.com.ve | KENNITH CASTILLO | 23 |
| ymoreno@opticolor.com.ve | YILBERT MORENO | 24 |
| oherrera@grupoopticolor.com | OHAMBRA HERRERA | 25 |
| egonzalez@grupoopticolor.com | EDMAIRA GONZALEZ | 26 |

**1.4 Asignar roles en `Seguridad_Usuarios_Roles`**

**1.5 Asignar sucursales en `Seguridad_Usuarios_Sucursales`** (solo SUPERVISORs)
- Primero: identificar el nombre del FK constraint existente con:
  ```sql
  SELECT name FROM sys.foreign_keys
  WHERE parent_object_id = OBJECT_ID('Seguridad_Usuarios_Sucursales');
  ```
- Eliminar FK viejo → crear FK nuevo apuntando a `Param_Sucursales_Directorio`

**1.6 Recrear `Vw_RLS_Sucursales`:**
```sql
-- UNION ALL de dos bloques:
-- Bloque 1: SUPER_ADMIN y MASTER → CROSS con todas las sucursales activas
-- Bloque 2: SUPERVISOR → JOIN con Seguridad_Usuarios_Sucursales
-- Columnas: id_usuario, email, nombre_rol, id_sucursal, nombre_sucursal, ciudad, estado, es_corporativo
```

**1.7 Recrear `Vw_Usuario_Accesos`** (usada por NextAuth):
```sql
-- Columnas mínimas necesarias:
-- id_usuario, email, nombre_completo, password_hash, esta_activo,
-- nombre_rol, nivel_jerarquico
```

**1.8 Verificación post-ejecución:**
```sql
SELECT 'Roles' AS tabla, COUNT(*) AS filas FROM Seguridad_Roles
UNION ALL SELECT 'Usuarios', COUNT(*) FROM Seguridad_Usuarios
UNION ALL SELECT 'Directorio', COUNT(*) FROM Param_Sucursales_Directorio
UNION ALL SELECT 'Usuarios_Roles', COUNT(*) FROM Seguridad_Usuarios_Roles
UNION ALL SELECT 'Usuarios_Sucursales', COUNT(*) FROM Seguridad_Usuarios_Sucursales;
-- Esperado: Roles=5, Usuarios=27, Directorio=103, Usuarios_Roles=26, Usuarios_Sucursales=21
```

---

### TAREA 2 — NextAuth + Login funcional
**Archivos:** `/portal/app/api/auth/[...nextauth]/route.ts` y `/portal/app/login/page.tsx`

Configura NextAuth con Credentials Provider que:
1. Recibe `email` + `password` del formulario
2. Consulta `Vw_Usuario_Accesos` en Azure SQL por email
3. Verifica password con `bcryptjs.compare()`
4. Si válido, retorna objeto de sesión con: `{ id, email, nombre, rol, nivel }`
5. El middleware en `/portal/middleware.ts` protege `/dashboard/*` — redirige a `/login` si no hay sesión

El login page ya existe visualmente en Vercel. Solo conectar la lógica de NextAuth.

Variables de entorno necesarias en `.env.local`:
```env
NEXTAUTH_SECRET=<generar con: openssl rand -base64 32>
NEXTAUTH_URL=http://localhost:3000
DB_SERVER=srv-opticolor.database.windows.net
DB_NAME=db-opticolor-dw
DB_USER=<ver Azure Key Vault>
DB_PASSWORD=<ver Azure Key Vault>
```

---

### TAREA 3 — Investigar Marketing_Citas = 0
**Archivo a crear:** `/docs/hallazgo_marketing_citas_23abr2026.md`

La tabla `Marketing_Citas` tiene 0 registros. Antes de reportarle a Eduardo, verifica:
1. Consulta la estructura de la tabla: `SELECT TOP 0 * FROM Marketing_Citas`
2. Revisa si el ETL tiene un módulo para esta tabla en `/etl/`
3. Si el módulo existe, revisar si está activo o deshabilitado en `Etl_Control_Ejecucion`
4. Documenta el hallazgo con conclusión y acción recomendada

---

## ALCANCES DE LA SEMANA — PENDIENTES (24-30 ABRIL)

### Viernes 25 abril
- [ ] API Routes Next.js para Informe 1 (Resumen Comercial) — conectar a `Fact_Ventas` + `Fact_Recaudo`
- [ ] API Routes Next.js para Informe 2 (Eficiencia Órdenes) — conectar a `Fact_Eficiencia_Ordenes`

### Lunes 28 abril
- [ ] Layout base portal — sidebar dinámico desde `Param_Modulos`, header con usuario/rol/logout
- [ ] Dashboard Informe 1 completo con Recharts (barras ventas por mes, KPIs cards)

### Martes 29 abril
- [ ] Dashboard Informe 2 completo
- [ ] Power BI Desktop — conexión a Azure SQL, Informes 1 y 2

### Miércoles 30 abril
- [ ] Testing responsive Informes 1 y 2 (mobile 375px, tablet 768px, desktop)
- [ ] Corrección fecha errónea en Notion ("5 feb 2026" → mayo 2026)

---

## DATOS COMPLETOS — 103 SUCURSALES DIRECTORIO

```
(1,'Catia','CARACAS','MIRANDA',0),
(2,'Los Proceres','CARACAS','MIRANDA',0),
(3,'La Cascada','LOS TEQUES','MIRANDA',0),
(4,'Metrocenter 1','CARACAS','MIRANDA',0),
(5,'Metrocenter 2','CARACAS','MIRANDA',0),
(6,'Multiplaza','CARACAS','MIRANDA',0),
(7,'Candelaria Center','CARACAS','MIRANDA',0),
(8,'Sambil Candelaria Miranda','CARACAS','MIRANDA',0),
(9,'Sambil Candelaria AB','CARACAS','MIRANDA',0),
(10,'El Recreo','CARACAS','MIRANDA',0),
(11,'Expresso Chacaito','CARACAS','MIRANDA',0),
(12,'Millenium','CARACAS','MIRANDA',0),
(13,'Sambil Chacao Autopista','CARACAS','MIRANDA',0),
(14,'CC Líder','CARACAS','MIRANDA',0),
(15,'El Márquez','CARACAS','MIRANDA',0),
(16,'Petare','CARACAS','MIRANDA',0),
(17,'Caracas Outlet','CARACAS','MIRANDA',0),
(18,'Expresso Baruta','CARACAS','MIRANDA',0),
(19,'Traki Trinidad','CARACAS','MIRANDA',0),
(20,'El Hatillo','CARACAS','MIRANDA',0),
(21,'CCCT 2','CARACAS','MIRANDA',0),
(22,'San Ignacio','CARACAS','MIRANDA',0),
(23,'Sambil Chacao Feria','CARACAS','MIRANDA',0),
(24,'Sambil Chacao Libertador','CARACAS','MIRANDA',0),
(25,'CCCT 1','CARACAS','MIRANDA',0),
(26,'Cerro Verde 1','CARACAS','MIRANDA',0),
(27,'Cerro Verde 2','CARACAS','MIRANDA',0),
(28,'Tolon','CARACAS','MIRANDA',0),
(29,'La Guaira','LA GUAIRA','VARGAS',0),
(30,'Centro Lido','CARACAS','MIRANDA',0),
(31,'Forum Guarenas','GUARENAS','MIRANDA',0),
(32,'Forum Guarire','GUATIRE','MIRANDA',0),
(33,'Forum La Urbina','CARACAS','MIRANDA',0),
(34,'Forum San Bernardino','CARACAS','MIRANDA',0),
(35,'Calle Libertad','PUERTO LA CRUZ','ANZOATEGUI',0),
(36,'Puente Real','BARCELONA','ANZOATEGUI',0),
(37,'Cumaná','CUMANA','SUCRE',0),
(38,'Plaza Mayor','LECHERIA','ANZOATEGUI',0),
(39,'Las Olas Lecheria','LECHERIA','ANZOATEGUI',0),
(40,'La Vela','ISLA DE MARGARITA','NUEVA ESPARTA',0),
(41,'Margarita City Place','ISLA DE MARGARITA','NUEVA ESPARTA',0),
(42,'Sambil Margarita','ISLA DE MARGARITA','NUEVA ESPARTA',0),
(43,'Oro','CIUDAD GUAYANA','BOLIVAR',0),
(44,'San Félix','SAN FELIX','BOLIVAR',0),
(45,'Alta Vista','CIUDAD GUAYANA','BOLIVAR',0),
(46,'SanTome','CIUDAD GUAYANA','BOLIVAR',0),
(47,'Acero','CIUDAD GUAYANA','BOLIVAR',0),
(48,'Aviadores 1','MARACAY','ARAGUA',0),
(49,'Aviadores Aeropuerto','MARACAY','ARAGUA',0),
(50,'Hyperjumbo','MARACAY','ARAGUA',0),
(51,'Las Américas','MARACAY','ARAGUA',0),
(52,'Parque Aragua','MARACAY','ARAGUA',0),
(53,'Galerías Plaza 1','MARACAY','ARAGUA',0),
(54,'Galerías Plaza 2','MARACAY','ARAGUA',0),
(55,'Estación Central','MARACAY','ARAGUA',0),
(56,'Unicentro','MARACAY','ARAGUA',0),
(57,'Metrópolis Valencia','VALENCIA','CARABOBO',0),
(58,'El Viñedo','VALENCIA','CARABOBO',0),
(59,'Sambil Valencia','VALENCIA','CARABOBO',0),
(60,'La Granja','VALENCIA','CARABOBO',0),
(61,'Traki Guacara','GUACARA','CARABOBO',0),
(62,'Traki Cabudare','CABUDARE','LARA',0),
(63,'Trinitarias','BARQUISIMETO','LARA',0),
(64,'Ciudad Crepuscular','BARQUISIMETO','LARA',0),
(65,'Metrópolis Barquisimeto','BARQUISIMETO','LARA',0),
(66,'Sambil Barquisimeto 2','BARQUISIMETO','LARA',0),
(67,'Sambil Barquisimeto 1','BARQUISIMETO','LARA',0),
(68,'Sambil Paraguaná 1','PUNTO FIJO','FALCON',0),
(69,'Sambil Paraguaná 2','PUNTO FIJO','FALCON',0),
(70,'Las Virtudes','PUNTO FIJO','FALCON',0),
(71,'Sambil San Cristóbal','SAN CRISTOBAL','TACHIRA',0),
(72,'Lago Mall','MARACAIBO','ZULIA',0),
(73,'MetroSol','MARACAIBO','ZULIA',0),
(74,'Chinita Plaza','MARACAIBO','ZULIA',0),
(75,'Chinita FDS','MARACAIBO','ZULIA',0),
(76,'Puente Cristal','MARACAIBO','ZULIA',0),
(77,'Caribe Zulia','MARACAIBO','ZULIA',0),
(78,'Cima','MARACAIBO','ZULIA',0),
(79,'Galerías Mall','MARACAIBO','ZULIA',0),
(80,'Gran Bazar','MARACAIBO','ZULIA',0),
(81,'Coromoto','SAN FRANCISCO','ZULIA',0),
(82,'Mall San Francisco','SAN FRANCISCO','ZULIA',0),
(83,'Traki Cabimas','CABIMAS','ZULIA',0),
(84,'Borgas','CABIMAS','ZULIA',0),
(85,'Terraza 77','MARACAIBO','ZULIA',0),
(86,'Mall Delicias','MARACAIBO','ZULIA',0),
(87,'Sambil Maracaibo','MARACAIBO','ZULIA',0),
(88,'Corporativo Caracas','CARACAS','MIRANDA',1),
(89,'Corporativo Zulia','MARACAIBO','ZULIA',1),
(90,'Corporativo Aragua','MARACAY','ARAGUA',1),
(91,'Corporativo Carabobo','VALENCIA','CARABOBO',1),
(92,'SOLE Tolon','CARACAS','MIRANDA',0),
(93,'Metrópolis Valencia 2','VALENCIA','LARA',0),
(94,'Metrópolis Barquisimeto 2','BARQUISIMETO','LARA',0),
(95,'Llano Mall','ACARIGUA','PORTUGUESA',0),
(96,'Forum Los Teques','LOS TEQUES','MIRANDA',0),
(97,'Forum Charallave','CARACAS','MIRANDA',0),
(98,'Forum La California','CARACAS','MIRANDA',0),
(99,'Forum San Martin','CARACAS','MIRANDA',0),
(100,'Forum Cagua','CAGUA','ARAGUA',0),
(101,'Forum Maturin 1','MATURIN','MONAGAS',0),
(102,'Forum Maturin 2','MATURIN','MONAGAS',0),
(103,'Forum Ciudad Bolívar','CIUDAD BOLIVAR','BOLIVAR',0)
```

---

## REGLAS GENERALES DEL PROYECTO

1. **Nunca inventar** nombres de tablas, columnas ni endpoints — verificar siempre contra el schema real
2. **GMT-4** para todas las fechas (Venezuela) — usar `DATEADD(HOUR, -4, fecha_utc)`
3. **IVA 16%** para cálculos fiscales venezolanos
4. **Passwords** nunca en texto plano — siempre bcrypt cost=10
5. **Commits** al repo `opticolor-bi` por cada tarea completada con mensaje descriptivo
6. **Documentar** hallazgos inesperados en `/docs/` antes de continuar
7. Si algo no está claro en el schema, **ejecutar query de diagnóstico primero**

---

## CRITERIO DE ÉXITO DEL DÍA

Al finalizar el 23 de abril, deben estar ✅:
- [ ] `Param_Sucursales_Directorio` creada con 103 filas
- [ ] 26 usuarios insertados con hash bcrypt correcto
- [ ] Roles actualizados: 5 roles (sin GERENTE_ZONA ni CONSULTOR)
- [ ] 21 asignaciones supervisor→sucursal en `Seguridad_Usuarios_Sucursales`
- [ ] `Vw_RLS_Sucursales` recreada con lógica simplificada
- [ ] `Vw_Usuario_Accesos` operativa para NextAuth
- [ ] NextAuth funcional: login con email/password → sesión con rol
- [ ] Hallazgo Marketing_Citas documentado
- [ ] Todo commiteado al repo con mensajes claros
