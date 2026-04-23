import { auth } from '@/config/auth';
import { NextResponse } from 'next/server';

export default auth((req) => {
  const isAuth = !!req.auth;
  const isLoginPage = req.nextUrl.pathname.startsWith('/auth');
  const isDashboard = req.nextUrl.pathname.startsWith('/dashboard');

  console.log('[Middleware]', {
    path: req.nextUrl.pathname,
    isAuth,
    isLoginPage,
    isDashboard,
  });

  // Proteger rutas de dashboard
  if (isDashboard && !isAuth) {
    console.log('[Middleware] Redirigiendo a login - no autenticado');
    return NextResponse.redirect(new URL('/auth/v2/login', req.url));
  }

  // Si está autenticado en login, ir a dashboard
  if (isLoginPage && isAuth) {
    console.log('[Middleware] Redirigiendo a dashboard - ya autenticado');
    return NextResponse.redirect(new URL('/dashboard/default', req.url));
  }

  // Permitir acceso
  return undefined;
});

export const config = {
  matcher: ['/dashboard/:path*', '/auth/:path*'],
};
