import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../../theme/theme_provider.dart';
import '../../../../../../src/rust/api/inventory.dart';

class InventoryItemCard extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback onEdit;
  final VoidCallback? onDelete;
  final bool isSelectionMode;
  final bool isSelected;
  final bool isWideLayout;
  final ValueChanged<bool?>? onSelectedChanged;

  const InventoryItemCard({
    super.key,
    required this.item,
    required this.onEdit,
    this.onDelete,
    this.isSelectionMode = false,
    this.isSelected = false,
    this.isWideLayout = false,
    this.onSelectedChanged,
  });

  @override
  Widget build(BuildContext context) {
    final theme = context.theme;
    final colorScheme = context.colorScheme;

    final itemData = _calculateItemData(item);

    return RepaintBoundary(
      child: Stack(
        children: [
          isWideLayout
              ? _buildWideLayout(context, theme, colorScheme, itemData)
              : _buildCompactLayout(context, theme, colorScheme, itemData),
          if (isSelectionMode)
            Positioned(
              top: 8,
              right: 8,
              child: Checkbox(
                value: isSelected,
                onChanged: onSelectedChanged,
                shape: const CircleBorder(),
                activeColor: colorScheme.primary,
              ),
            ),
        ],
      ),
    );
  }

  _ItemDisplayData _calculateItemData(InventoryItem item) {
    final hasExpiration = item.expirationDate != 0;
    final dailyCost = item.dailyCost;

    final daysLeft = item.daysLeft;
    final daysOwned = item.daysOwned;
    final isExpired = hasExpiration && daysLeft < 0;

    Color statusColor = Colors.green;
    String statusText = '';
    if (hasExpiration) {
      if (isExpired) {
        statusColor = Colors.red;
        statusText = '已过期';
      } else if (daysLeft < 30) {
        statusColor = Colors.orange;
        statusText = '剩 $daysLeft 天';
      } else {
        statusText = '剩 $daysLeft 天';
      }
    }
    //不用显示太多相同信息 保持页面简洁。
    //else {
    //   statusColor = Colors.blue;
    //   statusText = '长期持有';
    // }

    final displayCategory = item.category.contains('/')
        ? item.category.split('/').last
        : item.category;

    final fullCategory = item.category.replaceAll('/', ' > ');

    return _ItemDisplayData(
      dailyCost: dailyCost,
      daysLeft: daysLeft.toInt(),
      daysOwned: daysOwned.toInt(),
      isExpired: isExpired,
      statusColor: statusColor,
      displayCategory: displayCategory,
      fullCategory: fullCategory,
      statusText: statusText,
      statusBgColor: statusColor.withValues(alpha: 0.1),
      hasExpiration: hasExpiration,
    );
  }

  Widget _buildCompactLayout(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    _ItemDisplayData data,
  ) {
    return GestureDetector(
      onTap: isSelectionMode ? () => onSelectedChanged!(!isSelected) : onEdit,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : context.adaptiveSecondaryBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected ? colorScheme.primary : theme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              flex: 3,
              child: item.imagePath != null
                  ? Image.file(
                      File(item.imagePath!),
                      fit: BoxFit.cover,
                      cacheWidth: 200,
                    )
                  : Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: Icon(
                        Icons.inventory_2,
                        size: 32,
                        color:
                            colorScheme.onSurfaceVariant.withValues(alpha: 0.5),
                      ),
                    ),
            ),
            Expanded(
              flex: 5,
              child: Padding(
                padding: const EdgeInsets.all(6.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      item.name,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.titleSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        fontSize: 12,
                        height: 1.1,
                      ),
                    ),
                    Text(
                      data.displayCategory,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: theme.textTheme.bodySmall?.copyWith(
                        fontSize: 10,
                        color: theme.hintColor,
                        height: 1.1,
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 1),
                      decoration: BoxDecoration(
                        color: data.statusBgColor,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        data.statusText,
                        style: TextStyle(
                          color: data.statusColor,
                          fontSize: 9,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                    const SizedBox(height: 2),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          '¥${item.cost.toStringAsFixed(1)}',
                          style: TextStyle(
                            color: theme.textTheme.bodyMedium?.color,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                        Text(
                          '已持${data.daysOwned}天',
                          style: TextStyle(
                            color: theme.hintColor,
                            fontSize: 9,
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 1),
                    FittedBox(
                      fit: BoxFit.scaleDown,
                      alignment: Alignment.centerLeft,
                      child: Text(
                        '¥${data.dailyCost.toStringAsFixed(1)}/天',
                        style: TextStyle(
                          color: colorScheme.primary,
                          fontSize: 11,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildWideLayout(
    BuildContext context,
    ThemeData theme,
    ColorScheme colorScheme,
    _ItemDisplayData data,
  ) {
    return GestureDetector(
      onTap: isSelectionMode ? () => onSelectedChanged!(!isSelected) : onEdit,
      child: Card(
        margin: EdgeInsets.zero,
        elevation: 0,
        color: isSelected
            ? colorScheme.primaryContainer.withValues(alpha: 0.3)
            : context.adaptiveSecondaryBackgroundColor,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: BorderSide(
            color: isSelected ? colorScheme.primary : theme.dividerColor,
            width: isSelected ? 2 : 1,
          ),
        ),
        clipBehavior: Clip.antiAlias,
        child: Stack(
          children: [
            Positioned.fill(
              child: item.imagePath != null
                  ? Image.file(
                      File(item.imagePath!),
                      fit: BoxFit.cover,
                      cacheWidth: 600,
                    )
                  : Container(
                      color: colorScheme.surfaceContainerHighest,
                      child: Center(
                        child: Icon(
                          Icons.inventory_2,
                          size: 80,
                          color: colorScheme.onSurfaceVariant
                              .withValues(alpha: 0.3),
                        ),
                      ),
                    ),
            ),
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Colors.black.withValues(alpha: 0.8),
                      Colors.black.withValues(alpha: 0.2),
                      Colors.transparent,
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(16.0),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Flexible(
                          child: Text(
                            item.name,
                            style: const TextStyle(
                              color: Colors.white,
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              shadows: [
                                Shadow(offset: Offset(0, 1), blurRadius: 4)
                              ],
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Flexible(
                          child: Text(
                            '分类: ${data.fullCategory} · 已拥有${data.daysOwned}天',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        const SizedBox(height: 12),
                        Wrap(
                          spacing: 20,
                          runSpacing: 8,
                          children: [
                            _buildLargeStat(
                                '总价', '¥${item.cost.toStringAsFixed(1)}'),
                            _buildLargeStat(
                              '日均',
                              '¥${data.dailyCost.toStringAsFixed(1)}',
                              highlight: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: data.statusColor,
                          borderRadius: BorderRadius.circular(10),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withValues(alpha: 0.2),
                              blurRadius: 4,
                              offset: const Offset(0, 2),
                            )
                          ],
                        ),
                        child: Text(
                          data.statusText,
                          style: const TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLargeStat(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            color: Colors.white.withValues(alpha: 0.7),
            fontSize: 12,
          ),
        ),
        Text(
          value,
          style: TextStyle(
            color: highlight ? Colors.orangeAccent : Colors.white,
            fontSize: 18,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

class _ItemDisplayData {
  final double dailyCost;
  final int daysLeft;
  final int daysOwned;
  final bool isExpired;
  final Color statusColor;
  final String displayCategory;
  final String fullCategory;
  final String statusText;
  final Color statusBgColor;
  final bool hasExpiration;

  _ItemDisplayData({
    required this.dailyCost,
    required this.daysLeft,
    required this.daysOwned,
    required this.isExpired,
    required this.statusColor,
    required this.displayCategory,
    required this.fullCategory,
    required this.statusText,
    required this.statusBgColor,
    required this.hasExpiration,
  });
}
