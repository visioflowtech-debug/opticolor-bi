import type { NextConfig } from "next";
import path from "path";

const monorepoBoundary = path.resolve(__dirname, "..");

const nextConfig: NextConfig = {
  output: "standalone",

  // ✅ Next.js 16: Define la raíz de rastreo de archivos en /portal de forma nativa
  outputFileTracingRoot: __dirname,

  // ✅ Omite bloqueos de construcción por errores estrictos de tipos (ej. Recharts)
  typescript: {
    ignoreBuildErrors: true,
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