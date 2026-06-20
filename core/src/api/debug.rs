use crate::database;

#[derive(Debug, serde::Serialize)]
pub struct DbQueryResult {
    pub columns: Vec<String>,
    pub rows: Vec<Vec<String>>,
}

/// 获取数据库中所有的表名
pub fn list_tables() -> Result<Vec<String>, String> {
    let conn = database::get_connection().map_err(|e| e.to_string())?;
    let mut stmt = conn
        .prepare("SELECT name FROM sqlite_master WHERE type='table' AND name NOT LIKE 'sqlite_%'")
        .map_err(|e| e.to_string())?;
    
    let table_names = stmt
        .query_map([], |row| row.get(0))
        .map_err(|e| e.to_string())?
        .collect::<Result<Vec<String>, _>>()
        .map_err(|e| e.to_string())?;
    
    Ok(table_names)
}

/// 执行自定义 SQL 查询并返回结果
pub fn execute_debug_sql(sql: String) -> Result<DbQueryResult, String> {
    let conn = database::get_connection().map_err(|e| e.to_string())?;
    let mut stmt = conn.prepare(&sql).map_err(|e| e.to_string())?;
    
    let column_names: Vec<String> = stmt
        .column_names()
        .into_iter()
        .map(|s| s.to_string())
        .collect();
    
    let column_count = stmt.column_count();
    
    let rows = stmt.query_map([], |row| {
        let mut row_data = Vec::with_capacity(column_count);
        for i in 0..column_count {
            let val: rusqlite::types::Value = row.get(i)?;
            row_data.push(match val {
                rusqlite::types::Value::Null => "NULL".to_string(),
                rusqlite::types::Value::Integer(i) => i.to_string(),
                rusqlite::types::Value::Real(f) => f.to_string(),
                rusqlite::types::Value::Text(t) => t,
                rusqlite::types::Value::Blob(b) => format!("<{} bytes>", b.len()),
            });
        }
        Ok(row_data)
    }).map_err(|e| e.to_string())?;

    let mut result_rows = Vec::new();
    for row in rows {
        result_rows.push(row.map_err(|e| e.to_string())?);
    }

    Ok(DbQueryResult {
        columns: column_names,
        rows: result_rows,
    })
}
