import { Metadata } from 'next';
import ResumenComercialDashboard from '@/components/dashboard/ResumenComercialDashboard';

export const metadata: Metadata = {
  title: 'Resumen Comercial | Opticolor BI',
  description: 'Dashboard de resumen comercial',
};

export default function DashboardHomePage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-foreground">📊 Resumen Comercial</h1>
        <p className="text-foreground/60 mt-2">
          Vista general de ventas, cobranzas y eficiencia operacional
        </p>
      </div>
      <ResumenComercialDashboard />
    </div>
  );
}
