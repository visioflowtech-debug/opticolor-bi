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
          return;
        }

        // Verificar sesión via endpoint seguro
        const response = await fetch('/api/auth/session-check', {
          method: 'GET',
          credentials: 'include',
        });

        const isValid = response.ok && response.status === 200;

        setIsAuthed(isValid);

        if (isDashboard && !isValid) {
          router.push('/auth/v2/login');
          return;
        }

        if (isLoginPage && isValid) {
          router.push('/dashboard/default');
          return;
        }

        setIsChecking(false);
      } catch {
        setIsChecking(false);
        if (pathname.startsWith('/dashboard')) {
          router.push('/auth/v2/login');
        }
      }
    };

    checkAuth();
  }, [pathname, router]);

  if (isChecking && pathname.startsWith('/dashboard')) {
    return <div>Verificando sesión...</div>;
  }

  return <>{children}</>;
}
