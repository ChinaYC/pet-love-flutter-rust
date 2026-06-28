import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../core/services/app_message_queue.dart';
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
  StreamSubscription<InventoryDataChangedMessage>? _refreshSubscription;
  bool _refreshScheduled = false;

  @override
  void initState() {
    super.initState();
    _bindRefreshQueue();
  }

  /// 功能：触发账本相关数据重新加载，并等待主要数据请求完成。
  /// 参数：无。
  /// 返回值：返回刷新完成的 Future。
  /// 注意事项：用于下拉刷新时必须等待真实请求结束，否则刷新指示器会过早消失。
  Future<void> _refreshAccountData() async {
    ref.invalidate(monthGroupedItemsProvider);
    ref.invalidate(accountOverviewStatsProvider);
    ref.invalidate(accountCategoriesProvider);
    await Future.wait([
      ref.read(monthGroupedItemsProvider.future),
      ref.read(accountOverviewStatsProvider.future),
      ref.read(accountCategoriesProvider.future),
    ]);
  }

  /// 功能：绑定全局消息队列，接收囤货变更后的显式刷新消息。
  /// 参数：无。
  /// 返回值：无。
  /// 注意事项：订阅只在页面生命周期内存在，避免 provider 之间互相 watch 造成隐式联动。
  void _bindRefreshQueue() {
    _refreshSubscription = ref
        .read(appMessageQueueProvider)
        .ofType<InventoryDataChangedMessage>()
        .listen((_) {
      if (!mounted || _refreshScheduled) return;
      _refreshScheduled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _refreshScheduled = false;
        if (!mounted) return;
        unawaited(_refreshAccountData());
      });
    });
  }

  bool _shouldShowRefreshIndicator(AsyncValue<Object?> value) {
    return value.hasValue && (value.isRefreshing || value.isReloading);
  }

  @override
  void dispose() {
    _refreshSubscription?.cancel();
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
    final isRefreshing = _shouldShowRefreshIndicator(groupedItemsAsync) ||
        _shouldShowRefreshIndicator(overviewStatsAsync);

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
      body: Column(
        children: [
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 180),
            child: isRefreshing
                ? const LinearProgressIndicator(
                    key: ValueKey('account-refreshing'),
                    minHeight: 2,
                  )
                : const SizedBox(
                    key: ValueKey('account-idle'),
                    height: 2,
                  ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: _refreshAccountData,
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
                              child:
                                  Center(child: CupertinoActivityIndicator()),
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
                          (context, index) =>
                              MonthBillSection(group: groups[index]),
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
          ),
        ],
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
