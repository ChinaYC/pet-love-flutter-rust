import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../../../theme/theme_provider.dart';
import '../../../../../src/rust/api/inventory/models.dart';

class BillItemCard extends StatelessWidget {
  final InventoryItem item;

  const BillItemCard({super.key, required this.item});

  @override
  Widget build(BuildContext context) {
    final date = DateTime.fromMillisecondsSinceEpoch(item.purchaseDate.toInt());
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: context.adaptiveBackgroundColor,
        border: Border(
          bottom: BorderSide(
            color: context.theme.dividerColor,
            width: 0.5,
          ),
        ),
      ),
      child: Row(
        children: [
          _buildCategoryIcon(context, item.category),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  item.name,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                Text(
                  DateFormat('MM-dd HH:mm').format(date),
                  style: TextStyle(
                    fontSize: 12,
                    color: context.theme.hintColor,
                  ),
                ),
              ],
            ),
          ),
          Text(
            '-${item.cost.toStringAsFixed(2)}',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildCategoryIcon(BuildContext context, String category) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: context.theme.colorScheme.primary.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Icon(
        _getCategoryIconData(category),
        color: context.theme.colorScheme.primary,
        size: 24,
      ),
    );
  }

  IconData _getCategoryIconData(String category) {
    if (category.contains('食') || category.contains('餐')) {
      return Icons.restaurant;
    }
    if (category.contains('衣')) return Icons.checkroom;
    if (category.contains('住')) return Icons.home;
    if (category.contains('行') || category.contains('交通')) {
      return Icons.directions_car;
    }
    if (category.contains('玩') || category.contains('娱乐')) {
      return Icons.sports_esports;
    }
    if (category.contains('医') || category.contains('药')) {
      return Icons.medical_services;
    }
    if (category.contains('宠')) return Icons.pets;
    return Icons.category;
  }
}
