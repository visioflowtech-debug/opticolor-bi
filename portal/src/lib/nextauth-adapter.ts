import { type Adapter, type AdapterSession, type AdapterUser } from 'next-auth/adapters';
import { query } from './db';

/**
 * Custom NextAuth Adapter para Azure SQL (MSSQL)
 * Gestiona sesiones en la tabla [sessions]
 */
export function MSSQLAdapter(): Adapter {
  return {
    async createSession(data): Promise<AdapterSession> {
      const { sessionToken, userId, expires } = data;

      try {
        console.log('[NextAuth Adapter] createSession start', { userId });

        const expiresDate = new Date(expires);

        await query(
          `INSERT INTO [sessions] ([id], [sessionToken], [userId], [expires])
           VALUES (NEWID(), @sessionToken, @userId, @expires)`,
          {
            sessionToken,
            userId,
            expires: expiresDate,
          }
        );

        console.log('[NextAuth Adapter] createSession success');

        return {
          sessionToken,
          userId,
          expires: expiresDate,
        };
      } catch (error) {
        console.error('[NextAuth Adapter] createSession error:', error);
        throw error;
      }
    },

    async getSessionAndUser(sessionToken): Promise<{ session: AdapterSession; user: AdapterUser } | null> {
      try {
        console.log('[NextAuth Adapter] getSessionAndUser start');

        const rows = await query<{
          sessionToken: string;
          userId: string;
          expires: string;
          id_usuario: string;
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
          console.log('[NextAuth Adapter] getSessionAndUser: not found');
          return null;
        }

        const row = rows[0];
        console.log('[NextAuth Adapter] getSessionAndUser success');

        return {
          session: {
            sessionToken: row.sessionToken,
            userId: String(row.userId),
            expires: new Date(row.expires),
          },
          user: {
            id: String(row.id_usuario),
            email: row.email,
            name: row.nombre_completo,
            image: null,
            emailVerified: null,
          },
        };
      } catch (error) {
        console.error('[NextAuth Adapter] getSessionAndUser error:', error);
        throw error;
      }
    },

    async updateSession(data): Promise<AdapterSession | null> {
      const { sessionToken, expires } = data;

      try {
        console.log('[NextAuth Adapter] updateSession start');

        const expiresDate = new Date(expires);

        await query(
          `UPDATE [sessions]
           SET [expires] = @expires, [updatedAt] = GETUTCDATE()
           WHERE [sessionToken] = @sessionToken`,
          {
            sessionToken,
            expires: expiresDate,
          }
        );

        const rows = await query<{
          sessionToken: string;
          userId: string;
          expires: string;
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
        console.log('[NextAuth Adapter] updateSession success');

        return {
          sessionToken: row.sessionToken,
          userId: String(row.userId),
          expires: new Date(row.expires),
        };
      } catch (error) {
        console.error('[NextAuth Adapter] updateSession error:', error);
        throw error;
      }
    },

    async deleteSession(sessionToken): Promise<void> {
      try {
        console.log('[NextAuth Adapter] deleteSession start');

        await query(
          `DELETE FROM [sessions] WHERE [sessionToken] = @sessionToken`,
          { sessionToken }
        );

        console.log('[NextAuth Adapter] deleteSession success');
      } catch (error) {
        console.error('[NextAuth Adapter] deleteSession error:', error);
        throw error;
      }
    },

    // Métodos no implementados
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
