import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../theme/theme_provider.dart';
import '../../../src/rust/api/inventory/models.dart';
import 'account/account_providers.dart';
import 'account/widgets/month_bill_section.dart';
import 'account/widgets/account_filter_sheet.dart';
import 'account/widgets/account_overview_card.dart';
import 'account/widgets/account_pie_chart.dart';

class AccountPage extends ConsumerStatefulWidget {
  const AccountPage({super.key});

  @override
  ConsumerState<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends ConsumerState<AccountPage> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String value) {
    final currentQuery = ref.read(accountSearchQueryProvider);
    ref.read(accountSearchQueryProvider.notifier).state = InventorySearchQuery(
      query: value.isEmpty ? null : value,
      category: currentQuery.category,
      startDate: currentQuery.startDate,
      endDate: currentQuery.endDate,
      minCost: currentQuery.minCost,
      maxCost: currentQuery.maxCost,
    );
  }

  @override
  Widget build(BuildContext context) {
    final groupedItemsAsync = ref.watch(monthGroupedItemsProvider);
    final overviewStatsAsync = ref.watch(accountOverviewStatsProvider);

    return Scaffold(
      backgroundColor: context.adaptiveBackgroundColor,
      appBar: CupertinoNavigationBar(
        backgroundColor: context.adaptiveBackgroundColor.withValues(alpha: 0.8),
        middle: const Text('账单'),
        trailing: CupertinoButton(
          padding: EdgeInsets.zero,
          child: const Icon(CupertinoIcons.slider_horizontal_3),
          onPressed: () => _showFilterSheet(context),
        ),
      ),
      body: RefreshIndicator(
        onRefresh: () async {
          ref.invalidate(monthGroupedItemsProvider);
          ref.invalidate(accountOverviewStatsProvider);
        },
        child: CustomScrollView(
          slivers: [
            SliverToBoxAdapter(
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  children: [
                    overviewStatsAsync.when(
                      data: (stats) => Column(
                        children: [
                          AccountOverviewCard(
                            totalYear: stats.totalYear,
                            totalQuarter: stats.totalQuarter,
                            totalMonth: stats.totalMonth,
                            totalDay: stats.totalDay,
                          ),
                          const SizedBox(height: 24),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              '本月支出构成',
                              style: TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),
                          AccountPieChart(stats: stats.categoryStats),
                        ],
                      ),
                      loading: () => const SizedBox(
                        height: 200,
                        child: Center(child: CupertinoActivityIndicator()),
                      ),
                      error: (err, _) => Text('统计加载失败: $err'),
                    ),
                    const SizedBox(height: 24),
                    _buildSearchField(),
                  ],
                ),
              ),
            ),
            groupedItemsAsync.when(
              data: (groups) {
                if (groups.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(context),
                  );
                }
                return SliverList(
                  delegate: SliverChildBuilderDelegate(
                    (context, index) => MonthBillSection(group: groups[index]),
                    childCount: groups.length,
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CupertinoActivityIndicator()),
              ),
              error: (err, stack) => SliverFillRemaining(
                child: Center(child: Text('加载失败: $err')),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchField() {
    return CupertinoSearchTextField(
      controller: _searchController,
      placeholder: '搜索账单内容',
      onChanged: _onSearchChanged,
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(CupertinoIcons.doc_text_search,
              size: 64, color: context.theme.hintColor),
          const SizedBox(height: 16),
          Text('没有找到相关账单', style: TextStyle(color: context.theme.hintColor)),
        ],
      ),
    );
  }

  void _showFilterSheet(BuildContext context) {
    showCupertinoModalPopup(
      context: context,
      builder: (context) => AccountFilterSheet(
        onApply: (query) {
          ref.read(accountSearchQueryProvider.notifier).state = query;
        },
        initialQuery: ref.read(accountSearchQueryProvider),
      ),
    );
  }
}
