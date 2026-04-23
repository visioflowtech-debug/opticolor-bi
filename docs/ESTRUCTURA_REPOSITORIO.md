# 📁 Estructura del Repositorio Opticolor BI

**Última reorganización:** 23 de Abril de 2026 (Semana 2 completada)  
**Estado:** ✅ Limpio y organizado

---

## 🗂️ Estructura General

```
opticolor-bi/
├── CLAUDE.md                          ← INDEX (referencia a /docs/)
│
├── /docs/                             ← 📚 DOCUMENTACIÓN PRINCIPAL
│   ├── CLAUDE.md                      ← Contexto técnico (LEER PRIMERO)
│   ├── INFORME_EJECUTIVO_SEMANA2.md   ← Resumen ejecutivo Semana 2
│   ├── TRACKING_ALCANCES_PROYECTO.md  ← Timeline 6 semanas (50 alcances)
│   ├── RESUMEN_PARA_COMPARTIR.txt     ← Ejecutivo para stakeholders
│   ├── INSTRUCCIONES_EVIDENCIA.md     ← Cómo validar carga de datos
│   └── README.md                      ← Información general proyecto
│
├── /sql/                              ← 🗄️ DDL, VISTAS, QUERIES
│   ├── ESTRUCTURA_COMPLETA_DB.sql     ← Schema DDL (34 tablas referencia)
│   ├── EVIDENCIA_CARGA_DATA.sql       ← Query validación post-carga
│   ├── VALIDACION_CRON_8_30.sql       ← Query post-ejecución CRON
│   ├── setup_opticolor_dw.sql         ← Schema inicial completo
│   ├── setup_opticolor_venezuela.sql  ← Setup Venezuela (geografía)
│   ├── vistas.sql                     ← Vistas Dim_*/Fact_* (Semana 3)
│   ├── create_ventas_detalle.sql      ← Tabla detalles ventas
│   └── 00_VALIDACION_Y_DESPLIEGUE.sql ← Script despliegue
│
├── /etl/                              ← ⚙️ APLICACIÓN ETL PYTHON
│   ├── function_app.py                ← Aplicación principal (18 módulos)
│   ├── requirements.txt                ← Dependencias Python
│   ├── host.json                      ← Configuración Azure Functions
│   ├── local.settings.json            ← Variables env (NO commitar)
│   ├── local.settings.template.json   ← Template variables env
│   ├── .vscode/launch.json            ← Debug VS Code
│   ├── run-local.ps1                  ← Script ejecutar local
│   └── .funcignore                    ← Ignorar local deploy
│
├── /portal/                           ← 🌐 APLICACIÓN NEXT.JS
│   ├── app/                           ← Next.js App Router
│   │   ├── api/                       ← API Routes (datos, auth)
│   │   ├── dashboard/                 ← 5 Dashboards
│   │   ├── auth/                      ← Página login
│   │   └── layout.tsx                 ← Layout principal
│   ├── components/                    ← React Components
│   ├── public/                        ← Assets estáticos
│   ├── package.json                   ← Dependencias Node.js
│   └── next.config.js                 ← Configuración Next.js
│
├── /.claude/                          ← 🤖 CONFIGURACIÓN CLAUDE
│   ├── agents/                        ← Instrucciones agentes especializados
│   │   └── sql-vistas-bi.md           ← Guía crear vistas Dim_*/Fact_*
│   ├── settings.json                  ← Configuración general
│   ├── settings.local.json            ← Configuración local
│   └── keybindings.json               ← Teclas personalizadas
│
├── /memory/                           ← 💾 MEMORIA PERSISTENTE CLAUDE
│   ├── MEMORY.md                      ← Índice memoria
│   └── estructura-completa-db-*.md    ← Referencia DB (futuras sesiones)
│
├── .gitignore                         ← Archivos ignorados
├── .git/                              ← Repositorio Git
└── (otros archivos de config)
```

---

## 📚 Documentación (Cómo Usarla)

### Leer Primero
1. **`/docs/CLAUDE.md`** — Contexto técnico permanente
   - Arquitectura stack
   - 34 tablas SQL (estructura completa)
   - RBAC 7 roles, RLS, auditoría
   - ETL cascada 18 módulos (CRON)
   - Variables env y configuración

### Para Resúmenes Ejecutivos
2. **`/docs/INFORME_EJECUTIVO_SEMANA2.md`** — Resumen detallado
   - Alcances completados
   - Datos cargados: 208,346 registros
   - Issues resueltos
   - Roadmap Semana 3-6

3. **`/docs/TRACKING_ALCANCES_PROYECTO.md`** — Timeline y métricas
   - 50 alcances totales (22/50 completados)
   - Estado por semana (barras de progreso)
   - Línea de tiempo visual

4. **`/docs/RESUMEN_PARA_COMPARTIR.txt`** — Para stakeholders
   - Resumen ejecutivo condensado
   - Métricas clave
   - Próximos pasos

### Para Validación
5. **`/docs/INSTRUCCIONES_EVIDENCIA.md`** — Cómo verificar datos
   - Ejecutar `EVIDENCIA_CARGA_DATA.sql` en SSMS
   - Interpretar resultados
   - Frecuencia validación

---

## 🗄️ SQL (Referencia Técnica)

| Archivo | Propósito | Usar para |
|---------|-----------|-----------|
| **ESTRUCTURA_COMPLETA_DB.sql** | Schema DDL de 34 tablas | Referencia completa, documentación |
| **setup_opticolor_dw.sql** | Script creación BD inicial | Recrear BD desde cero |
| **setup_opticolor_venezuela.sql** | Geografía Venezuela | Parámetros Estados/Municipios |
| **vistas.sql** | Vistas Dim_*/Fact_* | Power BI, Portal (Semana 3) |
| **EVIDENCIA_CARGA_DATA.sql** | Query validación | Verificar registros post-carga |
| **VALIDACION_CRON_8_30.sql** | Query post-ejecución | Validar CRON (cada 2 horas) |
| **00_VALIDACION_Y_DESPLIEGUE.sql** | Checklist despliegue | Deploy a producción |

**Usar en:** SQL Server Management Studio (SSMS) o Azure Data Studio

---

## ⚙️ ETL (Aplicación Python)

**Archivo principal:** `/etl/function_app.py` (190 KB, 68 funciones)

### Funciones Activas
- ✅ **EtlOrquestadorPrincipal** — Timer trigger CRON (8x/día)
- ✅ 18 módulos sync_* (SUCURSALES → INVENTARIO)
- ✅ Checkpoints para INCREMENTAL
- ✅ Notificaciones Telegram

### Configuración
- `local.settings.json` — Credenciales Gesvision, SQL Azure, Telegram
- `requirements.txt` — Dependencias: azure-functions, pyodbc, requests
- `host.json` — Config Azure Functions runtime
- `run-local.ps1` — Script ejecutar localmente

### No Afectado por Limpieza
- ✅ Todos los archivos Python intactos
- ✅ Deploy Azure Production sigue igual
- ✅ CRON ejecutándose automáticamente
- ✅ Funciones disabled: Solo actualizadas en local.settings.json

---

## 🌐 Portal (Aplicación Next.js)

**Framework:** Next.js 16.2.4 (App Router)  
**Deploy:** Vercel (producción, Semana 5)

### Estructura
- `/app/api/` — Rutas API (data endpoints, autenticación)
- `/app/dashboard/` — 5 dashboards principales
- `/app/auth/` — Página login
- `/components/` — React components (navbar, sidebar, dashboards)
- `/public/` — Assets estáticos (logo, imágenes)

### No Afectado por Limpieza
- ✅ Código Next.js intacto
- ✅ Estructura directorios sin cambios
- ✅ Deploy Vercel sin cambios

---

## 🤖 Configuración Claude Code

**Archivos:**
- `/.claude/agents/sql-vistas-bi.md` — Instrucciones agentes SQL
- `/.claude/settings.json` — Permisos, hooks, configuración
- `/.claude/settings.local.json` — Overrides locales

**Memoria persistente:**
- `/memory/MEMORY.md` — Índice memoria
- `/memory/estructura-completa-db-*.md` — Referencia BD para futuras sesiones

---

## 🗑️ Archivos Eliminados (Limpieza Semana 2)

**Total eliminado:** 29 archivos archivados y de testing

**De `/docs/`:**
- SIDEBAR_TOGGLE_*.md (feature Semana 1, completada)
- INFORME_EJECUTIVO_SEMANA1.md (reemplazado por Semana 2)
- INDICE_DESPLIEGUE_VISTAS_VENEZUELA.md (archivado)
- Y otros 11 más (testing, análisis previos, protocolos archivados)

**De `/sql/`:**
- vistas_opticolor_venezuela_AJUSTADAS.sql (versión anterior)
- QUERIES_ANALISIS_VISTAS.sql (análisis archivado)
- respaldo_optilux.sql (backup, no necesario)
- Y otros 3 más

**De `/etl/`:**
- PRODUCTOS_LOOP_TEMPORAL.md (issue resuelto Semana 2)
- SETUP_LOCAL.md (testing local, no necesario)

**De `/portal/`:**
- NAVBAR_ICON_ANALYSIS.md (completado)
- UX_UI_ROADMAP.md (archivado)

**Resultado:** Repositorio limpio sin afectar aplicación ni deploy

---

## ✅ Verificación Post-Limpieza

| Aspecto | Status |
|---------|--------|
| ETL (function_app.py) | ✅ Intacto, 18 módulos presentes |
| Portal (Next.js) | ✅ Intacto, estructura sin cambios |
| SQL (DDL) | ✅ Intacto, 34 tablas referencia |
| Deploy Azure | ✅ Sin cambios, production sigue igual |
| Deploy Vercel | ✅ Sin cambios, testing sigue igual |
| Documentación | ✅ Reorganizada en /docs/, con índice en raíz |

---

## 📊 Tamaño Repositorio

**Antes de limpieza:** ~35 MB (con documentos archivados)  
**Después de limpieza:** ~28 MB (32% reducción)

**Cambios Git:** 2 commits de reorganización
- `8055c1f`: Mover docs a /docs/, SQL a /sql/
- `4bde97b`: Eliminar 29 archivos archivados

---

## 🔄 Próximos Pasos

**Semana 3:**
- Crear vistas Dim_*/Fact_* en `/sql/vistas.sql`
- Actualizar `/docs/INFORME_EJECUTIVO_SEMANA3.md`

**Semana 4:**
- Agregar `.md` con especificaciones Power BI

**Semana 5:**
- Documentación Portal APIs en `/portal/API_REFERENCE.md`

---

## 📌 Notas Importantes

1. **CLAUDE.md en raíz** es un índice → apunta a `/docs/CLAUDE.md`
2. **No eliminar** directorio `/memory/` → memoria persistente Claude
3. **No eliminar** `/.claude/` → configuración proyecto
4. **local.settings.json** en `.gitignore` → nunca commitar credenciales
5. **Documentación actualiza** cada sesión → mantener `/docs/` actualizado

---

**Documento generado:** 23 de Abril de 2026  
**Versión:** 1.0  
**Estado:** Repositorio limpio y organizado ✅
