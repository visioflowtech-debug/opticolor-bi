import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export function middleware(req: NextRequest) {
  const pathname = req.nextUrl.pathname;
  const isLoginPage = pathname.startsWith('/auth');
  const isDashboard = pathname.startsWith('/dashboard');

  // Obtener token JWT de las cookies
  const token = req.cookies.get('next-auth.session-token')?.value ||
                req.cookies.get('__Secure-next-auth.session-token')?.value;

  const hasSession = !!token;

  console.log('[Middleware]', {
    path: pathname,
    hasSession,
    cookieName: req.cookies.get('next-auth.session-token') ? 'next-auth.session-token' :
                req.cookies.get('__Secure-next-auth.session-token') ? '__Secure-next-auth.session-token' : 'ninguna',
  });

  // Proteger rutas de dashboard
  if (isDashboard && !hasSession) {
    console.log('[Middleware] Redirigiendo a login - sin sesión');
    return NextResponse.redirect(new URL('/auth/v2/login', req.url));
  }

  // Si está autenticado en login, ir a dashboard
  if (isLoginPage && hasSession) {
    console.log('[Middleware] Redirigiendo a dashboard - sesión presente');
    return NextResponse.redirect(new URL('/dashboard/default', req.url));
  }

  return NextResponse.next();
}

export const config = {
  matcher: ['/dashboard/:path*', '/auth/:path*'],
};
