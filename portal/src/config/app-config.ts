import packageJson from "../../package.json";

const currentYear = new Date().getFullYear();

export const APP_CONFIG = {
  name: "Opticolor - BI",
  version: packageJson.version,
  copyright: `© ${currentYear}, Opticolor - BI.`,
  meta: {
    title: "Opticolor - BI",
    description:
      "Portal de Inteligencia de Datos para OPTI-COLOR — Sistema integrado de análisis y reportería.",
  },
};
