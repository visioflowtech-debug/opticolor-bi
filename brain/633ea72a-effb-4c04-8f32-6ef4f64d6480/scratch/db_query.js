const mssql = require('mssql');
const fs = require('fs');

// Parse .env.local manually
try {
    const env = fs.readFileSync('c:/Users/MICHELLE/opticolor-bi/portal/.env.local', 'utf8');
    env.split('\n').forEach(line => {
        const parts = line.split('=');
        if (parts.length >= 2) {
            process.env[parts[0].trim()] = parts.slice(1).join('=').trim();
        }
    });
} catch (e) {
    console.error("Error reading .env.local:", e);
}

const sqlConfig = {
    user: process.env.AZURE_SQL_USER,
    password: process.env.AZURE_SQL_PASSWORD,
    database: process.env.AZURE_SQL_DATABASE,
    server: process.env.AZURE_SQL_SERVER || "",
    port: parseInt(process.env.AZURE_SQL_PORT || "1433", 10),
    connectionTimeout: 180000,
    requestTimeout: 180000,
    options: {
        encrypt: true,
        trustServerCertificate: false,
    },
};

async function run() {
    try {
        console.log("Connecting to", sqlConfig.server, "database:", sqlConfig.database);
        const pool = await mssql.connect(sqlConfig);
        console.log("Connected successfully!");

        console.log("\n--- Query 1: Total exams by gender directly from Fact_Examenes and Dim_Clientes (No date filters, no sucursal filters) ---");
        let result1 = await pool.request().query(`
            SELECT
                CASE
                    WHEN dc.genero_label IS NULL OR RTRIM(LTRIM(dc.genero_label)) = '' THEN 'NO DEFINIDO (PENDIENTE)'
                    ELSE UPPER(RTRIM(LTRIM(dc.genero_label)))
                END AS genero_label,
                COUNT(DISTINCT fe.id_examen) AS total_examenes,
                CAST(
                    COUNT(DISTINCT fe.id_examen) * 100.0
                    / SUM(COUNT(DISTINCT fe.id_examen)) OVER()
                    AS DECIMAL(5,2)
                ) AS porcentaje
            FROM dbo.Fact_Examenes fe
            LEFT JOIN dbo.Dim_Clientes dc ON fe.id_cliente = dc.id_cliente
            GROUP BY
                CASE
                    WHEN dc.genero_label IS NULL OR RTRIM(LTRIM(dc.genero_label)) = '' THEN 'NO DEFINIDO (PENDIENTE)'
                    ELSE UPPER(RTRIM(LTRIM(dc.genero_label)))
                END
            ORDER BY total_examenes DESC
        `);
        console.table(result1.recordset);

        console.log("\n--- Query 2: Let's see total count of exams in Fact_Examenes ---");
        let result2 = await pool.request().query(`
            SELECT COUNT(1) as raw_rows, COUNT(DISTINCT id_examen) as distinct_exams FROM dbo.Fact_Examenes
        `);
        console.table(result2.recordset);

        console.log("\n--- Query 3: Are there duplicate id_examen? ---");
        let result3 = await pool.request().query(`
            SELECT TOP 5 id_examen, COUNT(1) as cnt
            FROM dbo.Fact_Examenes
            GROUP BY id_examen
            HAVING COUNT(1) > 1
            ORDER BY cnt DESC
        `);
        console.table(result3.recordset);

        console.log("\n--- Query 4: Checking how count(id_examen) compares to count(distinct id_examen) by gender ---");
        let result4 = await pool.request().query(`
            SELECT
                CASE
                    WHEN dc.genero_label IS NULL OR RTRIM(LTRIM(dc.genero_label)) = '' THEN 'NO DEFINIDO (PENDIENTE)'
                    ELSE UPPER(RTRIM(LTRIM(dc.genero_label)))
                END AS genero_label,
                COUNT(fe.id_examen) AS raw_exam_count,
                COUNT(DISTINCT fe.id_examen) AS distinct_exam_count
            FROM dbo.Fact_Examenes fe
            LEFT JOIN dbo.Dim_Clientes dc ON fe.id_cliente = dc.id_cliente
            GROUP BY
                CASE
                    WHEN dc.genero_label IS NULL OR RTRIM(LTRIM(dc.genero_label)) = '' THEN 'NO DEFINIDO (PENDIENTE)'
                    ELSE UPPER(RTRIM(LTRIM(dc.genero_label)))
                END
            ORDER BY raw_exam_count DESC
        `);
        console.table(result4.recordset);

        await pool.close();
    } catch (err) {
        console.error(err);
    }
}

run();
