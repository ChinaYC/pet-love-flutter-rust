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
    let quarter_month = (now.month() - 1) / 3 * 3 + 1;
    let start_of_quarter = Local.with_ymd_and_hms(now.year(), quarter_month, 1, 0, 0, 0)
        .single()
        .map(|dt| dt.timestamp_millis())
        .unwrap_or(0);
        
    // 获取当年的起始时间戳
    let start_of_year = Local.with_ymd_and_hms(now.year(), 1, 1, 0, 0, 0)
        .single()
        .map(|dt| dt.timestamp_millis())
        .unwrap_or(0);

    // 获取下一天/月/季/年的起始时间戳，用于闭区间查询
    let next_day = now + chrono::Duration::days(1);
    let start_of_next_day = Local.with_ymd_and_hms(next_day.year(), next_day.month(), next_day.day(), 0, 0, 0)
        .single()
        .map(|dt| dt.timestamp_millis())
        .unwrap_or(i64::MAX);

    let next_month_year = if now.month() == 12 { now.year() + 1 } else { now.year() };
    let next_month = if now.month() == 12 { 1 } else { now.month() + 1 };
    let start_of_next_month = Local.with_ymd_and_hms(next_month_year, next_month, 1, 0, 0, 0)
        .single()
        .map(|dt| dt.timestamp_millis())
        .unwrap_or(i64::MAX);

    let next_quarter_month = quarter_month + 3;
    let (next_quarter_year, final_next_quarter_month) = if next_quarter_month > 12 {
        (now.year() + 1, 1)
    } else {
        (now.year(), next_quarter_month)
    };
    let start_of_next_quarter = Local.with_ymd_and_hms(next_quarter_year, final_next_quarter_month, 1, 0, 0, 0)
        .single()
        .map(|dt| dt.timestamp_millis())
        .unwrap_or(i64::MAX);

    let start_of_next_year = Local.with_ymd_and_hms(now.year() + 1, 1, 1, 0, 0, 0)
        .single()
        .map(|dt| dt.timestamp_millis())
        .unwrap_or(i64::MAX);

    let get_total = |start: i64, end: i64| -> Result<f64, InventoryError> {
        let mut stmt = conn.prepare("SELECT SUM(cost) FROM inventory_items WHERE (status = 'active' OR status IS NULL) AND purchase_date >= ?1 AND purchase_date < ?2")?;
        let total: f64 = stmt.query_row([start, end], |row| row.get(0)).unwrap_or(0.0);
        Ok(total)
    };

    let total_day = get_total(start_of_day, start_of_next_day)?;
    let total_month = get_total(start_of_month, start_of_next_month)?;
    let total_quarter = get_total(start_of_quarter, start_of_next_quarter)?;
    let total_year = get_total(start_of_year, start_of_next_year)?;

    // 获取本月分类占比 (同样限制在当前月份内)
    let mut stmt = conn.prepare("SELECT category, SUM(cost) FROM inventory_items WHERE (status = 'active' OR status IS NULL) AND purchase_date >= ?1 AND purchase_date < ?2 GROUP BY category")?;
    let rows = stmt.query_map([start_of_month, start_of_next_month], |row| {
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
