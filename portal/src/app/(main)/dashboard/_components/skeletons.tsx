import { Skeleton } from "@/components/ui/skeleton";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";

interface KPISkeletonProps {
  cols?: number;
  count?: number;
  className?: string;
}

export function KPISkeleton({ cols = 3, count = cols, className = "" }: KPISkeletonProps) {
  // Use a string representation for class to avoid Tailwind compilation dynamic class generation issues
  const gridColsClass = 
    cols === 1 ? "grid-cols-1" :
    cols === 2 ? "grid-cols-1 sm:grid-cols-2" :
    cols === 3 ? "grid-cols-1 sm:grid-cols-2 lg:grid-cols-3" :
    cols === 4 ? "grid-cols-1 sm:grid-cols-2 lg:grid-cols-4" :
    cols === 5 ? "grid-cols-1 sm:grid-cols-2 xl:grid-cols-5" :
    cols === 6 ? "grid-cols-1 sm:grid-cols-2 lg:grid-cols-3 xl:grid-cols-6" :
    cols === 8 ? "grid-cols-1 sm:grid-cols-2 md:grid-cols-3 lg:grid-cols-4" :
    "grid-cols-1 sm:grid-cols-2 lg:grid-cols-3";

  return (
    <div className={`grid gap-4 ${gridColsClass} ${className}`}>
      {Array.from({ length: count }).map((_, i) => (
        <Skeleton key={i} className="h-[104px] w-full rounded-xl" />
      ))}
    </div>
  );
}

interface ChartSkeletonProps {
  title?: string;
  height?: string;
}

export function ChartSkeleton({ title, height = "h-[300px]" }: ChartSkeletonProps) {
  return (
    <Card className="overflow-hidden rounded-2xl shadow-md">
      <CardHeader className="pb-3">
        {title ? (
          <CardTitle className="text-sm font-semibold text-muted-foreground">
            {title}
          </CardTitle>
        ) : (
          <Skeleton className="h-5 w-48" />
        )}
      </CardHeader>
      <CardContent>
        <Skeleton className={`w-full ${height}`} />
      </CardContent>
    </Card>
  );
}

interface TableSkeletonProps {
  title?: string;
  rows?: number;
}

export function TableSkeleton({ title, rows = 5 }: TableSkeletonProps) {
  return (
    <Card className="overflow-hidden rounded-2xl shadow-md">
      <CardHeader className="pb-3">
        {title ? (
          <CardTitle className="text-sm font-semibold text-muted-foreground">
            {title}
          </CardTitle>
        ) : (
          <Skeleton className="h-5 w-48" />
        )}
      </CardHeader>
      <CardContent>
        <div className="w-full space-y-4">
          <Skeleton className="h-10 w-full rounded-lg" />
          {Array.from({ length: rows }).map((_, i) => (
            <Skeleton key={i} className="h-12 w-full rounded-lg" />
          ))}
        </div>
      </CardContent>
    </Card>
  );
}
