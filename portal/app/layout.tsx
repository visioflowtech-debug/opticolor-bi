import type { Metadata } from "next";
import "./globals.css";
import SessionWrapper from './components/SessionWrapper';

export const metadata: Metadata = {
  title: "Opticolor BI - Portal de Inteligencia de Datos",
  description: "Dashboard de BI para Opticolor Venezuela - Ventas, Cartera, Clínica, Inventario",
  icons: {
    icon: [{ url: '/favicon.ico' }],
  },
};

export default function RootLayout({
  children,
}: Readonly<{
  children: React.ReactNode;
}>) {
  return (
    <html lang="es" className="h-full antialiased">
      <body className="min-h-full flex flex-col bg-gray-50">
        <SessionWrapper>
          {children}
        </SessionWrapper>
      </body>
    </html>
  );
}
