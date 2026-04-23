import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';
import { jwtVerify } from 'jose';

const secret = new TextEncoder().encode(process.env.NEXTAUTH_SECRET || '');

export async function middleware(req: NextRequest) {
  const pathname = req.nextUrl.pathname;
  const isLoginPage = pathname.startsWith('/auth');
  const isDashboard = pathname.startsWith('/dashboard');

  // Obtener JWT de la cookie
  const token =
    req.cookies.get('next-auth.session-token')?.value ||
    req.cookies.get('__Secure-next-auth.session-token')?.value;

  let isAuth = false;

  if (token) {
    try {
      await jwtVerify(token, secret);
      isAuth = true;
      console.log('[Middleware] Token válido encontrado');
    } catch (error) {
      console.log('[Middleware] Token inválido o expirado');
      isAuth = false;
    }
  }

  console.log('[Middleware]', { path: pathname, isAuth, hasToken: !!token });

  // Proteger rutas de dashboard
  if (isDashboard && !isAuth) {
    console.log('[Middleware] Redirigiendo a login (sin sesión válida)');
    return NextResponse.redirect(new URL('/auth/v2/login', req.url));
  }

  // Si está autenticado en login, ir a dashboard
  if (isLoginPage && isAuth) {
    console.log('[Middleware] Redirigiendo a dashboard (sesión válida)');
    return NextResponse.redirect(new URL('/dashboard/default', req.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: ['/dashboard/:path*', '/auth/:path*'],
};
