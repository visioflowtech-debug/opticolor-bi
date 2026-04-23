import { auth } from '@/app/api/auth/[...nextauth]/route';
import { cookies } from 'next/headers';

export async function GET() {
  const session = await auth();
  const allCookies = (await cookies()).getAll();

  return Response.json({
    session,
    cookies: allCookies.map(c => ({
      name: c.name,
      value: c.value ? c.value.substring(0, 50) + '...' : null,
    })),
    nodeEnv: process.env.NODE_ENV,
  });
}
