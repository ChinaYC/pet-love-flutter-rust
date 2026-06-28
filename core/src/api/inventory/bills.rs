use crate::database;
use chrono::{Local, TimeZone};
use super::models::{InventoryItem, MonthGroupedItems, InventorySearchQuery};
use super::errors::InventoryError;

pub fn search_and_group_by_month(
    query: InventorySearchQuery,
) -> Result<Vec<MonthGroupedItems>, InventoryError> {
    let conn = database::get_connection()?;
    
    let mut sql = "SELECT id, name, category, purchase_date, expiration_date, cost, status, image_path 
                   FROM inventory_items 
                   WHERE (status = 'active' OR status IS NULL)".to_string();
    
    let mut params: Vec<Box<dyn rusqlite::ToSql>> = Vec::new();
    
    if let Some(q) = query.query {
        if !q.trim().is_empty() {
            sql.push_str(" AND (LOWER(name) LIKE ? OR LOWER(category) LIKE ?)");
            let pattern = format!("%{}%", q.trim().to_lowercase());
            params.push(Box::new(pattern.clone()));
            params.push(Box::new(pattern));
        }
    }
    
    if let Some(cat) = query.category {
        if !cat.trim().is_empty() && cat != "全部" {
            sql.push_str(" AND category = ?");
            params.push(Box::new(cat));
        }
    }
    
    if let Some(start) = query.start_date {
        if start > 0 {
            sql.push_str(" AND purchase_date >= ?");
            params.push(Box::new(start));
        }
    }
    
    if let Some(end) = query.end_date {
        if end > 0 {
            sql.push_str(" AND purchase_date <= ?");
            params.push(Box::new(end));
        }
    }
    
    if let Some(min) = query.min_cost {
        sql.push_str(" AND cost >= ?");
        params.push(Box::new(min));
    }
    
    if let Some(max) = query.max_cost {
        sql.push_str(" AND cost <= ?");
        params.push(Box::new(max));
    }
    
    sql.push_str(" ORDER BY purchase_date DESC");
    
    let mut stmt = conn.prepare(&sql)?;
    
    let now = Local::now().timestamp_millis();
    
    // Convert Vec<Box<dyn ToSql>> to a slice of &dyn ToSql
    let params_refs: Vec<&dyn rusqlite::ToSql> = params.iter().map(|p| p.as_ref()).collect();

    let items = stmt
        .query_map(params_refs.as_slice(), |row| {
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

    // Group by month (using Local time to ensure consistency with stats)
    let mut groups: std::collections::BTreeMap<String, MonthGroupedItems> = std::collections::BTreeMap::new();
    
    for item in items {
        // 使用 Local 时区进行月份分组，确保与统计概览中的“本月”定义一致
        let dt = Local.timestamp_millis_opt(item.purchase_date).unwrap();
        let month = dt.format("%Y-%m").to_string();
        
        let group = groups.entry(month.clone()).or_insert(MonthGroupedItems {
            month,
            total_cost: 0.0,
            items: Vec::new(),
        });
        
        group.total_cost += item.cost;
        group.items.push(item);
    }
    
    // Convert to Vec and sort by month descending
    let mut result: Vec<MonthGroupedItems> = groups.into_values().collect();
    result.sort_by(|a, b| b.month.cmp(&a.month));
    
    Ok(result)
}
