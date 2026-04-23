# 🎯 Opticolor BI — Ecosistema de Inteligencia de Datos Venezuela

**DOCUMENTACIÓN PRINCIPAL:** 📂 [`/docs/CLAUDE.md`](docs/CLAUDE.md)

Esta es la **guía técnica permanente del proyecto**. Se actualiza cada sesión y contiene:
- Arquitectura y stack completo
- 34 tablas SQL (23 base + 8 seguridad + 2 control + 1 parámetros)
- RBAC 7 roles jerárquicos
- ETL cascada 18 módulos (CRON 8x/día)
- Variables de entorno y configuración
- Convenciones nomenclatura

---

## 📊 Estado Actual (Semana 2/6)

✅ **COMPLETADA EN HORARIO**

| Métrica | Valor |
|---------|-------|
| Alcances cumplidos | 22/50 (44%) |
| Registros ETL | 208,346 ✅ |
| Módulos activos | 18/18 |
| Deploy Azure | Production ✅ |

---

## 📁 Estructura Documentación

```
/docs/
├── CLAUDE.md                              ← Contexto técnico (LEER PRIMERO)
├── INFORME_EJECUTIVO_SEMANA2.md           ← Resumen detallado Semana 2
├── TRACKING_ALCANCES_PROYECTO.md          ← Timeline 6 semanas
└── RESUMEN_PARA_COMPARTIR.txt             ← Ejecutivo para stakeholders

/sql/
├── ESTRUCTURA_COMPLETA_DB.sql             ← Schema DDL (34 tablas)
├── EVIDENCIA_CARGA_DATA.sql               ← Query validación post-carga
├── VALIDACION_CRON_8_30.sql               ← Query post-ejecución CRON
└── (otros scripts SQL por módulo)

/memory/
└── estructura-completa-db-23abril2026.md  ← Referencia DB persistente

/.claude/agents/
└── sql-vistas-bi.md                       ← Instrucciones vistas Dim_*/Fact_*
```

---

## 🚀 Próximos Pasos

**Semana 3 (23-30 Abril):**
1. Crear vistas Dim_*/Fact_* (copiar Optilux Panama, adaptar)
2. Validar KPIs con stakeholders
3. Investigar Marketing_Citas (0 registros)

**Validación:**
- Ejecutar `EVIDENCIA_CARGA_DATA.sql` en SSMS
- Ejecutar `VALIDACION_CRON_8_30.sql` post-CRON

---

## 🔗 Referencias

- **Documentación técnica:** [`/docs/CLAUDE.md`](docs/CLAUDE.md)
- **Resumen ejecutivo:** [`/docs/INFORME_EJECUTIVO_SEMANA2.md`](docs/INFORME_EJECUTIVO_SEMANA2.md)
- **Timeline proyecto:** [`/docs/TRACKING_ALCANCES_PROYECTO.md`](docs/TRACKING_ALCANCES_PROYECTO.md)
- **Memoria persistente:** `/memory/estructura-completa-db-23abril2026.md`
- **Instrucciones vistas:** `/.claude/agents/sql-vistas-bi.md`

---

**Última actualización:** 23 de Abril de 2026  
**Estado:** Semana 2/6 ✅ Completada  
**Repositorio:** https://github.com/visioflowtech/opticolor-bi
