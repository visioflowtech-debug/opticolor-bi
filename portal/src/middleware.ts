import { auth } from '@/app/api/auth/[...nextauth]/route';
import { NextResponse } from 'next/server';
import type { NextRequest } from 'next/server';

export async function middleware(req: NextRequest) {
  const pathname = req.nextUrl.pathname;
  const isLoginPage = pathname.startsWith('/auth');
  const isDashboard = pathname.startsWith('/dashboard');

  // Obtener sesión usando auth() de NextAuth
  const session = await auth();
  const hasSession = !!session;

  console.log('[Middleware]', {
    path: pathname,
    hasSession,
    user: hasSession ? (session?.user as any)?.email : 'no autenticado',
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
