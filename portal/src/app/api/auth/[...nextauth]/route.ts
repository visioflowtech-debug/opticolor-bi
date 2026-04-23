import NextAuth from 'next-auth';
import Credentials from 'next-auth/providers/credentials';
import bcrypt from 'bcryptjs';
import { query } from '@/lib/db';
import { MSSQLAdapter } from '@/lib/nextauth-adapter';

export const { handlers, auth } = NextAuth({
  secret: process.env.NEXTAUTH_SECRET,
  providers: [
    Credentials({
      credentials: {
        email: { label: 'Email', type: 'email' },
        password: { label: 'Password', type: 'password' },
      },
      async authorize(credentials) {
        if (!credentials?.email || !credentials?.password) {
          console.warn('[NextAuth] Credenciales vacías');
          return null;
        }

        try {
          console.log('[NextAuth] Intentando autenticar:', credentials.email);

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

          console.log('[NextAuth] Query resultado:', rows.length, 'registros');

          if (!rows.length) {
            console.warn('[NextAuth] Usuario no encontrado:', credentials.email);
            return null;
          }

          const user = rows[0];
          console.log('[NextAuth] Usuario encontrado:', user.nombre_completo, 'ID:', user.id_usuario);

          const isValidPassword = await bcrypt.compare(
            credentials.password as string,
            user.password_hash
          );

          console.log('[NextAuth] Password válido:', isValidPassword);

          if (!isValidPassword) {
            console.warn('[NextAuth] Password incorrecto');
            return null;
          }

          console.log('[NextAuth] Autenticación exitosa para:', credentials.email, '- ID:', user.id_usuario);
          return {
            id: String(user.id_usuario),
            email: user.email,
            name: user.nombre_completo,
            nombre_rol: user.nombre_rol,
            nivel_jerarquico: user.nivel_jerarquico,
          };
        } catch (error) {
          console.error('[NextAuth] Error en authorize:', error instanceof Error ? error.message : String(error));
          throw error;
        }
      },
    }),
  ],
  callbacks: {
    jwt({ token, user }) {
      if (user) {
        token.id = user.id;
        token.email = user.email;
        token.name = user.name;
        token.nombre_rol = (user as any).nombre_rol;
        token.nivel_jerarquico = (user as any).nivel_jerarquico;
      }
      return token;
    },
    session({ session, token }) {
      if (session.user) {
        session.user.id = token.id as string;
        session.user.email = token.email as string;
        session.user.name = token.name as string;
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
  cookies: {
    sessionToken: {
      name: process.env.NODE_ENV === 'production'
        ? '__Secure-next-auth.session-token'
        : 'next-auth.session-token',
      options: {
        httpOnly: true,
        secure: process.env.NODE_ENV === 'production',
        sameSite: 'lax',
        path: '/',
        maxAge: 24 * 60 * 60,
      },
    },
  },
});

export const { GET, POST } = handlers;
