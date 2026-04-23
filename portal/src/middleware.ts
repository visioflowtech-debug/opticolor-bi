import { auth } from '@/config/auth';
import { NextResponse } from 'next/server';

export default auth((req) => {
  const isAuth = !!req.auth;
  const isLoginPage = req.nextUrl.pathname.startsWith('/auth');
  const isDashboard = req.nextUrl.pathname.startsWith('/dashboard');

  if (isDashboard && !isAuth) {
    return NextResponse.redirect(new URL('/auth/v2/login', req.url));
  }

  if (isLoginPage && isAuth) {
    return NextResponse.redirect(new URL('/dashboard/default', req.url));
  }
});

export const config = {
  matcher: ['/dashboard/:path*', '/auth/:path*'],
};
