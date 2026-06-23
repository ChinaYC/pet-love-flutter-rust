use serde::{Deserialize, Serialize};
use super::errors::InventoryError;

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
    pub days_owned: i64,
    pub days_left: i64,
    pub daily_cost: f64,
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
    pub percentage: f64,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct AccountOverviewStats {
    pub total_year: f64,
    pub total_quarter: f64,
    pub total_month: f64,
    pub total_day: f64,
    pub category_stats: Vec<CategoryCostStat>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct GroupedInventoryItems {
    pub category: String,
    pub count: i64,
    pub items: Vec<InventoryItem>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct MonthGroupedItems {
    pub month: String, // e.g., "2023-10"
    pub total_cost: f64,
    pub items: Vec<InventoryItem>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InventorySearchQuery {
    pub query: Option<String>,
    pub category: Option<String>,
    pub start_date: Option<i64>,
    pub end_date: Option<i64>,
    pub min_cost: Option<f64>,
    pub max_cost: Option<f64>,
}

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct InventoryCategory {
    pub id: String,
    pub name: String,
    pub parent_id: Option<String>,
    pub sort_order: i32,
    pub is_preset: bool,
}

pub struct CreateItemPayload {
    pub name: String,
    pub category: String,
    pub purchase_date: i64,
    pub expiration_date: i64,
    pub cost: f64,
    pub image_path: Option<String>,
}

impl CreateItemPayload {
    pub fn validate_and_sanitize(self) -> Result<(String, String, i64, i64, f64, Option<String>), InventoryError> {
        let normalized_name = self.name.trim().to_string();
        if normalized_name.is_empty() {
            return Err(InventoryError::EmptyName);
        }

        let normalized_category = {
            let trimmed = self.category.trim();
            if trimmed.is_empty() {
                "其他".to_string()
            } else {
                trimmed.to_string()
            }
        };

        if self.expiration_date != 0 && self.expiration_date < self.purchase_date {
            return Err(InventoryError::InvalidExpirationDate);
        }

        let normalized_cost = self.cost.max(0.0);
        let normalized_image_path = self.image_path.and_then(|path| {
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
            self.purchase_date,
            self.expiration_date,
            normalized_cost,
            normalized_image_path,
        ))
    }
}
