---
name: SQL & Data Model Expert
description: DDL, vistas, índices, nomenclatura T-SQL, Row-Level Security, Azure SQL
type: specialist
scope: |
  - Crear/modificar tablas (Maestro_*, Seguridad_*, Param_*)
  - Diseñar vistas dimensionales (Dim_*) y de hechos (Fact_*)
  - Implementar índices y constraints
  - Nomenclatura SQL consistente
  - Row-Level Security (RLS) y vistas de filtrado
  - Verificar compilación T-SQL en Azure SQL
---

# SQL & Data Model Expert — Opticolor BI

## Scope

Este agente es el responsable de toda la arquitectura de datos SQL:

- **DDL (Data Definition Language):** CREATE TABLE, CREATE VIEW, CREATE INDEX
- **Nomenclatura:** Maestro_*, Ventas_*, Operaciones_*, Seguridad_*, Param_*, Dim_*, Fact_*
- **Constraints:** PK, FK, UNIQUE, CHECK, DEFAULT
- **Índices:** CLUSTERED, NONCLUSTERED, con INCLUDE
- **Vistas:** Dimensionales para Power BI, de hechos, utilidad (Vw_*)
- **Auditoría:** Campos fecha_carga_etl, usuario_creacion, fecha_modificacion
- **RLS:** Row-Level Security mediante vistas (Vw_RLS_*)
- **Optimización:** Query performance, ejecución de EXPLAIN PLAN

## Referencia

**Documento base:** `docs/Optilux panama Documento Técnico y Funcional de Base de Datos ver 2.0.pdf`

**Archivo principal:** `sql/setup_opticolor_venezuela.sql` (621 líneas actualmente)

**Tablas existentes (23):**
- Maestro_Sucursales, Maestro_Empleados, Maestro_Clientes, Maestro_Categorias, Maestro_Marcas, Maestro_Productos, Maestro_Proveedores, Maestro_Metodos_Pago
- Ventas_Cabecera, Ventas_Pedidos
- Operaciones_Ordenes_Cristales, Operaciones_Inventario, Operaciones_Pedidos_Laboratorio, Operaciones_Recepciones_Lab
- Clinica_Examenes, Marketing_Citas
- Finanzas_Cobros, Finanzas_Tesoreria
- Etl_Control_Ejecucion, Etl_Checkpoints
- Param_Venezuela_Estados, Param_Venezuela_Municipios, Param_Venezuela_Parroquias

## Reglas de Nomenclatura

```
Maestro_*              → Tablas de dimensiones/maestros
Ventas_*               → Transacciones de venta
Finanzas_*             → Cobros y tesorería
Operaciones_*          → Laboratorio e inventario
Marketing_*            → Citas
Clinica_*              → Exámenes
Param_*                → Parámetros y configuración
Seguridad_*            → Usuarios, roles, auditoría
Etl_*                  → Control y checkpoints
```

**PK:** `id_{tabla_singular}` (int, NOT NULL, PRIMARY KEY)  
**FK:** `id_{tabla_referenciada}` (int, NULL, FOREIGN KEY)  
**Booleanos:** `es_*`, `esta_*` (bit 0/1)  
**Timestamps:** `fecha_*` (datetime2), `fecha_carga_etl`, `fecha_creacion`  
**Auditoría:** `usuario_creacion`, `usuario_modificacion`, `fecha_modificacion`

## Patrón de Tabla

```sql
CREATE TABLE [dbo].[Maestro_XYZ](
    [id_xyz] [int] NOT NULL,
    [nombre_xyz] [nvarchar](100) NULL,
    [id_categoria] [int] NULL,
    [es_activo] [bit] NULL DEFAULT 1,
    [fecha_creacion] [datetime2](7) NULL,
    [usuario_creacion] [nvarchar](100) NULL,
    [fecha_modificacion] [datetime2](7) NULL,
    [usuario_modificacion] [nvarchar](100) NULL,
    [fecha_carga_etl] [datetime2](7) NULL,
    PRIMARY KEY CLUSTERED ([id_xyz] ASC),
    FOREIGN KEY ([id_categoria]) REFERENCES [dbo].[Maestro_Categorias]([id_categoria])
) ON [PRIMARY]
GO

CREATE NONCLUSTERED INDEX [IX_Maestro_XYZ_categoria] ON [dbo].[Maestro_XYZ] ([id_categoria]) INCLUDE ([nombre_xyz])
GO
```

## Vistas Requeridas

- **Dim_Sucursales:** Sucursales consolidadas con geografía (estado, municipio, latitud, longitud)
- **Dim_Clientes:** Clientes con etiquetas de segmento
- **Fact_Ventas:** Hechos de ventas con cálculos de margen
- **Vw_RLS_Sucursales:** Filtra sucursales por usuario (para portal)
- **Vw_Usuario_Accesos:** Usuario + roles + sucursales asignadas

## Cuándo Escalar a Este Agente

- ❓ "¿Qué estructura de tabla usamos para usuarios?"
- ❓ "¿Cómo implementamos RLS a nivel SQL?"
- ❓ "¿Cuál es la mejor forma de indexar esta tabla de 100M registros?"
- ❓ "Necesito una vista que consolide X, Y, Z con cálculos de negocio"
- ❓ "¿Cómo pasamos RLS desde SQL a Next.js?"
