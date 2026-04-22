import React, { useState, useEffect } from "react"
import { Skeleton } from "@/components/ui/skeleton"

export interface ChartWithSkeletonProps extends React.HTMLAttributes<HTMLDivElement> {
  children: React.ReactNode
  isLoading?: boolean
  height?: string
}

export function ChartSkeleton({ isLoading = true, height = "h-80" }: { isLoading?: boolean; height?: string }) {
  return (
    <div className={`${height} w-full space-y-2`}>
      <Skeleton className="h-full w-full rounded-lg" />
    </div>
  )
}

export function ChartWithSkeleton({
  children,
  isLoading = false,
  height = "h-80",
  className,
  ...props
}: ChartWithSkeletonProps) {
  const [showSkeleton, setShowSkeleton] = useState(isLoading)

  useEffect(() => {
    if (isLoading) {
      setShowSkeleton(true)
    } else {
      // Small delay to avoid skeleton flashing
      const timer = setTimeout(() => setShowSkeleton(false), 100)
      return () => clearTimeout(timer)
    }
  }, [isLoading])

  return (
    <div className={className} {...props}>
      {showSkeleton ? (
        <ChartSkeleton height={height} />
      ) : (
        <div className="transition-opacity duration-300 opacity-100">{children}</div>
      )}
    </div>
  )
}
