use thiserror::Error;

#[derive(Error, Debug)]
pub enum InventoryError {
    #[error("数据库错误: {0}")]
    DatabaseError(#[from] rusqlite::Error),

    #[error("系统错误: {0}")]
    SystemError(#[from] anyhow::Error),

    #[error("物品名称不能为空")]
    EmptyName,

    #[error("过期时间不能早于购买时间")]
    InvalidExpirationDate,

    #[error("未找到可编辑的囤货记录")]
    ItemNotFound,

    #[error("未找到可编辑的分类")]
    CategoryNotFound,

    #[error("未找到要删除的分类")]
    DeleteCategoryNotFound,

    #[error("业务逻辑错误: {0}")]
    BusinessError(String),
}
