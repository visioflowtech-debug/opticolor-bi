import { NextRequest, NextResponse } from 'next/server';
import { jwtVerify } from 'jose';

const secret = new TextEncoder().encode(process.env.NEXTAUTH_SECRET || '');

export async function GET(req: NextRequest) {
  const logs: string[] = [];

  // Obtener JWT de la cookie
  const token =
    req.cookies.get('next-auth.session-token')?.value ||
    req.cookies.get('__Secure-next-auth.session-token')?.value;

  logs.push(`[TEST] Token encontrado: ${!!token}`);

  if (token) {
    logs.push(`[TEST] Token length: ${token.length}`);
    logs.push(`[TEST] Token start: ${token.substring(0, 50)}...`);

    try {
      const verified = await jwtVerify(token, secret);
      logs.push(`[TEST] ✅ JWT válido`);
      logs.push(`[TEST] Payload: ${JSON.stringify(verified.payload)}`);
    } catch (error) {
      logs.push(`[TEST] ❌ JWT inválido: ${error instanceof Error ? error.message : String(error)}`);
    }
  } else {
    logs.push('[TEST] ❌ No hay token en cookies');
    logs.push(`[TEST] Cookies disponibles: ${Array.from(req.cookies).map(c => c[0]).join(', ')}`);
  }

  return NextResponse.json({ logs });
}
