-- Vista: Vw_Sucursales_Pendientes_Clasificacion
-- Propósito: Identificar sucursales que llegaron de Gesvision sin clasificación
--           (sin estado_sucursal ni zona_sucursal asignados)
-- Usada por: ETL → _verificar_sucursales_pendientes() para alertas Telegram
-- Fecha creación: 24 Abril 2026
-- Actualización: 24 Abril 2026 — Ahora solo muestra sucursales con esta_clasificada = 0

USE [db-opticolor-dw];
GO

IF OBJECT_ID('dbo.Vw_Sucursales_Pendientes_Clasificacion', 'V') IS NOT NULL
    DROP VIEW dbo.Vw_Sucursales_Pendientes_Clasificacion;
GO

CREATE VIEW dbo.Vw_Sucursales_Pendientes_Clasificacion
AS
SELECT
    ms.id_sucursal,
    ms.nombre_sucursal,
    ms.municipio,
    DATEDIFF(DAY, ISNULL(pse.fecha_creacion, ms.fecha_carga_etl), GETDATE()) AS dias_sin_clasificar,
    pse.esta_clasificada,
    pse.usuario_clasifico,
    pse.fecha_clasificacion,
    ms.fecha_carga_etl
FROM dbo.Maestro_Sucursales ms
LEFT JOIN dbo.Param_Sucursales_Enriquecimiento pse
    ON ms.id_sucursal = pse.id_sucursal
WHERE pse.esta_clasificada = 0
   OR (pse.id_sucursal IS NULL)
ORDER BY dias_sin_clasificar DESC, ms.nombre_sucursal;

GO

-- Verificación rápida
SELECT 'Vistas creada: Vw_Sucursales_Pendientes_Clasificacion' AS [Status],
       COUNT(*) AS [Sucursales Pendientes]
FROM dbo.Vw_Sucursales_Pendientes_Clasificacion;
