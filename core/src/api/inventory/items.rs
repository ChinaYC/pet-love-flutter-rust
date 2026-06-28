use crate::database;
use chrono::Local;
use uuid::Uuid;
use super::models::{InventoryItem, GroupedInventoryItems, CreateItemPayload};
use super::categories::ensure_inventory_category;
use super::errors::InventoryError;

pub fn add_inventory_item(
    name: String,
    category: String,
    purchase_date: i64,
    expiration_date: i64,
    cost: f64,
    image_path: Option<String>,
) -> Result<String, InventoryError> {
    let id = Uuid::new_v4().to_string();
    let payload = CreateItemPayload {
        name,
        category,
        purchase_date,
        expiration_date,
        cost,
        image_path,
    };
    let (name, category, purchase_date, expiration_date, cost, image_path) =
        payload.validate_and_sanitize()?;
    
    // 自动确保品类存在（计算下沉：解析分类字符串并维护分类表）
    if category.contains('/') {
        let parts: Vec<&str> = category.split('/').collect();
        let parent = parts[0].trim().to_string();
        let sub = parts.get(1).map(|s| s.trim().to_string());
        let _ = ensure_inventory_category(parent, sub);
    } else {
        let _ = ensure_inventory_category(category.clone(), None);
    }

    let conn = database::get_connection()?;
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
    )?;
    
    Ok(id)
}

pub fn update_inventory_item(
    id: String,
    name: String,
    category: String,
    purchase_date: i64,
    expiration_date: i64,
    cost: f64,
    image_path: Option<String>,
) -> Result<(), InventoryError> {
    let payload = CreateItemPayload {
        name,
        category,
        purchase_date,
        expiration_date,
        cost,
        image_path,
    };
    let (name, category, purchase_date, expiration_date, cost, image_path) =
        payload.validate_and_sanitize()?;

    // 自动确保品类存在（计算下沉：解析分类字符串并维护分类表）
    if category.contains('/') {
        let parts: Vec<&str> = category.split('/').collect();
        let parent = parts[0].trim().to_string();
        let sub = parts.get(1).map(|s| s.trim().to_string());
        let _ = ensure_inventory_category(parent, sub);
    } else {
        let _ = ensure_inventory_category(category.clone(), None);
    }

    let conn = database::get_connection()?;
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
        )?;

    if updated_rows == 0 {
        return Err(InventoryError::ItemNotFound);
    }

    Ok(())
}

pub fn get_active_inventory_items() -> Result<Vec<InventoryItem>, InventoryError> {
    let conn = database::get_connection()?;
    let mut stmt = conn
        .prepare("SELECT id, name, category, purchase_date, expiration_date, cost, status, image_path FROM inventory_items WHERE status = 'active' OR status IS NULL ORDER BY expiration_date ASC")?;
        
    let now = Local::now().timestamp_millis();
    
    let items = stmt
        .query_map([], |row| {
            let status: String = row.get(6).unwrap_or_else(|_| "active".to_string());
            let purchase_date: i64 = row.get(3)?;
            let expiration_date: i64 = row.get(4)?;
            
            // 计算已拥有天数
            let days_owned = (now - purchase_date) / (24 * 60 * 60 * 1000);
            // 计算剩余天数 (如果 expiration_date 为 0，则设为 0)
            let days_left = if expiration_date == 0 {
                0
            } else {
                (expiration_date - now) / (24 * 60 * 60 * 1000)
            };

            // 计算日均成本：总价 / (已持有天数 + 1)
            // 这样持有时间越长，每天成本越低，符合用户直觉
            let daily_cost = row.get::<_, f64>(5)? / (days_owned.abs() as f64 + 1.0);

            Ok(InventoryItem {
                id: row.get(0)?,
                name: row.get(1)?,
                category: row.get(2)?,
                purchase_date,
                expiration_date,
                cost: row.get(5)?,
                status,
                image_path: row.get(7)?,
                days_owned,
                days_left,
                daily_cost,
            })
        })?
        .collect::<Result<Vec<InventoryItem>, _>>()?;
        
    Ok(items)
}

pub fn search_and_group_inventory_items(query: String) -> Result<Vec<GroupedInventoryItems>, InventoryError> {
    let conn = database::get_connection()?;
    let query_pattern = format!("%{}%", query.to_lowercase());
    
    let mut stmt = conn
        .prepare("SELECT id, name, category, purchase_date, expiration_date, cost, status, image_path FROM inventory_items 
                  WHERE (status = 'active' OR status IS NULL) 
                  AND (LOWER(name) LIKE ?1 OR LOWER(category) LIKE ?1)
                  ORDER BY category ASC, expiration_date ASC")?;
        
    let now = Local::now().timestamp_millis();
    
    // 搜索结果统计逻辑：如果 query 为空，则返回所有项目
    
    let items = stmt
        .query_map([&query_pattern], |row| {
            let status: String = row.get(6).unwrap_or_else(|_| "active".to_string());
            let purchase_date: i64 = row.get(3)?;
            let expiration_date: i64 = row.get(4)?;
            
            let days_owned = (now - purchase_date) / (24 * 60 * 60 * 1000);
            let days_left = if expiration_date == 0 {
                0
            } else {
                (expiration_date - now) / (24 * 60 * 60 * 1000)
            };

            let daily_cost = row.get::<_, f64>(5)? / (days_owned.abs() as f64 + 1.0);

            Ok(InventoryItem {
                id: row.get(0)?,
                name: row.get(1)?,
                category: row.get(2)?,
                purchase_date,
                expiration_date,
                cost: row.get(5)?,
                status,
                image_path: row.get(7)?,
                days_owned,
                days_left,
                daily_cost,
            })
        })?
        .collect::<Result<Vec<InventoryItem>, _>>()?;

    let mut groups_map: std::collections::BTreeMap<String, Vec<InventoryItem>> = std::collections::BTreeMap::new();
    for item in items {
        let parent_cat = item.category.split('/').next().unwrap_or("其他").trim().to_string();
        groups_map.entry(parent_cat).or_default().push(item);
    }

    let result = groups_map
        .into_iter()
        .map(|(category, items)| GroupedInventoryItems {
            count: items.len() as i64,
            category,
            items,
        })
        .collect();

    Ok(result)
}

pub fn delete_inventory_item(id: String) -> Result<(), InventoryError> {
    let conn = database::get_connection()?;
    conn.execute(
        "UPDATE inventory_items SET status = 'deleted' WHERE id = ?1",
        [&id],
    )?;
    
    Ok(())
}

pub fn batch_delete_inventory_items(ids: Vec<String>) -> Result<(), InventoryError> {
    let mut conn = database::get_connection()?;
    let tx = conn.transaction()?;
    
    for id in ids {
        tx.execute(
            "UPDATE inventory_items SET status = 'deleted' WHERE id = ?1",
            [&id],
        )?;
    }
    
    tx.commit()?;
    Ok(())
}
