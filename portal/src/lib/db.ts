import sql from 'mssql';

const config: sql.config = {
  server: process.env.AZURE_SQL_SERVER!,
  database: process.env.AZURE_SQL_DATABASE!,
  user: process.env.AZURE_SQL_USER!,
  password: process.env.AZURE_SQL_PASSWORD!,
  options: {
    encrypt: true,
    trustServerCertificate: false,
    connectTimeout: 15000,
    requestTimeout: 30000,
  },
  pool: {
    max: 5,
    min: 0,
    idleTimeoutMillis: 30000,
  },
};

let pool: sql.ConnectionPool | null = null;

export async function getPool(): Promise<sql.ConnectionPool> {
  try {
    if (!pool || !pool.connected) {
      pool = new sql.ConnectionPool(config);
      await pool.connect();
      console.log('[DB] Conexión a Azure SQL establecida');
    }
    return pool;
  } catch (error) {
    console.error('[DB] Error conectando a Azure SQL:', error);
    pool = null;
    throw error;
  }
}

export async function query<T>(
  sqlText: string,
  params?: Record<string, any>
): Promise<T[]> {
  const pool = await getPool();
  const request = pool.request();

  if (params) {
    for (const [key, value] of Object.entries(params)) {
      request.input(key, value);
    }
  }

  const result = await request.query(sqlText);
  return result.recordset as T[];
}

export async function closePool(): Promise<void> {
  if (pool) {
    await pool.close();
    pool = null;
  }
}
