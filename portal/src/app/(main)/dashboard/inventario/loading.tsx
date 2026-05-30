import { Card, CardContent, CardHeader } from "@/components/ui/card";
import { Skeleton } from "@/components/ui/skeleton";

function KpiSkeleton() {
  return (
    <div className="overflow-hidden rounded-2xl border bg-card p-5 shadow-md">
      <div className="flex items-start justify-between gap-3">
        <Skeleton className="h-3 w-24" />
        <Skeleton className="h-9 w-9 rounded-full" />
      </div>
      <Skeleton className="mt-4 h-7 w-28" />
      <Skeleton className="mt-2 h-3 w-20" />
    </div>
  );
}

export default function Loading() {
  return (
    <div className="flex flex-col gap-6 overflow-hidden">
      {/* Fila 1: 6 KPI Cards */}
      <div className="grid grid-cols-1 gap-4 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6">
        {Array.from({ length: 6 }).map((_, i) => (
          <KpiSkeleton key={i} />
        ))}
      </div>

      {/* Fila 2: Tabla + Dispersión */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Card className="overflow-hidden rounded-2xl shadow-md flex flex-col h-auto md:h-[480px] w-full min-w-0">
          <CardHeader className="pb-3">
            <Skeleton className="h-4 w-36" />
          </CardHeader>
          <CardContent className="flex-1 flex flex-col gap-2 min-h-0">
            {Array.from({ length: 9 }).map((_, i) => (
              <div key={i} className="flex items-center gap-3">
                <Skeleton className="h-3 w-32 shrink-0" />
                <Skeleton className="h-3 flex-1" />
                <Skeleton className="h-3 w-20 shrink-0" />
                <Skeleton className="h-3 w-24 shrink-0" />
              </div>
            ))}
          </CardContent>
        </Card>

        <Card className="overflow-hidden rounded-2xl shadow-md flex flex-col h-auto md:h-[480px] w-full min-w-0">
          <CardHeader className="pb-3">
            <Skeleton className="h-4 w-52" />
          </CardHeader>
          <CardContent className="flex-1 flex flex-col min-h-0 justify-center">
            <Skeleton className="h-full w-full min-h-[300px] md:min-h-[380px]" />
          </CardContent>
        </Card>
      </div>

      {/* Fila 3: Ranking + Treemap */}
      <div className="grid grid-cols-1 gap-6 lg:grid-cols-2">
        <Card className="overflow-hidden rounded-2xl shadow-md flex flex-col h-auto md:h-[480px] w-full min-w-0">
          <CardHeader className="pb-3">
            <Skeleton className="h-4 w-48" />
          </CardHeader>
          <CardContent className="flex-1 flex flex-col min-h-0 justify-center">
            <Skeleton className="h-full w-full min-h-[300px] md:min-h-[380px]" />
          </CardContent>
        </Card>

        <Card className="overflow-hidden rounded-2xl shadow-md flex flex-col h-auto md:h-[480px] w-full min-w-0">
          <CardHeader className="pb-3">
            <Skeleton className="h-4 w-44" />
          </CardHeader>
          <CardContent className="flex-1 flex flex-col min-h-0 justify-center">
            <Skeleton className="h-full w-full min-h-[300px] md:min-h-[380px]" />
          </CardContent>
        </Card>
      </div>
    </div>
  );
}
