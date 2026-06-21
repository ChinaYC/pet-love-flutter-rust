use crate::database;
use serde::{Deserialize, Serialize};
use uuid::Uuid;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InventoryItem {
    pub id: String,
    pub name: String,
    pub category: String,
    pub purchase_date: i64,
    pub expiration_date: i64,
    pub cost: f64,
    pub status: String,
    pub image_path: Option<String>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CategoryStat {
    pub name: String,
    pub count: u32,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct CategoryCostStat {
    pub name: String,
    pub total_cost: f64,
}

/// 功能：在新增或更新囤货前统一清洗和校验输入数据。
/// 参数：名称、分类、购买时间、过期时间、花费、图片路径。
/// 返回值：返回清洗后的安全入库数据，或错误信息。
/// 注意事项：这是最终写库前的兜底入口，不能只依赖前端交互事件保证数据正确。
fn sanitize_inventory_payload(
    name: String,
    category: String,
    purchase_date: i64,
    expiration_date: i64,
    cost: f64,
    image_path: Option<String>,
) -> Result<(String, String, i64, i64, f64, Option<String>), String> {
    let normalized_name = name.trim().to_string();
    if normalized_name.is_empty() {
        return Err("物品名称不能为空".to_string());
    }

    let normalized_category = {
        let trimmed = category.trim();
        if trimmed.is_empty() {
            "其他".to_string()
        } else {
            trimmed.to_string()
        }
    };

    if expiration_date < purchase_date {
        return Err("过期时间不能早于购买时间".to_string());
    }

    let normalized_cost = cost.max(0.0);
    let normalized_image_path = image_path.and_then(|path| {
        let trimmed = path.trim().to_string();
        if trimmed.is_empty() {
            None
        } else {
            Some(trimmed)
        }
    });

    Ok((
        normalized_name,
        normalized_category,
        purchase_date,
        expiration_date,
        normalized_cost,
        normalized_image_path,
    ))
}

pub fn add_inventory_item(
    name: String,
    category: String,
    purchase_date: i64,
    expiration_date: i64,
    cost: f64,
    image_path: Option<String>,
) -> Result<String, String> {
    let conn = database::get_connection().map_err(|e| e.to_string())?;
    let id = Uuid::new_v4().to_string();
    let (name, category, purchase_date, expiration_date, cost, image_path) =
        sanitize_inventory_payload(name, category, purchase_date, expiration_date, cost, image_path)?;
    
    conn.execute(
        "INSERT INTO inventory_items (id, name, category, purchase_date, expiration_date, cost, status, image_path)
         VALUES (?1, ?2, ?3, ?4, ?5, ?6, 'active', ?7)",
        (
            &id,
            &name,
            &category,
            purchase_date,
            expiration_date,
            cost,
            &image_path,
        ),
    )
    .map_err(|e| e.to_string())?;
    
    Ok(id)
}

/// 功能：更新现有囤货记录。
/// 参数：记录 ID、名称、分类、购买时间、过期时间、花费、图片路径。
/// 返回值：成功返回空，失败返回错误信息。
/// 注意事项：更新前同样必须执行兜底清洗，避免编辑页历史脏数据直接覆盖数据库。
pub fn update_inventory_item(
    id: String,
    name: String,
    category: String,
    purchase_date: i64,
    expiration_date: i64,
    cost: f64,
    image_path: Option<String>,
) -> Result<(), String> {
    let conn = database::get_connection().map_err(|e| e.to_string())?;
    let (name, category, purchase_date, expiration_date, cost, image_path) =
        sanitize_inventory_payload(name, category, purchase_date, expiration_date, cost, image_path)?;

    let updated_rows = conn
        .execute(
            "UPDATE inventory_items
             SET name = ?2,
                 category = ?3,
                 purchase_date = ?4,
                 expiration_date = ?5,
                 cost = ?6,
                 image_path = ?7
             WHERE id = ?1 AND (status = 'active' OR status IS NULL)",
            (
                &id,
                &name,
                &category,
                purchase_date,
                expiration_date,
                cost,
                &image_path,
            ),
        )
        .map_err(|e| e.to_string())?;

    if updated_rows == 0 {
        return Err("未找到可编辑的囤货记录".to_string());
    }

    Ok(())
}

pub fn get_active_inventory_items() -> Result<Vec<InventoryItem>, String> {
    let conn = database::get_connection().map_err(|e| e.to_string())?;
    let mut stmt = conn
        .prepare("SELECT id, name, category, purchase_date, expiration_date, cost, status, image_path FROM inventory_items WHERE status = 'active' OR status IS NULL ORDER BY expiration_date ASC")
        .map_err(|e| e.to_string())?;
        
    let items = stmt
        .query_map([], |row| {
            let status: String = row.get(6).unwrap_or_else(|_| "active".to_string());
            Ok(InventoryItem {
                id: row.get(0)?,
                name: row.get(1)?,
                category: row.get(2)?,
                purchase_date: row.get(3)?,
                expiration_date: row.get(4)?,
                cost: row.get(5)?,
                status,
                image_path: row.get(7)?,
            })
        })
        .map_err(|e| e.to_string())?
        .collect::<Result<Vec<InventoryItem>, _>>()
        .map_err(|e| e.to_string())?;
        
    Ok(items)
}

pub fn delete_inventory_item(id: String) -> Result<(), String> {
    let conn = database::get_connection().map_err(|e| e.to_string())?;
    conn.execute(
        "UPDATE inventory_items SET status = 'deleted' WHERE id = ?1",
        [&id],
    )
    .map_err(|e| e.to_string())?;
    
    Ok(())
}

/// 保存新增囤货的草稿 (JSON 格式)
pub fn save_inventory_draft(json_data: String) -> Result<(), String> {
    let conn = database::get_connection().map_err(|e| e.to_string())?;
    conn.execute(
        "INSERT OR REPLACE INTO app_settings (key, value) VALUES ('inventory_add_draft', ?1)",
        [json_data],
    ).map_err(|e| e.to_string())?;
    Ok(())
}

/// 获取新增囤货的草稿
pub fn get_inventory_draft() -> Result<Option<String>, String> {
    let conn = database::get_connection().map_err(|e| e.to_string())?;
    let mut stmt = conn.prepare("SELECT value FROM app_settings WHERE key = 'inventory_add_draft'")
        .map_err(|e| e.to_string())?;
    
    let mut rows = stmt.query([]).map_err(|e| e.to_string())?;
    if let Some(row) = rows.next().map_err(|e| e.to_string())? {
        let value: String = row.get(0).map_err(|e| e.to_string())?;
        Ok(Some(value))
    } else {
        Ok(None)
    }
}

/// 清除新增囤货的草稿
pub fn clear_inventory_draft() -> Result<(), String> {
    let conn = database::get_connection().map_err(|e| e.to_string())?;
    conn.execute(
        "DELETE FROM app_settings WHERE key = 'inventory_add_draft'",
        [],
    ).map_err(|e| e.to_string())?;
    Ok(())
}

/// 功能：获取所有活跃囤货的分类统计数量。
/// 返回值：包含分类名称及其对应数量的列表。
/// 注意事项：在 Rust 层直接进行 SQL 聚合，性能远高于拉取全量数据到 Dart 层处理。
pub fn get_category_stats() -> Result<Vec<CategoryStat>, String> {
    let conn = database::get_connection().map_err(|e| e.to_string())?;
    let mut stmt = conn
        .prepare("SELECT category, COUNT(*) FROM inventory_items WHERE status = 'active' OR status IS NULL GROUP BY category")
        .map_err(|e| e.to_string())?;

    let rows = stmt
        .query_map([], |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, u32>(1)?))
        })
        .map_err(|e| e.to_string())?;

    let mut stats_map: std::collections::HashMap<String, u32> = std::collections::HashMap::new();

    for row_result in rows {
        let (full_category, count) = row_result.map_err(|e| e.to_string())?;
        
        // 1. 记录完整的子分类统计 (e.g. "食品伙食 / 主粮")
        *stats_map.entry(full_category.clone()).or_insert(0) += count;

        // 2. 如果包含层级，拆分并累加父分类统计 (e.g. "食品伙食")
        if full_category.contains('/') {
            let parent = full_category.split('/').next().unwrap_or("").trim().to_string();
            if !parent.is_empty() {
                *stats_map.entry(parent).or_insert(0) += count;
            }
        }
    }

    let result = stats_map
        .into_iter()
        .map(|(name, count)| CategoryStat { name, count })
        .collect();

    Ok(result)
}

/// 功能：获取所有活跃囤货的分类金额统计。
/// 返回值：包含分类名称及其对应累计金额的列表。
pub fn get_category_cost_stats() -> Result<Vec<CategoryCostStat>, String> {
    let conn = database::get_connection().map_err(|e| e.to_string())?;
    let mut stmt = conn
        .prepare("SELECT category, SUM(cost) FROM inventory_items WHERE status = 'active' OR status IS NULL GROUP BY category")
        .map_err(|e| e.to_string())?;

    let rows = stmt
        .query_map([], |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, f64>(1)?))
        })
        .map_err(|e| e.to_string())?;

    let mut stats_map: std::collections::HashMap<String, f64> = std::collections::HashMap::new();

    for row_result in rows {
        let (full_category, cost) = row_result.map_err(|e| e.to_string())?;
        
        // 统计父分类金额
        let parent = if full_category.contains('/') {
            full_category.split('/').next().unwrap_or("").trim().to_string()
        } else {
            full_category.trim().to_string()
        };

        if !parent.is_empty() {
            *stats_map.entry(parent).or_insert(0.0) += cost;
        }
    }

    let mut result: Vec<CategoryCostStat> = stats_map
        .into_iter()
        .map(|(name, total_cost)| CategoryCostStat { name, total_cost })
        .collect();

    // 按金额降序排列
    result.sort_by(|a, b| b.total_cost.partial_cmp(&a.total_cost).unwrap_or(std::cmp::Ordering::Equal));

    Ok(result)
}
