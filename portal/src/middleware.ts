import { auth } from '@/app/api/auth/[...nextauth]/route';
import { NextResponse } from 'next/server';

export default auth((req) => {
  const pathname = req.nextUrl.pathname;
  const isLoginPage = pathname.startsWith('/auth');
  const isDashboard = pathname.startsWith('/dashboard');
  const isAuth = !!req.auth;

  console.log('[Middleware] Verificando:', {
    path: pathname,
    isAuth,
    user: isAuth ? (req.auth?.user as any)?.email : 'no autenticado',
  });

  // Proteger rutas de dashboard
  if (isDashboard && !isAuth) {
    console.log('[Middleware] Redirigiendo a login');
    return NextResponse.redirect(new URL('/auth/v2/login', req.url));
  }

  // Si está autenticado en login, ir a dashboard
  if (isLoginPage && isAuth) {
    console.log('[Middleware] Redirigiendo a dashboard');
    return NextResponse.redirect(new URL('/dashboard/default', req.url));
  }

  return NextResponse.next();
});

export const config = {
  matcher: ['/dashboard/:path*', '/auth/:path*'],
};
