use crate::database;
use super::models::{CategoryStat, CategoryCostStat, AccountOverviewStats};
use super::errors::InventoryError;
use chrono::{Datelike, Local, TimeZone};

pub fn get_account_overview_stats() -> Result<AccountOverviewStats, InventoryError> {
    let conn = database::get_connection()?;
    let now = Local::now();
    
    // 获取当天的起始时间戳 (Local -> Utc millis)
    let start_of_day = Local.with_ymd_and_hms(now.year(), now.month(), now.day(), 0, 0, 0)
        .single()
        .map(|dt| dt.timestamp_millis())
        .unwrap_or(0);
        
    // 获取当月的起始时间戳
    let start_of_month = Local.with_ymd_and_hms(now.year(), now.month(), 1, 0, 0, 0)
        .single()
        .map(|dt| dt.timestamp_millis())
        .unwrap_or(0);
        
    // 获取当季的起始时间戳
    let quarter_month = ((now.month() - 1) / 3) * 3 + 1;
    let start_of_quarter = Local.with_ymd_and_hms(now.year(), quarter_month, 1, 0, 0, 0)
        .single()
        .map(|dt| dt.timestamp_millis())
        .unwrap_or(0);
        
    // 获取当年的起始时间戳
    let start_of_year = Local.with_ymd_and_hms(now.year(), 1, 1, 0, 0, 0)
        .single()
        .map(|dt| dt.timestamp_millis())
        .unwrap_or(0);

    let get_total = |start: i64| -> Result<f64, InventoryError> {
        let mut stmt = conn.prepare("SELECT SUM(cost) FROM inventory_items WHERE (status = 'active' OR status IS NULL) AND purchase_date >= ?1")?;
        let total: f64 = stmt.query_row([start], |row| row.get(0)).unwrap_or(0.0);
        Ok(total)
    };

    let total_day = get_total(start_of_day)?;
    let total_month = get_total(start_of_month)?;
    let total_quarter = get_total(start_of_quarter)?;
    let total_year = get_total(start_of_year)?;

    // 获取本月分类占比
    let mut stmt = conn.prepare("SELECT category, SUM(cost) FROM inventory_items WHERE (status = 'active' OR status IS NULL) AND purchase_date >= ?1 GROUP BY category")?;
    let rows = stmt.query_map([start_of_month], |row| {
        Ok((row.get::<_, String>(0)?, row.get::<_, f64>(1)?))
    })?;

    let mut stats_map: std::collections::HashMap<String, f64> = std::collections::HashMap::new();
    let mut month_total = 0.0;

    for row_result in rows {
        let (full_category, cost) = row_result?;
        let parent = full_category.split('/').next().unwrap_or("其他").trim().to_string();
        *stats_map.entry(parent).or_insert(0.0) += cost;
        month_total += cost;
    }

    let mut category_stats: Vec<CategoryCostStat> = stats_map
        .into_iter()
        .map(|(name, total_cost)| CategoryCostStat {
            name,
            total_cost,
            percentage: if month_total > 0.0 { total_cost / month_total } else { 0.0 },
        })
        .collect();

    category_stats.sort_by(|a, b| b.total_cost.partial_cmp(&a.total_cost).unwrap_or(std::cmp::Ordering::Equal));

    Ok(AccountOverviewStats {
        total_year,
        total_quarter,
        total_month,
        total_day,
        category_stats,
    })
}

pub fn get_category_stats() -> Result<Vec<CategoryStat>, InventoryError> {
    let conn = database::get_connection()?;
    let mut stmt = conn
        .prepare("SELECT category, COUNT(*) FROM inventory_items WHERE status = 'active' OR status IS NULL GROUP BY category")?;

    let rows = stmt
        .query_map([], |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, u32>(1)?))
        })?;

    let mut stats_map: std::collections::HashMap<String, u32> = std::collections::HashMap::new();

    for row_result in rows {
        let (full_category, count) = row_result?;
        
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

pub fn get_category_cost_stats() -> Result<Vec<CategoryCostStat>, InventoryError> {
    let conn = database::get_connection()?;
    let mut stmt = conn
        .prepare("SELECT category, SUM(cost) FROM inventory_items WHERE status = 'active' OR status IS NULL GROUP BY category")?;

    let rows = stmt
        .query_map([], |row| {
            Ok((row.get::<_, String>(0)?, row.get::<_, f64>(1)?))
        })?;

    let mut stats_map: std::collections::HashMap<String, f64> = std::collections::HashMap::new();

    for row_result in rows {
        let (full_category, cost) = row_result?;
        
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
        .map(|(name, total_cost)| CategoryCostStat { 
            name, 
            total_cost,
            percentage: 0.0, // 旧接口不计算百分比
        })
        .collect();

    // 按金额降序排列
    result.sort_by(|a, b| b.total_cost.partial_cmp(&a.total_cost).unwrap_or(std::cmp::Ordering::Equal));

    Ok(result)
}
