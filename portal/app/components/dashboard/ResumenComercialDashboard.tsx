'use client';

import { LineChart, Line, XAxis, YAxis, CartesianGrid, Tooltip, Legend, ResponsiveContainer } from 'recharts';

const mockData = [
  { fecha: '2026-04-01', venta_total: 125000, cobrado: 110000, otif: 96.2 },
  { fecha: '2026-04-02', venta_total: 132000, cobrado: 115000, otif: 97.1 },
  { fecha: '2026-04-03', venta_total: 128000, cobrado: 112000, otif: 96.8 },
  { fecha: '2026-04-04', venta_total: 135000, cobrado: 118000, otif: 97.5 },
  { fecha: '2026-04-05', venta_total: 142000, cobrado: 125000, otif: 98.1 },
  { fecha: '2026-04-06', venta_total: 138000, cobrado: 121000, otif: 97.8 },
  { fecha: '2026-04-07', venta_total: 145000, cobrado: 128000, otif: 98.3 },
];

export default function ResumenComercialDashboard() {
  return (
    <div className="space-y-6">
      <div className="grid grid-cols-1 md:grid-cols-5 gap-4">
        <div className="bg-white p-4 rounded-lg shadow">
          <p className="text-sm text-foreground/60">Venta Total</p>
          <p className="text-2xl font-bold text-primary-600">$142,000</p>
        </div>
        <div className="bg-white p-4 rounded-lg shadow">
          <p className="text-sm text-foreground/60">Cobrado</p>
          <p className="text-2xl font-bold text-primary-600">$125,000</p>
        </div>
        <div className="bg-white p-4 rounded-lg shadow">
          <p className="text-sm text-foreground/60">Ticket Promedio</p>
          <p className="text-2xl font-bold text-primary-600">$920</p>
        </div>
        <div className="bg-white p-4 rounded-lg shadow">
          <p className="text-sm text-foreground/60">Run Rate</p>
          <p className="text-2xl font-bold text-primary-600">99.5%</p>
        </div>
        <div className="bg-white p-4 rounded-lg shadow">
          <p className="text-sm text-foreground/60">OTIF</p>
          <p className="text-2xl font-bold text-primary-600">98.1%</p>
        </div>
      </div>

      <div className="bg-white p-6 rounded-lg shadow">
        <h2 className="text-lg font-semibold mb-4">Tendencia 7 días</h2>
        <ResponsiveContainer width="100%" height={300}>
          <LineChart data={mockData}>
            <CartesianGrid strokeDasharray="3 3" />
            <XAxis dataKey="fecha" />
            <YAxis />
            <Tooltip />
            <Legend />
            <Line type="monotone" dataKey="venta_total" stroke="#1A3A6B" name="Venta Total" />
            <Line type="monotone" dataKey="cobrado" stroke="#2B6CB0" name="Cobrado" />
            <Line type="monotone" dataKey="otif" stroke="#D4A017" name="OTIF" />
          </LineChart>
        </ResponsiveContainer>
      </div>
    </div>
  );
}
