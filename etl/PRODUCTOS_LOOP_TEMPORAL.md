# 🔄 PRODUCTOS Loop Temporal (Carga 143,860 productos)

**Fecha:** 21 Abril 2026  
**Total productos a cargar:** 143,860  
**Duración estimada:** ~144 minutos (2.4 horas)

---

## ✅ Cambios Realizados en function_app.py

### 1. Aumentar timeout PRODUCTOS (línea 1113)
```python
# ANTES: MAX_EXECUTION_TIME = 9 * 60
# DESPUÉS:
MAX_EXECUTION_TIME = 20 * 60  # 20 minutos por ciclo
```

### 2. Nueva función timer (línea 84-142)
```python
@app.timer_trigger(schedule="*/1 * * * *", arg_name="myTimer", run_on_startup=False)
def EtlProductosRepetitivo(myTimer: func.TimerRequest) -> None:
    """Ejecutor temporal SOLO PRODUCTOS cada minuto"""
```

**Qué hace:**
- ✅ Se ejecuta **cada minuto** automáticamente
- ✅ Carga PRODUCTOS durante **20 minutos máximo** por ejecución
- ✅ Guarda checkpoint automáticamente
- ✅ Se reeja el siguiente minuto (sin intervención)
- ✅ Notifica progreso por Telegram cada 5 minutos
- ✅ Detecta cuando completó y envía notificación final

---

## 🚀 Flujo Automático

```
Minuto 1:  PRODUCTOS inicia skip=0  → carga 1,000 productos → timeout 20 min → checkpoint=1000
Minuto 2:  PRODUCTOS inicia skip=1000 → carga 1,000 productos → timeout 20 min → checkpoint=2000
Minuto 3:  PRODUCTOS inicia skip=2000 → carga 1,000 productos → timeout 20 min → checkpoint=3000
...
Minuto 144: PRODUCTOS inicia skip=142000 → carga últimos 1,860 → COMPLETA → checkpoint=0
           ✅ Notificación Telegram: "PRODUCTOS completado: 143,860 productos"
```

---

## 📋 Pasos para Implementar

### Paso 1: Pull / Restart local
```bash
cd c:\opticolor-bi\ETL\
func host start
```

### Paso 2: Monitorear logs
Verás cada minuto:
```
[2026-04-21T22:30:00] --- [PRODUCTOS-LOOP] Inicio repetitivo (cada minuto) ---
[2026-04-21T22:30:01]    [Historical] Retomando carga masiva desde SKIP: 0
[2026-04-21T22:30:10]    [SQL Write] Guardando bloque (Skip actual: 150)...
...
[2026-04-21T22:50:00]    [TIMEOUT] Tiempo agotado en skip 1000. Guardando estado...
[2026-04-21T22:50:01] --- [PRODUCTOS-LOOP] Procesados: 1000 productos en 20.0 min ---
[2026-04-21T22:51:00] --- [PRODUCTOS-LOOP] Inicio repetitivo (cada minuto) ---
[2026-04-21T22:51:01]    [Historical] Retomando carga masiva desde SKIP: 1000
...
```

### Paso 3: Dejar ejecutarse toda la noche
- Timer ejecuta automáticamente cada minuto
- No necesitas intervención manual
- Logs en Azure Portal → Function App → Monitor

### Paso 4: Monitorear con Telegram
- Notificación cada 5 minutos con progreso
- Notificación final: "PRODUCTOS completado: 143,860"

---

## ✅ Verificación

**En SQL, ver progreso:**
```sql
SELECT COUNT(*) AS productos_cargados FROM Maestro_Productos;
SELECT 'checkpoint_products_skip' AS clave, LastValue FROM Etl_Checkpoints WHERE KeyName = 'checkpoint_products_skip';
```

**Resultado final esperado:**
```
productos_cargados = 143,860
checkpoint_products_skip = 0 (o no existe)
```

---

## 🛑 Cuando Completar

Una vez que veas:
```
✅ [PRODUCTOS-LOOP] Carga histórica COMPLETADA (143,860 productos)
```

### Entonces:
1. **Comentar función `EtlProductosRepetitivo`** (línea 84)
2. **Descomentar cascada normal** (EtlOrquestadorPrincipal módulos)
3. **Cambiar `LOAD_MODE_INVOICES = 'INCREMENTAL'`**
4. **Commit y push a Azure**

---

## 📊 Estimación de Tiempo

| Total Productos | Rate | Duración |
|---|---|---|
| 143,860 | ~1,000/min | ~144 minutos |
| | | = 2.4 horas |
| | | ≈ 01:00 - 03:24 |

Si ejecutas a las 22:00, termina ~00:24

---

## 🔧 Troubleshooting

### Si se detiene por error API:
- Timer reinicia automáticamente en 1 minuto
- Checkpoint guardado, continúa desde último skip

### Si necesitas forzar reinicio:
```sql
-- Reset completo (cuidado, reinicia desde 0)
DELETE FROM Maestro_Productos;
DELETE FROM Etl_Checkpoints WHERE KeyName = 'checkpoint_products_skip';
```

### Si necesitas pausar:
- Comentar función `EtlProductosRepetitivo`
- Haz deploy a Azure
- Timer no se ejecutará

---

## 📄 Archivos Modificados

| Archivo | Cambio | Línea |
|---------|--------|-------|
| `function_app.py` | Aumentar timeout PRODUCTOS | 1113 |
| `function_app.py` | Agregar función timer repetitiva | 84-142 |

---

**Estado:** ✅ Listo para ejecutar `func host start`  
**Duración:** ~144 minutos toda la noche  
**Intervención:** Ninguna (completamente automático)

---
