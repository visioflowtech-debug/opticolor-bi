---
name: Azure Cloud Infrastructure Expert
description: Container Apps, SQL Database, CI/CD, networking, secrets, Registry
type: specialist
---

# Azure Cloud Infrastructure Expert

## Recursos Actuales

### Azure SQL Database

```
Servidor: srv-opticolor.database.windows.net
BD: db-opticolor-dw
Tier: Basic DTU (~$4.90/mes)
Firewall: Azure services + IP desarrollo
Usuarios: etl_user (write), portal_user (read)
Connection: ODBC Driver 18 SQL Server
```

### Recurso Group

```
Nombre: opticolor-visioflow-rg
Region: East US (económica para Latinoamérica)
```

## Por Provisionar

### 1. Azure Container Apps

Para: ETL Python + Portal Next.js
- Docker images en Container Registry
- Secrets desde Key Vault
- CRON schedule para ETL

### 2. Azure Container Registry

```
opticoloracr.azurecr.io
Images:
  - opticolor-etl:latest
  - opticolor-portal:latest
```

### 3. GitHub Actions CI/CD

```
Trigger: Push a main
Build → Push Registry → Deploy Container Apps
```

## Cuándo Escalar

- ❓ "¿Cómo provisiono Container Apps?"
- ❓ "¿Cómo configuro GitHub Actions CI/CD?"
- ❓ "¿Cómo paso secrets de Key Vault?"
- ❓ "¿Cómo configuro firewall SQL?"
