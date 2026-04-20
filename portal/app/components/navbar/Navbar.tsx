'use client';

export default function Navbar() {
  return (
    <nav className="fixed top-0 left-0 right-0 bg-white border-b border-gray-200 shadow-sm z-50 h-16 flex items-center px-6">
      <div className="flex-1 flex items-center gap-4">
        <div className="w-10 h-10 bg-primary-500 rounded-lg flex items-center justify-center">
          <span className="text-white font-bold text-lg">📊</span>
        </div>
        <span className="text-xl font-bold text-primary-600">Opticolor BI</span>
      </div>
      <div className="flex items-center gap-4">
        <p className="text-sm font-medium text-foreground">Usuario</p>
        <button className="px-4 py-2 text-sm bg-red-50 text-red-600 hover:bg-red-100 rounded-lg">
          Salir
        </button>
      </div>
    </nav>
  );
}
