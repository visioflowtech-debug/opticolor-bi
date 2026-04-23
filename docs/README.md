# 🎯 Opticolor BI — Ecosistema de Inteligencia de Datos Venezuela

Plataforma BI completa para OPTI-COLOR #2, C.A. integrada con Gesvision API.  
**Desarrollado por:** VisioFlow — Gerardo Argueta  
**Período:** 14 abril — 26 mayo 2026 (6 semanas)  
**Estado:** Semana 1 Completada ✅ → Semana 2 En Progreso  

---

## 📊 Estado del Proyecto

| Componente | Estado | % |
|------------|--------|---|
| **SQL Base** (31 tablas) | ✅ Compilado Azure | 100% |
| **RBAC/RLS** (7 roles) | ✅ Implementado | 100% |
| **Contexto Permanente** | ✅ claude.md + 8 agentes | 100% |
| **Portal Next.js** | ⏳ Esperando datos | 0% |
| **Vistas BI** | ⏳ Copiar Panamá | 30% |
| **ETL Gesvision** | ⏳ Validación blocked | 0% |
| **Power BI (5 informes)** | ⏳ Iterativo | 0% |

---

## 📁 Estructura del Repositorio

```
opticolor-bi/
├── claude.md                          ⭐ Fuente de verdad permanente
├── INFORME_EJECUTIVO_SEMANA1.md      📊 Estado Semana 1
├── CHECKLIST_SEMANA2.md              ✅ Tareas Semana 2
├── SOLICITUD_DATOS_OPTICOLOR.md      📋 Datos requeridos
├── RESUMEN_IMPLEMENTACION.md         🚀 Quick reference
│
├── etl/                               🔄 Pipeline Python
│   ├── function_app.py               (18 módulos sync)
│   ├── local.settings.json           (credenciales, CRON)
│   └── requirements.txt
│
├── portal/                            🌐 Será creado Semana 2
│   └── (Next.js 14 + NextAuth.js)
│
├── sql/                               📦 Data Warehouse
│   └── setup_opticolor_venezuela.sql (31 tablas + 2 vistas)
│
├── docs/                              📚 Referencias
│   ├── PROYECTO_OPTICOLOR.pdf        (Tracker semanal)
│   ├── HOJA_DE_RUTA.pdf              (Fases + blockers)
│   ├── Optilux_panama_*.pdf          (Referencia vistas)
│   ├── Propuesta_Comercial_v1.2.pdf  (KPIs + alcance)
│   └── INFORME_DE_AVANCE_17042026.pdf (Estado ejecutivo)
│
├── .claude/
│   └── agents/                        🤖 8 Especialistas
│       ├── sql-datamodel.md
│       ├── security.md
│       ├── etl-azure.md
│       ├── portal-nextjs.md
│       ├── powerbi.md
│       ├── qa.md
│       ├── optica-negocio.md
│       └── azure-cloud.md
│
└── .gitignore                         🔐 Credenciales excluidas
```

---

## 🚀 Inicio Rápido

### Prerequisites
- Node.js 18+
- Python 3.11+
- Azure CLI
- SQL Server Management Studio (opcional)

### Setup

1. **Clonar repositorio:**
   ```bash
   git clone https://github.com/visioflowtech/opticolor-bi.git
   cd opticolor-bi
   ```

2. **Configurar variables de entorno:**
   ```bash
   cp etl/local.settings.json.example etl/local.settings.json
   # Llenar credenciales (ver SOLICITUD_DATOS_OPTICOLOR.md)
   ```

3. **Compilar SQL Schema:**
   ```bash
   sqlcmd -S srv-opticolor.database.windows.net -d db-opticolor-dw \
     -U admin_opticolor -i sql/setup_opticolor_venezuela.sql
   ```

4. **Semana 2 — Setup Portal:**
   ```bash
   npx create-next-app@latest apps/portal --typescript --tailwind
   npm install next-auth bcryptjs
   ```

---

## 📚 Documentación Principal

**LEER EN ESTE ORDEN CADA SESIÓN:**

1. **[PROYECTO OPTICOLOR.pdf](docs/PROYECTO%20OPTICOLOR.pdf)** — Tracker semanal (Notion)
   - Estado tareas por semana
   - Completadas ✅ / En progreso ↻ / Pendientes —

2. **[claude.md](claude.md)** — Contexto técnico permanente
   - Stack, arquitectura, convenciones SQL
   - RBAC 7 roles, ETL schedule, 5 informes
   - Instrucciones críticas (nunca inventar URLs, etc.)

3. **[INFORME_EJECUTIVO_SEMANA1.md](INFORME_EJECUTIVO_SEMANA1.md)** — Estado ejecutivo
   - Realizado vs Pendiente
   - Métricas cumplimiento
   - Bloqueadores identificados

4. **[CHECKLIST_SEMANA2.md](CHECKLIST_SEMANA2.md)** — Tareas próxima semana
   - Hitos Portal, Vistas, ETL, BI
   - Métricas éxito
   - Timeline entregas

5. **[SOLICITUD_DATOS_OPTICOLOR.md](SOLICITUD_DATOS_OPTICOLOR.md)** — Datos requeridos
   - Logo + Colores
   - Credenciales Gesvision
   - Usuarios operacionales
   - Sucursales + Zonas

6. **[HOJA_DE_RUTA.pdf](docs/HOJA%20DE%20RUTA%20al%2012042026_version%20inicial%20.pdf)** — Plan 6 semanas
   - Fases 0-6
   - Dependencias
   - Bloqueadores críticos

7. **[Optilux panama Documento Técnico DB v2.0.pdf](docs/Optilux%20panama%20Documento%20Técnico%20y%20Funcional%20de%20Base%20de%20Datos%20ver%202.0.pdf)** — Vistas referencia
   - Dim_*, Fact_* para copiar/adaptar
   - Cálculos DAX
   - KPI nomenclatura

---

## 🤖 Agentes Especializados

Invocar según tarea:

```bash
# SQL/Modelo de datos
claude-code /ask "Necesito crear vista Dim_Sucursales adaptada de Panamá"
→ Responde: sql-datamodel agent

# Seguridad RBAC/RLS
claude-code /ask "¿Cómo configuro NextAuth con Seguridad_Usuarios?"
→ Responde: security agent

# ETL Python
claude-code /ask "Valida endpoint Gesvision para módulo EtlVentasCabecera"
→ Responde: etl-azure agent

# Portal Next.js
claude-code /ask "Setup estructura Portal Next.js con login"
→ Responde: portal-nextjs agent

# Power BI / DAX
claude-code /ask "Cálculo OTIF para Informe 1"
→ Responde: powerbi agent

# Testing / QA
claude-code /ask "Criterio aceptación Informe 1"
→ Responde: qa agent

# Óptica / Negocio
claude-code /ask "¿Qué es % Conversión Clínico?"
→ Responde: optica-negocio agent

# Azure Cloud
claude-code /ask "Setup Container Apps con CRON scheduler"
→ Responde: azure-cloud agent
```

---

## 🔴 Bloqueadores Críticos (Semana 2)

| # | Bloqueador | Responsable | Resolución |
|---|-----------|------------|-----------|
| 1 | Credenciales Gesvision API | Opticolor | URGENTE — Enviar hoy |
| 2 | Logo + Paleta colores | Opticolor | URGENTE — Para Portal branding |
| 3 | Usuarios operacionales iniciales | Opticolor | Viernes 22 abril |
| 4 | Sucursales + Zonas geográficas | Opticolor | Viernes 22 abril |

📧 Ver detalles: **[SOLICITUD_DATOS_OPTICOLOR.md](SOLICITUD_DATOS_OPTICOLOR.md)**

---

## 📞 Contacto

**Gerardo Argueta (VisioFlow)**
- Email: visioflow.tech@gmail.com
- WhatsApp: [Gerardo]

**Opticolor (Cliente)**
- Eduardo Martínez
- Reinaldo José Rangel

---

## 📅 Timeline Proyecto

```
Semana 1 (14-20 abril):  ✅ Contexto + SQL + RBAC
Semana 2 (21-27 abril):  ⏳ Portal + Vistas + ETL
Semana 3 (28-04 mayo):   ⏳ Power BI 5 informes
Semana 4 (05-11 mayo):   ⏳ Testing RBAC/RLS/Performance
Semana 5 (12-18 mayo):   ⏳ Go-live Prep
Semana 6 (19-26 mayo):   ⏳ Go-live + Soporte
```

---

## ✅ Completado Esta Semana

- ✅ Azure SQL Database compilada (31 tablas)
- ✅ RBAC estructura con 7 roles jerárquicos
- ✅ RLS automático con Vw_RLS_Sucursales
- ✅ Usuario SUPER_ADMIN creado (Gerardo)
- ✅ 8 Agentes especializados configurados
- ✅ claude.md fuente verdad permanente
- ✅ Documentación completa (5+ archivos)

---

## ⏳ Próximos Pasos (Semana 2)

1. ✋ **PAUSADO** — Esperando datos Opticolor
2. Setup Portal Next.js + Login
3. Copiar vistas Dim_*/Fact_* de Panamá
4. Validar ETL con credenciales Gesvision
5. Crear usuarios operacionales en BD

---

**Última actualización:** 17 de abril de 2026  
**Versión:** 1.2  
**Estado:** VERDE ✅ — Fundación completada
