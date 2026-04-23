import NextAuth from 'next-auth';
import Credentials from 'next-auth/providers/credentials';
import bcrypt from 'bcryptjs';
import { query } from '@/lib/db';

export const { handlers, auth, signIn, signOut } = NextAuth({
  providers: [
    Credentials({
      credentials: {
        email: { label: 'Email', type: 'email' },
        password: { label: 'Password', type: 'password' },
      },
      async authorize(credentials) {
        if (!credentials?.email || !credentials?.password) {
          return null;
        }

        try {
          const rows = await query<{
            id_usuario: number;
            email: string;
            nombre_completo: string;
            password_hash: string;
            nombre_rol: string;
            nivel_jerarquico: number;
          }>(
            `SELECT id_usuario, email, nombre_completo, password_hash, nombre_rol, nivel_jerarquico
             FROM Vw_Usuario_Accesos
             WHERE email = @email`,
            { email: credentials.email }
          );

          if (!rows.length) {
            return null;
          }

          const user = rows[0];
          const isValidPassword = await bcrypt.compare(
            credentials.password as string,
            user.password_hash
          );

          if (!isValidPassword) {
            return null;
          }

          return {
            id: String(user.id_usuario),
            email: user.email,
            name: user.nombre_completo,
            nombre_rol: user.nombre_rol,
            nivel_jerarquico: user.nivel_jerarquico,
          };
        } catch (error) {
          console.error('[NextAuth] Error en authorize:', error);
          return null;
        }
      },
    }),
  ],
  callbacks: {
    jwt({ token, user }) {
      if (user) {
        token.nombre_rol = (user as any).nombre_rol;
        token.nivel_jerarquico = (user as any).nivel_jerarquico;
      }
      return token;
    },
    session({ session, token }) {
      if (session.user) {
        (session.user as any).nombre_rol = token.nombre_rol;
        (session.user as any).nivel_jerarquico = token.nivel_jerarquico;
      }
      return session;
    },
  },
  pages: {
    signIn: '/auth/v2/login',
  },
  session: {
    strategy: 'jwt',
    maxAge: 24 * 60 * 60,
  },
});
