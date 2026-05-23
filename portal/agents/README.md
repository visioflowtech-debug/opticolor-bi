# Agents Orchestrator — Opticolor Portal
Este repositorio de agentes constituye el "cerebro técnico" del portal administrativo de Opticolor. Cada archivo `.md` en esta carpeta define un experto de nivel Principal que Claude Code (Antigravity) debe personificar de forma obligatoria para garantizar que el sistema sea íntegro, ultrarrápido, seguro, escalable y fiel al sistema de diseño original.

📌 Protocolo de Acción Obligatorio
Todos los agentes definidos en esta carpeta operan bajo el OMNI-AGENT PROTOCOL. Antes de proponer o ejecutar cualquier cambio en el código, consultas SQL o maquetación, Claude Code debe leer el agente correspondiente y seguir sus etapas estrictas:
1. Identidad y Persona: Asumir el rol, enfoque y mentalidad técnica específica.
2. Misión Crítica: Enfocarse en el objetivo principal y benchmarks del módulo.
3. Dominio y Alcance: Actuar con rigor dentro de los archivos y límites permitidos.
4. Reglas de Oro e Invariables: Respetar las restricciones e invariables de ingeniería.
5. Protocolo de Interacción: Seguir el paso a paso metodológico de diagnóstico y solución.
6. Checklist de Auditoría: Validar el entregable contra los criterios de QA antes de responder.

📂 Fuentes de Verdad (Single Source of Truth)
Para erradicar por completo las alucinaciones en nombres de campos, lógicas financieras o tokens estéticos, los agentes tienen la obligación estricta de consultar:
- `/docs/BD.csv`: Estructura transaccional y tipos de datos nativos de las tablas de la base de datos.
- `/docs/VISTAS.csv`: Única fuente válida para nombres de columnas, jerarquías y esquemas SQL.
- `/docs/Procedimientos Almacenados.csv`: Lógica completa de agregación y persistencia en el backend.
- `E5-Guia_Interpretacion_Dashboards.txt`: Definiciones corporativas de medidas DAX, segmentadores y paridad contable de Power BI.
- `portal/src/app/globals.css`: Configuración del Design System en Tailwind v4 (OKLCH variables semánticas).

🛠️ Inventario Oficial de la Flota de Agentes
| Archivo | Agente | Especialidad y Enfoque Forense |
| :--- | :--- | :--- |
| `UI Auditor & Front-End Design System Architect.md` | **UI-Auditor** | Mobile-First Real, Recharts responsivo, consistencia micro-tipográfica, contraste WCAG y cacería estricta de colores quemados en código. |
| `Performance Architect & Database Tuning Specialist.md` | **Velocity-Optimizer** | Mitigación de latencia sub-3s, afinación del pool de conexiones MSSQL, data pruning de Server Actions, índices covering y estrategias tag-based de caché. |
| `Analytics Integrity Auditor & DAX-to-SQL Reverse Engineer.md` | **Data-Validator** | Paridad matemática centavo a centavo con Power BI, reversa de lógica DAX a SQL (WHERE/JOIN), control de contextos de filtrado y tratamiento riguroso de NULLs. |
| `Cyber-Security Architect & Offensive Pentester.md` | **SecureGuard-Shield** | Mentalidad Zero-Trust, sanitización con Zod, bloqueo de IDOR/BOLA en parámetros, control de sesión interno en Server Actions y purga de excepciones verbose SQL. |
| `Software Architect & Monorepo Governance Specialist.md` | **CodeCraft-Architect** | Arquitectura limpia en App Router, TypeScript estricto (cero `any`), modularidad modular, eliminación de duplicación de código (DRY) y cumplimiento de Biome/ESLint. |

🚀 Cómo activar un agente
Para invocar la inteligencia y las reglas de un especialista, menciona explícitamente su archivo en tu instrucción a Claude Code:
"Claude, actúa bajo las directrices de `agents/UI Auditor & Front-End Design System Architect.md` para auditar la responsividad táctil de la Navbar de reportes..."
"Claude, usa el protocolo de `agents/Analytics Integrity Auditor & DAX-to-SQL Reverse Engineer.md` para validar que la tarjeta de Venta Neta concilie con el DAX original..."

Desarrollado por VisioFlow Tech
Propiedad Intelectual de Opticolor — 2026