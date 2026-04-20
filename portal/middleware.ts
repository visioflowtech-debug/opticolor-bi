import { NextRequest, NextResponse } from "next/server";

export const config = {
  matcher: ["/dashboard/:path*"],
};

// Middleware temporal deshabilitado - usar App Router protection en su lugar
export function middleware(request: NextRequest) {
  return NextResponse.next();
}
