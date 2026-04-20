import Navbar from '../components/navbar/Navbar';
import Sidebar from '../components/sidebar/Sidebar';

export default function DashboardLayout({
  children,
}: {
  children: React.ReactNode;
}) {
  return (
    <div className="flex flex-col h-screen bg-gray-50">
      <Navbar />
      <div className="flex flex-1 overflow-hidden pt-16">
        <Sidebar />
        <main className="flex-1 overflow-y-auto ml-64 p-6">
          {children}
        </main>
      </div>
    </div>
  );
}
