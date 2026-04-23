import { type Adapter } from 'next-auth/adapters';
import { query } from './db';

/**
 * Custom NextAuth Adapter para Azure SQL (MSSQL)
 * Gestiona sesiones en la tabla [sessions]
 */
export function MSSQLAdapter(): Adapter {
  return {
    async createSession(data) {
      const { sessionToken, userId, expires } = data;

      try {
        console.log('[NextAuth Adapter] Creando sesión para usuario:', userId);

        await query(
          `INSERT INTO [sessions] ([id], [sessionToken], [userId], [expires])
           VALUES (NEWID(), @sessionToken, @userId, @expires)`,
          {
            sessionToken,
            userId,
            expires,
          }
        );

        return {
          sessionToken,
          userId,
          expires,
        } as any;
      } catch (error) {
        console.error('[NextAuth Adapter] Error creando sesión:', error);
        throw error;
      }
    },

    async getSessionAndUser(sessionToken) {
      try {
        console.log('[NextAuth Adapter] Buscando sesión:', sessionToken);

        const rows = await query<{
          sessionToken: string;
          userId: number;
          expires: Date;
          id_usuario: number;
          email: string;
          nombre_completo: string;
          nombre_rol: string;
          nivel_jerarquico: number;
        }>(
          `SELECT
             s.[sessionToken],
             s.[userId],
             s.[expires],
             u.[id_usuario],
             u.[email],
             u.[nombre_completo],
             u.[nombre_rol],
             u.[nivel_jerarquico]
           FROM [sessions] s
           INNER JOIN [Seguridad_Usuarios] u ON s.[userId] = u.[id_usuario]
           WHERE s.[sessionToken] = @sessionToken AND s.[expires] > GETUTCDATE()`,
          { sessionToken }
        );

        if (!rows.length) {
          console.log('[NextAuth Adapter] Sesión no encontrada o expirada');
          return null;
        }

        const row = rows[0];
        console.log('[NextAuth Adapter] Sesión encontrada para:', row.email);

        return {
          session: {
            sessionToken: row.sessionToken,
            userId: row.userId,
            expires: new Date(row.expires),
          } as any,
          user: {
            id: String(row.id_usuario),
            email: row.email,
            name: row.nombre_completo,
            nombre_rol: row.nombre_rol,
            nivel_jerarquico: row.nivel_jerarquico,
          } as any,
        };
      } catch (error) {
        console.error('[NextAuth Adapter] Error obteniendo sesión:', error);
        throw error;
      }
    },

    async updateSession(data) {
      const { sessionToken, expires } = data;

      try {
        console.log('[NextAuth Adapter] Actualizando sesión:', sessionToken);

        await query(
          `UPDATE [sessions]
           SET [expires] = @expires, [updatedAt] = GETUTCDATE()
           WHERE [sessionToken] = @sessionToken`,
          {
            sessionToken,
            expires,
          }
        );

        const rows = await query<{
          sessionToken: string;
          userId: number;
          expires: Date;
        }>(
          `SELECT [sessionToken], [userId], [expires]
           FROM [sessions]
           WHERE [sessionToken] = @sessionToken`,
          { sessionToken }
        );

        if (!rows.length) {
          return null;
        }

        const row = rows[0];
        return {
          sessionToken: row.sessionToken,
          userId: row.userId,
          expires: new Date(row.expires),
        } as any;
      } catch (error) {
        console.error('[NextAuth Adapter] Error actualizando sesión:', error);
        throw error;
      }
    },

    async deleteSession(sessionToken) {
      try {
        console.log('[NextAuth Adapter] Eliminando sesión:', sessionToken);

        await query(
          `DELETE FROM [sessions] WHERE [sessionToken] = @sessionToken`,
          { sessionToken }
        );
      } catch (error) {
        console.error('[NextAuth Adapter] Error eliminando sesión:', error);
        throw error;
      }
    },

    async createUser() {
      throw new Error('createUser no está implementado');
    },
    async getUser() {
      throw new Error('getUser no está implementado');
    },
    async getUserByEmail() {
      throw new Error('getUserByEmail no está implementado');
    },
    async getUserByAccount() {
      throw new Error('getUserByAccount no está implementado');
    },
    async updateUser() {
      throw new Error('updateUser no está implementado');
    },
    async deleteUser() {
      throw new Error('deleteUser no está implementado');
    },
    async linkAccount() {
      throw new Error('linkAccount no está implementado');
    },
    async unlinkAccount() {
      throw new Error('unlinkAccount no está implementado');
    },
    async createVerificationToken() {
      throw new Error('createVerificationToken no está implementado');
    },
    async useVerificationToken() {
      throw new Error('useVerificationToken no está implementado');
    },
  };
}
