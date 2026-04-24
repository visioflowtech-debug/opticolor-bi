import { NextResponse } from 'next/server';
import { jwtVerify } from 'jose';
import { cookies } from 'next/headers';

const secret = new TextEncoder().encode(process.env.NEXTAUTH_SECRET || '');

export async function GET() {
  try {
    const cookieStore = await cookies();
    const token =
      cookieStore.get('next-auth.session-token')?.value ||
      cookieStore.get('__Secure-next-auth.session-token')?.value;

    if (!token) {
      return NextResponse.json({ valid: false }, { status: 401 });
    }

    const { payload } = await jwtVerify(token, secret);

    return NextResponse.json(
      {
        valid: true,
        role: payload.role,
        nivel: payload.nivel
      },
      { status: 200 }
    );
  } catch {
    return NextResponse.json({ valid: false }, { status: 401 });
  }
}
