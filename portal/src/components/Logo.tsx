import Link from "next/link";
import Image from "next/image";

import { cn } from "@/lib/utils";

interface LogoProps {
  size?: "sm" | "md" | "lg";
  href?: string;
  priority?: boolean;
  className?: string;
}

const sizeMap = {
  sm: 60,
  md: 120,
  lg: 180,
};

export function Logo({ size = "md", href = "/", priority = false, className }: LogoProps) {
  const width = sizeMap[size];
  const height = Math.round(width * (200 / 500)); // 500x200 original ratio

  const image = (
    <Image
      src="/media/logo-opticolor.png"
      alt="OPTI-COLOR - Portal de Inteligencia de Datos"
      width={width}
      height={height}
      priority={priority}
      quality={90}
      className={cn("object-contain", className)}
    />
  );

  if (!href) {
    return image;
  }

  return (
    <Link href={href} prefetch={false}>
      {image}
    </Link>
  );
}
