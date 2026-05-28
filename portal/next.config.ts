import type { NextConfig } from "next";
import path from "path";

const monorepoBoundary = path.resolve(__dirname, "..");

const nextConfig: NextConfig = {
  output: "standalone",

  // ✅ Next.js 16: Define la raíz de rastreo de archivos en /portal de forma nativa
  outputFileTracingRoot: __dirname,

  // ✅ Habilita la verificación estricta de tipos de TypeScript durante la construcción
  typescript: {
    ignoreBuildErrors: false,
  },

  async headers() {
    return [
      {
        source: "/:path*",
        headers: [
          {
            key: "X-Frame-Options",
            value: "DENY",
          },
          {
            key: "X-Content-Type-Options",
            value: "nosniff",
          },
          {
            key: "Referrer-Policy",
            value: "strict-origin-when-cross-origin",
          },
          {
            key: "Strict-Transport-Security",
            value: "max-age=31536000; includeSubDomains; preload",
          },
          {
            key: "Content-Security-Policy",
            value: "default-src 'self'; script-src 'self' 'unsafe-inline' 'unsafe-eval'; style-src 'self' 'unsafe-inline'; img-src 'self' data:; connect-src 'self'; frame-ancestors 'none';",
          },
        ],
      },
    ];
  },

  // 💡 Nota: El bloque 'eslint' fue removido en Next.js 16 porque 'next build' 
  // ya no ejecuta linting automáticamente. No es necesario configurarlo aquí.

  webpack(config) {
    // Anchor webpack's compilation context and module resolution root to /portal.
    // Without this, webpack may inherit the monorepo root's package-lock.json as
    // the workspace root, distorting CSS asset path resolution.
    config.context = __dirname;
    config.resolve.roots = [__dirname];

    config.watchOptions = {
      // Prevent the file watcher from escaping /portal into monorepo siblings.
      // etl/.venv alone is 144 MB — scanning it causes Windows handle exhaustion.
      ignored: [
        "**/node_modules/**",
        "**/.git/**",
        `${monorepoBoundary}/etl/**`,
        `${monorepoBoundary}/sql/**`,
        `${monorepoBoundary}/powerbi/**`,
        `${monorepoBoundary}/memory/**`,
        `${monorepoBoundary}/docs/**`,
      ],
      poll: false,
    };
    return config;
  },
};

export default nextConfig;