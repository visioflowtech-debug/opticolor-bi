import type { Config } from "tailwindcss"

const config: Config = {
  content: [
    "./app/**/*.{js,ts,jsx,tsx,mdx}",
    "./components/**/*.{js,ts,jsx,tsx,mdx}",
    "./lib/**/*.{js,ts,jsx,tsx,mdx}",
  ],
  theme: {
    extend: {
      colors: {
        // Paleta Opticolor corporativa
        primary: {
          50: "#F0F4FA",
          100: "#E1E9F5",
          200: "#C3D3EB",
          300: "#A5BDE1",
          400: "#6B92CC",
          500: "#1A3A6B", // Primary: azul corporativo
          600: "#163260",
          700: "#122A55",
          800: "#0E224A",
          900: "#0A1A3F",
        },
        secondary: {
          50: "#F0F6FB",
          100: "#E1ECF7",
          200: "#C3D9EF",
          300: "#A5C6E7",
          400: "#6B9FD3",
          500: "#2B6CB0", // Secondary: azul medio
          600: "#265A9D",
          700: "#21488A",
          800: "#1C3677",
          900: "#172A64",
        },
        accent: {
          50: "#FEFBF0",
          100: "#FEF7E1",
          200: "#FCEED3",
          300: "#FAE5C5",
          400: "#F6D59E",
          500: "#D4A017", // Accent: dorado
          600: "#C09014",
          700: "#AC8011",
          800: "#98700E",
          900: "#84600B",
        },
      },
    },
  },
  plugins: [],
}
export default config
