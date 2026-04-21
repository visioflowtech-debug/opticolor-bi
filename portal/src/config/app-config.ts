import packageJson from "../../package.json";

const currentYear = new Date().getFullYear();

export const APP_CONFIG = {
  name: "Opticolor - BI",
  version: packageJson.version,
  copyright: `© ${currentYear}, Opticolor - BI.`,
  meta: {
    title: "Opticolor - BI",
    description:
      "Sistema integrado de análisis y reportería para OPTI-COLOR.",
  },
};
