use crate::database;
use super::errors::InventoryError;

/// 保存新增囤货的草稿 (JSON 格式)
pub fn save_inventory_draft(json_data: String) -> Result<(), InventoryError> {
    let conn = database::get_connection()?;
    conn.execute(
        "INSERT OR REPLACE INTO app_settings (key, value) VALUES ('inventory_add_draft', ?1)",
        [json_data],
    )?;
    Ok(())
}

/// 获取新增囤货的草稿
pub fn get_inventory_draft() -> Result<Option<String>, InventoryError> {
    let conn = database::get_connection()?;
    let mut stmt = conn.prepare("SELECT value FROM app_settings WHERE key = 'inventory_add_draft'")?;
    
    let mut rows = stmt.query([])?;
    if let Some(row) = rows.next()? {
        let value: String = row.get(0)?;
        Ok(Some(value))
    } else {
        Ok(None)
    }
}

/// 清除新增囤货的草稿
pub fn clear_inventory_draft() -> Result<(), InventoryError> {
    let conn = database::get_connection()?;
    conn.execute(
        "DELETE FROM app_settings WHERE key = 'inventory_add_draft'",
        [],
    )?;
    Ok(())
}
