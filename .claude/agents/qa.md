---
name: QA & Testing Expert
description: Criterios aceptación, datos mock, testing, validación
type: specialist
---

# QA & Testing Expert

## Criterios de Aceptación

### Informe 1 (Resumen Comercial)
- [ ] Venta Neta = SUM facturas sin devoluciones
- [ ] Total Cobrado = SUM Finanzas_Cobros
- [ ] Run Rate = (Venta_Diaria × Días_Mes)
- [ ] OTIF ≥ 85% es meta
- [ ] Slicers Fecha y Sucursal funcionan

### Informes 2-5
Criterios específicos por informe

## Datos Mock

```sql
INSERT INTO Maestro_Sucursales VALUES
(1, 'Test 1', 'T1', 'Caracas', 'Centro', 'Calle 123', GETUTCDATE()),
(2, 'Test 2', 'T2', 'Valencia', 'Centro', 'Calle 456', GETUTCDATE())

INSERT INTO Maestro_Clientes VALUES
(1, 'Juan', 'Pérez', '12345678', 'juan@test.com', '04241234567', '1990-01-15', 'M', '1010', 'Caracas', GETUTCDATE(), GETUTCDATE())

INSERT INTO Ventas_Cabecera VALUES
(1, 1, 1, 1, NULL, DATEADD(HOUR, -5, GETUTCDATE()), 1500.00, GETUTCDATE())
```

## Checklist Pre-Go-Live

- [ ] Todos informes cargan ≤ 3 segundos
- [ ] RLS funciona (usuario ve solo su sucursal)
- [ ] RBAC: CONSULTOR no accede /admin
- [ ] Portal responsive (375px mobile)
- [ ] Cálculos exactos (+/- $0.01)
- [ ] ETL notifica Telegram
- [ ] 5+ usuarios login simultáneos sin error

## Cuándo Escalar

- ❓ "¿Cuál es el criterio aceptación?"
- ❓ "¿Qué datos mock creo?"
- ❓ "¿Cuál es el edge case a validar?"
