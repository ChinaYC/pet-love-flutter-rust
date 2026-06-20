pub mod migration;

use rusqlite::{Connection, Result};
use std::sync::Mutex;
use lazy_static::lazy_static;

lazy_static! {
    static ref DB_PATH: Mutex<Option<String>> = Mutex::new(None);
}

/// 设置数据库路径并初始化
pub fn setup_database(path: String) -> Result<()> {
    let mut db_path = DB_PATH.lock().unwrap();
    *db_path = Some(path.clone());
    
    // 初始化并迁移
    let _conn = migration::init_database(&path)?;
    Ok(())
}

/// 获取数据库连接
pub fn get_connection() -> anyhow::Result<Connection> {
    let db_path = DB_PATH.lock().unwrap();
    let path = db_path.as_ref().ok_or_else(|| {
        anyhow::anyhow!("Database not initialized. Call setup_database first.")
    })?;
    Ok(Connection::open(path)?)
}
