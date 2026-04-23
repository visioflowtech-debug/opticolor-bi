'use client';

import { useEffect, useState } from 'react';
import { useRouter, usePathname } from 'next/navigation';

export default function MainLayout({ children }: { children: React.ReactNode }) {
  const router = useRouter();
  const pathname = usePathname();
  const [isChecking, setIsChecking] = useState(true);
  const [isAuthed, setIsAuthed] = useState(false);

  useEffect(() => {
    const checkAuth = async () => {
      try {
        const isLoginPage = pathname.startsWith('/auth');
        const isDashboard = pathname.startsWith('/dashboard');

        if (!isLoginPage && !isDashboard) {
          setIsChecking(false);
          return; // No protegemos otras rutas
        }

        const response = await fetch('/api/debug/middleware-test');
        const data = await response.json();
        const hasValidToken = data.logs.some((log: string) => log.includes('✅ JWT válido'));

        setIsAuthed(hasValidToken);

        if (isDashboard && !hasValidToken) {
          console.log('[MainLayout] Redirigiendo a login (sin sesión)');
          router.push('/auth/v2/login');
        } else if (isLoginPage && hasValidToken) {
          console.log('[MainLayout] Redirigiendo a dashboard (con sesión)');
          router.push('/dashboard/default');
        }
      } catch (error) {
        console.error('[MainLayout] Error:', error);
        if (pathname.startsWith('/dashboard')) {
          router.push('/auth/v2/login');
        }
      } finally {
        setIsChecking(false);
      }
    };

    checkAuth();
  }, [pathname, router]);

  if (isChecking && pathname.startsWith('/dashboard')) {
    return <div>Verificando sesión...</div>;
  }

  return <>{children}</>;
}
