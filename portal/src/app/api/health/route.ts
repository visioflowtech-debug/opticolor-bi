import { NextResponse } from 'next/server';

export async function GET() {
  return NextResponse.json(
    {
      status: 'ok',
      service: 'opticolor-bi-portal',
      timestamp: new Date().toISOString(),
    },
    { status: 200 }
  );
}
