use serde::{Deserialize, Serialize};
use uuid::Uuid;
use chrono::Utc;

#[derive(Debug, Clone, Serialize, Deserialize)]
pub struct PetStatusLog {
    pub id: String,
    pub pet_id: String,
    pub data_type: String,
    pub data_value: String,
    pub created_by: String,
    pub client_timestamp: i64,
    pub status: String, // 'active' 或 'superseded'
}

/// 检查指定宠物模块的未决冲突
/// 
/// 查找同一 `pet_id` 和 `data_type` 下，状态为 'active' 的多条记录。
pub fn check_pet_conflicts(pet_id: String, data_type: String) -> Result<Vec<PetStatusLog>, String> {
    // 模拟数据库查询：正常情况下会通过 rusqlite 检索 SQLite 数据库
    // 这里构造两条冲突记录（比如断网期间两人都修改了宠物体重）
    
    // tracing::info!("Checking conflicts for pet_id: {}, data_type: {}", pet_id, data_type);
    
    let conflict_logs = vec![
        PetStatusLog {
            id: Uuid::new_v4().to_string(),
            pet_id: pet_id.clone(),
            data_type: data_type.clone(),
            data_value: "5.2kg".to_string(),
            created_by: "user_a".to_string(),
            client_timestamp: Utc::now().timestamp_millis() - 5000,
            status: "active".to_string(),
        },
        PetStatusLog {
            id: Uuid::new_v4().to_string(),
            pet_id: pet_id.clone(),
            data_type: data_type.clone(),
            data_value: "5.5kg".to_string(),
            created_by: "user_b".to_string(),
            client_timestamp: Utc::now().timestamp_millis() - 2000,
            status: "active".to_string(),
        }
    ];

    Ok(conflict_logs)
}

/// 解决冲突并保存最终结果
///
/// `log_id_to_keep`: 若选择保留某条冲突记录，则传其 ID
/// `merged_value`: 若选择输入全新合并值，则传合并后的值
pub fn resolve_pet_conflict(
    pet_id: String, 
    data_type: String, 
    log_id_to_keep: Option<String>, 
    merged_value: Option<String>
) -> Result<(), String> {
    // tracing::info!("Resolving conflict for pet: {}, type: {}", pet_id, data_type);
    
    // 1. 在数据库中将所有该 pet_id & data_type 的 'active' 记录更新为 'superseded'
    
    // 2. 插入一条新的 'active' 记录，代表最终裁决结果
    let final_value = if let Some(val) = merged_value {
        val
    } else if let Some(_id) = log_id_to_keep {
        // 实际场景需要通过 id 查出原 value
        "Resolved_Value".to_string()
    } else {
        return Err("Must provide either a log_id_to_keep or a merged_value".to_string());
    };

    let _new_log = PetStatusLog {
        id: Uuid::new_v4().to_string(),
        pet_id,
        data_type,
        data_value: final_value,
        created_by: "system_resolver".to_string(),
        client_timestamp: Utc::now().timestamp_millis(),
        status: "active".to_string(),
    };

    // 执行 INSERT 写入 SQLite 数据库 ...

    Ok(())
}
