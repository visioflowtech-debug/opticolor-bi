import { NextResponse } from 'next/server';
import { cookies } from 'next/headers';

export async function POST() {
  const cookieStore = await cookies();

  const response = NextResponse.json(
    { success: true },
    { status: 200 }
  );

  // Borrar ambas variantes de la cookie JWT
  response.cookies.set('next-auth.session-token', '', {
    expires: new Date(0),
    path: '/',
  });

  response.cookies.set('__Secure-next-auth.session-token', '', {
    expires: new Date(0),
    path: '/',
    secure: true,
  });

  return response;
}
