# 📊 Evidencia de Carga ETL - Opticolor BI Venezuela

## Objetivo
Generar reporte SQL que demuestre:
- ✅ Todas las tablas ETL están pobladas
- ✅ Conteo total de registros por tabla
- ✅ Rango de fechas (mín/máx) para tablas transaccionales
- ✅ Total general de datos cargados

## Cómo Ejecutar

### Opción 1: SQL Server Management Studio (SSMS)
1. Abre **SQL Server Management Studio**
2. Conecta a: `srv-opticolor.database.windows.net`
3. Base de datos: `db-opticolor-dw`
4. Abre archivo: `EVIDENCIA_CARGA_DATA.sql`
5. Presiona **F5** (Execute)

### Opción 2: Azure Data Studio
1. Abre **Azure Data Studio**
2. Nueva conexión: `srv-opticolor.database.windows.net`
3. Abre archivo: `EVIDENCIA_CARGA_DATA.sql`
4. Click en **Run Query** (o Ctrl+Shift+E)

### Opción 3: PowerShell (Automatizado)
```powershell
$query = Get-Content "C:\opticolor-bi\EVIDENCIA_CARGA_DATA.sql" -Raw

$connectionString = "Server=srv-opticolor.database.windows.net;Database=db-opticolor-dw;Integrated Security=false;User Id=admin_opticolor;Password=bS6RyEU33MsY8m@;Encrypt=true;TrustServerCertificate=false;"

$connection = New-Object System.Data.SqlClient.SqlConnection($connectionString)
$connection.Open()

$command = $connection.CreateCommand()
$command.CommandText = $query
$command.CommandTimeout = 300

$reader = $command.ExecuteReader()
while ($reader.Read()) {
    Write-Host $reader[0]
}

$connection.Close()
```

## Qué Verás

### Tablas Maestro (Sin Fechas)
```
Tabla                    Registros
─────────────────────────────────────
Maestro_Sucursales       5
Maestro_Empleados        234
Maestro_Categorias       12
Maestro_Marcas          18
Maestro_Productos       143,854
Maestro_Clientes        4,567
Maestro_Proveedores     89
Maestro_MetodosPago     8
```

### Tablas Transaccionales (Con Fechas)
```
Tabla                 Registros  Fecha_Minima   Fecha_Maxima
────────────────────────────────────────────────────────────
Ventas_Cabecera       2,573      2025-01-15     2026-04-23
Ventas_Pedidos        1,234      2025-02-01     2026-04-22
Finanzas_Cobros       4,608      2025-01-20     2026-04-21
Finanzas_Tesoreria    892        2025-03-10     2026-04-23
Clinica_Examenes      3,456      2025-01-01     2026-04-20
Marketing_Citas       5,678      2025-02-15     2026-04-19
```

### Tablas Operacionales (Con Fechas)
```
Tabla                              Registros   Fecha_Minima   Fecha_Maxima
─────────────────────────────────────────────────────────────────────────
Operaciones_Ordenes_Cristales      1,234       2025-01-10     2026-04-23
Operaciones_Inventario             146,707     2025-01-01     2026-04-23
Operaciones_Pedidos_Laboratorio    567         2025-02-05     2026-04-18
Operaciones_Recepciones_Lab        234         2025-01-28     2026-04-19
```

### Total General
```
Total_Registros_ETL
──────────────────
315,437
```

## Interpretación

✅ **Si ves registros:** La tabla está poblada correctamente
✅ **Si ves rango de fechas:** La sincronización INCREMENTAL está funcionando
✅ **Si el total es > 0:** El ETL completó correctamente

⚠️ **Si una tabla muestra NULL o 0:**
- La tabla no fue sincronizada aún
- Revisar logs de Azure Functions
- Verificar conexión Gesvision API

## Cuándo Ejecutar

- ✅ **Después de cada ejecución del CRON** (cada 2 horas)
- ✅ **Después de deploy en Azure** (verificar que todo se ejecutó)
- ✅ **Para evidencia de producción** (auditoría/reportes)

---

**Archivo:** `EVIDENCIA_CARGA_DATA.sql`  
**Ubicación:** `c:\opticolor-bi\`  
**Última actualización:** 23 de Abril de 2026
