import Link from "next/link";
import Image from "next/image";

import { cn } from "@/lib/utils";

interface LogoProps {
  size?: "sm" | "md" | "lg";
  width?: number;
  href?: string;
  priority?: boolean;
  className?: string;
}

const sizeMap = {
  sm: 60,
  md: 120,
  lg: 180,
};

export function Logo({ size, width, href = "/", priority = false, className }: LogoProps) {
  const logoWidth = width || sizeMap[size || "md"];
  const logoHeight = Math.round(logoWidth * (200 / 500)); // Proporción original

  const image = (
    <Image
      src="/media/logo_opticolor.webp"
      alt="Opticolor - BI"
      width={logoWidth}
      height={logoHeight}
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
