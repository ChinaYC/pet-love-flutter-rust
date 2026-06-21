import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import '../../../theme/theme_provider.dart';
import '../../../src/rust/api/inventory.dart';

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  List<InventoryItem> _items = [];
  bool _isLoading = true;
  int _touchedIndex = -1;

  final List<Color> _chartColors = [
    Colors.blue,
    Colors.red,
    Colors.orange,
    Colors.green,
    Colors.purple,
    Colors.teal,
    Colors.amber,
    Colors.pink,
  ];

  @override
  void initState() {
    super.initState();
    _loadItems();
  }

  Future<void> _loadItems() async {
    setState(() => _isLoading = true);
    try {
      final items = await getActiveInventoryItems();
      final stats = await getCategoryCostStats();
      setState(() {
        _items = items;
        _categoryStats = {for (var s in stats) s.name: s.totalCost};
        _isLoading = false;
      });
    } catch (e) {
      debugPrint('Error loading account data: $e');
      setState(() => _isLoading = false);
    }
  }

  Map<String, double> _categoryStats = {};

  double _calculateTotalCost() {
    return _categoryStats.values.fold(0, (sum, item) => sum + item);
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator());
    }

    final theme = context.theme;
    final totalCost = _calculateTotalCost();
    final categoryStats = _categoryStats;

    return Scaffold(
      backgroundColor: context.adaptiveBackgroundColor,
      body: RefreshIndicator(
        onRefresh: _loadItems,
        child: ListView(
          padding: const EdgeInsets.all(16.0),
          children: [
            _buildOverviewCard(totalCost),
            const SizedBox(height: 24),
            if (categoryStats.isNotEmpty) ...[
              Text('支出构成',
                  style: theme.textTheme.titleLarge
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              _buildPieChart(categoryStats, totalCost),
              const SizedBox(height: 24),
              ...categoryStats.entries.indexed.map((entry) {
                final index = entry.$1;
                final e = entry.$2;
                return _buildCategoryStatTile(
                  e.key,
                  e.value,
                  totalCost,
                  _chartColors[index % _chartColors.length],
                );
              }),
            ],
            const SizedBox(height: 24),
            Text('最近支出',
                style: theme.textTheme.titleLarge
                    ?.copyWith(fontWeight: FontWeight.bold)),
            const SizedBox(height: 12),
            if (_items.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  child: Text('暂无支出记录',
                      style: theme.textTheme.bodyMedium
                          ?.copyWith(color: theme.hintColor)),
                ),
              )
            else ...[
              ..._items.take(5).map((item) => _buildRecentItemTile(item)),
              if (_items.length > 5)
                TextButton(
                  onPressed: () {
                    // 跳转到囤货清单页面
                    DefaultTabController.of(context).animateTo(3);
                    // 或者通过 go_router 跳转
                    // context.go('/inventory');
                  },
                  child: const Text('查看全部记录'),
                ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildPieChart(Map<String, double> stats, double total) {
    return AspectRatio(
      aspectRatio: 1.3,
      child: PieChart(
        PieChartData(
          pieTouchData: PieTouchData(
            touchCallback: (FlTouchEvent event, pieTouchResponse) {
              setState(() {
                if (!event.isInterestedForInteractions ||
                    pieTouchResponse == null ||
                    pieTouchResponse.touchedSection == null) {
                  _touchedIndex = -1;
                  return;
                }
                _touchedIndex =
                    pieTouchResponse.touchedSection!.touchedSectionIndex;
              });
            },
          ),
          borderData: FlBorderData(show: false),
          sectionsSpace: 2,
          centerSpaceRadius: 40,
          sections: stats.entries.indexed.map((entry) {
            final index = entry.$1;
            final e = entry.$2;
            final isTouched = index == _touchedIndex;
            final fontSize = isTouched ? 20.0 : 12.0;
            final radius = isTouched ? 60.0 : 50.0;
            final percentage = (e.value / total * 100).toStringAsFixed(1);

            return PieChartSectionData(
              color: _chartColors[index % _chartColors.length],
              value: e.value,
              title: isTouched ? '${e.key}\n$percentage%' : '$percentage%',
              radius: radius,
              titleStyle: TextStyle(
                fontSize: fontSize,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildOverviewCard(double totalCost) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      clipBehavior: Clip.antiAlias,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              context.colorScheme.primary,
              context.colorScheme.secondary,
            ],
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: Column(
          children: [
            const Text('累计支出',
                style: TextStyle(color: Colors.white70, fontSize: 16)),
            const SizedBox(height: 8),
            Text('¥${totalCost.toStringAsFixed(2)}',
                style: const TextStyle(
                    color: Colors.white,
                    fontSize: 36,
                    fontWeight: FontWeight.bold)),
          ],
        ),
      ),
    );
  }

  Widget _buildCategoryStatTile(
      String category, double amount, double total, Color color) {
    final theme = context.theme;
    final percentage = total > 0 ? amount / total : 0.0;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    width: 12,
                    height: 12,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(category,
                      style: theme.textTheme.bodyLarge
                          ?.copyWith(fontWeight: FontWeight.w500)),
                ],
              ),
              Text(
                  '¥${amount.toStringAsFixed(1)} (${(percentage * 100).toStringAsFixed(1)}%)',
                  style: theme.textTheme.bodyMedium),
            ],
          ),
          const SizedBox(height: 4),
          LinearProgressIndicator(
            value: percentage,
            backgroundColor: context.colorScheme.surfaceContainerHighest,
            color: color.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(4),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentItemTile(InventoryItem item) {
    final theme = context.theme;
    final date = DateTime.fromMillisecondsSinceEpoch(item.purchaseDate);
    return ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(item.name, style: theme.textTheme.bodyLarge),
      subtitle: Text(
          '${date.year}-${date.month}-${date.day} · ${item.category}',
          style: theme.textTheme.bodySmall),
      trailing: Text('¥${item.cost.toStringAsFixed(1)}',
          style:
              theme.textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.bold)),
    );
  }
}
