'use client';

import { useSearchParams } from 'next/navigation';
import Link from 'next/link';
import { Suspense } from 'react';

export const dynamic = 'force-dynamic';

function ErrorContent() {
  const searchParams = useSearchParams();
  const error = searchParams.get('error');

  const errorMessages: Record<string, string> = {
    CredentialsSignin: 'Email o contraseña incorrectos',
    AccessDenied: 'Acceso denegado',
    OAuthSignin: 'Error conectando con proveedor OAuth',
    OAuthCallback: 'Error en callback OAuth',
    EmailSigninEmail: 'Error enviando email de confirmación',
    SessionCallback: 'Error en callback de sesión',
    Default: 'Error desconocido',
  };

  const message = error ? errorMessages[error] || errorMessages.Default : errorMessages.Default;

  return (
    <div className="min-h-screen bg-gradient-to-br from-red-50 to-primary-50 flex items-center justify-center p-4">
      <div className="w-full max-w-md bg-white rounded-lg shadow-lg p-8 text-center">
        <div className="mb-4">
          <svg className="w-16 h-16 mx-auto text-red-500" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 8v4m0 4v.01M21 12a9 9 0 11-18 0 9 9 0 0118 0z" />
          </svg>
        </div>
        <h1 className="text-2xl font-bold text-foreground mb-2">Error de Autenticación</h1>
        <p className="text-foreground/70 mb-6">{message}</p>
        <Link
          href="/auth/login"
          className="inline-block bg-primary-500 hover:bg-primary-600 text-white font-semibold py-2 px-6 rounded-lg transition"
        >
          Volver al Login
        </Link>
      </div>
    </div>
  );
}

export default function AuthErrorPage() {
  return (
    <Suspense fallback={<div>Cargando...</div>}>
      <ErrorContent />
    </Suspense>
  );
}
