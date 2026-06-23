use crate::database;
use uuid::Uuid;
use rusqlite::OptionalExtension;
use super::models::InventoryCategory;
use super::errors::InventoryError;

pub fn add_inventory_category(
    name: String,
    parent_id: Option<String>,
    sort_order: i32,
    is_preset: bool,
) -> Result<String, InventoryError> {
    let conn = database::get_connection()?;
    let id = Uuid::new_v4().to_string();
    
    conn.execute(
        "INSERT INTO inventory_categories (id, name, parent_id, sort_order, is_preset)
         VALUES (?1, ?2, ?3, ?4, ?5)",
        (
            &id,
            &name,
            &parent_id,
            sort_order,
            if is_preset { 1 } else { 0 },
        ),
    )?;
    
    Ok(id)
}

pub fn get_inventory_categories() -> Result<Vec<InventoryCategory>, InventoryError> {
    let conn = database::get_connection()?;
    let mut stmt = conn
        .prepare("SELECT id, name, parent_id, sort_order, is_preset FROM inventory_categories ORDER BY sort_order ASC, name ASC")?;
        
    let categories = stmt
        .query_map([], |row| {
            Ok(InventoryCategory {
                id: row.get(0)?,
                name: row.get(1)?,
                parent_id: row.get(2)?,
                sort_order: row.get(3)?,
                is_preset: row.get::<_, i32>(4)? > 0,
            })
        })?
        .collect::<Result<Vec<InventoryCategory>, _>>()?;
        
    Ok(categories)
}

pub fn update_inventory_category(
    id: String,
    name: String,
    parent_id: Option<String>,
    sort_order: i32,
) -> Result<(), InventoryError> {
    let conn = database::get_connection()?;
    
    let updated_rows = conn
        .execute(
            "UPDATE inventory_categories
             SET name = ?2,
                 parent_id = ?3,
                 sort_order = ?4
             WHERE id = ?1",
            (
                &id,
                &name,
                &parent_id,
                sort_order,
            ),
        )?;

    if updated_rows == 0 {
        return Err(InventoryError::CategoryNotFound);
    }

    Ok(())
}

pub fn delete_inventory_category(id: String) -> Result<(), InventoryError> {
    let conn = database::get_connection()?;

    let deleted_rows = conn
        .execute("DELETE FROM inventory_categories WHERE id = ?1", [&id])?;

    if deleted_rows == 0 {
        return Err(InventoryError::DeleteCategoryNotFound);
    }

    Ok(())
}

pub fn ensure_inventory_category(
    parent_name: String,
    sub_name: Option<String>,
) -> Result<(), InventoryError> {
    let mut conn = database::get_connection()?;
    let tx = conn.transaction()?;

    // 1. 检查或创建父分类
    let parent_id: Option<String> = tx
        .query_row(
            "SELECT id FROM inventory_categories WHERE name = ?1 AND parent_id IS NULL",
            [&parent_name],
            |row| row.get(0),
        )
        .optional()?;

    let final_parent_id = match parent_id {
        Some(id) => id,
        None => {
            let id = Uuid::new_v4().to_string();
            tx.execute(
                "INSERT INTO inventory_categories (id, name, parent_id, sort_order, is_preset) VALUES (?1, ?2, NULL, 999, 0)",
                (&id, &parent_name),
            )?;
            id
        }
    };

    // 2. 如果有子分类，检查或创建
    if let Some(sub) = sub_name {
        let sub_id: Option<String> = tx
            .query_row(
                "SELECT id FROM inventory_categories WHERE name = ?1 AND parent_id = ?2",
                [&sub, &final_parent_id],
                |row| row.get(0),
            )
            .optional()?;

        if sub_id.is_none() {
            let id = Uuid::new_v4().to_string();
            tx.execute(
                "INSERT INTO inventory_categories (id, name, parent_id, sort_order, is_preset) VALUES (?1, ?2, ?3, 999, 0)",
                (&id, &sub, &final_parent_id),
            )?;
        }
    }

    tx.commit()?;
    Ok(())
}

pub fn batch_update_inventory_category(ids: Vec<String>, category: String) -> Result<(), InventoryError> {
    let mut conn = database::get_connection()?;
    let tx = conn.transaction()?;
    
    // 自动确保品类存在
    if category.contains('/') {
        let parts: Vec<&str> = category.split('/').collect();
        let parent = parts[0].trim().to_string();
        let sub = parts.get(1).map(|s| s.trim().to_string());
        let _ = ensure_inventory_category(parent, sub);
    } else {
        let _ = ensure_inventory_category(category.clone(), None);
    }

    for id in ids {
        tx.execute(
            "UPDATE inventory_items SET category = ?2 WHERE id = ?1",
            (&id, &category),
        )?;
    }
    
    tx.commit()?;
    Ok(())
}
