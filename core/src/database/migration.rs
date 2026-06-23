use rusqlite::{Connection, Result};
// tracing 会在实际项目中被使用
// use tracing::{info, warn};

const DB_VERSION: i32 = 2; // 当前应用程序期望的最新数据库版本

/// 初始化数据库连接并执行自动迁移策略
pub fn init_database(db_path: &str) -> Result<Connection> {
    let mut conn = Connection::open(db_path)?;

    // 获取当前 SQLite 数据库文件内的版本号
    let current_version: i32 = conn.query_row("PRAGMA user_version", [], |row| row.get(0))?;
    
    // println!("当前数据库版本: {}, 期望版本: {}", current_version, DB_VERSION);

    if current_version < DB_VERSION {
        // 开启事务，确保所有迁移脚本原子执行
        let tx = conn.transaction()?;

        // ==========================================
        // 步骤 1 & 2: 首次全新安装或初始表结构定义 (v1)
        // 包含静态模型定义，并预留 NULL 以支持包容性查询
        // ==========================================
        if current_version < 1 {
            // println!("执行 V1 迁移: 创建初始表结构");
            tx.execute(
                "CREATE TABLE IF NOT EXISTS pet_status_logs (
                    id TEXT PRIMARY KEY,
                    pet_id TEXT NOT NULL,
                    data_type TEXT NOT NULL,
                    data_value TEXT NOT NULL,
                    created_by TEXT NOT NULL,
                    client_timestamp INTEGER NOT NULL,
                    status TEXT DEFAULT 'active', -- 预留 NULL 兼容老客户端
                    sync_status TEXT DEFAULT 'pending'
                )",
                [],
            )?;
            
            // app_settings 表：用于存储应用状态，如最后打开的页面、用户偏好等
            tx.execute(
                "CREATE TABLE IF NOT EXISTS app_settings (
                    key TEXT PRIMARY KEY,
                    value TEXT NOT NULL
                )",
                [],
            )?;
            
            // inventory_items 表：用于存储物品库存，保质期，成本等
            tx.execute(
                "CREATE TABLE IF NOT EXISTS inventory_items (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    category TEXT NOT NULL,
                    purchase_date INTEGER NOT NULL,
                    expiration_date INTEGER NOT NULL,
                    cost REAL NOT NULL,
                    status TEXT DEFAULT 'active',
                    image_path TEXT
                )",
                [],
            )?;
            
            // inventory_categories 表
            tx.execute(
                "CREATE TABLE IF NOT EXISTS inventory_categories (
                    id TEXT PRIMARY KEY,
                    name TEXT NOT NULL,
                    parent_id TEXT,
                    sort_order INTEGER DEFAULT 0,
                    is_preset INTEGER DEFAULT 0
                )",
                [],
            )?;
        }

        // 更新数据库的内部版本号到最新
        tx.pragma_update(None, "user_version", &DB_VERSION)?;
        
        tx.commit()?;
        // println!("数据库迁移完成！最新版本: {}", DB_VERSION);
    }

    // ==========================================
    // 强制检查并补全缺失表 (防御性编程)
    // ==========================================
    conn.execute(
        "CREATE TABLE IF NOT EXISTS inventory_categories (
            id TEXT PRIMARY KEY,
            name TEXT NOT NULL,
            parent_id TEXT,
            sort_order INTEGER DEFAULT 0,
            is_preset INTEGER DEFAULT 0
        )",
        [],
    )?;

    // ==========================================
    // 强制检查并补全缺失字段 (用于开发环境 V1 结构更新)
    // 这样即便用户数据库版本 > 1 也能补充上新字段
    // ==========================================
    let table_info: Vec<String> = conn
        .prepare("PRAGMA table_info(inventory_items)")?
        .query_map([], |row| row.get(1))?
        .collect::<Result<Vec<String>, _>>()?;
    
    if !table_info.contains(&"image_path".to_string()) {
        conn.execute("ALTER TABLE inventory_items ADD COLUMN image_path TEXT", [])?;
    }

    let log_info: Vec<String> = conn
        .prepare("PRAGMA table_info(pet_status_logs)")?
        .query_map([], |row| row.get(1))?
        .collect::<Result<Vec<String>, _>>()?;
    
    if !log_info.contains(&"sync_status".to_string()) {
        conn.execute("ALTER TABLE pet_status_logs ADD COLUMN sync_status TEXT DEFAULT 'pending'", [])?;
    }

    Ok(conn)
}

/// 演示包容性查询 (Tolerant Query)
pub fn fetch_active_logs(conn: &Connection) -> Result<()> {
    // 在查询阶段尽量包容状态字段为 NULL 的情况（保护老客户端产生的数据）
    let mut stmt = conn.prepare(
        "SELECT id, pet_id, status, sync_status 
         FROM pet_status_logs 
         WHERE status = 'active' OR status IS NULL"
    )?;

    // 假设进行映射处理...
    let _log_iter = stmt.query_map([], |row| {
        let id: String = row.get(0)?;
        let _pet_id: String = row.get(1)?;
        // 将可能为 NULL 的状态安全转换为默认值
        let _status: String = row.get(2).unwrap_or_else(|_| "active".to_string());
        let _sync_status: String = row.get(3).unwrap_or_else(|_| "pending".to_string());
        
        Ok(id)
    })?;

    Ok(())
}
