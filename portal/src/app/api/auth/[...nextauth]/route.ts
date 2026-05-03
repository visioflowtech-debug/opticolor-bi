import NextAuth from 'next-auth';
import CredentialsProvider from 'next-auth/providers/credentials';
import bcrypt from 'bcryptjs';
import type { JWT } from 'next-auth/jwt';
import type { User } from 'next-auth';
import { query } from '@/lib/db';

export const authOptions = {
  secret: process.env.NEXTAUTH_SECRET,
  providers: [
    CredentialsProvider({
      name: 'Credentials',
      credentials: {
        email: { label: 'Email', type: 'email' },
        password: { label: 'Password', type: 'password' },
      },
      async authorize(credentials) {
        console.log('[NextAuth Credentials] authorize called with:', { email: credentials?.email });

        if (!credentials?.email || !credentials?.password) {
          console.warn('[NextAuth Credentials] Credenciales vacías');
          return null;
        }

        try {
          console.log('[NextAuth Credentials] Intentando autenticar:', credentials.email);

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

          console.log('[NextAuth Credentials] Query resultado:', rows.length, 'registros');

          if (!rows.length) {
            console.warn('[NextAuth Credentials] Usuario no encontrado:', credentials.email);
            return null;
          }

          const user = rows[0];
          console.log('[NextAuth Credentials] Usuario encontrado:', user.nombre_completo, 'ID:', user.id_usuario);

          const isValidPassword = await bcrypt.compare(
            credentials.password as string,
            user.password_hash
          );

          console.log('[NextAuth Credentials] Password válido:', isValidPassword);

          if (!isValidPassword) {
            console.warn('[NextAuth Credentials] Password incorrecto');
            return null;
          }

          console.log('[NextAuth Credentials] Autenticación exitosa para:', credentials.email, '- ID:', user.id_usuario);
          const result = {
            id: String(user.id_usuario),
            email: user.email,
            name: user.nombre_completo,
            nombre_rol: user.nombre_rol,
            nivel_jerarquico: user.nivel_jerarquico,
          };
          console.log('[NextAuth Credentials] Retornando usuario:', result);
          return result;
        } catch (error) {
          console.error('[NextAuth Credentials] Error en authorize:', error instanceof Error ? error.message : String(error));
          throw error;
        }
      },
    }),
  ],
  callbacks: {
    async jwt({ token, user }: { token: JWT; user?: User }) {
      if (user) {
        token.id = user.id || (user as any).id_usuario;
        token.email = user.email;
        token.name = user.name;
        token.nombre_rol = (user as any).nombre_rol;
        token.nivel_jerarquico = (user as any).nivel_jerarquico;
      }
      return token;
    },
    async session({ session, token }) {
      if (token && session.user) {
        (session.user as any).id = token.id;
        (session.user as any).email = token.email;
        (session.user as any).name = token.name;
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
    strategy: 'jwt' as const,
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
        sameSite: 'lax' as const,
        path: '/',
        maxAge: 24 * 60 * 60,
      },
    },
  },
};

const handler = NextAuth(authOptions);
export { handler as GET, handler as POST };
