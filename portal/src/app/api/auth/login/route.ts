import { query } from '@/lib/db';
import bcrypt from 'bcryptjs';
import { jwtVerify, SignJWT } from 'jose';
import { cookies } from 'next/headers';

const secret = new TextEncoder().encode(process.env.NEXTAUTH_SECRET || '');

export async function POST(req: Request) {
  try {
    const body = await req.json();
    const { email, password } = body;

    console.log('[Login API] Autenticando:', email);

    // Verificar credenciales
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
      { email }
    );

    if (!rows.length) {
      console.log('[Login API] Usuario no encontrado:', email);
      return Response.json({ error: 'Usuario no encontrado' }, { status: 401 });
    }

    const user = rows[0];
    const isValid = await bcrypt.compare(password, user.password_hash);

    if (!isValid) {
      console.log('[Login API] Password incorrecto para:', email);
      return Response.json({ error: 'Password incorrecto' }, { status: 401 });
    }

    console.log('[Login API] Autenticación exitosa para:', email);

    // Crear JWT en formato NextAuth
    const now = Math.floor(Date.now() / 1000);
    const expires = now + 24 * 60 * 60; // 24 horas

    const token = await new SignJWT({
      sub: String(user.id_usuario),
      email: user.email,
      name: user.nombre_completo,
      iat: now,
      exp: expires,
      jti: Math.random().toString(36).substring(2, 15),
      // Agregar claims personalizadas para NextAuth
    } as any)
      .setProtectedHeader({ alg: 'HS256', typ: 'JWT' })
      .sign(secret);

    console.log('[Login API] JWT creado, expires:', new Date(expires * 1000).toISOString());

    // Guardar en cookie
    const cookieStore = await cookies();
    const isProduction = process.env.NODE_ENV === 'production';
    const cookieName = isProduction
      ? '__Secure-next-auth.session-token'
      : 'next-auth.session-token';

    cookieStore.set(cookieName, token, {
      httpOnly: true,
      secure: isProduction,
      sameSite: 'lax',
      path: '/',
      maxAge: 24 * 60 * 60,
    });

    console.log('[Login API] Cookie guardada:', cookieName);

    // Verificar que la cookie se creó correctamente
    const verifyToken = cookieStore.get(cookieName);
    console.log('[Login API] Cookie verificada:', verifyToken ? 'OK' : 'FALLO');

    return Response.json({
      ok: true,
      user: {
        id: String(user.id_usuario),
        email: user.email,
        name: user.nombre_completo,
        nombre_rol: user.nombre_rol,
        nivel_jerarquico: user.nivel_jerarquico,
      },
    });
  } catch (error) {
    console.error('[Login API] Error:', error);
    return Response.json(
      { error: error instanceof Error ? error.message : 'Error interno' },
      { status: 500 }
    );
  }
}
