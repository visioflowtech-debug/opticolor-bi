import { Metadata } from 'next';

export const metadata: Metadata = {
  title: 'Control de Cartera | Opticolor BI',
};

export default function ControlCarteraPage() {
  return (
    <div className="space-y-6">
      <div>
        <h1 className="text-3xl font-bold text-foreground">💰 Control de Cartera y Saldos</h1>
        <p className="text-foreground/60 mt-2">
          Facturación, cobranzas y análisis de crédito
        </p>
      </div>

      <div className="bg-white rounded-lg shadow p-8 text-center border-2 border-dashed border-gray-300">
        <div className="mb-4">
          <svg className="w-16 h-16 mx-auto text-secondary-400" fill="none" stroke="currentColor" viewBox="0 0 24 24">
            <path strokeLinecap="round" strokeLinejoin="round" strokeWidth={2} d="M12 6v6m0 0v6m0-6h6m-6 0H6" />
          </svg>
        </div>
        <h3 className="text-xl font-semibold text-foreground mb-2">Dashboard en Construcción</h3>
        <p className="text-foreground/60 mb-4">
          Semana 2.2: Se conectarán datos reales de la BD y Recharts
        </p>
        <div className="inline-block bg-secondary-100 text-secondary-700 px-4 py-2 rounded-lg text-sm">
          Status: Mock Data ✓ | Queries SQL: ⏳
        </div>
      </div>
    </div>
  );
}
