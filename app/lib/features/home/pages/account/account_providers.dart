import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../src/rust/api/inventory/items.dart';
import '../../../../src/rust/api/inventory/bills.dart';
import '../../../../src/rust/api/inventory/stats.dart';
import '../../../../src/rust/api/inventory/models.dart';

final accountOverviewStatsProvider =
    FutureProvider<AccountOverviewStats>((ref) async {
  // 监听账单变化，自动刷新统计
  ref.watch(monthGroupedItemsProvider);
  return getAccountOverviewStats();
});

final accountSearchQueryProvider = StateProvider<InventorySearchQuery>((ref) {
  return const InventorySearchQuery(
    query: null,
    category: null,
    startDate: null,
    endDate: null,
    minCost: null,
    maxCost: null,
  );
});

final monthGroupedItemsProvider =
    FutureProvider<List<MonthGroupedItems>>((ref) async {
  final query = ref.watch(accountSearchQueryProvider);
  return searchAndGroupByMonth(query: query);
});

final accountCategoriesProvider = FutureProvider<List<String>>((ref) async {
  // We can get categories from inventory stats or a dedicated API
  // For now, let's just get active items and extract categories
  final items = await getActiveInventoryItems();
  final categories = items.map((e) => e.category).toSet().toList();
  categories.sort();
  return ['全部', ...categories];
});
