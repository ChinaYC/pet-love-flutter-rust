import 'dart:io';
import 'package:flutter/material.dart';
import '../../../../../../src/rust/api/inventory.dart';

class InventoryItemCard extends StatelessWidget {
  final InventoryItem item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const InventoryItemCard({
    super.key,
    required this.item,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    // calculate dates
    final purchase = DateTime.fromMillisecondsSinceEpoch(item.purchaseDate);
    final expiration = DateTime.fromMillisecondsSinceEpoch(item.expirationDate);
    final now = DateTime.now();

    // total days
    final totalDays = expiration.difference(purchase).inDays;
    // protect against division by zero or negative days
    final validDays = totalDays > 0 ? totalDays : 1;

    final dailyCost = item.cost / validDays;

    // days left
    final daysLeft = expiration.difference(now).inDays;
    final isExpired = daysLeft < 0;

    // color based on days left
    Color statusColor = Colors.green;
    if (isExpired) {
      statusColor = Colors.red;
    } else if (daysLeft < 30) {
      statusColor = Colors.orange;
    }

    // Determine layout based on screen width or parent constraint roughly.
    // Here we use LayoutBuilder to adjust UI for Grid view.
    return LayoutBuilder(builder: (context, constraints) {
      final isSmall = constraints.maxWidth <
          300; // threshold for single column vs multi column

      if (isSmall) {
        // Multi-column compact layout (Medium and Small)
        return GestureDetector(
          onTap: onEdit,
          child: Card(
            margin: EdgeInsets.zero,
            elevation: 2,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Image Header (Top)
                Expanded(
                  flex: 4,
                  child: item.imagePath != null
                      ? Image.file(File(item.imagePath!), fit: BoxFit.cover)
                      : Container(
                          color: Colors.grey[200],
                          child: const Icon(Icons.inventory_2,
                              size: 40, color: Colors.grey),
                        ),
                ),
                // Content (Bottom)
                Expanded(
                  flex: 5,
                  child: Padding(
                    padding: const EdgeInsets.all(10.0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              item.name,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                  fontWeight: FontWeight.bold, fontSize: 14),
                            ),
                            Text(
                              item.category,
                              style: TextStyle(
                                  fontSize: 11, color: Colors.grey[600]),
                            ),
                          ],
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: statusColor.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            isExpired ? '已过期' : '剩 $daysLeft 天',
                            style: TextStyle(
                                color: statusColor,
                                fontSize: 11,
                                fontWeight: FontWeight.bold),
                          ),
                        ),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              '¥${dailyCost.toStringAsFixed(1)}/天',
                              style: TextStyle(
                                color: Theme.of(context).colorScheme.primary,
                                fontSize: 13,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                GestureDetector(
                                  onTap: onEdit,
                                  child: const Icon(Icons.edit_outlined,
                                      size: 18, color: Colors.black54),
                                ),
                                const SizedBox(width: 10),
                                GestureDetector(
                                  onTap: onDelete,
                                  child: const Icon(Icons.delete_outline,
                                      size: 18, color: Colors.redAccent),
                                ),
                              ],
                            ),
                          ],
                        )
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      }

      // Single column wide layout (Large) - Image as Background
      return GestureDetector(
        onTap: onEdit,
        child: Card(
          margin: EdgeInsets.zero,
          elevation: 3,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            children: [
              // Background Image
              Positioned.fill(
                child: item.imagePath != null
                    ? Image.file(File(item.imagePath!), fit: BoxFit.cover)
                    : Container(
                        color: Colors.grey[100],
                        child: Center(
                          child: Icon(Icons.inventory_2,
                              size: 80, color: Colors.grey[300]),
                        ),
                      ),
              ),
              // Gradient Overlay for readability
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
              // Content
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
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
                          const SizedBox(height: 4),
                          Text(
                            '分类: ${item.category}',
                            style: TextStyle(
                              color: Colors.white.withValues(alpha: 0.9),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            children: [
                              _buildLargeStat(
                                  '总价', '¥${item.cost.toStringAsFixed(1)}'),
                              const SizedBox(width: 20),
                              _buildLargeStat(
                                  '日均', '¥${dailyCost.toStringAsFixed(1)}',
                                  highlight: true),
                            ],
                          ),
                        ],
                      ),
                    ),
                    Column(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: statusColor,
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
                            isExpired ? '已过期' : '剩 $daysLeft 天',
                            style: const TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                                fontSize: 13),
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.edit_outlined,
                              color: Colors.white70, size: 26),
                          onPressed: onEdit,
                          padding: EdgeInsets.zero,
                          tooltip: '编辑',
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline,
                              color: Colors.white70, size: 28),
                          onPressed: onDelete,
                          padding: EdgeInsets.zero,
                          tooltip: '删除',
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
    });
  }

  Widget _buildLargeStat(String label, String value, {bool highlight = false}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
              color: Colors.white.withValues(alpha: 0.7), fontSize: 12),
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
