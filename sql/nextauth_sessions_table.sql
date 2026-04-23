-- NextAuth Sessions Table para Azure SQL
-- Ejecutar en db-opticolor-dw
-- Esto almacenará las sesiones de usuarios autenticados

USE [db-opticolor-dw];
GO

-- Crear tabla de sesiones si no existe
IF NOT EXISTS (SELECT * FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_NAME = 'sessions')
BEGIN
    CREATE TABLE [dbo].[sessions] (
        [id] NVARCHAR(255) NOT NULL PRIMARY KEY,
        [sessionToken] NVARCHAR(255) NOT NULL UNIQUE,
        [userId] INT NOT NULL,
        [expires] DATETIME2 NOT NULL,
        [createdAt] DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        [updatedAt] DATETIME2 NOT NULL DEFAULT GETUTCDATE(),
        CONSTRAINT [FK_sessions_users] FOREIGN KEY ([userId])
            REFERENCES [dbo].[Seguridad_Usuarios]([id_usuario])
                ON DELETE CASCADE
    );

    PRINT 'Tabla [sessions] creada exitosamente';

    -- Crear índices para optimizar queries
    CREATE INDEX [IX_sessions_userId] ON [dbo].[sessions]([userId]);
    CREATE INDEX [IX_sessions_sessionToken] ON [dbo].[sessions]([sessionToken]);
    CREATE INDEX [IX_sessions_expires] ON [dbo].[sessions]([expires]);

    PRINT 'Índices creados';
END
ELSE
BEGIN
    PRINT 'Tabla [sessions] ya existe';
END

GO

-- Verificar que se creó correctamente
SELECT 'Tabla sessions' AS tabla, COUNT(*) AS registros FROM [sessions]
UNION ALL
SELECT 'Seguridad_Usuarios', COUNT(*) FROM [Seguridad_Usuarios];

GO
