# 📋 Inventario de Archivos — Opticolor BI (Post-Limpieza)

**Fecha:** 21 Abril 2026  
**Estado:** Repositorio limpio, archivos innecesarios removidos  
**Total archivos eliminados:** 21

---

## 📁 Estructura Principal

### 🔒 CORE (No modificar)
```
CLAUDE.md                          — Documentación proyecto, variables env, stack
README.md                          — Índice principal del repositorio
```

### 📚 Documentación Activa (`/docs/`)
```
CHECKLIST_SEMANA2.md               — Checklist semana 2 (actualizar a Semana 2)
INDICE_DESPLIEGUE_VISTAS_VENEZUELA.md  — Índice vistas BI
INFORME_EJECUTIVO_SEMANA1.md       — Estado semanal (actualizar a Semana 2)
PROTOCOLO_DESPLIEGUE_VISTAS_VENEZUELA.md — Deployment vistas
QUICK_REFERENCE_VISTAS_VENEZUELA.md — Referencia rápida vistas
SOLICITUD_DATOS_OPTICOLOR.md       — Datos pendientes de cliente
VERCEL_SETUP_INSTRUCCIONES.md      — Setup Portal Vercel
```

### 🗄️ Base de Datos (`/sql/`)
```
CORE SETUP:
  setup_opticolor_venezuela.sql    — ✅ DDL schema principal (31 tablas)
  create_ventas_detalle.sql        — ✅ Tabla Ventas_Detalle (FK, índices)

VISTAS BI (Copiar en orden):
  vistas.sql                       — ✅ Vistas finales limpias
  vistas_opticolor_venezuela_AJUSTADAS.sql — Versión adaptada (backup)
  vistas_opticolor_venezuela_LIMPIO.sql — Versión limpia (backup)

VALIDACIÓN Y ANÁLISIS:
  00_VALIDACION_Y_DESPLIEGUE.sql   — Queries validación post-deploy
  QUERIES_ANALISIS_VISTAS.sql      — Análisis datos y vistas

REFERENCIAS:
  respaldo_optilux.sql             — Schema Optilux Panama (referencia)
  setup_opticolor_dw.sql           — Setup DW opcional
```

### 🐍 ETL/Azure Functions (`/etl/`)
```
CÓDIGO PRODUCCIÓN:
  function_app.py                  — ✅ Orquestador ETL + clase GesvisionEtl
  requirements.txt                 — Dependencias Python

DOCUMENTACIÓN TEMPORAL:
  PRODUCTOS_LOOP_TEMPORAL.md       — ✅ Guía loop automático (MANTENER hasta completar)

CONFIG:
  host.json                        — Config Azure Functions
  local.settings.json              — Variables locales
  .env                             — Credenciales (NO commitear)
```

### 🌐 Portal (`/portal/`)
```
Next.js 16 con App Router
  app/                             — Rutas y páginas
  components/                      — Componentes React
  public/                          — Assets estáticos
  package.json                     — Dependencias Node.js
  README.md                        — Documentación Portal
```

### 🤖 Agentes Especializados (`/.claude/agents/`)
```
Guías domain-specific para sesiones futuras:
  azure-cloud.md                   — Azure Functions, CI/CD, infrastructure
  etl-azure.md                     — Python ETL, CRON, checkpoints
  optica-negocio.md               — Reglas negocio óptica
  portal-nextjs.md                — Next.js 16, API routes
  powerbi.md                       — DAX, KPIs, vistas BI
  qa.md                            — Testing, validación
  security.md                      — RBAC, NextAuth, JWT
  sql-datamodel.md                — DDL, vistas, RLS
```

---

## ✅ Checklist de Limpieza Completado

| Item | Status | Notas |
|------|--------|-------|
| Documentación residual (11 archivos) | ✅ Eliminado | RESUMEN_*, ADAPTACION, TESTING, VERIFICACION |
| Scripts SQL testing (9 archivos) | ✅ Eliminado | audit_*, clean_*, reset_*, respaldo_utf8 |
| Instrucciones obsoletas (2 archivos) | ✅ Eliminado | INSTRUCCIONES_PRODUCTOS_LOCAL, RUN_PRODUCTOS_LOCAL |
| STATUS_CASCADA.txt | ✅ Eliminado | Reemplazado por PRODUCTOS_LOOP_TEMPORAL.md |
| **Total eliminado** | **✅ 21 archivos** | **Espacio liberado: ~500 KB** |

---

## 📝 Archivos a Actualizar (Próxima Sesión)

- [ ] `docs/CHECKLIST_SEMANA2.md` — Cambiar Semana 1 → Semana 2, fechas actuales
- [ ] `docs/INFORME_EJECUTIVO_SEMANA1.md` — Cambiar a Semana 2, agregar progreso

---

## 🔑 Archivos Críticos (No eliminar nunca)

1. **CLAUDE.md** — Contexto proyecto, stack, variables env, RBAC, tablas
2. **setup_opticolor_venezuela.sql** — Schema base (31 tablas)
3. **function_app.py** — Orquestador ETL completo
4. **vistas.sql** — Vistas BI finales
5. **PROTOCOLO_DESPLIEGUE_VISTAS_VENEZUELA.md** — Guía deployment

---

## 🚀 Flujo de Trabajo Recomendado

### Para próximas sesiones:
1. Leer **CLAUDE.md** (contexto permanente)
2. Revisar **PROTOCOLO_DESPLIEGUE_VISTAS_VENEZUELA.md** (si trabajas vistas)
3. Revisar **PRODUCTOS_LOOP_TEMPORAL.md** (si trabajas ETL)
4. Consultar agentes especializados en `.claude/agents/` según dominio

### Commitear cambios:
```bash
git add -A
git commit -m "refactor: cleanup obsolete docs and test scripts"
git push origin main
```

---

## 📊 Estadísticas Post-Limpieza

| Categoría | Cantidad |
|-----------|----------|
| Archivos .md (docs) | 7 |
| Archivos .sql (sql) | 9 |
| Archivos .md (etl) | 1 |
| Archivos agentes | 8 |
| Archivos core | 2 |
| **Total activos** | **27** |

---

**Última actualización:** 21 Abril 2026 22:30  
**Responsable:** Gerardo (VisioFlow)  
**Estado:** ✅ Repositorio limpio y organizado

