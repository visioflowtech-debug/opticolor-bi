import mssql from "mssql";

declare global {
  // Permite que sqlPool coexista en el espacio global de ejecución en entornos Serverless/Node
  var sqlPool: mssql.ConnectionPool | undefined;
}

const sqlConfig: mssql.config = {
    user: process.env.AZURE_SQL_USER,
    password: process.env.AZURE_SQL_PASSWORD,
    database: process.env.AZURE_SQL_DATABASE,
    server: process.env.AZURE_SQL_SERVER || "",
    port: parseInt(process.env.AZURE_SQL_PORT || "1433", 10),
    connectionTimeout: 180000,
    requestTimeout: 180000,
    pool: {
        max: 10,
        min: 0,
        idleTimeoutMillis: 180000,
    },
    options: {
        encrypt: true,
        trustServerCertificate: false,
    },
};

export const getConnection = async (): Promise<mssql.ConnectionPool> => {
    try {
        // 1. Si globalThis.sqlPool existe y está conectado -> retornarlo.
        if (globalThis.sqlPool) {
            if (globalThis.sqlPool.connected) {
                return globalThis.sqlPool;
            }
            
            // 2. Si existe pero se desconectó -> cerrar de forma segura con .close()
            try {
                await globalThis.sqlPool.close();
            } catch (e) {
                console.warn("[DB] Error al cerrar pool desconectado:", e);
            }
            globalThis.sqlPool = undefined;
        }

        // 3. Si no existe -> instanciar, ejecutar await pool.connect(), asignarlo a globalThis.sqlPool y retornarlo.
        const pool = new mssql.ConnectionPool(sqlConfig);
        await pool.connect();
        
        globalThis.sqlPool = pool;
        return pool;
    } catch (err) {
        // Limpiar la referencia global si el handshake inicial falla
        globalThis.sqlPool = undefined;
        console.error("Database connection failed", err);
        throw err;
    }
};
