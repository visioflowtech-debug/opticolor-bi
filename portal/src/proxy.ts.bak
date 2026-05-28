import { withAuth } from "next-auth/middleware";
import { NextResponse } from "next/server";

function applySecurityHeaders(res: NextResponse): NextResponse {
    res.headers.set("Content-Security-Policy", "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none';");
    res.headers.set("X-Frame-Options", "DENY");
    res.headers.set("X-Content-Type-Options", "nosniff");
    res.headers.set("Strict-Transport-Security", "max-age=31536000; includeSubDomains; preload");
    res.headers.set("Referrer-Policy", "strict-origin-when-cross-origin");
    return res;
}

export default withAuth(
    function middleware(req) {
        const token = req.nextauth.token;
        const path = req.nextUrl.pathname;

        const isSupervisor = token?.nivel === 4 || token?.rol === "SUPERVISOR";

        // Proteger rutas de Configuración para el rol SUPERVISOR
        if (isSupervisor && (path.startsWith("/dashboard/usuarios") || path.startsWith("/dashboard/sucursales"))) {
            return applySecurityHeaders(NextResponse.redirect(new URL("/dashboard/resumen-comercial", req.url)));
        }

        return applySecurityHeaders(NextResponse.next());
    },
    {
        callbacks: {
            // Bloquea la carga de página si el token no existe o ya expiró.
            // Evita el limbo visual donde se muestra "Usuario" antes del redirect.
            authorized: ({ token }) => {
                if (!token) return false;
                if (typeof token.exp === "number" && Date.now() / 1000 > token.exp) return false;
                return true;
            },
        },
        pages: {
            signIn: "/login",
        },
    }
);

export const config = {
    // Excluye: rutas de API, assets de Next.js (_next/static, _next/image),
    // favicon y la página de login (evita bucles de redirección).
    // Los archivos de /public se sirven en rutas raíz (/logo.png) y Next.js
    // los optimiza antes de llegar al middleware; no necesitan exclusión explícita.
    matcher: ["/((?!api|_next/static|_next/image|favicon\\.ico|login).*)"],
};
