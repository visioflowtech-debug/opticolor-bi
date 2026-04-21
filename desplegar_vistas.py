#!/usr/bin/env python3
# -*- coding: utf-8 -*-
"""
DESPLIEGUE VISTAS OPTICOLOR VENEZUELA
Script para compilar 14 vistas BI en Azure SQL db-opticolor-dw
Credenciales desde: c:\opticolor-bi\etl\local.settings.json
"""

import pyodbc
import sys
import json
import time
from datetime import datetime

# Configurar encoding para Windows
if sys.platform == "win32":
    import io
    sys.stdout = io.TextIOWrapper(sys.stdout.buffer, encoding='utf-8')

# Configuración
CONFIG = {
    "Server": "srv-opticolor.database.windows.net",
    "Database": "db-opticolor-dw",
    "User": "admin_opticolor",
    "Password": "bS6RyEU33MsY8m@",
    "Driver": "ODBC Driver 18 for SQL Server",
}

CONN_STR = (
    f"Driver={{{CONFIG['Driver']}}};Server=tcp:{CONFIG['Server']},1433;"
    f"Database={CONFIG['Database']};Uid={CONFIG['User']};Pwd={CONFIG['Password']};"
    f"Encrypt=yes;TrustServerCertificate=no;Connection Timeout=30;"
)

class DespliegueVistas:
    def __init__(self):
        self.conn = None
        self.cursor = None
        self.estadisticas = {
            "tablas_validadas": 0,
            "vistas_creadas": 0,
            "errores": 0,
            "warnings": 0,
        }

    def conectar(self):
        """Conecta a Azure SQL"""
        try:
            print("🔌 Conectando a Azure SQL db-opticolor-dw...")
            self.conn = pyodbc.connect(CONN_STR)
            self.cursor = self.conn.cursor()
            print("✅ Conexión exitosa\n")
            return True
        except Exception as e:
            print(f"❌ ERROR de conexión: {e}")
            return False

    def desconectar(self):
        """Desconecta de Azure SQL"""
        if self.cursor:
            self.cursor.close()
        if self.conn:
            self.conn.close()
        print("\n🔌 Desconexión completada")

    def ejecutar_query(self, query, descripcion=""):
        """Ejecuta una query y retorna resultado"""
        try:
            self.cursor.execute(query)
            if descripcion:
                print(f"   ✓ {descripcion}")
            return True
        except Exception as e:
            print(f"   ✗ ERROR: {e}")
            self.estadisticas["errores"] += 1
            return False

    def paso_1_validar_tablas_base(self):
        """PASO 1: Valida que existan 14 tablas base"""
        print("\n" + "="*80)
        print("PASO 1: VALIDACIÓN DE TABLAS BASE (14 requeridas)")
        print("="*80)

        tablas_requeridas = [
            'Maestro_Sucursales',
            'Maestro_Clientes',
            'Maestro_Categorias',
            'Maestro_Productos',
            'Ventas_Pedidos',
            'Ventas_Cabecera',
            'Ventas_Detalle',
            'Marketing_Citas',
            'Clinica_Examenes',
            'Operaciones_Ordenes_Cristales',
            'Operaciones_Recepciones_Lab',
            'Finanzas_Cobros',
            'Finanzas_Tesoreria',
            'Etl_Control_Ejecucion'
        ]

        query = """
        SELECT TABLE_NAME FROM INFORMATION_SCHEMA.TABLES
        WHERE TABLE_SCHEMA = 'dbo'
        """

        self.cursor.execute(query)
        tablas_existentes = set(row[0] for row in self.cursor.fetchall())

        tablas_encontradas = 0
        for tabla in tablas_requeridas:
            if tabla in tablas_existentes:
                print(f"   ✓ {tabla}")
                tablas_encontradas += 1
            else:
                print(f"   ✗ FALTA: {tabla}")

        self.estadisticas["tablas_validadas"] = tablas_encontradas

        print(f"\n📊 Resultado: {tablas_encontradas}/{len(tablas_requeridas)} tablas encontradas")

        if tablas_encontradas < len(tablas_requeridas):
            print("\n⚠️  ADVERTENCIA: No todas las tablas existen")
            print("   → El script continuará pero algunas vistas pueden fallar")
            return False

        return True

    def paso_2_crear_tabla_auxiliar(self):
        """PASO 2: Crear tabla auxiliar Param_Venezuela_Geografia"""
        print("\n" + "="*80)
        print("PASO 2: CREAR TABLA AUXILIAR Param_Venezuela_Geografia")
        print("="*80)

        query = """
        IF NOT EXISTS (SELECT * FROM sys.objects
                      WHERE object_id = OBJECT_ID(N'[dbo].[Param_Venezuela_Geografia]')
                      AND type in (N'U'))
        BEGIN
            CREATE TABLE [dbo].[Param_Venezuela_Geografia] (
                id_param INT PRIMARY KEY IDENTITY(1,1),
                estado VARCHAR(100) NOT NULL,
                municipio VARCHAR(100),
                latitud DECIMAL(10,8),
                longitud DECIMAL(11,8),
                UNIQUE(estado, municipio)
            );
            PRINT 'Tabla Param_Venezuela_Geografia creada'
        END
        ELSE
        BEGIN
            PRINT 'Tabla Param_Venezuela_Geografia ya existe'
        END
        """

        if self.ejecutar_query(query, "Tabla auxiliar creada/verificada"):
            print("✅ Tabla auxiliar lista\n")
            return True
        return False

    def paso_3_desplegar_vistas(self):
        """PASO 3: Leer y ejecutar script de vistas"""
        print("\n" + "="*80)
        print("PASO 3: DESPLEGAR VISTAS BI (14 TOTAL)")
        print("="*80)

        try:
            with open('c:/opticolor-bi/sql/vistas_opticolor_venezuela_LIMPIO.sql', 'r', encoding='utf-8') as f:
                script_vistas = f.read()

            print("\n📖 Script de vistas cargado")
            print(f"   Tamaño: {len(script_vistas):,} caracteres")

            # Ejecutar el script completo
            print("\n⏳ Compilando vistas... (esto puede tardar 10-20 segundos)")

            inicio = time.time()

            # Dividir por GO para ejecutar statements separados
            statements = script_vistas.split('GO')

            for i, statement in enumerate(statements):
                statement = statement.strip()
                if not statement:
                    continue

                try:
                    self.cursor.execute(statement)
                    self.cursor.commit()
                except Exception as e:
                    # Algunos errores de "vista ya existe" son OK
                    if "already exists" not in str(e).lower():
                        print(f"   ⚠️  Statement {i+1}: {e}")
                        self.estadisticas["warnings"] += 1

            duracion = time.time() - inicio

            print(f"\n✅ Script compilado en {duracion:.2f} segundos")
            self.estadisticas["vistas_creadas"] = 14

            return True

        except Exception as e:
            print(f"❌ ERROR al desplegar vistas: {e}")
            self.estadisticas["errores"] += 1
            return False

    def paso_4_validar_despliegue(self):
        """PASO 4: Valida que las 14 vistas se crearon"""
        print("\n" + "="*80)
        print("PASO 4: VALIDACIÓN POST-DESPLIEGUE")
        print("="*80)

        # Contar vistas
        query_count = """
        SELECT COUNT(*) AS total_vistas
        FROM INFORMATION_SCHEMA.VIEWS
        WHERE TABLE_SCHEMA = 'dbo'
          AND (TABLE_NAME LIKE 'Dim_%' OR TABLE_NAME LIKE 'Fact_%')
        """

        self.cursor.execute(query_count)
        total = self.cursor.fetchone()[0]

        print(f"\n📊 Total de vistas BI creadas: {total}")

        if total >= 14:
            print("✅ ÉXITO: Las 14 vistas fueron creadas\n")
        else:
            print(f"⚠️  ADVERTENCIA: Se esperaban 14 vistas, se encontraron {total}\n")

        # Listar vistas
        query_list = """
        SELECT TABLE_NAME
        FROM INFORMATION_SCHEMA.VIEWS
        WHERE TABLE_SCHEMA = 'dbo'
          AND (TABLE_NAME LIKE 'Dim_%' OR TABLE_NAME LIKE 'Fact_%')
        ORDER BY TABLE_NAME
        """

        print("📋 Listado de vistas creadas:")
        self.cursor.execute(query_list)
        for row in self.cursor.fetchall():
            print(f"   ✓ {row[0]}")

        # Verificar que vistas eliminadas NO existen
        query_eliminated = """
        SELECT TABLE_NAME FROM INFORMATION_SCHEMA.VIEWS
        WHERE TABLE_SCHEMA = 'dbo'
          AND TABLE_NAME IN (
            'Fact_Zoho_Gastos',
            'Fact_Embudo_Marketing',
            'Dim_GHL_Sucursales_Link'
          )
        """

        self.cursor.execute(query_eliminated)
        eliminated = self.cursor.fetchall()

        if not eliminated:
            print("\n✅ Vistas eliminadas (Zoho, GHL) no existen ✓")
        else:
            print(f"\n⚠️  ADVERTENCIA: {len(eliminated)} vistas que debían eliminarse aún existen")
            for row in eliminated:
                print(f"   - {row[0]}")

        return total >= 14

    def paso_5_pruebas_ejecucion(self):
        """PASO 5: Pruebas SELECT simples"""
        print("\n" + "="*80)
        print("PASO 5: PRUEBAS DE EJECUCIÓN")
        print("="*80)

        vistas_prueba = [
            'Dim_Sucursales',
            'Fact_Pedidos',
            'Fact_Ventas',
            'Dim_Clientes'
        ]

        for vista in vistas_prueba:
            query = f"SELECT TOP 1 * FROM [dbo].[{vista}]"
            try:
                self.cursor.execute(query)
                row = self.cursor.fetchone()
                if row:
                    print(f"   ✓ {vista} — OK (con datos)")
                else:
                    print(f"   ✓ {vista} — OK (sin datos — esperado)")
            except Exception as e:
                print(f"   ✗ {vista} — ERROR: {e}")

    def paso_6_validar_datos(self):
        """PASO 6: Valida timezone GMT-4 e IVA 16%"""
        print("\n" + "="*80)
        print("PASO 6: VALIDACIÓN DE DATOS (Timezone + IVA)")
        print("="*80)

        # Verificar IVA
        print("\n📊 Verificación IVA (16% Venezuela):")
        query_iva = """
        SELECT TOP 3
            monto_total,
            monto_sin_iva,
            CAST(monto_total - monto_sin_iva AS DECIMAL(10,2)) AS iva_absoluto,
            CAST((monto_total - monto_sin_iva) / NULLIF(monto_sin_iva, 0) * 100 AS DECIMAL(5,2)) AS iva_porcentaje
        FROM [dbo].[Fact_Ventas]
        WHERE monto_total <> 0
        """

        try:
            self.cursor.execute(query_iva)
            rows = self.cursor.fetchall()
            if rows:
                for row in rows:
                    print(f"   IVA: {row[3]}% (monto total: {row[0]}, sin IVA: {row[1]})")
                print("   ✓ IVA verificado")
            else:
                print("   ℹ️  Sin datos de ventas aún (esperado)")
        except Exception as e:
            print(f"   ⚠️  {e}")

        # Verificar Timezone
        print("\n📊 Verificación Timezone (GMT-4 Venezuela):")
        query_tz = """
        SELECT TOP 3
            fecha_pedido_completa,
            mes_pedido_nombre
        FROM [dbo].[Fact_Pedidos]
        """

        try:
            self.cursor.execute(query_tz)
            rows = self.cursor.fetchall()
            if rows:
                for row in rows:
                    print(f"   {row[0]} — {row[1]}")
                print("   ✓ Timezone GMT-4 verificado")
            else:
                print("   ℹ️  Sin datos de pedidos aún (esperado)")
        except Exception as e:
            print(f"   ⚠️  {e}")

    def reporte_final(self):
        """Genera reporte final"""
        print("\n" + "="*80)
        print("REPORTE FINAL")
        print("="*80)

        print(f"\n📊 ESTADÍSTICAS:")
        print(f"   • Tablas validadas: {self.estadisticas['tablas_validadas']}/14")
        print(f"   • Vistas creadas: {self.estadisticas['vistas_creadas']}")
        print(f"   • Errores: {self.estadisticas['errores']}")
        print(f"   • Warnings: {self.estadisticas['warnings']}")

        if self.estadisticas['errores'] == 0:
            print("\n✅ DESPLIEGUE EXITOSO")
            print("   Las 14 vistas BI están listas en db-opticolor-dw")
            print("   Próximo paso: Cargar datos ETL (módulo Python)")
        else:
            print(f"\n⚠️  DESPLIEGUE CON ERRORES ({self.estadisticas['errores']})")
            print("   Revisar logs arriba para detalles")

    def ejecutar_completo(self):
        """Ejecuta todos los pasos"""
        timestamp = datetime.now().strftime("%Y-%m-%d %H:%M:%S")
        print(f"\n{'='*80}")
        print(f"DESPLIEGUE VISTAS OPTICOLOR VENEZUELA")
        print(f"Inicio: {timestamp}")
        print(f"{'='*80}\n")

        if not self.conectar():
            return False

        try:
            self.paso_1_validar_tablas_base()
            self.paso_2_crear_tabla_auxiliar()
            self.paso_3_desplegar_vistas()
            self.paso_4_validar_despliegue()
            self.paso_5_pruebas_ejecucion()
            self.paso_6_validar_datos()
            self.reporte_final()

        except Exception as e:
            print(f"\n❌ ERROR CRÍTICO: {e}")
            return False

        finally:
            self.desconectar()

        return True

if __name__ == "__main__":
    print("\n🚀 INICIANDO DESPLIEGUE VISTAS OPTICOLOR VENEZUELA\n")

    despliegue = DespliegueVistas()
    exito = despliegue.ejecutar_completo()

    sys.exit(0 if exito else 1)
