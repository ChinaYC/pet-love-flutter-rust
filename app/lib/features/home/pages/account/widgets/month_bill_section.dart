import 'package:flutter/material.dart';
import '../../../../../theme/theme_provider.dart';
import '../../../../../src/rust/api/inventory/models.dart';
import 'bill_item_card.dart';

class MonthBillSection extends StatelessWidget {
  final MonthGroupedItems group;

  const MonthBillSection({super.key, required this.group});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _buildHeader(context),
        ...group.items.map((item) => BillItemCard(item: item)),
      ],
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: context.adaptiveSecondaryBackgroundColor,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            _formatMonth(group.month),
            style: const TextStyle(fontWeight: FontWeight.bold),
          ),
          Text(
            '支出: ¥${group.totalCost.toStringAsFixed(2)}',
            style: TextStyle(
              color: context.theme.hintColor,
              fontSize: 12,
            ),
          ),
        ],
      ),
    );
  }

  String _formatMonth(String monthStr) {
    try {
      final parts = monthStr.split('-');
      final year = parts[0];
      final month = parts[1];
      final now = DateTime.now();
      if (year == now.year.toString()) {
        return '$month月';
      }
      return '$year年$month月';
    } catch (e) {
      return monthStr;
    }
  }
}
